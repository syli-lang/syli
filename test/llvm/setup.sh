#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if [ -n "${SYLI_PROJECT_ROOT:-}" ]; then
  PROJECT_ROOT=$SYLI_PROJECT_ROOT
elif [ -n "${DUNE_SOURCEROOT:-}" ]; then
  PROJECT_ROOT=$DUNE_SOURCEROOT
else
  PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
fi

export SYLI_PROJECT_ROOT="$PROJECT_ROOT"
export SYLI_RUNTIME_LIB="$SYLI_PROJECT_ROOT/runtime/cmake-build/Debug/libsyliruntime.a"

# Alias some commands if they does not exist
find_cmd() {
    local name="$1"

    # prefer versioned LLVM tools first
    for ver in 21 20 19 18 17; do
        command -v "${name}-${ver}" >/dev/null 2>&1 && {
            printf '%s\n' "${name}-${ver}"
            return
        }
    done

    # fallback to unversioned tool if it exists
    if command -v "$name" >/dev/null 2>&1; then
        printf '%s\n' "$name"
        return
    fi

    # last resort (keeps your env var defined, even if broken)
    printf '%s\n' "$name"
}

export SYLI_LLC="$(find_cmd llc)"
export SYLI_CC="$(find_cmd clang)"
export SYLI_OPT="$(find_cmd opt)"

alias opt="$SYLI_OPT"
alias clang="$SYLI_CC"
alias llc="$SYLI_LLC"
