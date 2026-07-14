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

static uint64_t time_diff_ns(
    const struct timespec* start, const struct timespec* end)
{
    return (uint64_t)(end->tv_sec - start->tv_sec) * 1000000000ULL
        + (uint64_t)(end->tv_nsec - start->tv_nsec);
}

static Object* make_ref_object(size_t words)
{
    object_payload_t payload = syli_object_make_mono_payload(words);
    object_header_t header   = syli_object_make_header(
        Zone_GcLocal, Cyclic, Type_MonoRef, Flag_HasPointers, payload);
    uint64_t meta = make_meta_refcount(
        Meta_Flags_None, (ObjectMetaFlags)syli_state.tracing_current_bit_mark);
    Object* obj = syli_object_alloc(header, meta, words);
    memset(syli_object_data(obj), 0, words * sizeof(uint64_t));
    return obj;
}

/* Returns true once the tracing GC has fully processed all suspects. */
static bool tracing_done(void)
{
    return syli_state.suspect_objects_notifications == 0
        && vector_size_GCObject(&syli_state.tracing_worklist) == 0
        && vector_size_GCObject(&syli_state.tracing_mutations_worklist) == 0
        && syli_state.tracing_state == Tracing_Idle
        && syli_state.releasing_state == Releasing_Idle
        && syli_state.dropping_state == Dropping_Idle;
}

/* ──────────────────────────────────────────────────────────────
   run_tracing_bench — generic tracing drain for one graph shape.

   root_slot: pointer to the root object pointer (frame root).
   node_count: total number of graph nodes (for throughput).
   label: section header printed to stdout.

   Allocates the graph externally; this function only handles
   the suspend→add_suspect→gc_drain loop + metric reporting.
   ────────────────────────────────────────────────────────────── */
static void run_tracing_bench(
    const char* label, Object** root_slot, size_t node_count, int N_ROUNDS,
    uint64_t alloc_ns)
{
    uint64_t total_gc_ns  = 0;
    uint64_t max_pause_ns = 0;
    size_t total_cycles = 0, peak_candidates = 0;

    for (int round = 0; round < N_ROUNDS; round++) {
        /* Reset tracing state for each round without reallocating the graph.
           Only the tracing-related fields need to be cleared. */
        syli_state.tracing_state                 = Tracing_Idle;
        syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = 0;
        syli_state.THRESHOLD_RELEASING_BUCKET    = 1;
        syli_state.THRESHOLD_DROPPING_BUCKET     = 1;

        Object** frame_roots[] = { root_slot };
        Frame frame            = { .root_count = 1, .roots = frame_roots };
        syli_state_push_frame_scope(&frame);

        gc_add_suspect(*root_slot);

        /* GC drain loop */
        while (!tracing_done()) {
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

        syli_state_pop_frame_scope();
    }

    double avg_gc_ms  = (total_gc_ns / (double)N_ROUNDS) / 1e6;
    size_t avg_cycles = total_cycles / (size_t)N_ROUNDS;

    printf("%s\n", label);
    printf("  nodes:              %zu\n", node_count);
    printf("  alloc time:         %.3f ms\n", alloc_ns / 1e6);
    printf("  gc time:            %.3f ms\n", avg_gc_ms);
    printf("  gc cycles:          %zu\n", avg_cycles);
    printf("  peak candidates:    %zu\n", peak_candidates);
    printf("  max pause:          %.3f ms\n", max_pause_ns / 1e6);
    printf("  throughput:         %.2f objects/ms\n",
        avg_gc_ms > 0.0 ? (double)node_count / avg_gc_ms : 0.0);
}

/* ──────────────────────────────────────────────────────────────
   Tracing Bench 1: Linear Chain
   head → n1 → n2 → … → tail  (10 000 nodes)
   ────────────────────────────────────────────────────────────── */
static void bench_linear_chain(void)
{
    const uint32_t n   = 100000;
    const int N_ROUNDS = 20;

    syli_state_init();

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    Object** nodes = (Object**)malloc(n * sizeof(Object*));
    for (uint32_t i = 0; i < n; i++)
        nodes[i] = make_ref_object(1);
    for (uint32_t i = 0; i + 1 < n; i++)
        syli_object_data(nodes[i])[0] = (uint64_t)nodes[i + 1];

    clock_gettime(CLOCK_MONOTONIC, &t1);
    uint64_t alloc_ns = time_diff_ns(&t0, &t1);

    Object* root_slot = nodes[0];
    run_tracing_bench(
        "\n=== Tracing Bench 1: Linear Chain ===", &root_slot, n, N_ROUNDS,
        alloc_ns);

    for (uint32_t i = 0; i < n; i++)
        free(nodes[i]);
    free(nodes);
    syli_state_destroy();
}

/* ──────────────────────────────────────────────────────────────
   Tracing Bench 2: Binary Tree
   Full binary tree of depth 12 (4 095 nodes)
   ────────────────────────────────────────────────────────────── */
static void bench_binary_tree(void)
{
    const uint32_t depth      = 16;
    const uint32_t node_count = (1u << depth) - 1;
    const int N_ROUNDS        = 20;

    syli_state_init();

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    Object** nodes = (Object**)malloc(node_count * sizeof(Object*));
    for (uint32_t i = 0; i < node_count; i++)
        nodes[i] = make_ref_object(2);
    for (uint32_t i = 0; i < node_count; i++) {
        uint32_t left = 2 * i + 1, right = 2 * i + 2;
        if (left < node_count)
            syli_object_data(nodes[i])[0] = (uint64_t)nodes[left];
        if (right < node_count)
            syli_object_data(nodes[i])[1] = (uint64_t)nodes[right];
    }

    clock_gettime(CLOCK_MONOTONIC, &t1);
    uint64_t alloc_ns = time_diff_ns(&t0, &t1);

    Object* root_slot = nodes[0];
    run_tracing_bench("\n=== Tracing Bench 2: Binary Tree ===", &root_slot,
        node_count, N_ROUNDS, alloc_ns);

    for (uint32_t i = 0; i < node_count; i++)
        free(nodes[i]);
    free(nodes);
    syli_state_destroy();
}

/* ──────────────────────────────────────────────────────────────
   Tracing Bench 3: Diamond Shared DAG
   root → (left[i], right[i]) → shared   for i in [0, diamonds)
   20 000 diamonds; each diamond shares one node (refcount = 40 000).
   ────────────────────────────────────────────────────────────── */
static void bench_diamond_shared(void)
{
    const uint32_t diamonds    = 100000;
    const int N_ROUNDS         = 20;
    const uint64_t total_nodes = 1 + (uint64_t)diamonds * 2 + 1;

    syli_state_init();

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    Object* root   = make_ref_object(diamonds * 2);
    Object* shared = make_ref_object(1);
    Object** left  = (Object**)malloc(diamonds * sizeof(Object*));
    Object** right = (Object**)malloc(diamonds * sizeof(Object*));

    for (uint32_t i = 0; i < diamonds; i++) {
        left[i]                           = make_ref_object(1);
        right[i]                          = make_ref_object(1);
        syli_object_data(root)[2 * i]     = (uint64_t)left[i];
        syli_object_data(root)[2 * i + 1] = (uint64_t)right[i];
        syli_object_data(left[i])[0]      = (uint64_t)shared;
        syli_object_data(right[i])[0]     = (uint64_t)shared;
    }

    clock_gettime(CLOCK_MONOTONIC, &t1);
    uint64_t alloc_ns = time_diff_ns(&t0, &t1);

    Object* root_slot = root;
    run_tracing_bench("\n=== Tracing Bench 3: Diamond Shared DAG ===",
        &root_slot, (size_t)total_nodes, N_ROUNDS, alloc_ns);

    for (uint32_t i = 0; i < diamonds; i++) {
        free(left[i]);
        free(right[i]);
    }
    free(left);
    free(right);
    free(shared);
    free(root);
    syli_state_destroy();
}

int main(void)
{
    printf("\033[1;34m=== Tracing Graph Benchmarks (Current Runtime) "
           "===\033[0m\n");
    bench_linear_chain();
    bench_binary_tree();
    bench_diamond_shared();
    printf("\n\033[1;32m=== Tracing Graph Benchmarks Complete ===\033[0m\n");
    return 0;
}
