# frozen_string_literal: true

require "tmpdir"

require "main"

RSpec.describe App do
  subject(:application) { described_class.new.build }

  it "is a Gtk::Application carrying upstream's id and the HANDLES_OPEN flag" do
    expect(application.app.application_id).to eq(PackageConfig::APPLICATION_ID)
    expect(application.app.flags).to eq(Gio::ApplicationFlags::HANDLES_OPEN)
  end

  it "installs upstream's seven actions" do
    expect(described_class::ACTIONS.keys.length).to eq(7)

    described_class::ACTIONS.each_key do |name|
      expect(application.app.lookup_action(name)).to be_a(Gio::SimpleAction)
    end
  end

  it "binds upstream's accelerators" do
    expect(described_class::ACTIONS.to_h { |name, accels| ["app.#{name}", accels] })
      .to eq(
        {
          "app.open"        => ["<Ctrl>o"],
          "app.open-folder" => [],
          "app.new-window"  => ["<Ctrl>n"],
          "app.close"       => ["<Ctrl>w"],
          "app.quit"        => ["<Ctrl>q"],
          "app.about"       => [],
          "app.shortcuts"   => ["<Ctrl>question"],
        },
      )

    # GTK answers with its own canonical spelling of the modifier, so the
    # accelerators are compared after parsing rather than as text.
    described_class::ACTIONS.each do |name, accels|
      expect(application.app.get_accels_for_action("app.#{name}").map { |accel| Gtk.accelerator_parse(accel) })
        .to eq(accels.map { |accel| Gtk.accelerator_parse(accel) })
    end
  end

  describe "the About dialog" do
    subject(:about) { application.about_dialog }

    it "reports upstream's version, not the gem's" do
      expect(about.version).to eq("3.1.0")
      expect(about.version).to eq(PackageConfig::PACKAGE_VERSION)
      expect(about.version).not_to eq(Raider::Rb::VERSION)
    end

    it "shows the application icon" do
      expect(about.application_icon).to eq(PackageConfig::APPLICATION_ID)
    end

    it "carries the translator-credits msgid, so the Translators page exists" do
      expect(about.translator_credits).not_to be_empty
    end

    it "credits upstream's people" do
      expect(about.developer_name).to eq("Alan Beveridge")
      expect(about.developers).to eq(described_class::DEVELOPERS)
      expect(about.artists).to eq(described_class::ARTISTS)
      expect(about.designers).to eq(described_class::DESIGNERS)
      expect(about.copyright).to eq("© 2024 Alan Beveridge")
      expect(about.license_type).to eq(Gtk::License::GPL_3_0)
      expect(about.issue_url).to eq("https://github.com/ADBeveridge/raider/issues/new")
    end
  end

  describe "#run" do
    it "prints the program name and upstream's version for --version" do
      expect { described_class.new(argv: ["--version"]).build.run }
        .to output("File Shredder - 3.1.0\n").to_stdout
    end

    it "prints it for -v too" do
      expect { described_class.new(argv: ["-v"]).build.run }
        .to output("File Shredder - 3.1.0\n").to_stdout
    end
  end

  describe "#action_quit across two windows" do
    # The suite's one registered application: a second one on the same id
    # cannot export its D-Bus object.
    let(:shared) { GtkSupport.app }
    let(:windows) { 2.times.map { shared.send(:open_window, []) } }

    after do
      windows.each { |window| window.window.destroy }
      GtkSupport.pump
    end

    it "lists the windows it holds, in the order they were opened" do
      # Named first: the two windows are built lazily, and the application
      # cannot be asked for them before they exist.
      opened = windows

      expect(shared.windows & opened).to eq(opened)
      expect(shared.windows.map(&:window)).to all(be_a(Adwaita::ApplicationWindow))
    end

    it "drops a window that has been closed, so a stale one is never polled" do
      opened = windows

      expect(shared.windows).to include(*opened)

      opened.last.window.close
      GtkSupport.pump_until { !shared.windows.include?(opened.last) }

      # GTK4 removed GtkWidget::destroy, so there is no signal to hang the
      # removal on: the list is pruned against gtk_application_get_windows.
      expect(shared.windows).not_to include(opened.last)
      expect(shared.windows).to include(opened.first)
    end

    it "quits when no window is shredding" do
      expect(shared.app).to receive(:quit)

      shared.send(:action_quit)

      expect(windows.map(&:shredding?)).to eq([false, false])
    end

    it "refuses to quit while one of them is shredding, and asks that one" do
      Dir.mktmpdir do |directory|
        windows.last.open_file(GtkSupport.write_file(directory, "big.bin", size: 4 * 1024 * 1024))
        windows.last.start_shredding

        expect(shared.app).not_to receive(:quit)

        shared.send(:action_quit)
        GtkSupport.pump

        expect(windows.first.window.visible_dialog).to be_nil
        expect(windows.last.window.visible_dialog).to be_a(ExitDialog)

        windows.last.window.visible_dialog.close
        windows.last.abort_shredding(exiting: false)
        GtkSupport.pump_until { windows.last.abort_button.label == "Abort All" }
      end
    end
  end

  describe "the arguments handed to GApplication" do
    it "keeps the switches it does not consume, so --gapplication-service arrives" do
      application = described_class.new(argv: ["--gapplication-service", "/tmp/a"])

      expect(application.send(:application_arguments)).to eq(["--gapplication-service", "/tmp/a"])
    end

    it "consumes --version and --new-window itself" do
      application = described_class.new(argv: ["--new-window", "--version", "/tmp/a"])

      expect(application.send(:application_arguments)).to eq(["/tmp/a"])
    end
  end

  # Regression test for gap C4 (component-parity.md): action_open resolves
  # the target window once, at dialog-presentation time
  # (src/raider-application.c:79-84), not at dialog-completion time. A
  # revert to resolving app.active_window inside the completion block would
  # route the file to whichever window the user focused while the dialog was
  # open — this drives exactly that race and asserts the file still lands in
  # the window the dialog was opened from.
  describe "#action_open targets the window active when the dialog was opened (C4)" do
    let(:shared) { GtkSupport.app }
    let(:windows) { 2.times.map { shared.send(:open_window, []) } }

    it "loads the file into the second window even if the first becomes active before the dialog finishes" do
      first, second = windows
      second.window.present
      GtkSupport.pump_until { shared.app.active_window == second.window }

      Dir.mktmpdir do |directory|
        path = GtkSupport.write_file(directory, "c4.bin", size: 16)
        fake_dialog = instance_double(
          Gtk::FileDialog,
          "modal=" => nil,
          "title=" => nil,
        )
        allow(Gtk::FileDialog).to receive(:new).and_return(fake_dialog)
        completion = nil
        allow(fake_dialog).to receive(:open_multiple) do |_parent, _cancellable, &block|
          completion = block
        end
        allow(fake_dialog).to receive(:open_multiple_finish).and_return([path])

        shared.send(:action_open)

        # The user focuses the other window while the dialog is still open.
        first.window.present
        GtkSupport.pump_until { shared.app.active_window == first.window }

        completion.call(fake_dialog, double("result"))

        expect(GtkSupport.pump_until { second.rows.map(&:path).include?(path) }).to be(true)
        expect(first.rows.map(&:path)).not_to include(path)
      end
    end
  end

  # Regression test named in test-parity.md's open gaps: action_open_folder
  # resolves its target window exactly the same way action_open does
  # (`active_port_window`, called once at dialog-presentation time), but
  # unlike action_open had no test driving that directly. This is C4's test
  # above, repeated against action_open_folder's own dialog and finish
  # method, so a future change that moves the `active_port_window` call
  # inside the completion block is caught here too, not only for the file
  # dialog.
  describe "#action_open_folder targets the window active when the dialog was opened" do
    let(:shared) { GtkSupport.app }
    let(:windows) { 2.times.map { shared.send(:open_window, []) } }

    it "loads the folder's files into the second window even if the first becomes active before the dialog finishes" do
      first, second = windows
      second.window.present
      GtkSupport.pump_until { shared.app.active_window == second.window }

      Dir.mktmpdir do |directory|
        path = GtkSupport.write_file(directory, "open-folder.bin", size: 16)
        fake_dialog = instance_double(
          Gtk::FileDialog,
          "modal=" => nil,
          "title=" => nil,
        )
        allow(Gtk::FileDialog).to receive(:new).and_return(fake_dialog)
        completion = nil
        allow(fake_dialog).to receive(:select_multiple_folders) do |_parent, _cancellable, &block|
          completion = block
        end
        allow(fake_dialog).to receive(:select_multiple_folders_finish).and_return([path])

        shared.send(:action_open_folder)

        # The user focuses the other window while the dialog is still open.
        first.window.present
        GtkSupport.pump_until { shared.app.active_window == first.window }

        completion.call(fake_dialog, double("result"))

        expect(GtkSupport.pump_until { second.rows.map(&:path).include?(path) }).to be(true)
        expect(first.rows.map(&:path)).not_to include(path)
      end
    end
  end

  # Regression test for gap C10 (component-parity.md): gapplication_argv
  # prepends $PROGRAM_NAME so Gtk::Application#run does not read the first
  # real filename as its own program name and drop it — g_application_run's
  # documented contract is that argv[0] is the program name and everything
  # after it is what GApplication's `open` vfunc receives. A revert to
  # `[*application_arguments]` without the prepended name would make the
  # file the program name instead, and `open` would never fire for it.
  #
  # This drives that exact contract directly: the argv #run would hand
  # Gtk::Application#run is fed to a bare, separate Gio::Application (its
  # own id, so it cannot collide with the shared app the rest of this file
  # uses) and the file is asserted to arrive through `open`, not consumed as
  # the program name.
  describe "a file argument reaches GApplication's open vfunc, not the program name (C10)" do
    it "the argv #run passes delivers the file through open" do
      Dir.mktmpdir do |directory|
        path = GtkSupport.write_file(directory, "c10.bin", size: 16)
        argv = described_class.new(argv: [path]).send(:gapplication_argv)

        expect(argv).to eq([$PROGRAM_NAME, path])

        probe = Gio::Application.new("io.github.raider-rb.c10-probe", :handles_open)
        received = nil
        probe.signal_connect("open") do |_, files, _count, _hint|
          received = files.map(&:path)
          probe.quit
        end
        probe.signal_connect("activate") { probe.quit }

        probe.run(argv)

        expect(received).to eq([path])
      end
    end
  end
end
