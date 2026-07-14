# Runtime — Syli Runtime System

A high-performance runtime for the Syli programming language, implemented in C.

> [!WARNING]
> The benchmark are not realworld usage, it is for validating the runtime.

## Runtime API

### Object Management

- `syli_rt_rc_alloc_object(header, refcount, words)` — allocate a reference-counted GC object
- `syli_rt_shared_alloc(header, words)` — allocate a shared (non-RC) object

### Reference Counting

- `syli_rt_object_incr(obj)` / `syli_rt_object_decr(obj)` / `syli_rt_object_decr_n(obj, n)`
- `syli_rt_object_check_release(obj)` — free if refcount drops to zero
- `syli_rt_object_decr_drop(obj)` — unconditional drop; caller guarantees the object is no longer reachable
- `syli_rt_object_check_lost_cyclic_release(obj)` — flag object as a potential cycle root
- `syli_rt_object_notify_mutation(obj, target)` — write barrier: notify the GC that a reference from `obj` to `target` during the tracing phase. If the target is not marked yet, the target is added to the mutation worklist.

### GC — reference counting + tracing with cycle detection

Three independent incremental state machines, each with its own worklist and budget:

- **Tracing** (`Sy_Tracing`): 2-color mark from stack roots. The tracing flag guarantees each object is processed at most once per tracing phase. Iterates the tracing worklist; the mutations worklist captures unmarked children of objects modified by write barriers during tracing.
- **Dropping** (`Sy_Dropping`): processes the unreachable set. Traverses their reference graph, decrements child refcounts, and frees objects when their refcount reaches zero. Objects still referenced by siblings go to the dropping waitlist. It is scope freeing.
- **Releasing** (`Sy_Releasing`): frees memory for objects whose reference count reached zero. It for escaped objects and non escaped, this is general purpose usage.

`syli_rt_gc_cycle()` sets budgets for all three phases and calls them (releasing → dropping → tracing). Each phase is incremental — it processes a budgeted number of objects per invocation and returns to idle when its worklist is empty.

### Object Access

- `syli_rt_get_object_tag(obj)` — read object tag
- `syli_rt_get_object_length(obj)` — read object logical length

### Stack Frames

- `syli_rt_push_frame_scope(frame)` / `syli_rt_pop_frame_scope()` — register/unregister GC roots via the current stack frame. But it will not be used in native compiled program, it was introduced for testing puporse and may be used for a VM when it is available.

### Utility

- `syli_rt_object_copy(src)` — shallow copy an object
- `syli_rt_object_raw_copy(src, dst)` — raw memory copy between two objects

### Makefile

There is a `Makefile`, which you could use `make` command to build and run the tests.

### Allocator variants

The runtime supports pluggable memory allocators (mutually exclusive, one per build):

| Option | Allocator | Origin |
|---|---|---|
| (default) | `malloc`/`free` | System (glibc) |
| `-DUSE_MIMALLOC=ON` | mimalloc | Microsoft |
| `-DUSE_TCMALLOC=ON` | tcmalloc | Google |
| `-DUSE_JEMALLOC=ON` | jemalloc | Facebook |

```bash
# mimalloc build
cmake -S . -B cmake-allocators/mimalloc -DCMAKE_BUILD_TYPE=Release -DUSE_MIMALLOC=ON
cmake --build cmake-allocators/mimalloc -j

# tcmalloc build
cmake -S . -B cmake-allocators/tcmalloc -DCMAKE_BUILD_TYPE=Release -DUSE_TCMALLOC=ON
cmake --build cmake-allocators/tcmalloc -j

# jemalloc build
cmake -S . -B cmake-allocators/jemalloc -DCMAKE_BUILD_TYPE=Release -DUSE_JEMALLOC=ON
cmake --build cmake-allocators/jemalloc -j

# Compare all allocators
./build_all_allocators.sh
./compare_allocators.sh
```

## File Layout

```
runtime/
├── src/                  # Source files
├── include/syli/         # Public headers
├── tests/                # Unit tests and benchmarks
├── compat/               # Compatibility helpers
├── CMakeLists.txt
├── build_all_allocators.sh
├── compare_allocators.sh
├── run_bench.sh
├── perf.sh
└── run_test.sh
```

## Building

Requires CMake 3.20+ and a C11 compiler (GCC 10+, Clang 17+).

```bash
# Release build
cmake -S . -B cmake-build -G "Ninja Multi-Config"
cmake --build cmake-build --config Release -j

# Run benchmarks
./cmake-build/Release/bench_gc

# Run tests
cmake --build cmake-build --config Release -j --target test
```

### Sanitizers

```bash
cmake -S . -B cmake-build -G "Ninja Multi-Config" -DENABLE_ASAN=ON
cmake --build cmake-build --config Debug -j
```
