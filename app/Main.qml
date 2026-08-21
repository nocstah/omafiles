import QtQuick
import QtQuick.Controls
import qs.Commons
import Omafiles.Backend as Backend
import "../core"
import "."

// Standalone Qt6 host adapter (Phase 4 → Phase 18, josema). It is the
// single official host frontend for Omafiles: it instantiates
// core/OmafilesContent.qml over an ApplicationWindow.
// It fulfills the host contract (see integrations/HostAdapter.qml):

//   · show()/hide()/close()  -- built-in of Window/ApplicationWindow.
//   · external close          -- onClosing (WM's close button / Alt+F4).
//   · geometry (size)         -- via HostAdapter, same persistence as
// Window size persistence.
// The bootstrap (create the engine, load this file) is done by main.cpp; that's
// expects a QQuickWindow) and there is no intermediate core nor host
// `shell` object.
ApplicationWindow {
  id: window
  // Under --preload the window must still be SHOWN once, then hidden again as
  // soon as it has painted: a window that is never shown never creates its
  // scene graph or its Wayland surface, so the first show() pays for all of it
  // and the whole point of preloading is lost (measured: ~1.4s to appear when
  // it had never been rendered, against ~0.2s once it has). Showing it and
  // pulling it back on the first frameSwapped costs a brief flash at login and
  // makes every later launch instant.
  visible: true
  readonly property bool _isPreload: (typeof omafilesPreload !== "undefined" && omafilesPreload)
  property bool _preloadWarming: window._isPreload
  // Payload waiting for the window to actually be on screen (see onReceived).
  property string _pendingPayload: ""
  onFrameSwapped: {
    if (window._preloadWarming) {
      window._preloadWarming = false
      window.hide()
      return
    }
    // The frame is painted, so the window is visible NOW; only then start the
    // directory load. Qt.callLater was not enough -- it still runs within the
    // same event-loop pass that produces the first frame, so the expensive
    // work landed before the compositor ever got something to show.
    if (window._pendingPayload !== "") {
      var p = window._pendingPayload
      window._pendingPayload = ""
      // "\x1e" = bare relaunch: open("") restores/reattaches the loaded
      // session (opened=true, watcher and list focus back) without changing
      // folder.
      content.open(p === "\x1e" ? "" : p)
    }
  }
  // Default size of the first opening; HostAdapter overrides it if
  // there is a saved window.json (see onSizeRestored).
  width: 1400
  height: 900
  minimumWidth: 560
  minimumHeight: 380
  title: "Omafiles"
  color: Color.menu.background

  HostAdapter {
    id: adapter
    window: window
  }

  Connections {
    target: adapter
    function onSizeRestored(w, h) {
      window.width = w
      window.height = h
    }
  }

  // External close (window manager's close button / Alt+F4) and internal
  // close (Esc / closing the last tab, via onCloseRequested -> window.
  // close()). In a single-window standalone, closing = quitting the app
  // (quitOnLastWindowClosed). content.close() is the one that PERSISTS the session
  // (saveSession, synchronous) besides stopping the watcher and resetting dialogs;
  // calling it here is essential, otherwise the session is never saved in the
  // standalone (Phase 25 regression: before this only set opened=false and
  // skipped the save, so session.json stayed frozen).
  onClosing: (close) => {
    content.close()
    // A preloaded instance is a warm cache, not a window: closing it should put
    // it away, not throw away the process. Quitting here meant the FIRST launch
    // after any close paid a full cold start again -- and, because the exit is
    // clean, systemd's Restart=on-failure never brought it back either.
    if (window._isPreload) {
      close.accepted = false
      window.hide()
      return
    }
    Qt.quit()
  }

  OmafilesContent {
    id: content
    anchors.fill: parent
    // Esc / closing the last tab: no `shell` object to notify (there is no
    // Closes the application window.
    onCloseRequested: {
      // window.close() routes through onClosing, which for a preloaded
      // instance HIDES instead of quitting -- the unconditional Qt.quit()
      // here killed the warm process anyway on the in-app close paths
      // (Esc / closing the last panel), silently defeating the preload the
      // same way the WM close used to before onClosing learned to hide.
      window.close()
      if (!window._isPreload) Qt.quit()
    }
  }

  // Single instance: a second invocation `omafiles [path]` doesn't open
  // another window -- main.cpp delivers the payload over the local socket and here it
  // navigates/selects (content.open) and brings the window to the front. Same
  // Opens the specified path or previous session.
  Connections {
    target: SingleInstance
    function onReceived(payload) {
      // "\x1e" = a bare `omafiles` with no path (dock icon, launcher). It is
      // sent as a sentinel rather than an empty string because writing zero
      // bytes never wakes readyRead on this side, so the window would stay
      // hidden and the launch would look like nothing happened. There is no
      // path to open in that case -- just come forward.
      // Map and raise the window FIRST, then load. content.open() does enough
      // main-thread work (delegates, per-folder child counting, preview) that
      // doing it first delays the first frame, and the compositor shows nothing
      // until that frame arrives: measured 1.24s to appear when opening a path
      // against 0.43s when only showing. Qt.callLater defers the load to after
      // this event loop pass, so the window is on screen and then fills in.
      window.show()
      window.raise()
      window.requestActivate()
      // A bare relaunch ("\x1e") must still REOPEN the content, not just come
      // forward: onClosing ran content.close() when the preloaded window was
      // put away (opened=false, dir watcher stopped -- and the file list's
      // focus binds to root.opened), so show() without open() brought back a
      // window that rendered and took mouse input but had a DEAD KEYBOARD
      // and a stale listing. The sentinel is kept in _pendingPayload so the
      // reopen still happens after the first frame, same as a path payload.
      window._pendingPayload = (payload && payload !== "\x1e") ? payload : "\x1e"
    }
  }

  Component.onCompleted: {
    var isPicker = typeof omafilesInitialPayload !== "undefined" && omafilesInitialPayload.indexOf("picker:") >= 0
    if (!isPicker) {
      adapter.restore()
    } else {
      window.width = 900
      window.height = 600
    }
    // Initial payload from the command line (main.cpp). Empty = restores the
    // Restores previous session tabs.
    content.open(typeof omafilesInitialPayload !== "undefined" ? omafilesInitialPayload : "")
  }
}
