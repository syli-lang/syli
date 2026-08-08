#ifndef SYLI_ENV_H
#define SYLI_ENV_H

#include <stdint.h>

typedef struct {
    uint64_t syli_gc_suspect_threshold;
    uint64_t syli_gc_release_threshold;

} Syli_Env;

extern Syli_Env syli_env;

void syli_load_env();

#endif