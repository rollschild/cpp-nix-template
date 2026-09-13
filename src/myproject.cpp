#include <format>
#include <myproject/myproject.hpp>

namespace myproject {

std::string greet(std::string_view name) {
    return std::format("Hello, {}!", name);
}

}  // namespace myproject
