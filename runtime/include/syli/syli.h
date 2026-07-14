#ifndef SYLI_H
#define SYLI_H

/*
 * Syli Runtime API
 * =================
 *
 * This header defines the public API for the Syli runtime system, including
 * object creation, reference management, field access, and GC triggering.
 *
 * The API is designed to be used by generated code and provides a low-level
 * interface to the underlying memory management and GC system.
 *
 * Note: This API is not intended for direct use by end-users; it is primarily
 * meant for internal use by the Syli compiler and runtime. It may change
 * without warning as the implementation evolves.
 *
 */

#include "header_object.h"
#include "immediate.h"
#include "object.h"
#include "stack_frame.h"

/************************************************
 * Object Creation Functions
 ************************************************/

GCObject* syli_rt_rc_alloc_object(
    object_header_t header, size_t refcount, size_t words);

GCObject* syli_rt_shared_alloc(object_header_t header, size_t words);

/************************************************
 * Reference Management Functions
 ************************************************/

void syli_rt_object_incr(Object* obj);
void syli_rt_object_decr(Object* obj);
void syli_rt_object_decr_n(Object* obj, int n);

// Check if refcount drops to zero — if so, add to release_waitlist or free immediately
void syli_rt_object_check_release(Object* obj);

// Add to dropping waitlist regardless of refcount. Does not decrement refcount.
// Caller must guarantee the object is no longer reachable.
void syli_rt_object_decr_drop(Object* obj);

// If refcount is still above zero, mark as suspect lost cycle
void syli_rt_object_check_lost_cyclic_release(Object* obj);

// Write barrier: notify the GC that `obj` was mutated to point to `target`
// during tracing. If `obj` is marked but `target` is not, `target` is added
// to the mutation worklist. Used for objects that could be cyclic:
//   - obj points to cyclic objects (directly or indirectly)
//   - obj could be cyclic
void syli_rt_object_notify_mutation(Object* obj, Object* target);

/************************************************
 * Object Field Access Functions
 ************************************************/

uint64_t syli_rt_get_object_tag(Object* obj);

uint64_t syli_rt_get_object_length(Object* obj);

/************************************************
 * GC Trigger Function
 ************************************************/

void syli_rt_gc_cycle();

/************************************************
 * Others Functions
 ************************************************/

Object* syli_rt_object_copy(Object* src);
void syli_rt_object_raw_copy(Object* src, Object* dst);

// Stack frame roots management
void syli_rt_push_frame_scope(Frame* frame);
void syli_rt_pop_frame_scope(void);

#endif /* SYLI_H */
