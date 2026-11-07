# Translation parity — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `4c759f350accd7b709978af2afc4dc56d0bc0dc8` |
| Domain | `raider` |
| Upstream messages (source + data) | **39** scanned, **38** real + 1 from a dead `/* */` block (`Devices`, `src/raider-window.c:129-141`, confirmed never emitted and never in any catalogue — not a gap) |
| Ported, byte-identical, in the `.po`/`.mo` catalogues | **38 / 38**, unchanged from the last audit and re-confirmed this audit |
| Catalogues on disk | 35 `.po` + 1 `.pot` |
| Languages built and installed | **35 / 35** — **gap T1 closed this round** |
| Live non-English-locale check | exists and passes — **gap T3 closed this round** |
| Open gaps | **T2 (changed shape), T4 (new)** |

## gap T1 — Polish, closed

`po/pl.po` was on disk but absent from `po/LINGUAS`, so a complete donated
Polish translation never reached a user even though 34 others did. This
round added `pl` to `po/LINGUAS` (now 35 lines, confirmed:
`wc -l po/LINGUAS` → 35) and rewrote the `Rakefile`'s `.mo` task to compile
the flat `po/<lang>.po` files directly with `msgfmt` rather than assuming a
nested per-locale layout. `spec/translation_spec.rb:40` now asserts a
catalogue exists for **every** `.po` on disk (`languages.length == 35`,
`languages.sort == po_languages`) instead of pinning the hole as expected
behaviour. Confirmed this audit: `rake gettext:mo` produces
`data/locale/pl/LC_MESSAGES/raider.mo` and the spec passes. **Closed, and
verified by an inverted check rather than a reverted one — this is how a
gap should close.**

## gap T3 — no check proved any language reaches the screen, closed

Previously, the only translation check that exercised the real binding
exercised it under the **C** locale, where "return the msgid unchanged"
looks correct whether or not `bindtextdomain`/`textdomain` actually work.
This round added a live German-locale check in two places:

* `spec/translation_spec.rb` — asserts `_('File Shredder')` returns
  `'Aktenvernichter'` and `Encoding::UTF_8` under `Locale.current = 'de'`.
* `test/drive_main_window.rb:739-744` — the same assertion inside the real
  running window, through the main loop.

Both run live this audit (`nix develop --command xvfb-run -a ruby
test/drive_main_window.rb` → `ok the marker answers the msgid in German,
live` / `ok the translated string is UTF-8`; the spec suite run shows the
same case passing). **Closed.**

## gap T2 — restated: the `.pot` is no longer stale, but it now silently drops 7 keys

The previous audit's T2 said the shipped `.pot` was upstream's own stale
artifact, citing four source files that do not exist in this repository.
This round regenerated it via `rake gettext:pot:create`
(`Rakefile:204-211`, `task.files = File.readlines("po/POTFILES", ...)`),
and the new `.pot`'s `#:` references now correctly cite `lib/exit_dialog.rb`,
`lib/main.rb`, `lib/progress_info_popover.rb`, `lib/shortcuts_dialog.rb`
and `lib/window.rb` — real files that exist. That part of T2 is genuinely
fixed.

**But it introduced a new drop, undetected by the commit that made it.**
`po/POTFILES` still lists `data/com.github.ADBeveridge.Raider.desktop.in.in`
and `data/com.github.ADBeveridge.Raider.metainfo.xml.in.in` as source files
(confirmed: `cat po/POTFILES` includes both), and the task hands them to
`GetText::Tools::Task`, which is a **Ruby** string-extractor — it has no
parser for `.desktop.in.in`'s `Name=`/`Comment=`/`Keywords=` key-value
syntax or for `.metainfo.xml.in.in`'s `<name>`/`<summary>`/`<description>`
elements. Measured this audit:

```sh
$ grep -c '^msgid "' po/com.github.ADBeveridge.Raider.pot
35
$ grep -n '"File Shredder"\|"Permanently delete your files"\|"enhancing data privacy"\|Keywords' po/com.github.ADBeveridge.Raider.pot
38:msgid "File Shredder"        # from lib/window.rb / lib/main.rb — survives
122:msgid "About File Shredder"  # from lib/main.rb — survives
```

Upstream's own `.pot` (and the port's hand-maintained `.po` files, still
byte-identical to upstream's — confirmed: `diff po/de.po <(git show
origin/main:po/de.po)` returns nothing) carry **36–38** msgids including
the desktop entry's own `Name=`/`Comment=`/`Keywords=` strings and the
metainfo's `<summary>` and `<description>` text — 7 distinct keys that are
sourced only from the two `data/*.in.in` templates and never duplicated in
Ruby source. The regenerated port `.pot` has **35** msgids and **none** of
those 7 data-only keys.

**This has not yet cost a translation.** The `.po` files were not
regenerated from this `.pot` this round — they are still the untouched,
byte-identical copies of upstream's catalogues, so today a user in any of
the 35 languages still gets all 38 strings translated. The gap is latent:
the moment anyone runs the normal gettext workflow this `.pot` exists to
drive — `msgmerge`/`rake gettext:po:create` against `po/*.po` — those 7
keys drop out of all 35 catalogues simultaneously, because the merge tool
trusts the `.pot` as the current, authoritative key set. A translator
opening this `.pot` today to see what needs translating would also not be
told the app has a desktop entry or a metainfo file to translate at all.

Owed: either extend `po/POTFILES`-driven extraction to parse the two
`.in.in` templates the way `msgfmt --desktop`/`--xml` already merges them
at build time, or split the `.pot` task so the two data templates are
still represented in the generated template even though `GetText::Tools::Task`
cannot read them — upstream's own `.pot` is the reference for what the
combined key set should look like. Until one of those lands, this `.pot`
is a correct description of the Ruby source and an incorrect description of
the whole translatable surface, and anyone who merges it will not find out
until 7 strings silently stop being translatable in every one of the 35
languages this port ships.

## gap T4 (new) — this gap was invisible to the commit that caused it

Commit `4c759f3`'s own message states T2 as closed ("regenerate
`po/com.github.ADBeveridge.Raider.pot` from the port's own `lib/*.rb`
sources") without noting that the regeneration narrowed the key set, and
`PORTING.md`'s "This round's changes" section repeats the same framing
("It no longer cites files that do not exist in this repository") without
mentioning what stopped being cited along with them. Neither statement is
false on its own terms, but together they read as "T2 is closed" when the
honest state is "T2's staleness is fixed and a narrower, latent gap
replaced it." This is recorded as its own line in
`accountability-ensurance.md` rather than folded into T2's text, because
the point is not the translation gap — it is that a fix shipped and was
described as complete by the same pass that introduced the regression
inside it, and nothing caught it before this audit.

## Catalogues

`po/LINGUAS` (35 lines) and all 35 `.po` files remain byte-identical to
upstream (re-diffed this audit for the full set, not merely sampled: `for f
in po/*.po; do diff "$f" <(git show origin/main:"$f"); done` — all empty).
Fourteen years of donated work is intact on disk and unaffected by the
`.pot` regeneration described above.

## Step 5, the runtime check

Now a check the port makes itself (gap T3, closed) — see above. Re-run by
hand this audit for a second data point: `LANGUAGE=de LC_ALL=de_DE.UTF-8`
against the window's title, empty-state label and shred-button label all
come back translated and `Encoding::UTF_8`.

## Rules check

* Never reworded an upstream string while porting it — unaffected, still
  byte-identical.
* No `#{}` inside a marked string — unaffected.
* No plural renumbered — unaffected (upstream has none in this app).
* No domain invented — `raider`, matching upstream's `i18n.gettext('raider', ...)`.
* Never counted a row `ported` from reading code alone — the catalogue
  census and a live diff back both claims in this report.
* The previous report's "0/78 languages" framing from an earlier round and
  this round's "T2 closed" framing are both corrected on evidence rather
  than carried forward: T1 is genuinely closed (35/35 languages built), and
  T2 is only half-closed, with the other half (T4) now named explicitly
  instead of absorbed into a clean-looking "closed" line.
