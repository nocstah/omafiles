import QtQuick
import "../state"
import Omafiles.Backend as Backend

// Keyboard shortcuts of the active panel (Keys.onPressed of the ListView) --
// first cut of panels/ActiveFileList.qml (761 lines, over the
// 300-500 limit), pulling out the more "logical" part (a long if/else that
// decides what to do based on event.key/modifiers) and leaving inside the more
// visual part (row delegate, marquee, drag&drop). handlePress() receives
// the same `event` that arrived at Keys.onPressed -- accepted is still
// marked here just like before, ActiveFileList only delegates the whole
// call.
Item {
  property Item hostRoot: null
  property var hostControllers: null
  property var hostCommandFacade: null
  property var hostDialogs: null
  property Item hostListView: null
  property Timer hostGTimer: null

  function handlePress(event) {
    if (PaletteState.paletteOpen) return
    if (PreviewState.openWithOpen) {
      if (event.key === Qt.Key_Escape) { PreviewState.openWithOpen = false; event.accepted = true }
      return
    }
    if (ChmodState.chmodOpen) {
      if (event.key === Qt.Key_Escape) { ChmodState.chmodOpen = false; event.accepted = true }
      else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.commitChmod(ChmodState.chmodMode)
        event.accepted = true
      }
      return
    }
    if (ContextMenuState.contextMenuOpen) {
      if (event.key === Qt.Key_Escape) { ContextMenuState.contextMenuOpen = false; event.accepted = true }
      return
    }
    if (ActionState.pendingDeleteNames.length > 0) {
      if (hostDialogs && hostDialogs.deleteConfirm && hostDialogs.deleteConfirm.handleKey(event)) event.accepted = true
      return
    }
    if (ConflictState.renameConflictOpen) {
      if (hostDialogs && hostDialogs.renameConflictConfirm && hostDialogs.renameConflictConfirm.handleKey(event)) event.accepted = true
      return
    }
    if (ConflictState.extractConflictOpen) {
      if (hostDialogs && hostDialogs.extractConflictConfirm && hostDialogs.extractConflictConfirm.handleKey(event)) event.accepted = true
      return
    }
    if (ConflictState.compressConflictOpen) {
      if (hostDialogs && hostDialogs.compressConflictConfirm && hostDialogs.compressConflictConfirm.handleKey(event)) event.accepted = true
      return
    }
    if (ConflictState.bulkRenameConflictOpen) {
      if (hostDialogs && hostDialogs.bulkRenameConflictConfirm && hostDialogs.bulkRenameConflictConfirm.handleKey(event)) event.accepted = true
      return
    }
    if (ConflictState.newFileConflictOpen) {
      if (hostDialogs && hostDialogs.newFileConflictConfirm && hostDialogs.newFileConflictConfirm.handleKey(event)) event.accepted = true
      return
    }
    if (ConflictState.newFolderConflictOpen) {
      if (hostDialogs && hostDialogs.newFolderConflictConfirm && hostDialogs.newFolderConflictConfirm.handleKey(event)) event.accepted = true
      return
    }
    if (ConflictState.pasteConflictOpen) {
      if (event.key === Qt.Key_Escape) {
        if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.cancelPasteConflict()
        event.accepted = true
      }
      return
    }
    if (ConflictState.dropConflictOpen) {
      if (event.key === Qt.Key_Escape) {
        if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.cancelDropConflict()
        event.accepted = true
      }
      return
    }
    if (PropertiesState.propertiesOpen) {
      if (event.key === Qt.Key_Escape) { PropertiesState.propertiesOpen = false; event.accepted = true }
      return
    }
    if (DialogsState.shortcutsHelpOpen) {
      if (event.key === Qt.Key_Escape || event.key === Qt.Key_Question) { DialogsState.shortcutsHelpOpen = false; event.accepted = true }
      return
    }
    if (DialogsState.notificationHistoryOpen) {
      if (event.key === Qt.Key_Escape) { DialogsState.notificationHistoryOpen = false; event.accepted = true }
      return
    }
    if (DialogsState.bulkRenameOpen) {
      if (event.key === Qt.Key_Escape) { DialogsState.bulkRenameOpen = false; event.accepted = true }
      return
    }
    if (DialogsState.connectServerOpen) {
      if (event.key === Qt.Key_Escape) {
        if (hostControllers && hostControllers.mountOps) {
          if (DialogsState.networkConnecting) hostControllers.mountOps.cancelNetworkConnect()
          else hostControllers.mountOps.cancelConnectToServer()
        }
        event.accepted = true
      }
      return
    }
    // NavState.searching does NOT go here: while the search is open,
    // the search field lives in the top bar and has its own focus;
    // if the user clicks a result and the list regains focus,
    // the shortcuts (navigate, copy, delete...) must work over the
    // results just like over any listing (req 7).
    if (EditModeState.creatingFolder || EditModeState.creatingFile || EditModeState.renamingIndex >= 0 || EditModeState.editingPath) return

    var extend = (event.modifiers & Qt.ShiftModifier) !== 0

    // Escape and the "gg" top-of-list chord stay hardcoded, not
    // resolver-driven (P2.5 audit's own recommendation): Escape's
    // meaning is context-dependent (search/preview/picker/tabs) rather
    // than a single handler call, and "g" is a stateful two-key chord
    // (hostRoot.gPending + hostGTimer), not a plain "key -> action".
    if (event.key === Qt.Key_Escape) {
      if (SelectionState.visualMode) SelectionState.visualMode = false
      else if (SelectionState.markedCount > 0) SelectionState.clearMarks()
      else if (NavState.searching) { if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.exitSearch() }
      // NOTE: Escape used to close the preview here. That made sense when the
      // preview was a thing you summoned with Space; now that it is the third
      // pane of the default layout, Escape collapsing it means the layout
      // falls apart whenever you back out of a filter or visual mode -- and it
      // is not obvious how to get it back. Space still toggles it.
      else if (PickerState.active) { if (hostRoot) hostRoot.cancelPicker() }
      else if (TabsState.tabs.length > 1) { if (hostControllers && hostControllers.tabOps) hostControllers.tabOps.closeTab() }
      event.accepted = true
      return
    }
    // g-prefix jumps (yazi): `g` then a letter. Hardcoded for the same reason
    // the "gg" chord below is -- it is stateful (hostRoot.gPending), not a
    // plain "key -> action" the resolver can express. MUST run before the
    // resolver, or `gd` would trash the selection via the `d` binding and `gp`
    // would paste. A `g` followed by anything unmapped just cancels.
    if (hostRoot && hostRoot.gPending && event.key !== Qt.Key_G && event.modifiers === Qt.NoModifier) {
      hostRoot.gPending = false
      var gTargets = {}
      gTargets[Qt.Key_H] = Paths.homeDir
      gTargets[Qt.Key_D] = Paths.homeDir + "/Downloads"
      gTargets[Qt.Key_O] = Paths.homeDir + "/Documents"
      gTargets[Qt.Key_C] = Paths.homeDir + "/.config"
      gTargets[Qt.Key_P] = Paths.homeDir + "/Projects"
      gTargets[Qt.Key_M] = Paths.homeDir + "/Music"
      gTargets[Qt.Key_I] = Paths.homeDir + "/Pictures"
      gTargets[Qt.Key_V] = Paths.homeDir + "/Videos"
      gTargets[Qt.Key_T] = Paths.trashDir
      gTargets[Qt.Key_E] = Paths.recentsDir
      gTargets[Qt.Key_R] = "/"
      var gDest = gTargets[event.key]
      if (gDest !== undefined) {
        if (hostControllers && hostControllers.navController) hostControllers.navController.navigateTo(gDest)
        event.accepted = true
        return
      }
    }
    // 1-9 tab jump (yazi). Also hardcoded rather than resolver-driven: it is
    // one behaviour over a RANGE of keys, so expressing it as data would mean
    // nine near-identical entries whose only difference is the index.
    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && event.modifiers === Qt.NoModifier) {
      var wanted = event.key - Qt.Key_1
      if (wanted < TabsState.tabs.length && wanted !== TabsState.activeTabIndex) {
        if (hostControllers && hostControllers.tabOps) hostControllers.tabOps.switchToTab(wanted)
      }
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_G && event.modifiers === Qt.NoModifier) {
      if (hostRoot.gPending) { if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.goTop(); hostRoot.gPending = false }
      else { hostRoot.gPending = true; hostGTimer.restart() }
      event.accepted = true
      return
    }

    // Everything else: configured-binding -> semantic action -> handler.
    // KeyboardDefaults.actions encodes both the default keys and the
    // priority order that used to be implicit in this if/else chain
    // (e.g. select_none before select_all so Ctrl+Shift+A doesn't also
    // match Ctrl+A); KeybindingResolver.actionFor() applies overrides
    // from ~/.config/omafiles/keybindings.toml on top of those defaults.
    var resolver = hostControllers && hostControllers.keybindingResolver
    var actionId = resolver ? resolver.actionFor(event) : null
    if (!actionId) return

    switch (actionId) {
    case "open_terminal":
      Backend.TerminalResolver.launchTerminal(NavState.currentPath)
      break
    case "go_up":
      if (hostControllers && hostControllers.navController) hostControllers.navController.goUp()
      break
    case "open":
      if (SelectionState.selectedIndex >= 0 && hostControllers && hostControllers.navController) hostControllers.navController.enter(NavState.visibleEntries[SelectionState.selectedIndex])
      break
    case "toggle_preview":
      if (hostControllers && hostControllers.previewLoader) hostControllers.previewLoader.togglePreview()
      break
    case "search":
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.startSearch()
      break
    case "command_palette":
      if (hostCommandFacade) hostCommandFacade.openPalette()
      break
    case "toggle_help":
      DialogsState.shortcutsHelpOpen = true
      break
    case "notification_history":
      DialogsState.notificationHistoryOpen = true
      break
    case "go_bottom":
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.goBottom()
      break
    case "move_down": {
      var down = Math.min(NavState.visibleEntries.length - 1, SelectionState.selectedIndex + 1)
      if (extend) SelectionState.selectRange(down)
      else SelectionState.selectOnly(down)
      hostListView.positionWithScrolloff(down)
      break
    }
    case "move_up": {
      var up = Math.max(0, SelectionState.selectedIndex - 1)
      if (extend) SelectionState.selectRange(up)
      else SelectionState.selectOnly(up)
      hostListView.positionWithScrolloff(up)
      break
    }
    case "select_none":
      SelectionState.clearMarks()
      SelectionState.selectNone()
      break
    case "select_all":
      SelectionState.selectAll()
      break
    case "invert_selection":
      SelectionState.invertSelection()
      break
    case "rename":
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.startRename(SelectionState.selectedIndex)
      break
    case "delete":
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.requestDelete()
      break
    case "refresh":
      if (hostControllers && hostControllers.navController) hostControllers.navController.refresh()
      break
    case "reverse_sort":
      SortState.reverseSort()
      break
    case "cycle_sort":
      SortState.cycleSort()
      break
    case "edit_path":
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.startEditPath()
      break
    case "new_folder":
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.startNewFolder()
      break
    case "new_file":
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.startNewFile()
      break
    case "new_tab":
      if (hostControllers && hostControllers.tabOps) hostControllers.tabOps.newTab()
      break
    case "nav_back":
      if (hostControllers && hostControllers.navController) hostControllers.navController.navBack()
      break
    case "nav_forward":
      if (hostControllers && hostControllers.navController) hostControllers.navController.navForward()
      break
    case "close_tab":
      if (hostControllers && hostControllers.tabOps) hostControllers.tabOps.closeTab()
      break
    case "next_tab":
      if (hostControllers && hostControllers.tabOps) hostControllers.tabOps.nextTab()
      break
    case "toggle_hidden":
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.toggleHidden()
      break
    case "copy":
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.copySelected()
      break
    case "cut":
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.cutSelected()
      break
    case "paste":
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.paste()
      break
    case "redo":
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.redoLast()
      break
    case "undo":
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.undoLast()
      break

    // ---- yazi muscle memory ------------------------------------------------
    // These ride the same resolver as everything above, so they are
    // rebindable from keybindings.toml like any other action. Their DEFAULT
    // keys (see state/KeyboardDefaults.qml) are all keys that were previously
    // unbound, and the aliases are additive: Ctrl+C/X/V and Delete still work,
    // so nothing a mouse-driven user relies on moves.
    case "delete_permanent":
      // Goes through the SAME confirm dialog as trash -- the dialog just says
      // so -- because this one has no undo.
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.requestDeletePermanent()
      break
    case "yazi_mode":
      // Parent + preview in, ratios locked to 2/3/4. One switch, because the
      // three columns only make sense together -- toggling them separately
      // just produced a four-pane hybrid. PER-PANE since the panes got their
      // own modes: this toggles only the focused pane's stance; the sidebar
      // follows the "every pane plain" rule in MainLayout instead of this
      // flag directly.
      NavState.yaziMode = !NavState.yaziMode
      if (NavState.yaziMode) {
        NavState.parentColumnOpen = true
        PreviewState.previewOpen = true
      } else {
        // Leaving the mode has to put the columns away too. Only restoring the
        // sidebar left the parent column and preview standing, so "off" looked
        // like yazi mode with a sidebar bolted on and the two states were
        // indistinguishable.
        NavState.parentColumnOpen = false
        PreviewState.previewOpen = false
      }
      // Write-through to the tab object: it is what the sidebar rule and the
      // session snapshot read for non-active panes, and it is otherwise only
      // written on a switch.
      if (hostControllers && hostControllers.tabOps) hostControllers.tabOps.saveActiveTab()
      break
    case "filter":
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.startFilter()
      break
    case "zoxide":
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.startZoxide()
      break
    case "cycle_linemode":
      // yazi's linemode cycle: none -> meta -> perms -> owner.
      NavState.cycleLineMode()
      break
    case "visual_mode":
      // Sticky range selection. Anchor where the cursor is now, so the first
      // j/k already extends from the right row.
      if (SelectionState.visualMode) {
        SelectionState.visualMode = false
      } else {
        SelectionState.visualMode = true
        SelectionState.anchorIndex = SelectionState.selectedIndex
      }
      break
    default:
      return
    }
    event.accepted = true
  }
}
