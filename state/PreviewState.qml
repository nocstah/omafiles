pragma Singleton
import QtQuick

// State of "viewing" a file: quick preview (Space) and the "Open with"
// selector -- seventh singleton of the state/ layer. They go together because
// both are ways of interacting with the selected item and share
// call sites (see logic/PreviewLoader.qml and core/CommandFacade.qml's
// showOpenWith()/launchWith(), corrected 2026-08-17, P2.1 follow-up --
// that logic used to live in logic/OpenWithOps.qml, folded away on
// 2026-08-15).
QtObject {
  // Third pane, on by default for the same reason the parent column is:
  // in yazi the preview is part of the layout, not a thing you summon. Space
  // still toggles it off when you want the width back.
  property bool previewOpen: true
  property bool openWithOpen: false
  property var openWithApps: []
  property var openWithEntry: null
}
