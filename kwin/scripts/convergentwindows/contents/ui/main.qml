// SPDX-FileCopyrightText: 2023 Plata Hill <plata.hill@kdemail.net>
// SPDX-FileCopyrightText: 2023 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQml
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
    readonly property int floatingMinWidth: 310
    readonly property int floatingMinHeight: 120
    // Share of the screen width a window shrunk to a miniature takes.
    readonly property real miniWidthRatio: 0.4

    // KWin reports its own windows, the handles below among them, as normal ones too.
    function isAppWindow(window) {
        return window.normalWindow && window.resourceClass !== "";
    }

    // The active floating window: it gets the handles below.
    readonly property var floatingWindow: {
        const window = KWinComponents.Workspace.activeWindow;
        if (!window || !root.isAppWindow(window) || !window.skipPager || window.fullScreen || window.minimized
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
        property alias iconColor: buttonIcon.color

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

    // Next to the application icon: stay above other windows.
    Window {
        transientParent: null
        flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
        color: "transparent"
        visible: root.floatingWindow !== null
        width: pinButton.width
        height: pinButton.height
        x: root.liveFrame.x + Kirigami.Units.gridUnit * 2
        y: root.liveFrame.y

        Rectangle {
            anchors.fill: parent
            radius: Kirigami.Units.cornerRadius
            color: Kirigami.Theme.backgroundColor
            opacity: 0.85
        }

        FloatingButton {
            id: pinButton
            readonly property bool pinned: root.floatingWindow !== null && root.floatingWindow.keepAbove
            iconName: "window-pin"
            iconColor: pinned ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
            onClicked: root.floatingWindow.keepAbove = !root.floatingWindow.keepAbove
        }
    }

    // Top right corner: shrink to a miniature, back to full screen, and close.
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
                iconName: "window-minimize"
                onClicked: root.toMini(root.floatingWindow)
            }

            FloatingButton {
                iconName: "window-maximize"
                onClicked: root.floatingWindow.skipPager = false
            }

            FloatingButton {
                iconName: "window-close"
                onClicked: root.floatingWindow.closeWindow()
            }
        }
    }

    // Miniatures: the window itself is minimized, and a live scaled copy of it stays
    // above everything. The application keeps its size, and a tap brings it back.
    property var miniWindows: []
    property var miniPlaces: ({})

    function toMini(window) {
        miniWindows = miniWindows.concat([window]);
        window.minimized = true;
    }

    function removeMini(window) {
        if (miniWindows.indexOf(window) >= 0) {
            miniWindows = miniWindows.filter(w => w !== window);
        }
    }

    function restoreMini(window) {
        window.minimized = false;
        KWinComponents.Workspace.activeWindow = window;
    }

    Instantiator {
        model: root.miniWindows

        delegate: QtObject {
            id: mini

            required property var modelData
            required property int index

            readonly property var window: modelData
            readonly property var area: root.floatingArea(window)
            readonly property int miniWidth: Math.round(area.width * root.miniWidthRatio)
            readonly property int miniHeight: Math.round(miniWidth * window.height / window.width)
            readonly property var place: root.miniPlaces[window.internalId]
            property real posX: place ? place.x : area.x + area.width - miniWidth - root.floatingMargin
            // top right by default: the on-screen keyboard covers the bottom
            property real posY: place ? place.y
                                      : area.y + root.floatingMargin + (miniHeight + root.floatingMargin) * index

            // the same two layers as the handles of a floating window
            readonly property Window picture: Window {
                transientParent: null
                flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint | Qt.WindowTransparentForInput
                color: "transparent"
                visible: true
                x: mini.posX
                y: mini.posY
                width: mini.miniWidth
                height: mini.miniHeight

                KWinComponents.WindowThumbnail {
                    anchors.fill: parent
                    client: mini.window
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: Kirigami.Theme.highlightColor
                }
            }

            readonly property Window touchArea: Window {
                id: touchWindow

                transientParent: null
                flags: Qt.BypassWindowManagerHint | Qt.FramelessWindowHint
                color: "transparent"
                visible: true
                width: mini.miniWidth
                height: mini.miniHeight
                Component.onCompleted: {
                    x = mini.posX;
                    y = mini.posY;
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true

                    property point pressPoint
                    property point startPos
                    property bool moved: false

                    onPressed: mouse => {
                        pressPoint = Qt.point(mouse.x, mouse.y);
                        startPos = Qt.point(mini.posX, mini.posY);
                        moved = false;
                    }
                    onPositionChanged: mouse => {
                        const dx = mouse.x - pressPoint.x;
                        const dy = mouse.y - pressPoint.y;
                        moved = moved || Math.abs(dx) > Kirigami.Units.gridUnit / 2 || Math.abs(dy) > Kirigami.Units.gridUnit / 2;
                        if (moved) {
                            const a = mini.area;
                            mini.posX = Math.max(a.x, Math.min(startPos.x + dx, a.x + a.width - mini.miniWidth));
                            mini.posY = Math.max(a.y, Math.min(startPos.y + dy, a.y + a.height - mini.miniHeight));
                        }
                    }
                    onReleased: {
                        if (moved) {
                            root.miniPlaces[mini.window.internalId] = Qt.point(mini.posX, mini.posY);
                            touchWindow.x = mini.posX;
                            touchWindow.y = mini.posY;
                        } else {
                            root.restoreMini(mini.window);
                        }
                    }
                }
            }
        }
    }

    // Without convergence mode every window is maximized, except the ones marked as
    // floating in the task switcher. The mark is "skip pager": there is no pager here,
    // and the switcher and this script both see it. "Keep above" is left for pinning.
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
        window.skipPagerChanged.connect(() => {
            if (window.skipPager) {
                root.makeFloating(window);
            } else {
                window.keepAbove = false;
                root.run(window);
            }
        });
        window.minimizedChanged.connect(() => {
            if (!window.minimized) {
                root.removeMini(window);
            } else if (window.skipPager && window.keepAbove && root.miniWindows.indexOf(window) < 0) {
                // a pinned window stays when the home button minimizes everything
                window.minimized = false;
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
        } else if (window.skipPager) {
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

        function onWindowRemoved(window) {
            root.removeMini(window);
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
                    if (windows[i].skipPager) {
                        root.makeFloating(windows[i]);
                    }
                }
            }
        }
    }
}
