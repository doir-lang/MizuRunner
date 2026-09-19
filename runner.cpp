#undef NDEBUG // Make sure all of the asserts still get built (even in release!)
#include <iostream>

#include "argparse/argparse.hpp"
#include "mio.hpp"

#define MIZU_IMPLEMENTATION
#include <mizu/portable_format.hpp>
#include <mizu/instructions.hpp>
#include <ffi/instructions.hpp>

struct Arguments : public argparse::Args {
	std::string& file = arg("The file to run.");
	bool& generate_header = flag("generate-header", "When set, instead of executing the program a C++ header file is printed to standard output instead");
};

// On windows we need to set the console to UTF8
#ifdef _WIN32
#include "windows.cpp"
int dll_main(int argc, char** argv)
#else
int main(int argc, char** argv)
#endif 
{
	auto args = argparse::parse<Arguments>(argc, argv);

	mio::mmap_source data(args.file);
	fp::view<const std::byte> binary{(std::byte*)data.data(), data.size()};
	auto [program, env] = mizu::portable::from_portable(binary);

	if(args.generate_header) {
		std::cout << mizu::portable::generate_header_file(program.view_full(), env).data() << std::endl;
		return 0;
	}

	mizu::setup_environment(env, program.data(), program.data() + program.size());
	MIZU_START_FROM_ENVIRONMENT(program.data(), env);
	return 0;
}