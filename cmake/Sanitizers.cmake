# AddressSanitizer + UndefinedBehaviorSanitizer for a single target (PRIVATE).
function(myproject_enable_sanitizers target)
  if(MSVC)
    target_compile_options(${target} PRIVATE /fsanitize=address)
    return()
  endif()

  target_compile_options(
    ${target} PRIVATE -fsanitize=address,undefined -fno-omit-frame-pointer
                      -fno-sanitize-recover=all)
  target_link_options(${target} PRIVATE -fsanitize=address,undefined)
endfunction()
