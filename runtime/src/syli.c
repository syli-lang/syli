#include "syli/syli.h"
#include "syli/syli_state.h"

#include "syli/gc_helpers.h"
#include "syli/header_object.h"
#include "syli/object.h"

GCObject* syli_rt_rc_alloc_object(
    object_header_t header, size_t refcount, size_t words)
{
    uint64_t meta_ref_count
        = refcount | (syli_state.tracing_current_bit_mark & MASK_MARKING_BIT);

    // Tag the object as marked
    meta_ref_count |= syli_state.tracing_current_bit_mark;

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

void syli_rt_object_decr(Object* obj)
{
    ObjectZone zone = syli_object_get_zone(obj);

    if (zone == Zone_Static)
        return;

    if (zone == Zone_GcLocal) {
        GCObject* local_obj = as_gc_object(obj);
        local_obj->meta_ref_count--;
        return;
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

void syli_rt_object_check_release(Object* obj)
{
    assert(obj != NULL);

    ObjectZone zone = syli_object_get_zone(obj);

    if (zone == Zone_Static) {
        return;
    }

    if (syli_object_refcount(obj) == 0) {
        // Add to releasing worklist
        gc_vector_push_back(&syli_state.releasing_waitlist, obj);
    }
}

void syli_rt_object_decr_drop(Object* obj)
{
    assert(obj != NULL);

    ObjectZone zone = syli_object_get_zone(obj);

    if (zone == Zone_Static) {
        return;
    }

    if (zone == Zone_GcLocal) {
        // Add to dropping worklist
        gc_vector_push_back(&syli_state.dropping_waitlist, obj);
        return;
    }
}

void syli_rt_object_check_lost_cyclic_release(Object* obj)
{
    assert(obj != NULL);

    ObjectZone zone = syli_object_get_zone(obj);

    if (zone == Zone_GcLocal && syli_object_refcount(obj) > 0) {
        gc_add_suspect(obj);
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
        GCObject* src_local = as_gc_object(src);
        size_t length = syli_object_length(src);
        object_header_t header = src_local->header_word;
        uint64_t meta_ref_count = src_local->meta_ref_count;

        GCObject* dst = (GCObject*)syli_object_alloc(header, meta_ref_count, length);

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

void syli_rt_object_notify_mutation(Object* obj, Object* target)
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
    gc_vector_push_back(&syli_state.tracing_mutations_worklist, target);
}

void syli_rt_gc_cycle() { syli_state_gc_cycle(); }
