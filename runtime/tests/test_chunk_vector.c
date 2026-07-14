#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "syli/chunk_vector.h"

// Disable unused variable warnings for test functions
// Variables may appear unused in Release mode (assert compiled out with NDEBUG)
#pragma GCC diagnostic ignored "-Wunused-variable"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"

#define UINT32_MAX (4294967295U)

// The NodeCount type used across tests
typedef struct NodeCount {
    void* obj;
    uint32_t in;
    uint32_t out;
} NodeCount;

// Define vector_NodeCount struct and implementation
CHUNK_VECTOR_STRUCT(NodeCount);
CHUNK_VECTOR_IMPLEMENT(NodeCount);

void test_basic_operations()
{
    printf("  basic operations...\n");

    vector_NodeCount cv;
    vector_init_NodeCount(&cv);
    assert(vector_size_NodeCount(&cv) == 0);

    // Push elements
    NodeCount nc1 = { .obj = NULL, .in = 1, .out = 42 };
    vector_push_back_NodeCount(&cv, &nc1);
    assert(vector_size_NodeCount(&cv) == 1);
    assert(vector_at_NodeCount(&cv, 0)->out == 42);

    NodeCount nc2 = { .obj = NULL, .in = 2, .out = 100 };
    vector_push_back_NodeCount(&cv, &nc2);
    NodeCount nc3 = { .obj = NULL, .in = 3, .out = 200 };
    vector_push_back_NodeCount(&cv, &nc3);
    assert(vector_size_NodeCount(&cv) == 3);
    assert(vector_at_NodeCount(&cv, 1)->out == 100);
    assert(vector_at_NodeCount(&cv, 2)->out == 200);

    // Modify elements
    vector_at_NodeCount(&cv, 1)->out = 150;
    assert(vector_at_NodeCount(&cv, 1)->out == 150);

    // Pop elements
    assert(vector_back_NodeCount(&cv)->out == 200);
    vector_pop_back_NodeCount(&cv);
    assert(vector_size_NodeCount(&cv) == 2);

    assert(vector_back_NodeCount(&cv)->out == 150);
    vector_pop_back_NodeCount(&cv);
    assert(vector_size_NodeCount(&cv) == 1);

    assert(vector_back_NodeCount(&cv)->out == 42);
    vector_pop_back_NodeCount(&cv);
    assert(vector_size_NodeCount(&cv) == 0);

    vector_destroy_NodeCount(&cv);
}

void test_chunk_growth()
{
    printf("  chunk growth...\n");

    vector_NodeCount cv;
    vector_init_NodeCount(&cv);

    // Push enough to trigger multiple chunks
    const int num_elements = 10000;
    for (int i = 0; i < num_elements; ++i) {
        NodeCount nc = { .obj = NULL, .in = (uint32_t)i, .out = (uint32_t)i };
        vector_push_back_NodeCount(&cv, &nc);
    }
    assert(vector_size_NodeCount(&cv) == (uint64_t)num_elements);

    // Verify all elements
    for (int i = 0; i < num_elements; ++i) {
        assert(vector_at_NodeCount(&cv, i)->out == (uint32_t)i);
    }

    // Pop all
    for (int i = num_elements - 1; i >= 0; --i) {
        assert(vector_back_NodeCount(&cv)->out == (uint32_t)i);
        vector_pop_back_NodeCount(&cv);
    }
    assert(vector_size_NodeCount(&cv) == 0);

    vector_destroy_NodeCount(&cv);
}

void test_edge_cases()
{
    printf("  edge cases...\n");

    vector_NodeCount cv;
    vector_init_NodeCount(&cv);

    // Empty vector
    assert(vector_size_NodeCount(&cv) == 0);
    assert(vector_empty_NodeCount(&cv) == true);

    // Push and pop single element
    NodeCount nc = { .obj = NULL, .in = 1, .out = 999 };
    vector_push_back_NodeCount(&cv, &nc);
    assert(vector_size_NodeCount(&cv) == 1);
    assert(vector_at_NodeCount(&cv, 0)->out == 999);
    assert(vector_back_NodeCount(&cv)->out == 999);
    assert(vector_empty_NodeCount(&cv) == false);
    vector_pop_back_NodeCount(&cv);
    assert(vector_size_NodeCount(&cv) == 0);
    assert(vector_empty_NodeCount(&cv) == true);

    // Large values
    NodeCount nc1 = { .obj = NULL, .in = UINT32_MAX, .out = 0 };
    vector_push_back_NodeCount(&cv, &nc1);
    NodeCount nc2 = { .obj = NULL, .in = 0, .out = UINT32_MAX };
    vector_push_back_NodeCount(&cv, &nc2);
    assert(vector_at_NodeCount(&cv, 0)->in == UINT32_MAX);
    assert(vector_at_NodeCount(&cv, 1)->out == UINT32_MAX);

    assert(vector_back_NodeCount(&cv)->out == UINT32_MAX);
    vector_pop_back_NodeCount(&cv);
    assert(vector_back_NodeCount(&cv)->in == UINT32_MAX);
    vector_pop_back_NodeCount(&cv);
    assert(vector_size_NodeCount(&cv) == 0);

    vector_destroy_NodeCount(&cv);
}

void test_random_access()
{
    printf("  random access...\n");

    vector_NodeCount cv;
    vector_init_NodeCount(&cv);

    const int num_elements = 1000;
    for (int i = 0; i < num_elements; ++i) {
        NodeCount nc
            = { .obj = NULL, .in = (uint32_t)i, .out = (uint32_t)(i * 7) };
        vector_push_back_NodeCount(&cv, &nc);
    }
    assert(vector_size_NodeCount(&cv) == (uint64_t)num_elements);

    // Access and verify
    for (int i = 0; i < num_elements; ++i) {
        assert(vector_at_NodeCount(&cv, i)->out == (uint32_t)(i * 7));
    }

    // Modify via direct access
    for (int i = 0; i < num_elements; i += 2) {
        uint32_t new_val = (uint32_t)(i * 7) + 1000;
        vector_at_NodeCount(&cv, i)->out = new_val;
    }

    // Verify modifications
    for (int i = 0; i < num_elements; ++i) {
        assert(vector_at_NodeCount(&cv, i)->out
            == ((i % 2 == 0) ? (uint32_t)(i * 7) + 1000 : (uint32_t)(i * 7)));
    }

    vector_destroy_NodeCount(&cv);
}

void test_clear()
{
    printf("  clear...\n");

    vector_NodeCount cv;
    vector_init_NodeCount(&cv);

    // Push some elements
    for (int i = 0; i < 1000; ++i) {
        NodeCount nc = { .obj = NULL, .in = (uint32_t)i, .out = (uint32_t)i };
        vector_push_back_NodeCount(&cv, &nc);
    }
    assert(vector_size_NodeCount(&cv) == 1000);
    assert(vector_empty_NodeCount(&cv) == false);

    // Clear
    vector_clear_NodeCount(&cv);
    assert(vector_size_NodeCount(&cv) == 0);
    assert(vector_empty_NodeCount(&cv) == true);

    // Push again after clear
    NodeCount nc = { .obj = NULL, .in = 1, .out = 42 };
    vector_push_back_NodeCount(&cv, &nc);
    assert(vector_size_NodeCount(&cv) == 1);
    assert(vector_at_NodeCount(&cv, 0)->out == 42);
    assert(vector_back_NodeCount(&cv)->out == 42);

    vector_destroy_NodeCount(&cv);
}

int main()
{
    printf("\033[1;34m=== Running ChunkVector Macro Tests ===\033[0m\n");

    test_basic_operations();
    test_chunk_growth();
    test_edge_cases();
    test_random_access();
    test_clear();

    printf("\033[1;32m=== All ChunkVector Macro Tests Passed! ===\033[0m\n\n");
    return 0;
}
