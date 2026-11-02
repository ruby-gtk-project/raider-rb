# frozen_string_literal: true

require 'adwaita'

# ExitDialog asks whether a window with shredding in flight may be closed.
#
# Ported from the alert dialog raider_window_exit builds in
# src/raider-window.c: "Stop Shredding?", a Cancel that is both the default
# and the close response, and a destructive Exit. Choosing Exit runs the
# block, which aborts the shredding and then destroys the window.
class ExitDialog < Adwaita::AlertDialog
  HEADING = 'Stop Shredding?'
  BODY = 'Are you sure that you want to exit?'

  CANCEL = 'cancel'
  EXIT = 'exit'

  def initialize(&on_exit)
    super(HEADING, BODY)
    @on_exit = on_exit
  end

  def build
    tap do |dialog|
      dialog.add_response(CANCEL, '_Cancel')
      dialog.add_response(EXIT, '_Exit')
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
