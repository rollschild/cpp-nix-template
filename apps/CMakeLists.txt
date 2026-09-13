add_executable(myproject_exe main.cpp)
add_executable(myproject::exe ALIAS myproject_exe)

set_target_properties(myproject_exe PROPERTIES OUTPUT_NAME myproject
                                               EXPORT_NAME exe)

target_link_libraries(myproject_exe PRIVATE myproject::myproject)

myproject_apply_dev_flags(myproject_exe)
