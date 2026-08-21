import QtQuick
import "../state"
import "../logic"
import "../shared"
import "../shared/Utils.js" as Utils
import Omafiles.Backend as Backend
import qs.Commons
import qs.Ui

// Parent column (the yazi idea): a read-only listing of the folder ABOVE the
// current one, with the folder you are standing in highlighted. Gives you
// continuous context while moving with h/l -- what you left, what is next to
// it, what you could jump to sideways -- without leaving where you are.
//
// Deliberately NOT a panel/tab. Panels here are independent workspaces with
// their own path and history, and hovering one makes it active
// (BackgroundPanel's HoverHandler -> switchToTab). A parent column must never
// do that: it is context, not a workspace. So it lives INSIDE the active
// panel, next to the file list, exactly the way PreviewPanel does -- which
// also means it costs no changes to panelsRow slot maths, TabsState, tab
// cycling or session persistence.
//
// It never takes keyboard focus: clicks navigate, everything else belongs to
// the list on the right.
Item {
  id: parentCol

  property Item hostNavController: null
  property Item hostFileMeta: null
  // Path whose PARENT is being listed (the active panel's folder).
  property string currentPath: NavState.currentPath
  // Stance/context gates. They default to the ACTIVE pane's globals, so the
  // MainLayout use is unchanged -- BackgroundPanel overrides them with its
  // tab's saved state, because per-pane yazi mode means a background pane
  // keeps its own parent column instead of the columns following focus.
  property bool openFlag: NavState.parentColumnOpen
  property bool inArchive: ArchiveState.inArchive

  // The folder we are inside, i.e. the row to highlight in the parent listing.
  readonly property string currentName: {
    var p = String(currentPath || "")
    var idx = p.lastIndexOf("/")
    return idx >= 0 ? p.substring(idx + 1) : ""
  }

  readonly property string parentPath: {
    var p = String(currentPath || "")
    if (p === "/" || p.length === 0) return ""
    var idx = p.lastIndexOf("/")
    return idx > 0 ? p.substring(0, idx) : "/"
  }

  // Cases where a parent column would be wrong rather than merely empty:
  //   - at "/" there is nothing above
  //   - inside an archive currentPath does not move, so the "parent" would be
  //     the archive's folder while the list shows archive members: a lie
  //   - the trash view aggregates several roots; it has no single parent
  readonly property bool applicable: parentPath !== ""
    && !inArchive
    && currentPath !== Paths.trashDir
    && currentPath !== Paths.recentsDir

  readonly property bool shown: openFlag && applicable

  DirLister {
    id: parentLister
    // Follow the panel's hidden setting, EXCEPT when the folder we are
    // standing in is itself hidden: a parent column that cannot show your own
    // position is worse than a slightly noisier one. Without this, standing in
    // ~/.config with hidden files off left nothing highlighted at all.
    showHidden: NavState.showHidden || parentCol.currentName.indexOf(".") === 0
    onListed: parentCol._syncHighlight()
  }

  function reload() {
    if (!shown) return
    parentLister.list(parentPath)
  }

  function _syncHighlight() {
    for (var i = 0; i < parentLister.entries.length; i++) {
      if (parentLister.entries[i].name === parentCol.currentName) {
        parentList.positionViewAtIndex(i, ListView.Contain)
        return
      }
    }
  }

  onShownChanged: reload()
  onParentPathChanged: reload()
  Connections {
    target: NavState
    function onShowHiddenChanged() { parentCol.reload() }
  }
  Component.onCompleted: reload()

  clip: true

  ListView {
    id: parentList
    anchors.fill: parent
    // Line up with the file list on the right, which starts below its own
    // separator (1px) plus Style.spacing.md. Without this the two columns
    // began at different heights and every row was off by a few pixels.
    anchors.topMargin: Style.spacing.md + 1
    model: parentCol.shown ? parentLister.entries : []
    // Context only: the keyboard belongs to the file list on the right.
    interactive: true
    focus: false
    boundsBehavior: Flickable.StopAtBounds
    spacing: 0

    // CursorSurface is what the real file rows use, so hover/current here get
    // the same fill, radius and border treatment as everywhere else rather
    // than a hand-rolled rectangle that would drift from the theme.
    delegate: CursorSurface {
      id: parentRow
      required property var modelData
      width: parentList.width
      // Same height formula as FileListRow — FileRowVisual reserves a fixed
      // name+subtitle height whether or not a subtitle is shown, so the rows
      // align 1:1 with the list on the right even though this column hides
      // the meta line. controlHeight (the old value) made them shorter and
      // the two columns drifted apart down the page.
      height: parentRowVisual.implicitHeight
        + (NavState.compactMode ? Style.spacing.xs : Style.spacing.md) * 2
      current: parentRow.isCurrent
      hasCursor: parentRowMouse.containsMouse

      readonly property bool isCurrent: modelData.name === parentCol.currentName

      // Folder item counts arrive from an async cache that only fills for rows
      // that ASK. Without this the folders here would show their age but never
      // "N items", unless the same folder happened to be visible in the main
      // list too.
      readonly property string _rowPath: Utils.joinPath(parentCol.parentPath, modelData.name || "")
      Component.onCompleted: {
        if (!NavState.needsFolderCounts) return   // count not drawn, no walk
        if (modelData.type === "dir" && FolderCountState.needsRequest(_rowPath)) {
          FolderCountState.markPending(_rowPath)
          Backend.FolderCounter.request(_rowPath, NavState.showHidden)
        }
      }

      FileRowVisual {
        id: parentRowVisual
        anchors.fill: parent
        anchors.leftMargin: Style.spacing.controlGap
        anchors.rightMargin: Style.spacing.controlGap
        name: parentRow.modelData.name || ""
        isDir: parentRow.modelData.type === "dir"
        isSymlink: parentRow.modelData.isSymlink === true
        compact: NavState.compactMode
        isBroken: parentRow.modelData.link === "broken"
        highlighted: parentRow.isCurrent
        fileIconGlyph: Utils.iconFor(parentRow.modelData)
        // Same subtitle as the main list — item count for folders, size for
        // files, both with age. FileRowVisual reserves the second line either
        // way, so showing it costs no height and the columns stay aligned.
        metaText: parentCol.hostFileMeta
          ? parentCol.hostFileMeta.lineFor(parentRow.modelData, parentCol.parentPath) : ""
      }

      MouseArea {
        id: parentRowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // Single click, not double: this column is a jump target, and the row
        // you want is usually the sibling folder you can already see.
        onClicked: {
          if (!parentCol.hostNavController) return
          if (parentRow.modelData.type === "dir")
            parentCol.hostNavController.navigateTo(Utils.joinPath(parentCol.parentPath, parentRow.modelData.name))
          else
            parentCol.hostNavController.navigateTo(parentCol.parentPath)
        }
      }
    }
  }
}
