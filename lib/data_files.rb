# frozen_string_literal: true

require 'open3'
require 'shellwords'

require_relative 'package_config'

# DataFiles builds the three installable files in data/ out of their templates
# and the catalogues in po/.
#
# Ported from upstream's data/meson.build, which runs two `i18n.merge_file`
# calls and one `configure_file`:
#
#   * com.github.ADBeveridge.Raider.desktop.in.in with `type: 'desktop'`, which
#     is `msgfmt --desktop`: every translatable key in the template gains a
#     `Key[language]=translation` line per catalogue that has one.
#   * com.github.ADBeveridge.Raider.metainfo.xml.in.in with no type, which is
#     `msgfmt --xml`: every translatable element gains an `xml:lang` sibling,
#     with `translate="no"` honoured.
#   * com.github.ADBeveridge.Raider.service.in through `configure_file` with
#     `bindir`, the only substitution that template asks for.
#
# The merges are the same msgfmt invocations meson makes rather than a
# reimplementation of them, so the languages come from po/LINGUAS and the ITS
# rules that decide which AppStream elements are translatable are AppStream's
# own. msgfmt is a build-time tool: it belongs in the flake's
# nativeBuildInputs, never in the runtime closure, and nothing under lib/ calls
# this class at runtime.
class DataFiles
  MSGFMT = 'msgfmt'

  TEMPLATE_DIRECTORY = File.expand_path('../data', __dir__)
  PO_DIRECTORY = File.expand_path('../po', __dir__)

  APPLICATION_ID = PackageConfig::APPLICATION_ID

  DESKTOP_TEMPLATE = "#{APPLICATION_ID}.desktop.in.in"
  DESKTOP_OUTPUT = "#{APPLICATION_ID}.desktop"

  METAINFO_TEMPLATE = "#{APPLICATION_ID}.metainfo.xml.in.in"
  METAINFO_OUTPUT = "#{APPLICATION_ID}.metainfo.xml"

  SERVICE_TEMPLATE = "#{APPLICATION_ID}.service.in"
  SERVICE_OUTPUT = "#{APPLICATION_ID}.service"

  DEFAULT_BINDIR = '/usr/bin'

  # Raised when msgfmt is not installed. Upstream's i18n.merge_file is not
  # optional either: without it there is no desktop entry to install, so this
  # is a missing build dependency and not a condition to work around.
  class MsgfmtMissing < StandardError
    MESSAGE = 'msgfmt is not on PATH; install GNU gettext to build the data files'

    def initialize(message = MESSAGE)
      super
    end
  end

  def self.msgfmt? = !which(MSGFMT).nil?

  def self.which(program)
    ENV.fetch('PATH', '').split(File::PATH_SEPARATOR)
       .map { |directory| File.join(directory, program) }
       .find { |candidate| File.executable?(candidate) && !File.directory?(candidate) }
  end

  def initialize(template_directory: TEMPLATE_DIRECTORY, po_directory: PO_DIRECTORY)
    @template_directory = template_directory
    @po_directory = po_directory
  end

  def languages
    File.readlines(File.join(@po_directory, 'LINGUAS'), chomp: true)
        .map(&:strip)
        .reject { |line| line.empty? || line.start_with?('#') }
  end

  # The merged desktop entry, written to `path`.
  def desktop_entry(path)
    merge('--desktop', DESKTOP_TEMPLATE, path)
  end

  # The merged metainfo, written to `path`.
  def metainfo(path)
    merge('--xml', METAINFO_TEMPLATE, path)
  end

  # Upstream's service_conf: @bindir@ and nothing else.
  def service(path, bindir: DEFAULT_BINDIR)
    File.write(path, read(SERVICE_TEMPLATE).gsub('@bindir@', bindir)).then { path }
  end

  # All three into `directory`, answering the paths written, which is what the
  # desktop and appstream validators are pointed at.
  def write_all(directory, bindir: DEFAULT_BINDIR)
    [
      desktop_entry(File.join(directory, DESKTOP_OUTPUT)),
      metainfo(File.join(directory, METAINFO_OUTPUT)),
      service(File.join(directory, SERVICE_OUTPUT), bindir: bindir),
    ]
  end

  private

    def read(name) = File.read(File.join(@template_directory, name))

    def merge(mode, template, path)
      unless self.class.msgfmt?
        raise MsgfmtMissing
      end

      run(
        MSGFMT,
        mode,
        "--template=#{File.join(@template_directory, template)}",
        '-d',
        @po_directory,
        '-o',
        path,
      ).then { path }
    end

    def run(*command)
      Open3.capture2e(*command).then do |output, status|
        unless status.success?
          raise "#{command.shelljoin} failed: #{output}"
        end
      end
    end
end
