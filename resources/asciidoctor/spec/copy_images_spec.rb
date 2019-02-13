require 'change_admonishment/extension'
require 'copy_images/extension'
require 'fileutils'
require 'tmpdir'

RSpec.describe CopyImages do
  RSpec::Matchers.define_negated_matcher :not_match, :match

  before(:each) do
    Extensions.register ChangeAdmonishment
    Extensions.register do
      tree_processor CopyImages
    end
  end

  after(:each) do
    Extensions.unregister_all
  end

  def copy_attributes(copied)
    return {
      'copy_image' => proc { |uri, source|
        copied << [uri, source]
      }
    }
  end

  spec_dir = File.dirname(__FILE__)

  it "copies a file when directly referenced" do
    copied = []
    attributes = copy_attributes copied
    input = <<~ASCIIDOC
      == Example
      image::resources/copy_images/example1.png[]
    ASCIIDOC
    convert input, attributes,
        eq("INFO: <stdin>: line 2: copying #{spec_dir}\/resources\/copy_images\/example1.png")
    expect(copied).to eq([
        ["resources/copy_images/example1.png", "#{spec_dir}/resources/copy_images/example1.png"]
    ])
  end

  it "copies a file when it can be found in a sub tree" do
    copied = []
    attributes = copy_attributes copied
    input = <<~ASCIIDOC
      == Example
      image::example1.png[]
    ASCIIDOC
    convert input, attributes,
        eq("INFO: <stdin>: line 2: copying #{spec_dir}/resources/copy_images/example1.png")
    expect(copied).to eq([
        ["example1.png", "#{spec_dir}/resources/copy_images/example1.png"]
    ])
  end

  it "copies a path when it can be found in a sub tree" do
    copied = []
    attributes = copy_attributes copied
    input = <<~ASCIIDOC
      == Example
      image::copy_images/example1.png[]
    ASCIIDOC
    convert input, attributes,
        eq("INFO: <stdin>: line 2: copying #{spec_dir}/resources/copy_images/example1.png")
    expect(copied).to eq([
        ["copy_images/example1.png", "#{spec_dir}/resources/copy_images/example1.png"]
    ])
  end

  it "warns when it can't find a file" do
    copied = []
    attributes = copy_attributes copied
    input = <<~ASCIIDOC
      == Example
      image::not_found.jpg[]
    ASCIIDOC
    convert input, attributes, match(/
        WARN:\ <stdin>:\ line\ 2:\ can't\ read\ image\ at\ any\ of\ \[
          "#{spec_dir}\/not_found.jpg",\s
          "#{spec_dir}\/resources\/not_found.jpg",\s
          .+
          "#{spec_dir}\/resources\/copy_images\/not_found.jpg"
          .+
        \]/x).and(not_match(/INFO: <stdin>/))
    expect(copied).to eq([])
  end

  it "only attempts to copy each file once" do
    copied = []
    attributes = copy_attributes copied
    input = <<~ASCIIDOC
      == Example
      image::resources/copy_images/example1.png[]
      image::resources/copy_images/example1.png[]
      image::resources/copy_images/example2.png[]
      image::resources/copy_images/example1.png[]
      image::resources/copy_images/example2.png[]
    ASCIIDOC
    expected_warnings = <<~LOG
      INFO: <stdin>: line 2: copying #{spec_dir}/resources/copy_images/example1.png
      INFO: <stdin>: line 4: copying #{spec_dir}/resources/copy_images/example2.png
    LOG
    convert input, attributes, eq(expected_warnings.strip)
    expect(copied).to eq([
        ["resources/copy_images/example1.png", "#{spec_dir}/resources/copy_images/example1.png"],
        ["resources/copy_images/example2.png", "#{spec_dir}/resources/copy_images/example2.png"],
    ])
  end

  it "skips external images" do
    copied = []
    attributes = copy_attributes copied
    input = <<~ASCIIDOC
      == Example
      image::https://f.cloud.github.com/assets/4320215/768165/19d8b1aa-e899-11e2-91bc-6b0553e8d722.png[]
    ASCIIDOC
    convert input, attributes
    expect(copied).to eq([])
  end

  it "can find files using a single valued resources attribute" do
    Dir.mktmpdir { |tmp|
      FileUtils.cp(
        ::File.join(spec_dir, 'resources', 'copy_images', 'example1.png'),
        ::File.join(tmp, 'tmp_example1.png')
      )

      copied = []
      attributes = copy_attributes copied
      attributes['resources'] = tmp
      input = <<~ASCIIDOC
        == Example
        image::tmp_example1.png[]
      ASCIIDOC
      convert input, attributes,
          eq("INFO: <stdin>: line 2: copying #{tmp}/tmp_example1.png")
      expect(copied).to eq([
          ["tmp_example1.png", "#{tmp}/tmp_example1.png"]
      ])
    }
  end

  it "can find files using a multi valued resources attribute" do
    Dir.mktmpdir { |tmp|
      FileUtils.cp(
        ::File.join(spec_dir, 'resources', 'copy_images', 'example1.png'),
        ::File.join(tmp, 'tmp_example1.png')
      )

      copied = []
      attributes = copy_attributes copied
      attributes['resources'] = "dummy1,#{tmp},/dummy2"
      input = <<~ASCIIDOC
        == Example
        image::tmp_example1.png[]
      ASCIIDOC
      convert input, attributes,
          eq("INFO: <stdin>: line 2: copying #{tmp}/tmp_example1.png")
      expect(copied).to eq([
          ["tmp_example1.png", "#{tmp}/tmp_example1.png"]
      ])
    }
  end

  it "doesn't mind an empty resources attribute" do
    copied = []
    attributes = copy_attributes copied
    attributes['resources'] = ''
    input = <<~ASCIIDOC
      == Example
      image::example1.png[]
    ASCIIDOC
    convert input, attributes,
        eq("INFO: <stdin>: line 2: copying #{spec_dir}/resources/copy_images/example1.png")
    expect(copied).to eq([
        ["example1.png", "#{spec_dir}/resources/copy_images/example1.png"]
    ])
  end

  it "has a nice error message if resources is invalid CSV" do
    copied = []
    attributes = copy_attributes copied
    attributes['resources'] = '"'
    input = <<~ASCIIDOC
      == Example
      image::example1.png[]
    ASCIIDOC
    expected_warnings = <<~LOG
      ERROR: <stdin>: line 2: Error loading [resources]: Unclosed quoted field on line 1.
      INFO: <stdin>: line 2: copying #{spec_dir}/resources/copy_images/example1.png
    LOG
    convert input, attributes, eq(expected_warnings.strip)
    expect(copied).to eq([
        ["example1.png", "#{spec_dir}/resources/copy_images/example1.png"]
    ])
  end

  it "has a nice error message when it can't find a file with single valued resources attribute" do
    Dir.mktmpdir { |tmp|
      copied = []
      attributes = copy_attributes copied
      attributes['resources'] = tmp
      input = <<~ASCIIDOC
        == Example
        image::not_found.png[]
      ASCIIDOC
      convert input, attributes, match(/
          WARN:\ <stdin>:\ line\ 2:\ can't\ read\ image\ at\ any\ of\ \[
            "#{spec_dir}\/not_found.png",\s
            "#{tmp}\/not_found.png"
            .+
          \]/x).and(not_match(/INFO: <stdin>/))
      expect(copied).to eq([])
    }
  end

  it "has a nice error message when it can't find a file with multi valued resources attribute" do
    Dir.mktmpdir { |tmp|
      copied = []
      attributes = copy_attributes copied
      attributes['resources'] = "#{tmp},/dummy2"
      input = <<~ASCIIDOC
        == Example
        image::not_found.png[]
      ASCIIDOC
      convert input, attributes, match(/
          WARN:\ <stdin>:\ line\ 2:\ can't\ read\ image\ at\ any\ of\ \[
            "#{spec_dir}\/not_found.png",\s
            "#{tmp}\/not_found.png",\s
            "\/dummy2\/not_found.png"
            .+
          \]/x).and(not_match(/INFO: <stdin>/))
      expect(copied).to eq([])
    }
  end

  it "copies images for callouts when requested (png)" do
    copied = []
    attributes = copy_attributes copied
    attributes['copy-callout-images'] = 'png'
    input = <<~ASCIIDOC
      == Example
      ----
      foo <1> <2>
      ----
      <1> words
      <2> words
    ASCIIDOC
    expected_warnings = <<~WARNINGS
      INFO: <stdin>: line 5: copying #{spec_dir}/resources/copy_images/images/icons/callouts/1.png
      INFO: <stdin>: line 6: copying #{spec_dir}/resources/copy_images/images/icons/callouts/2.png
    WARNINGS
    convert input, attributes, eq(expected_warnings.strip)
    expect(copied).to eq([
        ["images/icons/callouts/1.png", "#{spec_dir}/resources/copy_images/images/icons/callouts/1.png"],
        ["images/icons/callouts/2.png", "#{spec_dir}/resources/copy_images/images/icons/callouts/2.png"],
    ])
  end

  it "copies images for callouts when requested (gif)" do
    copied = []
    attributes = copy_attributes copied
    attributes['copy-callout-images'] = 'gif'
    input = <<~ASCIIDOC
      == Example
      ----
      foo <1>
      ----
      <1> words
    ASCIIDOC
    expected_warnings = <<~WARNINGS
      INFO: <stdin>: line 5: copying #{spec_dir}/resources/copy_images/images/icons/callouts/1.gif
    WARNINGS
    convert input, attributes, eq(expected_warnings.strip)
    expect(copied).to eq([
        ["images/icons/callouts/1.gif", "#{spec_dir}/resources/copy_images/images/icons/callouts/1.gif"],
    ])
  end

  it "has a nice error message when a callout image is missing" do
    copied = []
    attributes = copy_attributes copied
    attributes['copy-callout-images'] = 'gif'
    input = <<~ASCIIDOC
      == Example
      ----
      foo <1> <2>
      ----
      <1> words
      <2> words
    ASCIIDOC
    convert input, attributes, match(/
    WARN:\ <stdin>:\ line\ 6:\ can't\ read\ image\ at\ any\ of\ \[
      "#{spec_dir}\/images\/icons\/callouts\/2.gif",\s
      "#{spec_dir}\/resources\/images\/icons\/callouts\/2.gif",\s
      .+
      "#{spec_dir}\/resources\/copy_images\/images\/icons\/callouts\/2.gif"
      .+
    \]/x).and(match(/INFO: <stdin>: line 5: copying #{spec_dir}\/resources\/copy_images\/images\/icons\/callouts\/1.gif/))
    expect(copied).to eq([
        ["images/icons/callouts/1.gif", "#{spec_dir}/resources/copy_images/images/icons/callouts/1.gif"],
    ])
  end

  it "only copies callout images one time" do
    copied = []
    attributes = copy_attributes copied
    attributes['copy-callout-images'] = 'png'
    input = <<~ASCIIDOC
      == Example
      ----
      foo <1>
      ----
      <1> words

      ----
      foo <1>
      ----
      <1> words
    ASCIIDOC
    expected_warnings = <<~WARNINGS
      INFO: <stdin>: line 5: copying #{spec_dir}/resources/copy_images/images/icons/callouts/1.png
    WARNINGS
    convert input, attributes, eq(expected_warnings.strip)
    expect(copied).to eq([
        ["images/icons/callouts/1.png", "#{spec_dir}/resources/copy_images/images/icons/callouts/1.png"],
    ])
  end

  it "supports callout lists with multiple callouts per item" do
    # This is a *super* weird case but we have it in Elasticsearch.
    # The only way I can make callout lists be for two things is by making
    # blocks with callouts but only having a single callout list below both.
    copied = []
    attributes = copy_attributes copied
    attributes['copy-callout-images'] = 'png'
    input = <<~ASCIIDOC
      == Example
      ----
      foo <1>
      ----

      ----
      foo <1>
      ----
      <1> words
    ASCIIDOC
    expected_warnings = <<~WARNINGS
      INFO: <stdin>: line 9: copying #{spec_dir}/resources/copy_images/images/icons/callouts/1.png
      INFO: <stdin>: line 9: copying #{spec_dir}/resources/copy_images/images/icons/callouts/2.png
    WARNINGS
    convert input, attributes, eq(expected_warnings.strip)
    expect(copied).to eq([
        ["images/icons/callouts/1.png", "#{spec_dir}/resources/copy_images/images/icons/callouts/1.png"],
        ["images/icons/callouts/2.png", "#{spec_dir}/resources/copy_images/images/icons/callouts/2.png"],
    ])
  end

  it "doesn't copy callout images if the extension isn't set" do
    copied = []
    attributes = copy_attributes copied
    input = <<~ASCIIDOC
      == Example
      ----
      foo <1>
      ----
      <1> words

      ----
      foo <1>
      ----
      <1> words
    ASCIIDOC
    convert input, attributes
    expect(copied).to eq([])
  end

  ['note', 'tip', 'important', 'caution', 'warning'].each { |(name)|
    it "copies images for the #{name} admonition when requested" do
      copied = []
      attributes = copy_attributes copied
      attributes['copy-admonition-images'] = 'png'
      input = <<~ASCIIDOC
        #{name.upcase}: Words words words.
      ASCIIDOC
      expected_warnings = <<~WARNINGS
        INFO: <stdin>: line 1: copying #{spec_dir}/resources/copy_images/images/icons/#{name}.png
      WARNINGS
      convert input, attributes, eq(expected_warnings.strip)
      expect(copied).to eq([
          ["images/icons/#{name}.png", "#{spec_dir}/resources/copy_images/images/icons/#{name}.png"],
      ])
    end
  }

  [
      ['added', 'note'],
      ['coming', 'note'],
      ['deprecated', 'warning']
  ].each { |(name, admonition)|
    it "copies images for the block formatted #{name} change admonition when requested" do
      copied = []
      attributes = copy_attributes copied
      attributes['copy-admonition-images'] = 'png'
      input = <<~ASCIIDOC
        #{name}::[some_version]
      ASCIIDOC
      # We can't get the location of the blocks because asciidoctor doesn't
      # make it available to us here!
      expected_warnings = <<~WARNINGS
        INFO: copying #{spec_dir}/resources/copy_images/images/icons/#{admonition}.png
      WARNINGS
      convert input, attributes, eq(expected_warnings.strip)
      expect(copied).to eq([
          ["images/icons/#{admonition}.png", "#{spec_dir}/resources/copy_images/images/icons/#{admonition}.png"],
      ])
    end
  }

  it "copies images for admonitions when requested with a different file extension" do
    copied = []
    attributes = copy_attributes copied
    attributes['copy-admonition-images'] = 'gif'
    input = <<~ASCIIDOC
      NOTE: Words words words.
    ASCIIDOC
    expected_warnings = <<~WARNINGS
      INFO: <stdin>: line 1: copying #{spec_dir}/resources/copy_images/images/icons/note.gif
    WARNINGS
    convert input, attributes, eq(expected_warnings.strip)
    expect(copied).to eq([
        ["images/icons/note.gif", "#{spec_dir}/resources/copy_images/images/icons/note.gif"],
    ])
  end

  it "doesn't copy images for admonitions if not requested" do
    copied = []
    attributes = copy_attributes copied
    input = <<~ASCIIDOC
      NOTE: Words words words.
    ASCIIDOC
    convert input, attributes
    expect(copied).to eq([])
  end
end
