# frozen_string_literal: true

require "progress_paintable"

RSpec.describe ProgressPaintable do
  subject(:paintable) { described_class.new }

  it "draws into a box wide enough for a ring upstream strokes outside the icon" do
    area = paintable.build

    expect(area).to be_a(Gtk::DrawingArea)
    expect(described_class::BOX).to eq(described_class::SIZE + 4)
    expect(area.content_width).to eq(described_class::BOX)
    expect(area.content_height).to eq(described_class::BOX)
  end

  it "redraws when the scale factor changes" do
    area = paintable.build

    expect(paintable).to receive(:follow_scale_factor).and_call_original

    area.signal_emit("notify::scale-factor", area.class.property("scale-factor"))
  end

  it "strokes at upstream's radius and line width" do
    expect(paintable.send(:radius)).to eq(9.0)
    expect(described_class::LINE_WIDTH).to eq(2.0)
    expect(described_class::TRACK_ALPHA).to eq(0.25)
  end

  it "sweeps clockwise from the top" do
    expect(paintable.send(:arc_end)).to be_within(0.0001).of(-Math::PI / 2.0)

    paintable.progress = 1.0

    expect(paintable.send(:arc_end)).to be_within(0.0001).of(3.0 * Math::PI / 2.0)
  end

  it "clamps the progress it is given" do
    paintable.progress = 2.5
    expect(paintable.progress).to eq(1.0)

    paintable.progress = -1.0
    expect(paintable.progress).to eq(0.0)
  end

  it "draws no check icon, because upstream's cross-fade never runs" do
    expect(paintable).not_to respond_to(:check_progress)
    expect(described_class.constants).not_to include(:CHECK_ICON)
    expect(paintable.build.children).to be_empty
  end
end
