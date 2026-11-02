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
end
