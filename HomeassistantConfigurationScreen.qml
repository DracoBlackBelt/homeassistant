import QtQuick 2.1
import qb.components 1.0

Screen {
    id: homeAssistantConfigurationScreen

    screenTitle: qsTr("Home Assistant Configuratie")
    hasBackButton: true

    // --- layout metrics, branch on hardware (isNxt = Toon 2/NXT) ---
    property int edge: isNxt ? 20 : 8
    property int rowH: isNxt ? 36 : 26
    property int rowGap: isNxt ? 6 : 4
    property int fieldH: isNxt ? 35 : 24
    property int wideFieldW: isNxt ? 560 : 268
    property int halfFieldW: isNxt ? 295 : 190
    property int toggleBlockW: isNxt ? 200 : 105

    // --- drafts: edited here, only pushed to the app on "Opslaan" ---
    property string draftServer: ""
    property string draftPort: ""
    property string draftSsl: "no"
    property int draftClock: 0
    property var draftSensors: ["", "", "", "", "", "", "", ""]
    property var draftSwitches: ["", "", "", "", ""]
    property var draftScenes: ["", "", "", ""]
    property string draftAlarmEntity: ""
    property string draftAlarmCode: ""

    // 0 = sensors, 1 = scenes, 2 = switches, 3 = alarm
    property int page: 0

    function storeSensor(index, text) {
        var a = draftSensors.slice();
        a[index] = text.trim();
        draftSensors = a;
    }

    function storeSwitch(index, text) {
        var a = draftSwitches.slice();
        a[index] = text.trim();
        draftSwitches = a;
    }

    function storeScene(index, text) {
        var a = draftScenes.slice();
        a[index] = text.trim();
        draftScenes = a;
    }

    function validatePort(text, isFinal) {
        if (isFinal && !/^[0-9]*$/.test(text)) {
            return {content: qsTr("Poortnummer onjuist")};
        }
        return null;
    }

    onShown: {
        addCustomTopRightButton(qsTr("Opslaan"));

        draftServer = app.homeAssistantServer;
        draftPort = app.homeAssistantPort;
        draftSsl = app.homeAssistantSSL;
        draftClock = app.clockTile;
        draftSensors = app.sensorEntities.slice();
        draftSwitches = app.switchEntities.slice();
        draftScenes = app.sceneEntities.slice();
        draftAlarmEntity = app.alarmEntity;
        draftAlarmCode = app.alarmCode;
        page = 0;
    }

    onCustomButtonClicked: {
        app.saveConfiguration(draftServer, draftPort, draftSsl, draftClock,
                              draftSensors, draftSwitches, draftScenes,
                              draftAlarmEntity, draftAlarmCode);
        hide();
    }

    //
    // Connection block (always visible)
    //

    Rectangle {
        id: connectionGrid
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: edge
            rightMargin: edge
            topMargin: rowGap + 4
        }
        height: 2 * (rowH + rowGap)
        color: "transparent"

        EditTextLabel4421 {
            id: serverField
            width: wideFieldW
            height: rowH
            leftTextAvailableWidth: isNxt ? 250 : 110
            leftText: qsTr("Server IP:")
            inputText: draftServer

            onClicked: {
                qkeyboard.open(qsTr("Voer het adres van Home Assistant in"), serverField.inputText,
                               function (text) { draftServer = text.trim(); });
            }
        }

        ToggleBlock {
            anchors {
                top: serverField.top
                left: serverField.right
                leftMargin: edge
            }
            width: toggleBlockW
            height: rowH
            labelText: qsTr("SSL")
            checked: draftSsl == "yes"
            onToggled: draftSsl = (draftSsl == "yes") ? "no" : "yes"
        }

        EditTextLabel4421 {
            id: portField
            anchors {
                top: serverField.bottom
                topMargin: rowGap
            }
            width: wideFieldW
            height: rowH
            leftTextAvailableWidth: isNxt ? 250 : 110
            leftText: qsTr("Poort:")
            inputText: draftPort

            onClicked: {
                qnumKeyboard.open(qsTr("Voer het poortnummer van Home Assistant in"), portField.inputText, "", 1,
                                  function (text) { draftPort = text.trim(); }, validatePort);
                qnumKeyboard.maxTextLength = 4;
                qnumKeyboard.state = "num_integer_clear_backspace";
            }
        }

        ToggleBlock {
            anchors {
                top: portField.top
                left: portField.right
                leftMargin: edge
            }
            width: toggleBlockW
            height: rowH
            labelText: qsTr("Klok op tegel")
            checked: draftClock ? true : false
            onToggled: draftClock = draftClock ? 0 : 1
        }
    }

    //
    // Paged entity config panels
    //

    Rectangle {
        id: configPanel
        anchors {
            left: parent.left
            right: parent.right
            top: connectionGrid.bottom
            bottom: navBar.top
            leftMargin: edge
            rightMargin: edge
            topMargin: rowGap
            bottomMargin: rowGap
        }
        radius: 10
        color: "#e8e8e8"
        clip: true

        Text {
            id: panelTitle
            x: 20
            y: 8
            text: page == 0 ? qsTr("Sensoren") : (page == 1 ? qsTr("Scenes") : (page == 2 ? qsTr("Schakelaars") : qsTr("Alarm")))
            font.pixelSize: isNxt ? 14 : 10
            font.family: qfont.semiBold.name
            color: "Black"
        }

        // page 0: 8 sensors in two columns of 4
        Item {
            id: sensorsPage
            anchors.fill: parent
            visible: page == 0

            Repeater {
                model: 2
                delegate: Column {
                    property int column: index
                    x: column == 0 ? 20 : 20 + halfFieldW + edge
                    y: panelTitle.y + panelTitle.height + rowGap
                    spacing: rowGap

                    Repeater {
                        model: 4
                        delegate: EditTextLabel4421 {
                            property int slot: column * 4 + index
                            width: halfFieldW
                            height: fieldH
                            leftTextAvailableWidth: 30
                            leftText: (slot + 1) + ":"
                            inputText: draftSensors[slot]

                            onClicked: {
                                qkeyboard.open(qsTr("Voer de entity-id in voor de sensor"), inputText,
                                               function (text) { homeAssistantConfigurationScreen.storeSensor(slot, text); });
                            }
                        }
                    }
                }
            }
        }

        // page 1: 4 scenes in one column
        Item {
            id: scenesPage
            anchors.fill: parent
            visible: page == 1

            Column {
                x: 20
                y: panelTitle.y + panelTitle.height + rowGap
                spacing: rowGap

                Repeater {
                    model: 4
                    delegate: EditTextLabel4421 {
                        width: parent.parent.width - 40
                        height: fieldH
                        leftTextAvailableWidth: 30
                        leftText: (index + 1) + ":"
                        inputText: draftScenes[index]

                        onClicked: {
                            qkeyboard.open(qsTr("Voer de entity-id in voor de scene"), inputText,
                                           function (text) { homeAssistantConfigurationScreen.storeScene(index, text); });
                        }
                    }
                }
            }
        }

        // page 2: 5 switches in two columns (3 + 2)
        Item {
            id: switchesPage
            anchors.fill: parent
            visible: page == 2

            Repeater {
                model: 2
                delegate: Column {
                    property int column: index
                    x: column == 0 ? 20 : 20 + halfFieldW + edge
                    y: panelTitle.y + panelTitle.height + rowGap
                    spacing: rowGap

                    Repeater {
                        model: column == 0 ? 3 : 2
                        delegate: EditTextLabel4421 {
                            property int slot: column * 3 + index
                            width: halfFieldW
                            height: fieldH
                            leftTextAvailableWidth: 30
                            leftText: (slot + 1) + ":"
                            inputText: draftSwitches[slot]

                            onClicked: {
                                qkeyboard.open(qsTr("Voer de entity-id in voor de schakelaar"), inputText,
                                               function (text) { homeAssistantConfigurationScreen.storeSwitch(slot, text); });
                            }
                        }
                    }
                }
            }
        }

        // page 3: alarm entity + code
        Item {
            id: alarmPage
            anchors.fill: parent
            visible: page == 3

            Column {
                x: 20
                y: panelTitle.y + panelTitle.height + rowGap
                width: alarmPage.width - 40
                spacing: rowGap

                EditTextLabel4421 {
                    width: parent.width
                    height: fieldH
                    leftTextAvailableWidth: isNxt ? 300 : 130
                    leftText: qsTr("Alarm entity-id:")
                    inputText: draftAlarmEntity

                    onClicked: {
                        qkeyboard.open(qsTr("Voer de entity-id in voor het alarm"), inputText,
                                       function (text) { draftAlarmEntity = text.trim(); });
                    }
                }

                EditTextLabel4421 {
                    width: parent.width
                    height: fieldH
                    leftTextAvailableWidth: isNxt ? 300 : 130
                    leftText: qsTr("Vaste code voor scherpstellen:")
                    inputText: draftAlarmCode != "" ? "*****" : ""

                    onClicked: {
                        qkeyboard.open(qsTr("Voer de code voor het alarm in"), "",
                                       function (text) { draftAlarmCode = text; });
                    }
                }
            }
        }
    }

    //
    // Page navigation
    //

    Row {
        id: navBar
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: rowGap
        }
        spacing: edge

        Image {
            width: 18
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            source: "drawables/navArrow-left.png"
            smooth: true

            MouseArea {
                anchors.fill: parent
                onClicked: homeAssistantConfigurationScreen.page = (homeAssistantConfigurationScreen.page + 3) % 4;
            }
        }

        Image {
            width: 100
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            source: "drawables/page" + (homeAssistantConfigurationScreen.page + 1) + ".png"
            smooth: true
        }

        Image {
            width: 18
            height: 28
            anchors.verticalCenter: parent.verticalCenter
            source: "drawables/navArrow-right.png"
            smooth: true

            MouseArea {
                anchors.fill: parent
                onClicked: homeAssistantConfigurationScreen.page = (homeAssistantConfigurationScreen.page + 1) % 4;
            }
        }
    }
}
