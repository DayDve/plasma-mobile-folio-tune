# SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

add_executable(plasma-mobile-screenshot main.cpp)
target_link_libraries(plasma-mobile-screenshot PRIVATE Qt::Core Qt::Gui Qt::DBus KF6::ConfigCore)
install(TARGETS plasma-mobile-screenshot DESTINATION ${KDE_INSTALL_FULL_LIBEXECDIR})

configure_file(org.kde.plasma.mobile.screenshot.desktop.in org.kde.plasma.mobile.screenshot.desktop @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/org.kde.plasma.mobile.screenshot.desktop DESTINATION ${KDE_INSTALL_APPDIR})
