#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "syli/gc_helpers.h"
#include "syli/header_object.h"
#include "syli/object.h"
#include "syli/syli_state.h"

#pragma GCC diagnostic ignored "-Wunused-parameter"

static Object* make_mono_ref_object(size_t words, CyclicFlag cyclic)
{
    object_payload_t payload = syli_object_make_mono_payload(words);
    object_header_t header = syli_object_make_header(
        Zone_GcLocal, cyclic, Type_MonoRef, Flag_HasPointers, payload);
    uint64_t meta_ref_count = make_meta_refcount(
        Meta_Flags_None, syli_state.tracing_current_bit_mark);
    return syli_object_alloc(header, meta_ref_count, words);
}

static bool releasing_drained(void)
{
    return vector_size_GCObject(&syli_state.releasing_waitlist) == 0
        && vector_size_GCObject(&syli_state.releasing_worklist) == 0
        && syli_state.releasing_state == Releasing_Idle;
}

static bool dropping_drained(void)
{
    return vector_size_GCObject(&syli_state.dropping_waitlist) == 0
        && vector_size_GCObject(&syli_state.dropping_worklist) == 0
        && syli_state.dropping_state == Dropping_Idle;
}

static bool tracing_suspects_gone(void)
{
    return vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0
        && syli_state.tracing_state == Tracing_Idle;
}

static bool suspect_vector_empty_and_releasing_drained(void)
{
    return vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0
        && vector_size_GCObject(&syli_state.releasing_waitlist) == 0
        && vector_size_GCObject(&syli_state.releasing_worklist) == 0;
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

    syli_state.THRESHOLD_RELEASING_BUCKET = 1;
    syli_state.THRESHOLD_DROPPING_BUCKET = 1;
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = SIZE_MAX;

    syli_state.BUDGET_GC_RELEASING = 1024;
    syli_state.BUDGET_GC_DROPPING = 16;
    syli_state.BUDGET_GC_TRACING = 16;
    syli_state.BUDGET_GC_CHECKING = 16;

    Object* root = make_mono_ref_object(1, Acyclic);
    Object* child = make_mono_ref_object(0, Acyclic);
    assert(root != NULL && child != NULL);

    syli_object_data(root)[0] = (uint64_t)child;

    /* "Released" means object lost its local reference and is queued for
     * release. */
    syli_object_decr_local(root);
    gc_vector_push_back(&syli_state.releasing_waitlist, root);

    assert(vector_size_GCObject(&syli_state.releasing_waitlist) == 1);
    assert(vector_size_GCObject(&syli_state.releasing_worklist) == 0);

    run_gc_until(releasing_drained, 64);

    assert(vector_size_GCObject(&syli_state.releasing_waitlist) == 0);
    assert(vector_size_GCObject(&syli_state.releasing_worklist) == 0);
    assert(syli_state.releasing_steps > 0);
    assert(syli_state.total_objects_memory_freed >= 2);

    syli_state_destroy();

    printf("✓ releasing waitlist/worklist drained\n\n");
}

static void test_dropping_waitlist_gets_drained(void)
{
    printf("Test 2: dropping waitlist drains to empty\n");

    syli_state_init();

    syli_state.THRESHOLD_RELEASING_BUCKET = 1;
    syli_state.THRESHOLD_DROPPING_BUCKET = 1;
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = SIZE_MAX;

    syli_state.BUDGET_GC_RELEASING = 16;
    syli_state.BUDGET_GC_DROPPING = 1024;
    syli_state.BUDGET_GC_TRACING = 16;
    syli_state.BUDGET_GC_CHECKING = 16;

    /*
     * "Dropped" objects: no local references remain and the full disconnected
     * group can be reclaimed by the dropping phase, one by one or in a batch.
     */
    Object* a = make_mono_ref_object(0, Acyclic);
    Object* b = make_mono_ref_object(0, Acyclic);
    Object* c = make_mono_ref_object(0, Acyclic);
    assert(a != NULL && b != NULL && c != NULL);

    syli_object_decr_local(a);
    syli_object_decr_local(b);
    syli_object_decr_local(c);

    gc_vector_push_back(&syli_state.dropping_waitlist, a);
    gc_vector_push_back(&syli_state.dropping_waitlist, b);
    gc_vector_push_back(&syli_state.dropping_waitlist, c);

    assert(vector_size_GCObject(&syli_state.dropping_waitlist) == 3);
    assert(vector_size_GCObject(&syli_state.dropping_worklist) == 0);

    run_gc_until(dropping_drained, 64);

    assert(vector_size_GCObject(&syli_state.dropping_waitlist) == 0);
    assert(vector_size_GCObject(&syli_state.dropping_worklist) == 0);
    assert(syli_state.dropping_steps >= 3);

    syli_state_destroy();

    printf("✓ dropping waitlist/worklist drained\n\n");
}

static void test_dropping_family_group_gets_drained(void)
{
    printf("Test 3: dropping drains disconnected family graph\n");

    syli_state_init();

    syli_state.THRESHOLD_RELEASING_BUCKET = 1;
    syli_state.THRESHOLD_DROPPING_BUCKET = 1;
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = SIZE_MAX;

    syli_state.BUDGET_GC_RELEASING = 16;
    syli_state.BUDGET_GC_DROPPING = 2048;
    syli_state.BUDGET_GC_TRACING = 16;
    syli_state.BUDGET_GC_CHECKING = 16;

    /*
     * Disconnected family graph:
     *   parent -> child_a
     *   parent -> child_b
     *   child_a -> child_b (sibling reference)
     */
    Object* parent = make_mono_ref_object(2, Acyclic);
    Object* child_a = make_mono_ref_object(1, Acyclic);
    Object* child_b = make_mono_ref_object(0, Acyclic);
    assert(parent != NULL && child_a != NULL && child_b != NULL);

    syli_object_data(parent)[0] = (uint64_t)child_a;
    syli_object_incr(child_a);
    syli_object_data(parent)[1] = (uint64_t)child_b;
    syli_object_incr(child_b);
    syli_object_data(child_a)[0] = (uint64_t)child_b;
    syli_object_incr(child_b);

    /* Lose local references: now they are only internally referenced. */
    syli_object_decr_local(parent);
    syli_object_decr_local(child_a);
    syli_object_decr_local(child_b);

    gc_vector_push_back(&syli_state.dropping_waitlist, parent);
    gc_vector_push_back(&syli_state.dropping_waitlist, child_a);
    gc_vector_push_back(&syli_state.dropping_waitlist, child_b);

    assert(vector_size_GCObject(&syli_state.dropping_waitlist) == 3);
    assert(vector_size_GCObject(&syli_state.dropping_worklist) == 0);

    run_gc_until(dropping_drained, 128);

    assert(vector_size_GCObject(&syli_state.dropping_waitlist) == 0);
    assert(vector_size_GCObject(&syli_state.dropping_worklist) == 0);
    assert(syli_state.dropping_steps >= 3);

    syli_state_destroy();

    printf("✓ dropping family graph drained\n\n");
}

static void test_unreachable_suspect_removed_via_releasing(void)
{
    printf("Test 4: unreachable suspect removed by releasing path\n");

    syli_state_init();

    syli_state.THRESHOLD_RELEASING_BUCKET = 1;
    syli_state.THRESHOLD_DROPPING_BUCKET = 1;
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = 0;

    syli_state.BUDGET_GC_RELEASING = 16;
    syli_state.BUDGET_GC_DROPPING = 16;
    syli_state.BUDGET_GC_TRACING = 1024;
    syli_state.BUDGET_GC_CHECKING = 1024;

    /* Unreachable suspect: dropped local ref + explicit releasing queue
     * insertion. */
    Object* unreachable = make_mono_ref_object(0, Cyclic);
    assert(unreachable != NULL);

    syli_state.suspect_objects_notifications = 0;
    syli_object_decr_local(unreachable);
    gc_add_suspect(unreachable);
    gc_vector_push_back(&syli_state.releasing_waitlist, unreachable);

    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 1);
    assert(syli_state.suspect_objects_notifications > 0);

    run_gc_until(suspect_vector_empty_and_releasing_drained, 128);

    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0);
    assert(vector_size_GCObject(&syli_state.releasing_waitlist) == 0);
    assert(vector_size_GCObject(&syli_state.releasing_worklist) == 0);

    syli_state_destroy();

    printf("✓ unreachable suspect removed via releasing\n\n");
}

static void test_tracing_only_suspected_notifications(void)
{
    printf("Test 5: suspects-only notification triggers tracing and drains "
           "suspects\n");

    syli_state_init();

    syli_state.THRESHOLD_RELEASING_BUCKET = 1;
    syli_state.THRESHOLD_DROPPING_BUCKET = 1;
    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE = 0;

    /* In checking, reachable suspects are drained when bucket is full enough. */
    syli_state.FULL_BUCKET_SUSPECT_LOST_CYCLE = 1;

    syli_state.BUDGET_GC_RELEASING = 16;
    syli_state.BUDGET_GC_DROPPING = 16;
    syli_state.BUDGET_GC_TRACING = 1024;
    syli_state.BUDGET_GC_CHECKING = 1024;

    Object* root = make_mono_ref_object(1, Cyclic);
    Object* child = make_mono_ref_object(0, Cyclic);
    assert(root != NULL && child != NULL);

    syli_object_data(root)[0] = (uint64_t)child;

    Object** roots[] = { &root };
    Frame frame = { .root_count = 1, .roots = roots };
    syli_state_push_frame_scope(&frame);

    /* Only suspects are added; no releasing/dropping work is enqueued. */
    syli_state.suspect_objects_notifications = 0;
    gc_add_suspect(root);

    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 1);
    assert(vector_size_GCObject(&syli_state.releasing_waitlist) == 0);
    assert(vector_size_GCObject(&syli_state.dropping_waitlist) == 0);
    assert(syli_state.suspect_objects_notifications > 0);

    run_gc_until(tracing_suspects_gone, 128);

    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0);
    assert(syli_state.tracing_generations > 0);
    assert(vector_size_GCObject(&syli_state.releasing_waitlist) == 0);
    assert(vector_size_GCObject(&syli_state.dropping_waitlist) == 0);

    syli_state_pop_frame_scope();
    free(root);
    free(child);
    syli_state_destroy();

    printf("✓ suspects-only notification path drained suspect list\n\n");
}

int main(void)
{
    printf("\033[1;34m=== Running GC Waitlist/Worklist Tests ===\033[0m\n\n");

    test_releasing_waitlist_gets_drained();
    test_dropping_waitlist_gets_drained();
    test_dropping_family_group_gets_drained();
    test_unreachable_suspect_removed_via_releasing();
    test_tracing_only_suspected_notifications();

    printf("\033[1;32m=== All GC Waitlist/Worklist Tests Passed! ===\033[0m\n\n");
    return 0;
}
