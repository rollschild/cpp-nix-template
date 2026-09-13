cmake_minimum_required(VERSION 3.28)

project(
  myproject
  VERSION 0.1.0
  DESCRIPTION "A C++23 project template"
  HOMEPAGE_URL "https://github.com/rollschild/myproject"
  LANGUAGES CXX)

# No C++20 modules here. Scanning is on by default for C++20+ with Ninja and GCC
# 14+, and it injects GCC-only flags (-fmodules-ts, -fdeps-format=...) into
# compile_commands.json that clangd and clang-tidy reject.
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake")

include(PreventInSourceBuilds)
include(ProjectOptions) # options + myproject_apply_dev_flags()

add_subdirectory(src)

if(MYPROJECT_BUILD_APPS)
  add_subdirectory(apps)
endif()

if(PROJECT_IS_TOP_LEVEL)
  include(CTest) # defines BUILD_TESTING (default ON) and calls enable_testing()
  if(BUILD_TESTING)
    add_subdirectory(tests)
  endif()
endif()

if(NOT CMAKE_SKIP_INSTALL_RULES)
  include(InstallRules)
endif()
