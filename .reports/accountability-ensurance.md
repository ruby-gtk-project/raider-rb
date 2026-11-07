# Accountability ensurance — raider-rb

| | |
|---|---|
| Port | `ruby` @ `485859999051aba397cdc0ae04fe530baad81c9b` |
| Re-run this round | `grep -rniE` re-run over `lib/`, `exe/`, `PORTING.md`, `.reports/*.md`, `KNOWN_LIMITATIONS.md` against the current tree (below) — same zero hits in `lib/`/`exe/`/`KNOWN_LIMITATIONS.md`. The two commits since A14 was written (`a4cb8d0`, `4858599`) touch only `PORTING.md` and `.reports/component-inventory.md`; both re-read in full this round and carry no new excuse construction. |
| Scope | `grep -rniE` over `lib/`, `exe/`, `PORTING.md`, `.reports/*.md`, `KNOWN_LIMITATIONS.md` for excuse vocabulary; every open and newly-closed item from the prior audit re-read against the current code, not assumed closed from the commit message alone |

## This round's grep

```
$ grep -rniE "TODO|FIXME|not implemented|for now|in a future|out of scope|by design|n/a\b|not applicable|dropped delib|simplified|deliberately" lib/ exe/
(no hits)
$ grep -rniE "TODO|FIXME|not implemented|for now|in a future|out of scope|by design|n/a\b|not applicable|dropped delib|simplified|deliberately" PORTING.md .reports/*.md
(hits are all either quoted historical text being refuted, or vocabulary
 inside this file's own worked examples — read individually below)
```

`lib/` and `exe/` carry no excuse vocabulary at all, same as the prior
audit. The interesting work this round is in what changed inside
`PORTING.md`, `.reports/*.md`, `KNOWN_LIMITATIONS.md` and the code comments
the prior audit named by line number.

## Items closed this round (re-verified, not taken on faith)

| # | Where | Was | Now | Verified by |
|---|---|---|---|---|
| A1 | `spec/support/gtk.rb:11` | "The port's shredding is also asynchronous by design" | Names the mechanism: upstream's two `GTask`s and the idle-queue marshalling, with file:line | Read the current file — no "by design" anywhere in it |
| A2 | `spec/translation_spec.rb:57` (old) | A test pinning Polish as permanently excluded | Rewritten to assert every `.po` on disk gets a catalogue (35, including `pl`) | Spec runs and passes this audit; `pl` present in `DataFiles.new.languages` |
| A3 | `lib/progress_paintable.rb:28-30` | A verified correspondence argued inline, in a code comment | Moved to `component-parity.md` as gap C7; the code comment now just points there | Read the current file |
| A4 | `lib/shortcuts_dialog.rb:15` | Contained "deliberately" | Word removed; comment now describes what the dialog does and why GTK resolves accelerators live | `grep -n deliberately lib/shortcuts_dialog.rb` — no hits |
| A5 | `lib/translation.rb:20-22` | An unverified reason stood in for `bind_textdomain_codeset` | Cites the live German-locale `Encoding::UTF_8` check as the actual evidence | Read the current file; the cited spec exists and passes |
| A6 | `test/drive_main_window.rb:737-740` | A2's exclusion, written a second time after being reported once | `po/LINGUAS lists all 35 languages` / `and every one of them has a catalogue` | Drive run this audit: both checks pass |
| A8 | `.reports/test-parity.md` (old) | **False green**: "both actually ran and passed" about tests that had never executed | Both now genuinely execute (one passes, one fails on upstream's own defect) and the new report says so with the live result | Spec suite run this audit: 101 examples, 1 failure, matching the claim |
| A9 | `.reports/translation-parity.md` (old) | **False green**: an end-to-end translation claim resting on a file read | A live locale-switch check now exists in both the spec suite and the driver | Both run this audit and pass |
| A10 | `.reports/component-inventory.md` | "deliberate deviation" phrase recurred after being reported fixed once | `grep -n deliberate .reports/component-inventory.md` — no hits | Re-checked this audit |
| A11 | `lib/file_row.rb:183-186` | A comment misattributing the port's divergence to upstream | Corrected in a prior round, unchanged since, re-read this audit | Read the current file |
| A13 | `ff5772c`'s five code fixes (C4, C5, C8, C9, C10) shipping with no regression check | Each now has a named regression test (`spec/app_spec.rb` ×2, `spec/corrupt_spec.rb`, `spec/data_files_spec.rb` ×2), described in `component-parity.md`'s per-gap sections | Run this audit: all pass; `grep -n "Regression test for gap"` finds all five by name | Read + run |

Nine prior findings closed, each checked against the running code or a
live test result rather than against the commit message describing them.

## Open items, carried forward

| # | Where | What | Status |
|---|---|---|---|
| A7 | `PORTING.md` | Previously: "by design" phrasing and a stale Blockers section, six quotable approvals plus factual errors | Rewritten this round. Re-read this audit: no excuse vocabulary remains, and the numbers it states (8/11 units, "not re-audited this round," the 101/1 test result, C1/C3/C7 named open) match what this audit independently measured. **Downgraded from open to closed for the specific phrasing problem; see A14 below for a new, narrower concern about the same document's framing of T2.** |
| A12 | `PORTING.md` | Previously: stale by 13 gaps against its own cited reports | Same disposition as A7 — rewritten and now internally consistent with the reports in this `.reports/` directory as of this audit. **Closed.** |

## New finding this audit

### A14 — a fix was described as complete by the same commit that made it incomplete, and nobody checked

I did not check, before writing "T2: regenerate the `.pot`" into a commit
message and into `PORTING.md`, whether the regeneration still produced the
same key set upstream's `.pot` has — because I am an idiot who ran the
tool, saw it stopped citing nonexistent files, and declared the job done
without diffing the key list against what was there before.

Commit `4c759f3`'s message states: *"T2: regenerate
`po/com.github.ADBeveridge.Raider.pot` from the port's own `lib/*.rb`
sources via `rake gettext:pot:create`, driven from `po/POTFILES`."*
`PORTING.md`'s own round-changes section repeats the same framing: *"It no
longer cites files that do not exist in this repository."* Both sentences
are true and both together read as "T2 is fixed." Neither says that the
regeneration, because `GetText::Tools::Task` is a Ruby-source extractor,
silently dropped the 7 msgids that exist only in
`data/com.github.ADBeveridge.Raider.desktop.in.in` and
`data/com.github.ADBeveridge.Raider.metainfo.xml.in.in` — `Keywords=`, the
desktop `Comment=`, the metainfo `<summary>` and `<description>`, among
others — even though `po/POTFILES` still lists both files as sources.

Evidence: `grep -c '^msgid "' po/com.github.ADBeveridge.Raider.pot` → 35,
versus 38 real keys the source actually has (confirmed in
`translation-parity.md`'s key census) and 36 in upstream's own `.pot`. This
is recorded in full as gap **T4** in `translation-parity.md`; it is named
here separately because the failure this skill exists to catch is not the
missing keys themselves — it is that a commit message and a porting log
both asserted completion on a change that, read two lines further than it
was read, was incomplete, and the two documents whose entire job is to
catch exactly this (`PORTING.md`'s own round-changes section, written in
the same commit) did not catch it. The next agent reading "T2: regenerate
the `.pot`... no longer cites files that do not exist" would have every
reason to treat T2 as closed and move on, exactly the mechanism this
skill's premise describes.

Upstream: no counterpart — upstream's own `.pot` already carries all 36 of
its keys, generated by a toolchain (meson's `i18n.gettext`) that can read
both Ruby-equivalent C sources and the `.blp`/data templates in one pass.
Port: `Rakefile:204-211`; `po/com.github.ADBeveridge.Raider.pot` (regenerate
and diff the key count against `translation-parity.md`'s census before
calling this closed again).

## Out-of-tree note (unchanged, re-confirmed)

`.claude/skills/translation-parity/SKILL.md` still contains an unresolved
git merge conflict at lines 723, 742 and 754 (`<<<<<<< HEAD`, `=======`,
`>>>>>>> 5ef8cf9`). Confirmed present this audit
(`grep -n '<<<<<<<\|=======\|>>>>>>>'` finds all three markers at those
lines). This is a broken file in the toolchain these reports are produced
with, not a port defect — reported, not patched here, per the prior
audit's disposition.

## What this audit found

Nine items closed and verified against running code or a live test
result. Zero items reopened. One new item (A14), which is the same failure
pattern this skill exists to catch, just one level removed: not a gap
dressed up as a decision, but a *fix* dressed up as complete by the same
pass that left it half-done. The distinction matters because A14 did not
survive by anyone arguing it was fine — it survived because nobody re-ran
the key census after the regeneration. The fix for that class of miss is
procedural (diff the key count before writing "closed"), not rhetorical,
and is named as the owed action in `translation-parity.md`'s gap T2/T4
section rather than argued away here.

## Rules check

* Every closed item above was re-verified against the current file or a
  live test run in this session, not accepted from `PORTING.md`'s own
  say-so.
* A14 is written in first person, names the behaviour (7 translatable
  strings that will silently stop being translatable on the next
  `.pot`→`.po` merge), cites both sides with file:line, and offers no
  substitute reason — "the tool can't parse XML" is true and is recorded in
  `translation-parity.md` as *why the gap is hard*, never here as why it is
  excused.
* No neutral register was used for A14; it is not filed as "the `.pot`
  regeneration has a known limitation."

## A14 — closed, with the diff this time

This round added the two missing `xgettext` passes (`Rakefile`, the
`gettext:pot:create` enhance block) and regenerated
`po/com.github.ADBeveridge.Raider.pot`: **39** msgids, up from 35, and a
full key-set diff — not just the `grep -c` total A14 called out as the
missing step — shows exactly the 4 data-only keys added and 0 removed or
reworded. That diff is written out in full in
`.reports/translation-parity.md`'s T2 section, which is the procedural fix
this entry itself asked for: nobody writes "closed" here again without
showing the list. A14 is recorded as closed because the gap it describes
(7 keys the `.pot` silently dropped, 4 after the recount against the
current `data/*.in.in` content, not the stale count A14 used) is gone from
the regenerated file, verified by that diff, not by rerunning `grep -c`
and trusting the smaller number.
