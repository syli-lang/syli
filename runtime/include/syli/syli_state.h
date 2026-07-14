#ifndef SYLI_STATE_H
#define SYLI_STATE_H

#include <stdatomic.h>
#include <stdint.h>
#include <stdlib.h>

#include "chunk_vector.h"
#include "object.h"
#include "stack_frame.h"

typedef struct Suspected {
    GCObject* obj;
} Suspected;

typedef enum Tracing_state_machine {
    Tracing_Idle                = 0,
    Tracing                     = 1,
    Mutation_Prepare            = 2,
    Checking_Suspect_Lost_Cycle = 3,
} Tracing_state_machine;

typedef enum Releasing_state_machine {
    Releasing_Idle = 0,
    Releasing      = 1
} Releasing_state_machine;

typedef enum Dropping_state_machine {
    Dropping_Idle = 0,
    Dropping      = 1
} Dropping_state_machine;

CHUNK_VECTOR_STRUCT(GCObject);
CHUNK_VECTOR_STRUCT(Suspected);

CHUNK_VECTOR_IMPLEMENT(GCObject);
CHUNK_VECTOR_IMPLEMENT(Suspected);

// ==================== Syli State ====================
typedef struct Syli_state {

    size_t THRESHOLD_SUSPECTS_LOST_CYCLE;
    size_t THRESHOLD_RELEASING_BUCKET;
    size_t THRESHOLD_DROPPING_BUCKET;

    size_t FULL_BUCKET_SUSPECT_LOST_CYCLE;

    size_t BUDGET_GC_TRACING;
    size_t BUDGET_GC_RELEASING;
    size_t BUDGET_GC_DROPPING;
    size_t BUDGET_GC_CHECKING;

    int tracing_budget;
    int releasing_budget;
    int dropping_budget;
    int checking_budget;

    vector_GCObject tracing_worklist;
    vector_GCObject tracing_mutations_worklist;

    vector_GCObject releasing_worklist;
    vector_GCObject dropping_worklist;

    vector_GCObject releasing_waitlist;
    vector_GCObject dropping_waitlist;

    vector_Suspected suspect_lost_cycle;

    size_t releasing_steps;
    size_t tracing_steps;
    size_t dropping_steps;
    size_t mutation_steps;
    size_t checking_steps;

    size_t total_objects_dropped;
    size_t total_objects_traced;
    size_t total_objects_released;
    size_t total_objects_memory_freed;

    // Shadowing stack frame indices for GC tracing
    size_t current_frame_stack_index;
    size_t snapshot_frame_stack_index;

    size_t generation_tracing;

    // Stack frame for root management
    StackFrame stack_frame_roots;

    uint64_t tracing_current_bit_mark;
    size_t tracing_generations;

    // State machines for GC phases
    Tracing_state_machine tracing_state;
    Releasing_state_machine releasing_state;
    Dropping_state_machine dropping_state;

    size_t suspect_objects_notifications;

    size_t current_suspected_check_index;
    size_t snapshot_check_index;

} Syli_state;

// ========================
// Thread-local state
// ========================

#if defined(__cplusplus)
#define SYLI_TLS thread_local
#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L
#define SYLI_TLS _Thread_local
#else
#define SYLI_TLS __thread
#endif

#define INITIAL_CANDIDATE_INDEX (-1)

// Thread-local state declaration
extern SYLI_TLS Syli_state syli_state;

// Initialize runtime system
void syli_state_init();
void syli_state_destroy();

// ========================
// Allocation
// ========================

// ARC allocations
Object* syli_state_alloc_object(object_header_t header, size_t length);

// ========================
// GC root management
// ========================

// Stack frame roots
void syli_state_push_frame_scope(Frame* frame);
void syli_state_pop_frame_scope(void);

// ========================
// Garbage collection
// ========================

void syli_state_gc_tracing(void);
void syli_state_gc_releasing(void);
void syli_state_gc_dropping(void);

static inline void syli_state_gc_cycle()
{
    syli_state.tracing_budget   = syli_state.BUDGET_GC_TRACING;
    syli_state.releasing_budget = syli_state.BUDGET_GC_RELEASING;

    syli_state.dropping_budget = syli_state.BUDGET_GC_DROPPING;
    syli_state.checking_budget = syli_state.BUDGET_GC_CHECKING;

    syli_state_gc_releasing();
    syli_state_gc_dropping();
    syli_state_gc_tracing();
}

#endif // SYLI_STATE_H
