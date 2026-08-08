#include "syli/syli_state.h"

#include <assert.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "syli/env.h"
#include "syli/gc_helpers.h"
#include "syli/gc_roots.h"
#include "syli/object.h"

SYLI_TLS Syli_state syli_state;

void syli_state_init()
{
    syli_rt_stackmap_check_version();
    syli_load_env();

    // Zero out the entire state to ensure clean initialization
    memset(&syli_state, 0, sizeof(Syli_state));

    syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE
        = syli_env.syli_gc_suspect_threshold;

    syli_state.THRESHOLD_RELEASING_BUCKET = syli_env.syli_gc_release_threshold;

    syli_state.FULL_BUCKET_SUSPECT_LOST_CYCLE = 10000;

    // Initialize budgets
    syli_state.BUDGET_GC_TRACING   = 2 * BUDGET_BATCH_SIZE;
    syli_state.BUDGET_GC_RELEASING = 5 * BUDGET_BATCH_SIZE;
    syli_state.BUDGET_GC_CHECKING  = 3 * BUDGET_BATCH_SIZE;

    syli_state.tracing_budget   = 0;
    syli_state.releasing_budget = 0;
    syli_state.checking_budget  = 0;

    // Initialize GC worklists (vectors of GCObject*)
    vector_init_obj_ptr(&syli_state.tracing_worklist);
    vector_init_obj_ptr(&syli_state.tracing_mutations_worklist);
    vector_init_obj_ptr(&syli_state.releasing_worklist);
    vector_init_obj_ptr(&syli_state.releasing_waitlist);

    // Initialize suspect lost cycle vector
    vector_init_Suspected(&syli_state.suspect_lost_cycle);

    // Initialize stats
    syli_state.releasing_steps = 0;
    syli_state.tracing_steps   = 0;
    syli_state.mutation_steps  = 0;
    syli_state.checking_steps  = 0;

    syli_state.total_objects_traced       = 0;
    syli_state.total_objects_released     = 0;
    syli_state.total_objects_memory_freed = 0;

    syli_state.generation_tracing = 0;

    // Initialize stack frame for root management
    syli_stack_frame_init(&syli_state.stack_frame_roots, 16);

    // Initialize tracing state
    syli_state.tracing_current_bit_mark = 0;
    syli_state.tracing_generations      = 0;

    // Initialize state machines
    syli_state.tracing_state   = Tracing_Idle;
    syli_state.releasing_state = Releasing_Idle;

    syli_state.suspect_objects_notifications = 0;

    syli_state.current_suspected_check_index = 0;
    syli_state.snapshot_check_index          = 0;

    syli_state.stackmap_record_entry     = NULL;
    syli_state.stackmap_record_entry_len = 0;
}

void syli_state_destroy()
{
    // Clean up GC worklists
    vector_destroy_obj_ptr(&syli_state.tracing_worklist);
    vector_destroy_obj_ptr(&syli_state.tracing_mutations_worklist);
    vector_destroy_obj_ptr(&syli_state.releasing_worklist);
    vector_destroy_obj_ptr(&syli_state.releasing_waitlist);

    // Clean up suspect lost cycle vector
    vector_destroy_Suspected(&syli_state.suspect_lost_cycle);

    // Clean up stackmap recorded pc
    free(syli_state.stackmap_record_entry);

    // Clean up stack frame
    syli_stack_frame_destroy(&syli_state.stack_frame_roots);
}

void syli_state_push_frame_scope(Frame* frame)
{
    assert(frame != NULL);
    assert(frame->root_count == 0 || frame->roots != NULL);

    syli_stack_frame_push_scope(&syli_state.stack_frame_roots, frame);
}

void syli_state_pop_frame_scope()
{
    syli_stack_frame_pop_scope(&syli_state.stack_frame_roots);

    // Update GC marker snapshot index
    if (syli_state.stack_frame_roots.top < syli_state.snapshot_check_index) {
        syli_state.snapshot_check_index = syli_state.stack_frame_roots.top;
    }
}
