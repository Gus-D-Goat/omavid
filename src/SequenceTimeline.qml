import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Format.js" as Format

// The clip sequence: a horizontally scrolling row of blocks in playlist order.
// Click a block to select it, drag left/right to reorder, and use the action row
// for the selected clip. Precise trimming still happens in the TrimBar.
Item {
    id: root
    implicitHeight: 168

    property var model: null
    property int clipCount: 0
    property int currentIndex: -1
    property bool currentClipHasAudio: false
    property bool canCut: false
    property bool busy: false
    property color accent: "#FFD60A"
    property color accentForeground: "black"

    readonly property int blockWidth: 140
    readonly property int blockHeight: 76
    readonly property int blockSpacing: 6

    signal clipSelected(int index)
    signal clipMoved(int from, int to)
    signal addRequested()
    signal batchRequested()
    signal mergeRequested()
    signal attachAudioRequested(int index)
    signal detachAudioRequested(int index)
    signal duplicateRequested(int index)
    signal cutRequested()
    signal removeRequested(int index)

    component SmallButton: Button {
        font.pixelSize: 11
        implicitHeight: 28
        leftPadding: 10
        rightPadding: 10
        topPadding: 4
        bottomPadding: 4
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: "#141416"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        // --- toolbar ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                text: "Timeline · " + root.clipCount
                    + (root.clipCount === 1 ? " clip" : " clips")
                color: "#d6d6da"
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            SmallButton {
                text: "Add videos"
                onClicked: root.addRequested()
            }
            SmallButton {
                text: "Batch export"
                highlighted: true
                Material.foreground: root.accentForeground
                enabled: root.clipCount >= 1 && !root.busy
                onClicked: root.batchRequested()
            }
            SmallButton {
                text: "Merge"
                enabled: root.clipCount >= 2 && !root.busy
                onClicked: root.mergeRequested()
            }
        }

        // --- selected clip actions ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.currentIndex >= 0

            Label {
                text: "Clip " + (root.currentIndex + 1)
                color: root.accent
                font.pixelSize: 11
                font.family: "monospace"
            }
            SmallButton {
                text: "←"
                enabled: root.currentIndex > 0 && !root.busy
                onClicked: root.clipMoved(root.currentIndex, root.currentIndex - 1)
            }
            SmallButton {
                text: "→"
                enabled: root.currentIndex < root.clipCount - 1 && !root.busy
                onClicked: root.clipMoved(root.currentIndex, root.currentIndex + 1)
            }
            SmallButton {
                text: root.currentClipHasAudio ? "Remove audio" : "Attach audio"
                enabled: !root.busy
                onClicked: {
                    if (root.currentClipHasAudio)
                        root.detachAudioRequested(root.currentIndex);
                    else
                        root.attachAudioRequested(root.currentIndex);
                }
            }
            SmallButton {
                text: "Duplicate"
                enabled: !root.busy
                onClicked: root.duplicateRequested(root.currentIndex)
            }
            SmallButton {
                text: "Cut"
                enabled: root.canCut && !root.busy
                onClicked: root.cutRequested()
            }
            SmallButton {
                text: "Remove"
                enabled: !root.busy
                onClicked: root.removeRequested(root.currentIndex)
            }
            Item { Layout.fillWidth: true }
        }

        // --- blocks ---
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: root.blockHeight

            ListView {
                id: timeline
                objectName: "sequenceList"
                anchors.fill: parent
                orientation: ListView.Horizontal
                model: root.model
                spacing: root.blockSpacing
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }

                Connections {
                    target: root
                    function onCurrentIndexChanged() {
                        if (root.currentIndex >= 0)
                            timeline.positionViewAtIndex(root.currentIndex, ListView.Contain);
                    }
                    function onClipCountChanged() {
                        if (root.currentIndex >= 0)
                            timeline.positionViewAtIndex(root.currentIndex, ListView.Contain);
                    }
                }

                delegate: Rectangle {
                    id: block
                    width: root.blockWidth
                    height: root.blockHeight
                    radius: 8
                    color: index === root.currentIndex ? "#2c2c2f" : "#1c1c1e"
                    border.width: 1
                    border.color: index === root.currentIndex ? root.accent : "#2a2a2e"

                    property bool dragging: false
                    opacity: dragging ? 0.55 : 1.0

                    Column {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 3

                        Label {
                            text: (index + 1) + "."
                            color: index === root.currentIndex ? root.accent : "#7a7a80"
                            font.pixelSize: 9
                            font.family: "monospace"
                        }
                        Label {
                            width: parent.width
                            text: model.name
                            color: "white"
                            elide: Text.ElideRight
                            font.pixelSize: 11
                        }
                        Label {
                            width: parent.width
                            text: model.trimmed
                                ? Format.fmt(model.startSec) + " – " + Format.fmt(model.endSec)
                                : Format.fmt(model.duration)
                            color: model.trimmed ? root.accent : "#9a9aa0"
                            elide: Text.ElideRight
                            font.pixelSize: 9
                            font.family: "monospace"
                        }
                        Label {
                            width: parent.width
                            visible: model.hasAudio
                            text: "♪ " + model.audioName
                            color: root.accent
                            elide: Text.ElideRight
                            font.pixelSize: 9
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        property real pressX: 0
                        property bool moved: false

                        onPressed: (mouse) => {
                            pressX = mouse.x;
                            moved = false;
                        }
                        onPositionChanged: (mouse) => {
                            if (Math.abs(mouse.x - pressX) > 8)
                                moved = true;
                            block.dragging = moved;
                        }
                        onReleased: (mouse) => {
                            block.dragging = false;
                            if (!moved) {
                                root.clipSelected(index);
                                return;
                            }
                            // Map the pointer into the scrolled content so the
                            // target index follows the block under the cursor.
                            var pt = mapToItem(timeline.contentItem, mouse.x, mouse.y);
                            var stride = root.blockWidth + root.blockSpacing;
                            var target = Math.floor(pt.x / stride);
                            target = Math.max(0, Math.min(target, root.clipCount - 1));
                            if (target !== index)
                                root.clipMoved(index, target);
                        }
                        onCanceled: block.dragging = false
                    }
                }
            }
        }
    }
}
