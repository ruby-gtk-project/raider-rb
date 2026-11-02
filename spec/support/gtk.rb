# frozen_string_literal: true

require "tmpdir"

require "raider"

# GtkSupport is the small amount of plumbing every widget spec needs.
#
# GTK does its work *between* callbacks: a widget is not laid out, a dialog
# does not exist and a revealer has not moved until control goes back to the
# main loop. The port's shredding is also asynchronous by design — Window
# launches the rows from a worker thread and marshals the widget work back
# through GLib's idle queue, as upstream's two GTasks do — so a spec that
# asserts straight after calling `start_shredding` is asserting on a frame
# that has not happened yet. `pump_until` gives the loop its turns back.
module GtkSupport
  # Long enough for five overwrite passes over the small fixtures these specs
  # write, short enough that a wedged run still reports.
  TIMEOUT = 20.0
  IDLE_SLEEP = 0.005

  module_function

  # One application for the whole suite. It has to be one: GTK complains when
  # a window is added to an application that has not emitted ::startup,
  # Gio::Application#send_notification asserts on being registered — which the
  # "finished shredding" announcement does when the window is not active — and
  # registering a second application on the same id exports the same D-Bus
  # object twice.
  def app
    @app ||= App.new.build.tap { |built| built.app.register }
  end

  def application = app.app

  def window
    Window.new(application).tap(&:build)
  end

  def context = GLib::MainContext.default

  # Turns of the main loop until the block answers true. Answers whether it
  # did, so a spec asserts on the outcome rather than on the timeout.
  def pump_until(timeout: TIMEOUT)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    until yield
      if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        break
      end

      pump_once
    end
    yield
  end

  # Drains whatever is already queued, which is what an assertion about a
  # widget the current turn has just touched needs.
  def pump
    while context.pending?
      context.iteration(false)
    end
  end

  def pump_once
    if context.pending?
      context.iteration(false)
    else
      sleep(IDLE_SLEEP)
    end
  end

  # A worker thread a spec left running hands widget work back through the
  # idle queue, and a launch a spec queued but never pumped is still queued.
  # Draining at the end of every example keeps both inside the example that
  # caused them instead of firing in the middle of the next one.
  def drain(timeout: TIMEOUT)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      pump
      sleep(IDLE_SLEEP)
      if !context.pending? || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        break
      end
    end
    pump
  end

  # A file of `size` bytes with known content, in a directory the example
  # owns.
  def write_file(directory, name, size: 64)
    File.join(directory, name).tap do |path|
      File.write(path, "r" * size)
    end
  end
end
