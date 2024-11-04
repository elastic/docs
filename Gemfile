# frozen_string_literal: true

# IMPORTANT: If you change this file you should run `bundle lock` to
# regenerate Gemfile.lock or building the docker image will fail.
source 'https://rubygems.org'

ruby '~> 3.1'

# We commit Gemfile.lock so we're not going to have "unexpected" version bumps
# of our gems. This file specifies what we think *should* work. Gemfile.lock
# specifies what we *know* does work.
gem 'asciidoctor', '~> 2.0'          # Used by the docs build
gem 'asciidoctor-diagram', '~> 1.5'  # Speculative
gem 'asciimath', '~> 1.0'            # Speculative
gem 'digest-murmurhash', '~> 1.1.1'  # Used by a custom asciidoctor plugin
gem 'jaro_winkler', '~> 1.6' # Speculative
gem 'thread_safe', '~> 0.3.6'        # Used by asciidoctor

group :test do
  gem 'rspec', '~> 3.13.0'
  gem 'rubocop', '~> 1.50.0'
end
