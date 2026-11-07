# frozen_string_literal: true

require "open3"
require "tmpdir"

require "data_files"

# Upstream's two meson tests, ported.
#
#   data/meson.build:12  test('Validate desktop file', desktop-file-validate, …)
#   data/meson.build:27  test('Validate appstream file', appstreamcli,
#                             args: ['validate', '--no-net', …])
#
# Both are defined on a `find_program(…, required: false)`, so upstream skips
# them when the validator is not installed and so does this. The file each one
# validates is the merged output, not the template, which is why it is built
# here first.
RSpec.describe DataFiles do
  subject(:data_files) { described_class.new }

  def self.program(name)
    described_class.which(name)
  end

  around do |example|
    Dir.mktmpdir do |directory|
      @built = directory
      example.run
    end
  end

  def built = @built

  def merged
    unless described_class.msgfmt?
      skip("msgfmt is not installed; GNU gettext is a build dependency")
    end

    @merged ||= data_files.write_all(built, bindir: "/usr/bin")
  end

  def desktop_file = merged[0]
  def metainfo_file = merged[1]
  def service_file = merged[2]

  describe "Validate desktop file" do
    it "passes desktop-file-validate" do
      validator = self.class.program("desktop-file-validate")
      unless validator
        skip("desktop-file-validate is not installed")
      end

      output, status = Open3.capture2e(validator, desktop_file)

      expect(status).to be_success, -> { output }
    end
  end

  describe "Validate appstream file" do
    it "passes appstreamcli validate --no-net" do
      validator = self.class.program("appstreamcli")
      unless validator
        skip("appstreamcli is not installed")
      end

      output, status = Open3.capture2e(
        validator,
        "validate",
        "--no-net",
        metainfo_file,
      )

      expect(status).to be_success, -> { output }
    end
  end

  describe "the merged desktop entry" do
    it "keeps upstream's untranslated keys" do
      contents = File.read(desktop_file)

      expect(contents).to include("Name=File Shredder")
      expect(contents).to include("Comment=Permanently delete your files")
      expect(contents).to include("Exec=raider")
      expect(contents).to include("Icon=#{described_class::APPLICATION_ID}")
      expect(contents).to include("DBusActivatable=true")
      expect(contents).to include("X-GNOME-UsesNotifications=true")
    end

    it "merges a Name and a Comment per language that has one" do
      contents = File.read(desktop_file)

      expect(contents).to include("Name[de]=Aktenvernichter")
      expect(contents).to include("Name[fr]=Broyeur de fichiers")
      expect(contents.scan(/^Name\[/).length).to be >= 30
      expect(contents.scan(/^Comment\[/).length).to be >= 30
    end
  end

  describe "the merged metainfo" do
    it "keeps upstream's id, licences and gettext domain" do
      contents = File.read(metainfo_file)

      expect(contents).to include("<id>#{described_class::APPLICATION_ID}</id>")
      expect(contents).to include("<project_license>GPL-3.0-or-later</project_license>")
      expect(contents).to include("<translation type=\"gettext\">raider</translation>")
      expect(contents).to include("<release version=\"#{PackageConfig::PACKAGE_VERSION}\"")
    end

    it "merges a translated name and summary" do
      contents = File.read(metainfo_file)

      expect(contents).to include("<name xml:lang=\"de\">Aktenvernichter</name>")
      expect(contents).to match(/<summary xml:lang="fr">/)
    end

    it "leaves the release notes alone, because they are translate=\"no\"" do
      contents = File.read(metainfo_file)

      expect(contents).to include("<p>GNOME 48 Update</p>")
      expect(contents).not_to match(/<p xml:lang="[a-z_]+">GNOME 48 Update/)
    end

    # Regression test for gap C8 (component-parity.md): the developer id's
    # casing was once retyped from upstream's "io.github.ADBeveridge" — a
    # byte-identical-looking but wrong string that a bare File.exist? or
    # "the file parses" check would never catch.
    it "keeps upstream's developer id, by name, not just a well-formed one (C8)" do
      contents = File.read(metainfo_file)

      expect(contents).to include('<developer id="io.github.ADBeveridge">')
    end

    # Regression test for gap C9 (component-parity.md): the metainfo's
    # <image> element and the screenshot file it names are asserted together
    # so they cannot drift apart again — a metainfo pointing at a screenshot
    # that does not exist is the exact shape of the bug this closes.
    it "names a screenshot that actually exists on disk (C9)" do
      contents = File.read(metainfo_file)

      screenshot = contents[%r{<image[^>]*>([^<]*raider-screenshot1\.png)</image>}, 1]

      expect(screenshot).not_to be_nil
      expect(File).to exist(
        File.join(described_class::TEMPLATE_DIRECTORY, File.basename(screenshot)),
      )
    end
  end

  describe "the D-Bus service file" do
    it "fills in bindir and asks for the service mode" do
      contents = File.read(service_file)

      expect(contents).to include("Name=#{described_class::APPLICATION_ID}")
      expect(contents).to include("Exec=/usr/bin/raider --gapplication-service")
      expect(contents).not_to include("@bindir@")
    end
  end

  describe "the icons" do
    it "ships the application icon the window and the About dialog ask for" do
      scalable = File.join(
        described_class::TEMPLATE_DIRECTORY,
        "icons",
        "hicolor",
        "scalable",
        "apps",
      )
      symbolic = File.join(
        described_class::TEMPLATE_DIRECTORY,
        "icons",
        "hicolor",
        "symbolic",
        "apps",
      )

      expect(File).to exist(File.join(scalable, "#{described_class::APPLICATION_ID}.svg"))
      expect(File).to exist(File.join(scalable, "#{described_class::APPLICATION_ID}.Devel.svg"))
      expect(File).to exist(File.join(symbolic, "#{described_class::APPLICATION_ID}-symbolic.svg"))
    end
  end
end
