#include "syli/env.h"
#include <stdlib.h>

Syli_Env syli_env;

void syli_load_env()
{
    Syli_Env env;

    // Default env
    env.syli_gc_release_threshold = 1000;
    env.syli_gc_suspect_threshold = 1000;

    const char* env_suspect_threshold = getenv("SYLI_GC_SUSPECT_THRESHOLD");
    if (env_suspect_threshold != NULL) {
        char* end                = NULL;
        unsigned long long value = strtoull(env_suspect_threshold, &end, 10);
        if (end != env_suspect_threshold && *end == '\0') {
            env.syli_gc_suspect_threshold = value;
        }
    }

    const char* env_releasing_threshold = getenv("SYLI_GC_RELEASING_THRESHOLD");
    if (env_releasing_threshold != NULL) {
        char* end                = NULL;
        unsigned long long value = strtoull(env_releasing_threshold, &end, 10);
        if (end != env_releasing_threshold && *end == '\0') {
            env.syli_gc_release_threshold = value;
        }
    }

    syli_env = env;
}