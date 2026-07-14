#!/bin/bash

# the compiler env path
export SYLI_RUNTIME_LIB="runtime/cmake-build/Debug/libsyliruntime.a"

# Resolve LLVM tools
find_cmd() {
    local name="$1"

    for ver in 21 20 19 18 17; do
        command -v "${name}-${ver}" >/dev/null 2>&1 && {
            printf '%s\n' "${name}-${ver}"
            return
        }
    done

    if command -v "$name" >/dev/null 2>&1; then
        printf '%s\n' "$name"
        return
    fi

    printf '%s\n' "$name"
}

export SYLI_LLC="$(find_cmd llc)"
export SYLI_CC="$(find_cmd clang)"
export SYLI_OPT="$(find_cmd opt)"