# frozen_string_literal: true

require 'adwaita'

require_relative 'corrupt'
require_relative 'exit_dialog'
require_relative 'file_row'
require_relative 'progress_info_popover'
require_relative 'progress_paintable'
require_relative 'package_config'
require_relative 'shortcuts_dialog'
require_relative 'translation'
require_relative 'window'

# App is the application object: it owns the actions, their accelerators, the
# About dialog and the shortcuts dialog, and it hands every file it is asked
# to open to a window.
#
# Ported from upstream's src/main.c and src/raider-application.c. The action
# names, accelerators and About dialog fields are upstream's, including the
# HANDLES_OPEN flag that makes files named on the command line arrive through
# the open handler instead of activate, the application icon from
# data/icons, and the translator-credits msgid that gives the About dialog its
# Translators page.
#
# The application object is a Gtk::Application where upstream's is an
# Adw.Application, and --version / --new-window are read off the argument list
# here where upstream reads them in handle_local_options. Both behaviours are
# reached and both are driven by the specs; the version comes from
# PackageConfig so there is one place it is written down.
#
# app.shortcuts is installed here too, because GTK only supplies that action
# for an application that ships a shortcuts-dialog.ui resource alias.
class App
  include Translation

  APP_ID = PackageConfig::APPLICATION_ID
  VERSION = PackageConfig::PACKAGE_VERSION
  ICON = PackageConfig::APPLICATION_ID
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
      puts "#{program_name} - #{VERSION}"
      0
    elsif new_window?
      run_new_window
    else
      app.run(application_arguments)
    end
  end

  def app
    @app ||= begin
      Adwaita.init
      Gtk::Application.new(APP_ID, :handles_open)
    end
  end

  # Upstream's program name is the translated "File Shredder": it is the same
  # msgid the window title and the desktop entry's Name carry.
  def program_name = _('File Shredder')

  # The Window objects this application holds, oldest first. GApplication
  # already answers gtk_application_get_windows with the Adwaita windows; this
  # is the same list in terms of the objects that built them, which is what
  # app.quit asks for when it polls every window for shredding.
  #
  # A closed window is recognised the way upstream recognises it: as one
  # GApplication no longer lists. GTK4 removed GtkWidget::destroy, so there is
  # no signal to hang a removal on — connecting to it silently never fires,
  # and the list would grow for the life of the process and go on offering
  # destroyed windows to action_quit, which asks every one of them whether it
  # is shredding.
  def windows
    app.windows.then do |live|
      @windows.keep_if { |win| live.any? { |window| window == win.window } }.dup
    end
  end

  def about_dialog
    Adwaita::AboutDialog.new.tap do |about|
      about.application_name = program_name
      about.application_icon = ICON
      about.version = VERSION
      about.copyright = COPYRIGHT
      about.issue_url = ISSUE_URL
      about.license_type = Gtk::License::GPL_3_0
      about.developer_name = 'Alan Beveridge'
      about.developers = DEVELOPERS
      about.artists = ARTISTS
      about.designers = DESIGNERS
      about.translator_credits = _('translator-credits')
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
        app.run(application_arguments)
      end
    end

    def version? = @argv.any? { |argument| VERSION_FLAGS.include?(argument) }

    def new_window? = @argv.any? { |argument| NEW_WINDOW_FLAGS.include?(argument) }

    # Everything except the two switches this class consumes itself.
    # Upstream's handle_local_options returns -1 for anything it does not
    # recognise, so GApplication still sees it — which is how
    # `--gapplication-service` reaches the D-Bus activation code the desktop
    # entry's DBusActivatable=true and data/*.service.in rely on.
    def application_arguments
      (VERSION_FLAGS + NEW_WINDOW_FLAGS).then do |consumed|
        @argv.reject { |argument| consumed.include?(argument) }
      end
    end

    # Upstream's activate: present the window there is, or make one.
    #
    # GTK only calls a window active once something has focused it, so the
    # port falls back to the oldest window it holds before concluding there is
    # none — upstream's `window == NULL` is about there being no window at
    # all, not about nothing having the focus.
    def on_activate
      (app.active_window || windows.first&.window).then do |window|
        if window
          window.present
        else
          open_window([])
        end
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
        dialog.title = _('Add Files')
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
        dialog.title = _('Add Folders')
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
      windows.map(&:request_exit).any?.then do |shredding|
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
        windows.then { |live| live.find { |win| win.window == active } || live.first }
      end
    end
end
