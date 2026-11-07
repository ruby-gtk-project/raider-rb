# frozen_string_literal: true

require 'adwaita'

require_relative 'translation'

# ShortcutsDialog lists the keyboard shortcuts.
#
# A direct port of upstream's src/raider-shortcuts.blp: an Adw.ShortcutsDialog
# with one "General" section holding five items, each naming the action it
# documents rather than the keys that action happens to be bound to. GTK looks
# the accelerator up on the application, so rebinding an accelerator in
# lib/main.rb changes what this dialog shows.
#
# The dialog sets no title, as src/raider-shortcuts.blp:4 sets none;
# libadwaita supplies its own translated default.
class ShortcutsDialog < Adwaita::ShortcutsDialog
  include Translation

  # Upstream's section, as title => [[item title, action name], …].
  def sections
    {
      _('General') => [
        [_('Add Files'), 'app.open'],
        [_('New Window'), 'app.new-window'],
        [_('Keyboard Shortcuts'), 'app.shortcuts'],
        [_('Close Window'), 'app.close'],
        [_('Quit'), 'app.quit'],
      ],
    }
  end

  def build
    tap do |dialog|
      sections.each do |title, items|
        dialog.add(section(title, items))
      end
    end
  end

  private

    def section(title, items)
      Adwaita::ShortcutsSection.new.tap do |section|
        section.title = title
        items.each { |item_title, action_name| section.add(item(item_title, action_name)) }
      end
    end

    # Adwaita::ShortcutsItem advertises two constructors — (title,
    # accelerator) and (title, action_name) — and only the first is reachable,
    # so the item is made with an empty accelerator and the action is set
    # afterwards. With action-name set, libadwaita resolves the accelerator
    # from the application and ignores the empty one.
    def item(title, action_name)
      Adwaita::ShortcutsItem.new(title, '').tap do |shortcut|
        shortcut.action_name = action_name
      end
    end
end
