/**
* MizuRunner: loads a program in Mizu's portable format and executes it, or prints it as D source.
*
* Mizu's asserts survive a release build because `dub.json` never passes `releaseMode`.
*/
module runner;

import core.stdc.stdio : EOF, fprintf, fputs, stderr, stdout;

static import fp.dynarray;
static import fp.pointer;
static import fp.string;
static import mizu.opcode;
static import mizu.portable_format;

static import arguments;
static import mapped_file;
static import validation;

@nogc nothrow:

version (Windows) {
	import core.sys.windows.wincon : SetConsoleOutputCP;
	import core.sys.windows.winnls : CP_UTF8;

	// Windows consoles default to a legacy code page, which garbles a Mizu program's non-ASCII output.
	private void useUtf8Console() @trusted { cast(void) SetConsoleOutputCP(CP_UTF8); }
} else
	private void useUtf8Console() {}

extern(C) int main(int argc, const(char*)* argv) @trusted {
	useUtf8Console();

	arguments.Arguments args;
	final switch (arguments.parseArguments(argc, argv, args)) {
		case arguments.Parse.run: break;
		case arguments.Parse.done: return 0;
		case arguments.Parse.failed: return 1;
	}

	auto file = mapped_file.mapFile(args.file);
	scope(exit) mapped_file.unmapFile(file);
	if (file.error !is null) {
		cast(void) fprintf(stderr, "Failed to read `%s`: %s\n", args.file, file.error);
		return 1;
	}

	auto loaded = mizu.portable_format.fromPortable(file.data);
	scope(exit) fp.dynarray.free(loaded.program);
	auto program = loaded.program[0 .. fp.pointer.length(loaded.program)];
	// Covers allocation failure too, since `fromPortable` then returns a null program.
	if (program.length == 0) {
		cast(void) fprintf(stderr, "`%s` holds no Mizu program.\n", args.file);
		return 1;
	}

	immutable unknown = validation.firstUnknownInstruction(file.data);
	if (unknown != fp.pointer.notFound) {
		cast(void) fprintf(stderr, "`%s` uses an instruction this build of Mizu does not know, at index %zu.\n", args.file, unknown);
		return 1;
	}

	if (args.generateSource) {
		// The environment is printed as the program's starting memory, so this happens before `setupEnvironment` touches it.
		auto source = mizu.portable_format.generateSourceFile(program, loaded.environment);
		scope(exit) fp.string.free(source);
		if (source is null) {
			cast(void) fprintf(stderr, "Ran out of memory generating source for `%s`.\n", args.file);
			return 1;
		}
		return fputs(source, stdout) == EOF ? 1 : 0;
	}

	mizu.opcode.setupEnvironment(loaded.environment, program);
	// What the final instruction returned; `halt` returns null, and the runner has no use for anything else.
	cast(void) mizu.opcode.startFromEnvironment(program, loaded.environment);
	return 0;
}
