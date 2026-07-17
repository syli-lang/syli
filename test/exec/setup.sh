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

export SYLI_CC="clang"
