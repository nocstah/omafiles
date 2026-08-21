import QtQuick
import qs.Commons
import qs.Ui
import "../shared/Utils.js" as Utils

// Sidebar recent section.
Column {
  id: root

  property var recentFiles: []
  property var iconForBookmark: null
  property var openContextMenu: null
  property Item positionRelativeTo: null

  signal recentOpened(var item)
  signal recentLaunched(var item)
  signal recentRemoveRequested(string path)
  signal recentClearRequested()
  // Header click: jump into the full Recents view (Paths.recentsDir).
  signal recentsViewRequested()

  width: parent ? parent.width : 0
  spacing: Style.spacing.md

  Item {
    visible: root.recentFiles.length > 0
    width: 1
    height: Style.spacing.sm
  }

  PanelSeparator {
    visible: root.recentFiles.length > 0
    foreground: Color.menu.text
    strength: 0.15
  }

  Item {
    visible: root.recentFiles.length > 0
    width: 1
    height: Style.spacing.xs
  }

  PanelSectionHeader {
    visible: root.recentFiles.length > 0
    text: "RECENT"
    foreground: Color.menu.text
    fontFamily: Style.font.family
    fontSize: Style.font.subtitle

    // The header is a DOOR, not just a label: clicking it opens the full
    // Recents view in the active pane -- the sidebar only ever shows the
    // first few entries, the view goes back hundreds.
    MouseArea {
      anchors.fill: parent
      anchors.margins: -Style.spacing.xxs
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.recentsViewRequested()
    }
  }

  Item {
    visible: root.recentFiles.length > 0
    width: 1
    height: Style.spacing.xxs
  }

  Repeater {
    // Only a teaser here -- the full history lives in the Recents view.
    model: root.recentFiles.slice(0, 8)

    CursorSurface {
      OpacityAnimator on opacity { from: 0; to: 1; duration: 120; easing.type: Easing.OutCubic }
      required property var modelData
      width: root.width
      implicitHeight: Style.spacing.controlHeight
      foreground: Color.menu.text
      accent: Color.accent
      hasCursor: recentMouse.containsMouse
      Accessible.role: Accessible.ListItem
      Accessible.name: "Recent file, " + modelData.name

      OpticalGlyph {
        id: recentIcon
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Style.spacing.sm
        width: Style.font.title
        height: Style.font.title
        text: Utils.iconFor({ type: "file", name: parent.modelData.name })
        fontFamily: Style.font.family
        fontSize: Style.font.icon
        color: Color.menu.text
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: recentIcon.right
        anchors.leftMargin: Style.spacing.xs
        text: parent.modelData.name
        font.pixelSize: Style.font.title
        font.family: Style.font.family
        font.weight: Font.Medium
        color: Color.menu.text
        elide: Text.ElideRight
        width: root.width - Style.spacing.sm * 2 - recentIcon.width - Style.spacing.xs
      }

      MouseArea {
        id: recentMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: function (mouse) {
          if (mouse.button === Qt.RightButton) {
            var pos = mapToItem(root.positionRelativeTo, mouse.x, mouse.y)
            if (root.openContextMenu) {
              root.openContextMenu(pos.x, pos.y, [
                { label: "Open", action: function () { root.recentOpened(modelData) } },
                { label: "Remove from recent", destructive: true, action: function () { root.recentRemoveRequested(modelData.path) } },
                { label: "Clear recent", destructive: true, action: function () { root.recentClearRequested() } }
              ])
            }
            return
          }
          root.recentOpened(modelData)
        }
        onDoubleClicked: root.recentLaunched(modelData)
      }
    }
  }
}
