# Build options, plus the developer-only flags (warnings, sanitizers) that are
# applied to this project's own targets and never leak to consumers.

option(MYPROJECT_WARNINGS_AS_ERRORS "Treat compiler warnings as errors" OFF)
option(MYPROJECT_ENABLE_SANITIZERS
       "Build with AddressSanitizer and UndefinedBehaviorSanitizer" OFF)
option(MYPROJECT_BUILD_APPS "Build the executables under apps/"
       ${PROJECT_IS_TOP_LEVEL})

include(CompilerWarnings)
include(Sanitizers)

# Apply warnings and (optionally) sanitizers to a target. Everything is PRIVATE
# so nothing propagates through the exported interface.
function(myproject_apply_dev_flags target)
  myproject_set_warnings(${target} ${MYPROJECT_WARNINGS_AS_ERRORS})
  if(MYPROJECT_ENABLE_SANITIZERS)
    myproject_enable_sanitizers(${target})
  endif()
endfunction()
