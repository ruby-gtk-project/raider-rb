# frozen_string_literal: true

# Drives the real application through everything the window does, one step per
# turn of the GTK main loop, and writes a screenshot of each state.
#
#   nix develop --command xvfb-run -a ruby test/drive_main_window.rb
#
# Every file it shreds is a throwaway it wrote itself in a temporary
# directory, so a drive never touches anything of yours.

require 'tmpdir'

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'raider'
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

GtkDriver.drive(App.new, shots: SHOTS) do |d, app|
  win = -> { app.windows.first }

  d.window { win.call.window }

  d.step('the window opens on the empty state') do
    d.check('one window') { app.windows.length == 1 }
    d.check('empty page') { win.call.window_stack.visible_child_name == Window::EMPTY_PAGE }
    d.check('the Add button is revealed') { win.call.open_revealer.reveal_child? }
    d.check('no floating buttons yet') { !win.call.shred_revealer.reveal_child? }
    d.shot('01-empty-state')
  end

  d.step('add three files') do
    win.call.open_files(%w[one.bin two.bin three.bin].map { |name| fixture(name, SHRED_SIZE) })

    d.check('three rows') { win.call.rows.length == 3 }
    d.check('the rows are titled with the basename') do
      win.call.rows.map(&:title) == %w[one.bin two.bin three.bin]
    end
    d.check('list page') { win.call.window_stack.visible_child_name == Window::LIST_PAGE }
    d.check('the shred buttons are revealed') { win.call.shred_revealer.reveal_child? }
    d.shot('02-three-files')
  end

  d.step('reject a duplicate, a file that is gone and one that cannot be written') do
    duplicate = File.join(DIR, 'one.bin')
    missing = File.join(DIR, 'nowhere.bin')
    readonly = fixture('readonly.bin', 64).tap { |path| File.chmod(0o444, path) }

    d.check('a duplicate keeps loading') { win.call.open_file(duplicate) == true }
    d.check('a missing file keeps loading') { win.call.open_file(missing) == true }
    d.check('an unwritable file keeps loading') { win.call.open_file(readonly) == true }
    d.check('and none of them was added') { win.call.rows.length == 3 }
    d.shot('03-rejections')
  end

  d.step('start shredding') do
    win.call.start_shredding

    d.check('the window reports shredding') { win.call.shredding? }
    d.check('the transient label is on screen') do
      win.call.shred_button.label == 'Starting Shredding…'
    end
    d.check('the shred button is dead') { !win.call.shred_button.sensitive? }
    d.check('the clear button is dead') { !win.call.clear_button.sensitive? }
    d.check('the Add button is hidden') { !win.call.open_revealer.reveal_child? }
    d.shot('04-starting-shredding')
  end

  d.step('the launch settles into the aborting view') do
    d.check('the abort button is revealed') { win.call.abort_revealer.reveal_child? }
    d.check('the shred buttons are hidden') { !win.call.shred_revealer.reveal_child? }
    d.check('the labels came back') { win.call.shred_button.label == 'Shred All' }
    d.check('and the clear button says Clear All') { win.call.clear_button.label == 'Clear All' }
    d.check('the rows show their progress button') do
      win.call.rows.all? { |row| row.progress_revealer.reveal_child? }
    end
    d.shot('05-shredding')
  end

  d.step('the shredding finishes and the window goes back to how it started') do
    d.check('every row went away') { wait_until { win.call.rows.empty? } }
    d.check('and every file is gone') do
      %w[one.bin two.bin three.bin].none? { |name| File.exist?(File.join(DIR, name)) }
    end
    d.check('empty page') { win.call.window_stack.visible_child_name == Window::EMPTY_PAGE }
    d.check('not shredding') { !win.call.shredding? }
    d.check('the Add button is back') { win.call.open_revealer.reveal_child? }
    d.shot('06-finished')
  end

  d.step('add a large file and start shredding it') do
    win.call.open_file(fixture('big.bin', ABORT_SIZE))
    win.call.start_shredding

    d.check('one row') { win.call.rows.length == 1 }
    d.check('shredding') { win.call.shredding? }
  end

  d.step('abort it') do
    d.check('the launch settled') { wait_until { win.call.abort_revealer.reveal_child? } }

    Process.clock_gettime(Process::CLOCK_MONOTONIC).then do |started|
      win.call.abort_shredding(exiting: false)

      d.check('the abort returned without blocking the loop') do
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - started < 0.5
      end
    end

    d.check('the transient label is on screen') { win.call.abort_button.label == 'Aborting…' }
    d.check('the list is desensitised') { !win.call.list_box.sensitive? }
    d.shot('07-aborting')
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
    d.shot('08-after-abort')
  end

  d.step('closing the window while shredding asks first') do
    win.call.start_shredding

    d.check('the close request is refused') { win.call.request_exit == true }
  end

  d.step('the exit dialog is up') do
    d.check('it is the exit dialog') { win.call.window.visible_dialog.is_a?(ExitDialog) }
    d.shot('09-exit-dialog', win.call.window.visible_dialog.child)
  end

  d.step('cancelling it leaves the shredding running') do
    win.call.window.visible_dialog.close

    d.check('the dialog went away') { wait_until { win.call.window.visible_dialog.nil? } }
    d.check('still shredding') { win.call.shredding? }
  end

  d.step('clear the list instead') do
    win.call.abort_shredding(exiting: false)

    d.check('the abort settled') { wait_until { win.call.abort_button.label == 'Abort All' } }

    win.call.clear_files

    d.check('no rows') { win.call.rows.empty? }
    d.check('empty page') { win.call.window_stack.visible_child_name == Window::EMPTY_PAGE }
    d.shot('10-cleared')
  end

  d.step('the shortcuts dialog lists the five shortcuts upstream documents') do
    app.shortcuts_dialog.then do |dialog|
      dialog.build
      d.check('it is an Adwaita shortcuts dialog') { dialog.is_a?(Adwaita::ShortcutsDialog) }
      d.check('one section of five items') do
        dialog.sections.values.flatten(1).length == 5
      end
    end
  end

  d.step('the About dialog carries the upstream version') do
    app.about_dialog.then do |about|
      d.check('version') { about.version == PackageConfig::PACKAGE_VERSION }
      d.check('application name') { about.application_name == 'File Shredder' }
    end
  end
end
