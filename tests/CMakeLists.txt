find_package(Catch2 3 REQUIRED)
include(Catch) # provides catch_discover_tests()

add_executable(myproject_tests myproject_test.cpp)
target_link_libraries(myproject_tests PRIVATE myproject::myproject
                                              Catch2::Catch2WithMain)

myproject_apply_dev_flags(myproject_tests)

# Register every TEST_CASE with CTest individually.
catch_discover_tests(myproject_tests)
