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
#include "syli/syli.h"
#include "syli/syli_state.h"

static uint64_t time_diff_ns(
    const struct timespec* start, const struct timespec* end)
{
    return (uint64_t)(end->tv_sec - start->tv_sec) * 1000000000ULL
        + (uint64_t)(end->tv_nsec - start->tv_nsec);
}

static obj_ptr make_ref_object(size_t words, CyclicFlag cyclic)
{
    object_payload_t payload = syli_object_make_mono_payload(words);
    object_header_t header   = syli_object_make_header(
        Zone_GcLocal, cyclic, Type_MonoRef, Flag_HasPointers, payload);
    obj_ptr obj = syli_rt_ownership_alloc_object(header, 1, words);
    Object* o   = syli_object_of_obj_ptr(obj);
    memset(syli_object_data(o), 0, words * sizeof(uint64_t));
    return obj;
}

/* Returns true when all GC queues are drained and state machines are idle. */
static bool gc_is_done(void)
{
    return vector_size_obj_ptr(&syli_state.releasing_waitlist) == 0
        && vector_size_obj_ptr(&syli_state.releasing_worklist) == 0
        && vector_size_obj_ptr(&syli_state.tracing_worklist) == 0
        && vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 0
        && syli_state.tracing_state == Tracing_Idle
        && syli_state.releasing_state == Releasing_Idle;
}

/* ──────────────────────────────────────────────────────────────
   run_profile — mixed workload benchmark.

    short_lived_count: leaf objects released immediately (short-lived).
   long_lived_count:  cyclic root+child pairs kept live (long-lived);
                     added as suspects to exercise cycle detection.

   Measures allocation time separately from GC drain time, then
   reports all 6 metrics: alloc time, gc time, gc cycles,
   peak candidates, max pause, throughput.
   ────────────────────────────────────────────────────────────── */
static void run_profile(
    const char* label, size_t short_lived_count, size_t long_lived_count)
{
    const int N_ROUNDS   = 10;
    size_t total_objects = short_lived_count + long_lived_count * 2;

    uint64_t total_alloc_ns = 0, total_gc_ns = 0;
    uint64_t max_pause_ns = 0;
    size_t total_cycles = 0, peak_candidates = 0;

    for (int round = 0; round < N_ROUNDS; round++) {
        syli_state_init();
        syli_state.THRESHOLD_RELEASING_BUCKET    = 1;
        syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = 0;

        /* Allocation phase */
        struct timespec t0, t1;
        clock_gettime(CLOCK_MONOTONIC, &t0);

        obj_ptr* root_slots
            = (obj_ptr*)malloc(long_lived_count * sizeof(obj_ptr));
        obj_ptr* children
            = (obj_ptr*)malloc(long_lived_count * sizeof(obj_ptr));

        for (size_t i = 0; i < long_lived_count; i++) {
            root_slots[i] = make_ref_object(1, Cyclic);
            children[i]   = make_ref_object(1, Cyclic);
            syli_object_data(syli_object_of_obj_ptr(root_slots[i]))[0]
                = (uint64_t)children[i];
            gc_tracing_worklist_push(root_slots[i]);
        }

        /* Short-lived leaf objects pushed to releasing waitlist */
        for (size_t i = 0; i < short_lived_count; i++) {
            obj_ptr obj = make_ref_object(0, Acyclic);
            syli_rt_ownership_release(obj);
        }

        /* Mark long-lived roots as cycle suspects */
        for (size_t i = 0; i < long_lived_count; i++) {
            gc_add_suspect(root_slots[i]);
        }

        clock_gettime(CLOCK_MONOTONIC, &t1);
        total_alloc_ns += time_diff_ns(&t0, &t1);

        /* GC drain loop — runs until all queues empty */
        while (!gc_is_done()) {
            size_t cands
                = vector_size_Suspected(&syli_state.suspect_lost_cycle);
            if (cands > peak_candidates)
                peak_candidates = cands;

            struct timespec cs, ce;
            clock_gettime(CLOCK_MONOTONIC, &cs);
            syli_state_gc_cycle();
            clock_gettime(CLOCK_MONOTONIC, &ce);

            uint64_t ns = time_diff_ns(&cs, &ce);
            total_gc_ns += ns;
            if (ns > max_pause_ns)
                max_pause_ns = ns;
            total_cycles++;
        }

        for (size_t i = 0; i < long_lived_count; i++) {
            syli_free_ptr(root_slots[i]);
            syli_free_ptr(children[i]);
        }
        free(children);
        free(root_slots);
        syli_state_destroy();
    }

    double avg_alloc_ms = (total_alloc_ns / (double)N_ROUNDS) / 1e6;
    double avg_gc_ms    = (total_gc_ns / (double)N_ROUNDS) / 1e6;
    size_t avg_cycles   = total_cycles / (size_t)N_ROUNDS;

    printf("  %s\n", label);
    printf("    short-lived(releasing):  %zu\n", short_lived_count);
    printf("    long-lived(trace roots): %zu\n", long_lived_count);
    printf("    total objects:           %zu\n", total_objects);
    printf("    alloc time:              %.3f ms\n", avg_alloc_ms);
    printf("    gc time:                 %.3f ms\n", avg_gc_ms);
    printf("    gc cycles:               %zu\n", avg_cycles);
    printf("    peak candidates:         %zu\n", peak_candidates);
    printf("    max pause:               %.3f ms\n", max_pause_ns / 1e6);
    printf("    throughput:              %.2f objects/ms\n",
        avg_gc_ms > 0.0 ? (double)total_objects / avg_gc_ms : 0.0);
}

int main(void)
{

    printf("\033[1;34m=== Workload Profile Benchmarks ===\033[0m\n");

    run_profile("Profile 1 (95/5)", 95000, 2500);
    run_profile("Profile 2 (80/20)", 80000, 10000);
    run_profile("Profile 3 (50/50)", 50000, 25000);

    printf(
        "\n\033[1;32m=== Workload Profile Benchmarks Complete ===\033[0m\n\n");
    return 0;
}
