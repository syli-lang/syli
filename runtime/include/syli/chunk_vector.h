#ifndef CHUNK_VECTOR_H
#define CHUNK_VECTOR_H

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>

#ifndef NULL
#define NULL ((void*)0)
#endif

#ifndef CHUNK_VECTOR_CHUNK_SIZE
#define CHUNK_VECTOR_CHUNK_SIZE 512
#endif
#ifndef CHUNK_VECTOR_INITIAL_CHUNK_ARRAY_CAPACITY
#define CHUNK_VECTOR_INITIAL_CHUNK_ARRAY_CAPACITY 64
#endif

#define CHUNK_VECTOR_CONCAT_(a, b) a##_##b
#define CHUNK_VECTOR_CONCAT(a, b)  CHUNK_VECTOR_CONCAT_(a, b)
#define CHUNK_VECTOR_TYPE(T)       CHUNK_VECTOR_CONCAT(vector, T)

#define CHUNK_VECTOR_STRUCT(T)                                                 \
    typedef struct {                                                           \
        T** chunks;                                                            \
        uint32_t chunk_count;                                                  \
        uint32_t chunk_array_capacity;                                         \
        uint32_t active_chunk;                                                 \
        uint64_t active_offset;                                                \
        uint64_t total_elements;                                               \
    } CHUNK_VECTOR_TYPE(T)

#define CHUNK_VECTOR_DECLARE(T)                                                \
    CHUNK_VECTOR_STRUCT(T);                                                    \
    void CHUNK_VECTOR_CONCAT(vector_init, T)(CHUNK_VECTOR_TYPE(T) * cv);       \
    void CHUNK_VECTOR_CONCAT(vector_destroy, T)(CHUNK_VECTOR_TYPE(T) * cv);    \
    void CHUNK_VECTOR_CONCAT(vector_push_back, T)(                             \
        CHUNK_VECTOR_TYPE(T) * cv, T * value);                                 \
    void CHUNK_VECTOR_CONCAT(vector_pop_back, T)(CHUNK_VECTOR_TYPE(T) * cv);   \
    T* CHUNK_VECTOR_CONCAT(vector_alloc_slot, T)(CHUNK_VECTOR_TYPE(T) * cv);   \
    T* CHUNK_VECTOR_CONCAT(vector_at, T)(                                      \
        CHUNK_VECTOR_TYPE(T) * cv, uint64_t index);                            \
    const T* CHUNK_VECTOR_CONCAT(vector_at_const, T)(                          \
        const CHUNK_VECTOR_TYPE(T) * cv, uint64_t index);                      \
    T* CHUNK_VECTOR_CONCAT(vector_back, T)(CHUNK_VECTOR_TYPE(T) * cv);         \
    uint64_t CHUNK_VECTOR_CONCAT(vector_size, T)(                              \
        const CHUNK_VECTOR_TYPE(T) * cv);                                      \
    int CHUNK_VECTOR_CONCAT(vector_empty, T)(const CHUNK_VECTOR_TYPE(T) * cv); \
    void CHUNK_VECTOR_CONCAT(vector_clear, T)(CHUNK_VECTOR_TYPE(T) * cv)

#define CHUNK_VECTOR_IMPLEMENT(T)                                              \
    static inline uint64_t CHUNK_VECTOR_CONCAT(vector_chunk_capacity, T)(      \
        uint32_t chunk_idx)                                                    \
    {                                                                          \
        (void)chunk_idx;                                                       \
        return CHUNK_VECTOR_CHUNK_SIZE;                                        \
    }                                                                          \
                                                                               \
    static inline void CHUNK_VECTOR_CONCAT(vector_index_to_chunk, T)(          \
        uint64_t index, uint32_t* chunk_idx, uint64_t* offset)                 \
    {                                                                          \
        *chunk_idx = (uint32_t)(index / CHUNK_VECTOR_CHUNK_SIZE);              \
        *offset    = index % CHUNK_VECTOR_CHUNK_SIZE;                          \
    }                                                                          \
                                                                               \
    static inline void CHUNK_VECTOR_CONCAT(vector_init, T)(                    \
        CHUNK_VECTOR_TYPE(T) * cv)                                             \
    {                                                                          \
        cv->chunks = (T**)malloc(                                              \
            sizeof(T*) * CHUNK_VECTOR_INITIAL_CHUNK_ARRAY_CAPACITY);           \
        cv->chunk_array_capacity = CHUNK_VECTOR_INITIAL_CHUNK_ARRAY_CAPACITY;  \
        cv->chunk_count          = 0;                                          \
        cv->active_chunk         = 0;                                          \
        cv->active_offset        = 0;                                          \
        cv->total_elements       = 0;                                          \
        cv->chunks[0]            = (T*)malloc(sizeof(T) * CHUNK_VECTOR_CHUNK_SIZE); \
        cv->chunk_count = 1;                                                   \
    }                                                                          \
                                                                               \
    static inline void CHUNK_VECTOR_CONCAT(vector_destroy, T)(                 \
        CHUNK_VECTOR_TYPE(T) * cv)                                             \
    {                                                                          \
        if (!cv->chunks)                                                       \
            return;                                                            \
        for (uint32_t i = 0; i < cv->chunk_count; i++)                         \
            free(cv->chunks[i]);                                               \
        free(cv->chunks);                                                      \
        cv->chunks         = NULL;                                             \
        cv->chunk_count    = 0;                                                \
        cv->total_elements = 0;                                                \
    }                                                                          \
                                                                               \
    static inline T* CHUNK_VECTOR_CONCAT(vector_alloc_slot, T)(                \
        CHUNK_VECTOR_TYPE(T) * cv)                                             \
    {                                                                          \
        if (cv->active_offset >= CHUNK_VECTOR_CHUNK_SIZE) {                    \
            cv->active_chunk++;                                                \
            cv->active_offset = 0;                                             \
            if (cv->active_chunk >= cv->chunk_array_capacity) {                \
                cv->chunk_array_capacity *= 2;                                 \
                T** new_chunks = (T**)realloc(                                 \
                    cv->chunks, sizeof(T*) * cv->chunk_array_capacity);        \
                if (!new_chunks) {                                             \
                    return NULL;                                               \
                }                                                              \
                cv->chunks = new_chunks;                                       \
            }                                                                  \
            if (cv->active_chunk >= cv->chunk_count) {                         \
                cv->chunks[cv->active_chunk]                                   \
                    = (T*)malloc(sizeof(T) * CHUNK_VECTOR_CHUNK_SIZE);         \
                if (!cv->chunks[cv->active_chunk]) {                           \
                    cv->active_chunk--;                                        \
                    cv->active_offset = CHUNK_VECTOR_CHUNK_SIZE;               \
                    return NULL;                                               \
                }                                                              \
                cv->chunk_count++;                                             \
            }                                                                  \
        }                                                                      \
        T* result = &cv->chunks[cv->active_chunk][cv->active_offset];          \
        cv->active_offset++;                                                   \
        cv->total_elements++;                                                  \
        return result;                                                         \
    }                                                                          \
                                                                               \
    static inline void CHUNK_VECTOR_CONCAT(vector_push_back, T)(               \
        CHUNK_VECTOR_TYPE(T) * cv, T * value)                                  \
    {                                                                          \
        if (cv->active_offset >= CHUNK_VECTOR_CHUNK_SIZE) {                    \
            cv->active_chunk++;                                                \
            cv->active_offset = 0;                                             \
            if (cv->active_chunk >= cv->chunk_array_capacity) {                \
                cv->chunk_array_capacity *= 2;                                 \
                T** new_chunks = (T**)realloc(                                 \
                    cv->chunks, sizeof(T*) * cv->chunk_array_capacity);        \
                if (!new_chunks)                                               \
                    return;                                                    \
                cv->chunks = new_chunks;                                       \
            }                                                                  \
            if (cv->active_chunk >= cv->chunk_count) {                         \
                cv->chunks[cv->active_chunk]                                   \
                    = (T*)malloc(sizeof(T) * CHUNK_VECTOR_CHUNK_SIZE);         \
                cv->chunk_count++;                                             \
            }                                                                  \
        }                                                                      \
        cv->chunks[cv->active_chunk][cv->active_offset] = *value;              \
        cv->active_offset++;                                                   \
        cv->total_elements++;                                                  \
    }                                                                          \
                                                                               \
    static inline void CHUNK_VECTOR_CONCAT(vector_pop_back, T)(                \
        CHUNK_VECTOR_TYPE(T) * cv)                                             \
    {                                                                          \
        if (cv->total_elements == 0)                                           \
            return;                                                            \
        cv->total_elements--;                                                  \
        if (cv->active_offset > 0) {                                           \
            cv->active_offset--;                                               \
        } else {                                                               \
            cv->active_chunk--;                                                \
            cv->active_offset = CHUNK_VECTOR_CHUNK_SIZE - 1;                   \
        }                                                                      \
    }                                                                          \
                                                                               \
    static inline T* CHUNK_VECTOR_CONCAT(vector_at, T)(                        \
        CHUNK_VECTOR_TYPE(T) * cv, uint64_t index)                             \
    {                                                                          \
        if (index >= cv->total_elements)                                       \
            return NULL;                                                       \
        uint32_t chunk_idx;                                                    \
        uint64_t offset;                                                       \
        CHUNK_VECTOR_CONCAT(vector_index_to_chunk, T)                          \
        (index, &chunk_idx, &offset);                                          \
        return &cv->chunks[chunk_idx][offset];                                 \
    }                                                                          \
                                                                               \
    static inline const T* CHUNK_VECTOR_CONCAT(vector_at_const, T)(            \
        const CHUNK_VECTOR_TYPE(T) * cv, uint64_t index)                       \
    {                                                                          \
        if (index >= cv->total_elements)                                       \
            return NULL;                                                       \
        uint32_t chunk_idx;                                                    \
        uint64_t offset;                                                       \
        CHUNK_VECTOR_CONCAT(vector_index_to_chunk, T)                          \
        (index, &chunk_idx, &offset);                                          \
        return &cv->chunks[chunk_idx][offset];                                 \
    }                                                                          \
                                                                               \
    static inline T* CHUNK_VECTOR_CONCAT(vector_back, T)(                      \
        CHUNK_VECTOR_TYPE(T) * cv)                                             \
    {                                                                          \
        if (cv->total_elements == 0)                                           \
            return NULL;                                                       \
        if (cv->active_offset > 0) {                                           \
            return &cv->chunks[cv->active_chunk][cv->active_offset - 1];       \
        } else {                                                               \
            uint32_t chunk_idx = cv->active_chunk - 1;                         \
            return &cv->chunks[chunk_idx][CHUNK_VECTOR_CHUNK_SIZE - 1];        \
        }                                                                      \
    }                                                                          \
                                                                               \
    static inline uint64_t CHUNK_VECTOR_CONCAT(vector_size, T)(                \
        const CHUNK_VECTOR_TYPE(T) * cv)                                       \
    {                                                                          \
        return cv->total_elements;                                             \
    }                                                                          \
                                                                               \
    static inline int CHUNK_VECTOR_CONCAT(vector_empty, T)(                    \
        const CHUNK_VECTOR_TYPE(T) * cv)                                       \
    {                                                                          \
        return cv->total_elements == 0;                                        \
    }                                                                          \
                                                                               \
    static inline void CHUNK_VECTOR_CONCAT(vector_clear, T)(                   \
        CHUNK_VECTOR_TYPE(T) * cv)                                             \
    {                                                                          \
        cv->active_chunk   = 0;                                                \
        cv->active_offset  = 0;                                                \
        cv->total_elements = 0;                                                \
    }

#define CHUNK_VECTOR_INIT(type)    CHUNK_VECTOR_CONCAT(vector_init, type)
#define CHUNK_VECTOR_DESTROY(type) CHUNK_VECTOR_CONCAT(vector_destroy, type)
#define CHUNK_VECTOR_PUSH(type)    CHUNK_VECTOR_CONCAT(vector_push_back, type)
#define CHUNK_VECTOR_ALLOC_SLOT(type)                                          \
    CHUNK_VECTOR_CONCAT(vector_alloc_slot, type)
#define CHUNK_VECTOR_POP(type)   CHUNK_VECTOR_CONCAT(vector_pop_back, type)
#define CHUNK_VECTOR_AT(type)    CHUNK_VECTOR_CONCAT(vector_at, type)
#define CHUNK_VECTOR_BACK(type)  CHUNK_VECTOR_CONCAT(vector_back, type)
#define CHUNK_VECTOR_SIZE(type)  CHUNK_VECTOR_CONCAT(vector_size, type)
#define CHUNK_VECTOR_EMPTY(type) CHUNK_VECTOR_CONCAT(vector_empty, type)
#define CHUNK_VECTOR_CLEAR(type) CHUNK_VECTOR_CONCAT(vector_clear, type)

#endif // CHUNK_VECTOR_H
