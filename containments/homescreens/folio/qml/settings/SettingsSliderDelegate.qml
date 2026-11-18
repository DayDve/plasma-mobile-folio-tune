// SPDX-FileCopyrightText: 2026 DayDve <daydve@smbit.pro>
// SPDX-License-Identifier: GPL-2.0-or-later

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard

// A number setting made for fingers: a slider across the whole row, with buttons
// for single steps. Takes the same properties as FormCard.FormSpinBoxDelegate.
// The value changes when the slider is released, not on every step of the drag:
// each change lays out the homescreen again.
FormCard.AbstractFormDelegate {
    id: root

    property string label
    property int from: 0
    property int to: 99
    property int stepSize: 1
    property int value: 0

    // The buttons show characters: the "list-remove" icon of Breeze is a red cross, and
    // its "value-decrease" does not match "value-increase" in weight or position.
    readonly property real buttonSize: Kirigami.Units.gridUnit * 3

    function setClamped(newValue: int): void {
        root.value = Math.max(root.from, Math.min(root.to, newValue));
    }

    background: null
    hoverEnabled: false
    focusPolicy: Qt.NoFocus

    contentItem: ColumnLayout {
        spacing: 0

        RowLayout {
            Layout.fillWidth: true

            QQC2.Label {
                Layout.fillWidth: true
                text: root.label
                elide: Text.ElideRight
            }

            QQC2.Label {
                text: slider.pressed ? Math.round(slider.value) : root.value
                font.bold: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            QQC2.ToolButton {
                Layout.preferredWidth: root.buttonSize
                Layout.preferredHeight: root.buttonSize
                text: "−"
                font.pixelSize: Kirigami.Units.gridUnit * 1.5
                enabled: root.value > root.from
                autoRepeat: true
                onClicked: root.setClamped(root.value - root.stepSize)
            }

            QQC2.Slider {
                id: slider
                Layout.fillWidth: true
                Layout.preferredHeight: root.buttonSize
                from: root.from
                to: root.to
                stepSize: root.stepSize
                snapMode: QQC2.Slider.SnapAlways
                onPressedChanged: {
                    if (!pressed) {
                        root.setClamped(Math.round(value));
                    }
                }

                Binding on value {
                    when: !slider.pressed
                    value: root.value
                    restoreMode: Binding.RestoreNone
                }
            }

            QQC2.ToolButton {
                Layout.preferredWidth: root.buttonSize
                Layout.preferredHeight: root.buttonSize
                text: "+"
                font.pixelSize: Kirigami.Units.gridUnit * 1.5
                enabled: root.value < root.to
                autoRepeat: true
                onClicked: root.setClamped(root.value + root.stepSize)
            }
        }
    }
}
