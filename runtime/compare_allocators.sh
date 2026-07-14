#!/bin/bash

# Compare allocator performance
# Usage: ./compare_allocators.sh [iterations]

ITERATIONS=${1:-1}

echo "🚀 GC Runtime - Allocator Performance Comparison"
echo "=================================================="
echo "Running $ITERATIONS iteration(s) per allocator"
echo

ALLOCATORS=("debug" "native" "mimalloc" "tcmalloc" "jemalloc")

# Arrays to store results for each benchmark
declare -a BENCH_NAMES
declare -A BENCH_RESULTS

# First pass: collect all results
for alloc in "${ALLOCATORS[@]}"; do
    if [ "$alloc" = "native" ]; then
        BUILD_DIR="cmake-allocators/native"
    elif [ "$alloc" = "debug" ]; then
        BUILD_DIR="cmake-allocators/debug"
    else
        BUILD_DIR="cmake-allocators/$alloc"
    fi

    if [ -f "$BUILD_DIR/bench_gc" ]; then
        echo "📊 Running benchmarks with $alloc allocator..."
        # Run benchmark
        if [ $ITERATIONS -eq 1 ]; then
            OUTPUT=$("$BUILD_DIR/bench_gc" --summary 2>/dev/null)
        else
            OUTPUT=$("$BUILD_DIR/bench_gc" --summary 2>/dev/null)
        fi

        # Store output for this allocator
        eval "OUTPUT_$alloc=\"$OUTPUT\""
    else
        echo "❌ Warning: $BUILD_DIR/bench_gc not found. Run ./build_all_allocators.sh first."
    fi
done

# Second pass: parse all collected outputs
for alloc in "${ALLOCATORS[@]}"; do
    if [ "$alloc" = "native" ]; then
        BUILD_DIR="cmake-allocators/native"
    elif [ "$alloc" = "debug" ]; then
        BUILD_DIR="cmake-allocators/debug"
    else
        BUILD_DIR="cmake-allocators/$alloc"
    fi

    if [ -f "$BUILD_DIR/bench_gc" ]; then
        # Get the stored output
        OUTPUT_VAR="OUTPUT_$alloc"
        OUTPUT=$(eval "echo \"\$$OUTPUT_VAR\"")

        # Parse benchmark results
        bench_num=0
        while IFS= read -r line; do
            if [[ $line =~ ^scenario: ]]; then
                bench_num=$((bench_num + 1))
                bench_name=$(echo "$line" | sed 's/^scenario: //')
                BENCH_NAMES[$bench_num]="$bench_name"
            elif [[ $line =~ "  avg throughput:" ]] && [ $bench_num -gt 0 ]; then
                throughput=$(echo "$line" | awk '{print $3}')
                BENCH_RESULTS["${bench_num}_${alloc}_throughput"]="$throughput"
            elif [[ $line =~ "  avg gc cycles:" ]] && [ $bench_num -gt 0 ]; then
                gc_cycles=$(echo "$line" | awk '{print $4}')
                BENCH_RESULTS["${bench_num}_${alloc}_cycles"]="$gc_cycles"
            elif [[ $line =~ "  peak candidates (max):" ]] && [ $bench_num -gt 0 ]; then
                peak=$(echo "$line" | awk '{print $4}')
                BENCH_RESULTS["${bench_num}_${alloc}_peak"]="$peak"
            elif [[ $line =~ "  max pause:" ]] && [ $bench_num -gt 0 ]; then
                pause_time=$(echo "$line" | awk '{print $3}')
                BENCH_RESULTS["${bench_num}_${alloc}_pause"]="$pause_time"
            elif [[ $line =~ "  avg alloc time:" ]] && [ $bench_num -gt 0 ]; then
                alloc_time=$(echo "$line" | awk '{print $4}')
                BENCH_RESULTS["${bench_num}_${alloc}_alloc"]="$alloc_time"
            elif [[ $line =~ "  avg gc time:" ]] && [ $bench_num -gt 0 ]; then
                gc_time=$(echo "$line" | awk '{print $4}')
                BENCH_RESULTS["${bench_num}_${alloc}_gc_time"]="$gc_time"
            elif [[ $line =~ "  avg all time:" ]] && [ $bench_num -gt 0 ]; then
                all_time=$(echo "$line" | awk '{print $4}')
                BENCH_RESULTS["${bench_num}_${alloc}_all"]="$all_time"
            fi
        done <<< "$OUTPUT"
    fi
done

echo
echo "📈 Performance Analysis by Benchmark"
echo "====================================="
echo

# Display results for each benchmark
for bench_num in $(seq 1 ${#BENCH_NAMES[@]}); do
    bench_name="${BENCH_NAMES[$bench_num]}"
    if [ -z "$bench_name" ]; then
        continue
    fi

    echo "📈 Benchmark $bench_num: $bench_name"
    echo "============================================================================="
    echo
    
    printf "%-12s %-15s %-10s %-12s %-12s %-12s %-12s\n" "Allocator" "Throughput" "GC Cycles" "Max Pause" "Alloc Time" "GC Time" "All Time"
    echo "---------------------------------------------------------------------------------------------"

    # Find best throughput for this benchmark
    best_throughput=0
    best_alloc=""
    for alloc in "${ALLOCATORS[@]}"; do
        throughput="${BENCH_RESULTS[${bench_num}_${alloc}_throughput]}"
        if [ -n "$throughput" ] && [ "$throughput" != "N/A" ]; then
            if awk "BEGIN {exit !($throughput > $best_throughput)}"; then
                best_throughput=$throughput
                best_alloc=$alloc
            fi
        fi
    done

    # Display results for this benchmark
    for alloc in "${ALLOCATORS[@]}"; do
        throughput="${BENCH_RESULTS[${bench_num}_${alloc}_throughput]}"
        gc_cycles="${BENCH_RESULTS[${bench_num}_${alloc}_cycles]}"
        pause_time="${BENCH_RESULTS[${bench_num}_${alloc}_pause]}"
        alloc_time="${BENCH_RESULTS[${bench_num}_${alloc}_alloc]}"
        gc_time="${BENCH_RESULTS[${bench_num}_${alloc}_gc_time]}"
        all_time="${BENCH_RESULTS[${bench_num}_${alloc}_all]}"

        # Show data if we have any metrics for this benchmark/allocator combination
        if [ -n "$throughput" ] || [ -n "$gc_cycles" ] || [ -n "$pause_time" ] || [ -n "$all_time" ]; then
            # Format values
            if [ -n "$throughput" ]; then
                tput_str="$(printf '%.0f obj/ms' "$throughput")"
            else
                tput_str=""
            fi
            cycles_str="${gc_cycles:-0}"
            pause_str="${pause_time:-0.0} ms"
            alloc_str="${alloc_time:-N/A} ms"
            gc_str="${gc_time:-N/A} ms"
            all_str="${all_time:-N/A} ms"
            
            # Mark the best performer
            if [ "$alloc" = "$best_alloc" ]; then
                printf "%-12s %-15s %-10s %-12s %-12s %-12s %-12s ⭐\n" "$alloc" "$tput_str" "$cycles_str" "$pause_str" "$alloc_str" "$gc_str" "$all_str"
            else
                printf "%-12s %-15s %-10s %-12s %-12s %-12s %-12s\n" "$alloc" "$tput_str" "$cycles_str" "$pause_str" "$alloc_str" "$gc_str" "$all_str"
            fi
        else
            printf "%-12s %-15s %-10s %-12s %-12s %-12s %-12s\n" "$alloc" "N/A" "N/A" "N/A" "N/A" "N/A" "N/A"
        fi
    done

    echo
done

echo "💡 Notes:"
echo "   • Higher throughput = better allocation/GC performance"
echo "   • Lower pause times = better responsiveness (GC latency)"
echo "   • Alloc Time = object allocation only, GC Time = garbage collection, All Time = allocation + GC cleanup"
echo "   • ⭐ indicates the best throughput for each benchmark"
echo "   • Run with argument to repeat: ./compare_allocators.sh 3"
echo "   • Run './build_all_allocators.sh' to rebuild all allocators"