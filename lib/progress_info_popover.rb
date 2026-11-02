# frozen_string_literal: true

require 'adwaita'

require_relative 'translation'

# ProgressInfoPopover shows how far along one file's shredding is.
#
# Ported from upstream's src/raider-progress-info-popover.blp and
# src/raider-progress-info-popover.c: a popover holding a single progress bar
# whose text doubles as the status. The four states are upstream's, including
# the deliberate full bar it shows while the first pass has not reported yet:
#
#   0%              "Starting…"      bar full
#   between         "42%"            bar at the fraction
#   100%            "Finishing up…"  bar pulsing
#   #pulse          "Estimating…"    bar pulsing
class ProgressInfoPopover < Gtk::Popover
  include Translation

  PULSE_STEP = 0.02

  def build
    tap do |popover|
      popover.child = popover_box

      popover_box.tap do |box|
        box.append(progress_bar)
      end
    end
  end

  def progress=(fraction)
    (fraction.to_f * 100.0).then do |percentage|
      if percentage <= 0
        show_starting
      elsif percentage < 100
        show_fraction(fraction.to_f, percentage)
      else
        show_finishing
      end
    end
  end

  # Used when the row shows the spinner instead of the progress icon, so there
  # is no fraction to show yet.
  def pulse
    tap do
      progress_bar.text = _('Estimating…')
      progress_bar.pulse
    end
  end

  def popover_box = @popover_box ||= Gtk::Box.new(:horizontal, 0)

  def progress_bar
    @progress_bar ||= Gtk::ProgressBar.new.tap do |bar|
      bar.show_text = true
      bar.hexpand = true
      bar.pulse_step = PULSE_STEP
    end
  end

  private

    def show_starting
      progress_bar.text = _('Starting…')
      progress_bar.fraction = 1
    end

    def show_fraction(fraction, percentage)
      progress_bar.text = "#{percentage.to_i}%"
      progress_bar.fraction = fraction
    end

    def show_finishing
      progress_bar.text = _('Finishing up…')
      progress_bar.pulse
    end
end
