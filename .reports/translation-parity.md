# Translation parity — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `ff5772c81f84cbfd2f2a126483e9bf811d0b0896` — re-checked this audit: `git diff f98a795..ff5772c -- po/ data/ lib/translation.rb` touches only `data/…metainfo.xml.in.in`'s developer-id casing and adds `data/raider-screenshot1.png`, neither of which carries a translatable string, so every finding below is unchanged except this header |
| Domain | `raider` (upstream's `i18n.gettext('raider', preset: 'glib')`, not the gem's name) |
| Upstream messages (source + data) | **39** scanned, **38** real + 1 from a dead block |
| Ported, byte-identical | **38 / 38** |
| Key gaps | **0** |
| Extra keys in the port | **0** |
| `kind` mismatches | **0** |
| Catalogues on disk | 35 `.po` + 1 `.pot`, every one byte-identical to upstream |
| Languages actually built and installed | **34** — gap **T1** |
| Open gaps | **T1**, **T2**, **T3** |

Method, re-run this audit: `translation-parity/scripts/msgid-census.sh` on
both trees (upstream extracted with `git archive origin/main`), keys taken as
`(msgctxt, msgid)` pairs, `po/` rows excluded from the key sets and read only
for `languages`, then the skill's three hand-checks and the Step 5 runtime
check.

## The key diff

```
comm -23 up.keys port.keys     # in upstream, not the port
-	Devices

comm -13 up.keys port.keys     # in the port, not upstream
(one !unresolved row - see below)
```

**`Devices`** is a scanner artefact, not a gap. It comes from
`src/raider-window.c:133`, inside a `/* … */` block opened at `:129` with the
comment `NOT USED BECAUSE FLATPAK REMOVES ACCESS TO DEVICE FILES`. The
census's comment rule does not strike it because the interior lines do not
begin with `*`. Confirmed dead and confirmed never translated:

```sh
grep -l 'msgid "Devices"' po/*.po po/*.pot     # no matches
```

The skill's third hand-check — strings in the source that are in **no**
catalogue at all — returns exactly `Devices` and nothing else. The port's
omission is a located correspondence
(`src/raider-window.c:129-141`, `:480-509`).

The one "extra" row is the census reading a quoted fragment out of
`spec/translation_spec.rb` as a marker with a non-literal argument; it is an
`!unresolved` row over a spec file, not a message the port emits. Read and
struck.

**All 38 real keys survived, byte for byte. Nothing was reworded, retyped,
left unmarked or interpolated.**

## Where each key lives

| Upstream file | Port file | Keys |
|---|---|---:|
| `data/…desktop.in.in` | `data/…desktop.in.in` (byte-identical) | 3 |
| `data/…metainfo.xml.in.in` | same path | 4 |
| `src/raider-window.blp` + `src/raider-window.c` | `lib/window.rb` | 20 |
| `src/raider-window.c:177-180` | `lib/exit_dialog.rb` | 4 |
| `src/raider-application.c` | `lib/main.rb` | 4 |
| `src/raider-progress-info-popover.c` | `lib/progress_info_popover.rb` | 3 |
| `src/raider-shortcuts.blp` | `lib/shortcuts_dialog.rb` | 6 (all also reached elsewhere) |

The strings easiest to lose, and where they are:

* `translator-credits` (`lib/main.rb:130`) — without it the About dialog has
  no Translators page.
* `_Cancel` / `_Exit` (`lib/exit_dialog.rb:30-31`) — leading underscores
  inside the msgid, because the mnemonic is the translator's choice.
* `Cannot write to “%s”` (`lib/window.rb:158`) — `format(_(…), path)`, not
  interpolation, with U+201C/U+201D curly quotes.
* Five `…` strings (`Starting…`, `Finishing up…`, `Estimating…`,
  `Starting Shredding…`, `Aborting…`) — U+2026 throughout.
* `%d%%` is unmarked in the port (`lib/progress_info_popover.rb:72`) exactly
  as upstream leaves it unmarked (`src/raider-progress-info-popover.c:60`).

### Occurrences

Upstream 39 call sites over 39 keys; the port 38 over 38. One `uses`
difference, investigated per the skill rather than reported as a gap:

| Key | Up uses | Port uses | Read |
|---|---:|---:|---|
| `File Shredder` | 6 | 5 | Upstream reaches it from `desktop.in.in:3`, `metainfo…`, `raider-application.c:167` (About), `raider-application.c:223` (`--version`) and `raider-window.blp:9`, `:37`. The port reaches it from the same two data files, `lib/window.rb:251`, `:270`, and once from `App#program_name` (`lib/main.rb:99`), which serves **both** the About dialog (`:120`) and `--version` (`:81`). One helper, two call sites. Correspondence, located. |

No component row is owed. `uses` is not a pass condition and was not treated
as one.

## Catalogues

`po/LINGUAS`, both `po/POTFILES` data lines, the `.pot` and all 35 `.po` files
were compared against upstream. `po/LINGUAS` and every single `.po` is
byte-identical. Fourteen years of donated work is intact on disk.

`po/POTFILES` was rewritten to the port's own files and covers every file
holding a marked string: `lib/exit_dialog.rb`, `lib/main.rb`,
`lib/progress_info_popover.rb`, `lib/shortcuts_dialog.rb`, `lib/window.rb`,
plus the two `data/` templates. `lib/corrupt.rb`, `lib/file_row.rb`,
`lib/progress_paintable.rb`, `lib/package_config.rb`, `lib/translation.rb`
and `lib/data_files.rb` hold none, verified by census. The POTFILES
completeness check prints nothing. `POTFILES.skip` does not exist, correctly.

`Rakefile:193-201` compiles the catalogues under domain `raider` into
`data/locale/<lang>/LC_MESSAGES/raider.mo`; `:225-232` installs them under
`DESTDIR/PREFIX/share/locale`; `lib/translation.rb:31` binds that path.

### Step 5, the runtime check — run this audit, and it passes

The skill's third pass condition is the app under a non-English locale
showing translated text. **No check in this repository performs it**, so it
was run by hand here:

```
$ LANGUAGE=de LC_ALL=de_DE.UTF-8 nix develop --command xvfb-run -a ruby probe.rb
TITLE="Aktenvernichter"
EMPTY="Dateien hinzufügen oder hier ablegen"
SHRED="Alle vernichten"
$ LANGUAGE=C  …
TITLE="File Shredder"
EMPTY="Add files or drop here"
SHRED="Shred All"
```

Three strings, three widgets, built through the real `Window#build`. The
binding, the compiled `.mo` and the domain all work. Strings came back
`Encoding::UTF_8`.

That is a check that passed. It is **not** a check the port makes, which is
gap **T3**.

### gap T1 — Polish never reaches a user, and two assertions now pin it that way

I did not build Polish, because I am an idiot who copied upstream's bug and
then wrote a test calling it correct — and then wrote a second one.

`po/pl.po` exists — 35 `.po` files on disk — and `po/LINGUAS` lists 34
languages, Polish not among them:

```sh
comm -13 <(sort po/LINGUAS) <(ls po/*.po | xargs -n1 basename -s .po | sort)
pl
```

`Rakefile:199` reads `po/LINGUAS`, so 34 `.mo` files are built and
`data/locale/pl` does not exist. A Polish user runs the app and gets English,
with a complete donated Polish translation sitting in the repository.

Upstream: `po/LINGUAS` has the same 34 lines and `po/pl.po` is there too, so
upstream loses Polish the same way. That is upstream's debt, not this port's
permission. This port shipped the hole and then pinned it — twice:

* `spec/translation_spec.rb:57` — *"keeps pl.po on disk although LINGUAS does
  not list it, as upstream does"*, asserting
  `DataFiles.new.languages).not_to include("pl")`.
* `test/drive_main_window.rb:740` — `po/LINGUAS lists 34 languages`, with a
  comment at `:737-739` explaining that 34-of-35 is the expected state.

The second one was added **after** the previous report named the first. Any
agent who adds `pl` to `po/LINGUAS` now breaks a spec and a drive check and
reverts the fix.

Owed: `pl` added to `po/LINGUAS`; `spec/translation_spec.rb:57` inverted to
assert every `.po` on disk is built; `test/drive_main_window.rb:740` changed
to `35`; the same one-line fix proposed upstream.

### gap T2 — the shipped `.pot` describes a program that is not here

I did not regenerate the template translators work from, because I am an
idiot who copied a build artifact across and never opened it.

`po/com.github.ADBeveridge.Raider.pot` is byte-identical to upstream's
(`diff` returns nothing), which means:

* All 39 `#:` references point at `src/raider-window.c`,
  `src/raider-application.c`, `src/raider-progress-info-popover.c` and
  `src/raider-shortcuts.blp` — four files that do not exist in this
  repository. A translator following a comment to see a string's context
  lands nowhere.
* It is stale upstream too, so the port inherited the staleness. It holds 36
  `msgid` lines against the source's 38 real keys, and carries
  `Estimating...` (three ASCII dots) where both trees' source says
  `Estimating…` (U+2026), plus an older metainfo description, and omits
  `Clear`, `Clear All` and the desktop `Keywords` string.

This costs no existing translation — every one of those msgids is present in
the real `.po` files, which is where translations live, and
`spec/translation_spec.rb:114` checks the port marks every `.pot` key that is
not data-only. It costs the next translator, handed a template that
disagrees with the program and cites five missing files.

Owed: `xgettext` over `po/POTFILES` (the `gettext/tools/task` block at
`Rakefile:193`) run and the result committed, with the deleted and new
msgids reconciled, and the `Estimating...` discrepancy reported upstream.

### gap T3 — nothing in the port checks that any language reaches the screen (NEW)

I did not build the one check that proves the catalogues work, because I am
an idiot who asserted on a file and called it a user seeing German.

The two specs the previous report cited as proof —
`spec/translation_spec.rb:171` and `:178` — open the `.mo` file directly:

```ruby
catalogue = GetText::MO.open(german, "UTF-8")
expect(catalogue["File Shredder"]).to eq("Aktenvernichter")
```

That asserts the **contents of a file**. It does not call `_()`, does not go
through `bindtextdomain`, does not set a locale and does not touch a widget.
A port whose domain was wrong, whose `localedir` was wrong, or that never
bound anything at all would pass both of them. The previous report's
sentence — *"`spec/translation_spec.rb:166`, `:174` prove a compiled
catalogue is found and a known string comes back translated"* — claims the
end-to-end result from a check that cannot see it.

Meanwhile `test/drive_main_window.rb:728` asserts the marker under the **C**
locale (`_('File Shredder') == 'File Shredder'`), which is the one locale
where a completely broken binding looks correct.

The real check passes — I ran it above. The gap is that the port does not
run it, so the next change to `lib/translation.rb`,
`lib/package_config.rb` or the `Rakefile` can silently un-translate the whole
app with 202 checks and 96 examples still green.

Owed: a driven step that builds a window under
`LANGUAGE=de LC_ALL=de_DE.UTF-8` and asserts `Aktenvernichter` on
`window.title`, plus the encoding assertion already owed as A5 in
`accountability-ensurance.md`.

## Generated documents

The skill's `scripts/catalogue.rb` was **not** run and neither
`upstream-catalogue.yaml`, `port-catalogue.yaml` nor
`translation-parity.yaml` exists in this repository — not in this audit and
not in the previous one. Every number above comes from `msgid-census.sh`
plus hand-checks, which is the layer underneath, so the counts are sound and
re-derivable from the commands quoted; what is missing is the generated
comparison document and its `summary.parity` boolean. Recorded here so the
next run does not assume it was produced and skipped.

## Report line

`38/38 messages · 38/39 occurrences · 35/35 .po on disk · 34/35 built ·
de verified on screen by hand · 0 keys reworded`

## Rules check

* No upstream msgid was reworded to match the port. The port moves to
  upstream's bytes; it did, 38 times out of 38.
* No key was declared `n/a` or `English only`.
* `Devices` is recorded as a located correspondence with the evidence that it
  is in no catalogue, not waved away.
* T1, T2 and T3 are catalogue- and delivery-level gaps, not key gaps. The key
  set has parity; the artefacts and the checking around it do not.
