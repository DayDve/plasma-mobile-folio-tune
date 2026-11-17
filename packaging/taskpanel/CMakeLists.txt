# The org.kde.plasma.mobile.taskpanel containment (navigation panel) from these sources
# (same version as the system's) with our changes. The package installs it into its own
# plugin directory, ahead of the system one through QT_PLUGIN_PATH.
cmake_minimum_required(VERSION 3.24)
project(taskpanel-mobile LANGUAGES CXX)

set(QT_MAJOR_VERSION 6)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQmlModule)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(QT_QML_GENERATE_QMLLS_INI OFF)

find_package(Qt6 REQUIRED COMPONENTS Core Gui DBus Qml Quick Sensors)
find_package(KF6 REQUIRED COMPONENTS I18n KIO Config CoreAddons Service Package WindowSystem)
find_package(KF6Screen REQUIRED)
find_package(Plasma CONFIG REQUIRED)

add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../../containments/taskpanel taskpanel)
