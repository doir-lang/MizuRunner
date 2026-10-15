/**
* Checks a portable binary's program can run before the runner dispatches to it.
*/
module validation;

static import fp.pointer;
static import mizu.lookup;
static import mizu.serialize;

@nogc nothrow:

/**
* Finds the first instruction in a portable `binary` whose ID this build of Mizu does not know, as from a newer Mizu or a corrupted file; `fromPortable` loads one as a null `op`, and running it would jump to address zero.
*
* This reads the serialized opcodes rather than the loaded program because only they tell an unknown ID apart from the all-zero terminator, which `toPortable` omits when there is no stack data.
*
* Params:
*   binary = the bytes `mizu.portable_format.toPortable` wrote
* Returns: the index of the first unknown instruction, or `fp.pointer.notFound` if every one is known.
*
* Examples:
* ---
* static immutable Opcode[2] program = [Opcode(&loadImmediate, Registers.t(0)).setImmediate(1), Opcode(&halt)];
* ubyte* blob = toPortable(program[]);
* scope(exit) fp.dynarray.free(blob);
* assert(firstUnknownInstruction(blob[0 .. fp.pointer.length(blob)]) == fp.pointer.notFound);
*
* (cast(SerializationOpcode*) blob)[1].op = instructionCount;
* assert(firstUnknownInstruction(blob[0 .. fp.pointer.length(blob)]) == 1);
* ---
*/
size_t firstUnknownInstruction(const(void)[] binary) @trusted {
	auto opcodes = cast(const(mizu.serialize.SerializationOpcode)*) binary.ptr;
	foreach (i; 0 .. binary.length / mizu.serialize.SerializationOpcode.sizeof) {
		auto code = opcodes[i];
		version (BigEndian) mizu.serialize.byteswap(code);
		// The all-zero opcode ends the program, as in `fromPortable`; what follows is stack data.
		if (code == mizu.serialize.SerializationOpcode.init) break;
		if (mizu.lookup.lookupPointer(cast(mizu.lookup.Id) code.op) is null)
			return i;
	}
	return fp.pointer.notFound;
}
