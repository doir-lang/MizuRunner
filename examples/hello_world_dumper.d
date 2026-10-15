/**
* Writes `hello_world.mizu`: a program that reaches through Mizu's FFI to the host's libc and calls `printf`.
*
* The string table is a compile-time concatenation, and the offsets into it are `enum`s computed the same way, so the whole table lives in read-only data.
*
* Run with: `dub run -c example-hello-world --compiler=ldc2`
*/
module examples.hello_world_dumper;

import core.stdc.stdio : fclose, fopen, fprintf, fwrite, stderr;

static import fp.dynarray;
static import fp.pointer;

import mizu;
import mizu.ffi;

/// The libraries to try, in order, when looking for `printf`.
enum string libcWindows = "msvcrt";
/// Ditto
enum string libcLinux = "libc.so.6";
/// Ditto, which the loader turns into `libc.dylib`, `libc.so` and friends.
enum string libcGeneric = "libc";

/// The function to call, and what to call it with.
enum string functionName = "printf";
/// Ditto
enum string message = "Hello 世界\n";

/// The strings the program needs, laid out as they will sit at the bottom of Mizu's stack; each is null-terminated, because the dynamic loader and `printf` expect C strings.
static immutable char[] stringTable = libcWindows ~ "\0" ~ libcLinux ~ "\0" ~ libcGeneric ~ "\0" ~ functionName ~ "\0" ~ message ~ "\0";

/// Where each string sits for `pointerToStackBottom`, which counts backwards from the bottom of the stack; the table ends at the stack's last byte, so an offset is how many table bytes start at that string.
enum size_t windowsOffset = stringTable.length;
/// Ditto
enum size_t linuxOffset = windowsOffset - (libcWindows.length + 1);
/// Ditto
enum size_t genericOffset = linuxOffset - (libcLinux.length + 1);
/// Ditto
enum size_t functionOffset = genericOffset - (libcGeneric.length + 1);
/// Ditto
enum size_t messageOffset = functionOffset - (functionName.length + 1);

static immutable Opcode[19] program = [
	// Reserve the string table, so that nothing the program pushes lands on it.
	Opcode(&stackPushImmediate).setImmediate(stringTable.length),

	// t0 = the first of the libcs that this host actually has
	Opcode(&loadImmediate, Registers.t(0)).setImmediate(windowsOffset),
	Opcode(&pointerToStackBottom, Registers.a(0), Registers.t(0)),
	Opcode(&loadImmediate, Registers.t(0)).setImmediate(linuxOffset),
	Opcode(&pointerToStackBottom, Registers.a(1), Registers.t(0)),
	Opcode(&loadImmediate, Registers.t(0)).setImmediate(genericOffset),
	Opcode(&pointerToStackBottom, Registers.a(2), Registers.t(0)),
	Opcode(&loadFirstLibraryThatExists, Registers.t(0)).setImmediate(3),
	// t1 = printf
	Opcode(&loadImmediate, Registers.t(1)).setImmediate(functionOffset),
	Opcode(&pointerToStackBottom, Registers.t(1), Registers.t(1)),
	Opcode(&loadLibraryFunction, Registers.t(1), Registers.t(0), Registers.t(1)),
	// t2 = uint(*)(void*)
	Opcode(&pushTypeU32),
	Opcode(&pushTypePointer),
	Opcode(&createInterface, Registers.t(2)),

	// a0 = message
	Opcode(&loadImmediate, Registers.a(0)).setImmediate(messageOffset),
	Opcode(&pointerToStackBottom, Registers.a(0), Registers.a(0)),

	// t3 = printf(message), which returns how many characters it printed
	Opcode(&callWithReturn, Registers.t(3), Registers.t(1), Registers.t(2)),
	Opcode(&debugPrint, 0, Registers.t(3)),
	Opcode(&halt),
];

extern(C) int main() @nogc nothrow {
	auto portable = toPortable(program[], stringTable[]);
	scope(exit) fp.dynarray.free(portable);
	if (portable is null) {
		cast(void) fprintf(stderr, "Ran out of memory serializing the program.\n");
		return 1;
	}

	auto file = fopen("hello_world.mizu", "wb");
	if (file is null) {
		cast(void) fprintf(stderr, "Failed to open `hello_world.mizu` for writing.\n");
		return 1;
	}

	immutable size = fp.pointer.length(portable);
	immutable written = fwrite(portable, 1, size, file);
	// `fclose` flushes, so a write can fail there as well as in `fwrite`.
	if ((fclose(file) != 0) | (written != size)) {
		cast(void) fprintf(stderr, "Failed to write `hello_world.mizu`.\n");
		return 1;
	}

	return 0;
}
