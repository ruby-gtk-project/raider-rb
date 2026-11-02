# Translation parity — raider-rb

| | |
|---|---|
| Upstream | `main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `fe65d4fc528569b77548e6cf8bb744135603ce5b` |
| Domain | `raider` (`meson.build`: `config_h.set_quoted('GETTEXT_PACKAGE', 'raider')`) |
| Upstream messages | **35** in the shipped `.pot`; **37** marked in upstream source |
| Ported | **0** |
| Gaps | **37** |
| Extra (untranslated, port-only) | **4** |
| Upstream occurrences | 45 across 35 messages (10 reused); 47 across 37 counting source-only |
| Port occurrences | **0** marked — 30 of the 37 exist as bare Ruby literals, 7 do not exist at all |
| Upstream languages | 35 `.po` files, 34 listed in `LINGUAS`; 1,307 translated, 10 untranslated, 10 fuzzy |
| Languages shipped by the port | **0** |
| Build command | **none** — the port has no `po/`, no gettext gem, no `bindtextdomain`, no `.mo` task |

## The state in one line

`grep -rn '_(' lib/ exe/` returns nothing. There is no `gettext` require, no
`bindtextdomain`, no `po/` directory and no Rakefile task that could build a
`.mo`. Every user-visible string in the port is an English literal frozen into
the source. 1,307 existing translations across 34 languages are unreachable
from this port today, and none of them was the port's to earn — they were
already paid for upstream and the port dropped the key that opens them.

## src/raider-window.blp + src/raider-window.c → lib/window.rb, lib/exit_dialog.rb (15 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 1 | — | `File Shredder` | single | 4 → 0 | `lib/window.rb:22`, `:259`; `lib/main.rb:39`, `:82`, `:100` — all unmarked | **gap** | `File Shredder` |
| 2 | — | `Add` | single | 1 → 0 | `lib/window.rb:278` unmarked | **gap** | `Add` |
| 3 | — | `Main Menu` | single | 1 → 0 | `lib/window.rb:287` unmarked | **gap** | `Main Menu` |
| 4 | — | `Add files or drop here` | single | 1 → 0 | `lib/window.rb:345` unmarked | **gap** | `Add files or drop here` |
| 5 | — | `Shredding is the obfuscation of a file with random data so the previous contents cannot be recovered.` | single | 1 → 0 | `lib/window.rb:39-40` unmarked (bytes verified identical) | **gap** | as written |
| 6 | — | `Shred All` | single | 2 → 0 | `lib/window.rb:389`, `:211` unmarked | **gap** | `Shred All` |
| 7 | — | `Abort All` | single | 2 → 0 | `lib/window.rb:398`, `:472` unmarked | **gap** | `Abort All` |
| 8 | — | `New Window` | single | 2 → 0 | `lib/window.rb:304` unmarked (1 of 2 sites) | **gap** | `New Window` |
| 9 | — | `Keyboard Shortcuts` | single | 2 → 0 | `lib/window.rb:310` unmarked; also `lib/shortcuts_dialog.rb:17`, `:25` | **gap** | `Keyboard Shortcuts` |
| 10 | — | `About File Shredder` | single | 1 → 0 | `lib/window.rb:311` unmarked | **gap** | `About File Shredder` |
| 11 | — | `Open Folder` | single | 1 → 0 | `lib/window.rb:324` unmarked | **gap** | `Open Folder` |
| 12 | — | `Stop Shredding?` | single | 1 → 0 | `lib/exit_dialog.rb:12` unmarked | **gap** | `Stop Shredding?` |
| 13 | — | `Are you sure that you want to exit?` | single | 1 → 0 | `lib/exit_dialog.rb:13` unmarked | **gap** | `Are you sure that you want to exit?` |
| 14 | — | `_Cancel` | single | 1 → 0 | `lib/exit_dialog.rb:25` unmarked | **gap** | `_Cancel` (keep the mnemonic underscore) |
| 15 | — | `_Exit` | single | 1 → 0 | `lib/exit_dialog.rb:26` unmarked | **gap** | `_Exit` (keep the mnemonic underscore) |

## src/raider-window.c, runtime strings → lib/window.rb (8 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 16 | — | `Could not remove filename from quick list. Please report this.` | single | 1 → 0 | **nowhere** — the error state itself is not ported (`.reports/component-parity.md`, window gap 5) | **gap** | `Could not remove filename from quick list. Please report this.` |
| 17 | — | `Finished shredding files` | single | 1 → 0 | `lib/window.rb:37` unmarked | **gap** | `Finished shredding files` |
| 18 | — | `This file was already added` | single | 1 → 0 | `lib/window.rb:34` unmarked | **gap** | `This file was already added` |
| 19 | — | `Some files did not exist` | single | 1 → 0 | `lib/window.rb:35` unmarked | **gap** | `Some files did not exist` |
| 20 | — | `Cannot write to “%s”` | single | 1 → 0 | `lib/window.rb:147` unmarked, via `format(...)` | **gap** | `Cannot write to “%s”` — U+201C/U+201D curly quotes, `%s` not `#{}` |
| 21 | — | `Cannot load more files` | single | 1 → 0 | `lib/window.rb:36` unmarked | **gap** | `Cannot load more files` |
| 22 | — | `Starting Shredding…` | single | 1 → 0 | `lib/window.rb:201` unmarked **and never rendered** | **gap** | `Starting Shredding…` (U+2026) |
| 23 | — | `Aborting…` | single | 1 → 0 | `lib/window.rb:222` unmarked **and never rendered** | **gap** | `Aborting…` (U+2026) |

Rows 22 and 23 wait on a component gap as well as a message gap: even once
marked, the user never sees either string, because the port overwrites both
labels in the same main-loop turn. Named in `.reports/component-parity.md`,
window gaps 3 and 4; do not close these rows on the marking alone.

## src/raider-shortcuts.blp → lib/shortcuts_dialog.rb (5 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 24 | — | `General` | single | 1 → 0 | `lib/shortcuts_dialog.rb:14` unmarked | **gap** | `General` |
| 25 | — | `Add Files` | single | 3 → 0 | `lib/shortcuts_dialog.rb:15`; also `lib/window.rb:280`, `lib/main.rb:179` | **gap** | `Add Files` |
| 26 | — | `Close Window` | single | 1 → 0 | `lib/shortcuts_dialog.rb:18` unmarked | **gap** | `Close Window` |
| 27 | — | `Quit` | single | 1 → 0 | `lib/shortcuts_dialog.rb:19` unmarked | **gap** | `Quit` |
| — | — | (`New Window`, `Keyboard Shortcuts`) | — | — | counted once, rows 8 and 9 | — | — |

## src/raider-application.c → lib/main.rb (3 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 28 | — | `Add Folders` | single | 1 → 0 | `lib/main.rb:190` unmarked | **gap** | `Add Folders` |
| 29 | — | `translator-credits` | single | 1 → 0 | **nowhere** — `about_dialog` never sets it; read back live as `""` | **gap** | `translator-credits` (the magic msgid; gettext returns the per-language translator list) |
| — | — | (`Add Files`, `File Shredder`) | — | — | counted once, rows 25 and 1 | — | — |

Row 29 is the one that stings: 34 catalogues already carry a translator list
under this exact msgid, and the port's About dialog has no Translators page to
show it in.

## src/raider-progress-info-popover.c → lib/progress_info_popover.rb (3 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 30 | — | `Starting…` | single | 1 → 0 | `lib/progress_info_popover.rb:19` unmarked | **gap** | `Starting…` (U+2026) |
| 31 | — | `Finishing up…` | single | 1 → 0 | `lib/progress_info_popover.rb:20` unmarked | **gap** | `Finishing up…` (U+2026) |
| 32 | — | `Estimating...` | single | 1 → 0 | `lib/progress_info_popover.rb:21` is `'Estimating…'` | **gap** ⚠ | **`Estimating...`** — three ASCII full stops. See the note below |

⚠ Row 32 is a trap. `src/raider-progress-info-popover.c:75` reads
`_("Estimating…")` with U+2026, but the shipped `.pot` and all 35 catalogues
are keyed on `Estimating...` with three ASCII dots — the `.pot` went stale
before the character was changed. **Upstream's own binary therefore shows this
string untranslated in every language.** The port copied the source bytes
(U+2026), which is the right call per the "byte-identical to upstream source"
rule, but it means that when `po/` is copied in, this one key will still miss.
Do not reword it to match the catalogue: fix it upstream, or carry it as a
known-unmatched key and say so here. Either way the row stays a gap.

## data/*.in.in → no port file (4 messages)

| # | msgctxt | msgid | Kind | Uses | Port site | State | Text still owed |
|---|---|---|---|---|---|---|---|
| 33 | — | `Permanently delete your files` | single | 2 → 0 | **nowhere** — no `.desktop`, no metainfo | **gap** | `Permanently delete your files` |
| 34 | — | `File Shredder is a file deletion program for the GNOME desktop environment. It is designed to permanently remove sensitive files from your computer, enhancing data privacy.` | single | 1 → 0 | **nowhere** | **gap** | the `.pot` wording above, **not** the current metainfo wording (see note) |
| 35 | — | `Within a certain limit, it is effective. However, modern SSDs use certain technologies to extend its lifetime, which has the side effect of ensuring that shredding is never perfect, and no software can fix that. But shredding significantly increases the difficulty of data recovery since it requires specialized software and hardware.` | single | 1 → 0 | **nowhere** | **gap** | as written |
| — | — | (`File Shredder`) | — | — | counted once, row 1 | — | — |

Note on row 34: `data/com.github.ADBeveridge.Raider.metainfo.xml.in.in:9`
currently reads "File Shredder is a file deletion program designed to
permanently remove sensitive files from your computer, enhancing data privacy."
— the `.pot` key still has the older "for the GNOME desktop environment"
wording. The catalogues are keyed on the `.pot`, so that is the string 34
languages can actually resolve. Another stale-`.pot` divergence upstream, in a
second file. Recorded, not silently normalised.

## Source-only messages (2) — marked upstream, absent from the shipped `.pot`

| # | msgid | Where upstream | Port site | State | Text still owed |
|---|---|---|---|---|---|
| 36 | `Clear` | `src/raider-window.blp:93` `label: _("Clear")` | `lib/window.rb:382` unmarked | **gap** | `Clear` |
| 37 | `Clear All` | `src/raider-window.c:387` `_("Clear All")` | `lib/window.rb:210` unmarked | **gap** | `Clear All` |

`po/POTFILES` lists both `src/raider-window.blp` and `src/raider-window.c`, so
these two should be in the `.pot` and are not: upstream has not regenerated it.
They are real marked messages in upstream source and therefore real rows here.
Marking them in the port means the port's template will carry 37 keys where
upstream's carries 35 — which is correct, and should go upstream rather than be
trimmed to match.

## Extra — strings the port invented (4)

Each is English-only in an app with 34 catalogues, and none has an upstream
counterpart. They are not parity work, and they are not free.

| Port string | Site | Why it exists |
|---|---|---|
| `Remove` | `lib/file_row.rb:122` (tooltip) | nothing upstream — an invented tooltip |
| `Shredding Progress` | `lib/file_row.rb:136` (tooltip) | nothing upstream — an invented tooltip |
| `Keyboard Shortcuts` as the dialog's own title | `lib/shortcuts_dialog.rb:25` | upstream sets no title and lets libadwaita supply its translated default; the port's literal shadows it. Already row 9 as a msgid, but this *site* is extra |
| `The Ruby port has not been written yet.` + `raider` | `lib/raider/application.rb:48-49`, `:38` | the dead scaffold, still required by `lib/raider.rb:3` and still inside `spec.files` |

The first two should be deleted, not translated. The last two should be deleted
with the file.

## What else lives in upstream's `po/`

Measured, because a port that copies the directory inherits all of it:

- **35 `.po` files, 34 shipped.** `po/pl.po` exists and is **not** in
  `po/LINGUAS`, so upstream's build never installs Polish. Copy `LINGUAS`
  verbatim; do not "fix" it by adding `pl`, and do not delete `pl.po` — the
  next Polish contributor starts from it.
- **1,307 translated, 10 untranslated, 10 fuzzy** (obsolete `#~` blocks
  excluded from all three counts). The 10 fuzzy entries are the cheapest work
  in the directory and will show as English until someone clears the flag:
  `rmsgfmt` drops fuzzy entries from the `.mo` exactly as GNU `msgfmt` does.
- **Two files have CRLF line endings: `po/kk.po` and `po/nl.po`.** Normalise on
  read in any scanner — a tool that splits entries on `\n\n` reports Kazakh and
  Dutch as zero-message files, which reads as two languages nobody ever
  translated. Do not rewrite the files.
- **`po/POTFILES`** (not `POTFILES.in`) lists 2 data files and 5 source files.
  The port's equivalent must point at `lib/*.rb` and must list **every** file
  with a marked string, or the template silently shrinks.

## Step 4, not yet started

The discipline the port owes, in order:

1. Copy upstream's whole `po/` into the port unchanged — all 35 `.po`,
   `LINGUAS` verbatim, `POTFILES` rewritten to the `lib/` paths. **First**, so
   every later row is verifiable.
2. Keep the domain `raider`. It is `meson.project_name()` upstream and it is
   the `.mo` lookup key the 34 catalogues are filed under. Not `raider-rb`.
3. Add `gettext`, `bindtextdomain('raider', ...)`, a `rake gettext:mo` task, and
   an install path.
4. Mark all 37 rows. `%s` stays `%s` — never `#{}` inside a marked string.
   Mnemonic underscores stay. Ellipses stay U+2026 where upstream's source has
   them.

## Checks not run

- No `.mo` was built and no translated run was attempted, because there is
  nothing to build. The claim "0 of 35 ported" rests on the census of the port
  (zero marked strings), not on a runtime check.
- The per-language table (which of the 34 are near-complete) was not produced;
  only the totals were measured.
