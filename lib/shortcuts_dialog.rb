# frozen_string_literal: true

require 'adwaita'

# ShortcutsDialog lists the keyboard shortcuts.
#
# A direct port of upstream's src/raider-shortcuts.blp: an Adw.ShortcutsDialog
# with one "General" section holding the five items below. Upstream names an
# action per item and lets GTK look its accelerator up; the bindings have no
# way to resolve that, so each item carries the accelerator this port binds in
# lib/main.rb.
class ShortcutsDialog < Adwaita::ShortcutsDialog
  SECTIONS = {
    'General' => [
      ['Add Files', '<Ctrl>o'],
      ['New Window', '<Ctrl>n'],
      ['Keyboard Shortcuts', '<Ctrl>question'],
      ['Close Window', '<Ctrl>w'],
      ['Quit', '<Ctrl>q'],
    ],
  }.freeze

  def initialize
    super()
    self.title = 'Keyboard Shortcuts'
  end

  def build
    tap do |dialog|
      SECTIONS.each do |title, items|
        dialog.add(section(title, items))
      end
    end
  end

  private

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |section|
        section.title = title
        items.each { |label, accelerator| section.add(item(label, accelerator)) }
      end
    end

    # Positional, not keyword, arguments — even though the error a no-argument
    # new raises advertises the signatures as "title: utf8, accelerator: utf8".
    def item(label, accelerator) = Adwaita::ShortcutsItem.new(label, accelerator)
end
