# frozen_string_literal: true

require 'adwaita'

require_relative 'exit_dialog'
require_relative 'file_row'
require_relative 'package_config'
require_relative 'translation'

# Window is the app's one window: a header bar with an "Add" split button, an
# empty state inviting a drop, and — once files are loaded — a boxed list of
# them over a floating pair of buttons that clear or shred the lot.
#
# Ported from upstream's src/raider-window.blp and src/raider-window.c. The
# stack, the three revealers and the toast overlay are upstream's, as is the
# bookkeeping: the window counts the rows it holds, remembers whether
# shredding is in flight, and when the last row goes away it flips back to the
# empty state and announces that the shredding finished.
#
# The rows are kept in an array rather than read back out of the list box with
# gtk_list_box_get_row_at_index, so the window always hands the shredding code
# the FileRow objects it created. `close_file` checks that the row it is given
# was one of them, which is upstream's `removed == FALSE` branch.
#
# Starting and aborting are both asynchronous, as upstream's two GTasks are:
# the transient "Starting Shredding…" and "Aborting…" labels are set on this
# main-loop turn and the work is launched from another, so both are painted
# before the labels are put back in the completion callback.
class Window
  include Translation

  DEFAULT_WIDTH = 800
  DEFAULT_HEIGHT = 600
  MINIMUM_WIDTH = 270
  MINIMUM_HEIGHT = 300
  CLAMP_SIZE = 700

  EMPTY_PAGE = 'empty_page'
  LIST_PAGE = 'list_page'

  # Upstream's icon-name on both the window and the empty state: the
  # application icon from data/icons, not a symbolic glyph.
  ICON = PackageConfig::APPLICATION_ID

  # Upstream's g_error in raider_window_close_file, which aborts the process.
  # A raise is the Ruby equivalent: a row whose path the window never held
  # means the window's bookkeeping and its list box have drifted apart, and
  # carrying on past that quietly is what hides the drift.
  class UnknownRow < StandardError; end

  attr_writer :show_notification

  def initialize(app)
    @app = app
    @rows = []
    @shredding = false
    @show_notification = false
  end

  def build
    window.tap do |win|
      win.content = toolbar_view

      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = toast_overlay

        header_bar.tap do |bar|
          bar.pack_start(open_revealer)
          bar.title_widget = window_title
          bar.pack_end(menu_button)

          open_revealer.tap do |revealer|
            revealer.child = open_button
          end
        end

        toast_overlay.tap do |toasts|
          toasts.child = contents_box

          contents_box.tap do |box|
            box.append(window_stack)
            box.add_controller(drop_target)

            window_stack.tap do |stack|
              stack.add_named(empty_state, EMPTY_PAGE)
              stack.add_named(overlay, LIST_PAGE)

              overlay.tap do |ov|
                ov.child = scrolled_window
                ov.add_overlay(shred_revealer)
                ov.add_overlay(abort_revealer)

                scrolled_window.tap { |scroller| scroller.child = clamp }
                clamp.tap { |clamped| clamped.child = list_box }

                shred_revealer.tap do |revealer|
                  revealer.child = shred_box

                  shred_box.tap do |box_|
                    box_.append(clear_button)
                    box_.append(shred_button)
                  end

                  clear_button.signal_connect('clicked') { clear_files }
                  shred_button.signal_connect('clicked') { start_shredding }
                end

                abort_revealer.tap do |revealer|
                  revealer.child = abort_box

                  abort_box.tap do |box_|
                    box_.append(abort_button)
                  end

                  abort_button.signal_connect('clicked') { abort_shredding(exiting: false) }
                end
              end
            end
          end
        end
      end

      drop_target.signal_connect('drop') { |_, value, _x, _y| on_drop(value) }
      win.signal_connect('close-request') { request_exit }
    end
  end

  def present = window.present

  def shredding? = @shredding

  def rows = @rows.dup

  # Upstream's raider_window_open_files. Loading stops at the first file that
  # reports the window is full.
  def open_files(files)
    tap do
      Array(files).each do |file|
        unless open_file(path_for(file))
          break
        end
      end
    end
  end

  # Upstream's raider_window_open_file: rejects a duplicate, a file that is
  # gone and one that cannot be written, each with its own toast. Returns
  # false only when no further file can be loaded at all.
  def open_file(path)
    if filenames.include?(path)
      show_toast(_('This file was already added'))
      true
    elsif !File.exist?(path)
      show_toast(_('Some files did not exist'))
      true
    elsif !File.writable?(path)
      show_toast(format(_('Cannot write to “%s”'), path))
      true
    elsif @rows.length >= file_limit
      show_toast(_('Cannot load more files'))
      false
    else
      add_row(path)
      true
    end
  end

  # Upstream's raider_window_close_file: the row is gone, and if it was the
  # last one the window goes back to how it started. A row the window never
  # held is upstream's fatal case.
  def close_file(row)
    tap do
      unless @rows.delete(row)
        raise UnknownRow, _('Could not remove filename from quick list. Please report this.')
      end

      if @rows.empty?
        on_last_row_closed
      end
    end
  end

  def show_toast(text)
    tap do
      toast_overlay.add_toast(Adwaita::Toast.new(text))
    end
  end

  # Upstream's raider_window_exit: true means shredding is in flight, which
  # both blocks the close-request and tells app.quit to stay put. The dialog
  # it puts up is what turns a confirmed exit into an abort.
  def request_exit
    if @shredding
      exit_dialog.build.present(window)
    end
    @shredding
  end

  # Upstream's raider_window_clear_files: closing every row is the same thing
  # the remove button does, one row at a time.
  def clear_files
    tap do
      @rows.dup.each(&:close)
    end
  end

  # Upstream's raider_window_start_shredding: the open button hides, the
  # buttons go dead, the shred button says it is starting, and a GTask
  # launches the rows. The labels come back in
  # raider_window_shred_files_finish and not before, so the transient one is
  # on screen for as long as the launching takes.
  def start_shredding
    tap do
      open_revealer.reveal_child = false
      clear_button.sensitive = false
      shred_button.sensitive = false
      shred_button.label = _('Starting Shredding…')
      @shredding = true

      launch_rows(@rows.dup)
    end
  end

  # Upstream's raider_window_abort_shredding. `exiting` is upstream's trick of
  # passing a NULL widget: an abort the exit dialog asked for destroys the
  # window instead of restoring it.
  #
  # Every row is cancelled here, on the main loop, and waited for off it:
  # Corrupt#wait joins the worker thread, and joining it from the main thread
  # is what used to freeze the window for the length of a write pass.
  def abort_shredding(exiting:)
    tap do
      abort_button.sensitive = false
      list_box.sensitive = false
      abort_button.label = _('Aborting…')
      @show_notification = false

      @rows.dup.tap do |rows|
        rows.each(&:shredding_abort)
        wait_for_rows(rows, exiting: exiting)
      end
    end
  end

  # Adwaita::ApplicationWindow, not Gtk::ApplicationWindow: the Gtk one draws
  # its own titlebar, which would sit above the Adwaita header bar and give
  # the window a second close button.
  def window
    @window ||= Adwaita::ApplicationWindow.new(@app).tap do |win|
      win.title = _('File Shredder')
      win.icon_name = ICON
      win.set_default_size(DEFAULT_WIDTH, DEFAULT_HEIGHT)
      win.set_size_request(MINIMUM_WIDTH, MINIMUM_HEIGHT)
    end
  end

  def toolbar_view
    @toolbar_view ||= Adwaita::ToolbarView.new.tap do |view|
      view.vexpand = true
    end
  end

  def header_bar
    @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
      bar.centering_policy = :strict
    end
  end

  def window_title = @window_title ||= Adwaita::WindowTitle.new(_('File Shredder'), '')

  def open_revealer
    @open_revealer ||= Gtk::Revealer.new.tap do |revealer|
      revealer.reveal_child = true
      revealer.transition_type = :slide_right
    end
  end

  def open_button
    @open_button ||= Adwaita::SplitButton.new.tap do |button|
      button.child = add_content
      button.action_name = 'app.open'
      button.menu_model = open_menu
    end
  end

  def add_content
    @add_content ||= Adwaita::ButtonContent.new.tap do |content|
      content.label = _('Add')
      content.icon_name = 'document-open-symbolic'
      content.tooltip_text = _('Add Files')
    end
  end

  def menu_button
    @menu_button ||= Gtk::MenuButton.new.tap do |button|
      button.icon_name = 'open-menu-symbolic'
      button.tooltip_text = _('Main Menu')
      button.menu_model = primary_menu
      button.primary = true
    end
  end

  # Upstream's `menu primary_menu`: two sections, so the new-window item is
  # separated from the help items.
  def primary_menu
    @primary_menu ||= Gio::Menu.new.tap do |menu|
      menu.append_section(nil, new_window_section)
      menu.append_section(nil, help_section)
    end
  end

  def new_window_section
    @new_window_section ||= Gio::Menu.new.tap do |section|
      section.append(_('New Window'), 'app.new-window')
    end
  end

  def help_section
    @help_section ||= Gio::Menu.new.tap do |section|
      section.append(_('Keyboard Shortcuts'), 'app.shortcuts')
      section.append(_('About File Shredder'), 'app.about')
    end
  end

  # Upstream's `menu open_menu`, which hangs off the split button's arrow.
  def open_menu
    @open_menu ||= Gio::Menu.new.tap do |menu|
      menu.append_section(nil, open_folder_section)
    end
  end

  def open_folder_section
    @open_folder_section ||= Gio::Menu.new.tap do |section|
      section.append(_('Open Folder'), 'app.open-folder')
    end
  end

  def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

  def contents_box
    @contents_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
      box.vexpand = true
      box.margin_top = 24
    end
  end

  def window_stack
    @window_stack ||= Gtk::Stack.new.tap do |stack|
      stack.transition_type = :crossfade
    end
  end

  def empty_state
    @empty_state ||= Adwaita::StatusPage.new.tap do |page|
      page.title = _('Add files or drop here')
      page.icon_name = ICON
      page.description = _('Shredding is the obfuscation of a file with random data so the previous contents cannot be recovered.')
      page.hexpand = true
    end
  end

  def overlay = @overlay ||= Gtk::Overlay.new
  def scrolled_window = @scrolled_window ||= Gtk::ScrolledWindow.new

  def clamp
    @clamp ||= Adwaita::Clamp.new.tap do |clamped|
      clamped.maximum_size = CLAMP_SIZE
    end
  end

  def list_box
    @list_box ||= Gtk::ListBox.new.tap do |box|
      box.valign = :start
      box.margin_start = 12
      box.margin_end = 12
      box.margin_top = 12
      box.margin_bottom = 12
      box.add_css_class('boxed-list')
    end
  end

  def shred_revealer = @shred_revealer ||= floating_revealer

  def abort_revealer = @abort_revealer ||= floating_revealer

  def shred_box = @shred_box ||= floating_box

  def abort_box = @abort_box ||= floating_box

  def clear_button
    @clear_button ||= Gtk::Button.new.tap do |button|
      button.label = _('Clear')
      button.add_css_class('pill')
    end
  end

  def shred_button
    @shred_button ||= Gtk::Button.new.tap do |button|
      button.label = _('Shred All')
      button.margin_start = 10
      button.add_css_class('destructive-action')
      button.add_css_class('pill')
    end
  end

  def abort_button
    @abort_button ||= Gtk::Button.new.tap do |button|
      button.label = _('Abort All')
      button.add_css_class('destructive-action')
      button.add_css_class('pill')
    end
  end

  # Upstream's drop target: GdkFileList only, copy only, and installed on the
  # content box so the whole page below the header bar accepts a drop.
  def drop_target = @drop_target ||= Gtk::DropTarget.new(Gdk::FileList.gtype, :copy)

  private

    def exit_dialog = ExitDialog.new { abort_shredding(exiting: true) }

    def floating_revealer
      Gtk::Revealer.new.tap do |revealer|
        revealer.reveal_child = false
        revealer.transition_type = :slide_up
        revealer.valign = :end
        revealer.halign = :center
        revealer.margin_bottom = 20
      end
    end

    def floating_box
      Gtk::Box.new(:horizontal, 0).tap do |box|
        box.margin_start = 5
        box.margin_end = 5
        box.margin_top = 5
        box.margin_bottom = 5
      end
    end

    def filenames = @rows.map(&:path)

    def add_row(path)
      FileRow.new(path, self).tap do |row|
        row.build
        list_box.append(row)
        @rows << row
        window_stack.visible_child_name = LIST_PAGE
        shred_revealer.reveal_child = true
      end
    end

    # Upstream's raider_window_shred_files_thread: a worker turn that starts
    # every row. Each start touches that row's widgets, so it is handed back
    # to the main loop; the idle queue is first in first out, which is what
    # makes the finish callback the last of them to run.
    def launch_rows(rows)
      Thread.new do
        rows.each { |row| on_main_loop { row.launch_shredding } }
        on_main_loop { shred_files_finish }
      end
    end

    # Upstream's raider_window_shred_files_finish.
    def shred_files_finish
      shred_revealer.reveal_child = false
      abort_revealer.reveal_child = true
      clear_button.sensitive = true
      shred_button.sensitive = true
      clear_button.label = _('Clear All')
      shred_button.label = _('Shred All')
    end

    # Upstream's raider_window_abort_files_thread, which is where its
    # per-row mutex wait happens.
    def wait_for_rows(rows, exiting:)
      Thread.new do
        rows.each(&:wait_for_abort)
        on_main_loop { abort_files_finish(exiting: exiting) }
      end
    end

    # Upstream's raider_window_abort_files_finish: the "exit" task data
    # destroys the window, anything else restores the view.
    def abort_files_finish(exiting:)
      if exiting
        window.destroy
      else
        restore_after_abort
      end
    end

    # GLib's idle queue is the port's g_main_context_invoke: a worker thread
    # hands widget work back to the thread that owns the widgets.
    def on_main_loop(&block)
      GLib::Idle.add do
        block.call
        false
      end
    end

    def on_last_row_closed
      window_stack.visible_child_name = EMPTY_PAGE
      @shredding = false
      if @show_notification
        announce_finish
      end
      shred_revealer.reveal_child = false
      abort_revealer.reveal_child = false
      open_revealer.reveal_child = true
      @show_notification = true
    end

    # Upstream sends a desktop notification when the window is not the one the
    # user is looking at, and a toast when it is.
    def announce_finish
      _('Finished shredding files').then do |message|
        if window.active?
          show_toast(message)
        else
          @app.send_notification(nil, Gio::Notification.new(message))
        end
      end
    end

    def restore_after_abort
      shred_revealer.reveal_child = true
      abort_revealer.reveal_child = false
      open_revealer.reveal_child = true
      @shredding = false
      abort_button.sensitive = true
      list_box.sensitive = true
      abort_button.label = _('Abort All')
    end

    # The drop hands over a GdkFileList, which is a boxed value holding the
    # dropped files. Returning true tells GTK the drop was accepted.
    def on_drop(value)
      open_files(value.files)
      true
    end

    def path_for(file)
      if file.respond_to?(:path)
        file.path
      else
        file.to_s
      end
    end

    # Upstream caps the list at half the process's open-file limit.
    def file_limit
      Process.getrlimit(Process::RLIMIT_NOFILE).first.then do |limit|
        if limit == Process::RLIM_INFINITY
          Float::INFINITY
        else
          limit / 2
        end
      end
    end
end
