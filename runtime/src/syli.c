#include "syli/syli.h"
#include "syli/syli_state.h"

#include "syli/gc_helpers.h"
#include "syli/header_object.h"
#include "syli/object.h"
#include <stdio.h>

GCObject* syli_rt_rc_alloc_object(
    object_header_t header, size_t refcount, size_t words)
{
    // Tag the object with the current generation's mark value
    uint64_t meta_ref_count = refcount | syli_state.tracing_current_bit_mark;

    GCObject* obj = (GCObject*)syli_object_alloc(header, meta_ref_count, words);

    // Initialize the object fields to 0
    // TODO: this will be removed once put in the language level
    //       the initialization is handled by the compiler
    for (size_t i = 0; i < words; i++) {
        obj->value[i] = 0;
    }

    return obj;
}

void syli_rt_object_incr(Object* obj)
{
    ObjectZone zone = syli_object_get_zone(obj);

    // Static: nothing to do
    if (zone == Zone_Static)
        return;

    if (zone == Zone_GcLocal) {
        GCObject* local_obj = as_gc_object(obj);
        local_obj->meta_ref_count++;
        return;
    }
}

void syli_rt_object_decr(Object* obj, obj_ptr obj_ptr)
{
    assert(obj != NULL);
    ObjectZone zone = syli_object_get_zone(obj);

    if (zone == Zone_Static)
        return;

    if (zone == Zone_GcLocal) {
        GCObject* local_obj = as_gc_object(obj);
        local_obj->meta_ref_count--;

        if (syli_object_refcount(obj) == 0) {
            if (syli_object_is_mono_imm(obj)) {
                syli_state.total_objects_memory_freed++;

                // Freeing an object that is not cyclic and has no value pointer
                free(obj);
                return;
            }
            gc_vector_push_back(&syli_state.releasing_waitlist, obj_ptr);
            return;
        } else if (syli_object_is_cyclic(obj)) {
            gc_add_suspect(obj_ptr);
        }
    }
}

void syli_rt_object_decr_n(Object* obj, int n)
{
    ObjectZone zone = syli_object_get_zone(obj);

    if (zone == Zone_Static)
        return;

    if (zone == Zone_GcLocal) {
        GCObject* local_obj = as_gc_object(obj);
        syli_object_decr_local_n((Object*)local_obj, n);
        return;
    }
}

void syli_rt_object_check_lost_cyclic_release(Object* obj, obj_ptr ptr)
{
    assert(obj != NULL);

    ObjectZone zone = syli_object_get_zone(obj);

    if (zone == Zone_GcLocal && syli_object_refcount(obj) > 0) {
        gc_add_suspect(ptr);
    }
}

uint64_t syli_rt_get_object_tag(Object* obj)
{
    assert(obj != NULL);
    return syli_object_get_variant_tag(obj);
}

uint64_t syli_rt_get_object_length(Object* obj)
{
    assert(obj != NULL);
    return syli_object_length(obj);
}

Object* syli_rt_object_copy(Object* src)
{
    assert(src != NULL);

    ObjectZone src_zone = syli_object_get_zone(src);

    if (src_zone == Zone_GcLocal) {
        GCObject* src_local     = as_gc_object(src);
        size_t length           = syli_object_length(src);
        object_header_t header  = src_local->header_word;
        uint64_t meta_ref_count = src_local->meta_ref_count;

        GCObject* dst
            = (GCObject*)syli_object_alloc(header, meta_ref_count, length);

        uint64_t* data_src = src_local->value;
        uint64_t* data_dst = dst->value;
        for (size_t i = 0; i < length; i++) {
            data_dst[i] = data_src[i];
        }

        // Increment refcounts for pointer/reference fields in the new copy
        ObjectType obj_type = syli_object_type(src);
        if (obj_type == Type_MonoRef) {
            // All fields are pointers
            for (size_t i = 0; i < length; i++) {
                Object* ref = (Object*)data_dst[i];
                if (ref != NULL) {
                    syli_rt_object_incr(ref);
                }
            }
        } else if (obj_type == Type_MixedOrder) {
            // First ptr_count fields are pointers
            size_t ptr_count = syli_object_order_ptr_count(src);
            for (size_t i = 0; i < ptr_count; i++) {
                Object* ref = (Object*)data_dst[i];
                if (ref != NULL) {
                    syli_rt_object_incr(ref);
                }
            }
        } else if (obj_type == Type_MixedBitmap) {
            // Bitmap encodes which fields are pointers
            uint32_t bitmap = syli_object_bitmap_bits(src);
            for (size_t i = 0; i < length; i++) {
                if (bitmap & (1u << i)) {
                    Object* ref = (Object*)data_dst[i];
                    if (ref != NULL) {
                        syli_rt_object_incr(ref);
                    }
                }
            }
        }
        // Type_MonoImm: no pointer fields, nothing to do

        return as_object(dst);
    }

    return NULL;
}

void syli_rt_object_raw_copy(Object* src, Object* dst)
{
    assert(src != NULL && dst != NULL);

    ObjectZone src_zone = syli_object_get_zone(src);

    if (src_zone == Zone_GcLocal) {
        GCObject* src_local       = as_gc_object(src);
        GCObject* dst_local       = as_gc_object(dst);
        dst_local->header_word    = src_local->header_word;
        dst_local->meta_ref_count = src_local->meta_ref_count;

        size_t length      = syli_object_length(src);
        uint64_t* data_src = src_local->value;
        uint64_t* data_dst = dst_local->value;
        for (size_t i = 0; i < length; i++) {
            data_dst[i] = data_src[i];
        }
    }
}

void syli_rt_object_notify_mutation(
    Object* obj, Object* target, obj_ptr target_ptr)
{
    assert(obj != NULL && target != NULL);

    if (!gc_is_object_mark_tagged(obj)) {
        return;
    }

    // TODO: make this as assert since only treceable objects will be notified.
    if (!syli_object_is_traceable(obj)) {
        return;
    }

    if (gc_is_object_mark_tagged(target)) {
        return;
    }

    gc_mark_tag_object(
        target); // mark the target as marked to avoid multiple notifications
                 // for the same object in the same tracing cycle
    gc_vector_push_back(&syli_state.tracing_mutations_worklist, target_ptr);
}

void syli_rt_gc_cycle() { syli_state_gc_cycle(); }

/************************************************
 * Ownership Tag Primitives
 ************************************************/

obj_ptr syli_rt_ownership_alloc_object(
    object_header_t header, size_t refcount, size_t words)
{
    GCObject* obj = syli_rt_rc_alloc_object(header, refcount, words);
    return syli_ownership_set_own(obj);
}

obj_ptr syli_rt_ownership_share(obj_ptr ptr)
{
    assert(syli_ownership_untag(ptr) != NULL);
    Object* obj = (Object*)syli_ownership_untag(ptr);
    assert(obj != NULL);
    syli_rt_object_incr(obj);
    return syli_ownership_set_own(ptr);
}

void syli_rt_ownership_decr(obj_ptr ptr)
{
    assert(syli_ownership_is_own_ref(ptr));
    Object* obj = (Object*)syli_ownership_untag(ptr);
    assert(obj != NULL);
    syli_rt_object_decr(obj, ptr);
}

obj_ptr syli_rt_ownership_untag(obj_ptr ptr)
{
    return syli_ownership_untag(ptr);
}

void syli_rt_ownership_incr(obj_ptr ptr)
{
    assert(syli_ownership_is_own_ref(ptr));
    Object* obj = (Object*)syli_ownership_untag(ptr);
    assert(obj != NULL);
    syli_rt_object_incr(obj);
}

void syli_rt_ownership_check_lost_cyclic_release(obj_ptr ptr)
{
    Object* obj = syli_object_of_obj_ptr(ptr);
    syli_rt_object_check_lost_cyclic_release(obj, ptr);
}

void syli_rt_ownership_notify_mutation(obj_ptr ptr, obj_ptr target_ptr)
{
    if ((syli_state.tracing_state == Tracing
            || syli_state.tracing_state == Mutation_Prepare)
        && syli_ownership_is_own_ref(ptr)) {
        Object* obj    = syli_object_of_obj_ptr(ptr);
        Object* target = syli_object_of_obj_ptr(target_ptr);
        syli_rt_object_notify_mutation(obj, target, target_ptr);
    }
}

void syli_rt_ownership_release(void* ptr)
{
    if (syli_ownership_is_own_ref(ptr)) {
        assert(syli_ownership_is_own_ref(ptr));
        Object* obj = (Object*)syli_ownership_untag(ptr);
        assert(obj != NULL);
        syli_rt_object_decr(obj, ptr);
    }
}

obj_ptr syli_rt_ownership_own(obj_ptr ptr)
{
    if (syli_ownership_is_own_ref(ptr)) {
        return ptr;
    }
    Object* obj = (Object*)syli_ownership_untag(ptr);
    assert(obj != NULL);
    syli_rt_object_incr(obj);
    return syli_ownership_set_own(obj);
}

obj_ptr syli_rt_ownership_borrow(obj_ptr ptr)
{
    return syli_ownership_untag(ptr);
}