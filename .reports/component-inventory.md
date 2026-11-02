# Component inventory (raw scan annex)

Raw output of `component-identification/scripts/component-scan.sh` on both
trees, with the symbol table built from the installed `.gir` files. This is the
**lead**, not the verdict: read `component-identification.md` for the inventory
and `component-parity.md` for the comparison. Rows are
`<file>  <kind>  <value>  <count>` and counts are per attachment site in the
text, not per widget on screen, except in the `widget` stream.

| | |
|---|---|
| Upstream | `origin/main` @ `e63f656e0f788a82ac558ff3ca1f67a632acc2a9` |
| Port | `ruby` @ `6a8dd32f8800a3d821ca3d86aa43b895fe8d5792` |
| Symbol table | `.claude/skills/component-identification/scripts/symbols.tsv`, 1301 rows |

## Upstream

```
src/window.py	widget	Adw.ApplicationWindow	1
src/window.py	css	black	6
src/window.py	css	white	6
src/window.py	signal	abbw	1
src/window.py	signal	activate	3
src/window.py	signal	awbb	1
src/window.py	signal	change-state	2
src/window.py	signal	clicked	2
src/window.py	signal	enter	1
src/window.py	signal	leave	1
src/window.py	signal	motion	1
src/window.py	signal	pause	1
src/window.py	action	close	1
src/window.py	action	F10	1
src/window.py	action	new	1
src/window.py	action	restart	1
src/gtk/timecontrolentry.ui	widget	Gtk.Box	2
src/gtk/timecontrolentry.ui	widget	Gtk.Button	8
src/gtk/timecontrolentry.ui	widget	Gtk.Grid	1
src/gtk/timecontrolentry.ui	widget	Gtk.Label	2
src/gtk/timecontrolentry.ui	widget	Gtk.SpinButton	3
src/gtk/timecontrolentry.ui	css	custom-label	2
src/gtk/timecontrolentry.ui	css	custom-spin	3
src/gtk/timecontrolentry.ui	css	time-button	8
src/gtk/window.ui	widget	Adw.ApplicationWindow	1
src/gtk/window.ui	type	Adw.Breakpoint	1
src/gtk/window.ui	widget	Adw.ComboRow	1
src/gtk/window.ui	widget	Adw.HeaderBar	2
src/gtk/window.ui	widget	Adw.PreferencesGroup	1
src/gtk/window.ui	widget	Adw.PreferencesRow	1
src/gtk/window.ui	widget	Adw.ToolbarView	1
src/gtk/window.ui	widget	Gtk.Box	4
src/gtk/window.ui	widget	Gtk.Button	2
src/gtk/window.ui	controller	Gtk.EventControllerMotion	1
src/gtk/window.ui	widget	Gtk.Label	2
src/gtk/window.ui	widget	Gtk.MenuButton	1
src/gtk/window.ui	widget	Gtk.Overlay	1
src/gtk/window.ui	widget	Gtk.Revealer	1
src/gtk/window.ui	widget	Gtk.ScrolledWindow	1
src/gtk/window.ui	widget	Gtk.Stack	1
src/gtk/window.ui	type	Gtk.StringList	1
src/gtk/window.ui	widget	Gtk.WindowControls	3
src/gtk/window.ui	widget	Gtk.WindowHandle	1
src/gtk/window.ui	css	black	2
src/gtk/window.ui	css	circular	2
src/gtk/window.ui	css	image-button	2
src/gtk/window.ui	css	large	1
src/gtk/window.ui	css	linked	1
src/gtk/window.ui	css	osd	2
src/gtk/window.ui	css	pill	1
src/gtk/window.ui	css	suggested-action	1
src/gtk/window.ui	css	title-1	1
src/gtk/window.ui	css	transparent	1
src/gtk/window.ui	css	white	3
src/gtk/timerbutton.ui	type	Adw.Breakpoint	1
src/gtk/timerbutton.ui	widget	Adw.BreakpointBin	1
src/gtk/timerbutton.ui	widget	Gtk.Box	1
src/gtk/timerbutton.ui	widget	Gtk.Button	1
src/gtk/timerbutton.ui	widget	Gtk.Label	3
src/gtk/timerbutton.ui	css	colon	1
src/gtk/timerbutton.ui	css	opaque	1
src/gtk/help-overlay.ui	widget	Gtk.ShortcutsGroup	2
src/gtk/help-overlay.ui	widget	Gtk.ShortcutsSection	1
src/gtk/help-overlay.ui	widget	Gtk.ShortcutsShortcut	6
src/gtk/help-overlay.ui	widget	Gtk.ShortcutsWindow	1
src/gtk/help-overlay.ui	action	app.quit	1
src/gtk/help-overlay.ui	action	win.close	1
src/gtk/help-overlay.ui	action	win.menu	1
src/gtk/help-overlay.ui	action	win.new	1
src/gtk/help-overlay.ui	action	win.restart	1
src/gtk/help-overlay.ui	action	win.show-help-overlay	1
src/timecontrolentry.py	type	Gtk.Adjustment	3
src/timecontrolentry.py	widget	Gtk.Box	1
src/timecontrolentry.py	type	Gtk.TextDirection	1
src/timecontrolentry.py	signal	clicked	8
src/timecontrolentry.py	signal	output	1
src/timecontrolentry.py	signal	wrapped	1
src/timerbutton.py	type	Gtk.AccessibleProperty	2
src/timerbutton.py	type	Gtk.AccessibleRole	1
src/timerbutton.py	type	Gtk.BinLayout	1
src/timerbutton.py	widget	Gtk.Button	1
src/timerbutton.py	type	Gtk.TextDirection	1
src/timerbutton.py	css	black	2
src/timerbutton.py	css	expired	2
src/timerbutton.py	css	inverted	2
src/timerbutton.py	css	running	2
src/timerbutton.py	css	timerbutton	1
src/timerbutton.py	css	white	2
src/timerbutton.py	css-name	button	1
src/statemachine.py	type	Gtk.ApplicationInhibitFlags	2
src/statemachine.py	signal	a-active	1
src/statemachine.py	signal	abbw	2
src/statemachine.py	signal	alerted	2
src/statemachine.py	signal	awbb	2
src/statemachine.py	signal	b-active	1
src/statemachine.py	signal	changed	2
src/statemachine.py	signal	clicked	2
src/statemachine.py	signal	expired	1
src/main.py	widget	Adw.AboutWindow	1
src/main.py	type	Adw.Application	1
src/main.py	signal	activate	1
src/main.py	action	about	1
src/main.py	action	quit	1
```

## Port

```
lib/chess_clock/about_dialog.rb	widget	Adw.AboutDialog	1
lib/chess_clock/about_dialog.rb	widget	Adw.AboutWindow	2
lib/chess_clock/about_dialog.rb	type	Gtk.License	1
lib/chess_clock/time_control_entry.rb	type	Gtk.Adjustment	1
lib/chess_clock/time_control_entry.rb	widget	Gtk.Box	2
lib/chess_clock/time_control_entry.rb	widget	Gtk.Button	1
lib/chess_clock/time_control_entry.rb	widget	Gtk.Grid	1
lib/chess_clock/time_control_entry.rb	widget	Gtk.Label	1
lib/chess_clock/time_control_entry.rb	widget	Gtk.SpinButton	1
lib/chess_clock/time_control_entry.rb	type	Gtk.TextDirection	1
lib/chess_clock/time_control_entry.rb	css	custom-label	1
lib/chess_clock/time_control_entry.rb	css	custom-spin	1
lib/chess_clock/time_control_entry.rb	css	time-button	1
lib/chess_clock/time_control_entry.rb	signal	clicked	1
lib/chess_clock/time_control_entry.rb	signal	output	1
lib/chess_clock/time_control_entry.rb	signal	wrapped	1
lib/chess_clock/shortcuts_window.rb	type	Gtk.Builder	1
lib/chess_clock/shortcuts_window.rb	widget	Gtk.ShortcutsGroup	2
lib/chess_clock/shortcuts_window.rb	widget	Gtk.ShortcutsSection	1
lib/chess_clock/shortcuts_window.rb	widget	Gtk.ShortcutsShortcut	6
lib/chess_clock/shortcuts_window.rb	widget	Gtk.ShortcutsWindow	1
lib/chess_clock/shortcuts_window.rb	action	app.quit	1
lib/chess_clock/shortcuts_window.rb	action	win.close	1
lib/chess_clock/shortcuts_window.rb	action	win.menu	1
lib/chess_clock/shortcuts_window.rb	action	win.new	1
lib/chess_clock/shortcuts_window.rb	action	win.restart	1
lib/chess_clock/shortcuts_window.rb	action	win.show-help-overlay	1
lib/chess_clock/timer_button.rb	type	Adw.Breakpoint	1
lib/chess_clock/timer_button.rb	widget	Adw.BreakpointBin	1
lib/chess_clock/timer_button.rb	type	Adw.BreakpointCondition	1
lib/chess_clock/timer_button.rb	type	Gtk.AccessibleProperty	1
lib/chess_clock/timer_button.rb	type	Gtk.BinLayout	1
lib/chess_clock/timer_button.rb	widget	Gtk.Box	1
lib/chess_clock/timer_button.rb	widget	Gtk.Button	1
lib/chess_clock/timer_button.rb	widget	Gtk.Label	3
lib/chess_clock/timer_button.rb	type	Gtk.TextDirection	1
lib/chess_clock/timer_button.rb	css	black	2
lib/chess_clock/timer_button.rb	css	colon	1
lib/chess_clock/timer_button.rb	css	expired	2
lib/chess_clock/timer_button.rb	css	inverted	2
lib/chess_clock/timer_button.rb	css	opaque	1
lib/chess_clock/timer_button.rb	css	running	2
lib/chess_clock/timer_button.rb	css	timerbutton	1
lib/chess_clock/timer_button.rb	css	white	2
lib/chess_clock/timer_button.rb	signal	apply	1
lib/chess_clock/timer_button.rb	signal	unapply	1
lib/chess_clock/state_machine.rb	type	Gtk.ApplicationInhibitFlags	1
lib/chess_clock/state_machine.rb	signal	clicked	2
lib/chess_clock/application.rb	type	Adw.Application	2
lib/chess_clock/application.rb	type	Gtk.Application	2
lib/chess_clock/application.rb	signal	activate	2
lib/chess_clock/style.rb	type	Adw.StyleManager	1
lib/chess_clock/style.rb	type	Gtk.CssProvider	2
lib/chess_clock/style.rb	type	Gtk.StyleContext	3
lib/chess_clock/style.rb	type	Gtk.StyleProvider	2
lib/chess_clock/style.rb	signal	notify::high-contrast	1
lib/chess_clock/window.rb	widget	Adw.ApplicationWindow	1
lib/chess_clock/window.rb	type	Adw.Breakpoint	1
lib/chess_clock/window.rb	type	Adw.BreakpointCondition	1
lib/chess_clock/window.rb	widget	Adw.ComboRow	1
lib/chess_clock/window.rb	widget	Adw.HeaderBar	2
lib/chess_clock/window.rb	widget	Adw.PreferencesGroup	1
lib/chess_clock/window.rb	widget	Adw.PreferencesRow	1
lib/chess_clock/window.rb	widget	Adw.ToolbarView	1
lib/chess_clock/window.rb	type	Gtk.AccessibleProperty	1
lib/chess_clock/window.rb	widget	Gtk.Box	4
lib/chess_clock/window.rb	widget	Gtk.Button	2
lib/chess_clock/window.rb	controller	Gtk.EventControllerMotion	1
lib/chess_clock/window.rb	widget	Gtk.Label	2
lib/chess_clock/window.rb	widget	Gtk.MenuButton	1
lib/chess_clock/window.rb	widget	Gtk.Overlay	1
lib/chess_clock/window.rb	widget	Gtk.Revealer	1
lib/chess_clock/window.rb	widget	Gtk.ScrolledWindow	1
lib/chess_clock/window.rb	widget	Gtk.Stack	1
lib/chess_clock/window.rb	type	Gtk.StringList	1
lib/chess_clock/window.rb	widget	Gtk.WindowControls	1
lib/chess_clock/window.rb	widget	Gtk.WindowHandle	1
lib/chess_clock/window.rb	css	black	1
lib/chess_clock/window.rb	css	circular	1
lib/chess_clock/window.rb	css	image-button	1
lib/chess_clock/window.rb	css	large	1
lib/chess_clock/window.rb	css	linked	1
lib/chess_clock/window.rb	css	osd	1
lib/chess_clock/window.rb	css	pill	1
lib/chess_clock/window.rb	css	suggested-action	1
lib/chess_clock/window.rb	css	title-1	1
lib/chess_clock/window.rb	css	transparent	1
lib/chess_clock/window.rb	css	white	2
lib/chess_clock/window.rb	signal	activate	2
lib/chess_clock/window.rb	signal	apply	1
lib/chess_clock/window.rb	signal	change-state	1
lib/chess_clock/window.rb	signal	clicked	2
lib/chess_clock/window.rb	signal	enter	1
lib/chess_clock/window.rb	signal	leave	1
lib/chess_clock/window.rb	signal	motion	1
lib/chess_clock/window.rb	signal	unapply	1
lib/chess_clock/window.rb	action	muted	1
lib/chess_clock/settings.rb	signal	notify::	1
lib/chess_clock/settings.rb	signal	notify::selected	1
lib/chess_clock/settings.rb	signal	value-changed	1
```

## Known scanner artefacts in the rows above

* `src/raider-window.c  widget  Adw.ApplicationWindow  1` and
  `src/raider-window.blp  widget  Adw.ApplicationWindow  1` are one window.
  Same for `Adw.ActionRow` across `raider-file-row.c`/`.blp` and `Gtk.Popover`
  across `raider-progress-info-popover.c`/`.blp`.
* `src/raider-application.c  signal  activate  7` counts six `GSimpleAction`
  `activate` connections plus the application's own `activate` vfunc.
* `src/raider-window.c  signal  mount-added|mount-changed|mount-removed` come
  from the commented-out `GVolumeMonitor` block at `:129-141`. Dead upstream.
* `src/raider-progress-paintable.c  widget  Gtk.Widget  1` is the
  construct-only `widget` property's type, not a widget this file builds.
* `lib/window.rb  widget  Adw.ApplicationWindow  2` / `Gtk.ApplicationWindow 1`
  are the class's comment at `:246-248` explaining why the Adwaita one is used,
  plus the one real construction at `:250`.
* `lib/main.rb  type  Gtk.Application  2` / `Adw.Application  1` likewise: one
  construction at `:93`, the rest prose.
* `lib/shortcuts_dialog.rb  widget  Adw.ShortcutsDialog  2` is the superclass
  plus the comment; there is one dialog.
* `lib/progress_paintable.rb  widget  Gtk.DrawingArea  2` is one memoized
  drawing area plus its mention in the class comment.
* `lib/window.rb  action  app.open  2` under-reports: the port installs seven
  actions from a loop over `ACTIONS` (`lib/main.rb:44-52`, `:173-185`), so none
  of their names is a literal at an install site the scan can match. The action
  table in `component-identification.md` was read off the install site instead.
* Revealers and boxes in `lib/window.rb` are built by the `floating_revealer`
  and `floating_box` helpers (`:423-440`), so the scan's count of 2 is two call
  sites and three widgets on screen.
