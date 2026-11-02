# frozen_string_literal: true

require 'adwaita'

# ProgressPaintable is the progress indicator on a file row's button: an arc
# that fills clockwise as the file is shredded.
#
# Ported from upstream's src/raider-progress-paintable.c, a GObject
# implementing GdkPaintable and GtkSymbolicPaintable. Here the picture is a
# Gtk::DrawingArea making the same Cairo calls upstream's snapshot_symbolic
# makes: the completed sweep from -π/2 in the widget's foreground colour, then
# the remainder of the circle to 3π/2 at a quarter of that colour's alpha, both
# stroked at radius `width / 2 + 1` — 9px, outside the 16px icon box.
#
# The line width is Cairo's default 2.0, which is what upstream gets by never
# calling cairo_set_line_width. The ring therefore reaches 10px from the
# centre, which is why upstream hands its Cairo node a rectangle of
# `width + 4`. A widget clips to its own content size, so the drawing area is
# 20px and not 16 and the ring comes out whole.
#
# Upstream re-caches and calls gdk_paintable_invalidate_size when the widget's
# `notify::scale-factor` fires; here the same signal redraws the arc. The
# content size itself is in logical pixels and does not move with the scale
# factor — a GdkPaintable's intrinsic size is in device pixels, which is why
# upstream multiplies, and GTK already renders a drawing area's Cairo surface
# at the display scale.
#
# Upstream's `icon-name` property is never set by any caller and its
# `check_progress` is never written, so the cross-fade to a check icon in its
# snapshot_symbolic is dead code upstream. Nothing here draws one.
class ProgressPaintable
  SIZE = 16
  LINE_WIDTH = 2.0
  TRACK_ALPHA = 0.25

  # Upstream's `GRAPHENE_RECT_INIT(-2, -2, width + 4, width + 4)`.
  OVERFLOW = 2
  BOX = SIZE + (2 * OVERFLOW)

  attr_reader :progress

  def initialize
    @progress = 0.0
  end

  def build
    arc.tap do |area|
      area.set_draw_func { |_, context, width, height| draw(context, width, height) }
      area.signal_connect('notify::scale-factor') { follow_scale_factor }
    end
  end

  # The arc redraws on every update, which is upstream's
  # gdk_paintable_invalidate_contents from its progress setter.
  def progress=(fraction)
    @progress = fraction.to_f.clamp(0.0, 1.0)
    arc.queue_draw
  end

  def arc
    @arc ||= Gtk::DrawingArea.new.tap do |area|
      area.content_width = BOX
      area.content_height = BOX
      area.valign = :center
      area.halign = :center
    end
  end

  private

    # Upstream's scale_factor_changed_cb, whose two halves are a re-cache and
    # a size invalidation; both come out here as a redraw.
    def follow_scale_factor
      arc.queue_draw
    end

    # Upstream's snapshot_symbolic, minus the dead check-icon branches.
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

    # Upstream's `width / 2.0 + 1`, where the width it is handed is SIZE.
    def radius = (SIZE / 2.0) + 1

    # Upstream's arc is drawn in the first of the symbolic colours
    # snapshot_symbolic is handed, which for an icon inside a button is the
    # button's foreground colour. The drawing area resolves the same colour
    # from its own style context.
    def stroke_color = arc.style_context.color
end
