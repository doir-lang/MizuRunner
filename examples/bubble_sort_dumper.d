/**
* Writes `bubble.mizu`: a program that bubble sorts 100 numbers sitting on
* its stack and then checks the result against a sorted copy of them.
*
* Nothing is printed when the check passes; a mismatch prints the index it
* happened at.
*
* The D port of the C++ `bubble_sort_dumper.cpp`, with two fixes the C++
* program needed. See the comments on the inner loop's bound and on the
* check loop's branch.
*
* Run with: `dub run -c example-bubble-sort --compiler=ldc2`
*/
module examples.bubble_sort_dumper;

import core.stdc.stdio : fclose, fopen, fprintf, fwrite, stderr;

import fp.dynarray : dynarrayFree = free;
import fp.pointer : ptrLength = length;

import mizu;

/// The numbers to sort.
static immutable ulong[100] numbers = [
	179, 1630, 754, 259, 858, 970, 310, 1612, 1269, 1000, 397, 783, 814, 1812, 1778, 641, 1925, 382, 82, 1147,
	152, 399, 1061, 1364, 1323, 1753, 96, 980, 1849, 1155, 1355, 1558, 168, 982, 1659, 598, 8, 1547, 52, 1164,
	1555, 445, 1069, 1921, 627, 1337, 845, 193, 1829, 1572, 1681, 1885, 197, 894, 1940, 1081, 1839, 313, 26, 116,
	692, 1105, 489, 1293, 502, 1019, 567, 496, 787, 1757, 1333, 1863, 1291, 1975, 744, 457, 1113, 1974, 246, 164,
	1441, 854, 1710, 583, 648, 484, 1279, 1890, 1588, 1073, 1944, 1231, 656, 566, 1676, 301, 1931, 667, 1167, 707
];

/// What they should look like afterwards.
static immutable ulong[100] sorted = [
	8, 26, 52, 82, 96, 116, 152, 164, 168, 179, 193, 197, 246, 259, 301, 310, 313, 382, 397, 399, 445, 457, 484, 489,
	496, 502, 566, 567, 583, 598, 627, 641, 648, 656, 667, 692, 707, 744, 754, 783, 787, 814, 845, 854, 858, 894, 970,
	980, 982, 1000, 1019, 1061, 1069, 1073, 1081, 1105, 1113, 1147, 1155, 1164, 1167, 1231, 1269, 1279, 1291, 1293,
	1323, 1333, 1337, 1355, 1364, 1441, 1547, 1555, 1558, 1572, 1588, 1612, 1630, 1659, 1676, 1681, 1710, 1753, 1757,
	1778, 1812, 1829, 1839, 1849, 1863, 1885, 1890, 1921, 1925, 1931, 1940, 1944, 1974, 1975
];

/**
* Both arrays, laid out as they will sit at the bottom of Mizu's stack:
* `sorted` first, so that `numbers` — the copy the program sorts in place —
* ends up directly under the stack pointer after the first `stackPush`.
*/
static immutable ulong[200] stackData = sorted ~ numbers;

/// Registers this program keeps constants in, beyond the named ones.
enum Reg bubbleLabel = 200;
/// Ditto
enum Reg innerLabel = 201;
/// Ditto
enum Reg checkLabel = 202;
/// Ditto
enum Reg checkTopLabel = 203;
/// Ditto
enum Reg elementSize = 204;
/// Ditto
enum Reg lastIndex = 205;
/// Ditto
enum Reg one = 206;

static immutable Opcode[50] program = [
	Opcode(&findLabel, bubbleLabel).setImmediate(label2immediate("bub")),    // outer loop
	Opcode(&findLabel, innerLabel).setImmediate(label2immediate("innr")),    // inner loop
	Opcode(&findLabel, checkLabel).setImmediate(label2immediate("chck")),    // the check
	Opcode(&findLabel, checkTopLabel).setImmediate(label2immediate("ctop")), // check loop
	Opcode(&loadImmediate, elementSize).setImmediate(ulong.sizeof),
	Opcode(&loadImmediate, one).setImmediate(1),

	// a0 (size) = numbers.length, and the last index the inner loop may touch
	Opcode(&loadImmediate, Registers.a(0)).setImmediate(numbers.length),
	Opcode(&subtract, lastIndex, Registers.a(0), one),
	// Reserve size * 8 bytes of stack, which puts the stack pointer at the
	// copy of `numbers` the stack data ends with.
	Opcode(&multiply, Registers.t(0), elementSize, Registers.a(0)),
	Opcode(&stackPush, 0, Registers.t(0)),
	// a1 (changed) = true
	Opcode(&loadImmediate, Registers.a(1)).setImmediate(1),

	Opcode(&label).setImmediate(label2immediate("bub")),
		// if (!changed) goto the check
		Opcode(&setIfEqual, Registers.t(0), Registers.a(1), 0),
		Opcode(&branchTo, 0, Registers.t(0), checkLabel),
		Opcode(&loadImmediate, Registers.a(1)).setImmediate(0), // changed = false
		Opcode(&loadImmediate, Registers.a(2)).setImmediate(0), // i = 0

		Opcode(&label).setImmediate(label2immediate("innr")),
			// The C++ compared against the size rather than the last index,
			// so the final iteration read (and could write) one element past
			// the end of the array — which, the array being at the very
			// bottom of the stack, is past the end of Mizu's memory too.
			Opcode(&setIfGreaterEqual, Registers.t(0), Registers.a(2), lastIndex),
			Opcode(&branchTo, 0, Registers.t(0), bubbleLabel),
			// t0 = i, then i += 1, so t0 is "i - 1" from here on
			Opcode(&add, Registers.t(0), Registers.a(2), 0),
			Opcode(&add, Registers.a(2), Registers.a(2), one),
			// t0 = stack[i - 1] at offset t2, t1 = stack[i] at offset t3
			Opcode(&multiply, Registers.t(2), Registers.t(0), elementSize),
			Opcode(&stackLoadU64, Registers.t(0), Registers.t(2)),
			Opcode(&multiply, Registers.t(3), Registers.a(2), elementSize),
			Opcode(&stackLoadU64, Registers.t(1), Registers.t(3)),
			// if (stack[i] >= stack[i - 1]) continue
			Opcode(&setIfGreaterEqual, Registers.t(4), Registers.t(1), Registers.t(0)),
			Opcode(&branchTo, 0, Registers.t(4), innerLabel),
			// swap them and note that something changed
			Opcode(&stackStoreU64, 0, Registers.t(1), Registers.t(2)),
			Opcode(&stackStoreU64, 0, Registers.t(0), Registers.t(3)),
			Opcode(&loadImmediate, Registers.a(1)).setImmediate(1),
			Opcode(&jumpTo, 0, innerLabel),

	Opcode(&label).setImmediate(label2immediate("chck")),
	// Reserve another size * 8 bytes, putting the stack pointer at `sorted`
	// with the freshly sorted `numbers` directly above it.
	Opcode(&multiply, Registers.t(0), elementSize, Registers.a(0)),
	Opcode(&stackPush, 0, Registers.t(0)),
	Opcode(&loadImmediate, Registers.a(1)).setImmediate(0), // i = 0

	Opcode(&label).setImmediate(label2immediate("ctop")),
		// if (i >= size) halt, everything matched
		Opcode(&setIfLess, Registers.t(0), Registers.a(1), Registers.a(0)),
		// The C++ left this branch's condition register at zero — which is
		// the register that is always zero — so it never branched and the
		// check halted before comparing anything.
		Opcode(&branchRelativeImmediate, 0, Registers.t(0)).setBranchImmediate(2),
		Opcode(&halt),
		// t0 = sorted[i] at offset t1
		Opcode(&multiply, Registers.t(1), Registers.a(1), elementSize),
		Opcode(&stackLoadU64, Registers.t(0), Registers.t(1)),
		// t1 = the sorted numbers[i], size * 8 bytes further up the stack
		Opcode(&multiply, Registers.t(2), Registers.a(0), elementSize),
		Opcode(&add, Registers.t(1), Registers.t(1), Registers.t(2)),
		Opcode(&stackLoadU64, Registers.t(1), Registers.t(1)),
		Opcode(&add, Registers.a(1), Registers.a(1), one),
		// if (sorted[i] == numbers[i]) continue
		Opcode(&setIfEqual, Registers.t(0), Registers.t(0), Registers.t(1)),
		Opcode(&branchTo, 0, Registers.t(0), checkTopLabel),
		// otherwise print the index they differ at
		Opcode(&subtract, Registers.t(0), Registers.a(1), one),
		Opcode(&debugPrint, 0, Registers.t(0)),
		Opcode(&halt),
];

extern(C) int main() @nogc nothrow {
	auto portable = toPortable(program[], cast(const(void)[]) stackData[]);
	scope(exit) dynarrayFree(portable);

	auto file = fopen("bubble.mizu", "wb");
	if (file is null) {
		fprintf(stderr, "Failed to open `bubble.mizu` for writing.\n");
		return 1;
	}
	scope(exit) fclose(file);

	immutable size = ptrLength(portable);
	if (fwrite(portable, 1, size, file) != size) {
		fprintf(stderr, "Failed to write `bubble.mizu`.\n");
		return 1;
	}

	return 0;
}
