# Refuse to configure inside the source tree.
get_filename_component(_myproject_src "${CMAKE_SOURCE_DIR}" REALPATH)
get_filename_component(_myproject_bin "${CMAKE_BINARY_DIR}" REALPATH)
if(_myproject_src STREQUAL _myproject_bin)
  message(
    FATAL_ERROR
      "In-source builds are not allowed. Use a preset, e.g. `cmake --preset dev` "
      "(and delete CMakeCache.txt and CMakeFiles/ from the source tree).")
endif()
unset(_myproject_src)
unset(_myproject_bin)
