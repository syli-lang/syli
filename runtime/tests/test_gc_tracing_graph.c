#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "syli/gc_helpers.h"
#include "syli/header_object.h"
#include "syli/object.h"
#include "syli/syli_state.h"

static Object* make_ref_object(size_t words, CyclicFlag cyclic)
{
    object_payload_t payload = syli_object_make_mono_payload(words);
    object_header_t header   = syli_object_make_header(
        Zone_GcLocal, cyclic, Type_MonoRef, Flag_HasPointers, payload);
    uint64_t meta = make_meta_refcount(
        Meta_Flags_None, syli_state.tracing_current_bit_mark);
    Object* obj    = syli_object_alloc(header, meta, words);
    uint64_t* data = syli_object_data(obj);
    for (size_t i = 0; i < words; i++)
        data[i] = 0;
    return obj;
}

static void run_tracing(Object* root)
{
    gc_add_suspect(root);
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = 0;
    syli_state.tracing_budget                = 1000;
    syli_state.checking_budget               = 1000;
    syli_state.tracing_state                 = Tracing_Idle;
    syli_state_gc_tracing();
}

// Test 1: Linear chain graph (root -> n1 -> n2 -> n3 -> n4)
static void test_linear_chain_marking(void)
{
    printf("Test 1: Linear chain graph marking\n");

    syli_state_init();

    Object* root = make_ref_object(1, Cyclic);
    Object* n1   = make_ref_object(1, Cyclic);
    Object* n2   = make_ref_object(1, Cyclic);
    Object* n3   = make_ref_object(1, Cyclic);
    Object* n4   = make_ref_object(1, Cyclic);

    syli_object_data(root)[0] = (uint64_t)n1;
    syli_object_data(n1)[0]   = (uint64_t)n2;
    syli_object_data(n2)[0]   = (uint64_t)n3;
    syli_object_data(n3)[0]   = (uint64_t)n4;

    Object** roots[] = { &root };
    Frame frame      = { .root_count = 1, .roots = roots };
    syli_state_push_frame_scope(&frame);

    run_tracing(root);

    assert(gc_is_object_mark_tagged(root));
    assert(gc_is_object_mark_tagged(n1));
    assert(gc_is_object_mark_tagged(n2));
    assert(gc_is_object_mark_tagged(n3));
    assert(gc_is_object_mark_tagged(n4));

    syli_state_pop_frame_scope();
    free(root);
    free(n1);
    free(n2);
    free(n3);
    free(n4);
    syli_state_destroy();
    printf("✓ Linear chain marking works\n\n");
}

/*
// Test 2: Binary tree graph
//       root
//      /    \
//    n1      n2
//   /  \    /  \
//  n3  n4  n5  n6
*/
static void test_binary_tree_marking(void)
{
    printf("Test 2: Binary tree graph marking\n");

    syli_state_init();

    Object* root = make_ref_object(2, Cyclic);
    Object* n1   = make_ref_object(2, Cyclic);
    Object* n2   = make_ref_object(2, Cyclic);
    Object* n3   = make_ref_object(1, Cyclic);
    Object* n4   = make_ref_object(1, Cyclic);
    Object* n5   = make_ref_object(1, Cyclic);
    Object* n6   = make_ref_object(1, Cyclic);

    syli_object_data(root)[0] = (uint64_t)n1;
    syli_object_data(root)[1] = (uint64_t)n2;
    syli_object_data(n1)[0]   = (uint64_t)n3;
    syli_object_data(n1)[1]   = (uint64_t)n4;
    syli_object_data(n2)[0]   = (uint64_t)n5;
    syli_object_data(n2)[1]   = (uint64_t)n6;

    Object** roots[] = { &root };
    Frame frame      = { .root_count = 1, .roots = roots };
    syli_state_push_frame_scope(&frame);

    run_tracing(root);

    assert(gc_is_object_mark_tagged(root));
    assert(gc_is_object_mark_tagged(n1));
    assert(gc_is_object_mark_tagged(n2));
    assert(gc_is_object_mark_tagged(n3));
    assert(gc_is_object_mark_tagged(n4));
    assert(gc_is_object_mark_tagged(n5));
    assert(gc_is_object_mark_tagged(n6));

    syli_state_pop_frame_scope();
    free(root);
    free(n1);
    free(n2);
    free(n3);
    free(n4);
    free(n5);
    free(n6);
    syli_state_destroy();
    printf("✓ Binary tree marking works\n\n");
}

/*
// Test 3: Diamond graph (shared node)
//      root
//      /  \
//    n1    n2
//      \  /
//      shared
*/
static void test_diamond_graph_marking(void)
{
    printf("Test 3: Diamond graph marking\n");

    syli_state_init();

    Object* root   = make_ref_object(2, Cyclic);
    Object* n1     = make_ref_object(1, Cyclic);
    Object* n2     = make_ref_object(1, Cyclic);
    Object* shared = make_ref_object(1, Cyclic);

    syli_object_data(root)[0] = (uint64_t)n1;
    syli_object_data(root)[1] = (uint64_t)n2;
    syli_object_data(n1)[0]   = (uint64_t)shared;
    syli_object_data(n2)[0]   = (uint64_t)shared;

    Object** roots[] = { &root };
    Frame frame      = { .root_count = 1, .roots = roots };
    syli_state_push_frame_scope(&frame);

    run_tracing(root);

    assert(gc_is_object_mark_tagged(root));
    assert(gc_is_object_mark_tagged(n1));
    assert(gc_is_object_mark_tagged(n2));
    assert(gc_is_object_mark_tagged(shared));

    syli_state_pop_frame_scope();
    free(root);
    free(n1);
    free(n2);
    free(shared);
    syli_state_destroy();
    printf("✓ Diamond graph marking works\n\n");
}
/*
// Test 4: Multiple roots with shared subgraph
//   root1 -> n1 -> shared
//   root2 -> n2 -> shared
*/
static void test_multiple_roots_shared_graph(void)
{
    printf("Test 4: Multiple roots with shared subgraph\n");

    syli_state_init();

    Object* root1  = make_ref_object(1, Cyclic);
    Object* root2  = make_ref_object(1, Cyclic);
    Object* n1     = make_ref_object(1, Cyclic);
    Object* n2     = make_ref_object(1, Cyclic);
    Object* shared = make_ref_object(1, Cyclic);

    syli_object_data(root1)[0] = (uint64_t)n1;
    syli_object_data(root2)[0] = (uint64_t)n2;
    syli_object_data(n1)[0]    = (uint64_t)shared;
    syli_object_data(n2)[0]    = (uint64_t)shared;

    Object** roots[] = { &root1, &root2 };
    Frame frame      = { .root_count = 2, .roots = roots };
    syli_state_push_frame_scope(&frame);

    // Add both roots as suspects
    gc_add_suspect(root1);
    gc_add_suspect(root2);
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = 0;
    syli_state.tracing_budget                = 1000;
    syli_state.checking_budget               = 1000;
    syli_state.tracing_state                 = Tracing_Idle;
    syli_state_gc_tracing();

    assert(gc_is_object_mark_tagged(root1));
    assert(gc_is_object_mark_tagged(root2));
    assert(gc_is_object_mark_tagged(n1));
    assert(gc_is_object_mark_tagged(n2));
    assert(gc_is_object_mark_tagged(shared));

    syli_state_pop_frame_scope();
    free(root1);
    free(root2);
    free(n1);
    free(n2);
    free(shared);
    syli_state_destroy();
    printf("✓ Multiple roots with shared graph works\n\n");
}

/*
// Test 5: Disconnected components (unreachable nodes)
// Reachable:   root -> n1 -> n2
// Unreachable: isolated1 -> isolated2
*/
static void test_disconnected_components(void)
{
    printf("Test 5: Disconnected components (unreachable nodes)\n");

    syli_state_init();

    Object* root      = make_ref_object(1, Cyclic);
    Object* n1        = make_ref_object(1, Cyclic);
    Object* n2        = make_ref_object(1, Cyclic);
    Object* isolated1 = make_ref_object(1, Cyclic);
    Object* isolated2 = make_ref_object(1, Cyclic);

    syli_object_data(root)[0]      = (uint64_t)n1;
    syli_object_data(n1)[0]        = (uint64_t)n2;
    syli_object_data(isolated1)[0] = (uint64_t)isolated2;

    Object** roots[] = { &root };
    Frame frame      = { .root_count = 1, .roots = roots };
    syli_state_push_frame_scope(&frame);

    run_tracing(root);

    // Reachable nodes should be marked
    assert(gc_is_object_mark_tagged(root));
    assert(gc_is_object_mark_tagged(n1));
    assert(gc_is_object_mark_tagged(n2));

    // Unreachable nodes should NOT be marked
    assert(!gc_is_object_mark_tagged(isolated1));
    assert(!gc_is_object_mark_tagged(isolated2));

    syli_state_pop_frame_scope();
    free(root);
    free(n1);
    free(n2);
    free(isolated1);
    free(isolated2);
    syli_state_destroy();
    printf("✓ Disconnected components correctly handled\n\n");
}

int main(void)
{
    printf("\033[1;34m=== Graph Marking Tests ===\033[0m\n\n");

    test_linear_chain_marking();
    test_binary_tree_marking();
    test_diamond_graph_marking();
    test_multiple_roots_shared_graph();
    test_disconnected_components();

    printf("\033[1;32m=== All 5 graph marking tests passed! ===\033[0m\n");

    return 0;
}
