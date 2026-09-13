# `cmake --install` layout and the exported CMake package, so other projects can
# `find_package(myproject)` and link `myproject::myproject`.
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

set(MYPROJECT_INSTALL_CMAKEDIR
    "${CMAKE_INSTALL_LIBDIR}/cmake/myproject"
    CACHE STRING "Install directory for the CMake package config files")
mark_as_advanced(MYPROJECT_INSTALL_CMAKEDIR)

# Library + its public headers (FILE_SET). Destinations default to
# GNUInstallDirs.
install(
  TARGETS myproject_lib
  EXPORT myproject-targets
  FILE_SET HEADERS)

if(TARGET myproject_exe)
  install(TARGETS myproject_exe EXPORT myproject-targets)
endif()

install(
  EXPORT myproject-targets
  NAMESPACE myproject::
  FILE myproject-targets.cmake
  DESTINATION "${MYPROJECT_INSTALL_CMAKEDIR}")

write_basic_package_version_file(
  "${PROJECT_BINARY_DIR}/myproject-config-version.cmake"
  COMPATIBILITY SameMajorVersion)

configure_package_config_file(
  "${PROJECT_SOURCE_DIR}/cmake/myproject-config.cmake.in"
  "${PROJECT_BINARY_DIR}/myproject-config.cmake"
  INSTALL_DESTINATION "${MYPROJECT_INSTALL_CMAKEDIR}")

install(FILES "${PROJECT_BINARY_DIR}/myproject-config.cmake"
              "${PROJECT_BINARY_DIR}/myproject-config-version.cmake"
        DESTINATION "${MYPROJECT_INSTALL_CMAKEDIR}")
