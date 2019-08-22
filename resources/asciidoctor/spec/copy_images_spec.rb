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

  include_context 'convert with logs'

  # [] is the initial value but it is mutated by the conversion
  let(:copied_storage) { [] }
  let(:convert_attributes) do
    {
      'copy_image' => proc { |uri, source| copied_storage << [uri, source] },
    }.tap do |attrs|
      attrs['resources'] = resources if defined?(resources)
      if defined?(copy_callout_images)
        attrs['copy-callout-images'] = copy_callout_images
      end
      if defined?(copy_admonition_images)
        attrs['copy-admonition-images'] = copy_admonition_images
      end
    end
  end
  let(:copied) do
    # Force evaluation of converted because it populates copied_storage
    converted
    copied_storage
  end

  # Absolute paths
  let(:spec_dir) { File.dirname(__FILE__) }
  let(:resources_dir) { "#{spec_dir}/resources/copy_images" }

  # Full relative path to example images
  let(:example1) { 'resources/copy_images/example1.png' }
  let(:example2) { 'resources/copy_images/example2.png' }

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
    # Asserts that some `input` causes just the `example1.png` image to
    # be copied.
    shared_examples 'copies example1' do
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
          'ERROR: <stdin>: line 2: Error loading [resources]: ' \
          'Unclosed quoted field on line 1.'
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
      it 'copies the images' do
        expect(copied).to eq(
          [
            ['example1.png', "#{spec_dir}/#{example1}"],
            ['example2.png', "#{spec_dir}/#{example2}"],
          ]
        )
      end
      it 'logs that it copied the image' do
        expect(logs).to eq(expected_logs.strip)
      end
    end
    context 'when the inline image is inside an ordered list' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          . words image:example1.png[] words
        ASCIIDOC
      end
      let(:resolved) { 'example1.png' }
      include_examples 'copies example1'
    end
    context 'when the inline image is inside an unordered list' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          * words image:example1.png[] words
        ASCIIDOC
      end
      let(:resolved) { 'example1.png' }
      include_examples 'copies example1'
    end
  end

  context 'when the same image is referenced more than once' do
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
          "#{spec_dir}/#{relative_path}/3.#{copy_callout_images}",\s
          "#{spec_dir}/resources/#{relative_path}/3.#{copy_callout_images}",\s
          .+
          "#{absolute_path}/3.#{copy_callout_images}"
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
    context 'when a callout image is used multiple times' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          ----
          foo <1> <2>
          ----
          <1> words
          <2> more words

          ----
          foo <1> <2>
          ----
          <1> words
          <2> more words again
        ASCIIDOC
      end
      it 'copies the images one time each' do
        expect(copied).to eq(expected_copied)
      end
    end
    context 'when there are multiple callouts per item' do
      # This is a *super* weird case but we have it in Elasticsearch.
      # The only way I can make callout lists be for two things is by making
      # blocks with callouts but only having a single callout list below both.
      let(:input) do
        <<~ASCIIDOC
          == Example
          ----
          foo <1>
          ----

          ----
          foo <1>
          ----
          <1> words
        ASCIIDOC
      end
      it 'copies an image for <1> and an image for <2>' do
        expect(copied).to eq(expected_copied)
      end
    end
    context "when there isn't a callout for an item in the list" do
      let(:input) do
        <<~ASCIIDOC
          == Example
          ----
          foo <1>
          ----
          <1> words
          <2> doesn't get an id
        ASCIIDOC
      end
      it 'copies what it can' do
        expect(copied).to eq(
          [["#{relative_path}/1.#{copy_callout_images}",
            "#{absolute_path}/1.#{copy_callout_images}"]]
        )
      end
      it 'logs a warnings about the bad callout item' do
        expect(logs).to include(
          'WARN: <stdin>: line 6: no callout found for <2>'
        )
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

  shared_context 'copy-admonition-images' do
    let(:relative_path) { 'images/icons' }
    let(:absolute_path) { "#{resources_dir}/#{relative_path}" }
  end
  shared_context 'copy-admonition-images is set' do
    include_context 'copy-admonition-images'
    it 'copies the admonition image' do
      expect(copied).to eq(
        [["#{relative_path}/#{admonition_image}.#{copy_admonition_images}",
          "#{absolute_path}/#{admonition_image}.#{copy_admonition_images}"]]
      )
    end
    it 'logs that it copied the image' do
      expect(logs).to eq(<<~LOGS.strip)
        INFO#{location}: copying #{absolute_path}/#{admonition_image}.#{copy_admonition_images}
      LOGS
    end
  end
  shared_examples 'copy-admonition-images examples' do
    context 'copy-admonition-images is set to png' do
      let(:copy_admonition_images) { 'png' }
      include_context 'copy-admonition-images is set'
    end
    context 'copy-admonition-images is set to gif' do
      let(:copy_admonition_images) { 'gif' }
      include_context 'copy-admonition-images is set'
    end
    context 'copy-admonition-images is not set' do
      include_context 'copy-admonition-images'
      it "doesn't copy the admonition image" do
        expect(copied).to eq([])
      end
      it "doesn't log that it copied the admonition image" do
        expect(logs).to eq('')
      end
    end
  end

  context 'standard admonitions' do
    let(:input) do
      <<~ASCIIDOC
        #{admonition.upcase}: Words words words.
      ASCIIDOC
    end
    let(:location) { ': <stdin>: line 1' }
    let(:admonition_image) { admonition }
    context 'for the note admonition' do
      include_context 'copy-admonition-images examples'
      let(:admonition) { 'note' }
    end
    context 'for the tip admonition' do
      include_context 'copy-admonition-images examples'
      let(:admonition) { 'tip' }
    end
    context 'for the important admonition' do
      include_context 'copy-admonition-images examples'
      let(:admonition) { 'important' }
    end
    context 'for the caution admonition' do
      include_context 'copy-admonition-images examples'
      let(:admonition) { 'caution' }
    end
    context 'for the warning admonition' do
      include_context 'copy-admonition-images examples'
      let(:admonition) { 'warning' }
    end
  end

  context 'care admonitions' do
    let(:input) do
      <<~ASCIIDOC
        #{admonition}::[]
      ASCIIDOC
    end
    let(:location) { ': <stdin>: line 1' }
    let(:admonition_image) { 'warning' }
    context 'for the beta admonition' do
      include_context 'copy-admonition-images examples'
      let(:admonition) { 'beta' }
    end
    context 'for the experimental admonition' do
      include_context 'copy-admonition-images examples'
      let(:admonition) { 'experimental' }
    end
  end

  context 'change admonitions' do
    let(:input) do
      <<~ASCIIDOC
        #{admonition}::[some_version]
      ASCIIDOC
    end
    # Asciidoctor doesn't make the location available to us for logging here.
    let(:location) { '' }
    let(:admonition_image) { 'note' }
    context 'for the added admonition' do
      include_context 'copy-admonition-images examples'
      let(:admonition) { 'added' }
    end
    context 'for the coming admonition' do
      include_context 'copy-admonition-images examples'
      let(:admonition) { 'coming' }
    end
    context 'for the deprecated admonition' do
      include_context 'copy-admonition-images examples'
      let(:admonition) { 'deprecated' }
      let(:admonition_image) { 'warning' }
    end
  end
end
