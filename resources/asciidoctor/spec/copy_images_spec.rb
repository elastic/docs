# frozen_string_literal: true

require 'care_admonition/extension'
require 'change_admonition/extension'
require 'copy_images/extension'
require 'fileutils'
require 'tmpdir'

RSpec.describe CopyImages do
  RSpec::Matchers.define_negated_matcher :not_match, :match

  before(:each) do
    Asciidoctor::Extensions.register CareAdmonition
    Asciidoctor::Extensions.register ChangeAdmonition
    Asciidoctor::Extensions.register do
      tree_processor CopyImages::CopyImages
    end
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  def copy_attributes(copied)
    return {
      'copy_image' => proc { |uri, source|
        copied << [uri, source]
      },
    }
  end

  spec_dir = File.dirname(__FILE__)

  shared_context 'convert' do
    let(:result) do
      copied = []
      attributes = copy_attributes copied
      result = convert_with_logs input, attributes
      result.push copied
      result
    end
    let(:logs)   { result[1] }
    let(:copied) { result[2] }
  end
  shared_examples 'copies the image' do
    include_context 'convert'
    it 'copies the image' do
      expect(copied).to eq([
          [resolved, "#{spec_dir}/resources/copy_images/example1.png"],
      ])
    end
    it 'logs that it copied the image' do
      expect(logs).to eq("INFO: <stdin>: line #{include_line}: copying #{spec_dir}/resources/copy_images/example1.png")
    end
  end
  shared_examples 'copies images' do
    let(:input) do
      <<~ASCIIDOC
        == Example
        #{image_command}
      ASCIIDOC
    end
    let(:include_line) { 2 }
    context 'when the image ref matches that path exactly' do
      let(:target)   { 'resources/copy_images/example1.png' }
      let(:resolved) { 'resources/copy_images/example1.png' }
      include_examples 'copies the image'
    end
    context 'when the image ref is just the name of the image' do
      let(:target)   { 'example1.png' }
      let(:resolved) { 'example1.png' }
      include_examples 'copies the image'
    end
    context 'when the image ref matches the end of the path' do
      let(:target)   { 'copy_images/example1.png' }
      let(:resolved) { 'copy_images/example1.png' }
      include_examples 'copies the image'
    end
    context 'when the image contains attributes' do
      let(:target)   { 'example1.{ext}' }
      let(:resolved) { 'example1.png' }
      let(:input) do
        <<~ASCIIDOC
          == Example
          :ext: png

          #{image_command}
        ASCIIDOC
      end
      let(:include_line) { 4 }
      include_examples 'copies the image'
    end
  end

  context 'for the image block macro' do
    let(:image_command) { "image::#{target}[]" }
    include_examples 'copies images'
  end
  context 'for the image inline macro' do
    let(:image_command) { "Words image:#{target}[] words" }
    include_examples 'copies images'
    context 'when the macro is escaped' do
      let(:target) { 'example1.jpg' }
      let(:input) do
        <<~ASCIIDOC
          == Example
          "Words \\image:#{target}[] words"
        ASCIIDOC
      end
      include_context 'convert'
      it "doesn't log about copying the image" do
        expect(logs).to eq('')
      end
      it "doesn't copy the image" do
        expect(copied).to eq([])
      end
    end
    context 'when there are multiple images on a line' do
      let(:input) do
        <<~ASCIIDOC
          == Example

          words image:example1.png[] words words image:example2.png[] words
        ASCIIDOC
      end
      let(:expected_warnings) do
        <<~WARNINGS
          INFO: <stdin>: line 3: copying #{spec_dir}/resources/copy_images/example1.png
          INFO: <stdin>: line 3: copying #{spec_dir}/resources/copy_images/example2.png
        WARNINGS
      end
      include_context 'convert'
      it 'copies the image' do
        expect(copied).to eq([
            ['example1.png', "#{spec_dir}/resources/copy_images/example1.png"],
            ['example2.png', "#{spec_dir}/resources/copy_images/example2.png"],
        ])
      end
      it 'logs that it copied the image' do
        expect(logs).to eq(expected_warnings.strip)
      end
    end
  end

  it "warns when it can't find a file" do
    copied = []
    attributes = copy_attributes copied
    input = <<~ASCIIDOC
      == Example
      image::not_found.jpg[]
    ASCIIDOC
    convert input, attributes, match(%r{
        WARN:\ <stdin>:\ line\ 2:\ can't\ read\ image\ at\ any\ of\ \[
          "#{spec_dir}/not_found.jpg",\s
          "#{spec_dir}/resources/not_found.jpg",\s
          .+
          "#{spec_dir}/resources/copy_images/not_found.jpg"
          .+
        \]}x).and(not_match(/INFO: <stdin>/))
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
    Dir.mktmpdir do |tmp|
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
          ["tmp_example1.png", "#{tmp}/tmp_example1.png"],
      ])
    end
  end

  it "can find files using a multi valued resources attribute" do
    Dir.mktmpdir do |tmp|
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
          ["tmp_example1.png", "#{tmp}/tmp_example1.png"],
      ])
    end
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
        ["example1.png", "#{spec_dir}/resources/copy_images/example1.png"],
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
        ["example1.png", "#{spec_dir}/resources/copy_images/example1.png"],
    ])
  end

  it "has a nice error message when it can't find a file with single valued resources attribute" do
    Dir.mktmpdir do |tmp|
      copied = []
      attributes = copy_attributes copied
      attributes['resources'] = tmp
      input = <<~ASCIIDOC
        == Example
        image::not_found.png[]
      ASCIIDOC
      convert input, attributes, match(%r{
          WARN:\ <stdin>:\ line\ 2:\ can't\ read\ image\ at\ any\ of\ \[
            "#{tmp}/not_found.png",\s
            "#{spec_dir}/not_found.png",\s
            .+
          \]}x).and(not_match(/INFO: <stdin>/))
      expect(copied).to eq([])
    end
  end

  it "has a nice error message when it can't find a file with multi valued resources attribute" do
    Dir.mktmpdir do |tmp|
      copied = []
      attributes = copy_attributes copied
      attributes['resources'] = "#{tmp},/dummy2"
      input = <<~ASCIIDOC
        == Example
        image::not_found.png[]
      ASCIIDOC
      convert input, attributes, match(%r{
          WARN:\ <stdin>:\ line\ 2:\ can't\ read\ image\ at\ any\ of\ \[
            "/dummy2/not_found.png",\s
            "#{tmp}/not_found.png",\s
            "#{spec_dir}/not_found.png",\s
            .+
          \]}x).and(not_match(/INFO: <stdin>/))
      expect(copied).to eq([])
    end
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
    convert input, attributes, match(%r{
    WARN:\ <stdin>:\ line\ 6:\ can't\ read\ image\ at\ any\ of\ \[
      "#{spec_dir}/images/icons/callouts/2.gif",\s
      "#{spec_dir}/resources/images/icons/callouts/2.gif",\s
      .+
      "#{spec_dir}/resources/copy_images/images/icons/callouts/2.gif"
      .+
    \]}x).and(match(%r{INFO: <stdin>: line 5: copying #{spec_dir}/resources/copy_images/images/icons/callouts/1.gif}))
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

  it "doesn't blow up when the callout can't be found" do
    copied = []
    attributes = copy_attributes copied
    attributes['copy-callout-images'] = 'png'
    input = <<~ASCIIDOC
      == Example
      ----
      foo <1>
      ----
      <1> words
      <2> doesn't get an id
    ASCIIDOC
    expected_warnings = <<~WARNINGS
      WARN: <stdin>: line 6: no callout found for <2>
      INFO: <stdin>: line 5: copying #{spec_dir}/resources/copy_images/images/icons/callouts/1.png
    WARNINGS
    convert input, attributes, eq(expected_warnings.strip)
    expect(copied).to eq([
        ["images/icons/callouts/1.png", "#{spec_dir}/resources/copy_images/images/icons/callouts/1.png"],
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

  %w[note tip important caution warning].each do |(name)|
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
  end

  %w[beta experimental].each do |(name)|
    it "copies images for the block formatted #{name} care admonition when requested" do
      copied = []
      attributes = copy_attributes copied
      attributes['copy-admonition-images'] = 'png'
      input = <<~ASCIIDOC
        #{name}::[]
      ASCIIDOC
      # We can't get the location of the blocks because asciidoctor doesn't
      # make it available to us here!
      expected_warnings = <<~WARNINGS
        INFO: <stdin>: line 1: copying #{spec_dir}/resources/copy_images/images/icons/warning.png
      WARNINGS
      convert input, attributes, eq(expected_warnings.strip)
      expect(copied).to eq([
          ["images/icons/warning.png", "#{spec_dir}/resources/copy_images/images/icons/warning.png"],
      ])
    end
  end

  [
      %w[added note],
      %w[coming note],
      %w[deprecated warning],
  ].each do |(name, admonition)|
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
  end

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
