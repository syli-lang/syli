CMAKE := cmake
GENERATOR := Ninja Multi-Config
BUILD_DIR := cmake-build

# Determine which config to use based on .build_type file
BUILD_TYPE = $(shell \
	if [ -f .build_type ] && [ "$$(cat .build_type)" = "Debug" ]; then \
		echo Debug; \
	else \
		echo Release; \
	fi)

# Phony targets - these don't produce files with matching names
.PHONY: all build debug release set-debug set-release syliruntime \
        mode test test-debug test-release test-header-object test-chunk-vector clean distclean help

# Help target
help:
	@echo "Available targets:"
	@echo "  mode                 - Show current build mode (Debug or Release)"
	@echo "  all                  - Build both Debug and Release (default)"
	@echo "  build                - Build both Debug and Release"
	@echo "  debug                - Set and build Debug configuration"
	@echo "  release              - Set and build Release configuration"
	@echo "  set-debug            - Set default build mode to Debug"
	@echo "  set-release          - Set default build mode to Release"
	@echo "  syliruntime          - Build syliruntime for both configurations"
	@echo "  test                 - Run tests (uses current build mode)"
	@echo "  test-debug           - Run Debug tests"
	@echo "  test-release         - Run Release tests"
	@echo "  test-header-object   - Build and run test_header_object (current mode)"
	@echo "  test-chunk-vector    - Build and run test_chunk_vector (current mode)"
	@echo "  clean                - Remove build directory"
	@echo "  distclean            - Deep clean (removes .build_type too)"
	@echo "  help                 - Show this help message"

# Show current build mode
mode:
	@if [ -f .build_type ]; then \
		cat .build_type; \
	else \
		echo "Release"; \
	fi

# Default target
all: build

# Configure once (supports all configurations)
$(BUILD_DIR)/build.ninja: CMakeLists.txt
	$(CMAKE) -S . -B $(BUILD_DIR) -G "$(GENERATOR)"

# Config target - ensures build directory is configured
config: $(BUILD_DIR)/build.ninja

# Build both configurations
build: config
	$(CMAKE) --build $(BUILD_DIR) --config Debug
	$(CMAKE) --build $(BUILD_DIR) --config Release

# Set build type state
set-debug:
	@echo Debug > .build_type
	@echo "Build mode set to Debug"

set-release:
	@echo Release > .build_type
	@echo "Build mode set to Release"

# Build the currently selected configuration
debug: set-debug config
	$(CMAKE) --build $(BUILD_DIR) --config Debug

release: set-release config
	$(CMAKE) --build $(BUILD_DIR) --config Release

# Build syliruntime for both configurations
syliruntime: config
	$(CMAKE) --build $(BUILD_DIR) --config Debug --target syliruntime
	$(CMAKE) --build $(BUILD_DIR) --config Release --target syliruntime

# Run tests on the currently selected configuration
test: config
	$(CMAKE) --build $(BUILD_DIR) --config $(BUILD_TYPE) --target test

# Run tests explicitly on Debug
test-debug: config
	$(CMAKE) --build $(BUILD_DIR) --config Debug --target test

# Run tests explicitly on Release
test-release: config
	$(CMAKE) --build $(BUILD_DIR) --config Release --target test

# Build and run (current mode)
test-header-object: config
	$(CMAKE) --build $(BUILD_DIR) --config $(BUILD_TYPE) --target test_header_object
	./$(BUILD_DIR)/$(BUILD_TYPE)/test_header_object

test-chunk-vector: config
	$(CMAKE) --build $(BUILD_DIR) --config $(BUILD_TYPE) --target test_chunk_vector
	./$(BUILD_DIR)/$(BUILD_TYPE)/test_chunk_vector

test-object: config
	$(CMAKE) --build $(BUILD_DIR) --config $(BUILD_TYPE) --target test_object
	./$(BUILD_DIR)/$(BUILD_TYPE)/test_object

bench: config
	$(CMAKE) --build $(BUILD_DIR) --config $(BUILD_TYPE) --target bench
	

# Clean build directory
clean:
	@echo "Cleaning build directory..."
	rm -rf $(BUILD_DIR)
	@echo "Clean complete"

# Deep clean - remove everything including build type state
distclean: clean
	@echo "Removing build mode state..."
	rm -f .build_type
	@echo "Deep clean complete"
