// SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later

#include "screenshotkeys.h"

#include <core/inputdevice.h>
#include <input_event.h>
#include <keyboard_input.h>
#include <wayland_server.h>

using namespace std::chrono_literals;

static bool isComboKey(Qt::Key key)
{
    return key == Qt::Key_PowerOff || key == Qt::Key_VolumeDown;
}

// Ahead of the lock screen filter too: a key held back here must also be released here,
// even if the screen gets locked in between.
ScreenshotKeys::ScreenshotKeys(QObject *parent)
    : QObject{parent}
    , KWin::InputEventFilter{KWin::InputFilterOrder::VirtualTerminal}
{
    m_holdTimer.setSingleShot(true);
    m_holdTimer.setInterval(150ms);
    connect(&m_holdTimer, &QTimer::timeout, this, &ScreenshotKeys::replayHeldKey);
    KWin::input()->installInputEventFilter(this);
}

ScreenshotKeys::~ScreenshotKeys()
{
    replayHeldKey();
}

bool ScreenshotKeys::isEnabled() const
{
    return m_enabled;
}

void ScreenshotKeys::setEnabled(bool enabled)
{
    if (m_enabled == enabled) {
        return;
    }
    m_enabled = enabled;
    if (!m_enabled) {
        replayHeldKey();
    }
    Q_EMIT enabledChanged();
}

void ScreenshotKeys::replayHeldKey()
{
    m_holdTimer.stop();
    if (!m_holding || !KWin::input()) {
        m_holding = false;
        return;
    }
    m_holding = false;
    m_replaying = true;
    KWin::input()->keyboard()->processKey(m_heldScanCode, KWin::KeyboardKeyState::Pressed, m_heldTime, m_heldDevice.data());
    m_replaying = false;
}

bool ScreenshotKeys::keyboardKey(KWin::KeyboardKeyEvent *event)
{
    if (m_replaying || !isComboKey(event->key)) {
        return false;
    }

    switch (event->state) {
    case KWin::KeyboardKeyState::Pressed:
        if (!m_enabled || KWin::waylandServer()->isScreenLocked()) {
            return false;
        }
        if (m_holding && m_heldKey != event->key) {
            m_holdTimer.stop();
            m_holding = false;
            m_consumed = {m_heldScanCode, event->nativeScanCode};
            Q_EMIT triggered();
            return true;
        }
        if (m_holding) {
            return false;
        }
        m_holding = true;
        m_heldKey = event->key;
        m_heldScanCode = event->nativeScanCode;
        m_heldTime = event->timestamp;
        m_heldDevice = event->device;
        m_holdTimer.start();
        return true;

    case KWin::KeyboardKeyState::Repeated:
        return m_consumed.contains(event->nativeScanCode) || (m_holding && m_heldScanCode == event->nativeScanCode);

    case KWin::KeyboardKeyState::Released:
        if (m_consumed.remove(event->nativeScanCode)) {
            return true;
        }
        // a quick tap: the press goes first, then this release continues on its way
        if (m_holding && m_heldScanCode == event->nativeScanCode) {
            replayHeldKey();
        }
        return false;
    }
    return false;
}

#include "moc_screenshotkeys.cpp"
