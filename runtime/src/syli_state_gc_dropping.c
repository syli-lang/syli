#include <assert.h>
#include <stdio.h>

#include "syli/gc_helpers.h"
#include "syli/object.h"

#include "syli/syli_state.h"

static inline void free_dropping_object(Object* obj)
{
    // A dropping object will never be reachable from roots.
    // Those objects are proven non escaped.
    assert(syli_object_has_flags(obj, Meta_Flags_Suspect_Lost_Cycle) == 0);
    assert(syli_object_has_flags(obj, Meta_Flags_Releasing) == 0);
    assert(syli_object_has_flags(obj, Meta_Flags_Tracing) == 0);

    if (syli_object_has_flags(obj, Meta_Flags_Tracing)) {
        gc_vector_push_back(&syli_state.dropping_waitlist, obj);
        return;
    }

    syli_state.total_objects_memory_freed++;
    free(obj);
}

static inline void child_dropping_object(Object* obj)
{
    assert(obj != NULL);

    syli_object_decr(obj);

    // No need to check ref count since the object will be popped
    // from the dropping worklist.
}

static inline void gc_one_step_dropping()
{
    syli_state.dropping_budget--;
    Object* obj = gc_vector_pop_back(&syli_state.dropping_worklist);
    GCObject* gc_obj = as_gc_object(obj);

    // when an object is referenced by its sibbling in the scope.
    if (syli_object_has_flags(obj, Meta_Flags_Waiting_Remove)
        && (gc_obj->meta_ref_count & REFCOUNT_MASK) == 0) {
        free(obj);
        return;
    } else if (syli_object_has_flags(obj, Meta_Flags_Waiting_Remove)) {
        gc_vector_push_back(&syli_state.dropping_waitlist, obj);
        return;
    }

    if (syli_object_is_mono_ref(obj)) {
        // All fields are references, traverse all
        uint64_t length = syli_object_length(obj);
        syli_state.dropping_budget -= (int)length;
        for (uint64_t i = 0; i < length; i++) {
            uint64_t field_value = gc_obj->value[i];
            if (!field_value) {
                continue;
            }
            child_dropping_object(((Object*)field_value));
        }
    } else if (syli_object_is_mixed_bitmap(obj)) {
        // All fields are references, traverse all
        uint64_t length = syli_object_length(obj);
        uint32_t bitmap = syli_object_bitmap_bits(obj);
        syli_state.dropping_budget -= (int)length;
        for (uint64_t i = 0; i < length; i++) {
            if (bitmap & (1 << i)) {
                continue; // non-reference field
            }
            uint64_t field_value = gc_obj->value[i];
            if (!field_value) {
                continue;
            }
            child_dropping_object(((Object*)field_value));
        }
    } else if (syli_object_is_mixed_order(obj)) {
        // All fields are references, traverse all
        size_t ptr_count = syli_object_order_ptr_count(obj);
        syli_state.dropping_budget -= (int)ptr_count;
        for (size_t i = 0; i < ptr_count; i++) {
            uint64_t field_value = gc_obj->value[i];
            if (!field_value) {
                continue;
            }
            child_dropping_object(((Object*)field_value));
        }
    }

    // we free the object because all children have been processed
    if ((gc_obj->meta_ref_count & REFCOUNT_MASK) == 0) {
        free_dropping_object(obj);
    } else {
        // when an object is referenced by its sibbling in the scope, we set it
        // to waiting remove and put it in dropping waitlist.
        gc_vector_push_back(&syli_state.dropping_waitlist, obj);
        syli_object_set_flags(obj, Meta_Flags_Waiting_Remove);
    }
}

void set_dropping_working()
{
    vector_GCObject tmp = syli_state.dropping_worklist;
    syli_state.dropping_worklist = syli_state.dropping_waitlist;
    syli_state.dropping_waitlist = tmp;
    vector_clear_GCObject(&syli_state.dropping_waitlist);
}

void syli_state_gc_dropping()
{
    while (1) {

        if (syli_state.dropping_budget <= 0) {
            return; // Out of budget for this cycle
        }

        switch (syli_state.dropping_state) {
        case Dropping_Idle:

            if (vector_size_GCObject(&syli_state.dropping_waitlist)
                < syli_state.THRESHOLD_DROPPING_BUCKET) {
                return; // Not enough objects to drop
            }

            set_dropping_working();
            syli_state.dropping_state = Dropping;

            break;
        case Dropping:
            gc_one_step_dropping();
            syli_state.dropping_steps++;

            if (vector_size_GCObject(&syli_state.dropping_worklist) == 0) {
                syli_state.dropping_state = Dropping_Idle;
            }
            break;
        }
    }
}
