# Strict warnings for the targets of this project. They are PRIVATE, so the
# users of the library do not get them. This file does not set -Werror. The
# presets and the Nix package set the CMake variable
# CMAKE_COMPILE_WARNING_AS_ERROR.
function(myproject_enable_warnings target)
    set(warnings
        -Wall
        -Wextra
        -Wpedantic
        -Wshadow
        -Wconversion
        -Wsign-conversion
        -Wnon-virtual-dtor
        -Wold-style-cast
        -Wcast-align
        -Woverloaded-virtual
        -Wnull-dereference
        -Wdouble-promotion
        -Wformat=2
        -Wimplicit-fallthrough
    )
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        list(
            APPEND warnings
            -Wduplicated-cond
            -Wduplicated-branches
            -Wlogical-op
            -Wuseless-cast
        )
    endif()
    target_compile_options(${target} PRIVATE ${warnings})
endfunction()
