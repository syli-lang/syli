#ifndef SYLI_OBJECT_H
#define SYLI_OBJECT_H

#include <assert.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "header_object.h" // header layout, masks, ObjectZone, ObjectFlags

#define INITIAL_REFCOUNT 1
#define REFCOUNT_SIZE_BITS 56
#define FLAGS_SHIFT REFCOUNT_SIZE_BITS

#define REFCOUNT_MASK 0x00FFFFFFFFFFFFFF
#define MASK_MARKING_BIT (1ULL << 63)
#define MARKING_SHIFT 63

#define META_FLAGS_MASK                                                        \
    (0x7F00000000000000ULL) // bits 56-62 (7 bits for meta flags)

/* ============================================================
 * Object types

 The meta refcount layout (64 bits):
 * Bits 63     : MARKING BIT (1 bit)
 * Bits 56–62  : FLAGS (7 bits)
 * Bits 0–55   : REFCOUNT (56 bits)
 * ============================================================ */

typedef struct GCObject {
    uint64_t header_word; // immutable: zone/type/length
    uint64_t meta_ref_count; // mutable: flags + reference count
    uint64_t value[];
} GCObject;

typedef struct StaticObject {
    uint64_t header_word;
    uint64_t value[];
} StaticObject;

typedef struct StackObject {
    uint32_t length;
    uint64_t value[];
} StackObject;

// - Dropping & Releasing are mutually exclusive
// - Tracing object inside tracing worklist:
//     - Could be inside dropping at the same time
//     - Could be inside releasing at the same time
typedef enum ObjectMetaFlags {
    Meta_Flags_None = 0,
    Meta_Flags_Suspect_Lost_Cycle = 1ULL << 56,
    Meta_Flags_Releasing = 1ULL << (56 + 1),
    Meta_Flags_Dropping = 1ULL << (56 + 2),
    Meta_Flags_Tracing = 1ULL << (56 + 3),
    Meta_Flags_Waiting_Remove = 1ULL << (56 + 4)
} ObjectMetaFlags;

static inline uint64_t make_meta_refcount(
    uint64_t current_state_bit_mark, ObjectMetaFlags flags)
{
    assert(flags == Meta_Flags_None || flags == Meta_Flags_Suspect_Lost_Cycle
        || flags == Meta_Flags_Releasing || flags == Meta_Flags_Dropping
        || flags == Meta_Flags_Tracing
        || flags == Meta_Flags_Waiting_Remove); // 5-bit flags
    return (current_state_bit_mark) | ((uint64_t)flags) | INITIAL_REFCOUNT;
}

/* ============================================================
 * Type casting helpers
 * ============================================================ */

static inline GCObject* as_gc_object(Object* o)
{
    assert(o != NULL);
    return (GCObject*)o;
}

static inline Object* as_object(void* o) { return (Object*)o; }

/* ============================================================
 * Marking bit manipulation
 * ============================================================ */

static inline uint64_t syli_object_mark_tag_shift(Object* obj)
{
    GCObject* gc_obj = as_gc_object(obj);
    ObjectZone zone = syli_object_get_zone(obj);
    if (zone == Zone_GcLocal) {
        return gc_obj->meta_ref_count & MASK_MARKING_BIT;
    } else if (zone == Zone_GcShared) {
        return atomic_load((_Atomic uint64_t*)&gc_obj->meta_ref_count)
            & MASK_MARKING_BIT;
    } else {
        return 0;
    }
}

/* ============================================================
 * Object flag manipulation
 * ============================================================ */

static inline void syli_object_set_flags(Object* o, ObjectMetaFlags flags)
{
    assert(o != NULL);
    switch (syli_object_get_zone(o)) {
    case Zone_GcLocal: {
        GCObject* gc_obj = as_gc_object(o);
        gc_obj->meta_ref_count |= ((uint64_t)flags);
        break;
    }
    case Zone_GcShared: {
        GCObject* gc_obj = as_gc_object(o);
        uint64_t old_meta;
        uint64_t new_meta;
        do {
            old_meta = atomic_load((_Atomic uint64_t*)&gc_obj->meta_ref_count);
            new_meta = old_meta | ((uint64_t)flags);
        } while (!atomic_compare_exchange_weak(
            (_Atomic uint64_t*)&gc_obj->meta_ref_count, &old_meta, new_meta));
        break;
    }
    default:
        break;
    }
}

static inline bool syli_object_has_flags(Object* o, ObjectMetaFlags flags)
{
    assert(o != NULL);
    switch (syli_object_get_zone(o)) {
    case Zone_GcLocal: {
        GCObject* gc_obj = as_gc_object(o);
        return (gc_obj->meta_ref_count & ((uint64_t)flags))
            == ((uint64_t)flags);
    }
    case Zone_GcShared: {
        GCObject* gc_obj = as_gc_object(o);
        return (atomic_load((_Atomic uint64_t*)&gc_obj->meta_ref_count)
                   & ((uint64_t)flags))
            == ((uint64_t)flags);
    }
    default:
        return 0;
    }
}

static inline void syli_object_clear_flags(Object* o, ObjectMetaFlags flags)
{
    assert(o != NULL);
    switch (syli_object_get_zone(o)) {
    case Zone_GcLocal: {
        GCObject* gc_obj = as_gc_object(o);
        gc_obj->meta_ref_count &= ~((uint64_t)flags);
        break;
    }
    case Zone_GcShared: {
        GCObject* gc_obj = as_gc_object(o);
        uint64_t old_meta;
        uint64_t new_meta;
        do {
            old_meta = atomic_load((_Atomic uint64_t*)&gc_obj->meta_ref_count);
            new_meta = old_meta & ~((uint64_t)flags);
        } while (!atomic_compare_exchange_weak(
            (_Atomic uint64_t*)&gc_obj->meta_ref_count, &old_meta, new_meta));
        break;
    }
    default:
        break;
    }
}

/* ============================================================
 * Reference counting
 * ============================================================ */

static inline uint64_t syli_object_refcount(Object* o)
{
    assert(o != NULL);
    switch (syli_object_get_zone(o)) {
    case Zone_GcLocal: {
        GCObject* gc_obj = as_gc_object(o);
        return gc_obj->meta_ref_count & REFCOUNT_MASK;
    }
    case Zone_GcShared: {
        GCObject* gc_obj = as_gc_object(o);
        return atomic_load((_Atomic uint64_t*)&gc_obj->meta_ref_count)
            & REFCOUNT_MASK;
    }
    default:
        return 0;
    }
}

static inline void syli_object_incr_local(Object* o)
{
    assert(o != NULL);
    GCObject* gc_obj = as_gc_object(o);
    gc_obj->meta_ref_count++;
}

static inline void syli_object_decr_local(Object* o)
{
    assert(o != NULL);
    GCObject* gc_obj = as_gc_object(o);

    assert((gc_obj->meta_ref_count & REFCOUNT_MASK) > 0);
    gc_obj->meta_ref_count--;
}

static inline void syli_object_decr_local_n(Object* o, size_t n)
{
    assert(o != NULL);
    GCObject* gc_obj = as_gc_object(o);

    assert((gc_obj->meta_ref_count & REFCOUNT_MASK) >= n);
    gc_obj->meta_ref_count -= n;
}

static inline void syli_object_incr_shared(Object* o)
{
    assert(o != NULL);
    GCObject* gc_obj = as_gc_object(o);
    atomic_fetch_add((_Atomic uint64_t*)&gc_obj->meta_ref_count, 1);
}

static inline void syli_object_decr_shared(Object* o)
{
    assert(o != NULL);
    GCObject* gc_obj = as_gc_object(o);

    assert((gc_obj->meta_ref_count & REFCOUNT_MASK) > 0);
    atomic_fetch_sub((_Atomic uint64_t*)&gc_obj->meta_ref_count, 1);
}

static inline void syli_object_decr_shared_n(Object* o, size_t n)
{
    assert(o != NULL);
    GCObject* gc_obj = as_gc_object(o);
    
    assert((gc_obj->meta_ref_count & REFCOUNT_MASK) >= n);
    atomic_fetch_sub((_Atomic uint64_t*)&gc_obj->meta_ref_count, n);
}

static inline void syli_object_incr(Object* o)
{
    assert(o != NULL);
    switch (syli_object_get_zone(o)) {
    case Zone_GcLocal:
        syli_object_incr_local(o);
        break;
    case Zone_GcShared:
        syli_object_incr_shared(o);
        break;
    default:
        break;
    }
}

static inline void syli_object_decr(Object* o)
{
    assert(o != NULL);
    switch (syli_object_get_zone(o)) {
    case Zone_GcLocal:
        syli_object_decr_local(o);
        break;
    case Zone_GcShared:
        syli_object_decr_shared(o);
        break;
    default:
        break;
    }
}

static inline void syli_object_decr_n(Object* o, size_t n)
{
    assert(o != NULL);
    switch (syli_object_get_zone(o)) {
    case Zone_GcLocal:
        syli_object_decr_local_n(o, n);
        break;
    case Zone_GcShared:
        syli_object_decr_shared_n(o, n);
        break;
    default:
        break;
    }
}

/* ============================================================
 * Object creation
 * ============================================================ */

static inline Object* syli_object_alloc(
    object_header_t header, uint64_t meta_ref_count, size_t words)
{
    int cyclic_index = 0;
    if ((header & GC_CYCLIC_MASK)) {
        cyclic_index = sizeof(uint32_t);
    }

    GCObject* obj = (GCObject*)malloc(
        sizeof(GCObject) + words * sizeof(uint64_t) + cyclic_index);

    obj->header_word = header;
    obj->meta_ref_count = meta_ref_count;
    return as_object(obj);
}

static inline uint64_t* syli_object_data(Object* obj)
{
    assert(obj != NULL);
    const ObjectZone zone = syli_object_get_zone(obj);
    switch (zone) {
    case Zone_GcLocal:
    case Zone_GcShared:
        return as_gc_object(obj)->value;
    case Zone_Static:
        return ((StaticObject*)obj)->value;
    default:
        return NULL;
    }
}

static inline void syli_object_set_cyclic_index(GCObject* obj, uint32_t index)
{
    assert(obj != NULL);
    assert(syli_object_is_cyclic(as_object(obj)));
    const ObjectZone zone = syli_object_get_zone((Object*)obj);
    switch (zone) {
    case Zone_GcLocal:
    case Zone_GcShared: {
        size_t len = syli_object_length(as_object((void*)obj));
        uint32_t* cyclic_index_ptr = (uint32_t*)(obj->value + len);
        *cyclic_index_ptr = index;
        break;
    }
    default:
        break;
    }
}

static inline uint32_t syli_object_get_cyclic_index(GCObject* obj)
{
    assert(obj != NULL);
    assert(syli_object_is_cyclic(as_object(obj)));
    const ObjectZone zone = syli_object_get_zone((Object*)obj);
    switch (zone) {
    case Zone_GcLocal:
    case Zone_GcShared: {
        size_t len = syli_object_length(as_object(obj));
        uint32_t* cyclic_index_ptr = (uint32_t*)(obj->value + len);
        return *cyclic_index_ptr;
    }
    default:
        return 0;
    }
}

#endif /* SYLI_OBJECT_H */