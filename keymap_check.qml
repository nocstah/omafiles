// Headless check of the keybinding resolver after the v1.0.0 rebase.
// Verifies that every yazi binding resolves to the right semantic action AND
// that none of them shadow a stock binding (the precedence rules in
// state/KeyboardDefaults.qml's header are order-sensitive and easy to get
// subtly wrong -- e.g. Alt+Left must still be nav_back, not go_up).
//
//   qml -I . keymap_check.qml
import QtQuick
import "state"
import "logic" as Logic

Item {
  Logic.KeybindingResolver { id: resolver }

  function ev(key, mods) { return { key: key, modifiers: mods } }

  Component.onCompleted: {
    var N = Qt.NoModifier, C = Qt.ControlModifier, S = Qt.ShiftModifier, A = Qt.AltModifier
    var cases = [
      // --- yazi additions ---
      ["left  -> go_up",              ev(Qt.Key_Left,   N),   "go_up"],
      ["right -> open",               ev(Qt.Key_Right,  N),   "open"],
      ["y     -> copy",               ev(Qt.Key_Y,      N),   "copy"],
      ["x     -> cut",                ev(Qt.Key_X,      N),   "cut"],
      ["p     -> paste",              ev(Qt.Key_P,      N),   "paste"],
      ["d     -> delete",             ev(Qt.Key_D,      N),   "delete"],
      [".     -> toggle_hidden",      ev(Qt.Key_Period, N),   "toggle_hidden"],
      ["D     -> delete_permanent",   ev(Qt.Key_D,      S),   "delete_permanent"],
      ["P     -> yazi_mode",          ev(Qt.Key_P,      S),   "yazi_mode"],
      ["f     -> filter",             ev(Qt.Key_F,      N),   "filter"],
      ["z     -> zoxide",             ev(Qt.Key_Z,      N),   "zoxide"],
      ["m     -> cycle_linemode",     ev(Qt.Key_M,      N),   "cycle_linemode"],
      ["v     -> visual_mode",        ev(Qt.Key_V,      N),   "visual_mode"],
      // --- stock bindings that must NOT be shadowed ---
      ["Alt+Left  -> nav_back",       ev(Qt.Key_Left,   A),   "nav_back"],
      ["Alt+Right -> nav_forward",    ev(Qt.Key_Right,  A),   "nav_forward"],
      ["Ctrl+C -> copy",              ev(Qt.Key_C,      C),   "copy"],
      ["Ctrl+V -> paste",             ev(Qt.Key_V,      C),   "paste"],
      ["Ctrl+X -> cut",               ev(Qt.Key_X,      C),   "cut"],
      ["Ctrl+Z -> undo",              ev(Qt.Key_Z,      C),   "undo"],
      ["Ctrl+Y -> redo",              ev(Qt.Key_Y,      C),   "redo"],
      ["Ctrl+F -> search",            ev(Qt.Key_F,      C),   "search"],
      ["Ctrl+P -> command_palette",   ev(Qt.Key_P,      C),   "command_palette"],
      ["Ctrl+H -> toggle_hidden",     ev(Qt.Key_H,      C),   "toggle_hidden"],
      ["h     -> go_up",              ev(Qt.Key_H,      N),   "go_up"],
      ["l     -> open",               ev(Qt.Key_L,      N),   "open"],
      ["j     -> move_down",          ev(Qt.Key_J,      N),   "move_down"],
      ["k     -> move_up",            ev(Qt.Key_K,      N),   "move_up"],
      ["s     -> cycle_sort",         ev(Qt.Key_S,      N),   "cycle_sort"],
      ["S     -> reverse_sort",       ev(Qt.Key_S,      S),   "reverse_sort"],
      ["Delete -> delete",            ev(Qt.Key_Delete, N),   "delete"],
      ["Ctrl+Shift+A -> select_none", ev(Qt.Key_A, C | S),    "select_none"],
      ["Ctrl+A -> select_all",        ev(Qt.Key_A,      C),   "select_all"]
    ]

    var pass = 0, fail = 0
    for (var i = 0; i < cases.length; i++) {
      var got = resolver.actionFor(cases[i][1])
      if (got === cases[i][2]) { pass++ }
      else { fail++; console.log("FAIL  " + cases[i][0] + "  got=" + got) }
    }
    console.log("keymap: " + pass + " passed, " + fail + " failed, " + cases.length + " total")
    Qt.exit(fail === 0 ? 0 : 1)
  }
}
