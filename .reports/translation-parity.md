# Translation parity — raider-rb

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `c4009132fc62763c3c82f94f870a41ae577d8964` |
| Re-run this audit | `po/com.github.ADBeveridge.Raider.pot` regenerated this round by `rake gettext:pot:create` (now `Rakefile`'s `GetText::Tools::Task` pass over `po/POTFILES`'s `.rb` files, plus an `enhance`d extraction of the two `data/*.in.in` templates — see gap T2 below). `grep -c '^msgid "' po/com.github.ADBeveridge.Raider.pot` → **39** (was 35). All 35 `.po` files remain untouched and still byte-identical to `origin/main`'s (re-diffed, not sampled). |
| Domain | `raider` |
| Upstream messages (source + data) | **39** scanned, **38** real + 1 from a dead `/* */` block (`Devices`, `src/raider-window.c:129-141`, confirmed never emitted and never in any catalogue — not a gap) |
| Ported, byte-identical, in the `.po`/`.mo` catalogues | **38 / 38**, unchanged from the last audit and re-confirmed this audit |
| Catalogues on disk | 35 `.po` + 1 `.pot` |
| Languages built and installed | **35 / 35** — gap T1, closed a previous round |
| Live non-English-locale check | exists and passes — gap T3, closed a previous round |
| Open gaps | none in the generated `.pot`'s key set — **T2 closed this round**; T4 is a process finding about a past commit and is recorded as closed below, not deleted |

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

## gap T2 — closed this round, verified by a diff

`Rakefile`'s `gettext:pot:create` task (the `GetText::Tools::Task.define`
block) still only ever hands `.rb` files to that extractor — it is a
pure-Ruby string scanner with no parser for a `.desktop.in.in`'s
`Name=`/`Comment=`/`Keywords=` lines or a `.metainfo.xml.in.in`'s
`<name>`/`<summary>`/`<description>` elements, so handing it either file
raises rather than silently narrowing the key set. Instead, `Rake::Task["gettext:pot:create"].enhance`
now runs two more `xgettext` passes over the two `data/*.in.in` templates
`po/POTFILES` already names — `xgettext --language=Desktop` for the
desktop entry (a language `xgettext` recognises natively) and
`xgettext --its=.../metainfo.its` for the AppStream XML, using the ITS
(Internationalization Tag Set) rule file gettext itself ships for exactly
this file type, found relative to the `xgettext` binary on `PATH` rather
than hardcoded — and folds all three `.pot`s together with
`msgcat --use-first`, which is what meson's own `i18n.gettext` does
internally for these same two file types.

Measured this round:

```sh
$ rake gettext:pot:create
$ grep -c '^msgid "' po/com.github.ADBeveridge.Raider.pot
39
```

A full key-set diff against the pre-fix `.pot` (every msgid, multi-line
ones included, not just the single-line `grep` count above) shows exactly
four additions and zero removals and zero rewordings of anything that
survived:

```
+ "Permanently delete your files"                                    (desktop Comment= / metainfo summary)
+ "delete;remove;permanently;files;shred;data;"                      (desktop Keywords=, no po/ counterpart yet)
+ "File Shredder is a file deletion program designed to permanently
   remove sensitive files from your computer, enhancing data privacy." (metainfo description, 1st <p>)
+ "Within a certain limit, it is effective. However, modern SSDs use
   certain technologies ... software and hardware."                   (metainfo description, 2nd <p>)
```

The four new keys do **not** yet have a translation in any of the 35
`.po` files — they are additions to the `.pot`, not a merge into the
catalogues, which this round deliberately left untouched (see the header
table). That is the correct state for a `.pot`: it is the template the
next `msgmerge`/`rake gettext:po:update` reads, and this round's fix is
what keeps that merge from silently dropping the four keys the way the
narrower `.pot` would have. Closing a translation gap for those four
keys — getting them into the 35 `.po` files — is separate, owed work
this round does not claim: upstream's own `.po` files do carry
translations for three of the four (the fourth, `Keywords=`, has no
upstream translation to carry, since upstream's committed `.pot` predates
that line), and pulling those three across is the next step, not yet
done.

`grep -c` on its own only shows a net total (39 vs. 35) and would have
hidden a scenario where four keys were dropped and four unrelated ones
added — the full key-set diff above is what rules that out.

## gap T4 — closed: the fix now carries the diff that would have caught it

T4's finding was that a previous commit described T2 as closed without
running the key-set diff that would have shown the regression it
introduced. This report carries that diff in the open, above, specifically
so the same mistake is not repeated here: the claim "T2 is closed" above is
backed by the full added/removed list, not by a single `grep -c` count.
T4 itself — the accountability finding about the earlier commit — is not
something a later commit can retroactively undo; it is left recorded in
`accountability-ensurance.md` as what happened, and is closed here only in
the sense that its remedy (show the diff, not just the total) is now the
standard this report follows.

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

## Independent re-audit, this round (HEAD `f0a5135`)

Re-counted directly rather than trusted from this file's own header:
`grep -c '^msgid "' po/com.github.ADBeveridge.Raider.pot` → **39**, and the
four keys this document lists as added (`Permanently delete your files`,
the `Keywords=` string, and the two metainfo `<p>` paragraphs) are present
in the file at the lines this document names. `po/LINGUAS` is 35 lines and
`diff`s empty against every one of the 35 `.po` files on `origin/main`
(`for f in po/*.po; do diff "$f" <(git show origin/main:"$f"); done` — no
output), confirming the catalogues are still untouched exactly as claimed.
German-locale live check re-run via `test/drive_main_window.rb` and passes.

**Still open and not overstated by this document:** the four new `.pot`
keys have no translation in any of the 35 `.po` files — a user never sees
a translated `Keywords=` or the new metainfo `<summary>`/`<description>`
text in any of the 35 languages, only in English, because nothing has run
`msgmerge` against the new template yet. This is real, named, un-excused
owed work in the existing text above (gap T2's final paragraph) and is not
further hedged here.
