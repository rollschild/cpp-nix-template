cmake_minimum_required(VERSION 3.28...4.4)

# This is the only source of the name, VERSION and DESCRIPTION.
# nix/project.nix reads them for the Nix package and the flake.
project(
    myproject
    VERSION 0.1.0
    DESCRIPTION "C++23 project template with CMake presets and a Nix flake"
    HOMEPAGE_URL "https://github.com/rollschild/myproject"
    LANGUAGES CXX
)

if(PROJECT_SOURCE_DIR STREQUAL PROJECT_BINARY_DIR)
    message(
        FATAL_ERROR
        "Do not build in the source directory. Use a preset: cmake --preset dev"
    )
endif()

# -std=c++23, not -std=gnu++23.
set(CMAKE_CXX_EXTENSIONS OFF)
# This project does not use C++20 modules. With Ninja and GCC 14 or later, CMake
# does a module scan by default. The scan adds GCC flags to
# compile_commands.json that clangd and clang-tidy show as errors.
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

include(cmake/CompilerWarnings.cmake) # myproject_enable_warnings()

add_subdirectory(src)

if(PROJECT_IS_TOP_LEVEL)
    add_subdirectory(apps)

    include(CTest) # sets BUILD_TESTING (default ON) and calls enable_testing()
    if(BUILD_TESTING)
        add_subdirectory(tests)
    endif()
endif()

if(NOT CMAKE_SKIP_INSTALL_RULES)
    include(cmake/InstallRules.cmake)
endif()
