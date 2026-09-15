import QtQuick 2.1

Item {
    id: toggleBlock

    width: 200
    height: 36

    property string labelText: ""
    property bool checked: false
    property int labelFont: isNxt ? 12 : 9

    signal toggled()

    Text {
        id: blockLabel
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: isNxt ? 20 : 4
        }
        width: parent.width - (isNxt ? 20 : 4) - blockSwitch.width - 8
        text: labelText
        font.pixelSize: labelFont
        elide: Text.ElideRight
        color: "Black"
        wrapMode: Text.WordWrap
    }

    ToggleSwitch {
        id: blockSwitch
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        width: isNxt ? 54 : 40
        height: isNxt ? 36 : 24
        checked: toggleBlock.checked
        onToggled: toggleBlock.toggled()
    }

    MouseArea {
        anchors.fill: parent
        onClicked: toggleBlock.toggled()
    }
}
