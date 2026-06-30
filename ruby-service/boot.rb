# frozen_string_literal: true

# Application bootstrap: configure Zeitwerk to autoload everything under lib/
# by naming convention (lib/validator.rb -> Validator, lib/routing.rb -> Routing,
# ...). Require this once from an entry point and then reference the constants
# directly — no manual require_relative needed.

require 'zeitwerk'

loader = Zeitwerk::Loader.new
loader.push_dir(File.expand_path('lib', __dir__))
loader.setup
