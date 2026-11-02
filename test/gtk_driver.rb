# frozen_string_literal: true

# A tiny harness for driving a Ruby GTK4 app from the outside.
#
# The problem it solves: GTK only does its work while the main loop is running,
# so you cannot open a dialog and inspect it on the next line — the dialog does
# not exist yet. Every action needs its own turn of the loop. This runs your
# steps one per timeout tick, which gives GTK a chance to lay out, render and
# settle in between.
#
#   require_relative 'gtk_driver'
#
#   GtkDriver.drive(MyApp.new, shots: 'tmp/shots') do |d, app|
#     d.window { app.main_view.window }
#
#     d.step('load files') { app.controller.load_pictures(uris) }
#
#     d.step('inspect') do
#       d.check('7 loaded') { app.controller.model.n_pictures == 7 }
#       d.shot('01-main')
#     end
#   end
#
# Run it with no display server at all — GTK4 renders to an offscreen surface
# and screenshots come out identical to a real session. No Xvfb needed.
module GtkDriver
  # Steps run one per tick. 500ms is comfortable for anything that only touches
  # widgets; raise it if a step kicks off real I/O you want settled before the
  # next one looks at the results.
  DEFAULT_INTERVAL = 500

  # A hung app would otherwise block forever, which is much worse than a
  # failure — you get no output at all to diagnose.
  DEFAULT_TIMEOUT = 120

  # How many frames a screenshot waits out before it gives up on an animation
  # settling, and how long a frame is taken to be. Six rounds at 60Hz is a
  # tenth of a second, which is longer than any Adwaita transition.
  SETTLE_ROUNDS = 6
  SETTLE_FRAME = 1.0 / 60

  # Drives `app_object` (anything answering `build`, per the house pattern
  # `MyApp.new.build.run`) through the steps registered in the block.
  #
  # Exits non-zero if any step raised or any check failed, so this works
  # directly as a test command.
  def self.drive(app_object, shots: nil, interval: DEFAULT_INTERVAL,
                 timeout: DEFAULT_TIMEOUT, &block)
    Session.new(app_object, shots: shots, interval: interval, timeout: timeout)
           .run(&block)
  end

  class Session
    attr_reader :app_object

    def initialize(app_object, shots:, interval:, timeout:)
      @app_object = app_object
      @shots = shots
      @interval = interval
      @timeout = timeout
      @steps = []
      @checks = 0
      @failed_checks = []
      @errored_steps = []
      @window_block = nil
    end

    # --- Registered from inside the block ---------------------------------

    # Names the widget screenshots default to. It is a block, not a value,
    # because the window usually does not exist until the app has activated.
    def window(&block)
      @window_block = block
    end

    def step(name, &block)
      @steps << [name, block]
    end

    # --- Called from inside a step ----------------------------------------

    # Records a pass/fail. Prefer several small checks over one big one: when
    # something breaks you want to know which part.
    def check(description)
      @checks += 1
      yield.then do |ok|
        puts(ok ? "    ok   #{description}" : "    FAIL #{description}")
        unless ok
          @failed_checks << description
        end
        ok
      end
    rescue StandardError => e
      puts "    FAIL #{description} (#{e.class}: #{e.message})"
      @failed_checks << description
      false
    end

    # Writes a PNG of `widget` (the default window if omitted).
    #
    # Screenshots are the point of this harness: read them back and look at
    # them. Assertions confirm what you thought to ask about; the picture shows
    # you the thing you did not think to ask about — a label that never got
    # set, a row that renders blank, a dialog that opened behind the window.
    def shot(name, widget = nil)
      if @shots.nil?
        raise 'no shots directory configured'
      end

      (widget || default_window).then do |target|
        if target.nil?
          raise 'no widget to screenshot'
        end

        require 'fileutils'
        FileUtils.mkdir_p(@shots)

        File.join(@shots, "#{name}.png").then do |path|
          render(target, path)
          puts "    shot #{path}"
          path
        end
      end
    rescue StandardError => e
      puts "    shot #{name} failed: #{e.class}: #{e.message}"
      nil
    end

    def default_window = @window_block&.call

    # --- Running -----------------------------------------------------------

    def run
      yield(self, app_object)

      gtk_application(app_object.build).tap do |application|
        application.signal_connect('activate') { schedule(application) }
        arm_watchdog(application)
        application.run([])
      end

      report
    end

    private

      # In the plain house pattern `MyApp.new.build.run`, `build` answers the
      # GApplication itself. A port whose App object keeps the application
      # behind an accessor — raider's does, so #run can answer --version
      # without starting a main loop — answers itself instead, and the
      # application is its #app.
      def gtk_application(built)
        if built.respond_to?(:signal_connect)
          built
        else
          built.app
        end
      end

      def schedule(application)
        index = 0

        GLib::Timeout.add(@interval) do
          if index < @steps.length
            run_step(@steps[index], index)
            index += 1
            true
          else
            application.quit
            false
          end
        end
      end

      def run_step((name, block), index)
        puts "[#{index}] #{name}"
        block.call
      rescue StandardError => e
        # One broken step should not hide the rest of the run — the later steps
        # often show whether the damage spread.
        puts "    ERROR #{e.class}: #{e.message}"
        puts "      #{e.backtrace.first(3).join("\n      ")}"
        @errored_steps << "#{name} (#{e.class}: #{e.message})"
      end

      def arm_watchdog(application)
        GLib::Timeout.add_seconds(@timeout) do
          puts "TIMEOUT after #{@timeout}s - the app never finished its steps"
          @errored_steps << 'watchdog timeout'
          application.quit
          false
        end
      end

    # GTK4 has no screenshot call. The route that works headlessly is to paint
    # the widget into a render node and hand that to a renderer, which returns
    # a texture that knows how to write a PNG.
      def render(widget, path)
        settle
        node_for(widget).then do |node|
          if node.nil?
            raise 'widget produced no render node (not realised yet?)'
          end

          write_png(node, path)
        end
      end

    # A widget that changed on this turn of the loop can still snapshot to
    # nothing after one settle — a stack mid-crossfade hands back no node at
    # all — so the snapshot is retried rather than the picture being lost.
      def node_for(widget, attempts: SETTLE_ROUNDS)
        (1..attempts).reduce(nil) do |found, _|
          if found
            found
          else
            snapshot_once(widget).then do |node|
              if node.nil?
                settle
              end
              node
            end
          end
        end
      end

      def snapshot_once(widget)
        Gtk::Snapshot.new.then do |snapshot|
          Gtk::WidgetPaintable.new(widget).snapshot(snapshot, widget.width, widget.height)
          snapshot.to_node
        end
      end

      def write_png(node, path)
        Gsk::CairoRenderer.new.tap do |renderer|
          renderer.realize(nil)

          begin
            renderer.render_texture(node, nil).save_to_png(path)
          ensure
            renderer.unrealize
          end
        end
      end

    # A widget whose state changed on this turn of the loop has not been laid
    # out yet, and an unlaid-out widget snapshots to nothing. Giving the loop
    # its pending work back first is what makes a shot taken straight after a
    # change come out as a picture rather than as nil.
    #
    # A widget mid-animation — a revealer sliding, a stack crossfading — needs
    # the frame clock to tick as well, and the clock's work is not pending
    # until the frame is due, so each round waits a frame out before draining
    # again.
      def settle(rounds: SETTLE_ROUNDS)
        GLib::MainContext.default.then do |context|
          rounds.times do
            while context.pending?
              context.iteration(false)
            end
            sleep(SETTLE_FRAME)
          end
        end
      end

      def report
        puts
        if @checks.positive?
          puts "#{@checks - @failed_checks.length} of #{@checks} checks passed"
        end
        @failed_checks.each { |check| puts "  failed check: #{check}" }
        @errored_steps.each { |step| puts "  errored step: #{step}" }

        (@failed_checks + @errored_steps).length.then do |total|
          puts(total.zero? ? 'DRIVE OK' : "DRIVE FAILED (#{total})")
          exit(total.zero? ? 0 : 1)
        end
      end
  end
end
