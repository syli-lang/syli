#include <assert.h>
#include <stdio.h>

#include "syli/gc_helpers.h"
#include "syli/object.h"

#include "syli/syli_state.h"

static inline void free_released_object(Object* obj)
{
    if (syli_object_has_flags(obj, Meta_Flags_Suspect_Lost_Cycle)) {
        size_t index_suspect = syli_object_get_cyclic_index(as_gc_object(obj));
        gc_remove_suspect_at(index_suspect);
        syli_object_clear_flags(obj, Meta_Flags_Suspect_Lost_Cycle);
    }

    if (syli_object_has_flags(obj, Meta_Flags_Tracing)) {
        syli_object_set_flags(obj, Meta_Flags_Waiting_Remove);
        return;
    }

    syli_state.total_objects_memory_freed++;
    free(obj);
}

static inline void child_release_object(Object* obj)
{
    assert(obj != NULL);

    GCObject* gc_obj = as_gc_object(obj);
    syli_object_decr_local(obj);

    const int ref_count = (gc_obj->meta_ref_count & REFCOUNT_MASK);

    if (ref_count > 0 && syli_object_is_cyclic(obj)) {
        gc_add_suspect(obj);
        return;
    }

    if (ref_count > 0) {
        // the child is not cyclic so safe to ignore
        return;
    }

    assert(ref_count == 0);

    if (syli_object_has_pointers(obj) == 0) {
        free_released_object(obj);
        return;
    }

    if (syli_object_has_flags(obj, Meta_Flags_Releasing)) {
        // an object can even points to itself.
        return;
    }

    // we need to process its children before we can free it
    gc_vector_push_back(&syli_state.releasing_waitlist, obj);
}

static inline void gc_one_step_releasing()
{
    syli_state.releasing_budget--;
    Object* obj = gc_vector_pop_back(&syli_state.releasing_worklist);
    GCObject* gc_obj = as_gc_object(obj);

    if (syli_object_is_mono_ref(obj)) {
        // All fields are references, traverse all
        uint64_t length = syli_object_length(obj);
        syli_state.releasing_budget -= (int)length;
        for (uint64_t i = 0; i < length; i++) {
            uint64_t field_value = gc_obj->value[i];
            if (!field_value) {
                continue;
            }
            child_release_object(((Object*)field_value));
        }
    } else if (syli_object_is_mixed_bitmap(obj)) {
        // All fields are references, traverse all
        uint64_t length = syli_object_length(obj);
        uint32_t bitmap = syli_object_bitmap_bits(obj);
        syli_state.releasing_budget -= (int)length;
        for (uint64_t i = 0; i < length; i++) {
            if (bitmap & (1 << i)) {
                continue; // non-reference field
            }
            uint64_t field_value = gc_obj->value[i];
            if (!field_value) {
                continue;
            }
            child_release_object(((Object*)field_value));
        }
    } else if (syli_object_is_mixed_order(obj)) {
        // All fields are references, traverse all
        size_t ptr_count = syli_object_order_ptr_count(obj);
        syli_state.releasing_budget -= (int)ptr_count;
        for (size_t i = 0; i < ptr_count; i++) {
            uint64_t field_value = gc_obj->value[i];
            if (!field_value) {
                continue;
            }
            child_release_object(as_object((GCObject*)field_value));
        }
    }

    assert((gc_obj->meta_ref_count & REFCOUNT_MASK) == 0);
    free_released_object(obj);
}

void set_releasing_working()
{
    vector_GCObject tmp = syli_state.releasing_worklist;
    syli_state.releasing_worklist = syli_state.releasing_waitlist;
    syli_state.releasing_waitlist = tmp;
    vector_clear_GCObject(&syli_state.releasing_waitlist);
}

void syli_state_gc_releasing()
{
    while (1) {

        if (syli_state.releasing_budget <= 0) {
            return; // Out of budget for this cycle
        }

        switch (syli_state.releasing_state) {
        case Releasing_Idle:

            if (vector_size_GCObject(&syli_state.releasing_waitlist)
                < syli_state.THRESHOLD_RELEASING_BUCKET) {
                return; // Not enough objects to release
            }

            set_releasing_working();

            syli_state.releasing_state = Releasing;

            break;
        case Releasing:
            gc_one_step_releasing();
            syli_state.releasing_steps++;

            if (vector_size_GCObject(&syli_state.releasing_worklist) == 0) {
                syli_state.releasing_state = Releasing_Idle;
            }
            break;
        }
    }
}