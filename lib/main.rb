# frozen_string_literal: true

require 'adwaita'

require_relative 'corrupt'
require_relative 'exit_dialog'
require_relative 'file_row'
require_relative 'progress_info_popover'
require_relative 'progress_paintable'
require_relative 'shortcuts_dialog'
require_relative 'window'

# App is the application object: it owns the actions, their accelerators, the
# About dialog and the shortcuts dialog, and it hands every file it is asked
# to open to a window.
#
# Ported from upstream's src/main.c and src/raider-application.c. The action
# names, accelerators and About dialog fields are upstream's, including the
# HANDLES_OPEN flag that makes files named on the command line arrive through
# the open handler instead of activate.
#
# Two deviations, both forced by the bindings:
#
#   * Adwaita::Application is broken in the Ruby bindings, so the application
#     object is a Gtk::Application. Every window is still an Adwaita one.
#   * Upstream registers GOptionEntries and sorts --version/--new-window out
#     in handle_local_options. Neither the entries nor that vfunc are reachable
#     from Ruby, so the two switches are read off the argument list here
#     before the application runs: --version prints and exits, and
#     --new-window asks an already-running instance for a window, exactly as
#     upstream's handler does.
#
# app.shortcuts is installed here too. Upstream does not install it: GTK
# supplies the action from the shortcuts-dialog.ui resource alias, and there
# is no resource bundle in this port.
class App
  APP_ID = 'com.github.ADBeveridge.Raider'
  VERSION = '0.1.0'
  PROGRAM_NAME = 'File Shredder'
  ICON = 'edit-delete-symbolic'
  ISSUE_URL = 'https://github.com/ADBeveridge/raider/issues/new'
  COPYRIGHT = '© 2024 Alan Beveridge'

  # Upstream's action entries, with the accelerators it sets for them.
  ACTIONS = {
    'open'        => ['<Ctrl>o'],
    'open-folder' => [],
    'new-window'  => ['<Ctrl>n'],
    'close'       => ['<Ctrl>w'],
    'quit'        => ['<Ctrl>q'],
    'about'       => [],
    'shortcuts'   => ['<Ctrl>question'],
  }.freeze

  DEVELOPERS = ['Alan Beveridge https://github.com/ADBeveridge'].freeze
  ARTISTS = [
    'noëlle https://github.com/jannuary',
    'David Lapshin https://github.com/daudix-UFO',
  ].freeze
  DESIGNERS = ['Tobias Bernard https://gitlab.gnome.org/bertob'].freeze

  VERSION_FLAGS = %w[--version -v].freeze
  NEW_WINDOW_FLAGS = %w[--new-window -w].freeze

  def initialize(argv: [])
    @argv = Array(argv)
    @windows = []
  end

  # Returns self, not the application object, so #run below can deal with the
  # command line before the main loop starts.
  def build
    tap do
      app.signal_connect('activate') { on_activate }
      app.signal_connect('open') { |_, files, _count, _hint| on_open(files) }
      setup_actions
    end
  end

  def run
    if version?
      puts "#{PROGRAM_NAME} - #{VERSION}"
      0
    elsif new_window?
      run_new_window
    else
      app.run(file_arguments)
    end
  end

  def app
    @app ||= begin
      Adwaita.init
      Gtk::Application.new(APP_ID, :handles_open)
    end
  end

  def about_dialog
    Adwaita::AboutDialog.new.tap do |about|
      about.application_name = PROGRAM_NAME
      about.application_icon = ICON
      about.version = VERSION
      about.copyright = COPYRIGHT
      about.issue_url = ISSUE_URL
      about.license_type = Gtk::License::GPL_3_0
      about.developer_name = 'Alan Beveridge'
      about.developers = DEVELOPERS
      about.artists = ARTISTS
      about.designers = DESIGNERS
    end
  end

  def shortcuts_dialog = ShortcutsDialog.new

  private

    # Upstream's handle_local_options: --new-window on a second launch is
    # forwarded to the instance that is already running, and on the first
    # launch the ordinary startup makes the window anyway.
    def run_new_window
      app.register
      if app.remote?
        app.activate_action('new-window', nil)
        0
      else
        app.run(file_arguments)
      end
    end

    def version? = @argv.any? { |argument| VERSION_FLAGS.include?(argument) }

    def new_window? = @argv.any? { |argument| NEW_WINDOW_FLAGS.include?(argument) }

    def file_arguments = @argv.reject { |argument| argument.start_with?('-') }

    # Upstream's activate: present the window there is, or make one.
    def on_activate
      if @windows.empty?
        open_window([])
      else
        app.active_window.present
      end
    end

    # Upstream's open vfunc: the files go to a window of their own.
    def on_open(files)
      open_window(Array(files))
    end

    def open_window(files)
      Window.new(app).tap do |win|
        win.build
        @windows << win
        win.window.signal_connect('destroy') { @windows.delete(win) }
        win.open_files(files)
        win.present
      end
    end

    def setup_actions
      ACTIONS.each { |name, accels| add_action(name, accels) }
    end

    def add_action(name, accels)
      Gio::SimpleAction.new(name, nil).tap do |action|
        action.signal_connect('activate') { send(:"action_#{name.tr('-', '_')}") }
        app.add_action(action)
        if accels.any?
          app.set_accels_for_action("app.#{name}", accels)
        end
      end
    end

    # --- Actions ------------------------------------------------------------

    def action_open
      Gtk::FileDialog.new.tap do |dialog|
        dialog.modal = true
        dialog.title = 'Add Files'
        dialog.open_multiple(app.active_window, nil) do |_, result|
          load_into_active_window(dialog.open_multiple_finish(result))
        rescue GLib::Error
          nil
        end
      end
    end

    def action_open_folder
      Gtk::FileDialog.new.tap do |dialog|
        dialog.modal = true
        dialog.title = 'Add Folders'
        dialog.select_multiple_folders(app.active_window, nil) do |_, result|
          load_into_active_window(dialog.select_multiple_folders_finish(result))
        rescue GLib::Error
          nil
        end
      end
    end

    def action_new_window = open_window([])

    def action_close = app.active_window&.close

    # Upstream's try_exit: every window is asked, and the application quits
    # only when none of them is shredding.
    def action_quit
      @windows.dup.map(&:request_exit).any?.then do |shredding|
        unless shredding
          app.quit
        end
      end
    end

    def action_about = about_dialog.present(app.active_window)

    def action_shortcuts = shortcuts_dialog.build.present(app.active_window)

    # --- Helpers ------------------------------------------------------------

    # Both file dialogs finish with a GListModel of GFiles, which the window
    # wants as a plain array.
    def load_into_active_window(model)
      active_port_window.then do |win|
        if win
          win.open_files(to_array(model))
        end
      end
    end

    def to_array(model)
      if model.respond_to?(:n_items)
        (0...model.n_items).map { |index| model.get_item(index) }
      else
        Array(model)
      end
    end

    # The Window objects wrap their Adwaita window, so the active one is found
    # by matching that.
    def active_port_window
      app.active_window.then do |active|
        @windows.find { |win| win.window == active } || @windows.first
      end
    end
end
