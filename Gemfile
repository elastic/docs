# IMPORTANT: If you change this file you should run `bundle lock` to
# regenerate Gemfile.lock or building the docker image will fail.
source "https://rubygems.org"

ruby "~> 2.3"

# We commit Gemfile.lock so we're not going to have "unexpected" version bumps
# of our gems. This file specifies what we think *should* work. Gemfile.lock
# specifies what we *know* does work.
gem "asciidoctor", "~> 1.5"          # Used by the docs build
gem "thread_safe", "~> 0.3.6"        # Used by asciidoctor
gem "asciidoctor-diagram", "~> 1.5"  # Speculative
gem "asciimath", "~> 1.0"            # Speculative

group :test do
  gem "rspec", "~> 3.8"
  gem "rubocop", "~> 0.64.0"
end
