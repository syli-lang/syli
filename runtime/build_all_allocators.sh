#!/bin/bash

# Build all allocators for performance comparison
# Usage: ./build_all_allocators.sh

set -e

echo "=== Building GC Runtime with Different Allocators ==="
echo

ALLOCATORS=("debug" "native" "mimalloc" "tcmalloc" "jemalloc")

for alloc in "${ALLOCATORS[@]}"; do
    echo "=== Building with $alloc allocator ==="

    if [ "$alloc" = "debug" ]; then
        BUILD_DIR="cmake-allocators/debug"
        CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Debug"
    elif [ "$alloc" = "native" ]; then
        BUILD_DIR="cmake-allocators/native"
        CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Release"
    else
        BUILD_DIR="cmake-allocators/$alloc"
        CMAKE_FLAGS="-DUSE_${alloc^^}=ON -DCMAKE_BUILD_TYPE=Release"
    fi

    # Create and configure build directory
    cmake -S . -B "$BUILD_DIR" $CMAKE_FLAGS -G Ninja
    
    # Build all targets including benchmarks
    cmake --build "$BUILD_DIR" --target bench_gc
    
    echo "✓ $alloc build complete"
    echo
done

echo "=== All allocator builds complete ==="
echo
echo "Build outputs:"
for alloc in "${ALLOCATORS[@]}"; do
    if [ "$alloc" = "debug" ]; then
        BUILD_DIR="cmake-allocators/debug"
    elif [ "$alloc" = "native" ]; then
        BUILD_DIR="cmake-allocators/native"
    else
        BUILD_DIR="cmake-allocators/$alloc"
    fi
    echo "  $alloc: $BUILD_DIR/bench_gc"
done
echo
echo "Run ./compare_allocators.sh to compare performance"
