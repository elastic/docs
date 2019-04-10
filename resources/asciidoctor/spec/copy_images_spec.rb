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

  ##
  # Like the 'convert' shared context, but also captures any images that
  # would be copied by the conversion process to the `convert` array. That
  # array contains tuples of the form
  # [image_path_from_asciidoc_file, image_path_on_disk] and is in the order
  # that the images source be copied.
  shared_context 'convert intercepting images' do
    # TODO: once we've switched all of the examples in this file we can probably
    #  drop this.
    include_context 'convert with logs'

    # [] is the initial value but it is mutated by the conversion
    let(:copied_storage) { [].dup }
    let(:convert_attributes) do
      copy_attributes(copied_storage).tap do |attrs|
        attrs['resources'] = resources if defined?(resources)
        attrs['copy-callout-images'] = copy_callout_images \
          if defined?(copy_callout_images)
      end
    end
    let(:copied) do
      # Force evaluation of converted because it populates copied_storage
      converted
      copied_storage
    end
  end

  # Absolute paths
  let(:spec_dir) { File.dirname(__FILE__) }
  let(:resources_dir) { "#{spec_dir}/resources/copy_images" }

  # Full relative path to example images
  let(:example1) { "resources/copy_images/example1.png" }
  let(:example2) { "resources/copy_images/example2.png" }

  ##
  # Asserts that a particular `image_command` copies the appropriate image
  # when the image is referred to in many ways. The `image_command` should
  # read `target` for the location of the image.
  shared_examples 'copies images with various paths' do
    let(:input) do
      <<~ASCIIDOC
        == Example
        #{image_command}
      ASCIIDOC
    end
    let(:include_line) { 2 }
    ##
    # Asserts that some `input` causes just the `example1.png` image to be copied.
    shared_examples 'copies example1' do
      include_context 'convert intercepting images'
      it 'copies the image' do
        expect(copied).to eq([[resolved, "#{spec_dir}/#{example1}"]])
      end
      it 'logs that it copied the image' do
        expect(logs).to include(
          "INFO: <stdin>: line #{include_line}: copying #{spec_dir}/#{example1}"
        )
      end
    end
    shared_examples "when it can't find a file" do
      include_context 'convert intercepting images'
      let(:target) { 'not_found.jpg' }
      it 'logs a warning' do
        expect(logs).to match(expected_logs).and(not_match(/INFO: <stdin>/))
      end
      it "doesn't copy anything" do
        expect(copied).to eq([])
      end
    end

    context 'when the image ref matches that path exactly' do
      let(:target) { example1 }
      let(:resolved) { example1 }
      include_examples 'copies example1'
    end
    context 'when the image ref is just the name of the image' do
      let(:target) { 'example1.png' }
      let(:resolved) { 'example1.png' }
      include_examples 'copies example1'
    end
    context 'when the image ref matches the end of the path' do
      let(:target) { 'copy_images/example1.png' }
      let(:resolved) { 'copy_images/example1.png' }
      include_examples 'copies example1'
    end
    context 'when the image contains attributes' do
      let(:target) { 'example1.{ext}' }
      let(:resolved) { 'example1.png' }
      let(:input) do
        <<~ASCIIDOC
          == Example
          :ext: png

          #{image_command}
        ASCIIDOC
      end
      let(:include_line) { 4 }
      include_examples 'copies example1'
    end
    context 'when referencing an external image' do
      include_context 'convert intercepting images'
      let(:target) do
        'https://f.cloud.github.com/assets/4320215/768165/19d8b1aa-e899-11e2-91bc-6b0553e8d722.png'
      end
      it "doesn't log anything" do
        expect(logs).to eq('')
      end
      it "doesn't copy anything" do
        expect(copied).to eq([])
      end
    end
    context "when it can't find a file" do
      include_examples "when it can't find a file"
      let(:expected_logs) do
        %r{WARN:\ <stdin>:\ line\ 2:\ can't\ read\ image\ at\ any\ of\ \[
          "#{spec_dir}/not_found.jpg",\s
          "#{spec_dir}/resources/not_found.jpg",\s
          .+
          "#{spec_dir}/resources/copy_images/not_found.jpg"
          .+
        \]}x
        # Comment to fix syntax highlighting bug in VSCode....'
      end
    end
    context 'when the resources attribute is invalid CSV' do
      # Note that we still copy the images even with the invalid resources
      include_examples 'copies example1'
      let(:resources) { '"' }
      let(:target) { 'example1.png' }
      let(:resolved) { 'example1.png' }
      it 'logs an error' do
        expect(logs).to include(
          "ERROR: <stdin>: line 2: Error loading [resources]: " \
          "Unclosed quoted field on line 1."
        )
      end
    end

    ##
    # Context and examples for testing copying from the directories in the
    # `resources` attribute.
    #
    # Input:
    #    resources - set it to a comma separated list of directories
    #                containing #{tmp}
    shared_examples 'copy with resources' do
      let(:tmp) { Dir.mktmpdir }
      before(:example) do
        FileUtils.cp(
          File.join(spec_dir, 'resources', 'copy_images', 'example1.png'),
          File.join(tmp, 'tmp_example1.png')
        )
      end
      after(:example) { FileUtils.remove_entry tmp }
      context 'when the referenced image is in the resource directory' do
        include_context 'convert intercepting images'
        let(:target) { 'tmp_example1.png' }
        it 'copies the image' do
          expect(copied).to eq([[target, "#{tmp}/#{target}"]])
        end
        it 'logs that it copied the image' do
          expect(logs).to eq(
            "INFO: <stdin>: line 2: copying #{tmp}/#{target}"
          )
        end
      end
      context 'when the referenced image is in the doc directory' do
        include_examples 'copies example1'
        let(:target) { 'example1.png' }
        let(:resolved) { 'example1.png' }
      end
    end
    context 'when the resources attribute contains a single directory' do
      let(:resources) { tmp }
      include_examples 'copy with resources'
      context "when it can't find a file" do
        include_examples "when it can't find a file"
        let(:expected_logs) do
          %r{WARN:\ <stdin>:\ line\ 2:\ can't\ read\ image\ at\ any\ of\ \[
            "#{tmp}/not_found.jpg",\s
            "#{spec_dir}/not_found.jpg",\s
            .+
          \]}x
          # Comment to fix syntax highlighting bug in VSCode....'
        end
      end
    end
    context 'when the resources attribute contains a multiple directories' do
      let(:resources) { "/dummy1,#{tmp},/dummy2" }
      include_examples 'copy with resources'
      context "when it can't find a file" do
        include_examples "when it can't find a file"
        let(:expected_logs) do
          %r{WARN:\ <stdin>:\ line\ 2:\ can't\ read\ image\ at\ any\ of\ \[
            "/dummy1/not_found.jpg",\s
            "/dummy2/not_found.jpg",\s
            "#{tmp}/not_found.jpg",\s
            "#{spec_dir}/not_found.jpg",\s
            .+
          \]}x
          # Comment to fix syntax highlighting bug in VSCode....'
        end
      end
    end
    context 'when the resources attribute is empty' do
      let(:resources) { '' }
      let(:target) { example1 }
      let(:resolved) { example1 }
      include_examples 'copies example1'
    end
  end

  context 'for the image block macro' do
    let(:image_command) { "image::#{target}[]" }
    include_examples 'copies images with various paths'
  end
  context 'for the image inline macro' do
    let(:image_command) { "Words image:#{target}[] words" }
    include_examples 'copies images with various paths'
    context 'when the macro is escaped' do
      let(:target) { 'example1.jpg' }
      let(:input) do
        <<~ASCIIDOC
          == Example
          "Words \\image:#{target}[] words"
        ASCIIDOC
      end
      include_context 'convert intercepting images'
      it "doesn't log anything" do
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
      let(:expected_logs) do
        <<~LOGS
          INFO: <stdin>: line 3: copying #{spec_dir}/#{example1}
          INFO: <stdin>: line 3: copying #{spec_dir}/#{example2}
        LOGS
      end
      include_context 'convert intercepting images'
      it 'copies the images' do
        expect(copied).to eq([
            ['example1.png', "#{spec_dir}/#{example1}"],
            ['example2.png', "#{spec_dir}/#{example2}"],
        ])
      end
      it 'logs that it copied the image' do
        expect(logs).to eq(expected_logs.strip)
      end
    end
  end

  context 'when the same image is referenced more than once' do
    include_context 'convert intercepting images'
    let(:input) do
      <<~ASCIIDOC
        == Example
        image::#{example1}[]
        image::#{example1}[]
        image::#{example2}[]
        image::#{example1}[]
        image::#{example2}[]
      ASCIIDOC
    end
    let(:expected_copied) do
      [
        [example1, "#{spec_dir}/#{example1}"],
        [example2, "#{spec_dir}/#{example2}"],
      ]
    end
    it 'is only copied once' do
      expect(copied).to eq(expected_copied)
    end
    let(:expected_logs) do
      <<~LOG
        INFO: <stdin>: line 2: copying #{spec_dir}/#{example1}
        INFO: <stdin>: line 4: copying #{spec_dir}/#{example2}
      LOG
    end
    it 'is only logged once' do
      expect(logs).to eq(expected_logs.strip)
    end
  end

  shared_context 'copy-callout-images' do
    include_context 'convert intercepting images'
    let(:input) do
      <<~ASCIIDOC
        == Example
        ----
        foo <1> <2>
        ----
        <1> words
        <2> words
      ASCIIDOC
    end
  end
  shared_context 'copy-callout-images is set' do
    include_context 'copy-callout-images'
    let(:relative_path) { 'images/icons/callouts' }
    let(:absolute_path) { "#{resources_dir}/#{relative_path}" }
    let(:expected_copied) do
      [
        ["#{relative_path}/1.#{copy_callout_images}",
         "#{absolute_path}/1.#{copy_callout_images}"],
        ["#{relative_path}/2.#{copy_callout_images}",
         "#{absolute_path}/2.#{copy_callout_images}"],
      ]
    end
    let(:expected_logs) do
      <<~LOGS
        INFO: <stdin>: line 5: copying #{absolute_path}/1.#{copy_callout_images}
        INFO: <stdin>: line 6: copying #{absolute_path}/2.#{copy_callout_images}
      LOGS
    end
    it 'copies the callout images' do
      expect(copied).to eq(expected_copied)
    end
    it 'logs that it copied the callout images' do
      expect(logs).to eq(expected_logs.strip)
    end
    context 'when a callout image is missing' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          ----
          foo <1> <2> <3>
          ----
          <1> words
          <2> words
          <3> words
        ASCIIDOC
      end
      let(:expected_warnings) do
        %r{
          WARN:\ <stdin>:\ line\ 7:\ can't\ read\ image\ at\ any\ of\ \[
          "#{spec_dir}/images/icons/callouts/3.#{copy_callout_images}",\s
          "#{spec_dir}/resources/images/icons/callouts/3.#{copy_callout_images}",\s
          .+
          "#{spec_dir}/resources/copy_images/images/icons/callouts/3.#{copy_callout_images}"
          .+
        \]}x
        # Comment to fix syntax highlighting bug in VSCode....'
      end
      it 'copies the images it can find' do
        expect(copied).to eq(expected_copied)
      end
      it 'logs about the images it can copy' do
        expect(logs).to include(expected_logs.strip)
      end
      it "logs a warning about the image it can't find" do
        expect(logs).to match(expected_warnings)
      end
    end
  end
  context 'when copy-callout-images is set to png' do
    include_context 'copy-callout-images is set'
    let(:copy_callout_images) { 'png' }
  end
  context 'when copy-callout-images is set to gif' do
    include_context 'copy-callout-images is set'
    let(:copy_callout_images) { 'gif' }
  end
  context "when copy-callout-images isn't set" do
    include_context 'copy-callout-images'
    it "doesn't copy the callout images" do
      expect(copied).to eq([])
    end
    it "doesn't log that it copied the callout images" do
      expect(logs).to eq('')
    end
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
