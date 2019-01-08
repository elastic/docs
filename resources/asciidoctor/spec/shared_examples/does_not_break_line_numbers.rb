RSpec.shared_examples "doesn't break line numbers" do 
  it "doesn't break line numbers" do
    input = <<~ASCIIDOC
      ---
      ---
      <1> callout
    ASCIIDOC
    expect { convert(input) }.to raise_error(
        ConvertError, /<stdin>: line 3: no callout found for <1>/)
  end

  it "doesn't break line numbers in included files" do
    input = <<~ASCIIDOC
      include::resources/does_not_break_line_numbers/missing_callout.adoc[]
    ASCIIDOC
    expect { convert(input) }.to raise_error(
        ConvertError, /missing_callout.adoc: line 3: no callout found for <1>/)
  end
end
