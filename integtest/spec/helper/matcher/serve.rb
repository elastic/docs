# frozen_string_literal: true

##
# Matches http responses.
RSpec::Matchers.define :serve do |expected|
  match do |actual|
    return false unless actual.code == '200'

    expected.matches? actual.body
  end
  failure_message do |actual|
    unless actual.code == '200'
      return "expected status [200] but was [#{actual.code}]"
    end

    "status was [200] but the body didn't match: #{expected.failure_message}"
  end
end
