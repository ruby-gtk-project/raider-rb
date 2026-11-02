# frozen_string_literal: true

require 'adwaita'

# ProgressPaintable is the 16px progress indicator on a file row's button: an
# arc that fills clockwise as the file is shredded, cross-fading into a check
# icon once it is done.
#
# Ported from upstream's src/raider-progress-paintable.c, which implements
# GdkPaintable and GtkSymbolicPaintable and draws both the arc (Cairo) and the
# check icon (a symbolic icon paintable) in one snapshot. GObject interfaces
# cannot be implemented from Ruby, so the same picture is composed out of
# widgets instead: a Gtk::DrawingArea draws the arc with the same Cairo calls
# upstream makes, a Gtk::Image holds the check icon, and a Gtk::Overlay stacks
# them. `check_progress` cross-fades between the two by opacity, where
# upstream scales them around their centre.
#
# Upstream's arc is drawn in the symbolic colour handed to snapshot_symbolic;
# here it comes from the drawing area's own style, which resolves to the same
# foreground colour the button's icon would use.
class ProgressPaintable
  SIZE = 16
  CHECK_ICON = 'object-select-symbolic'
  LINE_WIDTH = 2.0
  TRACK_ALPHA = 0.25
  FADE_INTERVAL = 40
  FADE_STEP = 0.1

  attr_reader :progress, :check_progress

  def initialize
    @progress = 0.0
    @check_progress = 0.0
    @fading = false
  end

  def build
    overlay.tap do |ov|
      ov.child = arc
      ov.add_overlay(check)

      arc.tap do |area|
        area.set_draw_func { |_, context, width, height| draw(context, width, height) }
      end
    end
  end

  # The arc redraws on every update, and reaching the end starts the fade to
  # the check icon.
  def progress=(fraction)
    @progress = fraction.to_f.clamp(0.0, 1.0)
    arc.queue_draw
    if @progress >= 1.0
      start_fade
    end
  end

  def check_progress=(value)
    @check_progress = value.to_f.clamp(0.0, 1.0)
    arc.opacity = 1.0 - @check_progress
    check.opacity = @check_progress
  end

  def overlay = @overlay ||= Gtk::Overlay.new

  def arc
    @arc ||= Gtk::DrawingArea.new.tap do |area|
      area.content_width = SIZE
      area.content_height = SIZE
      area.valign = :center
      area.halign = :center
    end
  end

  def check
    @check ||= Gtk::Image.new(icon_name: CHECK_ICON).tap do |image|
      image.pixel_size = SIZE
      image.opacity = 0.0
    end
  end

  private

    def start_fade
      unless @fading
        @fading = true
        GLib::Timeout.add(FADE_INTERVAL) do
          self.check_progress = @check_progress + FADE_STEP
          @check_progress < 1.0
        end
      end
    end

    # Upstream's snapshot_symbolic: the completed sweep in the symbolic
    # colour, then the remainder of the circle at a quarter of its alpha.
    def draw(context, width, height)
      stroke_color.then do |color|
        context.translate(width / 2.0, height / 2.0)
        context.line_width = LINE_WIDTH
        stroke_arc(
          context,
          color,
          1.0,
          -Math::PI / 2.0,
          arc_end,
        )
        stroke_arc(
          context,
          color,
          TRACK_ALPHA,
          arc_end,
          3.0 * Math::PI / 2.0,
        )
      end
    end

    def stroke_arc(context, color, alpha, from, to)
      context.set_source_rgba(
        color.red,
        color.green,
        color.blue,
        color.alpha * alpha,
      )
      context.arc(
        0,
        0,
        radius,
        from,
        to,
      )
      context.stroke
    end

    def arc_end = (@progress * Math::PI * 2.0) - (Math::PI / 2.0)

    def radius = (SIZE / 2.0) - (LINE_WIDTH / 2.0)

    # The widget's foreground colour, which is what the symbolic icon beside
    # it is drawn in. A theme that cannot be queried yet (before the drawing
    # area is realized) falls back to plain white, which is legible on the
    # dark button the row shows while shredding.
    def stroke_color
      arc.style_context.color
    rescue StandardError
      Gdk::RGBA.new(
        1.0,
        1.0,
        1.0,
        1.0,
      )
    end
end
