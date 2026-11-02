# frozen_string_literal: true

# PackageConfig is the handful of build-time constants the rest of the port
# reads.
#
# Ported from the `config_h` block in upstream's meson.build, which generates
# raider-config.h with exactly these three values: PACKAGE_VERSION (the meson
# project version, `project('raider', 'c', version: '3.1.0')`),
# GETTEXT_PACKAGE and LOCALEDIR. Everything that wants the version — the About
# dialog and `--version` — reads PACKAGE_VERSION from here, so there is one
# place to change when upstream's project version moves.
#
# LOCALEDIR is upstream's `prefix/localedir`. There is no configure step here,
# so the directory is looked for in the three places a .mo can actually be:
# an explicit override, the catalogues `rake gettext:mo` compiles into the
# source tree (which is also what `rake gettext:install` lays down under a
# prefix), and the system locale directory.
module PackageConfig
  PACKAGE_VERSION = '3.1.0'
  PACKAGE_NAME = 'raider'

  # Upstream's application id, from src/main.c. It is also the name of the
  # icon in data/icons/hicolor/*/apps, which is why the window, the empty
  # state and the About dialog all ask for it by this name.
  APPLICATION_ID = 'com.github.ADBeveridge.Raider'

  # Upstream's GETTEXT_PACKAGE. It is the upstream domain name, not the gem
  # name, because the 35 catalogues in po/ are compiled under this name.
  GETTEXT_PACKAGE = 'raider'

  LOCALEDIR_ENVIRONMENT_VARIABLE = 'RAIDER_LOCALEDIR'

  # The tree's own catalogues, written by `rake gettext:mo`.
  BUNDLED_LOCALEDIR = File.expand_path('../data/locale', __dir__)

  SYSTEM_LOCALEDIR = '/usr/share/locale'

  # The first of the candidates that exists, and the bundled one when none of
  # them does, so bindtextdomain is always given a path.
  def self.localedir
    localedir_candidates.find { |candidate| File.directory?(candidate) } || BUNDLED_LOCALEDIR
  end

  def self.localedir_candidates
    [
      ENV.fetch(LOCALEDIR_ENVIRONMENT_VARIABLE, nil),
      BUNDLED_LOCALEDIR,
      SYSTEM_LOCALEDIR,
    ].compact
  end
end
