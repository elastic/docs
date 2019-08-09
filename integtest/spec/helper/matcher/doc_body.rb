# frozen_string_literal: true

##
# Matches extracts the "body" of a docs page, removing its template.
RSpec::Matchers.define :doc_body do |expected|
  match do |actual|
    body = actual.sub(/.+<!-- start body -->/m, '')
                 .sub(/<!-- end body -->.+/m, '')

    expected.matches? body
  end
  failure_message do
    "doc_body didn't match: #{expected.failure_message}"
  end
end
