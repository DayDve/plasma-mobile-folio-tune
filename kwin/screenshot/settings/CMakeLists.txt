# SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
# SPDX-License-Identifier: GPL-2.0-or-later

ecm_add_qml_module(screenshotsettingsplugin
    URI org.kde.plasma.private.mobileshell.screenshotsettings
    GENERATE_PLUGIN_SOURCE
    DEPENDENCIES QtCore
)
target_sources(screenshotsettingsplugin PRIVATE screenshotsettings.cpp)
target_link_libraries(screenshotsettingsplugin PRIVATE Qt::Core Qt::Qml KF6::ConfigCore)
ecm_finalize_qml_module(screenshotsettingsplugin)
