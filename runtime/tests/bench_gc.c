#define _POSIX_C_SOURCE 200809L
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "syli/gc_helpers.h"
#include "syli/header_object.h"
#include "syli/object.h"
#include "syli/syli_state.h"

typedef enum {
    Output_JSON,
    Output_CSV,
    Output_SUMMARY,
    Output_SILENT
} OutputMode;

typedef struct {
    OutputMode output_mode;
} RunConfig;

typedef struct {
    size_t cycle_index;
    uint64_t pause_ns;
    size_t suspected_lost_cycle;
    size_t releasing_worklist;
    size_t releasing_waitlist;
    size_t dropping_worklist;
    size_t dropping_waitlist;
    size_t tracing_worklist;
    size_t tracing_mutations;
} CycleMetrics;

typedef struct {
    size_t releasing_steps;
    size_t tracing_steps;
    size_t dropping_steps;
    size_t mutation_steps;
    size_t checking_steps;

    size_t total_dropped;
    size_t total_traced;
    size_t total_released;
    size_t total_memory_freed;

    size_t generation_tracing;
    size_t tracing_generations;
    size_t suspect_notifications;
} CounterSnapshot;

typedef struct {
    double alloc_time_ms;
    double gc_time_ms;
    double all_time_ms;
    size_t gc_cycles;
    size_t peak_candidates;
    uint64_t max_pause_ns;
    double throughput_objects_per_ms;

    size_t suspect_notifications;
    size_t generation_tracing;
    size_t tracing_generations;

    size_t releasing_steps;
    size_t tracing_steps;
    size_t dropping_steps;
    size_t mutation_steps;
    size_t checking_steps;

    size_t total_dropped;
    size_t total_traced;
    size_t total_released;
    size_t total_memory_freed;

    size_t total_dropped_derived;
    size_t total_released_derived;

    CycleMetrics* cycles;
    size_t cycle_count;
    size_t cycle_capacity;
} RoundResult;

typedef struct {
    const char* name;
    const char* workload;
    size_t rounds;
    size_t total_objects;
    RoundResult* round_results;
} ScenarioResult;

static uint64_t time_diff_ns(
    const struct timespec* start, const struct timespec* end)
{
    return (uint64_t)(end->tv_sec - start->tv_sec) * 1000000000ULL
        + (uint64_t)(end->tv_nsec - start->tv_nsec);
}

static double ns_to_ms(uint64_t ns) { return (double)ns / 1e6; }

static int compare_u64(const void* a, const void* b)
{
    uint64_t lhs = *(const uint64_t*)a;
    uint64_t rhs = *(const uint64_t*)b;
    if (lhs < rhs) {
        return -1;
    }
    if (lhs > rhs) {
        return 1;
    }
    return 0;
}

static double percentile_ns_sorted(const uint64_t* sorted, size_t n, double p)
{
    if (n == 0) {
        return 0.0;
    }

    double rank = p * (double)(n - 1);
    size_t lo   = (size_t)rank;
    size_t hi   = lo + 1 < n ? lo + 1 : lo;
    double frac = rank - (double)lo;
    return (double)sorted[lo]
        + ((double)sorted[hi] - (double)sorted[lo]) * frac;
}

static Object* make_ref_object(size_t words, CyclicFlag cyclic)
{
    object_payload_t payload = syli_object_make_mono_payload(words);
    object_header_t header   = syli_object_make_header(
        Zone_GcLocal, cyclic, Type_MonoRef, Flag_HasPointers, payload);
    uint64_t meta = make_meta_refcount(
        Meta_Flags_None, (ObjectMetaFlags)syli_state.tracing_current_bit_mark);
    Object* obj = syli_object_alloc(header, meta, words);
    memset(syli_object_data(obj), 0, words * sizeof(uint64_t));
    return obj;
}

static void init_round_result(RoundResult* r) { memset(r, 0, sizeof(*r)); }

static void destroy_round_result(RoundResult* r)
{
    free(r->cycles);
    r->cycles         = NULL;
    r->cycle_count    = 0;
    r->cycle_capacity = 0;
}

static void destroy_scenario_result(ScenarioResult* scenario)
{
    if (!scenario || !scenario->round_results) {
        return;
    }

    for (size_t i = 0; i < scenario->rounds; i++) {
        destroy_round_result(&scenario->round_results[i]);
    }

    free(scenario->round_results);
    scenario->round_results = NULL;
}

static void reserve_cycle_metrics(RoundResult* round, size_t need)
{
    if (need <= round->cycle_capacity) {
        return;
    }

    size_t next_cap = round->cycle_capacity == 0 ? 256 : round->cycle_capacity;
    while (next_cap < need) {
        next_cap *= 2;
    }

    CycleMetrics* new_cycles = (CycleMetrics*)realloc(
        round->cycles, next_cap * sizeof(CycleMetrics));
    if (!new_cycles) {
        fprintf(stderr, "bench_gc: failed to allocate cycle metrics buffer\n");
        exit(1);
    }

    round->cycles         = new_cycles;
    round->cycle_capacity = next_cap;
}

static void append_cycle_metric(RoundResult* round, const CycleMetrics* metric)
{
    reserve_cycle_metrics(round, round->cycle_count + 1);
    round->cycles[round->cycle_count++] = *metric;
}

static CounterSnapshot take_counter_snapshot(void)
{
    CounterSnapshot s;
    s.releasing_steps = syli_state.releasing_steps;
    s.tracing_steps   = syli_state.tracing_steps;
    s.dropping_steps  = syli_state.dropping_steps;
    s.mutation_steps  = syli_state.mutation_steps;
    s.checking_steps  = syli_state.checking_steps;

    s.total_dropped      = syli_state.total_objects_dropped;
    s.total_traced       = syli_state.total_objects_traced;
    s.total_released     = syli_state.total_objects_released;
    s.total_memory_freed = syli_state.total_objects_memory_freed;

    s.generation_tracing    = syli_state.generation_tracing;
    s.tracing_generations   = syli_state.tracing_generations;
    s.suspect_notifications = syli_state.suspect_objects_notifications;
    return s;
}

static size_t delta_size(size_t before, size_t after)
{
    return after >= before ? after - before : 0;
}

/* Returns true when all GC queues are drained and state machines are idle. */
static bool gc_is_done(void)
{
    return vector_size_GCObject(&syli_state.releasing_waitlist) == 0
        && vector_size_GCObject(&syli_state.releasing_worklist) == 0
        && vector_size_GCObject(&syli_state.dropping_waitlist) == 0
        && vector_size_GCObject(&syli_state.dropping_worklist) == 0
        && vector_size_GCObject(&syli_state.tracing_worklist) == 0
        && vector_size_GCObject(&syli_state.tracing_mutations_worklist) == 0
        && syli_state.tracing_state == Tracing_Idle
        && syli_state.releasing_state == Releasing_Idle
        && syli_state.dropping_state == Dropping_Idle;
}

static void init_runtime_defaults(void)
{
    syli_state.THRESHOLD_RELEASING_BUCKET    = 1;
    syli_state.THRESHOLD_DROPPING_BUCKET     = 1;
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = 0;
}

static void run_drain_and_collect(RoundResult* round)
{
    uint64_t total_gc_ns = 0;
    size_t peak_suspect_notifications
        = syli_state.suspect_objects_notifications;

    while (!gc_is_done()) {
        struct timespec cs;
        struct timespec ce;
        clock_gettime(CLOCK_MONOTONIC, &cs);
        syli_state_gc_cycle();
        clock_gettime(CLOCK_MONOTONIC, &ce);

        CycleMetrics metric;
        metric.cycle_index = round->cycle_count;
        metric.pause_ns    = time_diff_ns(&cs, &ce);
        metric.suspected_lost_cycle
            = vector_size_Suspected(&syli_state.suspect_lost_cycle);
        metric.releasing_worklist
            = vector_size_GCObject(&syli_state.releasing_worklist);
        metric.releasing_waitlist
            = vector_size_GCObject(&syli_state.releasing_waitlist);
        metric.dropping_worklist
            = vector_size_GCObject(&syli_state.dropping_worklist);
        metric.dropping_waitlist
            = vector_size_GCObject(&syli_state.dropping_waitlist);
        metric.tracing_worklist
            = vector_size_GCObject(&syli_state.tracing_worklist);
        metric.tracing_mutations
            = vector_size_GCObject(&syli_state.tracing_mutations_worklist);

        append_cycle_metric(round, &metric);

        if (syli_state.suspect_objects_notifications
            > peak_suspect_notifications) {
            peak_suspect_notifications
                = syli_state.suspect_objects_notifications;
        }

        if (metric.pause_ns > round->max_pause_ns) {
            round->max_pause_ns = metric.pause_ns;
        }
        if (metric.suspected_lost_cycle > round->peak_candidates) {
            round->peak_candidates = metric.suspected_lost_cycle;
        }

        total_gc_ns += metric.pause_ns;
    }

    round->gc_cycles             = round->cycle_count;
    round->gc_time_ms            = ns_to_ms(total_gc_ns);
    round->suspect_notifications = peak_suspect_notifications;
}

static void finalize_round_metrics(RoundResult* round, size_t total_objects,
    const CounterSnapshot* before, const CounterSnapshot* after,
    uint64_t alloc_ns)
{
    round->alloc_time_ms             = ns_to_ms(alloc_ns);
    round->all_time_ms               = round->alloc_time_ms + round->gc_time_ms;
    round->throughput_objects_per_ms = round->all_time_ms > 0.0
        ? (double)total_objects / round->all_time_ms
        : 0.0;

    round->releasing_steps
        = delta_size(before->releasing_steps, after->releasing_steps);
    round->tracing_steps
        = delta_size(before->tracing_steps, after->tracing_steps);
    round->dropping_steps
        = delta_size(before->dropping_steps, after->dropping_steps);
    round->mutation_steps
        = delta_size(before->mutation_steps, after->mutation_steps);
    round->checking_steps
        = delta_size(before->checking_steps, after->checking_steps);

    round->total_dropped
        = delta_size(before->total_dropped, after->total_dropped);
    round->total_traced = delta_size(before->total_traced, after->total_traced);
    round->total_released
        = delta_size(before->total_released, after->total_released);
    round->total_memory_freed
        = delta_size(before->total_memory_freed, after->total_memory_freed);

    round->total_dropped_derived  = round->dropping_steps;
    round->total_released_derived = round->releasing_steps;

    round->generation_tracing
        = delta_size(before->generation_tracing, after->generation_tracing);
    round->tracing_generations
        = delta_size(before->tracing_generations, after->tracing_generations);
}

static void setup_releasing_workload(size_t chain_count, size_t chain_len)
{
    Object** roots = (Object**)malloc(chain_count * sizeof(Object*));
    if (!roots) {
        fprintf(stderr, "bench_gc: failed to allocate releasing roots\n");
        exit(1);
    }

    for (size_t i = 0; i < chain_count; i++) {
        Object* head = make_ref_object(1, Acyclic);
        Object* cur  = head;
        for (size_t j = 1; j < chain_len; j++) {
            Object* next             = make_ref_object(1, Acyclic);
            syli_object_data(cur)[0] = (uint64_t)next;
            cur                      = next;
        }
        roots[i] = head;
    }

    for (size_t i = 0; i < chain_count; i++) {
        syli_object_decr_local(roots[i]);
        gc_vector_push_back(&syli_state.releasing_waitlist, roots[i]);
    }

    free(roots);
}

static void setup_dropping_workload(size_t leaf_count)
{
    for (size_t i = 0; i < leaf_count; i++) {
        Object* leaf = make_ref_object(0, Acyclic);
        syli_object_decr_local(leaf);
        gc_vector_push_back(&syli_state.dropping_waitlist, leaf);
    }
}

static ScenarioResult run_releasing_scenario(size_t rounds)
{
    const size_t chain_count   = 3000;
    const size_t chain_len     = 96;
    const size_t total_objects = chain_count * chain_len;

    ScenarioResult scenario;
    scenario.name          = "releasing_stress";
    scenario.workload      = "3000 chains x 96 nodes";
    scenario.rounds        = rounds;
    scenario.total_objects = total_objects;
    scenario.round_results = (RoundResult*)calloc(rounds, sizeof(RoundResult));
    if (!scenario.round_results) {
        fprintf(stderr, "bench_gc: failed to allocate releasing scenario\n");
        exit(1);
    }

    for (size_t r = 0; r < rounds; r++) {
        RoundResult* round = &scenario.round_results[r];
        init_round_result(round);

        syli_state_init();
        init_runtime_defaults();

        CounterSnapshot before = take_counter_snapshot();

        struct timespec t0;
        struct timespec t1;
        clock_gettime(CLOCK_MONOTONIC, &t0);
        setup_releasing_workload(chain_count, chain_len);
        clock_gettime(CLOCK_MONOTONIC, &t1);

        run_drain_and_collect(round);
        CounterSnapshot after = take_counter_snapshot();
        finalize_round_metrics(
            round, total_objects, &before, &after, time_diff_ns(&t0, &t1));

        syli_state_destroy();
    }

    return scenario;
}

static ScenarioResult run_dropping_scenario(size_t rounds)
{
    const size_t leaf_count = 250000;

    ScenarioResult scenario;
    scenario.name          = "dropping_stress";
    scenario.workload      = "250000 leaf objects";
    scenario.rounds        = rounds;
    scenario.total_objects = leaf_count;
    scenario.round_results = (RoundResult*)calloc(rounds, sizeof(RoundResult));
    if (!scenario.round_results) {
        fprintf(stderr, "bench_gc: failed to allocate dropping scenario\n");
        exit(1);
    }

    for (size_t r = 0; r < rounds; r++) {
        RoundResult* round = &scenario.round_results[r];
        init_round_result(round);

        syli_state_init();
        init_runtime_defaults();

        CounterSnapshot before = take_counter_snapshot();

        struct timespec t0;
        struct timespec t1;
        clock_gettime(CLOCK_MONOTONIC, &t0);
        setup_dropping_workload(leaf_count);
        clock_gettime(CLOCK_MONOTONIC, &t1);

        run_drain_and_collect(round);
        CounterSnapshot after = take_counter_snapshot();
        finalize_round_metrics(
            round, leaf_count, &before, &after, time_diff_ns(&t0, &t1));

        syli_state_destroy();
    }

    return scenario;
}

static ScenarioResult run_mixed_scenario(size_t rounds)
{
    const size_t release_count = 80000;
    const size_t drop_count    = 80000;
    const size_t trace_pairs   = 2048;
    const size_t total_objects = release_count + drop_count + trace_pairs * 2;

    ScenarioResult scenario;
    scenario.name          = "mixed_stress";
    scenario.workload      = "80000 release + 80000 drop + 2048 traced cycles";
    scenario.rounds        = rounds;
    scenario.total_objects = total_objects;
    scenario.round_results = (RoundResult*)calloc(rounds, sizeof(RoundResult));
    if (!scenario.round_results) {
        fprintf(stderr, "bench_gc: failed to allocate mixed scenario\n");
        exit(1);
    }

    for (size_t r = 0; r < rounds; r++) {
        RoundResult* round = &scenario.round_results[r];
        init_round_result(round);

        syli_state_init();
        init_runtime_defaults();

        Object** root_slots = (Object**)malloc(trace_pairs * sizeof(Object*));
        Object*** roots     = (Object***)malloc(trace_pairs * sizeof(Object**));
        Object** children   = (Object**)malloc(trace_pairs * sizeof(Object*));
        if (!root_slots || !roots || !children) {
            fprintf(
                stderr, "bench_gc: failed to allocate mixed tracing roots\n");
            free(root_slots);
            free(roots);
            free(children);
            exit(1);
        }

        CounterSnapshot before = take_counter_snapshot();

        struct timespec t0;
        struct timespec t1;
        clock_gettime(CLOCK_MONOTONIC, &t0);

        for (size_t i = 0; i < trace_pairs; i++) {
            root_slots[i]                      = make_ref_object(1, Cyclic);
            children[i]                        = make_ref_object(1, Cyclic);
            syli_object_data(root_slots[i])[0] = (uint64_t)children[i];
            syli_object_data(children[i])[0]   = (uint64_t)root_slots[i];
            roots[i]                           = &root_slots[i];
        }

        Frame frame = { .root_count = (uint32_t)trace_pairs, .roots = roots };
        syli_state_push_frame_scope(&frame);

        for (size_t i = 0; i < release_count; i++) {
            Object* rel = make_ref_object(0, Acyclic);
            syli_object_decr_local(rel);
            gc_vector_push_back(&syli_state.releasing_waitlist, rel);
        }

        for (size_t i = 0; i < drop_count; i++) {
            Object* drp = make_ref_object(0, Acyclic);
            syli_object_decr_local(drp);
            gc_vector_push_back(&syli_state.dropping_waitlist, drp);
        }

        for (size_t i = 0; i < trace_pairs; i++) {
            gc_add_suspect(root_slots[i]);
        }

        clock_gettime(CLOCK_MONOTONIC, &t1);

        run_drain_and_collect(round);
        CounterSnapshot after = take_counter_snapshot();
        finalize_round_metrics(
            round, total_objects, &before, &after, time_diff_ns(&t0, &t1));

        syli_state_pop_frame_scope();
        for (size_t i = 0; i < trace_pairs; i++) {
            free(root_slots[i]);
            free(children[i]);
        }
        free(children);
        free(roots);
        free(root_slots);
        syli_state_destroy();
    }

    return scenario;
}

static void print_json_round(const RoundResult* r)
{
    printf("      {\n");
    printf("        \"alloc_time_ms\": %.6f,\n", r->alloc_time_ms);
    printf("        \"gc_time_ms\": %.6f,\n", r->gc_time_ms);
    printf("        \"all_time_ms\": %.6f,\n", r->all_time_ms);
    printf("        \"gc_cycles\": %zu,\n", r->gc_cycles);
    printf("        \"peak_candidates\": %zu,\n", r->peak_candidates);
    printf("        \"max_pause_ms\": %.6f,\n", ns_to_ms(r->max_pause_ns));
    printf("        \"throughput_objects_per_ms\": %.6f,\n",
        r->throughput_objects_per_ms);
    printf(
        "        \"suspect_notifications\": %zu,\n", r->suspect_notifications);
    printf("        \"generation_tracing\": %zu,\n", r->generation_tracing);
    printf("        \"tracing_generations\": %zu,\n", r->tracing_generations);

    printf("        \"steps\": {\n");
    printf("          \"releasing\": %zu,\n", r->releasing_steps);
    printf("          \"tracing\": %zu,\n", r->tracing_steps);
    printf("          \"dropping\": %zu,\n", r->dropping_steps);
    printf("          \"mutations\": %zu,\n", r->mutation_steps);
    printf("          \"checking\": %zu\n", r->checking_steps);
    printf("        },\n");

    printf("        \"total\": {\n");
    printf("          \"dropped\": %zu,\n", r->total_dropped);
    printf("          \"traced\": %zu,\n", r->total_traced);
    printf("          \"released\": %zu,\n", r->total_released);
    printf("          \"memory_freed\": %zu,\n", r->total_memory_freed);
    printf("          \"dropped_derived_steps\": %zu,\n",
        r->total_dropped_derived);
    printf("          \"released_derived_steps\": %zu\n",
        r->total_released_derived);
    printf("        },\n");

    printf("        \"cycle_list\": [\n");
    for (size_t i = 0; i < r->cycle_count; i++) {
        const CycleMetrics* c = &r->cycles[i];
        printf("          {");
        printf("\"cycle\": %zu, ", c->cycle_index);
        printf("\"pause_ms\": %.6f, ", ns_to_ms(c->pause_ns));
        printf("\"suspected_lost_cycle\": %zu, ", c->suspected_lost_cycle);
        printf("\"releasing_worklist\": %zu, ", c->releasing_worklist);
        printf("\"releasing_waitlist\": %zu, ", c->releasing_waitlist);
        printf("\"dropping_worklist\": %zu, ", c->dropping_worklist);
        printf("\"dropping_waitlist\": %zu, ", c->dropping_waitlist);
        printf("\"tracing_worklist\": %zu, ", c->tracing_worklist);
        printf("\"tracing_mutations\": %zu", c->tracing_mutations);
        printf("}");
        if (i + 1 < r->cycle_count) {
            printf(",");
        }
        printf("\n");
    }
    printf("        ]\n");
    printf("      }");
}

static void print_json_output(
    const ScenarioResult* scenarios, size_t scenario_count)
{
    printf("{\n");
    printf("  \"suite\": \"gc_performance\",\n");
    printf("  \"format_version\": 1,\n");
    printf("  \"throughput_unit\": \"objects/ms\",\n");
    printf("  \"scenarios\": [\n");

    for (size_t i = 0; i < scenario_count; i++) {
        const ScenarioResult* s = &scenarios[i];
        printf("    {\n");
        printf("      \"name\": \"%s\",\n", s->name);
        printf("      \"workload\": \"%s\",\n", s->workload);
        printf("      \"total_objects\": %zu,\n", s->total_objects);
        printf("      \"rounds\": [\n");
        for (size_t r = 0; r < s->rounds; r++) {
            print_json_round(&s->round_results[r]);
            if (r + 1 < s->rounds) {
                printf(",");
            }
            printf("\n");
        }
        printf("      ]\n");
        printf("    }");
        if (i + 1 < scenario_count) {
            printf(",");
        }
        printf("\n");
    }

    printf("  ]\n");
    printf("}\n");
}

static void print_csv_output(
    const ScenarioResult* scenarios, size_t scenario_count)
{
    printf("scenario,round,alloc_time_ms,gc_time_ms,all_time_ms,gc_cycles,peak_"
           "candidates,max_pause_ms,throughput_objects_per_ms,suspect_"
           "notifications,generation_tracing,tracing_generations,releasing_"
           "steps,tracing_steps,dropping_steps,mutation_steps,checking_steps,"
           "total_dropped,total_traced,total_released,total_memory_freed,total_"
           "dropped_derived_steps,total_released_derived_steps\n");
    for (size_t i = 0; i < scenario_count; i++) {
        const ScenarioResult* s = &scenarios[i];
        for (size_t r = 0; r < s->rounds; r++) {
            const RoundResult* rr = &s->round_results[r];
            printf("%s,%zu,%.6f,%.6f,%.6f,%zu,%zu,%.6f,%.6f,%zu,%zu,%zu,%zu,%"
                   "zu,%zu,%zu,%zu,%zu,%zu,%zu,%zu,%zu,%zu\n",
                s->name, r, rr->alloc_time_ms, rr->gc_time_ms, rr->all_time_ms,
                rr->gc_cycles, rr->peak_candidates, ns_to_ms(rr->max_pause_ns),
                rr->throughput_objects_per_ms, rr->suspect_notifications,
                rr->generation_tracing, rr->tracing_generations,
                rr->releasing_steps, rr->tracing_steps, rr->dropping_steps,
                rr->mutation_steps, rr->checking_steps, rr->total_dropped,
                rr->total_traced, rr->total_released, rr->total_memory_freed,
                rr->total_dropped_derived, rr->total_released_derived);
        }
    }

    printf("\n");
    printf("scenario,round,cycle,pause_ms,suspected_lost_cycle,releasing_"
           "worklist,releasing_waitlist,dropping_worklist,dropping_waitlist,"
           "tracing_worklist,tracing_mutations\n");
    for (size_t i = 0; i < scenario_count; i++) {
        const ScenarioResult* s = &scenarios[i];
        for (size_t r = 0; r < s->rounds; r++) {
            const RoundResult* rr = &s->round_results[r];
            for (size_t c = 0; c < rr->cycle_count; c++) {
                const CycleMetrics* cm = &rr->cycles[c];
                printf("%s,%zu,%zu,%.6f,%zu,%zu,%zu,%zu,%zu,%zu,%zu\n", s->name,
                    r, cm->cycle_index, ns_to_ms(cm->pause_ns),
                    cm->suspected_lost_cycle, cm->releasing_worklist,
                    cm->releasing_waitlist, cm->dropping_worklist,
                    cm->dropping_waitlist, cm->tracing_worklist,
                    cm->tracing_mutations);
            }
        }
    }
}

static void print_summary_output(
    const ScenarioResult* scenarios, size_t scenario_count)
{
    printf("\033[1;34m=== GC Performance Summary ===\033[0m\n");
    printf("\033[1;34mthroughput unit: objects/ms\033[0m\n\n");

    for (size_t i = 0; i < scenario_count; i++) {
        const ScenarioResult* s = &scenarios[i];

        double sum_alloc_ms              = 0.0;
        double sum_gc_ms                 = 0.0;
        double sum_all_ms                = 0.0;
        double sum_cycles                = 0.0;
        double sum_throughput            = 0.0;
        double sum_suspect_notifications = 0.0;
        double sum_generation_tracing    = 0.0;
        double sum_tracing_generations   = 0.0;

        size_t peak_candidates_max = 0;
        uint64_t max_pause_ns      = 0;
        size_t total_cycles        = 0;

        for (size_t r = 0; r < s->rounds; r++) {
            const RoundResult* rr = &s->round_results[r];
            sum_alloc_ms += rr->alloc_time_ms;
            sum_gc_ms += rr->gc_time_ms;
            sum_all_ms += rr->all_time_ms;
            sum_cycles += (double)rr->gc_cycles;
            sum_throughput += rr->throughput_objects_per_ms;
            sum_suspect_notifications += (double)rr->suspect_notifications;
            sum_generation_tracing += (double)rr->generation_tracing;
            sum_tracing_generations += (double)rr->tracing_generations;

            if (rr->peak_candidates > peak_candidates_max) {
                peak_candidates_max = rr->peak_candidates;
            }
            if (rr->max_pause_ns > max_pause_ns) {
                max_pause_ns = rr->max_pause_ns;
            }

            total_cycles += rr->cycle_count;
        }

        uint64_t* pauses = NULL;
        if (total_cycles > 0) {
            pauses = (uint64_t*)malloc(total_cycles * sizeof(uint64_t));
            if (!pauses) {
                fprintf(stderr,
                    "bench_gc: failed to allocate summary pause buffer\n");
                exit(1);
            }
        }

        size_t pos = 0;
        for (size_t r = 0; r < s->rounds; r++) {
            const RoundResult* rr = &s->round_results[r];
            for (size_t c = 0; c < rr->cycle_count; c++) {
                pauses[pos++] = rr->cycles[c].pause_ns;
            }
        }

        if (total_cycles > 0) {
            qsort(pauses, total_cycles, sizeof(uint64_t), compare_u64);
        }

        double p50_ms = ns_to_ms(
            (uint64_t)percentile_ns_sorted(pauses, total_cycles, 0.50));
        double p95_ms = ns_to_ms(
            (uint64_t)percentile_ns_sorted(pauses, total_cycles, 0.95));
        double p99_ms = ns_to_ms(
            (uint64_t)percentile_ns_sorted(pauses, total_cycles, 0.99));

        double rounds_d = s->rounds > 0 ? (double)s->rounds : 1.0;
        printf("scenario: %s\n", s->name);
        printf("  workload:              %s\n", s->workload);
        printf("  total objects:         %zu\n", s->total_objects);
        printf("  avg alloc time:        %.3f ms\n", sum_alloc_ms / rounds_d);
        printf("  avg gc time:           %.3f ms\n", sum_gc_ms / rounds_d);
        printf("  avg all time:          %.3f ms\n", sum_all_ms / rounds_d);
        printf("  avg gc cycles:         %.2f\n", sum_cycles / rounds_d);
        printf("  peak candidates (max): %zu\n", peak_candidates_max);
        printf("  max pause:             %.3f ms\n", ns_to_ms(max_pause_ns));
        printf("  pause p50/p95/p99:     %.3f / %.3f / %.3f ms\n", p50_ms,
            p95_ms, p99_ms);
        printf("  avg throughput:               %.2f objects/ms\n",
            sum_throughput / rounds_d);
        printf("  avg suspect notifications:    %.2f\n",
            sum_suspect_notifications / rounds_d);
        printf("  avg generation_tracing:       %.2f\n",
            sum_generation_tracing / rounds_d);
        printf("  avg tracing_generations:      %.2f\n",
            sum_tracing_generations / rounds_d);
        printf("\n");

        printf("\033[1;32m=== GC Benchmarks Complete ===\033[0m\n\n");

        free(pauses);
    }
}

static RunConfig parse_args(int argc, char** argv)
{
    RunConfig cfg;
    cfg.output_mode = Output_SUMMARY;

    for (int i = 1; i < argc; i++) {
        const char* arg = argv[i];
        if (strcmp(arg, "--json") == 0) {
            cfg.output_mode = Output_JSON;
            continue;
        }
        if (strcmp(arg, "--csv") == 0) {
            cfg.output_mode = Output_CSV;
            continue;
        }
        if (strcmp(arg, "--summary") == 0) {
            cfg.output_mode = Output_SUMMARY;
            continue;
        }
        if (strcmp(arg, "--silent") == 0) {
            cfg.output_mode = Output_SILENT;
            continue;
        }
        fprintf(stderr,
            "usage: bench_gc [--json|--csv|--both] [--summary] [--silent]\n"
            "default output: --json\n");
        exit(2);
    }

    return cfg;
}

int main(int argc, char** argv)
{
    const size_t rounds         = 3;
    const size_t scenario_count = 3;
    RunConfig cfg               = parse_args(argc, argv);

    ScenarioResult scenarios[3];
    scenarios[0] = run_releasing_scenario(rounds);
    scenarios[1] = run_dropping_scenario(rounds);
    scenarios[2] = run_mixed_scenario(rounds);

    if (cfg.output_mode == Output_SILENT) {
        return 0;
    }

    if (cfg.output_mode == Output_SUMMARY) {
        print_summary_output(scenarios, scenario_count);
    } else if (cfg.output_mode == Output_JSON) {
        print_json_output(scenarios, scenario_count);
    } else if (cfg.output_mode == Output_CSV) {
        print_csv_output(scenarios, scenario_count);
    }

    for (size_t i = 0; i < scenario_count; i++) {
        destroy_scenario_result(&scenarios[i]);
    }

    return 0;
}
