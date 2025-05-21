cmake_minimum_required(VERSION 3.21)
set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "" FORCE)
project(MizuRunner CXX)

set(CMAKE_CXX_STANDARD 23)

option(GENERATE_EXAMPLES "Should we generate the example programs?" ${PROJECT_IS_TOP_LEVEL})

add_subdirectory(argparse)
add_subdirectory(mizuvm)

add_executable(${PROJECT_NAME} runner.cpp)
set_target_properties(${PROJECT_NAME} PROPERTIES OUTPUT_NAME "mizu")
target_link_libraries(${PROJECT_NAME} PUBLIC mizu::vm argparse)

add_executable(mizu-trace runner.cpp)
target_link_libraries(mizu-trace PUBLIC mizu::vm argparse)
target_compile_definitions(mizu-trace PUBLIC MIZU_ENABLE_TRACING)

if(GENERATE_EXAMPLES)
    add_dynamic_executable(bubble_sort examples/bubble_sort_dumper.cpp)
    target_link_libraries(bubble_sort PUBLIC mizu::vm)

    add_dynamic_executable(hello_world examples/hello_world_dumper.cpp)
    target_link_libraries(hello_world PUBLIC mizu::vm)
endif()

