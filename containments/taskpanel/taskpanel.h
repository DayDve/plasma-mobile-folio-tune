/*
 *   SPDX-FileCopyrightText: 2015 Marco Martin <mart@kde.org>
 *
 *   SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#include <KConfigWatcher>
#include <KSharedConfig>
#include <Plasma/Containment>

class TaskPanel : public Plasma::Containment
{
    Q_OBJECT
    // the button that hides the panel; set in the Folio homescreen settings (plasmamobilerc)
    Q_PROPERTY(bool hideButtonEnabled READ hideButtonEnabled NOTIFY hideButtonEnabledChanged)

public:
    TaskPanel(QObject *parent, const KPluginMetaData &data, const QVariantList &args);
    Q_INVOKABLE void triggerTaskSwitcher() const;

    bool hideButtonEnabled() const;

Q_SIGNALS:
    void hideButtonEnabledChanged();

private:
    void readShellConfig();

    KSharedConfig::Ptr m_shellConfig;
    KConfigWatcher::Ptr m_shellConfigWatcher;
    bool m_hideButtonEnabled = false;
};
