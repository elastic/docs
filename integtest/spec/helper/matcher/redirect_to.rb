# frozen_string_literal: true

##
# Matches http responses.
RSpec::Matchers.define :redirect_to do |expected, ecode = '301'|
  match do |actual|
    return false unless actual.code == ecode

    expected.matches? actual['Location']
  end
  failure_message do |actual|
    unless actual.code == ecode
      return "expected status [#{ecode}] but was [#{actual.code}]. Body:\n" +
             actual.body
    end

    message = expected.failure_message
    "status was [#{ecode}] but the location didn't match: #{message}"
  end
end
