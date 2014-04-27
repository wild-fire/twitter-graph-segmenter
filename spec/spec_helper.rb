require 'vcr'

# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper"` to ensure that it is only
# loaded once.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  VCR.configure do |c|
    c.cassette_library_dir = 'spec/vcr'
    c.configure_rspec_metadata!
    c.hook_into :webmock # or :fakeweb
    # Don't playback transient errors

    yml_config = YAML.load_file( File.expand_path('../config/twitter.yml', File.dirname(__FILE__)) )['twitter']
    c.filter_sensitive_data('<CONSUMER KEY>') { yml_config['consumer_key'] }
    c.filter_sensitive_data('<ACCESS TOKEN>') { yml_config['access_token'] }
    c.before_playback do |interaction|
      interaction.ignore! if interaction.response.status.code >= 400
    end
  end

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
end
