# frozen_string_literal: true

require "exit_dialog"

RSpec.describe ExitDialog do
  it "asks upstream's question" do
    dialog = described_class.new.build

    expect(dialog.heading).to eq("Stop Shredding?")
    expect(dialog.body).to eq("Are you sure that you want to exit?")
  end

  it "offers a default Cancel and a destructive Exit, mnemonics included" do
    dialog = described_class.new.build

    expect(dialog.get_response_label(described_class::CANCEL)).to eq("_Cancel")
    expect(dialog.get_response_label(described_class::EXIT)).to eq("_Exit")
    expect(dialog.get_response_appearance(described_class::EXIT)).to eq(Adwaita::ResponseAppearance::DESTRUCTIVE)
    expect(dialog.default_response).to eq(described_class::CANCEL)
    expect(dialog.close_response).to eq(described_class::CANCEL)
  end

  it "runs the block only for Exit" do
    exited = []
    dialog = described_class.new { exited << :exit }.build

    dialog.signal_emit("response", described_class::CANCEL)
    expect(exited).to be_empty

    dialog.signal_emit("response", described_class::EXIT)
    expect(exited).to eq([:exit])
  end
end
