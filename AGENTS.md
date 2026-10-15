# Agent guidelines for MizuRunner

These follow [Mizu's own guidelines](Mizu/AGENTS.md), trimmed to what applies to a program built on Mizu rather than to Mizu itself.

## Comments

- Keep comments minimal.
  Write one only where the code does something difficult to follow on its own: a non-obvious invariant, a subtle memory or lifetime rule, a workaround for a compiler bug, or why an apparently simpler approach would be wrong.
  Do not restate what the code already says.
- Cap every free-standing comment (a `//` or `/* */` block that is not a documentation comment) at 25 words.
  If it needs more, the code or its documentation should carry the explanation instead.
- Editors here soft-wrap, so write each comment, and each paragraph of a DDoc comment, on a single line rather than hard-wrapping it at a column.
- Do not leave commented-out code, change logs, or notes about what was changed in a comment; those belong in commit messages.
  How the runner differs from the C++ one belongs in the README's "Notes on the port".

## Documentation

- Put a DDoc comment (`///` or `/** */`) directly above every publicly accessible definition in `source/`: each public or package-visible function, struct, enum, alias, template, and module-level variable.
  Private helpers, and `main`, do not need one.
- Every DDoc comment on a function or template includes an example of its use in an `Examples:` section, as a `---` code block:

  ```d
  /**
  * Parses the runner's command line.
  *
  * Examples:
  * ---
  * static immutable(char)*[2] argv = ["mizu", "hello.mizu"];
  * Arguments args;
  * assert(parseArguments(argv.length, argv.ptr, args) == Parse.run);
  * ---
  */
  Parse parseArguments(int argc, const(char*)* argv, out Arguments args) { ... }
  ```

- Keep examples short, and make them correct against the current API: they should compile and pass as written under `-betterC`.
  Check them with `python3 tools/doctest.py`, which compiles and runs every example and reports public definitions missing documentation or an example.
  Examples see `import mizu;` and their own module unqualified, as user code would; anything else needs its full name.
  Module documentation may sketch usage in a `---` block; doctest does not compile those.
- When a platform `static if` or `version` gives an API several implementations, document the first branch's definitions; an `else` branch reimplementing the same API needs only `/// Ditto`.
- A DDoc comment is documentation, not a free-standing comment, so the 25-word cap does not apply to it, but keep it as brief as the definition allows.
- The programs in `examples/` are user code, as Mizu's own examples are: they `import mizu;` unqualified, and `main` and the program arrays need no DDoc.

## Style

- Prefer plain-data structs operated on by free functions that take them by `ref` (for example `mapped_file.unmapFile(file)`), rather than methods.
- Prefer fully qualified names to aliasing imports: call `fp.dynarray.free(a)` rather than `import fp.dynarray : dynarrayFree = free;`.
- A module in `source/` uses another, or Mizu, or libfp, through a `static import`, so every call names its layer (`mapped_file.mapFile`, `mizu.opcode.setupEnvironment`, `fp.dynarray.free`).
  Selective imports from `core.*` are fine.
- Name everything in camelCase.
  Add a trailing underscore only when the plain name is a D keyword (`out_`, `in_`, `with_`).
- Indent with tabs.
- Under a `@nogc nothrow:` label, do not repeat those attributes on the declarations it already covers.

## Failure and invariants

- Every function that can fail says in its DDoc how it reports failure, and what state it leaves its arguments in.
- Never drop the result of a call that can fail: check it, or discard it explicitly with `cast(void)` when failure is impossible or harmless there, as for diagnostics printed on the way to exiting.
  Writing a file counts as failing if `fclose` fails, since that is where buffered output is flushed.
- Mizu's functions report allocation failure by returning null; check for it before using what they return.
- Put test-only code inside `version(unittest)`.

## Organization

- Group related definitions into sections, separated by blank lines, and order them so a reader meets a type before the functions built on it.
- Whenever possible, define a function before anything that uses it, so a module reads bottom-up from its building blocks.

## Bugs

- If you find a bug while working, fix it, with a test that would have caught it, rather than only reporting it.
  Only when the fix would likely take a long time, report it instead, saying what you found and where.
