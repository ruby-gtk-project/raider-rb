# frozen_string_literal: true

require 'adwaita'

require_relative 'translation'

# ExitDialog asks whether a window with shredding in flight may be closed.
#
# Ported from the alert dialog raider_window_exit builds in
# src/raider-window.c: "Stop Shredding?", a Cancel that is both the default
# and the close response, and a destructive Exit. Choosing Exit runs the
# block, which aborts the shredding and then destroys the window.
#
# The leading underscores in the response labels are the Alt-key mnemonics and
# are part of the msgid, because translators pick a mnemonic that works in
# their own language.
class ExitDialog < Adwaita::AlertDialog
  include Translation

  CANCEL = 'cancel'
  EXIT = 'exit'

  def initialize(&on_exit)
    super(_('Stop Shredding?'), _('Are you sure that you want to exit?'))
    @on_exit = on_exit
  end

  def build
    tap do |dialog|
      dialog.add_response(CANCEL, _('_Cancel'))
      dialog.add_response(EXIT, _('_Exit'))
      dialog.set_response_appearance(EXIT, :destructive)
      dialog.default_response = CANCEL
      dialog.close_response = CANCEL
      dialog.signal_connect('response') { |_, response| respond(response) }
    end
  end

  private

    def respond(response)
      if response == EXIT
        @on_exit&.call
      end
    end
end
