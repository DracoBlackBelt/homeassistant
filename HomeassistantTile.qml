import QtQuick 2.1
import qb.components 1.0

/*
 * Home screen tile: optional clock + first 3 configured sensors.
 * Fixed in this rewrite (upstream had operator-precedence bugs):
 *   font.pixelSize: X - isNxt ? 5 : 4   ->  X - (isNxt ? 5 : 4)
 *   width: tileGrid.width - isNxt ? 50 : 40 -> tileGrid.width - (isNxt ? 50 : 40)
 */
Tile {
    id: homeAssistantTile

    function init() {}

    onClicked: {
        if (app.homeAssistantScreen) {
            app.homeAssistantScreen.show();
        }
    }

    Text {
        id: txtTimeBig
        text: app.timeStr
        color: (typeof dimmableColors !== 'undefined') ? dimmableColors.clockTileColor : colors.clockTileColor
        anchors {
            left: parent.left
            leftMargin: 10
            baseline: parent.top
            baselineOffset: isNxt ? 67 : 54
        }
        font {
            family: qfont.regular.name
            pixelSize: dimState ? qfont.clockFaceText : qfont.timeAndTemperatureText - (isNxt ? 5 : 4)
        }
        visible: app.clockTile ? true : false
    }

    Text {
        id: txtDate
        text: app.dateStr
        color: (typeof dimmableColors !== 'undefined') ? dimmableColors.clockTileColor : colors.clockTileColor
        anchors {
            left: txtTimeBig.left
            top: txtTimeBig.bottom
            topMargin: -10
        }
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: qfont.tileTitle - 2
        font.family: qfont.regular.name
        visible: app.clockTile ? !dimState : false
    }

    Image {
        id: homeAssistantIconSmall
        source: "drawables/homeAssistantIconSmall.png"
        anchors {
            bottom: txtDate.bottom
            right: parent.right
            rightMargin: 10
        }
        cache: false
        visible: app.clockTile ? !dimState : false
    }

    Image {
        id: homeAssistantIconSmallCenter
        source: dimState ? "drawables/homeAssistantIconSmallDim.png" : "drawables/homeAssistantIconSmall.png"
        anchors {
            baseline: parent.top
            horizontalCenter: parent.horizontalCenter
            baselineOffset: isNxt ? 19 : 15
        }
        cache: false
        visible: app.clockTile ? false : true
    }

    Column {
        id: tileGrid
        width: parent.width - 20
        anchors {
            bottom: parent.bottom
            left: parent.left
            bottomMargin: 10
            leftMargin: 10
        }

        Repeater {
            model: 3
            delegate: Item {
                width: tileGrid.width
                height: active ? (isNxt ? 25 : 20) : 0
                visible: active
                readonly property bool active: app.sensorEntity(index) != ""

                Text {
                    anchors {
                        left: parent.left
                        right: tileSensorValue.left
                        verticalCenter: parent.verticalCenter
                        rightMargin: 6
                    }
                    text: app.sensorName(index)
                    elide: Text.ElideRight
                    color: (typeof dimmableColors !== 'undefined') ? dimmableColors.clockTileColor : colors.clockTileColor
                    font.pixelSize: isNxt ? 15 : 12
                    font.family: qfont.regular.name
                    font.bold: true
                }

                Text {
                    id: tileSensorValue
                    width: isNxt ? 110 : 75
                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: app.sensorValue(index)
                    elide: Text.ElideLeft
                    color: (typeof dimmableColors !== 'undefined') ? dimmableColors.clockTileColor : colors.clockTileColor
                    font.pixelSize: isNxt ? 15 : 12
                    font.family: qfont.regular.name
                    font.bold: true
                }
            }
        }
    }
}
