# M/o/Vfuscator — Claude Context

## What this project is

The M/o/Vfuscator compiles C programs into x86 binaries that use only `mov` instructions. It is based on the **lcc** C frontend (fetched from GitHub at build time) with a custom `mov` backend.

## How to build

```sh
bash build.sh
```

The script:
1. Clones `https://github.com/drh/lcc` and hard-resets it to a known commit.
2. Applies all patches in `movfuscator/` to lcc source files.
3. Builds the lcc compiler driver (`build/lcc`, symlinked as `build/movcc`).
4. Builds the mov backend (`build/rcc`).
5. Compiles the CRT libraries (`build/crt0.o`, `crtf.o`, `crtd.o` and `_cf` variants).
6. Builds softfloat libraries into `movfuscator/lib/`.

## How to verify the build

```sh
bash check.sh
```

Clones a tiny AES implementation, M/o/Vfuscates it, objdumps it, and runs it.

## Patch files

All patches live in `movfuscator/` and are applied by `build.sh` to the freshly-reset lcc tree. **Any fix to lcc source must go into a patch file**, not directly into `lcc/` (which is wiped on every build).

| Patch file | Target | Purpose |
|---|---|---|
| `bind.patch` | `lcc/src/bind.c` | Bind movfuscator backend to lcc |
| `makefile.patch` | `lcc/makefile` | Add mov backend to lcc build |
| `enode.patch` | `lcc/src/enode.c` | Silence pointer/const errors (modern GCC) |
| `gen.patch` | `lcc/src/gen.c` | Fix register allocation bug |
| `expr.patch` | `lcc/src/expr.c` | Fix unary minus promotion bug |
| `lcc.patch` | `lcc/etc/lcc.c` | Fix implicit return type, `execv` signature, `strchr` cast; add `--no-mov-flow` flag forwarding to linker |
| `constexpr.patch` | `lcc/src/c.h`, `simp.c`, `stmt.c` | Rename `constexpr` (reserved keyword in C23) |
| `gram.patch` | `lcc/lburg/gram.c` | Add unconditional `#include <stdlib.h>` — the yacc-generated parser only included it under `#ifdef __cplusplus`, causing errors with modern GCC |

## host.c

`movfuscator/host.c` is the lcc host configuration: it defines the preprocessor, assembler, and linker command lines used by `movcc`.

Key points:
- Targets **32-bit x86** (`--32` for `as`, `-m elf_i386` for `ld`).
- Linker searches `build/gcc/32` (GCC multilib) **and `/usr/lib32`** for 32-bit libc/libm. On Arch Linux (and similar), 32-bit system libraries live in `/usr/lib32/`, not in the GCC multilib path.
- Requires `lib32-glibc` (Arch) or equivalent to be installed.

## Known non-fatal build warnings

- `softfloat` produces many overflow and type warnings — these are expected and safe to ignore.
- Building `timesoftfloat` (a softfloat test binary) fails if 32-bit libc is missing; this does not affect the movfuscator libraries.

## Generated / ignored paths

- `build/` — all compiled output
- `lcc/` — cloned and patched at build time
- `movfuscator/lib/` — compiled softfloat libraries
- `validation/aes/` — cloned by `check.sh` for validation
