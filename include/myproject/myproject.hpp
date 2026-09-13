#pragma once

#include <string>
#include <string_view>

namespace myproject {

/// Returns "Hello, <name>!".
[[nodiscard]] std::string greet(std::string_view name);

}  // namespace myproject
