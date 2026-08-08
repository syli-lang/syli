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
#include "object.h"
#include "syli_primitives.h"

/************************************************
 * Object Creation Functions
 ************************************************/

GCObject* syli_rt_rc_alloc_object(
    object_header_t header, size_t refcount, size_t words);

GCObject* syli_rt_shared_alloc(object_header_t header, size_t words);

/************************************************
 * Ownership Tag Primitives
 ************************************************/
obj_ptr syli_rt_ownership_alloc_object(
    object_header_t header, size_t refcount, size_t words);

obj_ptr syli_rt_ownership_untag(obj_ptr ptr);
obj_ptr syli_rt_ownership_borrow(obj_ptr ptr);
obj_ptr syli_rt_ownership_own(obj_ptr ptr);
obj_ptr syli_rt_ownership_share(obj_ptr ptr);

void syli_rt_ownership_release(obj_ptr ptr);
void syli_rt_ownership_decr(obj_ptr ptr);
void syli_rt_ownership_incr(obj_ptr ptr);
void syli_rt_ownership_check_lost_cyclic_release(obj_ptr ptr);
void syli_rt_ownership_notify_mutation(obj_ptr ptr, obj_ptr target_ptr);

/************************************************
 * Reference Management Functions
 ************************************************/

void syli_rt_object_incr(Object* obj);
void syli_rt_object_decr(Object* obj, obj_ptr obj_ptr);
void syli_rt_object_decr_n(Object* obj, int n);

// If refcount is still above zero, mark as suspect lost cycle
void syli_rt_object_check_lost_cyclic_release(Object* obj, obj_ptr ptr);

// Write barrier: notify the GC that `obj` was mutated to point to `target`
// during tracing. If `obj` is marked but `target` is not, `target` is added
// to the mutation worklist. Used for objects that could be cyclic:
//   - obj points to cyclic objects (directly or indirectly)
//   - obj could be cyclic
void syli_rt_object_notify_mutation(
    Object* obj, Object* target, obj_ptr target_ptr);

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

#endif /* SYLI_H */
