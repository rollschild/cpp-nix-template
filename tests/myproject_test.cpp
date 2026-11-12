#include <gtest/gtest.h>

#include <myproject/myproject.hpp>

TEST(Greet, FormatsTheName) {
    EXPECT_EQ(myproject::greet("Nix"), "Hello, Nix!");
}

TEST(Greet, AcceptsAnEmptyName) { EXPECT_EQ(myproject::greet(""), "Hello, !"); }
