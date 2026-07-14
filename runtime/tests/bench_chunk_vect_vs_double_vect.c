#define _POSIX_C_SOURCE 200809L
#include "syli/chunk_vector.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define ROUNDS 5

typedef struct {
    void* obj;
    uint32_t in;
    uint32_t out;
} NodeCount;

CHUNK_VECTOR_STRUCT(NodeCount);
CHUNK_VECTOR_IMPLEMENT(NodeCount);

typedef struct {
    void* data;
    size_t capacity;
    size_t size;
    size_t element_size;
} DoublingArray;

static inline void doubling_array_init(DoublingArray* arr, size_t element_size)
{
    arr->capacity     = 16;
    arr->size         = 0;
    arr->element_size = element_size;
    arr->data         = malloc(arr->capacity * element_size);
}

static inline void doubling_array_destroy(DoublingArray* arr)
{
    free(arr->data);
    arr->data     = NULL;
    arr->capacity = 0;
    arr->size     = 0;
}

static inline void doubling_array_push_back(
    DoublingArray* arr, const void* value)
{
    if (arr->size >= arr->capacity) {
        arr->capacity *= 2;
        void* tmp = realloc(arr->data, arr->capacity * arr->element_size);
        if (!tmp) {
            fprintf(stderr, "realloc failed\n");
            exit(EXIT_FAILURE);
        }
        arr->data = tmp;
    }
    void* dest = (char*)arr->data + (arr->size * arr->element_size);
    memcpy(dest, value, arr->element_size);
    arr->size++;
}

static inline void* doubling_array_at(DoublingArray* arr, size_t index)
{
    return (char*)arr->data + (index * arr->element_size);
}

static inline void doubling_array_pop_back(DoublingArray* arr)
{
    if (arr->size > 0)
        arr->size--;
}

static inline size_t doubling_array_size(const DoublingArray* arr)
{
    return arr->size;
}

static uint64_t get_time_ns(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

int main(void)
{
    srand(42);
    volatile uint64_t sink = 0;

    size_t sizes[] = {10000, 100000, 1000000};

    printf("\033[1;34m=== ChunkVector vs DoublingArray ===\033[0m\n\n");

    for (int si = 0; si < 3; si++) {
        size_t N = sizes[si];

        NodeCount* data_da = (NodeCount*)malloc(N * sizeof(NodeCount));
        NodeCount* data_cv = (NodeCount*)malloc(N * sizeof(NodeCount));
        size_t* random_indices = (size_t*)malloc(N * sizeof(size_t));

        for (size_t i = 0; i < N; i++) {
            random_indices[i] = (size_t)(rand() % N);
            data_da[i] = (NodeCount){
                .obj = NULL, .in = (uint32_t)(i * 2), .out = (uint32_t)(i * 3 + 1) };
            data_cv[i] = (NodeCount){
                .obj = NULL, .in = (uint32_t)(i * 2), .out = (uint32_t)(i * 3 + 1) };
        }

        double da_push_ns = 0, cv_push_ns = 0;
        double da_linear_get_ns = 0, cv_linear_get_ns = 0;
        double da_random_get_ns = 0, cv_random_get_ns = 0;
        double da_linear_set_ns = 0, cv_linear_set_ns = 0;
        double da_random_set_ns = 0, cv_random_set_ns = 0;
        double da_pop_ns = 0, cv_pop_ns = 0;
        double da_overhead = 0, cv_overhead = 0;

        for (int r = 0; r < ROUNDS; r++) {
            DoublingArray da;
            doubling_array_init(&da, sizeof(NodeCount));

            uint64_t t1 = get_time_ns();
            for (size_t i = 0; i < N; i++)
                doubling_array_push_back(&da, &data_da[i]);
            uint64_t t2 = get_time_ns();
            da_push_ns += (double)(t2 - t1);

            uint64_t t3 = get_time_ns();
            for (size_t i = 0; i < N; i++) {
                volatile NodeCount* nc
                    = (volatile NodeCount*)doubling_array_at(&da, i);
                sink += nc->out;
            }
            uint64_t t4 = get_time_ns();
            da_linear_get_ns += (double)(t4 - t3);

            uint64_t t5 = get_time_ns();
            for (size_t i = 0; i < N; i++) {
                volatile NodeCount* nc
                    = (volatile NodeCount*)doubling_array_at(
                        &da, random_indices[i]);
                sink += nc->out;
            }
            uint64_t t6 = get_time_ns();
            da_random_get_ns += (double)(t6 - t5);

            uint64_t t7 = get_time_ns();
            for (size_t i = 0; i < N; i++) {
                volatile NodeCount* nc
                    = (volatile NodeCount*)doubling_array_at(&da, i);
                nc->out = data_da[i].out;
            }
            uint64_t t8 = get_time_ns();
            da_linear_set_ns += (double)(t8 - t7);

            uint64_t t8b = get_time_ns();
            for (size_t i = 0; i < N; i++) {
                volatile NodeCount* nc
                    = (volatile NodeCount*)doubling_array_at(
                        &da, random_indices[i]);
                nc->out = data_da[random_indices[i]].out;
            }
            uint64_t t8c = get_time_ns();
            da_random_set_ns += (double)(t8c - t8b);

            da_overhead += (double)da.capacity / da.size;

            uint64_t t9 = get_time_ns();
            for (size_t i = 0; i < N; i++)
                doubling_array_pop_back(&da);
            uint64_t t10 = get_time_ns();
            da_pop_ns += (double)(t10 - t9);

            doubling_array_destroy(&da);

            vector_NodeCount cv;
            vector_init_NodeCount(&cv);

            uint64_t u1 = get_time_ns();
            for (size_t i = 0; i < N; i++)
                vector_push_back_NodeCount(&cv, &data_cv[i]);
            uint64_t u2 = get_time_ns();
            cv_push_ns += (double)(u2 - u1);

            uint64_t u3 = get_time_ns();
            for (size_t i = 0; i < N; i++) {
                volatile NodeCount* nc
                    = (volatile NodeCount*)vector_at_NodeCount(&cv, i);
                sink += nc->out;
            }
            uint64_t u4 = get_time_ns();
            cv_linear_get_ns += (double)(u4 - u3);

            uint64_t u5 = get_time_ns();
            for (size_t i = 0; i < N; i++) {
                volatile NodeCount* nc
                    = (volatile NodeCount*)vector_at_NodeCount(
                        &cv, random_indices[i]);
                sink += nc->out;
            }
            uint64_t u6 = get_time_ns();
            cv_random_get_ns += (double)(u6 - u5);

            uint64_t u7 = get_time_ns();
            for (size_t i = 0; i < N; i++) {
                volatile NodeCount* nc
                    = (volatile NodeCount*)vector_at_NodeCount(&cv, i);
                nc->out = data_cv[i].out;
            }
            uint64_t u8 = get_time_ns();
            cv_linear_set_ns += (double)(u8 - u7);

            uint64_t u8b = get_time_ns();
            for (size_t i = 0; i < N; i++) {
                volatile NodeCount* nc
                    = (volatile NodeCount*)vector_at_NodeCount(
                        &cv, random_indices[i]);
                nc->out = data_cv[random_indices[i]].out;
            }
            uint64_t u8c = get_time_ns();
            cv_random_set_ns += (double)(u8c - u8b);

            uint64_t total_cap = 0;
            for (uint32_t ci = 0; ci < cv.chunk_count; ci++)
                total_cap += vector_chunk_capacity_NodeCount(ci);
            cv_overhead += (double)total_cap / vector_size_NodeCount(&cv);

            uint64_t u9 = get_time_ns();
            for (size_t i = 0; i < N; i++)
                vector_pop_back_NodeCount(&cv);
            uint64_t u10 = get_time_ns();
            cv_pop_ns += (double)(u10 - u9);

            vector_destroy_NodeCount(&cv);
        }

        printf("  N = %zu, Rounds = %d\n\n", N, ROUNDS);

        printf("  %-20s %13s %13s   %s\n",
            "Operation", "DoublingArray", "ChunkVector", "Diff");
        printf("  %s\n",
            "--------------------------------------------------------");

        double da_push_us = da_push_ns / ROUNDS / 1000.0;
        double cv_push_us = cv_push_ns / ROUNDS / 1000.0;
        double da_lin_get_us = da_linear_get_ns / ROUNDS / 1000.0;
        double cv_lin_get_us = cv_linear_get_ns / ROUNDS / 1000.0;
        double da_rand_get_us = da_random_get_ns / ROUNDS / 1000.0;
        double cv_rand_get_us = cv_random_get_ns / ROUNDS / 1000.0;
        double da_lin_set_us = da_linear_set_ns / ROUNDS / 1000.0;
        double cv_lin_set_us = cv_linear_set_ns / ROUNDS / 1000.0;
        double da_rand_set_us = da_random_set_ns / ROUNDS / 1000.0;
        double cv_rand_set_us = cv_random_set_ns / ROUNDS / 1000.0;
        double da_pop_us = da_pop_ns / ROUNDS / 1000.0;
        double cv_pop_us = cv_pop_ns / ROUNDS / 1000.0;

#define PRINT_ROW(op, da, cv)                                                  \
    printf("  %-20s %10.2f us %10.2f us   %+.1f%%\n",                         \
        op, da, cv, da > 0 ? (cv - da) / da * 100.0 : 0.0)

        PRINT_ROW("Push", da_push_us, cv_push_us);
        PRINT_ROW("Linear get", da_lin_get_us, cv_lin_get_us);
        PRINT_ROW("Random get", da_rand_get_us, cv_rand_get_us);
        PRINT_ROW("Linear set", da_lin_set_us, cv_lin_set_us);
        PRINT_ROW("Random set", da_rand_set_us, cv_rand_set_us);
        PRINT_ROW("Pop", da_pop_us, cv_pop_us);

        printf("\n");
        printf("  %-20s %6.2fx %6.2fx\n", "Memory overhead",
            da_overhead / ROUNDS, cv_overhead / ROUNDS);

        printf("\n");

        free(data_da);
        free(data_cv);
        free(random_indices);
    }

    printf("\033[1;32m=== Complete ===\033[0m\n\n");

    (void)sink;
    return 0;
}
