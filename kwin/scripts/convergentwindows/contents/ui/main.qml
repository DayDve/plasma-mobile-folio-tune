// SPDX-FileCopyrightText: 2023 Plata Hill <plata.hill@kdemail.net>
// SPDX-FileCopyrightText: 2023 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.kwin as KWinComponents
import org.kde.plasma.private.mobileshell.shellsettingsplugin as ShellSettings

Loader {
    id: root

    property var currentWindow

    // Share of the screen height a floating window takes; what is below it stays visible.
    readonly property real floatingHeightRatio: 0.55
    readonly property int floatingMargin: 8
    readonly property int floatingMinWidth: 240
    readonly property int floatingMinHeight: 120

    // KWin reports its own windows, the handles below among them, as normal ones too.
    function isAppWindow(window) {
        return window.normalWindow && window.resourceClass !== "";
    }

    // The active floating window: it gets the handles below.
    readonly property var floatingWindow: {
        const window = KWinComponents.Workspace.activeWindow;
        if (!window || !root.isAppWindow(window) || !window.keepAbove || window.fullScreen || window.minimized
                || ShellSettings.Settings.convergenceModeEnabled) {
            return null;
        }
        return window;
    }

    // Handles are two layers. What takes the touch does not move during a drag: touch
    // points are mapped through its position, which must not change under the finger.
    // What is drawn ignores input and stays on the window all the time.
    readonly property var liveFrame: floatingWindow ? floatingWindow.frameGeometry : Qt.rect(0, 0, 0, 0)
    readonly property var liveArea: floatingWindow ? floatingArea(floatingWindow) : Qt.rect(0, 0, 0, 0)
    property var handleFrame: Qt.rect(0, 0, 0, 0)
    property var dragStart: null
    property var pendingGeometry: null

    Binding {
        target: root
        property: "handleFrame"
        when: root.floatingWindow !== null && root.dragStart === null
        value: root.liveFrame
        restoreMode: Binding.RestoreNone
    }

    function floatingArea(window) {
        return KWinComponents.Workspace.clientArea(KWinComponents.Workspace.MaximizeArea, window.output, window.desktops[0]);
    }

    function beginDrag() {
        const g = floatingWindow.frameGeometry;
        dragStart = Qt.rect(g.x, g.y, g.width, g.height);
    }

    function dragTo(dx, dy, resize) {
        const window = floatingWindow;
        if (!window || !dragStart) {
            return;
        }
        const s = dragStart;
        const area = floatingArea(window);
        const clamp = (value, low, high) => Math.max(low, Math.min(value, high));
        if (resize) {
            const minWidth = Math.max(window.minSize.width, floatingMinWidth);
            const minHeight = Math.max(window.minSize.height, floatingMinHeight);
            pendingGeometry = Qt.rect(s.x, s.y,
                                      clamp(s.width + dx, minWidth, area.x + area.width - s.x),
                                      clamp(s.height + dy, minHeight, area.y + area.height - s.y));
        } else {
            pendingGeometry = Qt.rect(clamp(s.x + dx, area.x, area.x + area.width - s.width),
                                      clamp(s.y + dy, area.y, area.y + area.height - s.height),
                                      s.width, s.height);
        }
        if (!applyTimer.running) {
            applyTimer.start();
        }
    }

    function applyPending() {
        if (floatingWindow && pendingGeometry) {
            floatingWindow.frameGeometry = pendingGeometry;
        }
        pendingGeometry = null;
    }

    function endDrag() {
        applyTimer.stop();
        applyPending();
        dragStart = null;
    }

    // apps redraw slowly on a phone: do not ask for a new size on every touch event
    Timer {
        id: applyTimer
        interval: 40
        onTriggered: root.applyPending()
    }

    component FloatingHandle: Window {
        id: handle

        property bool resize: false

        // declared inside an item that has no window: Qt would wait for that one to show
        transientParent: null
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        color: "transparent"
        visible: root.floatingWindow !== null

        MouseArea {
            anchors.fill: parent
            preventStealing: true

            property point pressPoint

            onPressed: mouse => {
                pressPoint = Qt.point(mouse.x, mouse.y);
                root.beginDrag();
            }
            onPositionChanged: mouse => root.dragTo(mouse.x - pressPoint.x, mouse.y - pressPoint.y, handle.resize)
            onReleased: root.endDrag()
            onCanceled: root.endDrag()
        }
    }

    component HandleMark: Window {
        transientParent: null
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint | Qt.WindowTransparentForInput
        color: "transparent"
        visible: root.floatingWindow !== null
    }

    // Moves the window. Only the middle of its top edge: applications without a title
    // bar have their own buttons in the corners.
    FloatingHandle {
        width: Kirigami.Units.gridUnit * 5
        height: Kirigami.Units.gridUnit * 1.5
        x: root.handleFrame.x + (root.handleFrame.width - width) / 2
        y: root.handleFrame.y
    }

    HandleMark {
        width: Kirigami.Units.gridUnit * 3
        height: Kirigami.Units.smallSpacing
        x: root.liveFrame.x + (root.liveFrame.width - width) / 2
        y: root.liveFrame.y + 2

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Kirigami.Theme.highlightColor
        }
    }

    // Resizes the window: a finger-sized area around its bottom right corner.
    FloatingHandle {
        resize: true
        width: Kirigami.Units.gridUnit * 3
        height: Kirigami.Units.gridUnit * 3
        x: Math.min(root.handleFrame.x + root.handleFrame.width - width / 2, root.liveArea.x + root.liveArea.width - width)
        y: Math.min(root.handleFrame.y + root.handleFrame.height - height / 2, root.liveArea.y + root.liveArea.height - height)
    }

    // A bracket lying on the corner: the corner of a rounded frame, the rest cut off.
    HandleMark {
        width: Kirigami.Units.gridUnit * 1.5
        height: Kirigami.Units.gridUnit * 1.5
        x: root.liveFrame.x + root.liveFrame.width - width
        y: root.liveFrame.y + root.liveFrame.height - height

        Item {
            anchors.fill: parent
            clip: true

            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: parent.width * 2
                height: parent.height * 2
                radius: Kirigami.Units.cornerRadius
                color: "transparent"
                border.width: Kirigami.Units.smallSpacing
                border.color: Kirigami.Theme.highlightColor
            }
        }
    }

    component FloatingButton: MouseArea {
        property alias iconName: buttonIcon.source

        width: Kirigami.Units.gridUnit * 2
        height: Kirigami.Units.gridUnit * 2

        Kirigami.Icon {
            id: buttonIcon
            anchors.centerIn: parent
            width: Kirigami.Units.iconSizes.small
            height: Kirigami.Units.iconSizes.small
            isMask: true
            color: Kirigami.Theme.textColor
        }
    }

    // Top right corner: back to full screen, and close.
    Window {
        transientParent: null
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        color: "transparent"
        visible: root.floatingWindow !== null
        width: buttonRow.width
        height: buttonRow.height
        x: root.liveFrame.x + root.liveFrame.width - width
        y: root.liveFrame.y

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.backgroundColor
            opacity: 0.85
        }

        Row {
            id: buttonRow

            FloatingButton {
                iconName: "window-maximize"
                onClicked: root.floatingWindow.keepAbove = false
            }

            FloatingButton {
                iconName: "window-close"
                onClicked: root.floatingWindow.closeWindow()
            }
        }
    }

    // Without convergence mode every window is maximized, except the ones marked as
    // floating in the task switcher. The mark is the window's "keep above" state: it
    // is what such a window needs anyway, and the switcher and this script both see it.
    function makeFloating(window) {
        if (ShellSettings.Settings.convergenceModeEnabled || window.fullScreen) {
            return;
        }
        const desktop = window.desktops[0];
        if (desktop === undefined) {
            return;
        }
        const area = KWinComponents.Workspace.clientArea(KWinComponents.Workspace.MaximizeArea, window.output, desktop);
        window.noBorder = false;
        window.setMaximize(false, false);
        window.frameGeometry = Qt.rect(area.x + floatingMargin,
                                       area.y + floatingMargin,
                                       area.width - floatingMargin * 2,
                                       Math.round(area.height * floatingHeightRatio));
    }

    function watchFloating(window) {
        window.keepAboveChanged.connect(() => {
            if (window.keepAbove) {
                root.makeFloating(window);
            } else {
                root.run(window);
            }
        });
    }

    Component.onCompleted: {
        const windows = KWinComponents.Workspace.windows;
        for (let i = 0; i < windows.length; i++) {
            if (root.isAppWindow(windows[i])) {
                root.watchFloating(windows[i]);
                root.run(windows[i]);
            }
        }
    }

    function run(window) {
        // HACK: don't maximize xwaylandvideobridge
        // see: https://invent.kde.org/plasma/plasma-mobile/-/issues/324
        if (window.resourceClass === 'xwaylandvideobridge') {
            return;
        }

        if (!root.isAppWindow(window)) {
            return;
        }

        if (ShellSettings.Settings.convergenceModeEnabled) {
            window.noBorder = false;
        } else if (window.keepAbove) {
            // floating: keep the place given by makeFloating(), and a title bar to tell
            // the window from what is below it
            window.noBorder = false;
        } else {
            if (!window.fullScreen) {
                const output = window.output;
                const desktop = window.desktops[0]; // assume it's the first desktop that the window is on
                if (desktop === undefined) {
                    return;
                }
                const maximizeRect = KWinComponents.Workspace.clientArea(KWinComponents.Workspace.MaximizeArea, output, desktop);

                // set the window to the maximized size and position instantly, avoiding race condition
                // between maximizing and window decorations being turned off (changing window height)
                // see: https://invent.kde.org/teams/plasma-mobile/issues/-/issues/256
                window.frameGeometry = maximizeRect;
            }

            // turn off window decorations
            window.noBorder = true;

            if (!window.fullScreen) {
                // run maximize after to ensure the state is maximized
                window.setMaximize(true, true);
            }
        }
    }

    Connections {
        target: currentWindow

        function onFullScreenChanged() {
            currentWindow.interactiveMoveResizeFinished.connect((currentWindow) => {
                root.run(currentWindow);
            });
            root.run(currentWindow);
        }

        function onMaximizedChanged() {
            if (!currentWindow.maximizable) {
                return;
            }
            currentWindow.interactiveMoveResizeFinished.connect((currentWindow) => {
                root.run(currentWindow);
            });
            root.run(currentWindow);
        }
    }

    Connections {
        target: ShellSettings.Settings

        function onConvergenceModeEnabledChanged() {
            const windows = KWinComponents.Workspace.windows;

            for (let i = 0; i < windows.length; i++) {
                if (root.isAppWindow(windows[i])) {
                    root.run(windows[i]);
                }
            }
        }
    }

    Connections {
        target: KWinComponents.Workspace

        function onWindowAdded(window) {
            if (root.isAppWindow(window)) {
                root.watchFloating(window);
                window.interactiveMoveResizeFinished.connect((window) => {
                    root.run(window);
                });
                root.run(window);
            }
        }

        function onWindowActivated(window) {
            if (root.isAppWindow(window)) {
                currentWindow = window;
                window.interactiveMoveResizeFinished.connect((window) => {
                    root.run(window);
                });
                root.run(window);
            }
        }

        function onScreensChanged() {
            // Windows are moved from the external screen
            // to the internal screen if the external screen
            // is disconnected.
            const windows = KWinComponents.Workspace.windows;

            for (var i = 0; i < windows.length; i++) {
                if (root.isAppWindow(windows[i])) {
                    root.run(windows[i]);
                    // the old place may be off the new screen
                    if (windows[i].keepAbove) {
                        root.makeFloating(windows[i]);
                    }
                }
            }
        }
    }
}
