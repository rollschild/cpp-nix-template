#include <format>
#include <myproject/myproject.hpp>
#include <string>
#include <string_view>

namespace myproject {

std::string greet(std::string_view name) {
    return std::format("Hello, {}!", name);
}

}  // namespace myproject
