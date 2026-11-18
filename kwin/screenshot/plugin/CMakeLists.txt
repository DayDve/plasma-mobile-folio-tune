# SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

ecm_add_qml_module(screenshotplugin
    URI org.kde.plasma.private.mobileshell.screenshotplugin
    GENERATE_PLUGIN_SOURCE
    DEPENDENCIES QtCore
)
target_sources(screenshotplugin PRIVATE screenshotkeys.cpp screenshotrunner.cpp)
target_compile_definitions(screenshotplugin PRIVATE
    SCREENSHOT_TOOL="${KDE_INSTALL_FULL_LIBEXECDIR}/plasma-mobile-screenshot")
target_link_libraries(screenshotplugin PRIVATE Qt::Core Qt::Gui Qt::Qml KWin::kwin)
ecm_finalize_qml_module(screenshotplugin)
