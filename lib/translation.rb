# frozen_string_literal: true

require 'gettext'

require_relative 'package_config'

# Translation is the port's gettext binding: include it and the gettext marker
# looks a string up in the `raider` domain.
#
# Ported from the gettext setup in upstream's src/main.c —
# `bindtextdomain(GETTEXT_PACKAGE, LOCALEDIR)`,
# `bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8")`,
# `textdomain(GETTEXT_PACKAGE)` — together with po/meson.build's
# `i18n.gettext('raider', preset: 'glib')`, which is what compiles and installs
# the catalogues the binding reads.
#
# The domain is bound once here, on a module, and the classes that carry
# msgids include it; the gettext gem resolves a domain by walking the
# including class's ancestors, so one binding serves the whole port. The
# codeset is not set: the gettext gem decodes catalogues as UTF-8 and hands
# back String objects already in Encoding::UTF_8, which is what
# bind_textdomain_codeset asks the C library for.
#
# Marked strings are returned by methods rather than held in constants. A
# constant is frozen at load time, before the locale is known to anything that
# might change it, and `_` is an instance method of the including class, so a
# class body could not call it anyway.
module Translation
  include GetText

  bindtextdomain(PackageConfig::GETTEXT_PACKAGE, path: PackageConfig.localedir)
end
