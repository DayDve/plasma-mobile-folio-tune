// SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#include <input.h>

#include <QObject>
#include <QPointer>
#include <QSet>
#include <QTimer>
#include <qqmlregistration.h>

#include <chrono>

namespace KWin
{
class InputDevice;
}

// Power + volume down, seen by KWin itself ahead of its global shortcuts.
//
// The first of the two keys is held back for a moment. If the other one follows, both are
// consumed: the screen does not turn off and the volume does not change. Otherwise the key
// is replayed and everything goes on as usual, so power keeps its short and long press.
class ScreenshotKeys : public QObject, public KWin::InputEventFilter
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool enabled READ isEnabled WRITE setEnabled NOTIFY enabledChanged)

public:
    explicit ScreenshotKeys(QObject *parent = nullptr);
    ~ScreenshotKeys() override;

    bool isEnabled() const;
    void setEnabled(bool enabled);

    bool keyboardKey(KWin::KeyboardKeyEvent *event) override;

Q_SIGNALS:
    void enabledChanged();
    void triggered();

private:
    void replayHeldKey();

    bool m_enabled = false;
    bool m_replaying = false;

    bool m_holding = false;
    Qt::Key m_heldKey = Qt::Key_unknown;
    quint32 m_heldScanCode = 0;
    std::chrono::microseconds m_heldTime{0};
    QPointer<KWin::InputDevice> m_heldDevice;
    QTimer m_holdTimer;

    // keys of a recognised combination: their repeats and releases are dropped too
    QSet<quint32> m_consumed;
};
