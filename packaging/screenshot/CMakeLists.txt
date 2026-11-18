# Screenshots from the power and volume keys or a gesture: a QML module KWin loads, the
# settings module and the one-shot capture tool. New names, so they sit next to the system
# files and override nothing. The KWin part must match the installed KWin exactly.
cmake_minimum_required(VERSION 3.24)
project(screenshot-mobile LANGUAGES CXX)

set(QT_MAJOR_VERSION 6)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQmlModule)
set(QT_QML_GENERATE_QMLLS_INI OFF)

find_package(Qt6 REQUIRED COMPONENTS Core Gui DBus Qml Quick)
find_package(KF6 REQUIRED COMPONENTS Config)
find_package(KWin REQUIRED)

set(SRC ${CMAKE_CURRENT_SOURCE_DIR}/../../kwin/screenshot)
add_subdirectory(${SRC}/settings settings)
add_subdirectory(${SRC}/plugin plugin)
add_subdirectory(${SRC}/tool tool)
