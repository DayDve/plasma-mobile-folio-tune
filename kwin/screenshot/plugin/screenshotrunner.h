// SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <QObject>
#include <QProcess>
#include <qqmlregistration.h>

// Starts the screenshot tool for one shot. KWin only allows capturing to a program named
// by a desktop file, and encoding the image does not belong in the compositor anyway.
class ScreenshotRunner : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool busy READ isBusy NOTIFY busyChanged)

public:
    explicit ScreenshotRunner(QObject *parent = nullptr);

    bool isBusy() const;

    Q_INVOKABLE void take();
    Q_INVOKABLE void open(const QString &path);

Q_SIGNALS:
    void busyChanged();
    void captured();
    void saved(const QString &path);

private:
    void readOutput();

    QProcess m_process;
};
