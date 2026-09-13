add_library(myproject_lib)
add_library(myproject::myproject ALIAS myproject_lib)

target_sources(
  myproject_lib
  PRIVATE myproject.cpp
  PUBLIC FILE_SET HEADERS BASE_DIRS "${PROJECT_SOURCE_DIR}/include" FILES
         "${PROJECT_SOURCE_DIR}/include/myproject/myproject.hpp")

target_compile_features(myproject_lib PUBLIC cxx_std_23)

set_target_properties(
  myproject_lib
  PROPERTIES OUTPUT_NAME myproject # libmyproject.a, not libmyproject_lib.a
             EXPORT_NAME myproject # consumers link myproject::myproject
             VERSION ${PROJECT_VERSION}
             SOVERSION ${PROJECT_VERSION_MAJOR})

myproject_apply_dev_flags(myproject_lib)
