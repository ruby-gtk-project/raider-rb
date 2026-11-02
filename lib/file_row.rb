# frozen_string_literal: true

require 'adwaita'

require_relative 'corrupt'
require_relative 'progress_info_popover'
require_relative 'progress_paintable'

# FileRow is one file in the window's list: its basename as the title, its
# full path as the subtitle, and a trailing button that is either "remove" or
# the shredding progress.
#
# Ported from upstream's src/raider-file-row.blp and src/raider-file-row.c.
# The two trailing buttons live in revealers that slide one out as the other
# slides in, exactly as upstream, and while shredding the row's activatable
# widget is the progress button so activating the row opens the popover.
#
# Upstream parents a bare Gtk.Popover to the progress button by hand and pops
# it up from the button's "clicked" handler. Here the progress button is a
# Gtk::MenuButton holding the same popover: the bindings have no equivalent of
# gtk_widget_set_parent for a popover, and a menu button owns its popover and
# pops it up for free.
#
# Progress arrives on the Corrupt worker thread, so every update is deferred
# to the main loop before it reaches a widget — upstream's
# g_main_context_invoke of raider_file_row_update_progress_ui.
class FileRow < Adwaita::ActionRow
  REMOVE_ICON = 'edit-delete-symbolic'

  attr_reader :path

  def initialize(path, window)
    super()
    @path = path
    @window = window
    @corrupt = nil
    self.title = File.basename(path)
    self.subtitle = path
    self.selectable = false
    self.activatable = true
    self.use_markup = false
  end

  def build
    tap do |row|
      row.add_suffix(controls)

      controls.tap do |box|
        box.append(remove_revealer)
        box.append(progress_revealer)

        remove_revealer.tap do |revealer|
          revealer.child = remove_button
          remove_button.signal_connect('clicked') { close }
        end

        progress_revealer.tap do |revealer|
          revealer.child = progress_button

          progress_button.tap do |button|
            button.child = progress_paintable.build
            button.popover = popover.build
          end
        end
      end
    end
  end

  # Upstream's raider_file_row_launch_shredding.
  def launch_shredding
    tap do
      @window.show_notification = true
      self.activatable_widget = progress_button
      remove_revealer.reveal_child = false
      progress_revealer.reveal_child = true
      start_corrupt
    end
  end

  # Upstream's raider_file_row_shredding_abort: flip the row back, cancel, and
  # block until the worker has noticed.
  def shredding_abort
    tap do
      self.activatable_widget = nil
      remove_revealer.reveal_child = true
      progress_revealer.reveal_child = false
      popover.visible = false
      @corrupt&.cancel
      @corrupt&.wait
    end
  end

  # Upstream's raider_file_row_close: drop the row from the window's book
  # keeping and then from the list box it sits in.
  def close
    tap do |row|
      if shredded?
        @window.show_notification = true
      end
      @window.close_file(row)
      parent&.remove(row)
    end
  end

  def controls
    @controls ||= Gtk::Box.new(:horizontal, 0).tap do |box|
      box.valign = :center
    end
  end

  def remove_revealer
    @remove_revealer ||= Gtk::Revealer.new.tap do |revealer|
      revealer.reveal_child = true
      revealer.transition_type = :slide_left
    end
  end

  def remove_button
    @remove_button ||= Gtk::Button.new.tap do |button|
      button.icon_name = REMOVE_ICON
      button.tooltip_text = 'Remove'
      button.valign = :center
      button.add_css_class('flat')
    end
  end

  def progress_revealer
    @progress_revealer ||= Gtk::Revealer.new.tap do |revealer|
      revealer.reveal_child = false
      revealer.transition_type = :slide_left
    end
  end

  def progress_button
    @progress_button ||= Gtk::MenuButton.new.tap do |button|
      button.tooltip_text = 'Shredding Progress'
      button.valign = :center
      button.always_show_arrow = false
      button.add_css_class('flat')
    end
  end

  def popover = @popover ||= ProgressInfoPopover.new
  def progress_paintable = @progress_paintable ||= ProgressPaintable.new

  private

    # A row whose shredding ran to completion is what makes the window show
    # the "finished shredding" notification; an aborted one does not.
    def shredded? = !@corrupt.nil? && !@corrupt.cancelled?

    # A fresh Corrupt per run, as upstream builds a fresh RaiderCorrupt, so a
    # row that was aborted can be shredded again.
    def start_corrupt
      Corrupt.new(@path, on_progress: method(:update_progress)).tap do |corrupt|
        @corrupt = corrupt
        corrupt.start { |error| finish_on_main_loop(error) }
      end
    end

    def update_progress(fraction)
      GLib::Idle.add do
        progress_paintable.progress = fraction
        popover.progress = fraction
        false
      end
    end

    def finish_on_main_loop(error)
      GLib::Idle.add do
        shredding_finished(error)
        false
      end
    end

    # Upstream's shredding_finished: the popover goes away, and a run that was
    # not aborted takes the row with it.
    def shredding_finished(error)
      popover.visible = false
      if error
        warn(error)
      end
      if @corrupt.cancelled?
        nil
      else
        close
      end
    end
end
