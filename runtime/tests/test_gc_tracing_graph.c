#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "syli/gc_helpers.h"
#include "syli/header_object.h"
#include "syli/object.h"
#include "syli/syli.h"
#include "syli/syli_state.h"

static obj_ptr make_ref_object(size_t words, CyclicFlag cyclic)
{
    object_payload_t payload = syli_object_make_mono_payload(words);
    object_header_t header   = syli_object_make_header(
        Zone_GcLocal, cyclic, Type_MonoRef, Flag_HasPointers, payload);
    obj_ptr obj    = syli_rt_ownership_alloc_object(header, 1, words);
    Object* o      = syli_object_of_obj_ptr(obj);
    uint64_t* data = syli_object_data(o);
    for (size_t i = 0; i < words; i++)
        data[i] = 0;
    return obj;
}

static bool is_marked(obj_ptr p)
{
    return gc_is_object_mark_tagged(syli_object_of_obj_ptr(p));
}

static void run_tracing(obj_ptr root)
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

    obj_ptr root = make_ref_object(1, Cyclic);
    obj_ptr n1   = make_ref_object(1, Cyclic);
    obj_ptr n2   = make_ref_object(1, Cyclic);
    obj_ptr n3   = make_ref_object(1, Cyclic);
    obj_ptr n4   = make_ref_object(1, Cyclic);

    syli_object_data(syli_object_of_obj_ptr(root))[0] = (uint64_t)n1;
    syli_object_data(syli_object_of_obj_ptr(n1))[0]   = (uint64_t)n2;
    syli_object_data(syli_object_of_obj_ptr(n2))[0]   = (uint64_t)n3;
    syli_object_data(syli_object_of_obj_ptr(n3))[0]   = (uint64_t)n4;

    gc_tracing_worklist_push(root);

    run_tracing(root);

    assert(is_marked(root));
    assert(is_marked(n1));
    assert(is_marked(n2));
    assert(is_marked(n3));
    assert(is_marked(n4));

    syli_free_ptr(root);
    syli_free_ptr(n1);
    syli_free_ptr(n2);
    syli_free_ptr(n3);
    syli_free_ptr(n4);
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

    obj_ptr root = make_ref_object(2, Cyclic);
    obj_ptr n1   = make_ref_object(2, Cyclic);
    obj_ptr n2   = make_ref_object(2, Cyclic);
    obj_ptr n3   = make_ref_object(1, Cyclic);
    obj_ptr n4   = make_ref_object(1, Cyclic);
    obj_ptr n5   = make_ref_object(1, Cyclic);
    obj_ptr n6   = make_ref_object(1, Cyclic);

    syli_object_data(syli_object_of_obj_ptr(root))[0] = (uint64_t)n1;
    syli_object_data(syli_object_of_obj_ptr(root))[1] = (uint64_t)n2;
    syli_object_data(syli_object_of_obj_ptr(n1))[0]   = (uint64_t)n3;
    syli_object_data(syli_object_of_obj_ptr(n1))[1]   = (uint64_t)n4;
    syli_object_data(syli_object_of_obj_ptr(n2))[0]   = (uint64_t)n5;
    syli_object_data(syli_object_of_obj_ptr(n2))[1]   = (uint64_t)n6;

    gc_tracing_worklist_push(root);

    run_tracing(root);

    assert(is_marked(root));
    assert(is_marked(n1));
    assert(is_marked(n2));
    assert(is_marked(n3));
    assert(is_marked(n4));
    assert(is_marked(n5));
    assert(is_marked(n6));

    syli_free_ptr(root);
    syli_free_ptr(n1);
    syli_free_ptr(n2);
    syli_free_ptr(n3);
    syli_free_ptr(n4);
    syli_free_ptr(n5);
    syli_free_ptr(n6);
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

    obj_ptr root = make_ref_object(2, Cyclic);

    obj_ptr n1     = make_ref_object(2, Cyclic);
    obj_ptr n2     = make_ref_object(2, Cyclic);
    obj_ptr n3     = make_ref_object(2, Cyclic);
    obj_ptr n4     = make_ref_object(2, Cyclic);
    obj_ptr n5     = make_ref_object(2, Cyclic);
    obj_ptr n6     = make_ref_object(2, Cyclic);
    obj_ptr shared = make_ref_object(1, Cyclic);

    syli_object_data(syli_object_of_obj_ptr(root))[0] = (uint64_t)n1;
    syli_object_data(syli_object_of_obj_ptr(root))[1] = (uint64_t)n2;
    syli_object_data(syli_object_of_obj_ptr(n1))[0]   = (uint64_t)shared;
    syli_object_data(syli_object_of_obj_ptr(n2))[0]   = (uint64_t)shared;

    gc_tracing_worklist_push(root);

    run_tracing(root);

    assert(is_marked(root));
    assert(is_marked(n1));
    assert(is_marked(n2));
    assert(is_marked(shared));

    syli_free_ptr(root);
    syli_free_ptr(n1);
    syli_free_ptr(n2);
    syli_free_ptr(shared);
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

    obj_ptr root1  = make_ref_object(1, Cyclic);
    obj_ptr root2  = make_ref_object(1, Cyclic);
    obj_ptr n1     = make_ref_object(1, Cyclic);
    obj_ptr n2     = make_ref_object(1, Cyclic);
    obj_ptr shared = make_ref_object(1, Cyclic);

    syli_object_data(syli_object_of_obj_ptr(root1))[0] = (uint64_t)n1;
    syli_object_data(syli_object_of_obj_ptr(root2))[0] = (uint64_t)n2;
    syli_object_data(syli_object_of_obj_ptr(n1))[0]    = (uint64_t)shared;
    syli_object_data(syli_object_of_obj_ptr(n2))[0]    = (uint64_t)shared;

    gc_tracing_worklist_push(root1);
    gc_tracing_worklist_push(root2);

    // Add both roots as suspects
    gc_add_suspect(root1);
    gc_add_suspect(root2);
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = 0;
    syli_state.tracing_budget                = 1000;
    syli_state.checking_budget               = 1000;
    syli_state.tracing_state                 = Tracing_Idle;
    syli_state_gc_tracing();

    assert(is_marked(root1));
    assert(is_marked(root2));
    assert(is_marked(n1));
    assert(is_marked(n2));
    assert(is_marked(shared));

    syli_free_ptr(root1);
    syli_free_ptr(root2);
    syli_free_ptr(n1);
    syli_free_ptr(n2);
    syli_free_ptr(shared);
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

    obj_ptr root      = make_ref_object(1, Cyclic);
    obj_ptr n1        = make_ref_object(1, Cyclic);
    obj_ptr n2        = make_ref_object(1, Cyclic);
    obj_ptr isolated1 = make_ref_object(1, Cyclic);
    obj_ptr isolated2 = make_ref_object(1, Cyclic);

    syli_object_data(syli_object_of_obj_ptr(root))[0] = (uint64_t)n1;
    syli_object_data(syli_object_of_obj_ptr(n1))[0]   = (uint64_t)n2;
    syli_object_data(syli_object_of_obj_ptr(isolated1))[0]
        = (uint64_t)isolated2;

    gc_tracing_worklist_push(root);

    run_tracing(root);

    // Reachable nodes should be marked
    assert(is_marked(root));
    assert(is_marked(n1));
    assert(is_marked(n2));

    // Unreachable nodes should NOT be marked
    assert(!is_marked(isolated1));
    assert(!is_marked(isolated2));

    syli_free_ptr(root);
    syli_free_ptr(n1);
    syli_free_ptr(n2);
    syli_free_ptr(isolated1);
    syli_free_ptr(isolated2);
    syli_state_destroy();
    printf("✓ Disconnected components correctly handled\n\n");
}

int main(void)
{
    printf("\033[1;34m=== Graph Tracing Tests ===\033[0m\n\n");

    test_linear_chain_marking();
    test_binary_tree_marking();
    test_diamond_graph_marking();
    test_multiple_roots_shared_graph();
    test_disconnected_components();

    printf("\033[1;32m=== All 5 graph tracing tests passed! ===\033[0m\n");

    return 0;
}
