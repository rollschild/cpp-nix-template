#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <myproject/myproject.hpp>
#include <print>
#include <span>
#include <string_view>

int main(int argc, char* argv[]) try {
    const std::span args(argv, static_cast<std::size_t>(argc));
    const std::string_view name = args.size() > 1 ? args[1] : "world";
    std::println("{}", myproject::greet(name));
    return EXIT_SUCCESS;
} catch (const std::exception& e) {
    // Write the error to stderr and return EXIT_FAILURE. Without this handler,
    // an exception causes a call to std::terminate. The handler must not throw
    // an exception, so it uses fputs, not std::println.
    std::fputs(e.what(), stderr);
    std::fputc('\n', stderr);
    return EXIT_FAILURE;
}
