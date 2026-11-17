# Folio Tune: the Folio homescreen under its own plugin ID.
# Sources are taken from ../containments/homescreens/folio as they are (so upstream
# merges do not conflict); the ID is changed at configure time.
cmake_minimum_required(VERSION 3.20)
project(foliotune LANGUAGES CXX)

set(UPSTREAM_ID org.kde.plasma.mobile.homescreen.folio)
set(TUNE_ID     org.kde.plasma.mobile.homescreen.foliotune)

set(QT_MAJOR_VERSION 6)
find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(ECMQmlModule)

set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(KF6 REQUIRED COMPONENTS I18n Service KIO Notifications WindowSystem JobWidgets)
find_package(Plasma CONFIG REQUIRED)
find_package(PlasmaQuick CONFIG REQUIRED)
find_package(KWayland CONFIG REQUIRED)

# QML without AOT: compiled at load time, less tied to the exact Qt version.
set(QT_QML_GENERATE_QMLLS_INI OFF)
set(_nocachegen "file(GLOB_RECURSE _qml \${CMAKE_CURRENT_SOURCE_DIR}/qml/*.qml)\nset_source_files_properties(\${_qml} PROPERTIES QT_QML_SKIP_CACHEGEN TRUE)\n")

# Copy of the sources with the new ID
set(SRC ${CMAKE_CURRENT_SOURCE_DIR}/../containments/homescreens/folio)
set(DST ${CMAKE_CURRENT_BINARY_DIR}/folio)
file(GLOB_RECURSE _files RELATIVE ${SRC} CONFIGURE_DEPENDS ${SRC}/*)
foreach(f ${_files})
    if(f MATCHES "^(po/|Messages.sh|README.md)")
        continue()
    endif()
    file(READ ${SRC}/${f} _c)
    string(REPLACE "plasma.applet.${UPSTREAM_ID}" "plasma.applet.${TUNE_ID}" _c "${_c}")
    if(f STREQUAL "CMakeLists.txt")
        # the translation domain stays Folio's
        string(REPLACE "plasma_add_applet(${UPSTREAM_ID}" "plasma_add_applet(${TUNE_ID}" _c "${_c}")
        string(REPLACE "(${UPSTREAM_ID} " "(${TUNE_ID} " _c "${_c}")
        string(PREPEND _c "${_nocachegen}")
    endif()
    if(f STREQUAL "metadata.json")
        string(JSON _n LENGTH "${_c}" KPlugin)
        math(EXPR _last "${_n} - 1")
        set(_drop)
        foreach(i RANGE ${_last})
            string(JSON _k MEMBER "${_c}" KPlugin ${i})
            if(_k MATCHES "^(Name|Description)\\[")
                list(APPEND _drop "${_k}")
            endif()
        endforeach()
        foreach(_k IN LISTS _drop)
            string(JSON _c REMOVE "${_c}" KPlugin "${_k}")
        endforeach()
        string(JSON _c SET "${_c}" KPlugin Name "\"Folio Tune\"")
    endif()
    file(WRITE ${DST}/${f}.tmp "${_c}")
    configure_file(${DST}/${f}.tmp ${DST}/${f} COPYONLY)
    file(REMOVE ${DST}/${f}.tmp)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${SRC}/${f})
endforeach()

add_subdirectory(${DST} folio)
