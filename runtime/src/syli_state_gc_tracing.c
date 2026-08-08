#include <assert.h>
#include <stdio.h>

#include "syli/gc_helpers.h"
#include "syli/gc_roots.h"
#include "syli/object.h"

#include "syli/syli_state.h"

// Non-recursive DFS marking (precise - uses type descriptors)
static void gc_one_step_tracing(void)
{

    Object* obj = syli_object_of_obj_ptr(
        gc_vector_pop_back(&syli_state.tracing_worklist));

    assert(obj != NULL && "Null GCObject in tracing worklist");

    // Clear the in-worklist guard now that we've popped it
    syli_object_clear_flags(obj, Meta_Flags_Tracing);

    if (syli_object_has_flags(obj, Meta_Flags_Waiting_Remove)) {
        free(obj);
        return;
    }

    GCObject* current = as_gc_object(obj);

    // Skip freed objects
    if ((current->meta_ref_count & REFCOUNT_MASK) == 0) {
        return;
    }

    if (gc_is_object_mark_tagged(as_object(current))) {
        return; // Already marked in this tracing cycle
    }

    gc_mark_tag_object(as_object(current));
    syli_state.total_objects_traced++;

    // All the child are reference
    if (syli_object_is_mono_ref(obj)) {
        // Fast path for uniform all-reference objects
        size_t length = syli_object_length(obj);
        syli_state.tracing_budget -= (int)length;
        for (size_t i = 0; i < length; i++) {
            uint64_t field_value = current->value[i];
            if (!field_value
                || !syli_ownership_is_own_ref((obj_ptr)field_value)) {
                continue;
            }
            gc_tracing_worklist_push((obj_ptr)field_value);
        }
        return;
    }

    // Mixed bitmap references
    if (syli_object_is_mixed_bitmap(obj)) {
        // All fields are references, traverse all
        size_t length = syli_object_bitmap_length(obj);
        int bitmap    = syli_object_bitmap_bits(obj);
        syli_state.tracing_budget -= (int)length;
        for (size_t i = 0; i < length; i++) {
            if (bitmap & (1 << i)) {
                continue; // non-reference field
            }
            uint64_t field_value = current->value[i];
            if (!field_value
                || !syli_ownership_is_own_ref((obj_ptr)field_value)) {
                continue;
            }
            gc_tracing_worklist_push((obj_ptr)field_value);
        }
        return;
    }

    // Mixed order references
    if (syli_object_is_mixed_order(obj)) {
        size_t ptr_count = syli_object_order_ptr_count(obj);
        syli_state.tracing_budget -= ptr_count;
        for (size_t i = 0; i < ptr_count; i++) {
            uint64_t field_value = current->value[i];
            if (!field_value
                || !syli_ownership_is_own_ref((obj_ptr)field_value)) {
                continue;
            }
            gc_tracing_worklist_push((obj_ptr)field_value);
        }
        return;
    }
}

static void gc_one_step_prepare_tracing_mutations()
{

    obj_ptr obj_p = gc_vector_pop_back(&syli_state.tracing_mutations_worklist);
    assert(syli_ownership_is_own_ref(obj_p));
    Object* obj      = syli_object_of_obj_ptr(obj_p);
    GCObject* gc_obj = as_gc_object(obj);

    assert(gc_obj != NULL);
    assert(syli_object_get_zone((Object*)gc_obj) == Zone_GcLocal);

    if (syli_object_has_flags(obj, Meta_Flags_Waiting_Remove)) {
        free(obj);
        return;
    }

    if (syli_object_is_mono_ref(obj)) {
        // All fields are references, traverse all
        size_t length = syli_object_length(obj);
        syli_state.tracing_budget -= (int)length;
        for (size_t i = 0; i < length; i++) {
            uint64_t field_value = gc_obj->value[i];
            if (!field_value
                || !syli_ownership_is_own_ref((obj_ptr)field_value)) {
                continue;
            }
            gc_tracing_worklist_push((obj_ptr)field_value);
        }
        return;
    }

    if (syli_object_is_mixed_bitmap(obj)) {
        // Precisely traverse only reference fields using type descriptor
        uint64_t length = syli_object_bitmap_length(obj);
        uint32_t bitmap = syli_object_bitmap_bits(obj);
        for (uint32_t i = 0; i < length; i++) {
            if (bitmap & (1 << i)) {
                continue; // non-reference field
            }
            uint64_t field_value = gc_obj->value[i];
            if (!field_value
                || !syli_ownership_is_own_ref((obj_ptr)field_value)) {
                continue;
            }
            gc_tracing_worklist_push((obj_ptr)field_value);
        }
        return;
    }

    if (syli_object_is_mixed_order(obj)) {
        // Precisely traverse only reference fields using type descriptor
        size_t ptr_count = syli_object_order_ptr_count(obj);
        syli_state.tracing_budget -= (int)ptr_count;
        for (size_t i = 0; i < ptr_count; i++) {
            uint64_t field_value = gc_obj->value[i];
            if (!field_value
                || !syli_ownership_is_own_ref((obj_ptr)field_value)) {
                continue;
            }
            gc_tracing_worklist_push((obj_ptr)field_value);
        }
        return;
    }
}

void syli_state_gc_tracing()
{
    while (1) {

        if (syli_state.tracing_budget <= 0)
            return; // Out of budget for this cycle

        switch (syli_state.tracing_state) {
        case Tracing_Idle:

            if (syli_state.suspect_objects_notifications
                > syli_state.THRESHOLD_SUSPECTS_LOST_CYCLE) {

                syli_state.tracing_state = Tracing;
                gc_next_marking_generation();

                syli_rt_collect_stack_roots();

                if (vector_size_obj_ptr(&syli_state.tracing_worklist) == 0
                    && vector_size_obj_ptr(
                           &syli_state.tracing_mutations_worklist)
                        == 0) {
                    syli_state.tracing_state = Checking_Suspect_Lost_Cycle;
                    syli_state.suspect_objects_notifications = 0;
                }

                break; // Start tracing in the next iteration
            }

            return; // No need to start tracing;
        case Tracing:
            gc_one_step_tracing();
            syli_state.tracing_steps++;

            if (vector_size_obj_ptr(&syli_state.tracing_worklist) == 0
                && vector_size_obj_ptr(&syli_state.tracing_mutations_worklist)
                    == 0) {
                syli_state.tracing_state = Checking_Suspect_Lost_Cycle;
                syli_state.suspect_objects_notifications = 0;
                break;
            }

            if (vector_size_obj_ptr(&syli_state.tracing_mutations_worklist)
                > 0) {
                syli_state.tracing_state = Mutation_Prepare;
                break;
            }

            break;
        case Mutation_Prepare:
            if (vector_size_obj_ptr(&syli_state.tracing_mutations_worklist)
                == 0) {
                // No mutations left: resume tracing or finish the cycle.
                if (vector_size_obj_ptr(&syli_state.tracing_worklist) > 0) {
                    syli_state.tracing_state = Tracing;
                } else {
                    syli_state.tracing_state = Checking_Suspect_Lost_Cycle;
                    syli_state.suspect_objects_notifications = 0;
                }
                break;
            }
            gc_one_step_prepare_tracing_mutations();
            syli_state.mutation_steps++;
            break;

        case Checking_Suspect_Lost_Cycle:
            syli_state.checking_budget--;

            if (syli_state.checking_budget <= 0) {
                return; // Out of budget for this cycle
            }

            if (vector_size_Suspected(&syli_state.suspect_lost_cycle) > 0) {
                Suspected* suspected_obj = (Suspected*)vector_at_Suspected(
                    &syli_state.suspect_lost_cycle,
                    syli_state.current_suspected_check_index);

                Object* obj = syli_object_of_obj_ptr(suspected_obj->obj);

                if (gc_is_object_mark_tagged(obj)) {
                    // Object is still reachable, could be removed from suspects

                    if (vector_size_Suspected(&syli_state.suspect_lost_cycle)
                        >= syli_state.FULL_BUCKET_SUSPECT_LOST_CYCLE) {

                        syli_object_clear_flags(
                            obj, Meta_Flags_Suspect_Lost_Cycle);
                        gc_remove_suspect_at(
                            syli_state.current_suspected_check_index);
                    }

                } else {
                    // Object is not reachable, free it
                    syli_state.total_objects_memory_freed++;
                    if (syli_object_is_mono(obj)) {
                        free(obj);
                    } else {
                        syli_object_clear_flags(
                            obj, Meta_Flags_Suspect_Lost_Cycle);
                        gc_vector_push_back(
                            &syli_state.releasing_waitlist, suspected_obj->obj);
                    }
                }

                syli_state.current_suspected_check_index++;

                size_t suspect_size
                    = vector_size_Suspected(&syli_state.suspect_lost_cycle);

                if (syli_state.current_suspected_check_index >= suspect_size) {
                    // Finished checking all suspects, reset for next cycle
                    syli_state.current_suspected_check_index = 0;
                    syli_state.tracing_state                 = Tracing_Idle;
                }
            } else {
                // No suspects left to check
                syli_state.tracing_state = Tracing_Idle;
            }

            break;
        }
    }
}