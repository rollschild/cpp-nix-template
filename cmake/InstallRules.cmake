# The `cmake --install` layout and an exported CMake package. Other projects
# can use `find_package(myproject)` and link to `myproject::myproject`.
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

set(cmakedir "${CMAKE_INSTALL_LIBDIR}/cmake/myproject")

install(TARGETS myproject_lib EXPORT myproject-targets FILE_SET HEADERS)
install(
    EXPORT myproject-targets
    NAMESPACE myproject::
    DESTINATION "${cmakedir}"
)

write_basic_package_version_file(
    "${PROJECT_BINARY_DIR}/myproject-config-version.cmake"
    COMPATIBILITY SameMajorVersion
)
configure_package_config_file(
    "${CMAKE_CURRENT_LIST_DIR}/myproject-config.cmake.in"
    "${PROJECT_BINARY_DIR}/myproject-config.cmake"
    INSTALL_DESTINATION "${cmakedir}"
)
install(
    FILES
        "${PROJECT_BINARY_DIR}/myproject-config.cmake"
        "${PROJECT_BINARY_DIR}/myproject-config-version.cmake"
    DESTINATION "${cmakedir}"
)
