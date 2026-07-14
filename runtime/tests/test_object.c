#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "syli/gc_helpers.h"
#include "syli/header_object.h"
#include "syli/object.h"
#include "syli/syli_state.h"

void test_object_allocation()
{
    printf("Test 1: Object allocation and reference counting\n");

    syli_state_init();

    size_t word_size = 4;

    object_payload_t payload = syli_object_make_mono_payload(word_size);

    object_header_t header = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, payload);

    uint64_t meta_ref_count = make_meta_refcount(
        Meta_Flags_Suspect_Lost_Cycle, syli_state.tracing_current_bit_mark);

    Object* obj = syli_object_alloc(header, meta_ref_count, word_size);

    gc_mark_tag_object(obj);

    assert(obj != NULL);
    assert(syli_object_get_zone(obj) == Zone_GcLocal);
    assert(syli_object_refcount(obj) == 1);
    assert(syli_object_has_flags(obj, Meta_Flags_Suspect_Lost_Cycle) == true);
    assert(gc_is_object_mark_tagged(obj) == true);
    assert(syli_object_payload(obj) == payload);
    assert(syli_object_length(obj) == word_size);

    free(obj);
    syli_state_destroy();
    printf("✓ Object allocation and reference counting works\n\n");
}

void test_object_allocation_and_refcounting()
{
    printf("Test 2: Object allocation and reference counting\n");

    syli_state_init();

    size_t word_size = 2;

    object_payload_t payload = syli_object_make_mono_payload(word_size);

    object_header_t header = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, payload);

    uint64_t meta_ref_count = make_meta_refcount(
        Meta_Flags_Releasing, syli_state.tracing_current_bit_mark);

    gc_next_marking_generation(); // the object is no longer tagged as marked.

    Object* obj = syli_object_alloc(header, meta_ref_count, word_size);

    assert(obj != NULL);
    assert(syli_object_get_zone(obj) == Zone_GcLocal);
    assert(syli_object_refcount(obj) == 1);
    assert(syli_object_has_flags(obj, Meta_Flags_Releasing) == true);
    assert(gc_is_object_mark_tagged(obj) == false);
    assert(syli_object_payload(obj) == payload);
    assert(syli_object_length(obj) == word_size);

    // Increment ref count
    syli_object_decr(obj);
    assert(syli_object_refcount(obj) == 0);
    syli_object_incr(obj);
    assert(syli_object_refcount(obj) == 1);
    syli_object_incr(obj);
    assert(syli_object_refcount(obj) == 2);
    syli_object_incr(obj);
    assert(syli_object_refcount(obj) == 3);
    syli_object_incr(obj);
    assert(syli_object_refcount(obj) == 4);
    syli_object_decr_n(obj, 2);
    assert(syli_object_refcount(obj) == 2);
    syli_object_decr(obj);
    assert(syli_object_refcount(obj) == 1);
    syli_object_decr(obj);
    assert(syli_object_refcount(obj) == 0);

    free(obj);
    syli_state_destroy();
    printf("✓ Object allocation and reference counting works\n\n");
}

void test_object_meta_flags()
{
    printf("Test 3: Object meta flags\n");

    syli_state_init();

    size_t word_size = 1;

    object_payload_t payload = syli_object_make_mono_payload(word_size);

    object_header_t header = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, payload);

    uint64_t meta_ref_count
        = make_meta_refcount(Meta_Flags_Dropping | Meta_Flags_Tracing,
            syli_state.tracing_current_bit_mark);

    Object* obj = syli_object_alloc(header, meta_ref_count, word_size);

    assert(obj != NULL);
    assert(syli_object_has_flags(obj, Meta_Flags_Dropping) == true);
    assert(syli_object_has_flags(obj, Meta_Flags_Tracing) == true);
    assert(syli_object_has_flags(obj, Meta_Flags_Releasing) == false);
    assert(syli_object_has_flags(obj, Meta_Flags_Suspect_Lost_Cycle) == false);

    syli_object_set_flags(obj, Meta_Flags_Suspect_Lost_Cycle);
    syli_object_clear_flags(obj, Meta_Flags_Tracing);
    assert(syli_object_has_flags(obj, Meta_Flags_Suspect_Lost_Cycle) == true);
    assert(syli_object_has_flags(obj, Meta_Flags_Dropping) == true);
    assert(syli_object_has_flags(obj, Meta_Flags_Tracing) == false);
    assert(syli_object_has_flags(obj, Meta_Flags_Releasing) == false);

    free(obj);
    syli_state_destroy();
    printf("✓ Object meta flags work\n\n");
}

int main()
{
    printf("\033[1;34m=== Running Object Tests ===\033[0m\n");

    test_object_allocation();
    test_object_allocation_and_refcounting();
    test_object_meta_flags();

    printf("\033[1;32m=== All Object Tests Passed! ===\033[0m\n\n");

    return 0;
}