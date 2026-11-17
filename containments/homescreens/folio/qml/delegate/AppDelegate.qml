// SPDX-FileCopyrightText: 2023 Devin Lin <devin@kde.org>
// SPDX-License-Identifier: LGPL-2.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import QtQuick.Effects

import org.kde.kirigami as Kirigami

import plasma.applet.org.kde.plasma.mobile.homescreen.folio as Folio
import org.kde.plasma.private.mobileshell.state as MobileShellState
import org.kde.plasma.private.mobileshell as MobileShell
import org.kde.plasma.plasmoid

AbstractDelegate {
    id: root

    shadow: true
    name: application ? application.name : ""

    // This may be null for short periods of time due to model changes
    property Folio.FolioApplication application

    property alias iconItem: icon

    property bool turnToFolder: false
    property bool turnToFolderAnimEnabled: false

    function launchApp() {
        if (!application) {
            return;
        }

        if (application.icon !== "" && !root.application.running) {
            MobileShellState.ShellDBusClient.openAppLaunchAnimationWithPosition(
                Plasmoid.screen,
                application.icon,
                application.name,
                application.storageId,
                root.iconItem.Kirigami.ScenePosition.x + root.iconItem.width/2,
                root.iconItem.Kirigami.ScenePosition.y + root.iconItem.height/2,
                Math.min(root.iconItem.width, root.iconItem.height));
        }

        application.setMinimizedDelegate(root);
        MobileShell.AppLaunch.launchOrActivateApp(application.storageId);
    }

    onAfterClickAnimation: {
        launchApp();
    }

    contentItem: Item {
        height: folio.FolioSettings.delegateIconSize
        width: folio.FolioSettings.delegateIconSize

        // Background for folder creation animation
        Rectangle {
            id: rect
            radius: Kirigami.Units.cornerRadius
            color: Qt.rgba(255, 255, 255, 0.3)
            anchors.fill: parent

            Component.onCompleted: {
                if (maskManager) {
                    maskManager.assignToMask(this)
                }
            }

            opacity: root.turnToFolder ? 1 : 0
            property real scaleAmount: root.turnToFolder ? 1.2 : 1.0

            Behavior on scaleAmount {
                enabled: root.turnToFolderAnimEnabled
                NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
            }
            Behavior on opacity {
                enabled: root.turnToFolderAnimEnabled
                NumberAnimation { duration: Kirigami.Units.longDuration; easing.type: Easing.InOutQuad }
            }

            transform: Scale {
                origin.x: rect.width / 2
                origin.y: rect.height / 2
                xScale: rect.scaleAmount
                yScale: rect.scaleAmount
            }
        }

        // Application icon
        DelegateAppIcon {
            id: icon
            folio: root.folio
            anchors.fill: parent
            source: root.application ? root.application.icon : ""

            property real scaleAmount: root.turnToFolder ? 0.3 : 1.0
            Behavior on scaleAmount {
                enabled: root.turnToFolderAnimEnabled
                NumberAnimation { duration: root.turnToFolderAnimEnabled ? Kirigami.Units.longDuration : 0; easing.type: Easing.InOutQuad }
            }

            transform: Scale {
                origin.x: icon.width / 2
                origin.y: icon.height / 2
                xScale: icon.scaleAmount
                yScale: icon.scaleAmount
            }

            // Badge and progress published by the application (com.canonical.Unity.LauncherEntry),
            // as on the Plasma desktop task manager
            Folio.LauncherEntry {
                id: launcherEntry
                storageId: root.application ? root.application.storageId : ""
            }

            Rectangle {
                id: badge
                visible: launcherEntry.badgeCount > 0
                anchors {
                    right: parent.right
                    top: parent.top
                    rightMargin: -width * 0.25
                    topMargin: -height * 0.25
                }
                height: Math.round(parent.height * 0.42)
                width: Math.max(height, badgeLabel.implicitWidth + height * 0.5)
                radius: height / 2
                color: launcherEntry.urgent ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.highlightColor
                border.width: 1
                border.color: Qt.rgba(0, 0, 0, 0.25)

                Controls.Label {
                    id: badgeLabel
                    anchors.centerIn: parent
                    text: launcherEntry.badgeCount > 99 ? "99+" : launcherEntry.badgeCount
                    color: Kirigami.Theme.highlightedTextColor
                    font.pixelSize: Math.round(badge.height * 0.62)
                    font.bold: true
                }
            }

            Rectangle {
                id: progressTrack
                visible: launcherEntry.progressVisible
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    leftMargin: parent.width * 0.1
                    rightMargin: parent.width * 0.1
                    bottomMargin: parent.height * 0.04
                }
                height: Math.max(3, Math.round(parent.height * 0.08))
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.45)

                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: parent.width * launcherEntry.progress
                    radius: parent.radius
                    color: Kirigami.Theme.highlightColor
                }
            }

            // Running indicator
            Rectangle {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: -Kirigami.Units.smallSpacing
                }
                visible: root.application && root.application.running
                radius: width
                width: Kirigami.Units.smallSpacing
                height: width
                color: Kirigami.Theme.highlightColor
            }
        }
    }
}
