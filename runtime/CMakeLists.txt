cmake_minimum_required(VERSION 3.16)

find_program(CLANG clang)
if(CLANG AND NOT CMAKE_C_COMPILER)
    set(CMAKE_C_COMPILER "${CLANG}" CACHE FILEPATH "C compiler")
endif()

project(runtime VERSION 1.0.0 LANGUAGES C)

# Set C standard
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

# Export compile_commands.json for IDEs and tooling
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Set default build type to Release if not specified
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
endif()

# Common compiler flags
set(COMMON_C_FLAGS
    -Wall
    -Wextra
    -Wno-stringop-overflow
    -Wno-maybe-uninitialized
)

# Optional native architecture optimization
option(USE_MARCH_NATIVE "Enable -march=native optimization" ON)
if(USE_MARCH_NATIVE)
    list(APPEND COMMON_C_FLAGS -march=native)
endif()

# Add common flags to both configurations
add_compile_options(${COMMON_C_FLAGS})

# Debug flags
set(CMAKE_C_FLAGS_DEBUG "-O0 \
    -g \
    -fno-omit-frame-pointer \
    -fno-inline \
    -fno-inline-functions \
    -fno-inline-small-functions \
    -fkeep-inline-functions"
)

# Release flags
set(CMAKE_C_FLAGS_RELEASE "-O3 -DNDEBUG")

# Core runtime library
add_library(syliruntime STATIC
    src/syli_state.c
    src/syli_state_gc_releasing.c
    src/syli_state_gc_tracing.c
    src/syli_state_gc_dropping.c
    src/stack_frame.c
    src/main.c
    src/immediate.c
    src/syli.c
)

target_include_directories(syliruntime PUBLIC
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
)

target_link_libraries(syliruntime PRIVATE runtime_sanitizers)

# Allocator options
option(USE_MIMALLOC "Use mimalloc allocator" OFF)
option(USE_TCMALLOC "Use tcmalloc allocator" OFF)
option(USE_JEMALLOC "Use jemalloc allocator" OFF)

# Threading support (for future multi-threaded GC)
option(ENABLE_THREADING "Enable threading support" OFF)

# Sanitizer options (for debugging and testing)
option(ENABLE_ASAN "Enable AddressSanitizer" OFF)
option(ENABLE_TSAN "Enable ThreadSanitizer" OFF)
option(ENABLE_UBSAN "Enable UndefinedBehaviorSanitizer" OFF)

# Convert booleans to integers for counting
if(USE_MIMALLOC)
  set(MIMALLOC_COUNT 1)
else()
  set(MIMALLOC_COUNT 0)
endif()

if(USE_TCMALLOC)
  set(TCMALLOC_COUNT 1)
else()
  set(TCMALLOC_COUNT 0)
endif()

if(USE_JEMALLOC)
  set(JEMALLOC_COUNT 1)
else()
  set(JEMALLOC_COUNT 0)
endif()

math(EXPR ALLOC_COUNT "${MIMALLOC_COUNT} + ${TCMALLOC_COUNT} + ${JEMALLOC_COUNT}")

if(ALLOC_COUNT GREATER 1)
  message(FATAL_ERROR "Select only one allocator")
endif()

if(USE_MIMALLOC)
  find_package(mimalloc REQUIRED)
  target_link_libraries(syliruntime PRIVATE mimalloc)
  target_compile_definitions(syliruntime PRIVATE USE_MIMALLOC)
endif()

if(USE_TCMALLOC)
  find_library(TCMALLOC_LIB tcmalloc REQUIRED)
  target_link_libraries(syliruntime PRIVATE ${TCMALLOC_LIB})
  target_compile_definitions(syliruntime PRIVATE USE_TCMALLOC)
endif()

if(USE_JEMALLOC)
  find_library(JEMALLOC_LIB jemalloc REQUIRED)
  target_link_libraries(syliruntime PRIVATE ${JEMALLOC_LIB})
  target_compile_definitions(syliruntime PRIVATE USE_JEMALLOC)
endif()

# Threading support
if(ENABLE_THREADING)
  find_package(Threads REQUIRED)
  target_link_libraries(syliruntime PRIVATE Threads::Threads)
  target_compile_definitions(syliruntime PRIVATE ENABLE_THREADING)
endif()

# Sanitizer options (mutually exclusive for simplicity)
set(SANITIZER_COUNT 0)
if(ENABLE_ASAN)
  math(EXPR SANITIZER_COUNT "${SANITIZER_COUNT} + 1")
endif()
if(ENABLE_TSAN)
  math(EXPR SANITIZER_COUNT "${SANITIZER_COUNT} + 1")
endif()
if(ENABLE_UBSAN)
  math(EXPR SANITIZER_COUNT "${SANITIZER_COUNT} + 1")
endif()

if(SANITIZER_COUNT GREATER 1)
  message(FATAL_ERROR "Select only one sanitizer at a time")
endif()

# Interface library for sanitizer propagation
add_library(runtime_sanitizers INTERFACE)

if(ENABLE_ASAN)
  target_compile_options(runtime_sanitizers INTERFACE -fsanitize=address -fno-omit-frame-pointer)
  target_link_options(runtime_sanitizers INTERFACE -fsanitize=address)
  target_compile_definitions(runtime_sanitizers INTERFACE ENABLE_ASAN)
endif()

if(ENABLE_TSAN)
  target_compile_options(runtime_sanitizers INTERFACE -fsanitize=thread)
  target_link_options(runtime_sanitizers INTERFACE -fsanitize=thread)
  target_compile_definitions(runtime_sanitizers INTERFACE ENABLE_TSAN)
endif()

if(ENABLE_UBSAN)
  target_compile_options(runtime_sanitizers INTERFACE -fsanitize=undefined)
  target_link_options(runtime_sanitizers INTERFACE -fsanitize=undefined)
  target_compile_definitions(runtime_sanitizers INTERFACE ENABLE_UBSAN)
endif()

# Test executables

add_executable(test_stack_frame tests/test_stack_frame.c)
target_link_libraries(test_stack_frame PRIVATE syliruntime)

add_executable(test_header_object tests/test_header_object.c)
target_include_directories(test_header_object PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(test_header_object PRIVATE syliruntime)

add_executable(test_object tests/test_object.c)
target_link_libraries(test_object PRIVATE syliruntime)

add_executable(test_syli_state tests/test_syli_state.c)
target_link_libraries(test_syli_state PRIVATE syliruntime)

add_executable(test_gc tests/test_gc.c)
target_include_directories(test_gc PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(test_gc PRIVATE syliruntime)

add_executable(test_graph_marking tests/test_gc_tracing_graph.c)
target_include_directories(test_graph_marking PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(test_graph_marking PRIVATE syliruntime)

add_executable(test_chunk_vector tests/test_chunk_vector.c)
target_include_directories(test_chunk_vector PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(test_chunk_vector PRIVATE syliruntime)

add_executable(test_syli_api tests/test_syli_api.c)
target_include_directories(test_syli_api PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(test_syli_api PRIVATE syliruntime)

add_executable(bench_gc tests/bench_gc.c)
target_link_libraries(bench_gc PRIVATE syliruntime)

add_executable(bench_workload_profile tests/bench_workload_profile.c)
target_link_libraries(bench_workload_profile PRIVATE syliruntime)

add_executable(bench_chunk_vect_vs_double_vect tests/bench_chunk_vect_vs_double_vect.c)
target_include_directories(bench_chunk_vect_vs_double_vect PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(bench_chunk_vect_vs_double_vect PRIVATE syliruntime)

add_executable(bench_chunk_vector tests/bench_chunk_vector.c)
target_include_directories(bench_chunk_vector PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
)
if(UNIX AND NOT APPLE)
  target_link_libraries(bench_chunk_vector PRIVATE rt)
endif()

add_executable(bench_tracing_graph tests/bench_tracing_graph.c)
target_include_directories(bench_tracing_graph PRIVATE
    ${CMAKE_SOURCE_DIR}
    ${CMAKE_SOURCE_DIR}/include
)
target_link_libraries(bench_tracing_graph PRIVATE syliruntime)

# Custom targets for convenience
add_custom_target(build-tests
    DEPENDS
        test_header_object
        test_gc
        test_graph_marking
        test_chunk_vector
        test_object
        test_stack_frame
        test_syli_state
        test_syli_api
)

add_custom_target(build-bench
    DEPENDS
        bench_gc
        bench_workload_profile
        bench_chunk_vect_vs_double_vect
        bench_tracing_graph
        bench_chunk_vector
)

add_custom_target(build-all
    DEPENDS build-tests build-bench
)

# Run targets
add_custom_target(run-tests
    COMMAND $<TARGET_FILE:test_gc>
    COMMAND $<TARGET_FILE:test_chunk_vector>
    COMMAND $<TARGET_FILE:test_object>
    COMMAND $<TARGET_FILE:test_header_object>
    COMMAND $<TARGET_FILE:test_stack_frame>
    COMMAND $<TARGET_FILE:test_syli_state>
    COMMAND $<TARGET_FILE:test_syli_api>
    DEPENDS build-tests
    COMMENT "Running all tests"
)

add_custom_target(run-bench
    COMMAND $<TARGET_FILE:bench_gc>
    COMMAND $<TARGET_FILE:bench_workload_profile>
    COMMAND $<TARGET_FILE:bench_chunk_vect_vs_double_vect>
    COMMAND $<TARGET_FILE:bench_chunk_vector>
    COMMAND $<TARGET_FILE:bench_tracing_graph>
    DEPENDS build-bench
    COMMENT "Running all benchmarks"
)

# Combined targets
add_custom_target(test
    DEPENDS run-tests
    COMMENT "Building and running all tests"
)

add_custom_target(bench
    DEPENDS run-bench
    COMMENT "Building and running all benchmarks"
)

add_custom_target(all-tests-and-bench
    DEPENDS run-tests run-bench
    COMMENT "Building and running all tests and benchmarks"
)

# Clean target
add_custom_target(clean-all
    COMMAND ${CMAKE_COMMAND} --build . --target clean
    COMMENT "Cleaning all build artifacts"
)

# Default target
add_custom_target(default
    DEPENDS all-tests-and-bench
)
