// SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQml
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents
import org.kde.plasma.private.mobileshell.screenshotplugin as Screenshot
import org.kde.plasma.private.mobileshell.screenshotsettings as ScreenshotSettings

// Screenshots from the keys or a gesture, with a flash and a preview in the corner.
// Loaded separately from the floating windows: if the module does not fit this KWin,
// only the screenshots are lost.
Item {
    id: shots

    readonly property var settings: ScreenshotSettings.ScreenshotSettings
    readonly property rect area: KWinComponents.Workspace.activeScreen
                                 ? KWinComponents.Workspace.activeScreen.geometry : Qt.rect(0, 0, 1, 1)
    property string lastShot: ""

    function take() {
        // the preview of the previous shot must not get into this one
        lastShot = "";
        runner.take();
    }

    Screenshot.ScreenshotKeys {
        enabled: shots.settings.keysEnabled
        onTriggered: shots.take()
    }

    Instantiator {
        active: shots.settings.gestureEnabled
        delegate: KWinComponents.SwipeGestureHandler {
            direction: KWinComponents.SwipeGestureHandler.Direction.Down
            fingerCount: 3
            deviceType: KWinComponents.SwipeGestureHandler.Device.Touchscreen
            onActivated: shots.take()
        }
    }

    Screenshot.ScreenshotRunner {
        id: runner
        onCaptured: flashAnimation.restart()
        onSaved: path => {
            shots.lastShot = path;
            previewTimer.restart();
        }
    }

    Timer {
        id: previewTimer
        interval: 4000
        onTriggered: shots.lastShot = ""
    }

    Window {
        transientParent: null
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint | Qt.WindowTransparentForInput
        color: "transparent"
        visible: flashAnimation.running
        x: shots.area.x
        y: shots.area.y
        width: shots.area.width
        height: shots.area.height

        Rectangle {
            id: flash
            anchors.fill: parent
            color: "white"
            opacity: 0
        }

        NumberAnimation {
            id: flashAnimation
            target: flash
            property: "opacity"
            from: 0.8
            to: 0
            duration: 250
            easing.type: Easing.OutQuad
        }
    }

    Window {
        id: preview

        transientParent: null
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        color: "transparent"
        visible: shots.lastShot !== ""
        width: Math.round(shots.area.width * 0.25)
        height: Math.round(width * shots.area.height / shots.area.width)
        x: shots.area.x + Kirigami.Units.gridUnit
        // above the navigation panel
        y: shots.area.y + shots.area.height - height - Kirigami.Units.gridUnit * 5

        Image {
            anchors.fill: parent
            source: shots.lastShot === "" ? "" : "file://" + shots.lastShot
            sourceSize.width: preview.width * 2
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: "white"
            radius: Kirigami.Units.cornerRadius
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                runner.open(shots.lastShot);
                shots.lastShot = "";
            }
        }
    }
}
