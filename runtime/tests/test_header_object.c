#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "syli/header_object.h"
#include "syli/object.h"

// Disable unused variable warnings for test functions
#pragma GCC diagnostic ignored "-Wunused-variable"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"

void test_header_construction_basic()
{
    printf("Test 1: Basic header construction\n");

    Object obj;
    obj.header_word = syli_object_make_header(Zone_GcLocal, // zone = local
        Acyclic, // acyclic
        Type_MonoImm, // type mono imm
        Flag_None, // no imm flags
        0 // payload = 0
    );

    assert(syli_object_get_zone(&obj) == Zone_GcLocal);
    assert(syli_object_is_shared(&obj) == false);
    assert(syli_object_is_mono(&obj) == true);
    assert(syli_object_is_mono_imm(&obj) == true);
    assert(syli_object_get_immutable_flags(&obj) == Flag_None);
    assert(syli_object_payload(&obj) == 0);

    printf("✓ Basic header construction works\n\n");
}

void test_header_cyclic_flag()
{
    printf("Test 3: Cyclic flag (bit 2)\n");

    Object obj_no_cyclic;
    obj_no_cyclic.header_word = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 0);
    assert(syli_object_is_acyclic(&obj_no_cyclic) == true);
    assert(syli_object_is_cyclic(&obj_no_cyclic) == false);

    Object obj_cyclic;
    obj_cyclic.header_word = syli_object_make_header(
        Zone_GcLocal, Cyclic, Type_MonoImm, Flag_None, 0);
    assert(syli_object_is_acyclic(&obj_cyclic) == false);
    assert(syli_object_is_cyclic(&obj_cyclic) == true);

    // Verify the bit position
    assert((obj_cyclic.header_word & GC_CYCLIC_MASK) != 0);
    assert((obj_no_cyclic.header_word & GC_CYCLIC_MASK) == 0);

    printf("✓ Cyclic flag works\n\n");
}

void test_header_type_field()
{
    printf("Test 4: Type field (bits 3-4)\n");

    Object obj_mono_imm;
    obj_mono_imm.header_word = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 0);
    assert(syli_object_type(&obj_mono_imm) == Type_MonoImm);
    assert(syli_object_is_mono(&obj_mono_imm) == true);
    assert(syli_object_is_mono_imm(&obj_mono_imm) == true);

    Object obj_mono_ref;
    obj_mono_ref.header_word = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoRef, Flag_None, 0);
    assert(syli_object_type(&obj_mono_ref) == Type_MonoRef);
    assert(syli_object_is_mono(&obj_mono_ref) == true);
    assert(syli_object_is_mono_ref(&obj_mono_ref) == true);

    Object obj_mixed_order;
    obj_mixed_order.header_word = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MixedOrder, Flag_None, 0);
    assert(syli_object_type(&obj_mixed_order) == Type_MixedOrder);
    assert(syli_object_is_mixed_order(&obj_mixed_order) == true);

    Object obj_mixed_bitmap;
    obj_mixed_bitmap.header_word = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MixedBitmap, Flag_None, 0);
    assert(syli_object_type(&obj_mixed_bitmap) == Type_MixedBitmap);
    assert(syli_object_is_mixed_bitmap(&obj_mixed_bitmap) == true);

    printf("✓ Type field works\n\n");
}

void test_header_flags_field()
{
    printf("Test 5: Object Flags\n");

    // Test specific flag patterns
    Object obj1;
    obj1.header_word = syli_object_make_header(Zone_GcLocal, Acyclic,
        Type_MonoImm, Flag_HasFinalizer | Flag_HasPointers, 0);
    assert(syli_object_get_immutable_flags(&obj1)
        == (Flag_HasFinalizer | Flag_HasPointers));
    assert(syli_object_has_finalizer(&obj1) == true);
    assert(syli_object_has_pointers(&obj1) == true);

    Object obj2;
    obj2.header_word = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoImm, Flag_HasFinalizer, 0);
    assert(syli_object_get_immutable_flags(&obj2) == Flag_HasFinalizer);
    assert(syli_object_has_finalizer(&obj2) == true);
    assert(syli_object_has_pointers(&obj2) == false);

    printf("✓ Flags field encoding/decoding works\n\n");
}

void test_header_payload_field()
{
    printf("Test 6: Payload field \n");

    // Test boundary values
    Object obj_min;
    obj_min.header_word = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 0);
    assert(syli_object_payload(&obj_min) == 0);

    Object obj_max;
    obj_max.header_word = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 0xFFFFFFFFULL);
    assert(syli_object_payload(&obj_max) == 0xFFFFFFFFULL);

    // Test some intermediate values
    Object obj_mid;
    obj_mid.header_word = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 0x12345678ULL);
    assert(syli_object_payload(&obj_mid) == 0x12345678ULL);

    printf("✓ Payload field encoding/decoding works\n\n");
}

void test_header_mixed_types()
{
    printf("Test 8: Mixed type payloads\n");

    // Test mixed order
    Object obj_order;
    obj_order.header_word
        = syli_object_make_header(Zone_GcLocal, Acyclic, Type_MixedOrder,
            Flag_HasPointers, syli_object_make_order_payload(3, 2));
    assert(syli_object_order_ptr_count(&obj_order) == 3);
    assert(syli_object_order_imm_count(&obj_order) == 2);
    assert(syli_object_length(&obj_order) == 5);

    // Test mixed bitmap
    Object obj_bitmap;
    obj_bitmap.header_word
        = syli_object_make_header(Zone_GcLocal, Acyclic, Type_MixedBitmap,
            Flag_HasPointers, syli_object_make_bitmap_payload(10, 0x1FF));
    assert(syli_object_bitmap_length(&obj_bitmap) == 10);
    assert(syli_object_bitmap_bits(&obj_bitmap) == 0x1FF);

    printf("✓ Mixed type payloads work\n\n");
}

void test_bitmap_payload()
{
    printf("Test 9: Bitmap payload decoding\n");

    // Test bitmap payload
    uint8_t length = 10;
    uint32_t bitmap = 0x1FF; // 9 bits set
    uint32_t payload = syli_object_make_bitmap_payload(length, bitmap);

    Object obj;
    obj.header_word = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MixedBitmap, Flag_HasPointers, payload);

    assert(syli_object_bitmap_length(&obj) == length);
    assert(syli_object_bitmap_bits(&obj) == bitmap);

    printf("✓ Bitmap payload decoding works\n\n");
}

void test_mono_payload()
{
    printf("Test 10: Mono payload decoding\n");

    // Test mono imm
    Object obj_imm;
    obj_imm.header_word = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 42);
    assert(syli_object_mono_length(&obj_imm) == 42);

    // Test mono ref
    Object obj_ref;
    obj_ref.header_word = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoRef, Flag_None, 100);
    assert(syli_object_mono_length(&obj_ref) == 100);

    printf("✓ Mono payload decoding works\n\n");
}

void test_header_full_combination()
{
    printf("Test 11: Full header with all fields set\n");

    Object obj;
    obj.header_word = syli_object_make_header(Zone_GcShared, // zone
        Cyclic, // cyclic
        Type_MonoRef, // type
        Flag_HasFinalizer | Flag_HasPointers, // imm flags
        0xDEADBEEF // payload
    );

    assert(syli_object_get_zone(&obj) == Zone_GcShared);
    assert(syli_object_is_cyclic(&obj) == 1);
    assert(syli_object_type(&obj) == Type_MonoRef);
    assert(syli_object_get_immutable_flags(&obj)
        == (Flag_HasFinalizer | Flag_HasPointers));
    assert(syli_object_payload(&obj) == 0xDEADBEEF);

    printf("✓ Full header combination works\n\n");
}

void test_zone_constants()
{
    printf("Test 13: Zone constants\n");

    assert(LOCAL == Zone_GcLocal);
    assert(SHARED == Zone_GcShared);

    printf("✓ Zone constants are correct\n\n");
}

int main()
{
    printf("\033[1;34m=== Running Header Word Tests ===\033[0m\n");

    test_header_construction_basic();
    test_header_cyclic_flag();
    test_header_type_field();
    test_header_payload_field();
    test_header_mixed_types();
    test_bitmap_payload();
    test_mono_payload();
    test_header_full_combination();

    printf("\033[1;32m=== All Header Word Tests Passed! ===\033[0m\n\n");
    return 0;
}
