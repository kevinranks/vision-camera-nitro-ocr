project(NitroOcr)
cmake_minimum_required(VERSION 3.9.0)

set(PACKAGE_NAME NitroOcr)
set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_CXX_STANDARD 20)

# Define the shared library with cpp-adapter.cpp as the JNI_OnLoad entry
# point. The Nitrogen-generated autolinking below adds additional sources
# (NitroOcrOnLoad.cpp, the hybrid specs) to this same target.
add_library(${PACKAGE_NAME} SHARED
  src/main/cpp/cpp-adapter.cpp
)

# Pull in Nitrogen-generated autolinking (defines sources, includes, and
# the react-native-nitro-modules / vision-camera prefab dependencies).
include(${CMAKE_SOURCE_DIR}/../nitrogen/generated/android/NitroOcr+autolinking.cmake)

# Local includes — cpp-adapter.cpp needs the generated OnLoad header.
target_include_directories(${PACKAGE_NAME} PRIVATE
  "src/main/cpp"
)

find_library(LOG_LIB log)
find_package(react-native-vision-camera REQUIRED)

target_link_libraries(
  ${PACKAGE_NAME}
  ${LOG_LIB}
  android
  react-native-vision-camera::VisionCamera
)
