/* ELF-only: used with `-Wl,-T` on Linux (x86_64 and aarch64). Mach-O (macOS)
 * has no GNU-ld-style linker scripts.
 *
 * Place the .llvm_stackmaps section and define the bounds symbols that the
 * runtime parses between. */
SECTIONS
{
  .llvm_stackmaps : {
    __start_llvm_stackmaps = .;
    KEEP(*(.llvm_stackmaps))
    __stop_llvm_stackmaps = .;
  }
} INSERT AFTER .rodata;
