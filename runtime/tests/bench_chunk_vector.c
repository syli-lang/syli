#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

#include "syli/chunk_vector.h"

// Disable unused variable warnings for test functions
// Variables may appear unused in Release mode (assert compiled out with NDEBUG)
#pragma GCC diagnostic ignored "-Wunused-variable"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"

CHUNK_VECTOR_STRUCT(uintptr_t);
CHUNK_VECTOR_IMPLEMENT(uintptr_t);

#define N      1000000
#define ROUNDS 5

volatile uintptr_t global_sink = 0;

static uint64_t get_time_ns()
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + ts.tv_nsec;
}

int main()
{
    printf("\033[1;34m=== Vector Macro Benchmarks ===\033[0m\n");
    printf("Elements per round: %d, Rounds: %d\n\n", N, ROUNDS);

    uint64_t push_ns = 0, pop_ns = 0, interleaved_ns = 0;
    uint64_t peek_ns = 0, prealloc_ns = 0;

    vector_uintptr_t peek_v;
    vector_init_uintptr_t(&peek_v);
    for (int i = 0; i < N; i++) {
        uintptr_t value = (uintptr_t)i;
        vector_push_back_uintptr_t(&peek_v, &value);
    }

    for (int r = 0; r < ROUNDS; r++) {
        {
            vector_uintptr_t v;
            vector_init_uintptr_t(&v);

            uint64_t t0 = get_time_ns();
            for (int i = 0; i < N; i++) {
                uintptr_t value = (uintptr_t)i;
                vector_push_back_uintptr_t(&v, &value);
            }
            push_ns += get_time_ns() - t0;

            t0 = get_time_ns();
            for (int i = 0; i < N; i++) {
                uintptr_t* back = vector_back_uintptr_t(&v);
                global_sink = *back;
                vector_pop_back_uintptr_t(&v);
            }
            pop_ns += get_time_ns() - t0;

            vector_destroy_uintptr_t(&v);
        }

        {
            vector_uintptr_t v;
            vector_init_uintptr_t(&v);

            uint64_t t0 = get_time_ns();
            for (int i = 0; i < N; i++) {
                uintptr_t value = (uintptr_t)i;
                vector_push_back_uintptr_t(&v, &value);
                if (i % 32 == 31) {
                    for (int j = 0; j < 16; j++) {
                        uintptr_t* back = vector_back_uintptr_t(&v);
                        global_sink = *back;
                        vector_pop_back_uintptr_t(&v);
                    }
                }
            }
            while (!vector_empty_uintptr_t(&v)) {
                uintptr_t* back = vector_back_uintptr_t(&v);
                global_sink = *back;
                vector_pop_back_uintptr_t(&v);
            }
            interleaved_ns += get_time_ns() - t0;

            vector_destroy_uintptr_t(&v);
        }

        {
            uint64_t t0 = get_time_ns();
            for (int i = 0; i < N; i++) {
                uintptr_t* back = vector_back_uintptr_t(&peek_v);
                global_sink = *back;
            }
            peek_ns += get_time_ns() - t0;
        }

        {
            vector_uintptr_t v;
            vector_init_uintptr_t(&v);
            for (int i = 0; i < N; i++) {
                uintptr_t value = (uintptr_t)i;
                vector_push_back_uintptr_t(&v, &value);
            }
            vector_clear_uintptr_t(&v);

            uint64_t t0 = get_time_ns();
            for (int i = 0; i < N; i++) {
                uintptr_t value = (uintptr_t)i;
                vector_push_back_uintptr_t(&v, &value);
            }
            prealloc_ns += get_time_ns() - t0;

            vector_destroy_uintptr_t(&v);
        }

    }

    vector_destroy_uintptr_t(&peek_v);

    printf("\n  %-26s %10s %8s %10s\n",
        "Operation", "Time", "ns/op", "M ops/s");
    printf("  %s\n",
        "--------------------------------------------------");

#define PRINT_ROW(name, ns)                                                    \
    printf("  %-26s %8.2f ms %7.1f  %8.2f\n",                                 \
        name, ns / 1e6, ns / N, N / (ns / 1e3))

    PRINT_ROW("push", push_ns / (double)ROUNDS);
    PRINT_ROW("pop", pop_ns / (double)ROUNDS);
    PRINT_ROW("interleaved", interleaved_ns / (double)ROUNDS);
    PRINT_ROW("peek", peek_ns / (double)ROUNDS);
    PRINT_ROW("push (preallocated)", prealloc_ns / (double)ROUNDS);

#undef PRINT_ROW

    printf("\n\033[1;32m=== Done ===\033[0m\n\n");
    return 0;
}
