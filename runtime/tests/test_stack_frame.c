#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#include "syli/object.h"
#include "syli/stack_frame.h"
#include "syli/syli_state.h"

#pragma GCC diagnostic ignored "-Wunused-variable"
#pragma GCC diagnostic ignored "-Wunused-but-set-variable"

static Object* make_test_mono_imm_object(size_t word_size)
{
    object_payload_t payload = syli_object_make_mono_payload(word_size);
    object_header_t header = syli_object_make_header(
        Zone_GcLocal, Acyclic, Type_MonoImm, Flag_None, payload);
    uint64_t meta_ref_count = make_meta_refcount(
        Meta_Flags_None, syli_state.tracing_current_bit_mark);
    return syli_object_alloc(header, meta_ref_count, word_size);
}

int main()
{
    printf("\033[1;34m=== Running Stack Frame Tests ===\033[0m\n\n");

    // Initialize syli state for object creation
    syli_state_init();

    // Test 1: Initialize stack
    printf("Test 1: Initialize stack\n");
    StackFrame stack;
    syli_stack_frame_init(&stack, 4);
    assert(stack.frames != NULL);
    assert(stack.top == 0);
    assert(stack.capacity == 4);
    printf("✓ Stack initialized\n\n");

    // Test 2: Push scope with StackFrame1
    printf("Test 2: Push scope with single root\n");
    Object* obj1 = (Object*)0x1000;
    Object** roots1[] = { &obj1 };
    Frame frame1 = { .root_count = 1, .roots = roots1 };

    int result = syli_stack_frame_push_scope(&stack, &frame1);
    assert(result == 1);
    assert(stack.top == 1);
    assert(stack.frames[0] == &frame1);
    printf("✓ Pushed single root frame\n\n");

    // Test 3: Push scope with StackFrame2
    printf("Test 3: Push scope with two roots\n");
    Object* obj2a = (Object*)0x2000;
    Object* obj2b = (Object*)0x2001;
    Object** roots2[] = { &obj2a, &obj2b };
    Frame frame2 = { .root_count = 2, .roots = roots2 };

    result = syli_stack_frame_push_scope(&stack, &frame2);
    assert(result == 1);
    assert(stack.top == 2);
    assert(stack.frames[1] == &frame2);
    printf("✓ Pushed two root frame\n\n");

    // Test 4: Push scope with StackFrame3
    printf("Test 4: Push scope with three roots\n");
    Object* obj3a = (Object*)0x3000;
    Object* obj3b = (Object*)0x3001;
    Object* obj3c = (Object*)0x3002;
    Object** roots3[] = { &obj3a, &obj3b, &obj3c };
    Frame frame3 = { .root_count = 3, .roots = roots3 };

    result = syli_stack_frame_push_scope(&stack, &frame3);
    assert(result == 1);
    assert(stack.top == 3);
    assert(stack.frames[2] == &frame3);
    printf("✓ Pushed three root frame\n\n");

    // Test 5: Push dynamic StackFrame
    printf("Test 5: Push dynamic StackFrame\n");
    Object* obj4a = (Object*)0x4000;
    Object* obj4b = (Object*)0x4001;
    Object* obj4c = (Object*)0x4002;
    Object* obj4d = (Object*)0x4003;
    Object* obj4e = (Object*)0x4004;

    // Create array of root pointers
    Object** roots4[] = { &obj4a, &obj4b, &obj4c, &obj4d, &obj4e };
    Frame dynamic_frame = { .root_count = 5, .roots = roots4 };

    result = syli_stack_frame_push_scope(&stack, &dynamic_frame);
    assert(result == 1);
    assert(stack.top == 4);
    assert(stack.frames[3] == &dynamic_frame);
    printf("✓ Pushed dynamic StackFrame\n\n");

    // Test 6: Verify stack capacity resize
    printf("Test 6: Verify stack capacity (should still be 4)\n");
    assert(stack.capacity == 4);
    printf("✓ Capacity is %u\n\n", stack.capacity);

    // Test 7: Push one more to trigger resize
    printf("Test 7: Push to trigger resize\n");
    Object* obj5 = (Object*)0x5000;
    Object** roots5[] = { &obj5 };
    Frame frame5 = { .root_count = 1, .roots = roots5 };

    result = syli_stack_frame_push_scope(&stack, &frame5);
    assert(result == 1);
    assert(stack.top == 5);
    assert(stack.capacity == 8); // Should have doubled
    printf("✓ Pushed 5th scope, capacity resized to %u\n\n", stack.capacity);

    // Test 8: Pop scopes
    printf("Test 8: Pop scopes\n");
    for (uint32_t i = 0; i < 5; i++) {
        result = syli_stack_frame_pop_scope(&stack);
        assert(result == 1);
        assert(stack.top == 4 - i);
    }
    assert(stack.top == 0);
    printf("✓ Popped all 5 scopes\n\n");

    // Test 9: Pop empty stack
    printf("Test 9: Pop empty stack\n");
    result = syli_stack_frame_pop_scope(&stack);
    assert(result == 0); // Should fail
    assert(stack.top == 0);
    printf("✓ Correctly failed to pop empty stack\n\n");

    // Test 10: Create objects and test root tracking
    printf("Test 10: Create objects and test root tracking\n");

    // Create a monotype object with 3 fields
    Object* test_obj1 = make_test_mono_imm_object(3);
    assert(test_obj1 != NULL);
    assert(syli_object_length(test_obj1) == 3);

    // Set some values in the object
    uint64_t* data1 = syli_object_data(test_obj1);
    data1[0] = 42;
    data1[1] = 123;
    data1[2] = 999;

    // Create another object
    Object* test_obj2 = make_test_mono_imm_object(2);
    assert(test_obj2 != NULL);
    uint64_t* data2 = syli_object_data(test_obj2);
    data2[0] = 777;
    data2[1] = 555;

    // Push a frame with these objects as roots
    Object** root_slots[] = { &test_obj1, &test_obj2 };
    Frame root_frame = { .root_count = 2, .roots = root_slots };

    result = syli_stack_frame_push_scope(&stack, &root_frame);
    assert(result == 1);
    assert(stack.top == 1);
    printf("✓ Pushed frame with object roots\n");

    // Verify we can access the objects through the roots
    Object* retrieved_obj1 = *root_frame.roots[0];
    Object* retrieved_obj2 = *root_frame.roots[1];

    assert(retrieved_obj1 == test_obj1);
    assert(retrieved_obj2 == test_obj2);
    printf("✓ Retrieved objects from roots match originals\n");

    // Verify the object data is still correct
    uint64_t* retrieved_data1 = syli_object_data(retrieved_obj1);
    uint64_t* retrieved_data2 = syli_object_data(retrieved_obj2);

    assert(retrieved_data1[0] == 42);
    assert(retrieved_data1[1] == 123);
    assert(retrieved_data1[2] == 999);
    assert(retrieved_data2[0] == 777);
    assert(retrieved_data2[1] == 555);
    printf("✓ Object data values are preserved through root tracking\n");

    // Pop the frame
    result = syli_stack_frame_pop_scope(&stack);
    assert(result == 1);
    assert(stack.top == 0);
    printf("✓ Popped frame with object roots\n\n");

    free(test_obj1);
    free(test_obj2);

    // Test 11: Destroy
    printf("Test 11: Destroy stack\n");
    syli_stack_frame_destroy(&stack);
    assert(stack.frames == NULL);
    assert(stack.top == 0);
    assert(stack.capacity == 0);
    printf("✓ Stack destroyed\n");

    // Clean up syli state
    syli_state_destroy();
    printf("✓ Syli state cleaned up\n\n");

    printf("\033[1;32m=== All Stack Frame Tests Passed! ===\033[0m\n\n");
    return 0;
}