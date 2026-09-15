import QtQuick 2.1

Item {
    id: toggle

    width: 54
    height: 36

    // Server/app-driven: bind "checked" to the authoritative state and handle
    // "toggled()" to send a command. The widget NEVER writes "checked" itself,
    // because a write from JS would destroy the binding.
    property bool checked: false

    signal toggled()

    Image {
        id: background
        anchors.fill: parent
        source: toggle.checked ? "drawables/backgroundOn.png" : "drawables/backgroundOff.png"
        fillMode: Image.Stretch
        smooth: true

        MouseArea {
            anchors.fill: parent
            onClicked: toggle.toggled()
        }
    }

    Image {
        id: knobImage
        width: toggle.height * 8 / 9
        height: toggle.height
        x: toggle.checked ? (toggle.width - width - 2) : 2
        y: 0
        source: "drawables/knob.png"
        fillMode: Image.Stretch
        smooth: true

        MouseArea {
            anchors.fill: parent
            onClicked: toggle.toggled()
        }
    }
}
