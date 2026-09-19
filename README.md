![Mizu's Mascot](https://github.com/doir-lang/Mizu/blob/D/docs/mizu.svg)

# MizuRunner

[![Unlicensed](https://flat.badgen.net/github/license/doir-lang/mizurunner)](LICENSE) [![Latest Release](https://flat.badgen.net/github/release/doir-lang/mizurunner)](https://github.com/doir-lang/mizurunner/releases)

A simple executable wrapper around the [Mizu](https://github.com/doir-lang/Mizu) assembly
interpreter library. It takes as input a binary in Mizu's
[portable format](https://github.com/doir-lang/Mizu/blob/D/source/mizu/portable_format.d) and
executes it.

This is the D `-betterC` runner, built on the D port of Mizu; see
[Notes on the port](#notes-on-the-port) for where it differs from the C++ one.

```bash
# On linux this looks like:
mizu hello.mizu

# Or like this to see a printed trace of the instructions as they are executed
mizu-trace hello.mizu

# A binary's "source code" can be examined by running
mizu hello.mizu --generate-source
```

## Features

- Lightweight runtime — 206kB on Linux x86_64, 175kB stripped
- No runtime at all, in the D sense: `-betterC` throughout, no GC, no druntime
- Cross platform (Windows, Linux, and Mac support)
- Foreign function interface to native DLLs (example:
  [examples/hello_world_dumper.d](examples/hello_world_dumper.d))

## Building

[LDC](https://github.com/ldc-developers/ldc) is required — Mizu's dispatch depends on tail call
optimization, which DMD does not perform — as is an optimizing build, which is why the `debug`
build type here asks for `optimize` too. Mizu also needs **libffi** unless it is built with
`-version=MizuNoFFI`; Linux and macOS package one, and on Windows `tools/vcpkg-libffi.ps1`
builds one and stages it where the linker will look.

```bash
dub build -c mizu --build=release --compiler=ldc2        # bin/mizu
dub build -c mizu-trace --build=release --compiler=ldc2  # bin/mizu-trace
```

The two configurations differ only in that `mizu-trace` sets `MizuEnableTracing`, which makes
every instruction print itself as it runs. That is a compile-time switch inside Mizu, so the
library is rebuilt for it and the two binaries cannot be one binary with a flag.

Neither build type passes `releaseMode`, so Mizu's asserts survive a release build. The C++
runner did the same thing by starting `runner.cpp` with `#undef NDEBUG`.

## Creating Mizu binaries

Mizu still has no assembler, so a binary is made by writing a small D program with the Mizu
program embedded in it, then calling `toPortable` and writing the result out:

```d
auto portable = toPortable(program[], stackData);
scope(exit) free(portable); // fp.dynarray.free

auto file = fopen("program.mizu", "wb");
fwrite(portable, 1, length(portable), file); // fp.pointer.length
fclose(file);
```

Two full dumpers live in [examples/](examples/), and double as this repository's tests:

```bash
dub run -c example-bubble-sort --compiler=ldc2   # writes bubble.mizu
dub run -c example-hello-world --compiler=ldc2   # writes hello_world.mizu

./bin/mizu bubble.mizu        # prints nothing: the numbers came back sorted
./bin/mizu hello_world.mizu   # prints "Hello 世界" through libc's printf
```

## Licence

The code in this repository is [unlicensed](LICENSE), feel free to do whatever you want with it.
[Mizu](https://github.com/doir-lang/Mizu) itself is MIT licensed.
