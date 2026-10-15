/**
* The runner's command line, parsed by hand: it is two arguments long, and `-betterC` has nothing to build a declarative parser from.
*/
module arguments;

import core.stdc.stdio : FILE, fprintf, stderr, stdout;
import core.stdc.string : strcmp;

@nogc nothrow:

/// What the command line asked the runner to do.
struct Arguments {
	/// The file to run.
	const(char)* file;
	/// Print the program as D source instead of executing it; see `mizu.portable_format.generateSourceFile`.
	bool generateSource;
}

/// What `parseArguments` decided should happen next.
enum Parse {
	/// The arguments are good; run the program.
	run,
	/// Nothing left to do (`--help`); exit successfully.
	done,
	/// The command line was wrong; exit with a failure.
	failed,
}

private void printUsage(const(char)* program, FILE* output) @trusted {
	cast(void) fprintf(output,
		"Usage: %s [options] file\n"
		~ "\n"
		~ "    file                 The file to run.\n"
		~ "\n"
		~ "Options:\n"
		~ "    --generate-source    When set, instead of executing the program a D source file is\n"
		~ "                         printed to standard output instead.\n"
		~ "    -h, --help           Print this message and exit.\n",
		program);
}

/**
* Parses the runner's command line.
*
* `--generate-header`, the C++ runner's name for `--generate-source`, is accepted as an alias.
*
* Params:
*   argc = the argument count `main` received
*   argv = the arguments `main` received, starting with the program's name
*   args = filled in with what was asked for
* Returns: `Parse.run` to run the program; `Parse.done` after printing the usage for `--help`; `Parse.failed` after printing what was wrong, and the usage, to `stderr`, leaving `args` holding whatever was parsed before the mistake.
*
* Examples:
* ---
* static immutable(char)*[3] argv = ["mizu", "--generate-source", "hello.mizu"];
* Arguments args;
* assert(parseArguments(argv.length, argv.ptr, args) == Parse.run);
* assert(args.generateSource);
* assert(args.file is argv[2]);
* ---
*/
Parse parseArguments(int argc, const(char*)* argv, out Arguments args) @trusted {
	auto program = argc > 0 && argv[0] !is null ? argv[0] : "mizu";

	foreach (i; 1 .. argc) {
		auto argument = argv[i];

		if (strcmp(argument, "-h") == 0 || strcmp(argument, "--help") == 0) {
			printUsage(program, stdout);
			return Parse.done;
		}

		if (strcmp(argument, "--generate-source") == 0 || strcmp(argument, "--generate-header") == 0) {
			args.generateSource = true;
			continue;
		}

		if (argument[0] == '-' && argument[1] != '\0') {
			cast(void) fprintf(stderr, "Unrecognized option: %s\n", argument);
			printUsage(program, stderr);
			return Parse.failed;
		}

		if (args.file !is null) {
			cast(void) fprintf(stderr, "Only one file can be run at a time, but both `%s` and `%s` were given.\n", args.file, argument);
			printUsage(program, stderr);
			return Parse.failed;
		}
		args.file = argument;
	}

	if (args.file is null) {
		cast(void) fprintf(stderr, "No file to run was given.\n");
		printUsage(program, stderr);
		return Parse.failed;
	}

	return Parse.run;
}
