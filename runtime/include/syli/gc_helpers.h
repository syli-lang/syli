#include "syli/object.h"
#include "syli/syli_state.h"

static inline void gc_add_suspect(obj_ptr obj_ptr)
{
    Object* obj = syli_object_of_obj_ptr(obj_ptr);
    syli_state.suspect_objects_notifications++;
    if (syli_object_has_flags(as_object(obj), Meta_Flags_Suspect_Lost_Cycle)) {
        return;
    }
    Suspected* suspected_obj
        = vector_alloc_slot_Suspected(&syli_state.suspect_lost_cycle);
    suspected_obj->obj = obj_ptr;
    size_t last_index
        = vector_size_Suspected(&syli_state.suspect_lost_cycle) - 1;

    syli_object_set_cyclic_index(as_gc_object(obj), (uint32_t)last_index);
    syli_object_set_flags(as_object(obj), Meta_Flags_Suspect_Lost_Cycle);
}

static inline void gc_remove_suspect_at(size_t index)
{
    vector_Suspected* vector = &syli_state.suspect_lost_cycle;
    size_t last              = vector_size_Suspected(vector) - 1;
    if (index != last) {
        Suspected* data      = (Suspected*)vector_at_Suspected(vector, index);
        Suspected* last_data = (Suspected*)vector_at_Suspected(vector, last);
        *data                = *last_data;
    }
    vector_pop_back_Suspected(vector);
}

static inline obj_ptr gc_vector_pop_back(vector_obj_ptr* vector)
{
    assert(
        vector_size_obj_ptr(vector) > 0 && "pop_stack called on empty vector");
    obj_ptr* back = (obj_ptr*)vector_back_obj_ptr(vector);
    obj_ptr obj   = *back;
    vector_pop_back_obj_ptr(vector);
    return obj;
}

static inline void gc_vector_push_back(vector_obj_ptr* vector, obj_ptr obj)
{
    obj_ptr* slot = (obj_ptr*)vector_alloc_slot_obj_ptr(vector);
    *slot         = obj;
}

static inline void gc_tracing_worklist_push(obj_ptr obj_p)
{
    if (!syli_ownership_is_own_ref(obj_p)) {
        return;
    }
    Object* child = syli_object_of_obj_ptr(obj_p);
    if (syli_object_has_flags(child, Meta_Flags_Tracing)) {
        return;
    }
    syli_object_set_flags(child, Meta_Flags_Tracing);
    gc_vector_push_back(&syli_state.tracing_worklist, obj_p);
}

// ========================
// Object marking bit management
// ========================

static inline void gc_next_marking_generation(void)
{
    // Toggle the marking bit for the next tracing generation
    syli_state.tracing_current_bit_mark ^= MASK_MARKING_BIT;
    syli_state.tracing_generations++;
}

static inline void gc_mark_tag_object(Object* obj)
{
    GCObject* gc_obj       = as_gc_object(obj);
    gc_obj->meta_ref_count = (gc_obj->meta_ref_count & ~MASK_MARKING_BIT)
        | syli_state.tracing_current_bit_mark;
}

static inline bool gc_is_object_mark_tagged(Object* obj)
{
    return (as_gc_object(obj)->meta_ref_count & MASK_MARKING_BIT)
        == syli_state.tracing_current_bit_mark;
}