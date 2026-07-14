#ifndef SYLI_SCOPE_ROOT_H
#define SYLI_SCOPE_ROOT_H

#include <stddef.h>
#include <stdint.h>
#include "object.h"

typedef struct Frame {
    uint32_t root_count;
    Object ***roots;
} Frame;

typedef struct StackFrame {
    uint32_t top;
    uint32_t capacity;
    Frame **frames;
} StackFrame;

void syli_stack_frame_init(StackFrame *stack, size_t initial_capacity);
void syli_stack_frame_destroy(StackFrame *stack);

int syli_stack_frame_push_scope(StackFrame *stack, Frame *frame);
int syli_stack_frame_pop_scope(StackFrame *stack);

#endif // SYLI_SCOPE_ROOT_H