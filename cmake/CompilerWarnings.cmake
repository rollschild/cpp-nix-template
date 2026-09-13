# Strict warning sets per compiler family. Applied PRIVATE, so consumers of the
# installed library are unaffected.
function(myproject_set_warnings target warnings_as_errors)
  set(gcc_clang_warnings
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
      -Wunused)

  set(gcc_only_warnings -Wmisleading-indentation -Wduplicated-cond
                        -Wduplicated-branches -Wlogical-op -Wuseless-cast)

  set(msvc_warnings /W4 /permissive-)

  if(MSVC)
    set(warnings ${msvc_warnings})
    if(warnings_as_errors)
      list(APPEND warnings /WX)
    endif()
  else()
    set(warnings ${gcc_clang_warnings})
    if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
      list(APPEND warnings ${gcc_only_warnings})
    endif()
    if(warnings_as_errors)
      list(APPEND warnings -Werror)
    endif()
  endif()

  target_compile_options(${target}
                         PRIVATE "$<$<COMPILE_LANGUAGE:CXX>:${warnings}>")
endfunction()
