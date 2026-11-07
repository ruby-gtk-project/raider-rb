# frozen_string_literal: true

# Drives the real application through everything the port claims to have, one
# step per turn of the GTK main loop, and writes a screenshot of each state.
#
#   nix develop --command xvfb-run -a ruby test/drive_main_window.rb
#
# Every component in .reports/component-inventory.md is exercised here:
#
#   1  App                   actions, accelerators, --version, new-window,
#                            close, quit, About and shortcuts dialogs
#   2  Window                chrome, menus, stack pages, toasts, revealers,
#                            drop target, file limit, clear, unknown row
#   3  ExitDialog            both responses — Cancel keeps going, Exit aborts
#                            the shredding and destroys the window
#   4  FileRow               title, subtitle, remove button, progress button,
#                            revealer swap, launch, abort, close
#   5  ProgressInfoPopover   all four states, and the popover the row opens
#   6  ProgressPaintable     the arc, its clamping and its drawing
#   7  ShortcutsDialog       the section, its five items and their actions
#   8  Corrupt               clean run, progress, cancel, folder, missing file
#   9  PackageConfig         the build constants the rest of the port reads
#  10  Translation           the gettext binding
#  11  DataFiles             the three installable files msgfmt merges
#
# Every file it shreds is a throwaway it wrote itself in a temporary
# directory, so a drive never touches anything of yours.

require 'fileutils'
require 'tmpdir'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'raider'
require 'data_files'
require_relative 'gtk_driver'

SHOTS = File.expand_path('../tmp/shots', __dir__)

# Small enough that five overwrite passes finish in a couple of seconds, big
# enough that the launch is still running on the turn after it started.
SHRED_SIZE = 256 * 1024

# Big enough that an abort always lands mid-pass.
ABORT_SIZE = 4 * 1024 * 1024

DIR = Dir.mktmpdir('raider-drive')

def fixture(name, size)
  File.join(DIR, name).tap { |path| File.write(path, 'r' * size) }
end

# The steps run inside a GLib timeout, so a wait has to give the loop its
# turns back rather than sleeping through them.
def wait_until(timeout: 60)
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout).then do |deadline|
    until yield
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        break
      end

      GLib::MainContext.default.then do |context|
        if context.pending?
          context.iteration(false)
        else
          sleep(0.005)
        end
      end
    end
    yield
  end
end

# Every label in a widget's tree. A toast is a widget the overlay parents to
# itself, so this is how the text of the toast that is on screen is read back.
def labels(widget, found = [])
  found.tap do
    if widget.is_a?(Gtk::Label)
      found << widget.label
    end

    widget.first_child.then do |first|
      child = first
      while child
        labels(child, found)
        child = child.next_sibling
      end
    end
  end
end

def toast_showing?(window, text)
  wait_until(timeout: 5) { labels(window.toast_overlay).include?(text) }
end

# A menu section's item labels and the actions they are wired to.
def menu_items(menu, index)
  menu.get_item_link(index, 'section').then do |section|
    (0...section.n_items).map do |item|
      [
        section.get_item_attribute_value(item, 'label', nil),
        section.get_item_attribute_value(item, 'action', nil),
      ]
    end
  end
end

# The window's drop handler takes a GdkFileList, and the Ruby bindings expose
# no way to build one (`Gdk::FileList` has `#files` and no constructor), so a
# real GTK drop cannot be synthesised here. The handler is called with a stand
# in that answers the one method it uses, which still puts the window's drop
# wiring and `open_files` under test.
DroppedFiles = Struct.new(:files)

# The watchdog has to outlast the whole run, and this one shreds several
# megabyte-sized files and merges 36 catalogues along the way.
GtkDriver.drive(App.new, shots: SHOTS, timeout: 600) do |d, app|
  win = -> { app.windows.first }

  d.window { win.call.window }

  d.step('the window opens on the empty state') do
    d.check('one window') { app.windows.length == 1 }
    d.check('it is an Adwaita::ApplicationWindow') do
      win.call.window.is_a?(Adwaita::ApplicationWindow)
    end
    d.check('its title is File Shredder') { win.call.window.title == 'File Shredder' }
    d.check('its icon is the application id') do
      win.call.window.icon_name == PackageConfig::APPLICATION_ID
    end
    d.check('empty page') { win.call.window_stack.visible_child_name == Window::EMPTY_PAGE }
    d.check('the status page is the empty page') do
      win.call.window_stack.get_child_by_name(Window::EMPTY_PAGE).equal?(win.call.empty_state)
    end
    d.check('the empty state invites a drop') do
      win.call.empty_state.title == 'Add files or drop here'
    end
    d.check('the empty state carries the app icon') do
      win.call.empty_state.icon_name == PackageConfig::APPLICATION_ID
    end
    d.check('the Add button is revealed') { win.call.open_revealer.reveal_child? }
    d.check('the Add button is the split button') do
      win.call.open_revealer.child.equal?(win.call.open_button)
    end
    d.check('the split button runs app.open') { win.call.open_button.action_name == 'app.open' }
    d.check('its content says Add') { win.call.add_content.label == 'Add' }
    d.check('the header bar title is the window title') do
      win.call.window_title.title == 'File Shredder'
    end
    d.check('the menu button is primary') { win.call.menu_button.primary? }
    d.check('no floating buttons yet') { !win.call.shred_revealer.reveal_child? }
    d.check('no abort buttons either') { !win.call.abort_revealer.reveal_child? }
    d.check('the drop target takes a GdkFileList') do
      win.call.drop_target.gtypes.map(&:name) == ['GdkFileList']
    end
    # The window, the empty state and the About dialog all ask for the icon by
    # the application id, so a theme that cannot resolve it renders three
    # missing-image placeholders.
    Gtk::IconTheme.get_for_display(Gdk::Display.default).then do |theme|
      d.check('the icon theme resolves the application icon') do
        theme.has_icon?(PackageConfig::APPLICATION_ID)
      end
      d.check('and its symbolic variant') do
        theme.has_icon?("#{PackageConfig::APPLICATION_ID}-symbolic")
      end
    end
    d.shot('01-empty-state')
  end

  d.step('every action upstream installs is here, with its accelerator') do
    App::ACTIONS.each do |name, accels|
      d.check("app.#{name} is installed") { app.app.has_action?(name) }
      d.check("app.#{name} is accelerated by #{accels.inspect}") do
        app.app.get_accels_for_action("app.#{name}").then do |bound|
          bound == accels.map { |accel| accel.sub('<Ctrl>', '<Control>') }
        end
      end
    end
    d.check('seven actions') { App::ACTIONS.length == 7 }
  end

  d.step('both menus hold the items the blueprint names') do
    d.check('the primary menu has two sections') { win.call.primary_menu.n_items == 2 }
    d.check('the first is New Window') do
      menu_items(win.call.primary_menu, 0) == [['New Window', 'app.new-window']]
    end
    d.check('the second is the help section') do
      menu_items(win.call.primary_menu, 1) == [
        ['Keyboard Shortcuts', 'app.shortcuts'],
        ['About File Shredder', 'app.about'],
      ]
    end
    d.check('the menu button shows the primary menu') do
      win.call.menu_button.menu_model.equal?(win.call.primary_menu)
    end
    d.check('the split button menu is Open Folder') do
      menu_items(win.call.open_menu, 0) == [['Open Folder', 'app.open-folder']]
    end
    d.check('the split button shows it') do
      win.call.open_button.menu_model.equal?(win.call.open_menu)
    end
  end

  d.step('app.new-window opens a second window') do
    app.app.activate_action('new-window', nil)

    d.check('two windows') { app.windows.length == 2 }
    d.check('the new one is on its empty page') do
      app.windows.last.window_stack.visible_child_name == Window::EMPTY_PAGE
    end
    d.check('it is not the first one') { !app.windows.last.equal?(win.call) }
  end

  d.step('app.close closes it again') do
    app.app.activate_action('close', nil)

    d.check('one window left') { wait_until { app.windows.length == 1 } }
    d.check('and it is the original') { win.call.window.title == 'File Shredder' }
  end

  d.step('add three files') do
    win.call.open_files(%w[one.bin two.bin three.bin].map { |name| fixture(name, SHRED_SIZE) })

    d.check('three rows') { win.call.rows.length == 3 }
    d.check('the rows are titled with the basename') do
      win.call.rows.map(&:title) == %w[one.bin two.bin three.bin]
    end
    d.check('and subtitled with the full path') do
      win.call.rows.map(&:subtitle) == %w[one.bin two.bin three.bin].map { |n| File.join(DIR, n) }
    end
    d.check('list page') { win.call.window_stack.visible_child_name == Window::LIST_PAGE }
    d.check('the shred buttons are revealed') { win.call.shred_revealer.reveal_child? }
    d.check('the rows are in the list box') do
      win.call.rows.all? { |row| row.parent.equal?(win.call.list_box) }
    end
    d.shot('02-three-files')
  end

  d.step('each row shows a remove button and hides its progress button') do
    win.call.rows.first.then do |row|
      d.check('the remove revealer is open') { row.remove_revealer.reveal_child? }
      d.check('the remove button carries the delete icon') do
        row.remove_button.icon_name == FileRow::REMOVE_ICON
      end
      d.check('the progress revealer is closed') { !row.progress_revealer.reveal_child? }
      d.check('the row has no activatable widget yet') { row.activatable_widget.nil? }
      d.check('the row is activatable') { row.activatable? }
      d.check('the row is not selectable') { !row.selectable? }
      d.check('its progress button owns the popover') do
        row.progress_button.popover.equal?(row.popover)
      end
      d.check('the progress arc is the button child') do
        row.progress_button.child.equal?(row.progress_paintable.arc)
      end
      d.check('the arc is drawn in a 20px box') do
        [row.progress_paintable.arc.content_width, row.progress_paintable.arc.content_height] ==
          [ProgressPaintable::BOX, ProgressPaintable::BOX]
      end
    end
  end

  d.step('a duplicate is refused with a toast') do
    d.check('a duplicate keeps loading') { win.call.open_file(File.join(DIR, 'one.bin')) == true }
    d.check('and says so') { toast_showing?(win.call, 'This file was already added') }
    d.check('no row was added') { win.call.rows.length == 3 }
    d.shot('03-duplicate-toast')
  end

  d.step('a file that is gone is refused with a toast') do
    d.check('it keeps loading') { win.call.open_file(File.join(DIR, 'nowhere.bin')) == true }
    d.check('and says so') { toast_showing?(win.call, 'Some files did not exist') }
    d.check('no row was added') { win.call.rows.length == 3 }
  end

  d.step('a file that cannot be written is refused with a toast naming it') do
    fixture('readonly.bin', 64).tap { |path| File.chmod(0o444, path) }.then do |path|
      d.check('it keeps loading') { win.call.open_file(path) == true }
      d.check('and names the file') { toast_showing?(win.call, "Cannot write to “#{path}”") }
      d.check('no row was added') { win.call.rows.length == 3 }
    end
  end

  # Upstream caps the list at half the process's open-file limit, so the only
  # way to reach the cap is to lower the limit. It is raised again at the end
  # of the step, and the cap is kept above the fds the process already holds.
  d.step('the list refuses to grow past half the open-file limit') do
    Dir.children('/proc/self/fd').length.then do |open_fds|
      (open_fds + 8).then do |cap|
        ((cap / 2) + 2).times.map { |i| fixture("limit#{i}.bin", 64) }.then do |paths|
          Process.setrlimit(Process::RLIMIT_NOFILE, cap, Process.getrlimit(Process::RLIMIT_NOFILE).last)

          paths.map { |path| win.call.open_file(path) }.then do |results|
            d.check('loading stops once the list is full') { results.include?(false) }
            d.check('the list is exactly half the limit') { win.call.rows.length == cap / 2 }
            d.check('and the refusal is the last word') { results.last == false }
          end

          Process.setrlimit(
            Process::RLIMIT_NOFILE,
            Process.getrlimit(Process::RLIMIT_NOFILE).last,
            Process.getrlimit(Process::RLIMIT_NOFILE).last,
          )
          d.check('the limit is back up') do
            Process.getrlimit(Process::RLIMIT_NOFILE).first > cap
          end
        end
      end
    end
    d.shot('04-file-limit')
  end

  # GtkButton animates an activation and emits `clicked` from a 250ms timeout
  # when it is over, so the row goes away on a later turn of the loop and not
  # on this one.
  d.step('the remove button takes its own row out of the list') do
    win.call.rows.length.then do |before|
      win.call.rows.last.then do |row|
        row.remove_button.activate

        d.check('one fewer row') { wait_until(timeout: 5) { win.call.rows.length == before - 1 } }
        d.check('the row left the list box') { row.parent.nil? }
        d.check('and the others stayed') { win.call.rows.length.positive? }
      end
    end
  end

  d.step('clearing empties the list and brings the empty state back') do
    win.call.clear_files

    d.check('no rows') { win.call.rows.empty? }
    d.check('empty page') { win.call.window_stack.visible_child_name == Window::EMPTY_PAGE }
    d.check('the shred buttons went away') { !win.call.shred_revealer.reveal_child? }
    d.check('the Add button is still there') { win.call.open_revealer.reveal_child? }
    d.shot('05-cleared')
  end

  d.step('a row the window never held is a fatal mix-up') do
    d.check('close_file raises UnknownRow') do
      begin
        win.call.close_file(Object.new)
        false
      rescue Window::UnknownRow
        true
      end
    end
  end

  d.step('a drop loads the dropped files') do
    %w[drop-one.bin drop-two.bin].map { |name| fixture(name, 1024) }.then do |paths|
      d.check('the drop is accepted') do
        win.call.send(:on_drop, DroppedFiles.new(paths)) == true
      end
      d.check('both files are listed') { win.call.rows.map(&:title) == %w[drop-one.bin drop-two.bin] }
      d.check('list page') { win.call.window_stack.visible_child_name == Window::LIST_PAGE }
      d.check('the drop target only accepts a copy') do
        win.call.drop_target.actions == Gdk::DragAction::COPY
      end
    end
    d.shot('06-dropped')
  end

  d.step('the progress popover shows its four states') do
    ProgressInfoPopover.new.build.then do |popover|
      popover.progress = 0.0
      d.check('nothing yet reads Starting…') { popover.progress_bar.text == 'Starting…' }
      d.check('and shows a full bar') { popover.progress_bar.fraction == 1.0 }

      popover.progress = 0.42
      d.check('part way reads the percentage') { popover.progress_bar.text == '42%' }
      d.check('and the bar follows the fraction') { popover.progress_bar.fraction.round(2) == 0.42 }

      popover.progress = 1.0
      d.check('done reads Finishing up…') { popover.progress_bar.text == 'Finishing up…' }

      popover.pulse
      d.check('a pulse reads Estimating…') { popover.progress_bar.text == 'Estimating…' }
      d.check('the bar shows its text') { popover.progress_bar.show_text? }
    end
  end

  d.step('the progress arc clamps what it is given') do
    win.call.rows.first.progress_paintable.then do |paintable|
      paintable.progress = 0.5
      d.check('a fraction is kept') { paintable.progress == 0.5 }
      paintable.progress = 2.0
      d.check('over one clamps to one') { paintable.progress == 1.0 }
      paintable.progress = -1.0
      d.check('under zero clamps to zero') { paintable.progress == 0.0 }
      paintable.progress = 0.75
      d.check('and a fraction in between is kept') { paintable.progress == 0.75 }
      d.check('the arc is not drawn while its revealer is closed') do
        !win.call.rows.first.progress_revealer.reveal_child?
      end
    end
  end

  d.step('start shredding') do
    win.call.clear_files
    win.call.open_files(%w[one.bin two.bin three.bin].map { |name| fixture(name, SHRED_SIZE) })
    win.call.start_shredding

    d.check('the window reports shredding') { win.call.shredding? }
    d.check('the transient label is on screen') do
      win.call.shred_button.label == 'Starting Shredding…'
    end
    d.check('the shred button is dead') { !win.call.shred_button.sensitive? }
    d.check('the clear button is dead') { !win.call.clear_button.sensitive? }
    d.check('the Add button is hidden') { !win.call.open_revealer.reveal_child? }
    d.shot('08-starting-shredding')
  end

  d.step('the launch settles into the aborting view') do
    d.check('the abort button is revealed') { win.call.abort_revealer.reveal_child? }
    d.check('the shred buttons are hidden') { !win.call.shred_revealer.reveal_child? }
    d.check('the labels came back') { win.call.shred_button.label == 'Shred All' }
    d.check('and the clear button says Clear All') { win.call.clear_button.label == 'Clear All' }
    d.check('the rows show their progress button') do
      win.call.rows.all? { |row| row.progress_revealer.reveal_child? }
    end
    d.check('and hid their remove button') do
      win.call.rows.none? { |row| row.remove_revealer.reveal_child? }
    end
    d.check('activating a row now opens its progress popover') do
      win.call.rows.all? { |row| row.activatable_widget.equal?(row.progress_button) }
    end
    d.shot('09-shredding')
  end

  d.step('the shredding finishes and the window goes back to how it started') do
    d.check('every row went away') { wait_until { win.call.rows.empty? } }
    d.check('and every file is gone') do
      %w[one.bin two.bin three.bin].none? { |name| File.exist?(File.join(DIR, name)) }
    end
    d.check('empty page') { win.call.window_stack.visible_child_name == Window::EMPTY_PAGE }
    d.check('not shredding') { !win.call.shredding? }
    d.check('the Add button is back') { win.call.open_revealer.reveal_child? }
    # Upstream announces the finish with a toast when its window is the one in
    # front and with a desktop notification when it is not. Under xvfb with no
    # window manager nothing ever takes the focus, so the notification branch
    # is the one that runs — which is what is asserted. The toast machinery
    # itself is covered by the three rejection toasts above.
    d.check('the window is not the one in front') { !win.call.window.active? }
    d.check('so the finish was not toasted') do
      !labels(win.call.toast_overlay).include?('Finished shredding files')
    end
    d.shot('11-finished')
  end

  d.step('add a large file and start shredding it') do
    win.call.open_file(fixture('big.bin', ABORT_SIZE))
    win.call.start_shredding

    d.check('one row') { win.call.rows.length == 1 }
    d.check('shredding') { win.call.shredding? }
  end

  d.step('the shredding row pops its progress popover up and draws its arc') do
    d.check('the launch settled') { wait_until { win.call.abort_revealer.reveal_child? } }

    win.call.rows.first.then do |row|
      d.check('the row shows its progress button') { row.progress_revealer.reveal_child? }

      row.progress_button.popup

      d.check('the popover is showing') { wait_until(timeout: 5) { row.popover.visible? } }
      d.check('it reports progress') { !row.popover.progress_bar.text.to_s.empty? }
      d.shot('10-progress-popover', row.popover.child)

      d.shot('10a-progress-arc', row.progress_paintable.arc)
      d.check('the arc drew itself to a file') do
        File.size?(File.join(SHOTS, '10a-progress-arc.png')).to_i.positive?
      end

      row.progress_button.popdown
    end
  end

  d.step('abort it') do
    d.check('still shredding') { win.call.shredding? }

    Process.clock_gettime(Process::CLOCK_MONOTONIC).then do |started|
      win.call.abort_shredding(exiting: false)

      d.check('the abort returned without blocking the loop') do
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - started < 0.5
      end
    end

    d.check('the transient label is on screen') { win.call.abort_button.label == 'Aborting…' }
    d.check('the list is desensitised') { !win.call.list_box.sensitive? }
    d.shot('12-aborting')
  end

  d.step('the abort settles and the file is still there') do
    d.check('the abort button came back') do
      wait_until { win.call.abort_button.label == 'Abort All' }
    end
    d.check('the list is live again') { win.call.list_box.sensitive? }
    d.check('not shredding') { !win.call.shredding? }
    d.check('the row is still held') { win.call.rows.length == 1 }
    d.check('and the file survived') { File.exist?(File.join(DIR, 'big.bin')) }
    d.check('the row shows its remove button again') do
      win.call.rows.first.remove_revealer.reveal_child?
    end
    d.check('and hid its progress button') do
      !win.call.rows.first.progress_revealer.reveal_child?
    end
    d.shot('13-after-abort')
  end

  d.step('closing the window while shredding asks first') do
    win.call.start_shredding

    d.check('the close request is refused') { win.call.request_exit == true }
  end

  d.step('the exit dialog is up') do
    win.call.window.visible_dialog.then do |dialog|
      d.check('it is the exit dialog') { dialog.is_a?(ExitDialog) }
      d.check('it asks whether to stop') { dialog.heading == 'Stop Shredding?' }
      d.check('its body is upstream’s') { dialog.body == 'Are you sure that you want to exit?' }
      d.check('Cancel is the default response') { dialog.default_response == ExitDialog::CANCEL }
      d.check('and the close response') { dialog.close_response == ExitDialog::CANCEL }
      d.check('Exit is destructive') do
        dialog.get_response_appearance(ExitDialog::EXIT) == Adwaita::ResponseAppearance::DESTRUCTIVE
      end
      d.check('both responses carry their mnemonic') do
        [dialog.get_response_label(ExitDialog::CANCEL), dialog.get_response_label(ExitDialog::EXIT)] ==
          ['_Cancel', '_Exit']
      end
      d.shot('14-exit-dialog', dialog.child)
    end
  end

  d.step('cancelling it leaves the shredding running') do
    win.call.window.visible_dialog.close

    d.check('the dialog went away') { wait_until { win.call.window.visible_dialog.nil? } }
    d.check('still shredding') { win.call.shredding? }
  end

  d.step('app.quit is refused while a window is shredding') do
    app.app.activate_action('quit', nil)

    d.check('a window asked first') do
      wait_until(timeout: 5) { win.call.window.visible_dialog.is_a?(ExitDialog) }
    end
  end

  d.step('the application is still running, so the quit was refused') do
    d.check('the window is still here') { app.windows.length == 1 }
    d.check('and still shredding') { win.call.shredding? }

    win.call.window.visible_dialog&.close
  end

  d.step('abort and clear up before the second window') do
    win.call.abort_shredding(exiting: false)

    d.check('the abort settled') { wait_until { win.call.abort_button.label == 'Abort All' } }

    win.call.clear_files

    d.check('no rows') { win.call.rows.empty? }
    d.check('empty page') { win.call.window_stack.visible_child_name == Window::EMPTY_PAGE }
  end

  # The Exit response is the half of the dialog the cancel path cannot show:
  # it aborts the shredding and then destroys the window. It is driven on a
  # second window so the drive still has one to work with afterwards.
  d.step('a second window starts shredding a file of its own') do
    app.app.activate_action('new-window', nil)

    d.check('two windows') { app.windows.length == 2 }

    app.windows.last.then do |second|
      second.open_file(fixture('second.bin', ABORT_SIZE))
      second.start_shredding

      d.check('the second window has the row') { second.rows.length == 1 }
      d.check('and is shredding') { second.shredding? }
    end
  end

  d.step('closing it puts its own exit dialog up') do
    app.windows.last.then do |second|
      d.check('the launch settled') { wait_until { second.abort_revealer.reveal_child? } }
      d.check('the close request is refused') { second.request_exit == true }
      d.check('the dialog belongs to the second window') do
        wait_until(timeout: 5) { second.window.visible_dialog.is_a?(ExitDialog) }
      end
      d.check('the first window has no dialog') { win.call.window.visible_dialog.nil? }
    end
  end

  d.step('choosing Exit aborts the shredding and destroys that window') do
    app.windows.last.then do |second|
      second.window.visible_dialog.signal_emit('response', ExitDialog::EXIT)

      d.check('the window went away') { wait_until { app.windows.length == 1 } }
      d.check('the first window is the one left') { app.windows.first.equal?(win.call) }
      d.check('its shredding was aborted, so the file survived') do
        File.exist?(File.join(DIR, 'second.bin'))
      end
      d.check('the first window is untouched') do
        win.call.window_stack.visible_child_name == Window::EMPTY_PAGE
      end
    end
    d.shot('15-after-exit-dialog')
  end

  d.step('the About dialog carries the upstream version and opens') do
    app.about_dialog.then do |about|
      d.check('version') { about.version == PackageConfig::PACKAGE_VERSION }
      d.check('application name') { about.application_name == 'File Shredder' }
      d.check('application icon') { about.application_icon == PackageConfig::APPLICATION_ID }
      d.check('copyright') { about.copyright == App::COPYRIGHT }
      d.check('issue url') { about.issue_url == App::ISSUE_URL }
      d.check('licence') { about.license_type == Gtk::License::GPL_3_0 }
      d.check('developer name') { about.developer_name == 'Alan Beveridge' }
      d.check('one developer, two artists, one designer') do
        [about.developers.length, about.artists.length, about.designers.length] == [1, 2, 1]
      end

      about.present(win.call.window)
    end
  end

  d.step('the About dialog is on screen') do
    win.call.window.visible_dialog.then do |dialog|
      d.check('it is the About dialog') { dialog.is_a?(Adwaita::AboutDialog) }
      d.shot('16-about-dialog', dialog.child)
      dialog.close
    end
  end

  d.step('the shortcuts dialog lists the five shortcuts upstream documents') do
    app.shortcuts_dialog.then do |dialog|
      dialog.build

      d.check('it is an Adwaita shortcuts dialog') { dialog.is_a?(Adwaita::ShortcutsDialog) }
      d.check('one section') { dialog.sections.length == 1 }
      d.check('titled General') { dialog.sections.keys == ['General'] }
      d.check('of five items') { dialog.sections.values.flatten(1).length == 5 }
      d.check('naming the actions upstream names') do
        dialog.sections.values.flatten(1).map(&:last) ==
          ['app.open', 'app.new-window', 'app.shortcuts', 'app.close', 'app.quit']
      end
      d.check('every item names an installed action') do
        dialog.sections.values.flatten(1).all? do |_title, action|
          app.app.has_action?(action.delete_prefix('app.'))
        end
      end

      dialog.present(win.call.window)
    end
  end

  d.step('the shortcuts dialog is on screen') do
    win.call.window.visible_dialog.then do |dialog|
      d.check('it is showing') { dialog.is_a?(ShortcutsDialog) }
      d.shot('17-shortcuts-dialog', dialog.child)
      dialog.close
    end
  end

  d.step('the shredding backend runs, reports, cancels and walks a folder') do
    fixture('corrupt.bin', 4096).then do |path|
      :unset.then do |error|
        [].then do |seen|
          Corrupt.new(path, on_progress: ->(fraction) { seen << fraction })
                 .start { |finished| error = finished }
                 .wait

          d.check('a clean run reports no error') { error.nil? }
          d.check('and removes the file') { !File.exist?(path) }
          d.check('progress runs one step per pass') { seen.length == Corrupt::PATTERNS.length + 1 }
          d.check('from zero to one') { [seen.first, seen.last] == [0.0, 1.0] }
        end
      end
    end

    Corrupt.new(File.join(DIR, 'never-existed.bin')).then do |corrupt|
      :unset.then do |error|
        corrupt.start { |finished| error = finished }.wait
        d.check('a missing file is an error') { error.to_s.start_with?(Corrupt::NOT_FOUND) }
      end
    end

    fixture('cancelled.bin', ABORT_SIZE).then do |path|
      Corrupt.new(path).then do |corrupt|
        :unset.then do |error|
          corrupt.start { |finished| error = finished }
          corrupt.cancel
          corrupt.wait

          d.check('a cancelled run reports it') { error == Corrupt::CANCELLED }
          d.check('and says it was cancelled') { corrupt.cancelled? }
          d.check('and leaves the file alone') { File.exist?(path) }
        end
      end
    end

    File.join(DIR, 'tree', 'inner').then do |inner|
      FileUtils.mkdir_p(inner)
      File.write(File.join(inner, 'deep.bin'), 'q' * 512)
      File.write(File.join(DIR, 'tree', 'shallow.bin'), 'q' * 512)

      :unset.then do |error|
        Corrupt.new(File.join(DIR, 'tree')).start { |finished| error = finished }.wait

        d.check('a folder shreds without error') { error.nil? }
        d.check('and the whole tree is gone') { !File.exist?(File.join(DIR, 'tree')) }
      end
    end
  end

  d.step('the build constants and the gettext binding are the ones upstream has') do
    d.check('the version is upstream’s project version') do
      PackageConfig::PACKAGE_VERSION == '3.1.0'
    end
    d.check('the application id') do
      PackageConfig::APPLICATION_ID == 'com.github.ADBeveridge.Raider'
    end
    d.check('the gettext domain') { PackageConfig::GETTEXT_PACKAGE == 'raider' }
    d.check('a localedir is always bound') { !PackageConfig.localedir.to_s.empty? }
    d.check('the marker answers the msgid under the C locale') do
      win.call.send(:_, 'File Shredder') == 'File Shredder'
    end
    d.check('the window title came through it') { win.call.window.title == 'File Shredder' }

    # The C-locale check above would still pass with the domain, localedir
    # or binding entirely broken — C is the one locale where "return the
    # msgid unchanged" looks correct. This drives the same marker under a
    # real catalogue instead of reading one as a file.
    require 'locale'
    previous_locale = Locale.current
    begin
      Locale.current = 'de'
      d.check('the marker answers the msgid in German, live') do
        win.call.send(:_, 'File Shredder') == 'Aktenvernichter'
      end
      d.check('the translated string is UTF-8') do
        win.call.send(:_, 'File Shredder').encoding == Encoding::UTF_8
      end
    ensure
      Locale.current = previous_locale
    end
  end

  d.step('the three installable data files build out of their templates') do
    d.check('msgfmt is on PATH') { DataFiles.msgfmt? }

    DataFiles.new.then do |data|
      # po/LINGUAS lists every catalogue in po/, including pl — msgfmt only
      # merges what LINGUAS names, so a language missing from this file never
      # reaches a user regardless of whether its .po exists.
      d.check('po/LINGUAS lists all 35 languages') { data.languages.length == 35 }
      d.check('and every one of them has a catalogue') do
        data.languages.all? do |language|
          File.exist?(File.join(DataFiles::PO_DIRECTORY, "#{language}.po"))
        end
      end

      Dir.mktmpdir('raider-data').then do |out|
        data.write_all(out, bindir: '/opt/bin').then do |written|
          d.check('all three were written') do
            written.map { |path| File.basename(path) } == [
              DataFiles::DESKTOP_OUTPUT,
              DataFiles::METAINFO_OUTPUT,
              DataFiles::SERVICE_OUTPUT,
            ]
          end
          d.check('none of them is empty') { written.all? { |path| File.size(path).positive? } }
          d.check('the desktop entry is translated') do
            File.read(written[0]).include?('Name[de]=')
          end
          d.check('the metainfo carries xml:lang') do
            File.read(written[1]).include?('xml:lang=')
          end
          d.check('the service file took the bindir') do
            File.read(written[2]).include?('/opt/bin/')
          end
        end
      end
    end
  end

  d.step('--version answers upstream’s version without a main loop') do
    App.new(argv: ['--version']).then do |versioned|
      d.check('it prints the program name and the version') do
        require 'stringio'
        StringIO.new.then do |out|
          $stdout.then do |real|
            $stdout = out
            begin
              versioned.run.then { |status| status.zero? && out.string.strip == 'File Shredder - 3.1.0' }
            ensure
              $stdout = real
            end
          end
        end
      end
    end
  end
end
