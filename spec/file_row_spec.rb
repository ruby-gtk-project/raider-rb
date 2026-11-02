# frozen_string_literal: true

require "tmpdir"

require "file_row"

RSpec.describe FileRow do
  subject(:row) { described_class.new(path, window).tap(&:build) }

  let(:window) { GtkSupport.window }
  let(:directory) { @directory }
  let(:path) { GtkSupport.write_file(@directory, "secret.txt") }

  around do |example|
    Dir.mktmpdir do |directory|
      @directory = directory
      example.run
    end
  end

  it "titles itself with the basename and subtitles itself with the path" do
    expect(row.title).to eq("secret.txt")
    expect(row.subtitle).to eq(path)
    expect(row).not_to be_selectable
    expect(row).to be_activatable
  end

  describe "the trailing buttons" do
    it "carries no style class of its own, as upstream's blueprint sets none" do
      expect(row.remove_button.css_classes).not_to include("flat")
      expect(row.progress_button.css_classes).not_to include("flat")
    end

    it "carries no tooltip, as upstream's blueprint sets none" do
      expect(row.remove_button.tooltip_text).to be_nil
      expect(row.progress_button.tooltip_text).to be_nil
    end

    it "shows the remove icon upstream names" do
      expect(row.remove_button.icon_name).to eq("edit-delete-symbolic")
    end

    it "reveals remove and hides progress until shredding starts" do
      expect(row.remove_revealer).to be_reveal_child
      expect(row.progress_revealer).not_to be_reveal_child
    end

    it "holds the popover on the progress button" do
      expect(row.progress_button.popover).to be_a(ProgressInfoPopover)
      expect(row.progress_button).not_to be_always_show_arrow
    end

    it "pops the popover up, which is what upstream's clicked handler does" do
      window.open_file(GtkSupport.write_file(directory, "big.bin", size: 4 * 1024 * 1024))
      window.present
      GtkSupport.pump
      held = window.rows.first
      held.launch_shredding

      held.progress_button.popup
      GtkSupport.pump

      expect(held.popover).to be_visible

      held.shredding_abort
      held.wait_for_abort
      window.window.destroy
    end
  end

  describe "#close" do
    it "drops the row from the window and from the list box" do
      window.open_file(path)
      held = window.rows.first

      held.close

      expect(window.rows).to be_empty
      expect(held.parent).to be_nil
    end
  end

  describe "#launch_shredding" do
    it "swaps the remove button for the progress button" do
      window.open_file(path)
      held = window.rows.first

      held.launch_shredding

      expect(held.remove_revealer).not_to be_reveal_child
      expect(held.progress_revealer).to be_reveal_child
      expect(held.activatable_widget).to eq(held.progress_button)

      GtkSupport.pump_until { window.rows.empty? }
    end

    it "keeps a row whose shredding failed, as upstream's g_task_had_error does" do
      window.open_file(path)
      held = window.rows.first
      File.chmod(0o444, path)

      held.launch_shredding
      # #wait_for_abort is the join on the Corrupt worker; the finish callback
      # it queued runs on the next turn of the loop.
      held.wait_for_abort
      GtkSupport.pump

      expect(window.rows).to eq([held])
      expect(File).to exist(path)
    end
  end

  describe "#shredding_abort" do
    it "returns at once and swaps the buttons back" do
      big = GtkSupport.write_file(directory, "big.bin", size: 4 * 1024 * 1024)
      window.open_file(big)
      held = window.rows.first
      held.launch_shredding

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      held.shredding_abort
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      expect(elapsed).to be < 0.5
      expect(held.remove_revealer).to be_reveal_child
      expect(held.progress_revealer).not_to be_reveal_child
      expect(held.activatable_widget).to be_nil

      held.wait_for_abort
      expect(File).to exist(big)
    end
  end

  describe "#wait_for_abort" do
    it "returns once the worker has stopped" do
      big = GtkSupport.write_file(directory, "big.bin", size: 4 * 1024 * 1024)
      window.open_file(big)
      held = window.rows.first
      held.launch_shredding
      held.shredding_abort

      held.wait_for_abort

      expect(File).to exist(big)
    end
  end
end
