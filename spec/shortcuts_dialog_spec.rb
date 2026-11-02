# frozen_string_literal: true

require "shortcuts_dialog"

RSpec.describe ShortcutsDialog do
  subject(:dialog) { described_class.new.build }

  it "keeps libadwaita's own translated title" do
    expect(dialog.title).to eq(Adwaita::ShortcutsDialog.new.title)
  end

  it "lists upstream's one section" do
    expect(dialog.sections.keys).to eq(["General"])
  end

  it "names an action per item rather than an accelerator" do
    expect(dialog.sections.fetch("General")).to eq(
      [
        ["Add Files", "app.open"],
            ["New Window", "app.new-window"],
            ["Keyboard Shortcuts", "app.shortcuts"],
            ["Close Window", "app.close"],
            ["Quit", "app.quit"],
      ],
    )
  end

  it "builds items that carry the action name and no hardcoded accelerator" do
    item = dialog.send(:item, "Add Files", "app.open")

    expect(item.action_name).to eq("app.open")
    expect(item.accelerator).to eq("")
    expect(item.title).to eq("Add Files")
  end

  it "documents every action the application binds an accelerator to" do
    accelerated = App::ACTIONS.reject { |_name, accels| accels.empty? }.keys

    expect(dialog.sections.fetch("General").map(&:last)).to include(*accelerated.map { |name| "app.#{name}" })
  end
end
