#!/bin/bash
set -euo pipefail

# Get current datetime in YYYY-MM-DD_HH-MM-SS format
DATETIME=$(date +%Y-%m-%d_%H-%M-%S)

# Create the bench.log directory if it doesn't exist
mkdir -p bench.log

# Build type (default: Release for performance)
BUILD_TYPE=${1:-Release}
BUILD_DIR="cmake-build"

# Always (re)configure to heal stale build trees
cmake -S . -B "$BUILD_DIR" -G "Ninja Multi-Config"

# Build bench target and run
cmake --build "$BUILD_DIR" --config "$BUILD_TYPE" --target bench > "bench.log/bench_${DATETIME}.log" 2>&1

# Display the contents of the log file
cat "bench.log/bench_${DATETIME}.log"