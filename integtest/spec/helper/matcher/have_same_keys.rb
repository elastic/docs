# frozen_string_literal: true

##
# Match the keys in two hashes, printing the extra or missing keys when there
# is a failure.
RSpec::Matchers.define :have_same_keys do |expected|
  match do |actual|
    expected_keys = expected.keys.sort
    actual_keys = actual.keys.sort
    expected_keys == actual_keys
  end
  failure_message do |actual|
    expected_keys = expected.keys.sort
    actual_keys = actual.keys.sort

    missing = expected_keys - actual_keys
    extra = actual_keys - expected_keys

    msg = 'expected keys to match exactly but'
    if missing
      msg += " missed:\n"
      missing.each { |k| msg += "#{k} => #{expected[k]}" }
      msg += "\nand" if extra
    end
    msg += " had extra:\n"
    extra.each { |k| msg += "#{k} => #{actual[k]}" }

    msg
  end
end
