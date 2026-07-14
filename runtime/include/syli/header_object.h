#ifndef SYLI_HEADER_OBJECT_H
#define SYLI_HEADER_OBJECT_H

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* ============================================================
 * LEVEL-0 ARC HEADER LAYOUT (64 bits)
 * ============================================================
 *
 * Bits  63–62   : ZONE (2)
 *               00 = local
 *               01 = shared
 *               10 = static
 *               11 = reserved
 *
 * Bit     61    : CYCLIC
 *               0 = acyclic
 *               1 = cyclic
 *
 * Bits  60–59   : TYPE (2)
 *               00 = mono_imm
 *               01 = multi-order
 *               10 = multi-bitmap
 *               11 = mono_ref
 *
 *              : IMMUTABLE FLAGS
 * Bits 58      - HasFinalizer
 * Bits 57      - HasPointers
 *
 * Bit 56       : Traceable (an object directly or indirectly refers to a cyclic object)
 *
 * Bits 55-48   : Variant type flags (8 bits) (256 variants)
 *
 * Bits 47–31   : Reserved for future use
 *
 * Bits  32-0  :
 *   PAYLOAD (32)   ← immutable
 *     mono:       length (32 bits)
 *     multi-order: arity (32 bits) (16 bits pointers + 16 bits non-pointers)
 *     multi-bitmap: length (5 bits) + bitmap (27 bits)
 *     all-ref: length (32 bits)
 */

typedef uint64_t object_header_t;
typedef uint32_t object_payload_t;

/* ============================================================
 * Bit Masks and Shifts
 * ============================================================ */

/* Field masks */
#define GC_ZONE_MASK            (0x3ULL << 62) // bits 63-62
#define GC_CYCLIC_MASK          (0x1ULL << 61) // bit 61
#define GC_TYPE_MASK            (0x3ULL << 59) // bits 60-59
#define GC_HAS_FINALIZER_MASK   (0x1ULL << 58) // bit 58
#define GC_HAS_POINTERS_MASK    (0x1ULL << 57) // bit 57
#define GC_TRACEABLE_MASK       (0x1ULL << 56) // bit 56
#define GC_VARIANT_FLAGS_MASK   (0xFFULL << 48) // bits 55-48
#define GC_IMMUTABLE_FLAGS_MASK (0x3ULL << 57) // bits 58-57
#define GC_PAYLOAD_MASK         0xFFFFFFFFULL // bits 31-0

#define GC_BITMAP_LENGTH_MASK    0x1FUL // bits 0-4 (5 bits)
#define GC_BITMAP_BITS_SHIFT     5 // bitmap starts at bit 5
#define GC_ORDER_PTR_COUNT_MASK  0xFFFFULL
#define GC_ORDER_IMM_COUNT_MASK  (0xFFFFULL << 16)
#define GC_ORDER_PTR_COUNT_SHIFT 0
#define GC_ORDER_IMM_COUNT_SHIFT 16

/* ============================================================
 * Type Definitions
 * ============================================================ */

typedef enum ObjectZone {
    Zone_GcLocal   = 0ULL << 62,
    Zone_GcShared  = 1ULL << 62,
    Zone_Static    = 2ULL << 62,
    Zone_Reserved2 = 3ULL << 62,
} ObjectZone;

typedef enum ObjectType {
    Type_MonoImm     = 0ULL << 59,
    Type_MonoRef     = 1ULL << 59,
    Type_MixedOrder  = 2ULL << 59,
    Type_MixedBitmap = 3ULL << 59,
} ObjectType;

typedef enum ObjectImmutableFlag {
    Flag_None         = 0ULL,
    Flag_Traceable    = 1ULL << 56,
    Flag_HasPointers  = 1ULL << 57,
    Flag_HasFinalizer = 1ULL << 58,
} ObjectImmutableFlag;

typedef enum CyclicFlag {
    Acyclic = 0ULL << 61,
    Cyclic  = 1ULL << 61,
} CyclicFlag;

typedef struct Object {
    object_header_t header_word;
} Object;

/* ============================================================
 * Constants
 * ============================================================ */

#define SHARED Zone_GcShared
#define LOCAL  Zone_GcLocal

/* ============================================================
 * Header Construction
 * ============================================================ */

static inline uint64_t syli_object_make_header(ObjectZone zone,
    CyclicFlag cyclic, ObjectType type, ObjectImmutableFlag imm_flags,
    object_payload_t payload)
{
    assert(
        zone == Zone_GcLocal || zone == Zone_GcShared || zone == Zone_Static);
    assert(cyclic == Cyclic || cyclic == Acyclic);
    assert(type == Type_MonoImm || type == Type_MonoRef
        || type == Type_MixedOrder || type == Type_MixedBitmap);

    return ((uint64_t)zone | (uint64_t)cyclic | (uint64_t)type
        | (uint64_t)imm_flags | ((uint64_t)payload & GC_PAYLOAD_MASK));
}

static inline uint32_t syli_object_make_mono_payload(size_t length)
{
    assert(length < (1ULL << 32));
    return length;
}

static inline uint32_t syli_object_make_order_payload(
    size_t ptr_count, size_t imm_count)
{
    assert(ptr_count < (1ULL << 16));
    assert(imm_count < (1ULL << 16));
    return (ptr_count << GC_ORDER_PTR_COUNT_SHIFT)
        | (imm_count << GC_ORDER_IMM_COUNT_SHIFT);
}

static inline uint32_t syli_object_make_bitmap_payload(
    uint8_t length, uint32_t bitmap)
{
    assert(length < (1UL << 5));
    assert(bitmap < (1UL << 27));
    return (uint32_t)length | (bitmap << GC_BITMAP_BITS_SHIFT);
}

/* ============================================================
 * Zone Extraction
 * ============================================================ */

static inline ObjectZone syli_object_get_zone(Object* o)
{
    return (ObjectZone)(o->header_word & GC_ZONE_MASK);
}

static inline bool syli_object_is_local(Object* o)
{
    return (o->header_word & GC_ZONE_MASK) == Zone_GcLocal;
}

static inline bool syli_object_is_shared(Object* o)
{
    return (o->header_word & GC_ZONE_MASK) == Zone_GcShared;
}

/* ============================================================
 * Cyclic Flag
 * ============================================================ */

static inline bool syli_object_is_cyclic(Object* o)
{
    return (o->header_word & GC_CYCLIC_MASK) != 0;
}

static inline bool syli_object_is_acyclic(Object* o)
{
    return (o->header_word & GC_CYCLIC_MASK) == 0;
}

static inline bool syli_object_has_finalizer(Object* o)
{
    return (o->header_word & GC_HAS_FINALIZER_MASK) != 0;
}

static inline bool syli_object_has_pointers(Object* o)
{
    return (o->header_word & GC_HAS_POINTERS_MASK) != 0;
}

static inline ObjectImmutableFlag syli_object_get_immutable_flags(Object* o)
{
    return (ObjectImmutableFlag)(o->header_word & GC_IMMUTABLE_FLAGS_MASK);
}

static inline bool syli_object_is_traceable(Object* o)
{
    return (o->header_word & GC_TRACEABLE_MASK) != 0;
}

/* ============================================================
 * Type Extraction
 * ============================================================ */

static inline ObjectType syli_object_type(Object* o)
{
    return (ObjectType)(o->header_word & GC_TYPE_MASK);
}

static inline bool syli_object_is_mono_imm(Object* o)
{
    return (o->header_word & GC_TYPE_MASK) == Type_MonoImm;
}

static inline bool syli_object_is_mono_ref(Object* o)
{
    return (o->header_word & GC_TYPE_MASK) == Type_MonoRef;
}

static inline bool syli_object_is_mono(Object* o)
{
    return syli_object_is_mono_imm(o) || syli_object_is_mono_ref(o);
}

static inline bool syli_object_is_mixed_order(Object* o)
{
    return (o->header_word & GC_TYPE_MASK) == Type_MixedOrder;
}

static inline bool syli_object_is_mixed_bitmap(Object* o)
{
    return (o->header_word & GC_TYPE_MASK) == Type_MixedBitmap;
}

/* ============================================================
 * Payload Extraction
 * ============================================================ */

static inline uint32_t syli_object_payload(Object* o)
{
    return (o->header_word & GC_PAYLOAD_MASK);
}

/* ============================================================
 * Type-Specific Payload Decoding
 * ============================================================ */

static inline size_t syli_object_mono_length(Object* o)
{
    assert(syli_object_is_mono(o));
    return syli_object_payload(o);
}

static inline size_t syli_object_order_ptr_count(Object* o)
{
    assert(syli_object_is_mixed_order(o));
    return (size_t)(syli_object_payload(o) & GC_ORDER_PTR_COUNT_MASK);
}

static inline size_t syli_object_order_imm_count(Object* o)
{
    assert(syli_object_is_mixed_order(o));
    return (size_t)((syli_object_payload(o) & GC_ORDER_IMM_COUNT_MASK)
        >> GC_ORDER_IMM_COUNT_SHIFT);
}

static inline size_t syli_object_order_length(Object* o)
{
    assert(syli_object_is_mixed_order(o));
    size_t payload   = syli_object_payload(o);
    size_t ptr_count = payload & GC_ORDER_PTR_COUNT_MASK;
    size_t imm_count
        = (payload & GC_ORDER_IMM_COUNT_MASK) >> GC_ORDER_IMM_COUNT_SHIFT;
    return ptr_count + imm_count;
}

static inline size_t syli_object_bitmap_length(Object* o)
{
    assert(syli_object_is_mixed_bitmap(o));
    return (syli_object_payload(o) & GC_BITMAP_LENGTH_MASK);
}

static inline uint32_t syli_object_bitmap_bits(Object* o)
{
    assert(syli_object_is_mixed_bitmap(o));
    return syli_object_payload(o) >> GC_BITMAP_BITS_SHIFT;
}

/* ============================================================
 * Generic Length Accessor
 * ============================================================ */

static inline size_t syli_object_length(Object* o)
{
    ObjectType type = (ObjectType)(o->header_word & GC_TYPE_MASK);

    switch (type) {
    case Type_MonoImm:
    case Type_MonoRef:
        return syli_object_mono_length(o);
    case Type_MixedOrder:
        return syli_object_order_length(o);
    case Type_MixedBitmap:
        return syli_object_bitmap_length(o);
    default:
        return 0;
    }
}

/* Variants */
static inline uint64_t syli_object_get_variant_tag(Object* o)
{
    return (o->header_word & GC_VARIANT_FLAGS_MASK);
}

#endif /* HEADER_OBJECT_H */
