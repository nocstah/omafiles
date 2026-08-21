import QtQuick
import qs.Commons

// Small "which panel is this" chip shown at the left of every panel header
// while several panels are up. The digit is not decoration: it is the 1-9
// key that jumps straight to this panel (see KeyboardShortcuts), so the
// badge is identity and shortcut in one glyph. Accent-filled on the active
// panel, hollow and muted on the rest -- readable at a glance without
// touching the panel content at all.
Rectangle {
  id: root

  property int panelIndex: -1
  property bool isActive: false
  // Callers gate on "several panels up" through this instead of overriding
  // visible, which would clobber the 1-9 guard below.
  property bool shown: true

  // Only the panels a digit can reach get a badge; a tenth-plus panel
  // would show a key that does nothing.
  visible: shown && panelIndex >= 0 && panelIndex < 9
  width: height
  height: Math.round(Style.spacing.controlHeight * 0.62)
  radius: Math.max(3, Math.round(Style.cornerRadius / 2))
  color: isActive ? Color.accent : "transparent"
  border.width: isActive ? 0 : Style.normalBorderWidth
  border.color: Util.alpha(Color.menu.text, 0.35)

  Text {
    anchors.centerIn: parent
    text: String(root.panelIndex + 1)
    font.family: Style.font.family
    font.pixelSize: Style.font.subtitle
    font.bold: root.isActive
    color: root.isActive ? Color.menu.background : Color.menu.text
    opacity: root.isActive ? 1 : Style.emphasis.secondary
  }
}
