#!/bin/bash

# Performance profiling script using Linux perf and flame graphs
#
# Usage:
#   ./perf.sh              # Use Release build (default)
#   ./perf.sh Release      # Explicitly use Release
#   ./perf.sh Debug        # Use Debug build
#
# Requirements:
#   - Linux perf tools
#   - FlameGraph (https://github.com/brendangregg/FlameGraph)
#   - stackcollapse-perf.pl and flamegraph.pl in PATH

# Build type for profiling (default: Release for performance)
BUILD_TYPE=${1:-Release}
BUILD_DIR="cmake-build"
CONFIG_DIR="$BUILD_DIR/$BUILD_TYPE"

# Configure with CMake if not already done
if [ ! -f "$BUILD_DIR/CMakeCache.txt" ]; then
    cmake -S . -B "$BUILD_DIR" -G "Ninja Multi-Config"
fi

# Build the benchmark if not already built
if [ ! -f "$CONFIG_DIR/bench_gc" ]; then
    cmake --build "$BUILD_DIR" --config "$BUILD_TYPE" --target bench_gc
fi

# Run perf profiling on bench_gc
echo "Profiling bench_gc with perf..."
sudo perf record -F max -g -o "$CONFIG_DIR/perf.data" -- "$CONFIG_DIR/bench_gc" --silent

# Generate flame graph
echo "Generating flame graph..."
sudo perf script -i "$CONFIG_DIR/perf.data" > "$CONFIG_DIR/out.perf"
stackcollapse-perf.pl "$CONFIG_DIR/out.perf" > "$CONFIG_DIR/out.folded"
flamegraph.pl "$CONFIG_DIR/out.folded" > "$CONFIG_DIR/flamegraph.svg"

echo "Flame graph generated: $CONFIG_DIR/flamegraph.svg"
echo "Perf data: $CONFIG_DIR/perf.data"