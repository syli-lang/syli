#include "syli/stack_frame.h"
#include <stdlib.h>

void syli_stack_frame_init(StackFrame* stack, size_t initial_capacity)
{
    stack->frames = (Frame**)malloc(sizeof(Frame*) * initial_capacity);
    stack->top = 0;
    stack->capacity = initial_capacity;
}

void syli_stack_frame_destroy(StackFrame* stack)
{
    if (stack->frames) {
        free(stack->frames);
        stack->frames = NULL;
    }
    stack->top = 0;
    stack->capacity = 0;
}

int syli_stack_frame_push_scope(StackFrame* stack, Frame* frame)
{
    if (stack->top >= stack->capacity) {
        uint32_t new_capacity = stack->capacity * 2;
        Frame** new_frames
            = realloc(stack->frames, new_capacity * sizeof(Frame*));
        if (!new_frames) {
            return 0; // allocation failed
        }
        stack->frames = new_frames;
        stack->capacity = new_capacity;
    }

    stack->frames[stack->top] = frame;
    stack->top++;
    return 1; // success
}

int syli_stack_frame_pop_scope(StackFrame* stack)
{
    if (stack->top == 0) {
        return 0; // stack underflow
    }
    stack->top--;
    return 1; // success
}