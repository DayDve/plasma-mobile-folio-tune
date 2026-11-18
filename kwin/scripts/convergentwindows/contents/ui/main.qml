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
    readonly property int floatingMinWidth: 160
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

    // Where the handles sit. It does not follow the window during a drag: touch points
    // are mapped through the handle's position, which must not change under the finger.
    property var handleFrame: Qt.rect(0, 0, 0, 0)
    property int handleTitleHeight: 0
    property var dragStart: null
    property var pendingGeometry: null

    Binding {
        target: root
        property: "handleFrame"
        when: root.floatingWindow !== null && root.dragStart === null
        value: root.floatingWindow ? root.floatingWindow.frameGeometry : Qt.rect(0, 0, 0, 0)
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: root
        property: "handleTitleHeight"
        when: root.floatingWindow !== null && root.dragStart === null
        value: root.floatingWindow ? root.floatingWindow.clientGeometry.y - root.floatingWindow.frameGeometry.y : 0
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
        default property alias content: dragArea.data

        // declared inside an item that has no window: Qt would wait for that one to show
        transientParent: null
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        color: "transparent"
        visible: root.floatingWindow !== null

        MouseArea {
            id: dragArea
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

    // Moves the window: lies over its title bar.
    FloatingHandle {
        x: root.handleFrame.x
        y: root.handleFrame.y
        width: Math.max(1, root.handleFrame.width)
        height: Math.max(root.handleTitleHeight, Kirigami.Units.gridUnit * 2)

        Rectangle {
            // at the very top, to stay off the title text
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 2
            width: Kirigami.Units.gridUnit * 3
            height: Kirigami.Units.smallSpacing
            radius: height / 2
            color: Kirigami.Theme.highlightColor
        }
    }

    // Resizes the window: hangs under its bottom right corner, so that it covers nothing
    // of the application, unless the window reaches the bottom of the screen.
    FloatingHandle {
        readonly property var area: root.floatingWindow ? root.floatingArea(root.floatingWindow) : Qt.rect(0, 0, 0, 0)

        resize: true
        width: Kirigami.Units.gridUnit * 3
        height: Kirigami.Units.gridUnit * 3
        x: root.handleFrame.x + root.handleFrame.width - width
        y: Math.min(root.handleFrame.y + root.handleFrame.height, area.y + area.height - height)

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.highlightColor

            Repeater {
                model: 2
                Rectangle {
                    required property int index
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: index * Kirigami.Units.smallSpacing * 2
                    anchors.verticalCenterOffset: index * Kirigami.Units.smallSpacing * 2
                    width: Kirigami.Units.gridUnit * (index ? 0.8 : 1.6)
                    height: 2
                    rotation: -45
                    color: Kirigami.Theme.highlightedTextColor
                }
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
