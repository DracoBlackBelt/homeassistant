import QtQuick 2.1
import qb.components 1.0

Screen {
    id: homeAssistantScreen

    screenTitle: "Home Assistant"
    hasBackButton: true

    // --- layout metrics, branch on hardware (isNxt = Toon 2/NXT) ---
    property int pad: isNxt ? 30 : 12
    property int gap: isNxt ? 10 : 4
    property int titleFont: isNxt ? 16 : 10
    property int bodyFont: isNxt ? 12 : 9
    property int sensorRowH: isNxt ? 19 : 15
    property int switchRowH: isNxt ? 50 : 30
    property int sceneBtnW: isNxt ? 120 : 62
    property int sceneBtnH: isNxt ? 75 : 38
    property int dialSize: isNxt ? 50 : 28
    property color cardColor: "#e8e8e8"
    property color textColor: "Black"

    onShown: {
        addCustomTopRightButton(qsTr("Instellingen"));
        app.refreshNow();
        app.logShown = false;
    }

    onCustomButtonClicked: {
        if (app.homeAssistantConfigurationScreen) {
            app.homeAssistantConfigurationScreen.show();
        }
    }

    //
    // Top: sensors (2 columns of 4) + HA logo (tap = manual refresh)
    //

    Rectangle {
        id: sensorRect
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: pad
            rightMargin: pad
            topMargin: gap
        }
        height: sensorRows.height + 2 * gap
        radius: 10
        color: cardColor

        Column {
            id: sensorRows
            spacing: 0
            anchors {
                left: parent.left
                right: logoImage.left
                verticalCenter: parent.verticalCenter
                leftMargin: gap + 10
                rightMargin: gap
            }

            Repeater {
                model: 4
                delegate: Row {
                    width: sensorRows.width
                    spacing: pad

                    Repeater {
                        model: [index, index + 4]
                        delegate: Item {
                            readonly property int slot: modelData
                            width: (parent.width - parent.spacing) / 2
                            height: active ? sensorRowH : 0
                            visible: active
                            readonly property bool active: app.sensorEntity(slot) != ""

                            Text {
                                anchors {
                                    left: parent.left
                                    right: sensorValueText.left
                                    verticalCenter: parent.verticalCenter
                                    rightMargin: gap
                                }
                                text: app.sensorName(slot)
                                font.pixelSize: bodyFont
                                elide: Text.ElideRight
                                color: textColor
                            }

                            Text {
                                id: sensorValueText
                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                text: app.sensorValue(slot)
                                font.pixelSize: bodyFont
                                elide: Text.ElideLeft
                                color: textColor
                            }
                        }
                    }
                }
            }
        }

        Image {
            id: logoImage
            anchors {
                right: parent.right
                rightMargin: gap + 5
                verticalCenter: parent.verticalCenter
            }
            width: isNxt ? 100 : 60
            height: isNxt ? 100 : 60
            source: "drawables/homeAssistantIconBig.png"
            fillMode: Image.PreserveAspectFit
            cache: false

            MouseArea {
                anchors.fill: parent
                onClicked: app.refreshNow()
            }
        }
    }

    //
    // Bottom left: scenes (2x2)
    //

    Text {
        id: sceneTitle
        anchors {
            left: parent.left
            top: sensorRect.bottom
            leftMargin: pad
            topMargin: gap
        }
        text: qsTr("Scenes")
        font.pixelSize: titleFont
        font.family: qfont.semiBold.name
        color: textColor
    }

    Grid {
        id: sceneGrid
        anchors {
            left: sceneTitle.left
            top: sceneTitle.bottom
            bottom: parent.bottom
            topMargin: gap
            bottomMargin: gap
        }
        columns: 2
        spacing: gap

        Repeater {
            model: 4
            delegate: IconButton {
                width: sceneBtnW
                height: active ? sceneBtnH : 0
                visible: active
                readonly property bool active: app.sceneEntity(index) != ""
                bottomClickMargin: 3
                text: app.sceneName(index)
                onClicked: app.setEntity(app.sceneEntity(index), true)
            }
        }
    }

    //
    // Bottom middle: switches
    //

    Text {
        id: switchTitle
        anchors {
            left: sceneGrid.right
            top: sceneTitle.top
            leftMargin: pad
        }
        text: qsTr("Schakelaars")
        font.pixelSize: titleFont
        font.family: qfont.semiBold.name
        color: textColor
    }

    Column {
        id: switchColumn
        anchors {
            left: switchTitle.left
            right: alarmTitle.left
            rightMargin: pad
            top: sceneGrid.top
        }

        Repeater {
            model: 5
            delegate: Item {
                width: parent.width
                height: active ? switchRowH : 0
                visible: active
                readonly property bool active: app.switchEntity(index) != ""

                Text {
                    id: switchNameLabel
                    anchors {
                        left: parent.left
                        right: switchToggle.left
                        verticalCenter: parent.verticalCenter
                        rightMargin: gap
                    }
                    text: app.switchName(index)
                    font.pixelSize: bodyFont
                    elide: Text.ElideRight
                    color: textColor
                }

                ToggleSwitch {
                    id: switchToggle
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    width: isNxt ? 54 : 40
                    height: isNxt ? 36 : 24
                    checked: app.switchOn(index)
                    onToggled: app.setEntity(app.switchEntity(index), !checked)
                }
            }
        }
    }

    //
    // Bottom right: alarm control panel
    //

    Text {
        id: alarmTitle
        anchors {
            right: parent.right
            rightMargin: pad
            top: sceneTitle.top
        }
        text: qsTr("Alarm")
        font.pixelSize: titleFont
        font.family: qfont.semiBold.name
        color: textColor
        visible: app.alarmEntity != ""
    }

    Column {
        id: alarmColumn
        anchors {
            right: alarmTitle.right
            top: sceneGrid.top
        }
        spacing: gap
        visible: app.alarmEntity != ""

        Rectangle {
            width: dialSize * 3 + gap * 2
            height: switchRowH
            radius: 10
            color: cardColor

            Text {
                anchors.centerIn: parent
                text: app.alarmInputLabel
                font.pixelSize: bodyFont
                font.family: qfont.semiBold.name
                font.capitalization: Font.Capitalize
                color: textColor
                elide: Text.ElideRight
            }
        }

        Grid {
            columns: 3
            spacing: gap

            Repeater {
                model: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "reset", "0", "enter"]
                delegate: Item {
                    width: dialSize
                    height: dialSize

                    Image {
                        anchors.centerIn: parent
                        width: dialSize
                        height: dialSize
                        smooth: true
                        source: modelData == "reset" ? "drawables/dialpadReset.png" :
                                (modelData == "enter" ?
                                    (app.alarmState.indexOf("armed") == 0 ? "drawables/dialpadLocked.png" : "drawables/dialpadUnlocked.png") :
                                    "drawables/dialpadButton.png")

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (modelData == "reset") {
                                    app.alarmInputReset();
                                } else if (modelData == "enter") {
                                    app.alarmToggle();
                                } else {
                                    app.alarmInput(modelData);
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: modelData != "reset" && modelData != "enter"
                        text: (modelData == "enter" || modelData == "reset") ? "" : modelData
                        font.pixelSize: bodyFont + 2
                        color: "#757575"
                    }
                }
            }
        }
    }

    //
    // Debug log overlay (only ever visible when app.debug is on)
    //

    Rectangle {
        id: logRect
        z: 100
        anchors.centerIn: parent
        width: parent.width - 4 * pad
        height: parent.height > 300 ? 300 : parent.height - 4 * pad
        radius: 10
        border.color: "#9e9e9e"
        border.width: 1
        color: "#f5f5f5"
        visible: app.debug && app.logShown
        clip: true

        Text {
            x: 15
            y: 10
            width: parent.width - 30
            text: app.message
            font.pixelSize: 10
            font.family: qfont.semiBold.name
            color: "#212121"
            wrapMode: Text.WordWrap
        }

        MouseArea {
            anchors.fill: parent
            onClicked: {
                app.logShown = false;
                app.message = "";
            }
        }
    }
}
