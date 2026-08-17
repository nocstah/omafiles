import QtQuick
import "../state"

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
    if (hostRoot && hostRoot.pendingDeleteNames && hostRoot.pendingDeleteNames.length > 0) {
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

    // Visual mode extends exactly like a held Shift, so every range path
    // below (j/k, arrows, selectRange) picks it up for free.
    var extend = (event.modifiers & Qt.ShiftModifier) !== 0 || SelectionState.visualMode

    // g-prefix jumps (yazi): `g` then a letter. This MUST resolve before the
    // plain-letter chain below, or `gd` would trash the selection via `d` and
    // `gp` would paste. A `g` followed by anything unmapped just cancels.
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
      gTargets[Qt.Key_R] = "/"
      var gDest = gTargets[event.key]
      if (gDest !== undefined) {
        if (hostControllers && hostControllers.navController) hostControllers.navController.navigateTo(gDest)
        event.accepted = true
        return
      }
    }

    // Shift+Return: Open terminal here
    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && (event.modifiers & Qt.ShiftModifier)) {
      Backend.TerminalResolver.launchTerminal(NavState.currentPath)
      event.accepted = true
    } else if (event.key === Qt.Key_Escape) {
      if (SelectionState.visualMode) SelectionState.visualMode = false
      else if (SelectionState.markedCount > 0) SelectionState.clearMarks()
      else if (NavState.searching) { if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.exitSearch() }
      // NOTE: Escape used to close the preview here. That made sense when the
      // preview was a thing you summoned with Space; now that it is the third
      // pane of the default layout, Escape collapsing it means the layout
      // falls apart whenever you back out of a filter or visual mode — and it
      // is not obvious how to get it back. Space still toggles it.
      else if (PickerState.active) { if (hostRoot) hostRoot.cancelPicker() }
      else if (TabsState.tabs.length > 1) { if (hostControllers && hostControllers.tabOps) hostControllers.tabOps.closeTab() }
      event.accepted = true
    } else if (event.key === Qt.Key_Backspace || ((event.key === Qt.Key_H || event.key === Qt.Key_Left) && event.modifiers === Qt.NoModifier)) {
      // Key_Left mirrors h (yazi-style: left leaves the folder). The
      // NoModifier guard is load-bearing -- this branch runs BEFORE the
      // Alt+Left history branch below, so without it Alt+Left would go up a
      // directory instead of back in history.
      if (hostControllers && hostControllers.navController) hostControllers.navController.goUp()
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || ((event.key === Qt.Key_L || event.key === Qt.Key_Right) && event.modifiers === Qt.NoModifier)) {
      if (SelectionState.selectedIndex >= 0 && hostControllers && hostControllers.navController) hostControllers.navController.enter(NavState.visibleEntries[SelectionState.selectedIndex])
      event.accepted = true
    } else if (event.key === Qt.Key_Space) {
      if (hostControllers && hostControllers.previewLoader) hostControllers.previewLoader.togglePreview()
      event.accepted = true
    } else if (event.key === Qt.Key_Slash || (event.key === Qt.Key_F && (event.modifiers & Qt.ControlModifier))) {
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.startSearch()
      event.accepted = true
    } else if (event.key === Qt.Key_Colon || (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier))) {
      if (hostCommandFacade) hostCommandFacade.openPalette()
      event.accepted = true
    } else if (event.key === Qt.Key_Question) {
      DialogsState.shortcutsHelpOpen = true
      event.accepted = true
    } else if (event.key === Qt.Key_G && (event.modifiers & Qt.ShiftModifier)) {
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.goBottom()
      event.accepted = true
    } else if (event.key === Qt.Key_G && event.modifiers === Qt.NoModifier) {
      if (hostRoot.gPending) { if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.goTop(); hostRoot.gPending = false }
      else { hostRoot.gPending = true; hostGTimer.restart() }
      event.accepted = true
    } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers === Qt.NoModifier)) {
      var down = Math.min(NavState.visibleEntries.length - 1, SelectionState.selectedIndex + 1)
      if (extend) { if (true) SelectionState.selectRange(down) }
      else { if (true) SelectionState.selectOnly(down) }
      hostListView.positionWithScrolloff(down)
      event.accepted = true
    } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers === Qt.NoModifier)) {
      var up = Math.max(0, SelectionState.selectedIndex - 1)
      if (extend) { if (true) SelectionState.selectRange(up) }
      else { if (true) SelectionState.selectOnly(up) }
      hostListView.positionWithScrolloff(up)
      event.accepted = true
    } else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
      SelectionState.clearMarks()
      if (true) SelectionState.selectNone()
      event.accepted = true
    } else if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
      SelectionState.selectedIndices = Array.from({ length: NavState.visibleEntries.length }, function (_, i) { return i })
      event.accepted = true
    } else if (event.key === Qt.Key_I && (event.modifiers & Qt.ControlModifier)) {
      if (true) SelectionState.invertSelection()
      event.accepted = true
    } else if (event.key === Qt.Key_F2) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.startRename(SelectionState.selectedIndex)
      event.accepted = true
    } else if (event.key === Qt.Key_Delete) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.requestDelete()
      event.accepted = true
    } else if (event.key === Qt.Key_F5) {
      if (hostControllers && hostControllers.navController) hostControllers.navController.refresh()
      event.accepted = true
    } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ShiftModifier)) {
      SortState.reverseSort()
      event.accepted = true
    } else if (event.key === Qt.Key_S && event.modifiers === Qt.NoModifier) {
      SortState.cycleSort()
      event.accepted = true
    } else if (event.key === Qt.Key_L && (event.modifiers & Qt.ControlModifier)) {
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.startEditPath()
      event.accepted = true
    } else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.startNewFolder()
      event.accepted = true
    } else if (event.key === Qt.Key_N && (event.modifiers & Qt.ControlModifier)) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.startNewFile()
      event.accepted = true
    } else if (event.key === Qt.Key_Backslash && (event.modifiers & Qt.ControlModifier)) {
      if (hostControllers && hostControllers.tabOps) hostControllers.tabOps.newTab()
      event.accepted = true
    } else if (event.key === Qt.Key_Left && (event.modifiers & Qt.AltModifier)) {
      if (hostControllers && hostControllers.navController) hostControllers.navController.navBack()
      event.accepted = true
    } else if (event.key === Qt.Key_Right && (event.modifiers & Qt.AltModifier)) {
      if (hostControllers && hostControllers.navController) hostControllers.navController.navForward()
      event.accepted = true
    } else if (event.key === Qt.Key_T && (event.modifiers & Qt.ControlModifier)) {
      if (hostControllers && hostControllers.tabOps) hostControllers.tabOps.newTab()
      event.accepted = true
    } else if (event.key === Qt.Key_W && (event.modifiers & Qt.ControlModifier)) {
      if (hostControllers && hostControllers.tabOps) hostControllers.tabOps.closeTab()
      event.accepted = true
    } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ControlModifier)) {
      if (hostControllers && hostControllers.tabOps) hostControllers.tabOps.nextTab()
      event.accepted = true
    } else if (event.key === Qt.Key_H && (event.modifiers & Qt.ControlModifier)) {
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.toggleHidden()
      event.accepted = true
    } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.copySelected()
      event.accepted = true
    } else if (event.key === Qt.Key_X && (event.modifiers & Qt.ControlModifier)) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.cutSelected()
      event.accepted = true
    } else if (event.key === Qt.Key_V && (event.modifiers & Qt.ControlModifier)) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.paste()
      event.accepted = true
    } else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.redoLast()
      event.accepted = true
    } else if (event.key === Qt.Key_Y && (event.modifiers & Qt.ControlModifier)) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.redoLast()
      event.accepted = true
    } else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.undoLast()
      event.accepted = true

    // ---- yazi muscle memory: unmodified keys, all previously unbound -------
    // Deliberately aliases rather than replacements — Ctrl+C/X/V and Delete
    // still work, so nothing a mouse-driven user relies on moves.
    } else if (event.key === Qt.Key_Y && event.modifiers === Qt.NoModifier) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.copySelected()
      event.accepted = true
    } else if (event.key === Qt.Key_X && event.modifiers === Qt.NoModifier) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.cutSelected()
      event.accepted = true
    } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ShiftModifier)) {
      // yazi mode on/off: sidebar out, parent + preview in, ratios locked to
      // 2/3/4. One switch, because the three columns only make sense together
      // — toggling them separately just produced a four-pane hybrid.
      NavState.yaziMode = !NavState.yaziMode
      if (NavState.yaziMode) {
        NavState.parentColumnOpen = true
        PreviewState.previewOpen = true
      } else {
        // Leaving the mode has to put the columns away too. Only restoring
        // the sidebar left the parent column and preview standing, so "off"
        // looked like yazi mode with a sidebar bolted on and the two states
        // were indistinguishable.
        NavState.parentColumnOpen = false
        PreviewState.previewOpen = false
      }
      event.accepted = true
    } else if (event.key === Qt.Key_P && event.modifiers === Qt.NoModifier) {
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.paste()
      event.accepted = true
    } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ShiftModifier)) {
      // Permanent delete. Goes through the SAME confirm dialog as trash — the
      // dialog just says so — because this one has no undo.
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.requestDeletePermanent()
      event.accepted = true
    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9 && event.modifiers === Qt.NoModifier) {
      // Jump straight to a tab, like yazi's 1-9.
      var wanted = event.key - Qt.Key_1
      if (wanted < TabsState.tabs.length && wanted !== TabsState.activeTabIndex) {
        if (hostControllers && hostControllers.tabOps) hostControllers.tabOps.switchToTab(wanted)
      }
      event.accepted = true
    } else if (event.key === Qt.Key_D && event.modifiers === Qt.NoModifier) {
      // Trash, not unlink — same path as the Delete key, so it still goes
      // through the confirm dialog and stays undoable.
      if (hostControllers && hostControllers.actionEngine) hostControllers.actionEngine.requestDelete()
      event.accepted = true
    } else if (event.key === Qt.Key_Period && event.modifiers === Qt.NoModifier) {
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.toggleHidden()
      event.accepted = true
    } else if (event.key === Qt.Key_F && event.modifiers === Qt.NoModifier) {
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.startFilter()
      event.accepted = true
    } else if (event.key === Qt.Key_Z && event.modifiers === Qt.NoModifier) {
      if (hostControllers && hostControllers.searchOps) hostControllers.searchOps.startZoxide()
      event.accepted = true
    } else if (event.key === Qt.Key_M && event.modifiers === Qt.NoModifier) {
      // yazi's linemode cycle: none -> meta -> perms -> owner.
      NavState.cycleLineMode()
      event.accepted = true
    } else if (event.key === Qt.Key_V && event.modifiers === Qt.NoModifier) {
      // Sticky range selection. Anchor where the cursor is now, so the first
      // j/k already extends from the right row.
      if (SelectionState.visualMode) {
        SelectionState.visualMode = false
      } else {
        SelectionState.visualMode = true
        SelectionState.anchorIndex = SelectionState.selectedIndex
      }
      event.accepted = true
    }
  }
}
