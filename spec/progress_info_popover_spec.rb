# frozen_string_literal: true

require "progress_info_popover"

RSpec.describe ProgressInfoPopover do
  subject(:popover) { described_class.new.build }

  it "holds a progress bar whose text is the status" do
    expect(popover.progress_bar).to be_a(Gtk::ProgressBar)
    expect(popover.progress_bar).to be_show_text
    expect(popover.progress_bar.pulse_step).to be_within(0.001).of(described_class::PULSE_STEP)
  end

  describe "#progress=" do
    it "says it is starting, with a deliberately full bar, at nothing" do
      popover.progress = 0.0

      expect(popover.progress_bar.text).to eq("Starting…")
      expect(popover.progress_bar.fraction).to eq(1.0)
    end

    it "shows the whole percentage in between" do
      popover.progress = 0.42

      expect(popover.progress_bar.text).to eq("42%")
      expect(popover.progress_bar.fraction).to be_within(0.001).of(0.42)
    end

    it "says it is finishing up at the end" do
      popover.progress = 1.0

      expect(popover.progress_bar.text).to eq("Finishing up…")
    end
  end

  describe "#pulse" do
    it "says it is estimating" do
      popover.pulse

      expect(popover.progress_bar.text).to eq("Estimating…")
    end
  end
end
