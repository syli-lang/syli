#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "syli/config.h"
#include "syli/gc_helpers.h"
#include "syli/object.h"
#include "syli/stack_frame.h"
#include "syli/syli_state.h"

#pragma GCC diagnostic ignored "-Wunused-but-set-variable"

void test_state_init()
{
    printf("Test 1: syli_state_init()\n");

    syli_state_init();

    // Check thresholds
    assert(syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE == 1000);
    assert(syli_state.THRESHOLD_RELEASING_BUCKET == 1000);
    assert(syli_state.THRESHOLD_DROPPING_BUCKET == 1000);
    assert(syli_state.FULL_BUCKET_SUSPECT_LOST_CYCLE == 10000);

    // Check budgets
    assert(syli_state.BUDGET_GC_TRACING == 2 * BUDGET_BATCH_SIZE);
    assert(syli_state.BUDGET_GC_RELEASING == 5 * BUDGET_BATCH_SIZE);
    assert(syli_state.BUDGET_GC_DROPPING == 5 * BUDGET_BATCH_SIZE);
    assert(syli_state.BUDGET_GC_CHECKING == 3 * BUDGET_BATCH_SIZE);

    // Check budget counters start at 0
    assert(syli_state.tracing_budget == 0);
    assert(syli_state.releasing_budget == 0);
    assert(syli_state.dropping_budget == 0);
    assert(syli_state.checking_budget == 0);

    // Check GC worklists are initialized (empty)
    assert(vector_size_GCObject(&syli_state.tracing_worklist) == 0);
    assert(vector_empty_GCObject(&syli_state.tracing_worklist) == true);
    assert(vector_size_GCObject(&syli_state.tracing_mutations_worklist) == 0);
    assert(
        vector_empty_GCObject(&syli_state.tracing_mutations_worklist) == true);
    assert(vector_size_GCObject(&syli_state.releasing_worklist) == 0);
    assert(vector_empty_GCObject(&syli_state.releasing_worklist) == true);
    assert(vector_size_GCObject(&syli_state.dropping_worklist) == 0);
    assert(vector_empty_GCObject(&syli_state.dropping_worklist) == true);
    assert(vector_size_GCObject(&syli_state.releasing_waitlist) == 0);
    assert(vector_empty_GCObject(&syli_state.releasing_waitlist) == true);
    assert(vector_size_GCObject(&syli_state.dropping_waitlist) == 0);
    assert(vector_empty_GCObject(&syli_state.dropping_waitlist) == true);
    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0);
    assert(vector_empty_Suspected(&syli_state.suspect_lost_cycle) == true);

    // Check stats start at 0
    assert(syli_state.releasing_steps == 0);
    assert(syli_state.tracing_steps == 0);
    assert(syli_state.dropping_steps == 0);
    assert(syli_state.mutation_steps == 0);
    assert(syli_state.checking_steps == 0);
    assert(syli_state.total_objects_dropped == 0);
    assert(syli_state.total_objects_traced == 0);
    assert(syli_state.total_objects_released == 0);
    assert(syli_state.total_objects_memory_freed == 0);

    // Check frame stack indices
    assert(syli_state.current_frame_stack_index == 0);
    assert(syli_state.snapshot_frame_stack_index == 0);
    assert(syli_state.generation_tracing == 0);

    // Check stack frame roots initialized
    assert(syli_state.stack_frame_roots.frames != NULL);
    assert(syli_state.stack_frame_roots.top == 0);
    assert(syli_state.stack_frame_roots.capacity == 16);

    // Check tracing state
    assert(syli_state.tracing_current_bit_mark == 0);
    assert(syli_state.tracing_generations == 0);

    // Check state machines
    assert(syli_state.tracing_state == Tracing_Idle);
    assert(syli_state.releasing_state == Releasing_Idle);
    assert(syli_state.dropping_state == Dropping_Idle);

    // Check suspect notifications and check indices
    assert(syli_state.suspect_objects_notifications == 0);
    assert(syli_state.current_suspected_check_index == 0);
    assert(syli_state.snapshot_check_index == 0);

    syli_state_destroy();
    printf("✓ syli_state_init() initializes all fields correctly\n\n");
}

void test_state_destroy()
{
    printf("Test 2: syli_state_destroy()\n");

    syli_state_init();

    // Verify state is usable before destroy
    assert(syli_state.stack_frame_roots.frames != NULL);

    syli_state_destroy();

    // After destroy, vectors should have chunks set to NULL
    assert(syli_state.tracing_worklist.chunks == NULL);
    assert(syli_state.tracing_worklist.chunk_count == 0);
    assert(syli_state.tracing_worklist.total_elements == 0);

    assert(syli_state.tracing_mutations_worklist.chunks == NULL);
    assert(syli_state.tracing_mutations_worklist.chunk_count == 0);
    assert(syli_state.tracing_mutations_worklist.total_elements == 0);

    assert(syli_state.releasing_worklist.chunks == NULL);
    assert(syli_state.releasing_worklist.chunk_count == 0);
    assert(syli_state.releasing_worklist.total_elements == 0);

    assert(syli_state.dropping_worklist.chunks == NULL);
    assert(syli_state.dropping_worklist.chunk_count == 0);
    assert(syli_state.dropping_worklist.total_elements == 0);

    assert(syli_state.releasing_waitlist.chunks == NULL);
    assert(syli_state.releasing_waitlist.chunk_count == 0);
    assert(syli_state.releasing_waitlist.total_elements == 0);

    assert(syli_state.dropping_waitlist.chunks == NULL);
    assert(syli_state.dropping_waitlist.chunk_count == 0);
    assert(syli_state.dropping_waitlist.total_elements == 0);

    assert(syli_state.suspect_lost_cycle.chunks == NULL);
    assert(syli_state.suspect_lost_cycle.chunk_count == 0);
    assert(syli_state.suspect_lost_cycle.total_elements == 0);

    // Stack frame roots should be destroyed
    assert(syli_state.stack_frame_roots.frames == NULL);
    assert(syli_state.stack_frame_roots.top == 0);
    assert(syli_state.stack_frame_roots.capacity == 0);

    printf("✓ syli_state_destroy() cleans up all resources\n\n");
}

void test_state_init_destroy_cycle()
{
    printf("Test 3: Multiple init/destroy cycles\n");

    // Cycle 1
    syli_state_init();
    assert(syli_state.stack_frame_roots.frames != NULL);
    syli_state_destroy();
    assert(syli_state.stack_frame_roots.frames == NULL);

    // Cycle 2
    syli_state_init();
    assert(syli_state.stack_frame_roots.frames != NULL);
    assert(syli_state.tracing_worklist.chunks != NULL);
    syli_state_destroy();
    assert(syli_state.stack_frame_roots.frames == NULL);

    // Cycle 3
    syli_state_init();
    assert(syli_state.stack_frame_roots.capacity == 16);
    assert(vector_empty_GCObject(&syli_state.tracing_worklist) == true);
    assert(vector_empty_GCObject(&syli_state.releasing_worklist) == true);
    assert(vector_empty_GCObject(&syli_state.dropping_worklist) == true);
    syli_state_destroy();

    printf("✓ Multiple init/destroy cycles work correctly\n\n");
}

void test_state_push_pop_frame_scope()
{
    printf("Test 4: syli_state_push/pop_frame_scope\n");

    syli_state_init();

    // Verify initial state
    assert(syli_state.stack_frame_roots.top == 0);
    assert(syli_state.snapshot_check_index == 0);

    // Create Object* pointers as frame roots
    Object* obj1 = (Object*)0x1000;
    Object** roots1[] = { &obj1 };
    Frame frame1 = { .root_count = 1, .roots = roots1 };

    // Push first frame scope
    syli_state_push_frame_scope(&frame1);
    assert(syli_state.stack_frame_roots.top == 1);
    assert(syli_state.stack_frame_roots.frames[0] == &frame1);

    // Push second frame scope
    Object* obj2 = (Object*)0x2000;
    Object** roots2[] = { &obj2 };
    Frame frame2 = { .root_count = 1, .roots = roots2 };

    syli_state_push_frame_scope(&frame2);
    assert(syli_state.stack_frame_roots.top == 2);
    assert(syli_state.stack_frame_roots.frames[1] == &frame2);

    // Pop second frame scope
    syli_state_pop_frame_scope();
    assert(syli_state.stack_frame_roots.top == 1);

    // Pop first frame scope
    syli_state_pop_frame_scope();
    assert(syli_state.stack_frame_roots.top == 0);

    printf("✓ Basic push/pop works correctly\n");

    // Test snapshot_check_index update on pop
    syli_state.snapshot_check_index = 5;
    assert(syli_state.snapshot_check_index == 5);

    syli_state_push_frame_scope(&frame1);
    assert(syli_state.stack_frame_roots.top == 1);

    syli_state_pop_frame_scope();
    // After pop, top is 0 which is < 5, so snapshot should update to 0
    assert(syli_state.snapshot_check_index == 0);

    printf("✓ Snapshot check index update works correctly\n");

    syli_state_destroy();
    printf("✓ Frame scope push/pop operations work\n\n");
}

void test_state_push_multiple_roots_scope()
{
    printf("Test 5: Frame scope with multiple roots\n");

    syli_state_init();

    Object* obj1 = (Object*)0x1000;
    Object* obj2 = (Object*)0x2000;
    Object* obj3 = (Object*)0x3000;
    Object** roots[] = { &obj1, &obj2, &obj3 };
    Frame frame = { .root_count = 3, .roots = roots };

    syli_state_push_frame_scope(&frame);
    assert(syli_state.stack_frame_roots.top == 1);

    // Verify the frame's roots are accessible
    assert(*frame.roots[0] == obj1);
    assert(*frame.roots[1] == obj2);
    assert(*frame.roots[2] == obj3);

    syli_state_pop_frame_scope();
    assert(syli_state.stack_frame_roots.top == 0);

    syli_state_destroy();
    printf("✓ Frame scope with multiple roots works\n\n");
}

void test_state_frame_scope_with_empty_roots()
{
    printf("Test 6: Frame scope with empty roots (root_count == 0)\n");

    syli_state_init();

    // A frame with root_count == 0 and roots == NULL
    Frame frame = { .root_count = 0, .roots = NULL };

    syli_state_push_frame_scope(&frame);
    assert(syli_state.stack_frame_roots.top == 1);

    syli_state_pop_frame_scope();
    assert(syli_state.stack_frame_roots.top == 0);

    syli_state_destroy();
    printf("✓ Frame scope with empty roots works\n\n");
}

void test_state_gc_cycle()
{
    printf("Test 7: syli_state_gc_cycle()\n");

    syli_state_init();

    // Set budget counters to non-zero to verify they get reset
    syli_state.tracing_budget = -1;
    syli_state.releasing_budget = -1;
    syli_state.dropping_budget = -1;
    syli_state.checking_budget = -1;

    // Call gc_cycle which resets budgets
    syli_state_gc_cycle();

    // Budgets should be reset
    assert(syli_state.tracing_budget == (int)syli_state.BUDGET_GC_TRACING);
    assert(syli_state.releasing_budget == (int)syli_state.BUDGET_GC_RELEASING);
    assert(syli_state.dropping_budget == (int)syli_state.BUDGET_GC_DROPPING);
    assert(syli_state.checking_budget == (int)syli_state.BUDGET_GC_CHECKING);

    syli_state_destroy();
    printf("✓ syli_state_gc_cycle() resets budgets\n\n");
}

void test_state_worklist_operations()
{
    printf("Test 8: GC worklist operations\n");

    syli_state_init();

    // Verify all worklists are empty initially
    assert(vector_empty_GCObject(&syli_state.tracing_worklist) == true);
    assert(
        vector_empty_GCObject(&syli_state.tracing_mutations_worklist) == true);
    assert(vector_empty_GCObject(&syli_state.releasing_worklist) == true);
    assert(vector_empty_GCObject(&syli_state.dropping_worklist) == true);
    assert(vector_empty_GCObject(&syli_state.releasing_waitlist) == true);
    assert(vector_empty_GCObject(&syli_state.dropping_waitlist) == true);
    assert(vector_empty_Suspected(&syli_state.suspect_lost_cycle) == true);

    // Push objects to tracing_worklist using gc_vector_push_back helper
    Object* obj1 = (Object*)0x1234;
    Object* obj2 = (Object*)0x5678;
    Object* obj3 = (Object*)0x9ABC;

    gc_vector_push_back(&syli_state.tracing_worklist, obj1);
    gc_vector_push_back(&syli_state.tracing_worklist, obj2);
    gc_vector_push_back(&syli_state.tracing_worklist, obj3);
    assert(vector_size_GCObject(&syli_state.tracing_worklist) == 3);

    // Pop and verify
    Object* popped = gc_vector_pop_back(&syli_state.tracing_worklist);
    assert(popped == obj3);
    popped = gc_vector_pop_back(&syli_state.tracing_worklist);
    assert(popped == obj2);
    popped = gc_vector_pop_back(&syli_state.tracing_worklist);
    assert(popped == obj1);
    assert(vector_size_GCObject(&syli_state.tracing_worklist) == 0);

    // Push to releasing_worklist
    gc_vector_push_back(&syli_state.releasing_worklist, obj1);
    gc_vector_push_back(&syli_state.releasing_worklist, obj2);
    assert(vector_size_GCObject(&syli_state.releasing_worklist) == 2);
    popped = gc_vector_pop_back(&syli_state.releasing_worklist);
    assert(popped == obj2);
    popped = gc_vector_pop_back(&syli_state.releasing_worklist);
    assert(popped == obj1);
    assert(vector_size_GCObject(&syli_state.releasing_worklist) == 0);

    // Push to dropping_worklist
    gc_vector_push_back(&syli_state.dropping_worklist, obj3);
    assert(vector_size_GCObject(&syli_state.dropping_worklist) == 1);
    popped = gc_vector_pop_back(&syli_state.dropping_worklist);
    assert(popped == obj3);
    assert(vector_size_GCObject(&syli_state.dropping_worklist) == 0);

    // Push to waitlists
    gc_vector_push_back(&syli_state.releasing_waitlist, obj1);
    gc_vector_push_back(&syli_state.dropping_waitlist, obj2);
    assert(vector_size_GCObject(&syli_state.releasing_waitlist) == 1);
    assert(vector_size_GCObject(&syli_state.dropping_waitlist) == 1);
    popped = gc_vector_pop_back(&syli_state.releasing_waitlist);
    assert(popped == obj1);
    popped = gc_vector_pop_back(&syli_state.dropping_waitlist);
    assert(popped == obj2);

    // Push to tracing_mutations_worklist
    gc_vector_push_back(&syli_state.tracing_mutations_worklist, obj1);
    assert(vector_size_GCObject(&syli_state.tracing_mutations_worklist) == 1);
    popped = gc_vector_pop_back(&syli_state.tracing_mutations_worklist);
    assert(popped == obj1);

    // Suspected worklist (uses Suspected struct directly)
    Suspected s1 = { .obj = (GCObject*)obj1 };
    Suspected s2 = { .obj = (GCObject*)obj2 };
    vector_push_back_Suspected(&syli_state.suspect_lost_cycle, &s1);
    vector_push_back_Suspected(&syli_state.suspect_lost_cycle, &s2);
    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 2);
    assert(vector_at_Suspected(&syli_state.suspect_lost_cycle, 0)->obj
        == (GCObject*)obj1);
    assert(vector_at_Suspected(&syli_state.suspect_lost_cycle, 1)->obj
        == (GCObject*)obj2);

    syli_state_destroy();
    printf("✓ GC worklist operations work correctly\n\n");
}

int main()
{
    printf("\033[1;34m=== Running syli_state Tests ===\033[0m\n\n");

    test_state_init();
    test_state_destroy();
    test_state_init_destroy_cycle();
    test_state_push_pop_frame_scope();
    test_state_push_multiple_roots_scope();
    test_state_frame_scope_with_empty_roots();
    test_state_gc_cycle();
    test_state_worklist_operations();

    printf("\033[1;32m=== All syli_state Tests Passed! ===\033[0m\n\n");
    return 0;
}
