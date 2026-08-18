# What's different in this fork

[Percius04/omafiles](https://github.com/Percius04/omafiles) with a **yazi-shaped
navigation layer** on top, plus a couple of startup and lifetime fixes. Everything
here is additive: no upstream key is rebound, no upstream feature is removed, and
every stock `Ctrl+` shortcut still does exactly what it does upstream.

Tracked as commits on the [`noc`](../../tree/noc) branch, rebased onto upstream
tags rather than carried as a patch file. `master` stays pristine upstream.

Upstream's `--selfcheck` on this branch: **124 passed, 1 failed, 125 total** —
identical to a pristine `origin/master` build, same single failure ([sent
upstream](https://github.com/Percius04/omafiles/pull/12)).

## Keys

All of these were unbound upstream. Since v1.0.0 they go through upstream's own
keybinding resolver, so they are remappable from `~/.config/omafiles/keybindings.toml`
and appear in the in-app `?` overlay like any stock binding.

| Key | Action |
|---|---|
| `←` / `→` | Up a directory / enter — mirrors `h`/`l` |
| `y` `x` `p` | Copy / cut / paste |
| `d` | Trash (same confirm dialog, still undoable) |
| `Shift+D` | Delete permanently — same confirm, no undo pushed |
| `.` | Toggle hidden files |
| `f` | Filter *this* folder, without the global search taking over |
| `z` | Zoxide jump — silent no-op if zoxide isn't installed |
| `v` | Visual (sticky range) selection |
| `m` | Cycle line info: none → meta → perms → owner |
| `Shift+P` | Toggle yazi mode (see below) |
| `1`–`9` | Jump straight to a panel |
| `g` + letter | Jump: `h` home, `d` Downloads, `o` Documents, `c` ~/.config, `p` Projects, `m` Music, `i` Pictures, `v` Videos, `t` Trash, `r` / |

`Alt+←`/`Alt+→` still navigate history, not directories — the plain arrows only
bind with no modifier held, which is what keeps those two apart.

## Behaviour

**Yazi mode** (`Shift+P`, on by default) switches the whole layout at once rather
than toggling one pane: sidebar out, parent column and preview in, list width
locked, and a `YAZI ·` marker in the status line. It's one switch because the
three columns only make sense together — toggling them separately just produced a
four-pane hybrid, and leaving the mode has to put the columns away too or "off"
looks like yazi mode with a sidebar bolted on.

**The parent column** lives *inside* the active panel, not as a panel of its own:
panels here are independent workspaces and hovering one switches the active tab,
so a parent-as-panel would hijack your path just by crossing the mouse. It
collapses where a parent would be a lie (at `/`, inside an archive, in the trash)
and forces hidden files when the current folder is itself a dotfile — otherwise
standing in `~/.config` highlights nothing.

**Scrolloff (4 rows).** Upstream scrolls only once the cursor would leave the
view, which pins it to the top or bottom line so you move blind into whatever is
coming next.

**Directories preview as a listing** — yazi's third column. Upstream closes the
preview outright on any folder row, so browsing with it open collapses the layout
constantly.

**Per-directory cursor memory.** Re-entering a folder puts the cursor back where
you left it. Session-lifetime, deliberately not persisted.

**`goUp()` lands on where you came from** rather than the top of the parent, and
sets the selection anchor too, so a `Shift`-range starts from the right row.

**Marks survive navigation.** A real multi-selection becomes marks when you leave
a folder; a single selection is just the cursor, so persisting it would mark every
folder you walked through. Copy and cut act on marks ∪ current selection —
**delete deliberately does not**, because the confirm dialog lists names from one
folder and a cross-directory delete could remove things it never showed you.

**Compact mode** also skips folder-item counting while it's on, since nothing
draws the result: counting stats every child of every visible folder. Measured on
`/usr/share`, 10 cursor moves — 22 ticks compact vs 36 not.

**Per-filetype row and icon colour**, read from a `[filetype]` section of
`shell.toml`. Every lookup falls back to the plain row colour, so a missing
section degrades to upstream's look rather than breaking.

## Startup

`omafiles --preload` becomes the single-instance server without showing a window,
so the expensive part of startup is paid once at login instead of on the first
launch you actually wait for. Launching from another app then travels the
single-instance socket instead of cold-starting.

```sh
cp packaging/omafiles-preload.service ~/.config/systemd/user/
systemctl --user enable --now omafiles-preload.service
```

Three things had to change for that to actually feel instant, because a warm
instance alone was not enough:

- the forwarding invocation used to construct a whole `QGuiApplication` — Wayland
  connection, platform plugin, fontconfig — just to write one string to a socket
  and exit. It now hands over via a raw `AF_UNIX` write before any Qt GUI init.
- a preloaded window that is never shown has no scene graph and no Wayland
  surface, so the first `show()` paid for all of it. It is shown once at startup
  and pulled back on its first frame.
- opening the folder ran *before* the window reached the screen, and the
  compositor shows nothing until the first frame arrives. The path is now opened
  from `onFrameSwapped`, so the window appears first and fills in immediately
  after.

Measured on a real session by polling `hyprctl clients` for the window actually
appearing: **~0.41–0.45s**, from ~1.24s with preload alone and a cold start of
~1.2–1.6s (fontconfig init, the QML engine, and a startup `lsblk`/`findmnt` mount
scan).

This does **not** speed up the xdg-desktop-portal Save/Open dialogs. Those bypass
the single instance by design — the portal helper treats the launched process
exiting as "dialog cancelled", so a stub that forwarded and exited would cancel
the dialog before you saw it.

## Sent upstream

| | |
|---|---|
| [#9](https://github.com/Percius04/omafiles/pull/9) | `PreviewProvider` use-after-free — a pool worker calling `invokeMethod` on the destroyed singleton, the one sibling class the v1.0.0 concurrency pass didn't cover |
| [#11](https://github.com/Percius04/omafiles/pull/11) | `"."` couldn't be bound from `keybindings.toml` — it parsed to null and was silently dropped |
| [#12](https://github.com/Percius04/omafiles/pull/12) | The P0-4 symlink check reported `VULNERABLE` on any host without the optional `ffmpegthumbnailer` |
| [#10](https://github.com/Percius04/omafiles/issues/10) | This layer, offered upstream in whatever pieces are wanted |

## Building

Unchanged from upstream:

```sh
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
ninja -C build
cmake --install build
```
