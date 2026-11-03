add_executable(myproject_exe main.cpp)
set_target_properties(myproject_exe PROPERTIES OUTPUT_NAME myproject)
target_link_libraries(myproject_exe PRIVATE myproject::myproject)
myproject_enable_warnings(myproject_exe)

install(TARGETS myproject_exe)
