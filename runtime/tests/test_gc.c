#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "syli/gc_helpers.h"
#include "syli/header_object.h"
#include "syli/object.h"
#include "syli/syli.h"
#include "syli/syli_primitives.h"
#include "syli/syli_state.h"

#pragma GCC diagnostic ignored "-Wunused-parameter"

static obj_ptr make_mono_ref_object(size_t words, CyclicFlag cyclic)
{
    object_payload_t payload = syli_object_make_mono_payload(words);
    object_header_t header   = syli_object_make_header(
        Zone_GcLocal, cyclic, Type_MonoRef, Flag_HasPointers, payload);
    return syli_rt_ownership_alloc_object(header, 1, words);
}

static obj_ptr make_trackable_object(size_t words)
{
    object_payload_t payload = syli_object_make_mono_payload(words);
    object_header_t header
        = syli_object_make_header(Zone_GcLocal, Cyclic, Type_MonoRef,
            (ObjectImmutableFlag)(Flag_HasPointers | Flag_Traceable), payload);
    return syli_rt_ownership_alloc_object(header, 1, words);
}

static bool releasing_drained(void)
{
    return vector_size_obj_ptr(&syli_state.releasing_waitlist) == 0
        && vector_size_obj_ptr(&syli_state.releasing_worklist) == 0
        && syli_state.releasing_state == Releasing_Idle;
}

static bool tracing_suspects_gone(void)
{
    return vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0
        && syli_state.tracing_state == Tracing_Idle;
}

static bool suspect_vector_empty_and_releasing_drained(void)
{
    return vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0
        && vector_size_obj_ptr(&syli_state.releasing_waitlist) == 0
        && vector_size_obj_ptr(&syli_state.releasing_worklist) == 0;
}

static void run_gc_until(bool (*done)(void), size_t max_cycles)
{
    size_t cycles = 0;
    while (!done()) {
        syli_state_gc_cycle();
        cycles++;
        assert(cycles <= max_cycles);
    }
}

static void test_releasing_waitlist_gets_drained(void)
{
    printf("Test 1: releasing waitlist drains to empty\n");

    syli_state_init();

    syli_state.THRESHOLD_RELEASING_BUCKET    = 1;
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = SIZE_MAX;

    syli_state.BUDGET_GC_RELEASING = 1024;
    syli_state.BUDGET_GC_TRACING   = 16;
    syli_state.BUDGET_GC_CHECKING  = 16;

    obj_ptr root  = make_mono_ref_object(1, Acyclic);
    obj_ptr child = make_mono_ref_object(0, Acyclic);
    assert(root != NULL && child != NULL);

    syli_object_data(syli_object_of_obj_ptr(root))[0] = (uint64_t)child;

    /* "Released" means object lost its local reference and is queued for
     * release. */
    syli_rt_ownership_decr(root);

    assert(vector_size_obj_ptr(&syli_state.releasing_waitlist) == 1);
    assert(vector_size_obj_ptr(&syli_state.releasing_worklist) == 0);

    run_gc_until(releasing_drained, 64);

    assert(vector_size_obj_ptr(&syli_state.releasing_waitlist) == 0);
    assert(vector_size_obj_ptr(&syli_state.releasing_worklist) == 0);
    assert(syli_state.releasing_steps > 0);
    assert(syli_state.total_objects_memory_freed >= 2);

    syli_state_destroy();

    printf("✓ releasing waitlist/worklist drained\n\n");
}

static void test_unreachable_suspect_removed_via_releasing(void)
{
    printf("Test 4: unreachable suspect removed by releasing path\n");

    syli_state_init();

    syli_state.THRESHOLD_RELEASING_BUCKET    = 1;
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = 0;

    syli_state.BUDGET_GC_RELEASING = 16;
    syli_state.BUDGET_GC_TRACING   = 1024;
    syli_state.BUDGET_GC_CHECKING  = 1024;

    /* Unreachable suspect: dropped local ref + explicit releasing queue
     * insertion. */
    obj_ptr unreachable = make_mono_ref_object(0, Cyclic);
    assert(unreachable != NULL);

    syli_state.suspect_objects_notifications = 0;
    syli_rt_ownership_decr(unreachable);
    gc_add_suspect(unreachable);

    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 1);
    assert(syli_state.suspect_objects_notifications > 0);

    run_gc_until(suspect_vector_empty_and_releasing_drained, 128);

    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0);
    assert(vector_size_obj_ptr(&syli_state.releasing_waitlist) == 0);
    assert(vector_size_obj_ptr(&syli_state.releasing_worklist) == 0);

    syli_state_destroy();

    printf("✓ unreachable suspect removed via releasing\n\n");
}

static void test_roots_protect_created_objects(void)
{
    printf("Test 5: rooted objects are traced, none freed\n");

    syli_state_init();

    syli_state.THRESHOLD_RELEASING_BUCKET     = 1;
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE  = 0;
    syli_state.FULL_BUCKET_SUSPECT_LOST_CYCLE = 1;

    syli_state.BUDGET_GC_RELEASING = 16;
    syli_state.BUDGET_GC_TRACING   = 1024;
    syli_state.BUDGET_GC_CHECKING  = 1024;

    size_t created  = 3;
    obj_ptr objs[3] = { 0 };
    for (size_t i = 0; i < created; i++) {
        objs[i] = make_mono_ref_object(1, Cyclic);
        assert(objs[i] != NULL);
    }
    for (size_t i = 0; i + 1 < created; i++) {
        syli_object_data(syli_object_of_obj_ptr(objs[i]))[0]
            = (uint64_t)objs[i + 1];
    }

    /* Simulate what the stackmap unwinder does: seed the tracing worklist
     * with the live roots. */
    gc_tracing_worklist_push(objs[0]);

    syli_state.suspect_objects_notifications = 0;
    gc_add_suspect(objs[0]);
    assert(syli_state.suspect_objects_notifications > 0);

    run_gc_until(tracing_suspects_gone, 128);

    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0);
    assert(syli_state.tracing_generations > 0);
    assert(syli_state.total_objects_traced == created);
    assert(syli_state.total_objects_memory_freed == 0);

    printf("  created=%zu traced=%zu freed=%zu\n", created,
        syli_state.total_objects_traced, syli_state.total_objects_memory_freed);
    syli_print_gc_state();

    syli_state_destroy();

    printf("✓ roots protect all created objects (traced == created)\n\n");
}

static void test_unrooted_objects_reclaimed(void)
{
    printf("Test 6: unrooted objects are freed (freed == created)\n");

    syli_state_init();

    syli_state.THRESHOLD_RELEASING_BUCKET    = 1;
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = 0;

    syli_state.BUDGET_GC_RELEASING = 1024;
    syli_state.BUDGET_GC_TRACING   = 1024;
    syli_state.BUDGET_GC_CHECKING  = 1024;

    obj_ptr root  = make_mono_ref_object(1, Cyclic);
    obj_ptr child = make_mono_ref_object(0, Cyclic);
    assert(root != NULL && child != NULL);

    syli_object_data(syli_object_of_obj_ptr(root))[0] = (uint64_t)child;

    syli_state.suspect_objects_notifications = 0;
    syli_rt_ownership_decr(root);
    gc_add_suspect(root);

    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 1);
    assert(syli_state.suspect_objects_notifications > 0);
    assert(vector_size_obj_ptr(&syli_state.releasing_waitlist) == 1);

    run_gc_until(suspect_vector_empty_and_releasing_drained, 128);

    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0);
    assert(vector_size_obj_ptr(&syli_state.releasing_waitlist) == 0);
    assert(vector_size_obj_ptr(&syli_state.releasing_worklist) == 0);
    assert(syli_state.total_objects_memory_freed == 2);

    printf("  created=2 traced=%zu freed=%zu\n",
        syli_state.total_objects_traced, syli_state.total_objects_memory_freed);
    syli_print_gc_state();

    syli_state_destroy();

    printf("✓ unrooted objects reclaimed (freed == created)\n\n");
}

static void test_borrowed_roots_not_pushed(void)
{
    printf("Test 7: borrowed roots are not pushed\n");

    syli_state_init();

    obj_ptr own = make_mono_ref_object(0, Cyclic);
    assert(own != NULL);

    obj_ptr borrowed = syli_rt_ownership_borrow(own);
    assert(!syli_ownership_is_own_ref(borrowed));

    gc_tracing_worklist_push(borrowed);
    assert(vector_size_obj_ptr(&syli_state.tracing_worklist) == 0);

    gc_tracing_worklist_push(own);
    assert(vector_size_obj_ptr(&syli_state.tracing_worklist) == 1);

    gc_vector_pop_back(&syli_state.tracing_worklist);
    assert(vector_size_obj_ptr(&syli_state.tracing_worklist) == 0);

    syli_free_ptr(own);
    syli_state_destroy();

    printf("✓ borrowed roots skipped, own roots pushed\n\n");
}

static void test_mutation_barrier_drains(void)
{
    printf("Test 8: mutation barrier queues and Mutation_Prepare drains\n");

    syli_state_init();

    syli_state.THRESHOLD_RELEASING_BUCKET     = 1;
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE  = 0;
    syli_state.FULL_BUCKET_SUSPECT_LOST_CYCLE = 1;

    syli_state.BUDGET_GC_RELEASING = 16;
    syli_state.BUDGET_GC_TRACING   = 1024;
    syli_state.BUDGET_GC_CHECKING  = 1024;

    /* Target with a reference child: Mutation_Prepare re-traces the child. */
    {
        syli_state.tracing_current_bit_mark = 0;
        obj_ptr obj                         = make_trackable_object(1);
        obj_ptr child                       = make_mono_ref_object(0, Cyclic);
        obj_ptr target                      = make_mono_ref_object(1, Cyclic);
        assert(obj != NULL && child != NULL && target != NULL);
        syli_object_data(syli_object_of_obj_ptr(target))[0] = (uint64_t)child;

        syli_state.tracing_current_bit_mark = MASK_MARKING_BIT;
        gc_mark_tag_object(syli_object_of_obj_ptr(obj));

        syli_state.tracing_state = Mutation_Prepare;
        syli_rt_ownership_notify_mutation(obj, target);
        assert(
            vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 1);

        run_gc_until(tracing_suspects_gone, 64);

        assert(
            vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 0);
        assert(vector_size_obj_ptr(&syli_state.tracing_worklist) == 0);
        assert(gc_is_object_mark_tagged(syli_object_of_obj_ptr(target)));

        syli_free_ptr(obj);
        syli_free_ptr(child);
        syli_free_ptr(target);
    }

    syli_state_destroy();

    printf("✓ mutation barrier queues and Mutation_Prepare drains\n\n");
}

int main(void)
{
    printf("\033[1;34m=== Running GC Waitlist/Worklist Tests ===\033[0m\n\n");

    test_releasing_waitlist_gets_drained();
    test_unreachable_suspect_removed_via_releasing();
    test_roots_protect_created_objects();
    test_unrooted_objects_reclaimed();
    test_borrowed_roots_not_pushed();
    test_mutation_barrier_drains();

    printf(
        "\033[1;32m=== All GC Waitlist/Worklist Tests Passed! ===\033[0m\n\n");
    return 0;
}
