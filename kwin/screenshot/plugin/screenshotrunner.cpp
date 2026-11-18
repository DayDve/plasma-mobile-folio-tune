// SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later

#include "screenshotrunner.h"

#include <QDebug>
#include <QTimer>

using namespace Qt::StringLiterals;

ScreenshotRunner::ScreenshotRunner(QObject *parent)
    : QObject{parent}
{
    m_process.setProgram(QStringLiteral(SCREENSHOT_TOOL));
    m_process.setProcessChannelMode(QProcess::ForwardedErrorChannel);
    connect(&m_process, &QProcess::readyReadStandardOutput, this, &ScreenshotRunner::readOutput);
    connect(&m_process, &QProcess::stateChanged, this, &ScreenshotRunner::busyChanged);
    connect(&m_process, &QProcess::errorOccurred, this, [](QProcess::ProcessError error) {
        qWarning() << "screenshot tool failed:" << error;
    });
}

bool ScreenshotRunner::isBusy() const
{
    return m_process.state() != QProcess::NotRunning;
}

void ScreenshotRunner::take()
{
    if (isBusy()) {
        return;
    }
    m_process.start();
    QTimer::singleShot(20000, &m_process, [this] {
        if (isBusy()) {
            m_process.kill();
        }
    });
}

void ScreenshotRunner::open(const QString &path)
{
    QProcess::startDetached(u"kde-open"_s, {path});
}

void ScreenshotRunner::readOutput()
{
    while (m_process.canReadLine()) {
        const QString line = QString::fromUtf8(m_process.readLine()).trimmed();
        if (line == "captured"_L1) {
            Q_EMIT captured();
        } else if (line.startsWith("saved "_L1)) {
            Q_EMIT saved(line.mid(6));
        }
    }
}

#include "moc_screenshotrunner.cpp"
