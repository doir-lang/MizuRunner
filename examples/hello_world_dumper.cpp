#define MIZU_IMPLEMENTATION
#include <mizu/portable_format.hpp>
#include <mizu/instructions.hpp>
#include <ffi/instructions.hpp>

#include <fstream>

fp::string message = "Hello 世界\n"_fp;
fp::string libc_windows = "msvcrt"_fp;
fp::string libc_linux = "libc.so.6"_fp;
auto libc = fp::builder::string{} << libc_windows << '\0' << libc_linux << '\0' << "libc";
auto strings = fp::builder::string{} << libc << '\0' << "printf" << '\0' << message << '\0';

MIZU_MAIN() {
	using namespace mizu;

	const static opcode program[] = {
		opcode{stack_push_immediate}.set_immediate(strings.size()),

		// t0 = libc
		opcode{load_immediate, t(0)}.set_immediate(strings.size()),
		opcode{unsafe::pointer_to_stack_bottom, a(0), t(0)},
		opcode{load_immediate, t(0)}.set_immediate(strings.size() - libc_windows.size() - 1),
		opcode{unsafe::pointer_to_stack_bottom, a(1), t(0)},
		opcode{load_immediate, t(0)}.set_immediate(strings.size() - libc_windows.size() - libc_linux.size() - 2),
		opcode{unsafe::pointer_to_stack_bottom, a(2), t(0)},
		opcode{ffi::load_first_library_that_exists, t(0)}.set_immediate(3),
		// t1 = printf
		opcode{load_immediate, t(1)}.set_immediate(strings.size() - libc.size() - 1),
		opcode{unsafe::pointer_to_stack_bottom, t(1), t(1)},
		opcode{ffi::load_library_function, t(1), t(0), t(1)},
		// t2 = uint32_t(*)(void*)
		opcode{ffi::push_type_u32},
		opcode{ffi::push_type_pointer},
		opcode{ffi::create_interface, t(2)},

		// a0 = message
		opcode{load_immediate, a(0)}.set_immediate(message.size() + 1),
		opcode{unsafe::pointer_to_stack_bottom, a(0), a(0)},

		// t3 = printf(message)
		opcode{ffi::call_with_return, t(3), t(1), t(2)},
		opcode{debug_print, 0, t(3)},
		opcode{halt}
	};

	// auto c = loader::load_library("libc.so.6");
	// auto printf = (uint32_t(*)(const char*))loader::lookup("printf", c);
	// printf(message.c_str());

	fp::raii::dynarray<std::byte> portable = mizu::portable::to_portable(fp::view<const opcode>{program, sizeof(program)/sizeof(program[0])}, strings.full_view().byte_view());

	std::ofstream fout("hello_world.mizu", std::ios::binary | std::ios::out);
	fout.write((char*)portable.data(), portable.size());

	return 0;
}