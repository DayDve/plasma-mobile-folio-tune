# The Shell page of the settings from these sources (same version as the system's) with
# the screenshot options. Put ahead of the system one through QT_PLUGIN_PATH.
cmake_minimum_required(VERSION 3.24)
project(kcm-mobileshell-mobile LANGUAGES CXX)

set(QT_MAJOR_VERSION 6)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(KF6 REQUIRED COMPONENTS Config CoreAddons I18n KCMUtils)

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../kcms/mobileshell mobileshell)
