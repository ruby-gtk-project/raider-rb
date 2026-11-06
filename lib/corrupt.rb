# frozen_string_literal: true

# Corrupt overwrites a file with fixed byte patterns and then unlinks it.
#
# Ported from upstream's src/corrupt.c. The patterns, the pass count and the
# odd write arithmetic are upstream's: the file is overwritten once per entry
# in PATTERNS, each pass writing the three-byte pattern
# `(size / 3) + (size % 3)` times from the start of the file, and the file is
# removed once every pass has run.
#
# A folder is shredded by walking it depth first, shredding every file it
# holds and then removing the (now empty) directories. Progress for a folder
# is the fraction of its files that have been dealt with; progress for a
# single file is the fraction of its passes that have completed.
#
# The shredding runs on a Ruby thread rather than upstream's GTask worker, and
# the cancellable is a flag this object owns: #cancel sets it, the write loop
# polls it between writes, and #wait blocks until the worker has stopped — the
# job upstream's GMutex does in raider_file_row_shredding_abort.
#
# No GTK here. The caller supplies an `on_progress` callable, which is invoked
# on the worker thread, so a UI caller is responsible for hopping back to the
# main loop before it touches a widget.
class Corrupt
  # The size of this array is how many times the file is overwritten.
  PATTERNS = [
    "\x77\x77\x77",
    "\x76\x76\x76",
    "\x33\x33\x33",
    "\x35\x35\x35",
    "\x55\x55\x55",
  ].freeze

  PATTERN_LENGTH = 3

  CANCELLED = 'corrupt: shredding cancelled'
  NOT_FOUND = 'corrupt: current file not found'
  NOT_REGULAR = 'corrupt: current file is not a regular file'

  attr_reader :path

  def initialize(path, on_progress: nil)
    @path = path
    @on_progress = on_progress
    @cancelled = false
    @thread = nil
  end

  # Starts the shredding on its own thread. The block is called with the error
  # message the run ended on, or nil when it ended cleanly.
  def start(&on_finished)
    tap do
      @thread = Thread.new do
        shred.then { |error| on_finished&.call(error) }
      end
    end
  end

  def cancel
    tap do
      @cancelled = true
    end
  end

  def cancelled? = @cancelled

  # Blocks until the worker thread has stopped.
  def wait
    tap do
      @thread&.join
    end
  end

  private

    def shred
      if File.directory?(@path)
        shred_folder
      else
        shred_single
      end
    end

    # Upstream's corrupt_folder, plus the corrupt_unlink_folder it runs when
    # every file in the tree was dealt with.
    def shred_folder
      list_files(@path).then do |files|
        shred_each(files).then do |error|
          if error.nil?
            unlink_folder(@path)
          end
          error
        end
      end
    end

    def shred_each(files)
      error = nil
      files.each_with_index do |file, index|
        report(index.to_f / files.length)
        error = shred_member(file)
        if error
          break
        end
      end
      error
    end

    # A file inside a folder: one that cannot be shredded at all is skipped
    # rather than failing the whole run, which is upstream's `continue`.
    def shred_member(file)
      file_size(file).then do |size|
        if size.nil?
          nil
        else
          finish_file(file, overwrite(file, size))
        end
      end
    end

    # Upstream's corrupt_file: progress starts at zero and advances once per
    # completed pass.
    def shred_single
      report(0.0)
      file_size(@path).then do |size|
        if size.nil?
          missing_message(@path)
        else
          finish_file(@path, overwrite(@path, size) { |pass| report((pass + 1).to_f / PATTERNS.length) })
        end
      end
    end

    def finish_file(file, error)
      if error.nil?
        unlink_file(file)
      end
      error
    end

    def overwrite(file, size, &after_pass)
      error = nil
      PATTERNS.each_with_index do |pattern, pass|
        error = step(file, size, pattern)
        if error
          break
        end
        after_pass&.call(pass)
      end
      error
    end

    # One pass over the file. The cancellable is polled after every write, as
    # upstream polls its GTask, so an abort stops part-way through a pass.
    def step(file, size, pattern)
      File.open(file, 'r+b') do |io|
        write_pattern(io, size, pattern)
      end
    rescue SystemCallError => error
      "corrupt: failed to perform shredding step: #{error.message}"
    end

    def write_pattern(io, size, pattern)
      stopped = false
      times(size).times do
        io.write(pattern)
        if cancelled?
          stopped = true
          break
        end
      end
      if stopped
        CANCELLED
      else
        nil
      end
    end

    def times(size) = (size / PATTERN_LENGTH) + (size % PATTERN_LENGTH)

    # Upstream's corrupt_check_file: a symbolic link is quietly unlinked and
    # skipped, anything that is not a regular file is skipped, and the size is
    # what the overwrite loop needs.
    def file_size(file)
      File.lstat(file).then do |stat|
        if stat.symlink?
          unlink_file(file)
          nil
        elsif !stat.file?
          warn(NOT_REGULAR)
          nil
        else
          stat.size
        end
      end
    rescue SystemCallError
      warn(NOT_FOUND)
      nil
    end

    def missing_message(file) = "#{NOT_FOUND}: #{file}"

    def unlink_file(file)
      File.unlink(file)
      nil
    rescue SystemCallError => error
      "corrupt: failed to remove file: #{error.message}"
    end

    # Upstream's corrupt_unlink_folder: recurse into subdirectories, then
    # remove this one. Anything still holding files is left alone. A folder
    # that cannot even be opened for listing is reported and left as-is —
    # upstream's g_dir_open failure returns before ever calling rmdir, so the
    # port must not call Dir.rmdir in that case either.
    def unlink_folder(folder)
      children = openable_entries(folder)
      if children
        children.each do |entry|
          if File.directory?(entry)
            unlink_folder(entry)
          else
            warn('directory not empty, some files skipped')
          end
        end
        remove_directory(folder)
      end
    end

    # Like #entries, but a directory this process cannot open for listing is
    # reported with upstream's own message and distinguished from an empty
    # directory, which #entries cannot do once it has swallowed the error.
    def openable_entries(folder)
      Dir.children(folder).map { |name| File.join(folder, name) }
    rescue SystemCallError
      warn('corrupt: failed to open directory for removal')
      nil
    end

    def remove_directory(folder)
      Dir.rmdir(folder)
      nil
    rescue SystemCallError
      warn('failed to remove folder')
      nil
    end

    # Upstream's list_files: every regular file under the folder, depth first.
    def list_files(folder)
      entries(folder).flat_map do |entry|
        if File.directory?(entry)
          list_files(entry)
        else
          [entry]
        end
      end
    end

    def entries(folder)
      Dir.children(folder).map { |name| File.join(folder, name) }
    rescue SystemCallError
      []
    end

    def report(fraction) = @on_progress&.call(fraction)
end
