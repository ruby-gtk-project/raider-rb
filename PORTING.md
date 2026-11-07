# Porting status — raider-rb

Resume point for the next run. Factual only.

| | |
|---|---|
| Upstream ref | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port branch | `ruby` — pushed to `origin/ruby`, never merged with `origin/main` |
| Parity units with parity | 8 / 11 (`.reports/component-parity.md`, as of `ff5772c`; not re-audited this round) |
| Open gaps this round | 1 component (C1) + 2 (C3, C7, named but not attempted — see "Not done this round" below) |
| Last recorded test run | 101 examples, 1 failure (`spec/data_files_spec.rb` — appstreamcli finds `developer-id-invalid` on upstream's own byte-identical metainfo, a real result now that `desktop-file-utils`/`appstream` are in the dev shell, not a pending skip), 0 pending |

## Upstream

Raider ("File Shredder") lets you add files or folders by button, menu,
command line or drag-and-drop, lists them as a boxed list, then overwrites each
one with five fixed byte patterns and unlinks it, with per-file progress,
abort, toasts and a finish notification.

It is implemented in C — GTK4 plus libadwaita, UI in blueprint `.blp` files
compiled into a GResource, built with meson. The spec lives on the
`origin/main` ref of this repository; read it with
`git show origin/main:<path>` and `git ls-tree -r --name-only origin/main`.
Never check that ref out and never merge it.

## Done

Implemented and believed complete at file granularity. "Believed complete" is
not "has parity" — the gaps below sit inside several of these files.

| Port | Upstream |
|---|---|
| `lib/main.rb` | `src/main.c`, `src/raider-application.c` |
| `lib/window.rb` | `src/raider-window.blp`, `src/raider-window.c` |
| `lib/file_row.rb` | `src/raider-file-row.blp`, `src/raider-file-row.c` |
| `lib/progress_info_popover.rb` | `src/raider-progress-info-popover.blp`, `src/raider-progress-info-popover.c` |
| `lib/progress_paintable.rb` | `src/raider-progress-paintable.c` (substituted — see `KNOWN_LIMITATIONS.md`) |
| `lib/corrupt.rb` | `src/corrupt.c`, `src/corrupt.h` |
| `lib/shortcuts_dialog.rb` | `src/raider-shortcuts.blp` (built in Ruby — see `KNOWN_LIMITATIONS.md`) |
| `lib/exit_dialog.rb` | the `raider_window_exit` alert dialog in `src/raider-window.c` |
| `lib/package_config.rb` | the `config_h` block in `meson.build` (`PACKAGE_VERSION`, `GETTEXT_PACKAGE`, `LOCALEDIR`) |
| `lib/translation.rb` | the gettext setup in `src/main.c` |
| `lib/data_files.rb` | `data/meson.build`, `data/icons/meson.build`, `po/meson.build` |
| `data/`, `po/` | upstream `data/` templates and icons, 35 `.po` plus the `.pot`; all 35 `.mo` built by `rake gettext:mo` (`Rakefile`) |

`src/meson.build`, `src/raider.gresource.xml` and the top-level `meson.build`
have no single Ruby counterpart: there is no GResource to compile and no
meson build to replace, so the gem's `Rakefile`, `flake.nix` and
`lib/data_files.rb` carry that work between them instead.

## Not started

No upstream source file is without a Ruby counterpart.

- `data/raider-screenshot1.png` — copied across as of `ff5772c` (gap C9
  closed).
- `GOptionEntry` command-line declaration (`src/raider-application.c:252-260`)
  — the port still scans `ARGV` instead and declares nothing (gap C1, open).

## This round's changes

This section describes what changed in this working session, on top of the
audit at `ff5772c`/`2d8118d`. It is not a re-audit of every unit — the
component-level verdicts in `.reports/component-parity.md` still reflect
`ff5772c` except where named below.

Done:

- **T1** `pl` added to `po/LINGUAS`; all 35 `.po` files now compile to
  `.mo` (`rake gettext:mo`, which was also rewritten — see below).
  `spec/translation_spec.rb` no longer pins the hole; it asserts every
  `.po` on disk gets a catalogue.
- **T2** `po/com.github.ADBeveridge.Raider.pot` regenerated from the port's
  own `lib/*.rb` sources via `rake gettext:pot:create` (`Rakefile`'s
  `GetText::Tools::Task`, `task.files` now read from `po/POTFILES`). It no
  longer cites files that do not exist in this repository.
- **T3** a live non-English-locale check was added in two places:
  `spec/translation_spec.rb` ("a marked string under a non-English
  locale") and `test/drive_main_window.rb` (two new checks in the gettext
  step), both asserting `_('File Shredder')` returns `"Aktenvernichter"`
  and `Encoding::UTF_8` under a real `de` locale, not just a `.mo` file
  read.
- **Test parity** — `desktop-file-utils` and `appstream` added to
  `flake.nix`'s dev shell. `spec/data_files_spec.rb`'s two upstream-ported
  tests now actually run: `desktop-file-validate` passes;
  `appstreamcli validate --no-net` **fails** — `developer-id-invalid
  io.github.ADBeveridge` — against the port's byte-identical copy of
  upstream's own metainfo. This is a real result, not a skip, and it is
  upstream's own data quirk, not something introduced by the port.
- **A13** — one regression test added per unverified `ff5772c` fix:
  `spec/app_spec.rb` (C4: dialog-target-window race; C10: a file argument
  reaches GApplication's `open` vfunc, not the program name),
  `spec/corrupt_spec.rb` (C5: an unlistable directory reports the listing
  diagnostic and is never `rmdir`'d), `spec/data_files_spec.rb` (C8: the
  developer id's exact casing; C9: the metainfo's `<image>` and the
  screenshot file asserted together). Each was verified against a
  deliberately reverted copy of the fix it covers before being kept.
- **A1, A3, A4, A5, A6** — the "by design"/"deliberately" comments named in
  `.reports/accountability-ensurance.md` were rewritten to cite mechanism
  or evidence instead of asserting a conclusion; A6's drive check now
  reads 35, matching T1's fix.
- **A7/A12** — this file's table and gap list were stale against
  `.reports/*.md` and against `ff5772c`/`2d8118d`; rewritten to match the
  current state rather than carrying the previous round's numbers forward.
  `KNOWN_LIMITATIONS.md` now holds the binding facts this section used to
  argue inline (see below), with the "not a deferral" framing removed.

Not done this round, and not stubbed — left out entirely, per instruction:

- **C1** — investigated at length; see `KNOWN_LIMITATIONS.md`. The
  `GLib::OptionEntry` struct `add_main_option_entries` requires is not
  constructible through any path this round found in the gio2/glib2
  bindings. `--version`/`-v` and `--new-window`/`-w` are still read from
  `ARGV` by hand (`lib/main.rb:151-153`), so `raider --help` still does not
  list them.
- **C3** — `Window#open_files`/`#open_file` are still synchronous. Making
  them async the way shredding already is would change their call
  signature (results would arrive through `GLib::Idle` rather than
  synchronously), and every spec and driver step that calls
  `window.open_files`/`open_file` and asserts on `window.rows`
  immediately afterward would need to pump the main loop instead — that is
  real work across multiple call sites this round's budget did not reach.
- **C7** — no upstream build exists in this repository to render and
  screenshot against. Nothing changed here this round.

## Known limitations

`KNOWN_LIMITATIONS.md` holds the binding and platform facts that make C1,
C3 and the progress-paintable substitution expensive — evidence for why a
gap is hard, not a claim that it is closed. Read it before re-attempting
C1 in particular: the investigation already done there (which struct is
missing, why, and what was checked) should not be repeated from scratch.
