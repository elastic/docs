# frozen_string_literal: true

##
# Matches http responses.
RSpec::Matchers.define :redirect_to do |expected|
  match do |actual|
    return false unless actual.code == '301'

    expected.matches? actual['Location']
  end
  failure_message do |actual|
    unless actual.code == '301'
      return "expected status [301] but was [#{actual.code}]. Body:\n" +
             actual.body
    end

    message = expected.failure_message
    "status was [301] but the location didn't match: #{message}"
  end
end
