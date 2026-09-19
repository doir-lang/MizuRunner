/**
* The runner's command line.
*
* The C++ version described its arguments declaratively with
* [argparse](https://github.com/morrisfranken/argparse), which builds its
* help text out of `std::string`s and its parser out of templates over
* `std::optional` — none of which exists under `-betterC`. The command line
* is two arguments long, so it is spelled out by hand instead.
*/
module arguments;

import core.stdc.stdio : FILE, fprintf, stderr, stdout;
import core.stdc.string : strcmp;

@nogc nothrow:

/// What the command line asked the runner to do.
struct Arguments {
	/// The file to run.
	const(char)* file;
	/**
	* Print the program as D source instead of executing it.
	* See_Also: `mizu.portable_format.generateSourceFile`
	*/
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

/**
* Parses the runner's command line.
*
* Params:
*   argc = ditto `main`
*   argv = ditto `main`
*   args = filled in with what was asked for
* Returns:
*   Whether to run the program, exit quietly, or exit with a failure.
*/
Parse parseArguments(int argc, const(char*)* argv, out Arguments args) @trusted {
	auto program = argc > 0 && argv[0] !is null ? argv[0] : "mizu";

	foreach (i; 1 .. argc) {
		auto argument = argv[i];

		if (strcmp(argument, "-h") == 0 || strcmp(argument, "--help") == 0) {
			printUsage(program, stdout);
			return Parse.done;
		}

		// `--generate-header` is what the C++ runner called this, back when
		// the generated file was a C++ header; it is kept as an alias.
		if (strcmp(argument, "--generate-source") == 0 || strcmp(argument, "--generate-header") == 0) {
			args.generateSource = true;
			continue;
		}

		if (argument[0] == '-' && argument[1] != '\0') {
			fprintf(stderr, "Unrecognized option: %s\n", argument);
			printUsage(program, stderr);
			return Parse.failed;
		}

		if (args.file !is null) {
			fprintf(stderr, "Only one file can be run at a time, but both `%s` and `%s` were given.\n",
				args.file, argument);
			printUsage(program, stderr);
			return Parse.failed;
		}
		args.file = argument;
	}

	if (args.file is null) {
		fprintf(stderr, "No file to run was given.\n");
		printUsage(program, stderr);
		return Parse.failed;
	}

	return Parse.run;
}

/// Prints how to invoke the runner to `output`.
private void printUsage(const(char)* program, FILE* output) @trusted {
	fprintf(output,
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
