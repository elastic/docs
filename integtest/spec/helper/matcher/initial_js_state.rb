# frozen_string_literal: true

##
# Matches extracts the "initial javascript state" of a templated html page.
RSpec::Matchers.define :initial_js_state do |expected|
  match do |actual|
    expected.matches? extract(actual)
  end
  failure_message do
    "doc_body didn't match: #{expected.failure_message}"
  end

  def extract(contents)
    start_boundry = 'window.initial_state = '
    start = contents.index start_boundry
    return unless start

    start += start_boundry.length
    stop = contents.index '</script>', start
    return unless stop

    txt = contents[start, stop - start]
    JSON.parse txt, symbolize_names: true
  end
end
