# frozen_string_literal: true

require "translation"

require "data_files"

RSpec.describe Translation do
  ROOT = File.expand_path("..", __dir__)

  # Every msgid the port marks, read back out of the source the way
  # rxgettext reads it. `_('…')` is the only marker form the port uses.
  MARKER = /(?<![A-Za-z0-9_])_\('((?:[^'\\]|\\.)*)'\)/

  def self.marked_msgids
    Dir.glob(
      File.join(
        ROOT,
        "lib",
        "**",
        "*.rb",
      ),
    )
       .reject { |path| path.end_with?("translation.rb") }
       .flat_map { |path| File.read(path).scan(MARKER).flatten }
       .uniq
  end

  def self.pot_msgids
    File.read(File.join(ROOT, "po", "com.github.ADBeveridge.Raider.pot"))
        .scan(/^msgid ((?:"(?:[^"\\]|\\.)*"\s*)+)/)
        .flatten
        .map { |block| block.scan(/"((?:[^"\\]|\\.)*)"/).flatten.join }
        .reject(&:empty?)
  end

  it "binds upstream's domain, not the gem's name" do
    expect(PackageConfig::GETTEXT_PACKAGE).to eq("raider")
  end

  it "builds a catalogue for every .po on disk" do
    languages = DataFiles.new.languages
    po_languages = Dir.glob(File.join(ROOT, "po", "*.po"))
                       .map { |path| File.basename(path, ".po") }
                       .sort

    expect(languages.length).to eq(35)
    expect(languages.sort).to eq(po_languages)
    expect(languages).to include(
      "de",
      "fr",
      "ar",
      "zh_CN",
      "cs",
      "sl",
      "pl",
    )
    languages.each do |language|
      expect(File).to exist(File.join(ROOT, "po", "#{language}.po"))
    end
  end

  it "lists the port's own files in POTFILES" do
    potfiles = File.readlines(File.join(ROOT, "po", "POTFILES"), chomp: true)
                   .reject(&:empty?)

    expect(potfiles).to all(satisfy { |path| File.exist?(File.join(ROOT, path)) })
    expect(potfiles.grep(/\.rb\z/)).not_to be_empty
    expect(potfiles.grep(%r{\Asrc/})).to be_empty
  end

  describe "the marked strings" do
    it "marks every msgid upstream's own source marks" do
      marked = self.class.marked_msgids

      expect(marked.length).to eq(34)
      expect(marked).to include(
        "File Shredder",
        "Add Files",
        "Add Folders",
        "translator-credits",
        "Starting…",
        "Finishing up…",
        "Estimating…",
        "General",
        "New Window",
        "Keyboard Shortcuts",
        "Close Window",
        "Quit",
        "Add",
        "Main Menu",
        "Add files or drop here",
        "Shred All",
        "Abort All",
        "About File Shredder",
        "Open Folder",
        "Stop Shredding?",
        "Are you sure that you want to exit?",
        "_Cancel",
        "_Exit",
        "Could not remove filename from quick list. Please report this.",
        "Finished shredding files",
        "This file was already added",
        "Some files did not exist",
        "Cannot write to “%s”",
        "Cannot load more files",
        "Starting Shredding…",
        "Aborting…",
        "Clear",
        "Clear All",
        "Shredding is the obfuscation of a file with random data so the previous contents cannot be recovered.",
      )
    end

    it "marks every msgid the shipped .pot carries that is not data-only" do
      marked = self.class.marked_msgids
      data_only = [
        "Permanently delete your files",
        /\AFile Shredder is a file deletion program/,
        /\AWithin a certain limit/,
      ]
      code_msgids = self.class.pot_msgids.reject do |msgid|
        data_only.any? { |pattern| pattern.is_a?(Regexp) ? pattern.match?(msgid) : pattern == msgid }
      end

      # The .pot is generated from the port's own lib/*.rb sources (`rake
      # gettext:pot:create`), so every code msgid it carries is one the
      # port actually marks.
      expect(code_msgids - marked).to eq([])
    end

    it "keeps %s rather than interpolating, so the key survives" do
      expect(self.class.marked_msgids).to include("Cannot write to “%s”")
      expect(File.read(File.join(ROOT, "lib", "window.rb"))).to include('format(_(\'Cannot write to “%s”\'), path)')
    end

    it "keeps the mnemonics inside the msgid" do
      expect(self.class.marked_msgids).to include("_Cancel", "_Exit")
    end

    it "uses U+2026 and not three dots" do
      ellipses = self.class.marked_msgids.grep(/…|\.\.\./)

      expect(ellipses).to include(
        "Starting…",
        "Finishing up…",
        "Estimating…",
        "Starting Shredding…",
        "Aborting…",
      )
      expect(ellipses.grep(/\.\.\./)).to be_empty
    end
  end

  describe "a compiled catalogue" do
    # `rake gettext:mo` writes these; without them the port is English, which
    # is a build step that has not been run and not a translation that is
    # missing.
    let(:german) do
      File.join(
        PackageConfig::BUNDLED_LOCALEDIR,
        "de",
        "LC_MESSAGES",
        "#{PackageConfig::GETTEXT_PACKAGE}.mo",
      )
    end

    it "is found under the bound path, named after upstream's domain" do
      unless File.exist?(german)
        skip("run `rake gettext:mo` first: #{german} does not exist")
      end

      expect(PackageConfig.localedir).to eq(PackageConfig::BUNDLED_LOCALEDIR)
    end

    it "translates a known string" do
      unless File.exist?(german)
        skip("run `rake gettext:mo` first: #{german} does not exist")
      end

      catalogue = GetText::MO.open(german, "UTF-8")

      expect(catalogue["File Shredder"]).to eq("Aktenvernichter")
      expect(catalogue["Starting Shredding…"]).to eq("Vernichten wird gestartet…")
    end
  end

  # The two examples above assert the contents of a .mo file. Neither calls
  # `_()`, so neither would notice a wrong domain, a wrong localedir, or a
  # binding that does nothing at all. This one goes through the real marker,
  # under a real non-English locale, the way `_('File Shredder')` does at
  # every call site in lib/.
  describe "a marked string under a non-English locale" do
    include Translation

    around do |example|
      require "locale"
      previous = Locale.current
      example.run
    ensure
      Locale.current = previous
    end

    it "comes back translated and UTF-8, not read off a file" do
      unless File.exist?(
        File.join(PackageConfig::BUNDLED_LOCALEDIR, "de", "LC_MESSAGES", "#{PackageConfig::GETTEXT_PACKAGE}.mo"),
      )
        skip("run `rake gettext:mo` first")
      end

      Locale.current = "de"

      expect(_("File Shredder")).to eq("Aktenvernichter")
      expect(_("File Shredder").encoding).to eq(Encoding::UTF_8)
    end
  end
end
