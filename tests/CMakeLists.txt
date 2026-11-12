find_package(GTest REQUIRED)
include(GoogleTest) # gtest_discover_tests()

add_executable(myproject_tests myproject_test.cpp)
target_link_libraries(
    myproject_tests
    PRIVATE myproject::myproject GTest::gtest_main
)
myproject_enable_warnings(myproject_tests)

# Add each TEST to CTest as a separate test.
gtest_discover_tests(myproject_tests)
