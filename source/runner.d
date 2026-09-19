/**
* MizuRunner: loads a program in Mizu's portable format and executes it.
*
* The D port of the C++ `runner.cpp`. Two things it did differently:
*
* $(UL
*   $(LI It began with `#undef NDEBUG`, so that Mizu's asserts survived a
*        release build. D spells that the other way around — asserts are
*        there unless `-release` asks for them to go — so `dub.json` simply
*        never passes `releaseMode`.)
*   $(LI `--generate-header` printed a C++ header. The D port of Mizu
*        generates D, so the flag is `--generate-source`; the old spelling
*        still works.))
*/
module runner;

import core.stdc.stdio : fprintf, fputs, stderr, stdout;

import fp.dynarray : dynarrayFree = free;
import fp.pointer : ptrLength = length;
import fp.string : stringFree = free;

import mizu;

import arguments;
import mapped_file;

@nogc nothrow:

version (Windows) {
	import core.sys.windows.wincon : SetConsoleOutputCP;
	import core.sys.windows.winnls : CP_UTF8;

	/**
	* Windows consoles default to a legacy code page, which turns any
	* non-ASCII output from a Mizu program into mojibake.
	*
	* The C++ runner did this in a `windows.cpp` that it `#include`d — and
	* which was never committed, so the Windows build has not compiled for
	* some time. It is two lines, so here they are.
	*/
	private void useUtf8Console() @trusted { SetConsoleOutputCP(CP_UTF8); }
} else
	private void useUtf8Console() {}

extern(C) int main(int argc, const(char*)* argv) @trusted {
	useUtf8Console();

	Arguments args;
	final switch (parseArguments(argc, argv, args)) {
		case Parse.run: break;
		case Parse.done: return 0;
		case Parse.failed: return 1;
	}

	auto file = mapFile(args.file);
	scope(exit) unmapFile(file);
	if (file.error !is null) {
		fprintf(stderr, "Failed to read `%s`: %s\n", args.file, file.error);
		return 1;
	}

	auto loaded = fromPortable(file.data);
	scope(exit) dynarrayFree(loaded.program);
	auto program = loaded.program[0 .. ptrLength(loaded.program)];
	// An empty or truncated file deserializes to no instructions at all, and
	// there is nothing to hand the first one's dispatch.
	if (program.length == 0) {
		fprintf(stderr, "`%s` holds no Mizu program.\n", args.file);
		return 1;
	}

	if (args.generateSource) {
		// The environment is printed as the program's starting memory, so
		// this happens before `setupEnvironment` touches it.
		auto source = generateSourceFile(program, loaded.environment);
		scope(exit) stringFree(source);
		fputs(source, stdout);
		return 0;
	}

	setupEnvironment(loaded.environment, program);
	startFromEnvironment(program, loaded.environment);
	return 0;
}
