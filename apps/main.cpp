#include <cstddef>
#include <myproject/myproject.hpp>
#include <print>
#include <span>
#include <string_view>

int main(int argc, char* argv[]) {
    const std::span args(argv, static_cast<std::size_t>(argc));
    const std::string_view name = args.size() > 1 ? args[1] : "world";
    std::println("{}", myproject::greet(name));
    return 0;
}
