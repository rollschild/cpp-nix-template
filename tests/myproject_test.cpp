#include <catch2/catch_test_macros.hpp>
#include <myproject/myproject.hpp>

TEST_CASE("greet formats the name", "[greet]") {
    REQUIRE(myproject::greet("Nix") == "Hello, Nix!");
}

TEST_CASE("greet accepts an empty name", "[greet]") {
    REQUIRE(myproject::greet("") == "Hello, !");
}
