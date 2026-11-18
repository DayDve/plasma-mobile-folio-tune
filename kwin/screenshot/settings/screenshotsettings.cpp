// SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later

#include "screenshotsettings.h"

#include <KConfigGroup>

using namespace Qt::StringLiterals;

static const auto s_group = "Screenshots"_L1;

ScreenshotSettings::ScreenshotSettings(QObject *parent)
    : QObject{parent}
    , m_config{KSharedConfig::openConfig(u"plasmamobilerc"_s)}
    , m_watcher{KConfigWatcher::create(m_config)}
{
    connect(m_watcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &group) {
        if (group.name() == s_group) {
            Q_EMIT keysEnabledChanged();
            Q_EMIT gestureEnabledChanged();
        }
    });
}

bool ScreenshotSettings::keysEnabled() const
{
    return KConfigGroup{m_config, s_group}.readEntry("keysEnabled", true);
}

void ScreenshotSettings::setKeysEnabled(bool enabled)
{
    write("keysEnabled", enabled);
    Q_EMIT keysEnabledChanged();
}

bool ScreenshotSettings::gestureEnabled() const
{
    return KConfigGroup{m_config, s_group}.readEntry("gestureEnabled", false);
}

void ScreenshotSettings::setGestureEnabled(bool enabled)
{
    write("gestureEnabled", enabled);
    Q_EMIT gestureEnabledChanged();
}

void ScreenshotSettings::write(const char *key, bool value)
{
    KConfigGroup group{m_config, s_group};
    group.writeEntry(key, value, KConfigGroup::Notify);
    m_config->sync();
}
