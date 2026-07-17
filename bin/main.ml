let usage () =
  Printf.eprintf
    "Usage:\n\
    \  sylic lex \"file.yl\"\n\
    \  sylic parse \"file.yl\"\n\
    \  sylic typing \"file.yl\"\n\
    \  sylic alpha \"file.yl\"\n\
    \  sylic core \"file.yl\"\n\
    \  sylic cir_raw \"file.yl\"\n\
    \  sylic cir \"file.yl\"\n\
    \  sylic oir \"file.yl\"\n\n\
    \      sylic rir \"file.yl\"\n\
    \  sylic llvm \"file.yl\"\n\
    \  sylic exec \"file.yl\"\n\
    \  sylic build \"file.yl\" [output_exe]";
  exit 1

module P = Middle_end.Pipeline

let () =
  if Array.length Sys.argv < 3 then usage ()
  else
    let command = Sys.argv.(1) in
    let filename = Sys.argv.(2) in
    match command with
    | "lex" -> Lexing.run filename
    | "parse" -> Parsing.run filename
    | "typing" -> Typing.run filename
    | "alpha" -> Alpha.run filename
    | "core" -> P.run P.Core filename |> print_string
    | "cir_raw" -> P.run P.Cir_raw filename |> print_string
    | "cir_mono" -> P.run P.Cir_mono filename |> print_string
    | "cir" -> P.run P.Cir filename |> print_string
    | "oir" -> P.run P.Oir filename |> print_string
    | "rir" -> P.run P.Rir filename |> print_string
    | "llvm" -> P.run P.Llvm filename |> print_string
    | "exec" -> P.run P.Exec filename |> print_string
    | "build" ->
        let llvm_ir = P.run P.Exec filename in
        let base = Filename.chop_extension (Filename.basename filename) in
        let dir = Filename.dirname filename in
        let ll_file = Filename.concat dir (base ^ ".ll") in
        let exe_file =
          if Array.length Sys.argv > 3 then Sys.argv.(3) else base ^ ".exe"
        in
        let cc = Sys.getenv_opt "SYLI_CC" |> Option.value ~default:"clang" in
        let rt =
          Sys.getenv_opt "SYLI_RUNTIME_LIB"
          |> Option.value ~default:"runtime/cmake-build/Debug/libsyliruntime.a"
        in
        let oc = open_out ll_file in
        output_string oc llvm_ir;
        close_out oc;
        let exe =
          Sys.command
            (Printf.sprintf "%s -O3 -Wno-override-module -o %s %s %s -lm" cc
               exe_file ll_file rt)
        in
        if exe <> 0 then (
          Printf.eprintf "error: compilation failed (%s exit code %d)\n" cc exe;
          exit 1)
    | _ -> usage ()
