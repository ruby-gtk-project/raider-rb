# frozen_string_literal: true

require_relative "rb/version"

# Raider::Rb is the gem's own namespace: the packaging version and nothing
# else. The application is not in this namespace — it is the classes under
# lib/, reached through lib/raider.rb, which is what exe/raider requires.
#
# Raider::Rb::VERSION is this gem's release number and is unrelated to
# PackageConfig::PACKAGE_VERSION, which is upstream's PACKAGE_VERSION and is
# what the About dialog and `--version` report.
module Raider
  module Rb
  end
end
