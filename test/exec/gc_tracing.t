We are showing here that the tracing is working.
With this simple example we need to reduce the thresholds:
SYLI_GC_RELEASING_THRESHOLD=0 SYLI_GC_SUSPECT_THRESHOLD=0
  $ cat >gc_state.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  >   extern syli_print_gc_state : unit -> unit = "syli_print_gc_state"
  > end
  > type box = { c : ref int64 }
  > fn main () =
  >   let child = ref 42
  >   let r1 = { c = child }
  >   let r2 = { c = child }
  >   let tmp = { c = child }
  >   let keep = ref 7
  >   let c1 = r1.c
  >   let c2 = r2.c
  >   let k1 = *keep
  >   let v = *child
  >   syli_print_i64 (*c1)
  >   syli_print_i64 (*c2)
  >   syli_print_i64 (v)
  >   syli_print_i64 (k1)
  >   let flush1 = ref 1
  >   let flush2 = ref 2
  >   let flush3 = ref 3
  >   let flush4 = ref 4
  >   let flush5 = ref 5
  >   syli_print_gc_state ()
  > EOF
  $ dune exec sylic -- build gc_state.sy
  $ SYLI_GC_RELEASING_THRESHOLD=0 SYLI_GC_SUSPECT_THRESHOLD=0 ./gc_state.exe
  4242427GC[tracing_state=Idle releasing_state=Idle generations=2 suspects=0 suspect-notif=0 traced=3 freed=10 release-waitlist=0 tracing-worklist=0]

Without the reducing the treshold, no tracing for this simple example:
  $ ./gc_state.exe
  4242427GC[tracing_state=Idle releasing_state=Idle generations=0 suspects=1 suspect-notif=3 traced=0 freed=6 release-waitlist=3 tracing-worklist=0]

It shows even with this simple example object is still be freed.
And tracing also still works.
  $ cat >basic.sy <<EOF
  > signature:
  >   extern syli_print_i64 : int64 -> unit = "syli_print_i64"
  >   extern syli_print_gc_state : unit -> unit = "syli_print_gc_state"
  > end
  > type box = { c : ref int64 }
  > fn main () =
  >   let child = ref 42
  >   let r1 = { c = child }
  >   let r2 = { c = child }
  >   syli_print_gc_state ()
  >   syli_print_i64 (*child)
  >   syli_print_gc_state ()
  > EOF
  $ dune exec sylic -- build basic.sy
  $ SYLI_GC_RELEASING_THRESHOLD=0 SYLI_GC_SUSPECT_THRESHOLD=0 ./basic.exe
  GC[tracing_state=Idle releasing_state=Idle generations=1 suspects=1 suspect-notif=0 traced=1 freed=1 release-waitlist=1 tracing-worklist=0]
  42GC[tracing_state=Idle releasing_state=Idle generations=1 suspects=1 suspect-notif=1 traced=1 freed=1 release-waitlist=1 tracing-worklist=0]

  $ ./basic.exe
  GC[tracing_state=Idle releasing_state=Idle generations=0 suspects=0 suspect-notif=0 traced=0 freed=0 release-waitlist=2 tracing-worklist=0]
  42GC[tracing_state=Idle releasing_state=Idle generations=0 suspects=1 suspect-notif=1 traced=0 freed=0 release-waitlist=2 tracing-worklist=0]
