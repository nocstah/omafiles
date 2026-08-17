import QtQuick
import qs.Commons

// Shared visual chrome for keyboard-and-mouse-navigable items inside a panel.
// Contract: items must NOT read `containsMouse` for color/border. Mouse
// hover updates the panel's cursor state at the root; visuals derive from
// `hasCursor` / `current`. That's what guarantees a single highlight on
// screen at any time across both keyboard and mouse interaction.
//
// Cursor paint is always the shared hover-cursor fill plus optional
// hover-cursor border. `outline` remains as a compatibility flag for
// callers that used to request border-only rows, but slider rows still
// receive the same hover-cursor background as every other row.
BorderSurface {
  id: root

  property bool hasCursor: false
  property bool current: false
  property bool outline: false
  property bool bordered: false

  property color foreground: Color.foreground
  property color accent: Color.accent
  property color fill: Style.hoverFillFor(foreground, accent)
  property color currentFill: Style.selectedFillFor(foreground, accent)

  // Selector shape. Default stays Style.cornerRadius (which mirrors
  // Hyprland's decoration:rounding, so 4px here — visually square). A theme
  // can ask for stadium/pill selectors instead with, in shell.toml:
  //     [controls]
  //     cursor-shape = "pill"
  // Driven by a token rather than hardcoded so it stays a theme decision and
  // reverts cleanly by removing the line.
  // Selector shape, theme-driven. In shell.toml:
  //     [controls]
  //     cursor-shape = "pill"   -> stadium (radius = half the row height)
  //     cursor-shape = "8"      -> any explicit radius in px
  //   (absent)                  -> Style.cornerRadius, which mirrors
  //                               Hyprland's decoration:rounding
  // A dial rather than a switch: "pill" on full-width rows makes a multi-row
  // selection scallop into itself, which a mid radius avoids while still
  // looking rounded.
  readonly property string _cursorShape: Style.styleString("cursor-shape", "")
  radius: _cursorShape === "pill"
    ? Math.round(height / 2)
    : (isFinite(Number(_cursorShape)) && _cursorShape !== ""
        ? Number(_cursorShape)
        : Style.cornerRadius)

  color: hasCursor ? fill : (current ? currentFill : "transparent")
  borderSpec: root.hasCursor
    ? Border.controlSpec("hover-cursor", root.foreground, root.accent)
    : (root.current
      ? Border.controlSpec("selected", root.foreground, root.accent)
      : (root.bordered
        ? Border.controlSpec("normal", root.foreground, root.accent)
        : Border.none()))

  Behavior on color {
    ColorAnimation { duration: 60 }
  }
}
