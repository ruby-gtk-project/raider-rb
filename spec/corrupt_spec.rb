# frozen_string_literal: true

require "fileutils"
require "stringio"
require "tmpdir"

require "corrupt"

RSpec.describe Corrupt do
  # Answers [error, progress]. The finish block runs on the worker thread, so
  # the result comes back through a queue rather than an assignment.
  def shred(path)
    progress = []
    done = Queue.new
    described_class.new(path, on_progress: ->(fraction) { progress << fraction })
      .start { |message| done.push([message]) }
    [done.pop(timeout: GtkSupport::TIMEOUT)&.first, progress]
  end

  it "has upstream's five three-byte patterns" do
    expect(described_class::PATTERNS).to eq(
      [
        "\x77\x77\x77",
            "\x76\x76\x76",
            "\x33\x33\x33",
            "\x35\x35\x35",
            "\x55\x55\x55",
      ],
    )
  end

  context "with a regular file" do
    it "overwrites it, unlinks it, and reports one step per pass" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, "secret.txt")
        File.write(path, "the quick brown fox")

        error, progress = shred(path)

        expect(error).to be_nil
        expect(File).not_to exist(path)
        expect(progress.first).to eq(0.0)
        expect(progress.last).to eq(1.0)
        expect(progress.length).to eq(described_class::PATTERNS.length + 1)
      end
    end
  end

  context "with a zero-byte file" do
    it "unlinks it and still runs every pass" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, "empty")
        File.write(path, "")

        error, progress = shred(path)

        expect(error).to be_nil
        expect(File).not_to exist(path)
        expect(progress.last).to eq(1.0)
      end
    end
  end

  context "with a folder" do
    it "shreds every file in the tree and removes the directories" do
      Dir.mktmpdir do |directory|
        tree = File.join(directory, "tree")
        nested = File.join(tree, "nested")
        FileUtils.mkdir_p(nested)
        File.write(File.join(tree, "one.txt"), "one")
        File.write(File.join(nested, "two.txt"), "two")

        error, progress = shred(tree)

        expect(error).to be_nil
        expect(Dir).not_to exist(tree)
        expect(progress.first).to eq(0.0)
      end
    end
  end

  # Regression test for gap C5 (component-parity.md): a directory that
  # cannot even be opened for listing (src/corrupt.c:219-224's fprintf) must
  # be reported with that diagnostic and left alone, distinct from a
  # directory that fails to be *removed*. A revert that let the listing
  # error fall through to #remove_directory's "failed to remove folder"
  # message, or that attempted rmdir on a directory it never listed, would
  # print the wrong diagnostic and could try to remove a directory whose
  # contents were never accounted for.
  describe "#openable_entries with a directory this process cannot list (C5)" do
    it "prints the listing diagnostic, returns nil, and never calls rmdir" do
      Dir.mktmpdir do |directory|
        locked = File.join(directory, "locked")
        FileUtils.mkdir_p(locked)
        File.chmod(0o000, locked)

        begin
          corrupt = described_class.new(locked)

          stderr = StringIO.new
          result = nil
          original_stderr = $stderr
          begin
            $stderr = stderr
            result = corrupt.send(:openable_entries, locked)
          ensure
            $stderr = original_stderr
          end

          expect(result).to be_nil
          expect(stderr.string).to include("corrupt: failed to open directory for removal")
          expect(stderr.string).not_to include("failed to remove folder")
          # rmdir was never attempted on a directory #openable_entries could
          # not even list: it is still there, not merely still full.
          expect(File).to be_directory(locked)
        ensure
          File.chmod(0o755, locked) if File.directory?(locked)
        end
      end
    end
  end

  describe "#cancel" do
    it "stops the write loop and reports the cancellation" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, "big.bin")
        File.write(path, "z" * (2 * 1024 * 1024))

        corrupt = described_class.new(path)
        done = Queue.new
        corrupt.start { |message| done.push([message]) }
        corrupt.cancel

        expect(corrupt).to be_cancelled
        expect(done.pop(timeout: GtkSupport::TIMEOUT)&.first).to eq(described_class::CANCELLED)
        expect(File).to exist(path)
      end
    end
  end

  describe "#wait" do
    it "returns once the worker has stopped" do
      Dir.mktmpdir do |directory|
        path = File.join(directory, "small")
        File.write(path, "x")

        corrupt = described_class.new(path)
        corrupt.start
        corrupt.wait

        expect(File).not_to exist(path)
      end
    end
  end
end
