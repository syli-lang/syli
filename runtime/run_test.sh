#!/bin/bash
set -euo pipefail

# Get current datetime in YYYY-MM-DD_HH-MM-SS format
DATETIME=$(date +%Y-%m-%d_%H-%M-%S)

# Build type (default: Release for performance)
BUILD_TYPE=${1:-Release}
BUILD_DIR="cmake-build"

# Always (re)configure to heal stale build trees
cmake -S . -B "$BUILD_DIR" -G "Ninja Multi-Config"

# Build and run test target
cmake --build "$BUILD_DIR" --config "$BUILD_TYPE" --target test