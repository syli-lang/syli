#ifndef SYLI_TASK_H
#define SYLI_TASK_H

#include "bump_zone.h"
#include "object.h"

typedef struct SyliTask {
    BumpZone bump;             // task-local bump allocator
    Object **task_roots;       // root pointers for GC
    size_t    task_root_count; // number of roots
    size_t    task_root_capacity;

    // Optional: async state machine pointer
    void *resume_state;        // where to resume execution

    // Optional: metadata
    uint32_t task_id;
    uint32_t priority;
} SyliTask;

#endif // SYLI_TASK_H