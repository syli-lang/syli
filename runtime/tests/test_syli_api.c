#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "syli/gc_helpers.h"
#include "syli/syli.h"
#include "syli/syli_state.h"

#pragma GCC diagnostic ignored "-Wunused-but-set-variable"

static obj_ptr make_object(ObjectZone zone, CyclicFlag cyclic, ObjectType type,
    ObjectImmutableFlag imm_flags, size_t words)
{
    object_payload_t payload;
    switch (type) {
    case Type_MonoImm:
    case Type_MonoRef:
        payload = syli_object_make_mono_payload(words);
        break;
    case Type_MixedOrder:
        payload = syli_object_make_order_payload(words, 0);
        break;
    case Type_MixedBitmap:
        payload = syli_object_make_bitmap_payload(words, 0);
        break;
    default:
        return (obj_ptr)NULL;
    }

    object_header_t header
        = syli_object_make_header(zone, cyclic, type, imm_flags, payload);
    return syli_rt_ownership_alloc_object(header, 1, words);
}

static void test_rt_rc_alloc_object(void)
{
    printf("Test 1: syli_rt_rc_alloc_object()\n");

    syli_state_init();

    obj_ptr obj
        = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 1);
    assert(obj != NULL);
    Object* o = syli_object_of_obj_ptr(obj);
    assert(syli_object_get_zone(o) == Zone_GcLocal);
    assert(syli_object_is_acyclic(o));
    assert(syli_object_is_mono_imm(o));
    assert(syli_object_mono_length(o) == 1);
    assert(syli_object_refcount(o) == 1);
    syli_free_ptr(obj);

    obj_ptr cyclic
        = make_object(Zone_GcLocal, Cyclic, Type_MonoRef, Flag_HasPointers, 3);
    assert(cyclic != NULL);
    Object* c = syli_object_of_obj_ptr(cyclic);
    assert(syli_object_get_zone(c) == Zone_GcLocal);
    assert(syli_object_is_cyclic(c));
    assert(syli_object_is_mono_ref(c));
    assert(syli_object_has_pointers(c));
    assert(syli_object_mono_length(c) == 3);
    assert(syli_object_refcount(c) == 1);
    syli_free_ptr(cyclic);

    object_payload_t order_payload = syli_object_make_order_payload(2, 1);
    object_header_t order_header   = syli_object_make_header(Zone_GcLocal,
        Acyclic, Type_MixedOrder, Flag_HasPointers, order_payload);
    obj_ptr mixed = syli_rt_ownership_alloc_object(order_header, 5, 3);
    assert(mixed != NULL);
    Object* m = syli_object_of_obj_ptr(mixed);
    assert(syli_object_is_mixed_order(m));
    assert(syli_object_refcount(m) == 5);
    syli_free_ptr(mixed);

    object_payload_t bitmap_payload = syli_object_make_bitmap_payload(4, 0b101);
    object_header_t bitmap_header   = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MixedBitmap, Flag_None, bitmap_payload);
    obj_ptr bitmap = syli_rt_ownership_alloc_object(bitmap_header, 1, 4);
    assert(bitmap != NULL);
    Object* b = syli_object_of_obj_ptr(bitmap);
    assert(syli_object_is_mixed_bitmap(b));
    assert(syli_object_refcount(b) == 1);
    assert(syli_object_bitmap_length(b) == 4);
    syli_free_ptr(bitmap);

    syli_state_destroy();
    printf("✓ syli_rt_rc_alloc_object works with all object types\n\n");
}

static void test_rt_object_incr_decr(void)
{
    printf("Test 2: syli_rt_object_incr() / syli_rt_object_decr()\n");

    syli_state_init();

    obj_ptr obj
        = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 0);
    assert(obj != NULL);
    Object* o = syli_object_of_obj_ptr(obj);
    assert(syli_object_refcount(o) == 1);

    syli_rt_ownership_incr(obj);
    assert(syli_object_refcount(o) == 2);

    syli_rt_ownership_incr(obj);
    assert(syli_object_refcount(o) == 3);

    syli_rt_ownership_decr(obj);
    assert(syli_object_refcount(o) == 2);

    syli_rt_ownership_decr(obj);
    assert(syli_object_refcount(o) == 1);

    Object static_obj;
    static_obj.header_word = syli_object_make_header(
        Zone_Static, Acyclic, Type_MonoImm, Flag_None, 0);

    uint64_t before_header = static_obj.header_word;
    syli_rt_object_incr(&static_obj);
    assert(static_obj.header_word == before_header);

    syli_rt_object_decr(&static_obj, (obj_ptr)&static_obj);
    assert(static_obj.header_word == before_header);

    syli_free_ptr(obj);
    syli_state_destroy();
    printf("✓ Acquire/release work correctly on GC and static objects\n\n");
}

static void test_rt_object_decr_n(void)
{
    printf("Test 3: syli_rt_object_decr_n()\n");

    syli_state_init();

    obj_ptr obj
        = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 0);
    assert(obj != NULL);
    Object* o = syli_object_of_obj_ptr(obj);
    assert(syli_object_refcount(o) == 1);

    syli_rt_ownership_incr(obj);
    syli_rt_ownership_incr(obj);
    syli_rt_ownership_incr(obj);
    syli_rt_ownership_incr(obj);
    assert(syli_object_refcount(o) == 5);

    syli_rt_object_decr_n(o, 3);
    assert(syli_object_refcount(o) == 2);

    syli_rt_object_decr_n(o, 2);
    assert(syli_object_refcount(o) == 0);

    Object static_obj;
    static_obj.header_word = syli_object_make_header(
        Zone_Static, Acyclic, Type_MonoImm, Flag_None, 0);
    uint64_t before_header = static_obj.header_word;
    syli_rt_object_decr_n(&static_obj, 5);
    assert(static_obj.header_word == before_header);

    syli_free_ptr(obj);
    syli_state_destroy();
    printf("✓ syli_rt_object_decr_n decrements by the correct amount\n\n");
}

static void test_rt_object_check_lost_cyclic_release(void)
{
    printf("Test 4: syli_rt_object_check_lost_cyclic_release()\n");

    syli_state_init();

    obj_ptr obj
        = make_object(Zone_GcLocal, Cyclic, Type_MonoRef, Flag_HasPointers, 1);
    assert(obj != NULL);
    Object* o = syli_object_of_obj_ptr(obj);
    assert(syli_object_refcount(o) == 1);

    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0);
    syli_rt_ownership_check_lost_cyclic_release(obj);
    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 1);

    {
        Suspected* suspect
            = vector_at_Suspected(&syli_state.suspect_lost_cycle, 0);
        assert(syli_object_of_obj_ptr(suspect->obj) == o);
    }

    syli_rt_ownership_check_lost_cyclic_release(obj);
    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 1);

    syli_object_clear_flags(o, Meta_Flags_Suspect_Lost_Cycle);
    vector_pop_back_Suspected(&syli_state.suspect_lost_cycle);
    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0);

    syli_rt_ownership_decr(obj);
    assert(syli_object_refcount(o) == 0);

    syli_rt_ownership_check_lost_cyclic_release(obj);
    assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0);

    {
        Object static_obj;
        static_obj.header_word = syli_object_make_header(
            Zone_Static, Acyclic, Type_MonoImm, Flag_None, 0);
        syli_rt_object_check_lost_cyclic_release(
            &static_obj, (obj_ptr)&static_obj);
        assert(vector_size_Suspected(&syli_state.suspect_lost_cycle) == 0);
    }

    syli_free_ptr(obj);
    syli_state_destroy();
    printf("✓ syli_rt_object_check_lost_cyclic_release correctly manages "
           "suspects\n\n");
}

static void test_rt_get_object_tag(void)
{
    printf("Test 5: syli_rt_get_object_tag()\n");

    syli_state_init();

    uint64_t variant_bits  = (uint64_t)0xAB << 48;
    object_header_t header = syli_object_make_header(Zone_GcLocal, Acyclic,
        Type_MonoImm, Flag_None, syli_object_make_mono_payload(0));
    header |= variant_bits;

    obj_ptr obj = syli_rt_ownership_alloc_object(header, 1, 0);
    assert(obj != NULL);

    uint64_t tag = syli_rt_get_object_tag(syli_object_of_obj_ptr(obj));
    assert(tag == variant_bits);

    object_header_t header_no_variant
        = syli_object_make_header(Zone_GcLocal, Acyclic, Type_MonoRef,
            Flag_HasPointers, syli_object_make_mono_payload(0));
    obj_ptr no_variant
        = syli_rt_ownership_alloc_object(header_no_variant, 1, 0);
    assert(no_variant != NULL);

    uint64_t tag_no_variant
        = syli_rt_get_object_tag(syli_object_of_obj_ptr(no_variant));
    assert(tag_no_variant == 0);

    syli_free_ptr(obj);
    syli_free_ptr(no_variant);
    syli_state_destroy();
    printf("✓ syli_rt_get_object_tag returns correct variant tag\n\n");
}

static void test_rt_get_object_length(void)
{
    printf("Test 6: syli_rt_get_object_length()\n");

    syli_state_init();

    {
        obj_ptr mono
            = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 5);
        assert(mono != NULL);
        assert(syli_rt_get_object_length(syli_object_of_obj_ptr(mono)) == 5);
        syli_free_ptr(mono);
    }

    {
        obj_ptr mono_ref = make_object(
            Zone_GcLocal, Acyclic, Type_MonoRef, Flag_HasPointers, 10);
        assert(mono_ref != NULL);
        assert(
            syli_rt_get_object_length(syli_object_of_obj_ptr(mono_ref)) == 10);
        syli_free_ptr(mono_ref);
    }

    {
        object_payload_t order_payload = syli_object_make_order_payload(3, 2);
        object_header_t order_header   = syli_object_make_header(Zone_GcLocal,
            Acyclic, Type_MixedOrder, Flag_HasPointers, order_payload);
        obj_ptr mixed = syli_rt_ownership_alloc_object(order_header, 1, 5);
        assert(mixed != NULL);
        assert(syli_rt_get_object_length(syli_object_of_obj_ptr(mixed)) == 5);
        syli_free_ptr(mixed);
    }

    {
        object_payload_t bitmap_payload
            = syli_object_make_bitmap_payload(4, 0xF);
        object_header_t bitmap_header = syli_object_make_header(Zone_GcLocal,
            Acyclic, Type_MixedBitmap, Flag_HasPointers, bitmap_payload);
        obj_ptr bitmap = syli_rt_ownership_alloc_object(bitmap_header, 1, 4);
        assert(bitmap != NULL);
        assert(syli_rt_get_object_length(syli_object_of_obj_ptr(bitmap)) == 4);
        syli_free_ptr(bitmap);
    }

    syli_state_destroy();
    printf("✓ syli_rt_get_object_length returns correct length for all "
           "types\n\n");
}

static void test_rt_object_raw_copy(void)
{
    printf("Test 7: syli_rt_object_raw_copy()\n");

    syli_state_init();

    size_t words = 4;
    obj_ptr src
        = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, words);
    assert(src != NULL);
    Object* src_o = syli_object_of_obj_ptr(src);

    uint64_t* src_data = syli_object_data(src_o);
    src_data[0]        = 0xDEAD;
    src_data[1]        = 0xBEEF;
    src_data[2]        = 0xCAFE;
    src_data[3]        = 0xBABE;

    obj_ptr dst
        = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, words);
    assert(dst != NULL);
    Object* dst_o = syli_object_of_obj_ptr(dst);

    uint64_t* dst_data = syli_object_data(dst_o);
    dst_data[0]        = 0xFFFF;
    dst_data[1]        = 0xFFFF;
    dst_data[2]        = 0xFFFF;
    dst_data[3]        = 0xFFFF;

    syli_rt_object_raw_copy(src_o, dst_o);

    GCObject* src_gc = as_gc_object(src_o);
    GCObject* dst_gc = as_gc_object(dst_o);
    assert(dst_gc->header_word == src_gc->header_word);
    assert(dst_gc->meta_ref_count == src_gc->meta_ref_count);

    uint64_t* dst_data_after = syli_object_data(dst_o);
    assert(dst_data_after[0] == 0xDEAD);
    assert(dst_data_after[1] == 0xBEEF);
    assert(dst_data_after[2] == 0xCAFE);
    assert(dst_data_after[3] == 0xBABE);

    syli_free_ptr(src);
    syli_free_ptr(dst);
    syli_state_destroy();
    printf("✓ syli_rt_object_raw_copy copies header, meta_ref_count, and "
           "data\n\n");
}

static void test_rt_gc_cycle(void)
{
    printf("Test 8: syli_rt_gc_cycle()\n");

    syli_state_init();

    syli_state.tracing_budget   = -1;
    syli_state.releasing_budget = -1;
    syli_state.checking_budget  = -1;

    syli_rt_gc_cycle();

    assert(syli_state.tracing_budget == (int)syli_state.BUDGET_GC_TRACING);
    assert(syli_state.releasing_budget == (int)syli_state.BUDGET_GC_RELEASING);
    assert(syli_state.checking_budget == (int)syli_state.BUDGET_GC_CHECKING);

    syli_state_destroy();
    printf("✓ syli_rt_gc_cycle() resets budgets\n\n");
}

static void test_rt_object_notify_mutation(void)
{
    printf("Test 9: syli_rt_object_notify_mutation()\n");

    syli_state_init();

    assert(vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 0);

    {
        obj_ptr obj = make_object(
            Zone_GcLocal, Acyclic, Type_MonoImm, Flag_Traceable, 1);
        assert(obj != NULL);
        Object* obj_o = syli_object_of_obj_ptr(obj);

        obj_ptr target
            = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 1);
        assert(target != NULL);
        Object* target_o = syli_object_of_obj_ptr(target);

        gc_next_marking_generation();

        gc_mark_tag_object(obj_o);
        assert(gc_is_object_mark_tagged(obj_o));
        assert(!gc_is_object_mark_tagged(target_o));

        syli_state.tracing_state = Tracing;
        syli_rt_ownership_notify_mutation(obj, target);

        assert(gc_is_object_mark_tagged(target_o));
        assert(
            vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 1);

        vector_pop_back_obj_ptr(&syli_state.tracing_mutations_worklist);
        assert(
            vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 0);

        syli_free_ptr(obj);
        syli_free_ptr(target);
    }

    {
        gc_next_marking_generation();

        obj_ptr obj = make_object(
            Zone_GcLocal, Acyclic, Type_MonoImm, Flag_Traceable, 1);
        assert(obj != NULL);

        obj_ptr target
            = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 1);
        assert(target != NULL);

        gc_next_marking_generation();

        assert(!gc_is_object_mark_tagged(syli_object_of_obj_ptr(obj)));

        syli_state.tracing_state = Tracing;
        syli_rt_ownership_notify_mutation(obj, target);

        assert(
            vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 0);

        syli_free_ptr(obj);
        syli_free_ptr(target);
    }

    {
        gc_next_marking_generation();

        obj_ptr obj
            = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 1);
        assert(obj != NULL);

        obj_ptr target
            = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 1);
        assert(target != NULL);

        gc_next_marking_generation();

        Object* obj_o = syli_object_of_obj_ptr(obj);
        gc_mark_tag_object(obj_o);
        assert(gc_is_object_mark_tagged(obj_o));

        assert(!syli_object_is_traceable(obj_o));

        syli_state.tracing_state = Tracing;
        syli_rt_ownership_notify_mutation(obj, target);

        assert(
            vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 0);

        syli_free_ptr(obj);
        syli_free_ptr(target);
    }

    {
        gc_next_marking_generation();

        obj_ptr obj = make_object(
            Zone_GcLocal, Acyclic, Type_MonoImm, Flag_Traceable, 1);
        assert(obj != NULL);

        obj_ptr target
            = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 1);
        assert(target != NULL);

        gc_next_marking_generation();

        Object* obj_o    = syli_object_of_obj_ptr(obj);
        Object* target_o = syli_object_of_obj_ptr(target);
        gc_mark_tag_object(obj_o);
        gc_mark_tag_object(target_o);
        assert(gc_is_object_mark_tagged(obj_o));
        assert(gc_is_object_mark_tagged(target_o));

        syli_state.tracing_state = Tracing;
        syli_rt_ownership_notify_mutation(obj, target);

        assert(
            vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 0);

        syli_free_ptr(obj);
        syli_free_ptr(target);
    }

    {
        gc_next_marking_generation();

        Object static_obj;
        static_obj.header_word = syli_object_make_header(
            Zone_Static, Acyclic, Type_MonoImm, Flag_None, 0);

        obj_ptr target
            = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 1);
        assert(target != NULL);
        Object* target_o = syli_object_of_obj_ptr(target);

        gc_next_marking_generation();

        syli_rt_object_notify_mutation(
            &static_obj, target_o, (obj_ptr)target_o);

        assert(
            vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 0);

        syli_free_ptr(target);
    }

    {
        gc_next_marking_generation();

        obj_ptr obj
            = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 1);
        assert(obj != NULL);

        obj_ptr target
            = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 1);
        assert(target != NULL);

        gc_next_marking_generation();

        Object* obj_o = syli_object_of_obj_ptr(obj);
        gc_mark_tag_object(obj_o);
        assert(gc_is_object_mark_tagged(obj_o));

        assert(!syli_object_is_traceable(obj_o));

        syli_state.tracing_state = Tracing;
        syli_rt_ownership_notify_mutation(obj, target);

        assert(
            vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 0);

        syli_free_ptr(obj);
        syli_free_ptr(target);
    }

    {
        gc_next_marking_generation();

        obj_ptr obj = make_object(
            Zone_GcLocal, Acyclic, Type_MonoImm, Flag_Traceable, 1);
        assert(obj != NULL);

        obj_ptr target
            = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 1);
        assert(target != NULL);

        gc_next_marking_generation();

        Object* obj_o    = syli_object_of_obj_ptr(obj);
        Object* target_o = syli_object_of_obj_ptr(target);
        gc_mark_tag_object(obj_o);
        gc_mark_tag_object(target_o);
        assert(gc_is_object_mark_tagged(obj_o));
        assert(gc_is_object_mark_tagged(target_o));

        syli_state.tracing_state = Tracing;
        syli_rt_ownership_notify_mutation(obj, target);

        assert(
            vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 0);

        syli_free_ptr(obj);
        syli_free_ptr(target);
    }

    {
        gc_next_marking_generation();

        Object static_obj;
        static_obj.header_word = syli_object_make_header(
            Zone_Static, Acyclic, Type_MonoImm, Flag_None, 0);

        obj_ptr target
            = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 1);
        assert(target != NULL);
        Object* target_o = syli_object_of_obj_ptr(target);

        gc_next_marking_generation();

        syli_rt_object_notify_mutation(
            &static_obj, target_o, (obj_ptr)target_o);

        assert(
            vector_size_obj_ptr(&syli_state.tracing_mutations_worklist) == 0);

        syli_free_ptr(target);
    }

    syli_state_destroy();
    printf("✓ syli_rt_object_notify_mutation works correctly\n\n");
}

static void test_rt_ownership_own(void)
{
    printf("Test 10: syli_rt_ownership_own()\n");

    syli_state_init();

    obj_ptr own_ref
        = make_object(Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, 1);
    assert(own_ref != NULL);
    Object* o = syli_object_of_obj_ptr(own_ref);
    assert(syli_object_refcount(o) == 1);
    assert(syli_ownership_is_own_ref(own_ref));

    /* own() on an already-owned ref is a no-op */
    obj_ptr result = syli_rt_ownership_own(own_ref);
    assert(result == own_ref);
    assert(syli_object_refcount(o) == 1);

    /* own() on a borrowed (untagged) ref promotes: +1 refcount, own result */
    obj_ptr borrowed = syli_rt_ownership_borrow(own_ref);
    assert(!syli_ownership_is_own_ref(borrowed));

    obj_ptr promoted = syli_rt_ownership_own(borrowed);
    assert(syli_ownership_is_own_ref(promoted));
    assert(syli_object_refcount(o) == 2);

    syli_rt_ownership_decr(promoted);
    assert(syli_object_refcount(o) == 1);

    syli_free_ptr(own_ref);
    syli_state_destroy();

    printf("✓ syli_rt_ownership_own promotes borrowed refs\n\n");
}

int main(void)
{
    printf("\033[1;34m=== Running syli.h API Tests ===\033[0m\n\n");

    test_rt_rc_alloc_object();
    test_rt_object_incr_decr();
    test_rt_object_decr_n();
    test_rt_object_check_lost_cyclic_release();
    test_rt_get_object_tag();
    test_rt_get_object_length();
    test_rt_object_raw_copy();
    test_rt_gc_cycle();
    test_rt_object_notify_mutation();
    test_rt_ownership_own();

    printf("\033[1;32m=== All syli.h API Tests Passed! ===\033[0m\n\n");
    return 0;
}
