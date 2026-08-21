pragma Singleton
import QtQuick
import Omafiles.Backend as Backend

// Hot navigation state: the current path, its
// listing and the visible search filter. It was the main coupling
// between logic/ and root -- currentPath (59 reads), visibleEntries (24) and
// Central navigation and directory listing state.
// logic layer, always via `property Item root`. Moving them to a singleton
// lets logic/ read/write NavState.* directly and lets root keep
// only thin compatibility bindings for the visual tree (still not
// split). See ARCHITECTURE.md (state/ layer) and the 2026-08-09 audit.
//
// The initial value of currentPath is just a placeholder: open() always
// rewrites it before the user sees anything (real payload or session
// restoration via Persistence), like TabsState.
QtObject {
  property string currentPath: Backend.Env.get("HOME")

  // Listing of the current folder, already sorted (DirectoryModel in C++
  // returns it by naturalCompare; logic/ only re-sorts if the user requested
  // another criterion -- see SortOps.isDefaultOrder). Source of truth; root.
  // entries is a binding to this.
  property var entries: []

  property bool showHidden: false

  // Text of the active panel's quick search (substring filter over
  // the current folder, not a recursive search). Empty = no filter.
  property string searchQuery: ""

  // Local-only filter (yazi `f`). searchQuery ALREADY filters the current
  // folder through visibleEntries below; what this flag adds is suppressing
  // the global deep search that otherwise replaces the listing with
  // system-wide plocate hits at 2+ characters. So: same box, stays home.
  property bool filterOnly: false

  // zoxide jump (yazi `z`): same input bar again, but Enter resolves the text
  // through `zoxide query` and navigates, instead of filtering anything.
  property bool zoxideMode: false

  // Per-directory cursor memory: path -> name of the row the cursor was on
  // when you last left it. yazi restores your position when you re-enter a
  // folder; without it every entry starts at the top, which is what makes
  // going back and forth feel like starting over. Session-lifetime only —
  // deliberately not persisted, since a stale row from days ago is noise.
  property var cursorMemory: ({})

  // Linemode, yazi's `m`: what the second line of every row carries.
  //   none  — nothing. Rows collapse to one line: this is compact mode, and
  //           the density comes from dropping the RESERVED height, not from
  //           blanking text in a tall row.
  //   meta  — item count / size, plus age (the original subtitle)
  //   perms — ls-style permission string
  //   owner — owning user
  readonly property var lineModes: ["none", "meta", "perms", "owner"]
  property string lineMode: "none"
  function cycleLineMode() {
    var i = lineModes.indexOf(lineMode)
    lineMode = lineModes[(i + 1) % lineModes.length]
  }

  // Kept as a name because row height, padding and the count-skip all key off
  // "is there a second line at all".
  readonly property bool compactMode: lineMode === "none"

  // Folder item counts are only ever DRAWN in meta mode, and producing one
  // stats every child of every visible folder. Any other mode skips the walk.
  readonly property bool needsFolderCounts: lineMode === "meta"

  // yazi mode: the window becomes a sliding parent | current | preview view
  // over the path, with NO sidebar. The bookmarks/devices sidebar is chrome,
  // not part of the cascade — leaving it up meant four panes, which is why the
  // layout never read as yazi no matter what the three columns did.
  //
  // Ratios are locked to 2/3/4 ninths (tony-tui's Miller-column contract):
  // parent 2/9, current 3/9, preview 4/9, and the parent never resizes.
  property bool yaziMode: true

  // Fraction of the space RIGHT of the parent column that the file list takes.
  // In yazi mode the parent has already eaten 2/9, so the remaining 7/9 splits
  // 3:4 -> 3/7 list, 4/7 preview. Outside the mode, upstream's 55/45.
  readonly property real listFraction: yaziMode ? (3 / 7) : 0.55

  // Parent column (yazi's left column), toggled with Shift+P. ON by default:
  // the three panes only work as a system — parent for where you came from,
  // middle for where you are, preview for what you are pointing at. Two of
  // them behind separate opt-ins meant the layout never actually assembled.
  property bool parentColumnOpen: true

  // Visible subset of `entries` after applying the quick filter. Derived
  // (readonly): previously it was computed in root.visibleEntries and read by 24
  // sites of logic/. Same expression, now next to its data source.
  // The NAME search filters the listing by the term (match in the
  // basename). The CONTENT search (`content:`) is NOT filtered: its
  // results are matches inside files and their name does not contain the
  // prefix, so filtering would hide them all.
  readonly property var visibleEntries: {
    if (!searchQuery || searchQuery.indexOf("content:") === 0) return entries
    // Hoisted out of the filter callback (cleanup pass) -- was recomputed
    // once per entry instead of once for the whole filter.
    var q = searchQuery.toLowerCase()
    return entries.filter(function (e) { return e.name.toLowerCase().indexOf(q) >= 0 })
  }

  // ---------- Runtime navigation/search state ----------
  // They were mutable properties of OmafilesContent that did not belong to the
  // composition root: they are all hot state of the same domain (nav +
  // search) that this singleton already governs. logic/ and the visual layer
  // read/write them directly via NavState.*, without `property Item root`.

  // Search mode open (Phase 19: the top bar's magnifier is
  // expanded; the search field is visible). Reused as an
  // "expanded" flag to not duplicate state -- there is no separate searchExpanded.
  property bool searching: false
  // A recursive search (SearchWorker) is in flight -- triggers the magnifier's
  // spinner. It is set in runDeepSearch() and cleared in onResults/restore.
  property bool searchBusy: false
  // The recursive search was cut to the first 200 results (a warning to the
  // user that items are missing; see SearchOps/search-recursive.sh).
  property bool searchTruncated: false
  // Suppresses the magnifier's expand/collapse animation during a tab
  // change (TabOps sets it while changing): on moving the cursor to another tab,
  // `searching` changes because it adopts THAT tab's state, not because the user
  // opened/closed the search -- without this, the tab you arrive at replays the
  // minimize/expand animation of the bar, which looks bad (same reason as
  // suppressListFade for the list fade).
  property bool suppressSearchAnim: false
  // Same idea for the LAYOUT: the parent column's width animates on an
  // interactive Shift+P (nice), but a focus switch between panes of
  // DIFFERENT stances flips parentColumnOpen/yaziMode as state restoration,
  // and the 120ms width tween dragged the whole list+preview sideways into a
  // layout the background twin had already painted -- everything visibly
  // "re-animated into place" on every mixed-stance switch. Stance changes
  // that come from a pane switch must SNAP.
  property bool suppressLayoutAnim: false
  // Message if the listing of currentPath failed (permissions, folder deleted
  // between navigating and listing...). Empty = no error or listing in progress.
  property string currentPathError: ""
  // Names to highlight as soon as the next listing finishes (ShowItems case
  // of org.freedesktop.FileManager1: several URIs of a folder at once).
  property var pendingSelectNames: []
  // Counter that forces a refresh of the background panels (signal, not data):
  // ActionEngine/RenameOps/SearchOps increment it after mutating disk.
  property int refreshTick: 0
}
