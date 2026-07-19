#!/bin/bash
set -e
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"

export SYLI_RUNTIME_LIB="$ROOT/runtime/cmake-build/Release/libsyliruntime.a"

build() {
  echo "Building $1..."
  cd "$ROOT"
  dune exec sylic -- build "bench/$1.sy" 2>/dev/null
  mv "$1.exe" "bench/$1.exe" 2>/dev/null || true
  cd "$OLDPWD"
}

bench() {
  echo ""
  echo "=== $1 ==="
  hyperfine -w 3 -m 5 "./$1.exe"
}

bench_mem() {
  /usr/bin/time -v "./$1.exe" 2>&1 | grep 'Maximum resident' | awk '{print $6}'
}

BENCHMARKS="tak queens clos clos4"

for b in $BENCHMARKS; do
  build "$b"
done

for b in $BENCHMARKS; do
  bench "$b"
done

echo ""
echo "=== Memory usage ==="
for b in $BENCHMARKS; do
  mem=$(bench_mem "$b")
  printf "  %-8s %s KB\n" "$b" "$mem"
done
