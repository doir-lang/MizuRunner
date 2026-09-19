/**
* Writes `hello_world.mizu`: a program that reaches through Mizu's FFI to the
* host's libc and calls `printf`.
*
* The D port of the C++ `hello_world_dumper.cpp`. Where that built its string
* table at run time with `fp::builder::string`, this one is a compile-time
* concatenation and the offsets into it are `enum`s computed the same way, so
* the whole table lives in read-only data.
*
* Run with: `dub run -c example-hello-world --compiler=ldc2`
*/
module examples.hello_world_dumper;

import core.stdc.stdio : fclose, fopen, fprintf, fwrite, stderr;

import fp.dynarray : dynarrayFree = free;
import fp.pointer : ptrLength = length;

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

/**
* The strings the program needs, laid out as they will sit at the bottom of
* Mizu's stack. Each is null terminated, because everything reading them —
* the dynamic loader, `printf` — expects a C string.
*/
static immutable char[] stringTable =
	libcWindows ~ "\0" ~ libcLinux ~ "\0" ~ libcGeneric ~ "\0" ~ functionName ~ "\0" ~ message ~ "\0";

/*
* `pointerToStackBottom` counts *backwards* from the bottom of the stack, and
* the table is placed so that its last byte is the last byte of the stack, so
* a string's offset is how many bytes of the table start at it.
*/
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
	scope(exit) dynarrayFree(portable);

	auto file = fopen("hello_world.mizu", "wb");
	if (file is null) {
		fprintf(stderr, "Failed to open `hello_world.mizu` for writing.\n");
		return 1;
	}
	scope(exit) fclose(file);

	immutable size = ptrLength(portable);
	if (fwrite(portable, 1, size, file) != size) {
		fprintf(stderr, "Failed to write `hello_world.mizu`.\n");
		return 1;
	}

	return 0;
}
