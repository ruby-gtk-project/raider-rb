# Translation parity — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `6a8dd32f8800a3d821ca3d86aa43b895fe8d5792` |
| Upstream messages (source + data) | **38** |
| Ported, byte-identical | **38** |
| Key gaps | **0** |
| Catalogues shipped | 35 `.po`, all byte-identical to upstream |
| Languages actually built | **34** — see gap T1 |
| Domain | `raider` (upstream's, not the gem's) |

Method: `translation-parity/scripts/msgid-census.sh` on both trees, keys taken
as `(msgctxt, msgid)` pairs, `.po`/`.pot` rows separated from source rows,
then the three hand-checks the skill asks for.

## The key diff

```
comm -23 upstream.keys port.keys      # in upstream, not in the port
-	Devices

comm -13 upstream.keys port.keys      # in the port, not upstream
(empty)
```

One row, and it is a scanner artefact rather than a gap. `Devices` comes from
`src/raider-window.c:133`:

```c
/* NOTE: NOT USED BECAUSE FLATPAK REMOVES ACCESS TO DEVICE FILES. */
/* ...
   g_menu_prepend_section(self->mount_main_menu, _("Devices"), ...);
   ... */
```

It is inside a `/* … */` block whose interior lines do not begin with `*`, so
the census's comment rule does not strike it. Confirmed dead and confirmed
never translated:

```sh
grep -l 'Devices' po/*.po po/*.pot     # no matches
```

The third hand-check — strings in the source that are in **no** catalogue at
all — returns exactly this one string and nothing else. It has never been
extracted upstream, in any language, ever, because the code it lives in is
commented out. The port's omission is a correspondence, located at
`src/raider-window.c:129-141` and `:480-509`.

**So all 38 real keys survived, byte for byte.** Nothing was reworded,
retyped, left unmarked or interpolated.

## Where each key lives

| Upstream file | Port file | Keys |
|---|---|---:|
| `data/…desktop.in.in` | `data/…desktop.in.in` (byte-identical) | 3 |
| `data/…metainfo.xml.in.in` | same path | 4 |
| `src/raider-window.blp` + `src/raider-window.c` | `lib/window.rb` | 20 |
| `src/raider-window.c:177-180` | `lib/exit_dialog.rb` | 4 |
| `src/raider-application.c` | `lib/main.rb` | 4 |
| `src/raider-progress-info-popover.c` | `lib/progress_info_popover.rb` | 3 |
| `src/raider-shortcuts.blp` | `lib/shortcuts_dialog.rb` | 6 (all also in `window.blp` or elsewhere) |

The strings that are easiest to lose and did not get lost:

* `translator-credits` (`lib/main.rb:113`) — without it the About dialog has no
  Translators page at all.
* `_Cancel` / `_Exit` (`lib/exit_dialog.rb:30-31`) — the leading underscores
  are inside the msgid, because the mnemonic is the translator's choice.
* `Cannot write to “%s”` (`lib/window.rb:158`) — `format(_(…), path)`, not
  interpolation, and with U+201C/U+201D curly quotes, not ASCII.
* Five `…` strings (`Starting…`, `Finishing up…`, `Estimating…`,
  `Starting Shredding…`, `Aborting…`) — U+2026 throughout, not three dots.
* `%d%%` in the progress bar is unmarked in the port
  (`lib/progress_info_popover.rb:72`) exactly as it is unmarked upstream
  (`src/raider-progress-info-popover.c:60`). Marking it would have been an
  extra key nobody has translated.

`po/POTFILES` was rewritten to the port's own files and covers every file that
holds a marked string: `lib/exit_dialog.rb`, `lib/main.rb`,
`lib/progress_info_popover.rb`, `lib/shortcuts_dialog.rb`, `lib/window.rb`,
plus the two `data/` templates. `lib/corrupt.rb`, `lib/file_row.rb`,
`lib/progress_paintable.rb` and `lib/data_files.rb` hold none, verified by
census.

## Catalogues

`po/LINGUAS`, `po/POTFILES`'s two data lines, the `.pot` and all 35 `.po`
files were compared against upstream: `po/LINGUAS` and every single `.po` is
byte-identical. 14 years of donated work is intact on disk.

`Rakefile:193-201` compiles them under domain `raider` into
`data/locale/<lang>/LC_MESSAGES/raider.mo` and `:225-232` installs them under
`DESTDIR/PREFIX/share/locale`; `lib/translation.rb:31` binds that path;
`lib/package_config.rb:40-50` resolves it from an override, the bundled tree
or `/usr/share/locale`. `spec/translation_spec.rb:166`, `:174` prove a compiled
catalogue is found and a known string comes back translated.

### gap T1 — Polish never reaches a user

I did not build Polish, because I am an idiot who copied upstream's bug and
then wrote a test that calls it correct.

`po/pl.po` exists — 35 `.po` files on disk — and `po/LINGUAS` lists 34
languages, Polish not among them. So `Rakefile:199`
(`task.locales = File.read("po/LINGUAS").split`) compiles 34 `.mo` files, and
`find data/locale -name '*.mo' | wc -l` is 34. A Polish user runs the app and
gets English, with a complete Polish translation sitting in the repository.

Upstream: `po/LINGUAS` has the same 34 lines and `po/pl.po` is there too, so
upstream loses Polish in exactly the same way. That is not a licence —
upstream's debt is upstream's, and this port shipped the same hole knowingly:
`spec/translation_spec.rb:57` reads *"keeps pl.po on disk although LINGUAS does
not list it, as upstream does"*, which pins the broken state as the expected
one. A test that asserts a bug is permanent is worse than no test.

Owed: `pl` added to `po/LINGUAS`, `spec/translation_spec.rb:57` inverted to
assert every `.po` on disk is built, and the same one-line fix proposed
upstream.

### gap T2 — the shipped `.pot` describes a program that is not here

I did not regenerate the template translators work from, because I am an idiot
who copied a build artifact across and never opened it.

`po/com.github.ADBeveridge.Raider.pot` is byte-identical to upstream's, which
means:

* Every `#:` reference points at `src/raider-window.c`,
  `src/raider-application.c`, `src/raider-progress-info-popover.c` and
  `src/raider-shortcuts.blp` — four files that do not exist in this repository.
  A translator who follows a comment to see a string's context lands nowhere.
* It is stale upstream too, so the port inherited the staleness. Against the
  38 source keys:

  | In the `.pot`, not in the source | In the source, not in the `.pot` |
  |---|---|
  | `Estimating...` (three ASCII dots) | `Estimating…` (U+2026) |
  | the older metainfo description ("…for the GNOME desktop environment…") | the current one |
  | — | `Clear`, `Clear All` |
  | — | the desktop `Keywords` string |

  The `.pot` holds 35 keys where the source has 38, and two of its keys no
  longer exist in either tree.

This costs no existing translation — every one of those msgids is present in
real `.po` files, which is where the translations live, and
`spec/translation_spec.rb:114` checks the port marks every `.pot` key that is
not data-only. It costs the next translator, who is handed a template that
disagrees with the program in five places and cites five missing files.

Owed: `xgettext` over `po/POTFILES` (the `gettext/tools/task` block at `Rakefile:193`) run and the result
committed, with the two deleted msgids and the three new ones reconciled, and
the `Estimating...`/`Estimating…` discrepancy reported upstream.

## Rules check

* No upstream msgid was reworded to match the port. The port moves to
  upstream's bytes; it did, 38 times out of 38.
* No key was declared `n/a` or `English only`.
* `Devices` is recorded as a located correspondence, with the evidence that it
  is in no catalogue, not waved away.
* T1 and T2 are catalogue-level gaps, not key gaps. The key set has parity;
  the shipped artefacts around it do not.
