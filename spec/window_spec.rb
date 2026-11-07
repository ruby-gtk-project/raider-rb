# frozen_string_literal: true

require "tmpdir"

require "window"

RSpec.describe Window do
  subject(:window) { GtkSupport.window }

  describe "the widget tree" do
    it "is an Adwaita window carrying the application icon" do
      expect(window.window).to be_a(Adwaita::ApplicationWindow)
      expect(window.window.icon_name).to eq(PackageConfig::APPLICATION_ID)
      expect(window.empty_state.icon_name).to eq(PackageConfig::APPLICATION_ID)
    end

    it "sizes itself as upstream's blueprint does" do
      expect(window.window.default_size).to eq([described_class::DEFAULT_WIDTH, described_class::DEFAULT_HEIGHT])
      expect(window.clamp.maximum_size).to eq(described_class::CLAMP_SIZE)
    end

    it "starts on the empty page with the open button revealed" do
      expect(window.window_stack.visible_child_name).to eq(described_class::EMPTY_PAGE)
      expect(window.open_revealer).to be_reveal_child
      expect(window.shred_revealer).not_to be_reveal_child
      expect(window.abort_revealer).not_to be_reveal_child
    end

    it "gives the list box the boxed-list style and the buttons their pills" do
      expect(window.list_box.css_classes).to include("boxed-list")
      expect(window.clear_button.css_classes).to include("pill")
      expect(window.shred_button.css_classes).to include("destructive-action", "pill")
      expect(window.abort_button.css_classes).to include("destructive-action", "pill")
    end

    it "labels the buttons as upstream does" do
      expect(window.clear_button.label).to eq("Clear")
      expect(window.shred_button.label).to eq("Shred All")
      expect(window.abort_button.label).to eq("Abort All")
      expect(window.add_content.label).to eq("Add")
      expect(window.add_content.tooltip_text).to eq("Add Files")
      expect(window.menu_button.tooltip_text).to eq("Main Menu")
    end

    it "builds upstream's two menus" do
      expect(window.primary_menu.n_items).to eq(2)
      expect(window.new_window_section.n_items).to eq(1)
      expect(window.help_section.n_items).to eq(2)
      expect(window.open_menu.n_items).to eq(1)
      expect(window.open_folder_section.n_items).to eq(1)
    end

    it "accepts a GdkFileList drop, copy only" do
      expect(window.drop_target.formats.gtypes).to include(Gdk::FileList.gtype)
      expect(window.drop_target.actions).to eq(Gdk::DragAction::COPY)
    end

    it "wires the split button to app.open" do
      expect(window.open_button.action_name).to eq("app.open")
    end
  end

  describe "#open_file" do
    it "adds a row and shows the list page" do
      Dir.mktmpdir do |directory|
        path = GtkSupport.write_file(directory, "one.txt")

        expect(window.open_file(path)).to be(true)
        expect(window.rows.map(&:path)).to eq([path])
        expect(window.window_stack.visible_child_name).to eq(described_class::LIST_PAGE)
        expect(window.shred_revealer).to be_reveal_child
      end
    end

    it "rejects a file it already holds, and keeps loading" do
      Dir.mktmpdir do |directory|
        path = GtkSupport.write_file(directory, "one.txt")
        window.open_file(path)

        expect(window.open_file(path)).to be(true)
        expect(window.rows.length).to eq(1)
      end
    end

    it "rejects a file that is not there, and keeps loading" do
      Dir.mktmpdir do |directory|
        expect(window.open_file(File.join(directory, "missing.txt"))).to be(true)
        expect(window.rows).to be_empty
      end
    end

    it "rejects a file it cannot write, and keeps loading" do
      Dir.mktmpdir do |directory|
        path = GtkSupport.write_file(directory, "readonly.txt")
        File.chmod(0o444, path)

        expect(window.open_file(path)).to be(true)
        expect(window.rows).to be_empty
      end
    end

    it "stops loading once the open-file cap is reached" do
      Dir.mktmpdir do |directory|
        path = GtkSupport.write_file(directory, "one.txt")
        allow(window).to receive(:file_limit).and_return(0)

        expect(window.open_file(path)).to be(false)
        expect(window.rows).to be_empty
      end
    end
  end

  describe "the drop handler" do
    # Gdk::FileList has no constructor in gtk4 4.3.9, so the handler is called
    # with a stand-in that answers #files the way the boxed value does. The
    # drop target's own configuration — GdkFileList, copy only — is asserted
    # above; what is exercised here is the handler behind the signal, not a
    # drag from a real GDK drop.
    it "loads the dropped files and accepts the drop" do
      Dir.mktmpdir do |directory|
        dropped = [
          GtkSupport.write_file(directory, "one.txt"),
          GtkSupport.write_file(directory, "two.txt"),
        ].map { |path| Gio::File.new_for_path(path) }

        accepted = window.send(:on_drop, Struct.new(:files).new(dropped))

        expect(accepted).to be(true)
        expect(GtkSupport.pump_until { window.rows.map(&:path) == dropped.map(&:path) }).to be(true)
        expect(window.window_stack.visible_child_name).to eq(described_class::LIST_PAGE)
      end
    end
  end

  describe "#open_files" do
    it "stops at the first file that reports the window is full" do
      Dir.mktmpdir do |directory|
        first = GtkSupport.write_file(directory, "one.txt")
        second = GtkSupport.write_file(directory, "two.txt")
        allow(window).to receive(:file_limit).and_return(1)

        window.open_files([first, second])

        expect(GtkSupport.pump_until { window.rows.map(&:path) == [first] }).to be(true)
      end
    end

    # Regression test for gap C3 (component-parity.md): upstream runs this on
    # a GTask worker thread (`raider_window_open_files_thread`,
    # `src/raider-window.c:272-284`) rather than the main thread, so a large
    # drop does not freeze the window while every file is stat'd. This opens
    # enough files that, if they were all examined synchronously on the main
    # thread as before, the main loop would have no turn free to run the
    # idle check below before every row had already landed — against the
    # threaded version, the check reliably catches rows arriving one at a
    # time rather than all at once.
    it "loads files one at a time through the main loop rather than freezing it for the whole drop (C3)" do
      Dir.mktmpdir do |directory|
        paths = 40.times.map { |n| GtkSupport.write_file(directory, "file#{n}.txt") }

        window.open_files(paths)

        counts = []
        GtkSupport.pump_until do
          counts << window.rows.length
          window.rows.length == paths.length
        end

        expect(counts.uniq.length).to be > 1
        expect(window.rows.map(&:path)).to eq(paths)
      end
    end
  end

  describe "#close_file" do
    it "refuses a row the window never held" do
      Dir.mktmpdir do |directory|
        stranger = FileRow.new(GtkSupport.write_file(directory, "stranger.txt"), window)

        expect { window.close_file(stranger) }
          .to raise_error(
            described_class::UnknownRow,
            "Could not remove filename from quick list. Please report this.",
          )
      end
    end
  end

  describe "#clear_files" do
    it "closes every row and goes back to the empty page" do
      Dir.mktmpdir do |directory|
        window.open_files(
          [
            GtkSupport.write_file(directory, "one.txt"),
                    GtkSupport.write_file(directory, "two.txt"),
          ],
        )
        GtkSupport.pump_until { window.rows.length == 2 }

        window.clear_files

        expect(window.rows).to be_empty
        expect(window.window_stack.visible_child_name).to eq(described_class::EMPTY_PAGE)
        expect(window.shred_revealer).not_to be_reveal_child
        expect(window.open_revealer).to be_reveal_child
      end
    end
  end

  describe "#start_shredding" do
    it "shows the transient label before the rows are launched" do
      Dir.mktmpdir do |directory|
        window.open_file(GtkSupport.write_file(directory, "one.txt"))

        window.start_shredding

        expect(window.shred_button.label).to eq("Starting Shredding…")
        expect(window.shred_button).not_to be_sensitive
        expect(window.clear_button).not_to be_sensitive
        expect(window.open_revealer).not_to be_reveal_child
        expect(window).to be_shredding

        # Let the launch this example queued run while its fixture is still
        # on disk, rather than against a directory that has been removed.
        GtkSupport.pump_until { window.rows.empty? }
      end
    end

    it "restores the labels in the completion callback" do
      Dir.mktmpdir do |directory|
        window.open_file(GtkSupport.write_file(directory, "one.txt", size: 1024 * 1024))

        window.start_shredding

        expect(GtkSupport.pump_until { window.abort_revealer.reveal_child? }).to be(true)
        expect(window.shred_button.label).to eq("Shred All")
        expect(window.clear_button.label).to eq("Clear All")
        expect(window.shred_button).to be_sensitive
        expect(window.shred_revealer).not_to be_reveal_child

        # The rows are still being overwritten; let them finish while the
        # fixture is on disk, so the worker is not left writing to a
        # directory this example has already removed.
        GtkSupport.pump_until { window.rows.empty? }
      end
    end

    it "shreds every file, drops every row and returns to the empty page" do
      Dir.mktmpdir do |directory|
        first = GtkSupport.write_file(directory, "one.txt")
        second = GtkSupport.write_file(directory, "two.txt")
        window.open_files([first, second])
        GtkSupport.pump_until { window.rows.length == 2 }

        window.start_shredding

        expect(GtkSupport.pump_until { window.rows.empty? }).to be(true)
        expect(File).not_to exist(first)
        expect(File).not_to exist(second)
        expect(window.window_stack.visible_child_name).to eq(described_class::EMPTY_PAGE)
        expect(window).not_to be_shredding
        expect(window.open_revealer).to be_reveal_child
        expect(window.abort_revealer).not_to be_reveal_child
      end
    end
  end

  describe "#abort_shredding" do
    it "shows the transient label without blocking the main loop" do
      Dir.mktmpdir do |directory|
        window.open_file(GtkSupport.write_file(directory, "big.bin", size: 4 * 1024 * 1024))
        window.start_shredding
        GtkSupport.pump_until { window.abort_revealer.reveal_child? }

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        window.abort_shredding(exiting: false)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

        expect(window.abort_button.label).to eq("Aborting…")
        expect(window.abort_button).not_to be_sensitive
        expect(window.list_box).not_to be_sensitive
        expect(elapsed).to be < 0.5
      end
    end

    it "restores the abort button once every worker has stopped" do
      Dir.mktmpdir do |directory|
        path = GtkSupport.write_file(directory, "big.bin", size: 4 * 1024 * 1024)
        window.open_file(path)
        window.start_shredding
        GtkSupport.pump_until { window.abort_revealer.reveal_child? }

        window.abort_shredding(exiting: false)

        expect(GtkSupport.pump_until { window.abort_button.label == "Abort All" }).to be(true)
        expect(window.abort_button).to be_sensitive
        expect(window.list_box).to be_sensitive
        expect(window).not_to be_shredding
        expect(window.shred_revealer).to be_reveal_child
        expect(window.rows.length).to eq(1)
        expect(File).to exist(path)
      end
    end
  end

  describe "#request_exit" do
    it "answers false and lets the window close when nothing is shredding" do
      expect(window.request_exit).to be(false)
      expect(window.window.visible_dialog).to be_nil
    end

    it "answers true and puts up the exit dialog while shredding" do
      Dir.mktmpdir do |directory|
        window.open_file(GtkSupport.write_file(directory, "big.bin", size: 4 * 1024 * 1024))
        window.start_shredding

        expect(window.request_exit).to be(true)

        GtkSupport.pump
        expect(window.window.visible_dialog).to be_a(ExitDialog)
        window.window.visible_dialog.close
        window.abort_shredding(exiting: false)
        GtkSupport.pump_until { window.abort_button.label == "Abort All" }
      end
    end
  end
end
