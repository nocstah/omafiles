import QtQuick
import qs.Commons
import qs.Ui
import Omafiles.Backend as Backend
import "../panels"
import "../shared"
import "../state"

// MainLayout -- main visual tree of Omafiles.
Item {
  id: mainLayout

  property Item root
  property var controllers
  property var commandFacade
  property var dialogs
  property Timer gTimer

  property alias list: list

  // Per-pane yazi mode: the sidebar is the ONE global piece of the mode, and
  // it must never flip as a side effect of hover-to-activate (mixed modes
  // plus hover focus would reflow the whole window on mouse travel). Policy:
  // the sidebar shows only while EVERY pane is plain, so it changes only on
  // an explicit Shift+P. The active pane is read live from NavState (its tab
  // object is a write-behind copy); the rest from their tab objects.
  readonly property bool anyPaneYazi: NavState.yaziMode
    || TabsState.tabs.some(function (t, i) { return i !== TabsState.activeTabIndex && t.yaziMode === true })

  BorderSurface {
    id: card
    anchors.fill: parent
    color: Color.menu.background
    borderSpec: Border.none()
    radius: Style.cornerRadius
    padding: Style.spacing.panelPadding

    Row {
      id: cardRow
      anchors.fill: parent
      anchors.topMargin: card.contentTopInset
      anchors.rightMargin: card.contentRightInset
      anchors.bottomMargin: card.contentBottomInset
      anchors.leftMargin: card.contentLeftInset
      spacing: Style.spacing.panelGap

      // ---------- Sidebar: pinned shortcuts ----------
      Sidebar {
        id: sidebar
        // Chrome, not a navigation column: it has no place in the cascade, and
        // with it up the window showed FOUR panes.
        visible: !mainLayout.anyPaneYazi
        width: mainLayout.anyPaneYazi ? 0 : 170
        height: parent.height
        bookmarks: BookmarksState.bookmarks
        recentFiles: BookmarksState.recentFiles
        mounts: MountsState.mounts
        networkMounts: MountsState.networkMounts
        currentPath: NavState.currentPath
        dropHoverPath: DropHoverState.dropHoverPath
        ejectingDevice: MountsState.ejectingDevice
        positionRelativeTo: card
        iconForBookmark: BookmarksState.iconForBookmark
        iconForMount: BookmarksState.iconForMount
        iconForNetworkMount: BookmarksState.iconForNetworkMount
        openContextMenu: commandFacade ? commandFacade.openContextMenu : null
        bookmarkActionsFor: commandFacade ? commandFacade.bookmarkActions : null
        mountActionsFor: commandFacade ? commandFacade.mountActions : null
        networkMountActionsFor: commandFacade ? commandFacade.networkMountActions : null
        onBookmarkOpened: function (bookmark) { if (commandFacade) commandFacade.openBookmark(bookmark) }
        onRecentOpened: function (item) { if (commandFacade) commandFacade.openRecent(item) }
        onRecentLaunched: function (item) { if (commandFacade) commandFacade.launchRecent(item) }
        onRecentRemoveRequested: function (path) { if (controllers) controllers.BookmarksState.removeRecent(path) }
        onRecentClearRequested: if (controllers) controllers.BookmarksState.clearRecent()
        onMountActivated: function (mount) {
          if (!mount.mounted) { if (controllers) controllers.mountOps.mountDevice(mount) }
          else { if (controllers) controllers.navController.navigateTo(mount.path) }
        }
        onMountEjectRequested: function (mount) { if (controllers) controllers.mountOps.ejectMount(mount) }
        onNetworkMountOpened: function (mount) { if (controllers) controllers.navController.navigateTo(mount.path) }
        onConnectRequested: if (controllers) controllers.mountOps.startConnectToServer()
        onFilesDropped: function (drop, destPath) { if (controllers) controllers.actionEngine.handleFilesDropped(drop, destPath) }
        onDropHoverChanged: function (path) { DropHoverState.dropHoverPath = path }
      }

      Rectangle {
        width: Style.spacing.hairline
        height: parent.height
        color: Color.menu.border
        opacity: 0.15
      }

      // ---------- Main content ----------
      Column {
        id: mainColumn
        width: parent.width - sidebar.width - 1 - parent.spacing * 2
        height: parent.height
        spacing: Style.spacing.rowGap

        Item {
          id: panelsRow
          width: parent.width
          height: parent.height
          readonly property int panelCount: TabsState.tabs.length
          readonly property real interPanelGap: 2 * Style.spacing.panelGap + Style.spacing.hairline
          readonly property real slotWidth: (panelsRow.width - (panelCount - 1) * interPanelGap) / panelCount
          function slotX(i) { return i * (panelsRow.slotWidth + panelsRow.interPanelGap) }

          // ---------- Dividers between panels ----------
          Repeater {
            model: Math.max(0, TabsState.tabs.length - 1)
            delegate: Rectangle {
              required property int index
              x: panelsRow.slotX(index) + panelsRow.slotWidth + Style.spacing.panelGap
              y: 0
              width: Style.spacing.hairline
              height: panelsRow.height
              color: Color.menu.border
              opacity: 0.15
            }
          }

          // ---------- Background panels (all tabs except the active one) ----------
          Repeater {
            model: TabsState.tabs

            BackgroundPanel {
              hostRoot: root
              hostPanelsRow: panelsRow
              hostNavController: controllers ? controllers.navController : null
              hostCommandFacade: commandFacade
              hostVideoThumbs: controllers ? controllers.videoThumbs : null
              hostDragDropOps: controllers ? controllers.actionEngine : null
              hostFileMeta: controllers ? controllers.fileMeta : null
              hostTabOps: controllers ? controllers.tabOps : null
            }
          }

          // ---------- Active panel ----------
          Item {
            id: activePanel
            x: panelsRow.slotX(TabsState.activeTabIndex)
            y: 0
            width: panelsRow.slotWidth
            height: panelsRow.height

            // The active panel is LIT rather than the inactive ones being
            // dimmed/darkened -- every treatment of the background panels
            // (opacity, grayscale, dark ground) cost readability on panels
            // that exist to be glanced at. A white wash at low alpha
            // brightens ANY theme's card (pure black included, where
            // Qt.lighter() is a no-op), so nothing ever gets harder to
            // read. Only with several panels up: a lone panel keeps the
            // stock card exactly.
            Rectangle {
              anchors.fill: parent
              visible: TabsState.tabs.length > 1
              color: Qt.rgba(1, 1, 1, 0.12)
            }

            // Hyprland-style focus frame: the same accent border the WM puts
            // around the focused window, drawn around the focused panel --
            // the one cue a Hyprland user parses without thinking. It lives
            // in the panel GAP (negative margins), so it never covers a row;
            // the radius mirrors the card's, which itself mirrors Hyprland's
            // rounding. z above the content because the gap belongs to no
            // child, and a plain Rectangle intercepts no mouse events.
            Rectangle {
              anchors.fill: parent
              anchors.margins: -Math.round(Style.spacing.panelGap / 2)
              z: 10
              visible: TabsState.tabs.length > 1
              color: "transparent"
              radius: Style.cornerRadius
              border.width: Math.max(2, Style.normalBorderWidth)
              border.color: Util.alpha(Color.accent, 0.7)
            }

        Column {
          id: activeTop
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          spacing: Style.spacing.rowGap

        Row {
          id: navRow
          width: parent.width
          height: Style.spacing.controlHeight
          spacing: Style.spacing.controlGap

          PanelIndexBadge {
            id: panelBadge
            anchors.verticalCenter: parent.verticalCenter
            shown: TabsState.tabs.length > 1
            panelIndex: TabsState.activeTabIndex
            isActive: true
          }

          PanelNavButtons {
            id: navButtons
            anchors.verticalCenter: parent.verticalCenter
            canGoBack: TabsState.navHistoryIndex > 0
            canGoForward: TabsState.navHistoryIndex < TabsState.navHistory.length - 1
            canGoUp: NavState.currentPath !== "/"
            onBackRequested: if (controllers) controllers.navController.navBack()
            onForwardRequested: if (controllers) controllers.navController.navForward()
            onUpRequested: if (controllers) controllers.navController.goUp()
          }

          Item {
            id: pathArea
            readonly property int minPathW: 120
            width: Math.max(minPathW, parent.width - navButtons.width - searchBar.width - 2 * Style.spacing.controlGap
              - (panelBadge.visible ? panelBadge.width + Style.spacing.controlGap : 0))
            height: parent.height

            MouseArea {
              anchors.fill: parent
              visible: !EditModeState.editingPath
              cursorShape: Qt.IBeamCursor
              onClicked: if (controllers) controllers.searchOps.startEditPath()
            }

            BreadcrumbSegments {
              id: breadcrumbRow
              visible: !EditModeState.editingPath
              anchors.fill: parent
              segments: commandFacade ? commandFacade.pathSegments() : []
              activePath: NavState.currentPath
            }

            PathCompletionField {
              id: pathField
              visible: EditModeState.editingPath
              anchors.fill: parent
              root: mainLayout.root
              navController: controllers ? controllers.navController : null
              list: list
            }
          }

          SearchBar {
            id: searchBar
            anchors.verticalCenter: parent.verticalCenter
            maxWidth: navRow.width - navButtons.width - pathArea.minPathW - 2 * Style.spacing.controlGap
            list: list
            searchOps: controllers ? controllers.searchOps : null
            navController: controllers ? controllers.navController : null
          }
        }

        ActivePanelInputRows {
          id: activeInputRows
          root: mainLayout.root
          list: list
          conflictActions: controllers ? controllers.actionEngine : null
        }

        Item {
          id: listContainer
          width: parent.width
          height: activePanel.height - navRow.height
            - (EditModeState.creatingFolder || EditModeState.creatingFile ? activeInputRows.height + mainColumn.spacing : 0)
            - (PickerState.active ? pickerBar.height : statusText.height) - mainColumn.spacing * (2 + (EditModeState.creatingFolder || EditModeState.creatingFile ? 1 : 0))

          // Parent column (yazi's left column). Inside the active panel next
          // to the list -- same place PreviewPanel splits into -- so it needs
          // no changes to panelsRow slot maths, TabsState or hover-to-activate.
          // Everything inside ActiveFileList (including the preview's 55/45
          // split) keeps working untouched: it is all relative to the list,
          // which is simply narrower now.
          ParentColumn {
            id: parentColumn
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            // In yazi mode the slot is UNCONDITIONAL: at /, inside an archive
            // and in the trash there is no parent to list, but collapsing the
            // column to zero reflowed the whole window and the other two panes
            // jumped. The contract is a stable three-slot window — hold the
            // slot, empty the content (ParentColumn.shown already gates that).
            width: NavState.yaziMode
              ? Math.round(parent.width * 2 / 9)
              : (shown ? Math.round(parent.width * 0.22) : 0)
            visible: width > 0
            hostNavController: controllers ? controllers.navController : null
            hostFileMeta: controllers ? controllers.fileMeta : null
            Behavior on width { NumberAnimation { duration: 120 } }
          }

          ActiveFileList {
            id: list
            anchors.left: parentColumn.right
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            root: mainLayout.root
            card: card
            controllers: mainLayout.controllers
            commandFacade: mainLayout.commandFacade
            dialogs: mainLayout.dialogs
            gTimer: mainLayout.gTimer
          }

        }
        } // end activeTop (Column)

        // Which-key hint for the `g` prefix. yazi pops the continuations the
        // moment you press a prefix, which is what makes its chords
        // discoverable instead of memorised — we added g-jumps with no way to
        // find them.
        //
        // An OVERLAY, not a column child: as a child it took real layout
        // space, so appearing for a few hundred ms shoved the list down and
        // pushed its last row under the status line. Floating over the panel
        // costs the layout nothing and matches how yazi draws it.
        Rectangle {
          id: gHint
          visible: mainLayout.root ? mainLayout.root.gPending : false
          z: 50
          anchors.left: activePanel.left
          anchors.right: activePanel.right
          anchors.bottom: activePanel.bottom
          anchors.margins: Style.spacing.controlGap
          height: gHintText.implicitHeight + Style.spacing.controlGap * 2
          color: Color.menu.background
          border.color: Color.menu.border
          border.width: Style.spacing.hairline
          radius: Style.cornerRadius > 0 ? Style.cornerRadius : 4

          Text {
            id: gHintText
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.spacing.controlGap
            text: "g →  h home · d Downloads · o Documents · c config · p Projects · m Music · i Pictures · v Videos · t Trash · r /  ·  gg top"
            color: Color.menu.text
            font.pixelSize: Style.font.bodySmall
            font.family: Style.font.family
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
          }
        }

            Text {
              id: statusText
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              visible: !PickerState.active
              // Position and mode flags first, yazi-style: the states you can be
              // in (visual, filter, hidden) must be visible without pressing
              // anything, or they become invisible modes you discover by
              // surprise. Position answers "how far down am I" the way yazi's
              // n/N does.
              text: (NavState.yaziMode ? "YAZI · " : "")
                + (SelectionState.selectedIndex >= 0 && NavState.visibleEntries.length > 0
                  ? (SelectionState.selectedIndex + 1) + "/" + NavState.visibleEntries.length + " · " : "")
                + (SelectionState.visualMode ? "VISUAL · " : "")
                + (NavState.filterOnly && NavState.searchQuery ? "FILTER · " : "")
                + (NavState.showHidden ? "HIDDEN · " : "")
                + NavState.visibleEntries.length + (NavState.visibleEntries.length === 1 ? " item" : " items")
                + (NavState.searchQuery ? " of " + NavState.entries.length : "")
                + (NavState.searchTruncated ? " · showing first 200" : "")
                + (!NavState.searchQuery && NavState.entries.length > 5000 ? " · large folder, may be slow" : "")
                + (SelectionState.selectedIndices.length > 1 ? " · " + SelectionState.selectedIndices.length + " selected" : "")
                + (SelectionState.markedCount > 0 ? " · " + SelectionState.markedCount + " marked" : "")
                + (ClipboardState.clipboardPaths.length > 0 ? " · clipboard: " + ClipboardState.clipboardPaths.length + (ClipboardState.clipboardPaths.length === 1 ? " item" : " items") + (ClipboardState.clipboardMode === "cut" ? " (cut)" : " (copied)") : "")
                // "(s)" because the direction arrow alone reads like a key hint
                // — it is the sort ORDER, not the shortcut.
                + " · sort: " + (controllers ? controllers.SortState.sortLabel() : "") + " (s)"
              font.pixelSize: Style.font.subtitle
              font.family: Style.font.family
              color: Color.menu.text
              opacity: Style.emphasis.secondary
            }

            FilePickerBar {
              id: pickerBar
              anchors.bottom: parent.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              visible: PickerState.active
              onResponseSubmitted: function(requestId, responseCode, results) {
                var resultsJson = JSON.stringify(results)
                Backend.Detached.run([
                  "dbus-send",
                  "--session",
                  "--type=method_call",
                  "--dest=org.freedesktop.impl.portal.desktop.omafiles",
                  "/org/freedesktop/portal/desktop",
                  "org.freedesktop.impl.portal.desktop.omafiles.SubmitResponse",
                  "string:" + requestId,
                  "uint32:" + responseCode,
                  "string:" + resultsJson
                ])
                root.close()
                root.requestClose()
              }
            }
          } // end activePanel (Item)
        } // end panelsRow (Item)
      }
    }

    MouseArea {
      x: cardRow.x + sidebar.width
      y: cardRow.y
      width: 2 * Style.spacing.panelGap + 1
      height: cardRow.height
      acceptedButtons: Qt.LeftButton
      onPressed: function (mouse) {
        var p = mapToItem(list.contentItem, mouse.x, mouse.y)
        var vp = mapToItem(list, mouse.x, mouse.y)
        if (controllers) controllers.SelectionState.startMarquee(p.x, p.y, vp.y, (mouse.modifiers & Qt.ControlModifier) !== 0)
      }
      onPositionChanged: function (mouse) {
        var p = mapToItem(list.contentItem, mouse.x, mouse.y)
        var vp = mapToItem(list, mouse.x, mouse.y)
        if (controllers) controllers.SelectionState.moveMarquee(p.x, p.y, vp.y, root.measuredRowHeight)
      }
      onReleased: if (controllers) controllers.SelectionState.endMarquee()
      onCanceled: if (controllers) controllers.SelectionState.endMarquee()
    }
  }

  Connections {
    target: mainLayout.root
    function onPickerSubmitRequested() {
      if (PickerState.active) {
        pickerBar.submit()
      }
    }
  }
}
