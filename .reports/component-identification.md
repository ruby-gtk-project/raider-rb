# Component identification — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `ff5772c81f84cbfd2f2a126483e9bf811d0b0896` |
| Method | `component-identification/scripts/component-scan.sh` on both trees (upstream extracted with `git archive origin/main`), symbol table present (1301 rows), then every file read |
| Re-run | this audit, against the current tip. Confirmed against the diff of `ff5772c`: that commit only changes property values and comment text inside existing methods (`lib/main.rb`, `lib/window.rb`, `lib/corrupt.rb`, `lib/file_row.rb`) plus two data files — it adds no widget, no action, no signal connection and removes none, so every row below is unchanged from the previous identification pass except the header's commit reference. |

## Step 1 — the declarative files

Upstream has four, and they are the unit list:

| Declarative file | Root | Unit |
|---|---|---|
| `src/raider-window.blp` | `template $RaiderWindow : Adw.ApplicationWindow` | window |
| `src/raider-file-row.blp` | `template $RaiderFileRow : Adw.ActionRow` | file row |
| `src/raider-progress-info-popover.blp` | `template $RaiderProgressInfoPopover : Gtk.Popover` | progress popover |
| `src/raider-shortcuts.blp` | `Adw.ShortcutsDialog shortcuts_dialog` (named root, no `template`, no backing source) | shortcuts dialog |

Two menu models live in `raider-window.blp` and produce no scan rows, being
all lowercase keywords: `primary_menu` (2 sections, 3 items) and `open_menu`
(1 section, 1 item). Counted by hand.

The port has no `.blp`/`.ui` files; every widget is a memoized accessor, which
is the house style.

## File mapping (unioned before any comparison)

```
src/main.c + src/raider-application.c              -> lib/main.rb + exe/raider + lib/package_config.rb
src/raider-window.blp + src/raider-window.c        -> lib/window.rb + lib/exit_dialog.rb
src/raider-file-row.blp + src/raider-file-row.c    -> lib/file_row.rb
src/raider-progress-info-popover.blp + .c          -> lib/progress_info_popover.rb
src/raider-shortcuts.blp                           -> lib/shortcuts_dialog.rb
src/raider-progress-paintable.c                    -> lib/progress_paintable.rb
src/corrupt.c                                      -> lib/corrupt.rb
data/meson.build + data/icons/meson.build          -> lib/data_files.rb + flake.nix installPhase
po/meson.build + src/main.c gettext calls          -> lib/translation.rb + Rakefile gettext tasks
```

Hand corrections before trusting the union (Step 2):

* The template root is one widget counted twice — `src/raider-window.c`'s
  `AdwApplicationWindow parent_instance` against the `.blp`'s
  `template $RaiderWindow : Adw.ApplicationWindow`. Struck one. Same for
  `Adw.ActionRow` (file row) and `Gtk.Popover` (popover).
* `lib/exit_dialog.rb` has no upstream file: it is the alert dialog built
  inline at `src/raider-window.c:177-185`.
* `lib/data_files.rb`, `lib/package_config.rb`, `lib/translation.rb` answer
  `data/meson.build`, the `config_h` block in `meson.build`, and
  `po/meson.build` + `src/main.c:31-33`.

## Whole-app axis totals (this run)

| Axis | Upstream distinct | Port distinct | In upstream, not the port | In the port, not upstream |
|---|---:|---:|---|---|
| widget | 20 | 21 | `Gtk.Image`, `Gtk.Widget` | `Adw.AboutDialog`, `Gtk.ApplicationWindow`, `Gtk.DrawingArea` |
| controller | 1 | 1 | — | — |
| css | 4 | 4 | — | — |
| css-name | 0 | 0 | — | — |
| signal | — | — | `mount-added`, `mount-changed`, `mount-removed` | `open` |
| action | 6 names | 1 name | all six | — |

Every row above was read before being believed:

* **`Gtk.Image`** — upstream's `gtk_image_new_from_paintable`
  (`src/raider-file-row.c:83`). The port draws the arc in a
  `Gtk::DrawingArea` instead (`lib/progress_paintable.rb:61`). A located
  substitution; it is gap **C7** in `component-parity.md`, not a missing
  widget in its own right.
* **`Gtk.Widget`** — `GtkWidget*` in C declarations. Not a component.
* **`Adw.AboutDialog`** — upstream reaches the same dialog through
  `adw_show_about_dialog` (`src/raider-application.c:169`), which names no
  type. Correspondence, located at `lib/main.rb:118-132`.
* **`Gtk.ApplicationWindow`** — only in the port's prose (`lib/window.rb:246`,
  a comment saying why it is *not* used) and in `spec/`. Not a built widget.
* **`Gtk.DrawingArea`** — the `Gtk.Image` substitution above.
* **`mount-*`** — the commented-out `GVolumeMonitor` block,
  `src/raider-window.c:129-141`. Dead upstream, inside `/* … */`.
* **`open`** — the port connects the `open` signal (`lib/main.rb:74`) where
  upstream overrides the `open` class vfunc
  (`src/raider-application.c:184`, `:238`). Same thing.
* **The six action names** are the scan's known blind spot. The port builds
  all seven from a loop over the `ACTIONS` hash (`lib/main.rb:44-52`,
  `:197-208`), so no action name is a literal and none is matched. Read off
  the install site: `open`, `open-folder`, `new-window`, `close`, `quit`,
  `about`, `shortcuts`, with accelerators `<Ctrl>o`, —, `<Ctrl>n`,
  `<Ctrl>w`, `<Ctrl>q`, —, `<Ctrl>question`. Upstream sets four explicitly
  (`src/raider-application.c:265`, `:270`, `:279`, `:284`) and gets
  `<Ctrl>question` from libadwaita.

## Repeaters, conditionals, factories

* **`FileRow`** — one per loaded file, driven by the dropped/opened file list.
  One component, variable count.
* **`floating_revealer` / `floating_box`** (`lib/window.rb:418-437`) — one
  private factory called twice each, standing for the two literal
  `Gtk.Revealer`/`Gtk.Box` pairs at `raider-window.blp:83-124`. Two call
  sites, two widgets. Not a gap.
* **Conditional:** the finish announcement is a toast when the window is
  active and a `Gio::Notification` when it is not
  (`lib/window.rb:517-525` ↔ `src/raider-window.c:238-250`). Two states, one
  of which no screenshot can show.
* **Conditional:** the exit dialog is built only while shredding
  (`lib/window.rb:193-198`).

## Stylesheet

Neither tree has a `.css` file, a `Gtk::CssProvider` or a `load(data:)`
heredoc — verified by `find` over both trees and
`grep -rn 'CssProvider\|load(data:' lib exe`. The four classes in play
(`boxed-list`, `pill`, `destructive-action`, and libadwaita's own) are
platform classes defined by GTK and libadwaita. The stylesheet axis is
vacuous for this app, in both directions.

## Unit list (11)

1. application — `src/main.c` + `src/raider-application.c` → `lib/main.rb`, `exe/raider`, `lib/package_config.rb`
2. window — `src/raider-window.blp` + `src/raider-window.c` → `lib/window.rb`
3. exit dialog — `src/raider-window.c:173-190` → `lib/exit_dialog.rb`
4. file row — `src/raider-file-row.blp` + `.c` → `lib/file_row.rb`
5. progress popover — `src/raider-progress-info-popover.blp` + `.c` → `lib/progress_info_popover.rb`
6. progress paintable — `src/raider-progress-paintable.c` → `lib/progress_paintable.rb`
7. shortcuts dialog — `src/raider-shortcuts.blp` → `lib/shortcuts_dialog.rb`
8. shredding backend — `src/corrupt.c` → `lib/corrupt.rb`
9. build constants — `meson.build` `config_h` → `lib/package_config.rb`
10. gettext binding — `po/meson.build` + `src/main.c:31-33` → `lib/translation.rb`
11. installable data — `data/meson.build`, `data/icons/meson.build` → `lib/data_files.rb`, `flake.nix`, `Rakefile`

`src/meson.build`, `src/raider.gresource.xml` and the top-level `meson.build`
hold no component. The GResource manifest lists the four `.blp` files that
units 2, 4, 5 and 7 cover; it is not a twelfth unit, and saying so is not a
licence to leave anything in it unbuilt — every resource it names is
accounted for above.

The commented-out drive/mount menu (`src/raider-window.c:129-141`, `:480-509`)
is dead in upstream's own build: it sits inside a `/* … */` block, so nothing
it declares is compiled and its one msgid reaches no catalogue (evidence in
`translation-parity.md`). It is recorded here as a located dead block, with
the location, so a reader can check rather than take it on trust.
