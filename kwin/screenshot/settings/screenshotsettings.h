// SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <KConfigWatcher>
#include <KSharedConfig>

#include <QObject>
#include <qqmlregistration.h>

// Which ways of taking a screenshot are on. Kept apart from the KWin plugin: the settings
// application loads this module and must not load KWin's library with it.
class ScreenshotSettings : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool keysEnabled READ keysEnabled WRITE setKeysEnabled NOTIFY keysEnabledChanged)
    Q_PROPERTY(bool gestureEnabled READ gestureEnabled WRITE setGestureEnabled NOTIFY gestureEnabledChanged)

public:
    explicit ScreenshotSettings(QObject *parent = nullptr);

    bool keysEnabled() const;
    void setKeysEnabled(bool enabled);
    bool gestureEnabled() const;
    void setGestureEnabled(bool enabled);

Q_SIGNALS:
    void keysEnabledChanged();
    void gestureEnabledChanged();

private:
    void write(const char *key, bool value);

    KSharedConfig::Ptr m_config;
    KConfigWatcher::Ptr m_watcher;
};
