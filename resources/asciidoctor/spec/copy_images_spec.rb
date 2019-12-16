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
    Asciidoctor::Extensions.register CopyImages
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
    let(:log_line) { include_line + log_offset }
    ##
    # Asserts that some `input` causes just the `example1.png` image to
    # be copied.
    shared_examples 'copies example1' do
      it 'copies the image' do
        expect(copied).to eq([[resolved, "#{spec_dir}/#{example1}"]])
      end
      it 'logs that it copied the image' do
        expect(logs).to include(
          "INFO: <stdin>: line #{log_line}: copying #{spec_dir}/#{example1}"
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
      context 'when the attribute is close to the image' do
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
      context 'when the attribute is far from the image' do
        let(:input) do
          <<~ASCIIDOC
            == Example
            :ext: png

            Words.

            #{image_command}
          ASCIIDOC
        end
        let(:include_line) { 6 }
        include_examples 'copies example1'
      end
    end
    context 'when using the imagesdir attribute' do
      let(:target) { 'example1.png' }
      let(:resolved) { 'resources/copy_images/example1.png' }
      let(:input) do
        <<~ASCIIDOC
          == Example
          :imagesdir: resources/copy_images

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
        %r{WARN:\ <stdin>:\ line\ \d+:\ can't\ read\ image\ at\ any\ of\ \[
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
          "ERROR: <stdin>: line #{log_line}: Error loading [resources]: " \
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
            "INFO: <stdin>: line #{log_line}: copying #{tmp}/#{target}"
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
          %r{WARN:\ <stdin>:\ line\ \d+:\ can't\ read\ image\ at\ any\ of\ \[
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
          %r{WARN:\ <stdin>:\ line\ \d+:\ can't\ read\ image\ at\ any\ of\ \[
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

  let(:log_offset) { 0 }
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
    context 'when the inline image has a specified width' do
      let(:image_command) { "image:#{target}[width=600]" }
      include_examples 'copies images with various paths'
    end
    context 'when the inline image is inside an ordered list' do
      let(:image_command) { ". Words image:#{target}[] words" }
      include_examples 'copies images with various paths'
    end
    context 'when the inline image is inside an unordered list' do
      let(:image_command) { "* Words image:#{target}[] words" }
      include_examples 'copies images with various paths'
    end
    context 'when the inline image is inside a definition list' do
      let(:image_command) { "Foo:: Words image:#{target}[] words" }
      include_examples 'copies images with various paths'
    end
    context 'when the inline image is inside a callout list' do
      let(:image_command) do
        <<~ASCIIDOC
          ----
          foo <1>
          ----

          <1> word image:#{target}[] word
        ASCIIDOC
      end
      let(:log_offset) { 4 }
      include_examples 'copies images with various paths'
    end
    context 'when there is a reference in an ordered list' do
      let(:input) do
        <<~ASCIIDOC
          [[foo-thing]]
          == Example
          :id: foo

          More words.

          . <<{id}-thing>>
        ASCIIDOC
      end
      it "doesn't log anything" do
        expect(logs).to eq('')
      end
    end
    context 'when there is an empty definition list' do
      let(:input) do
        <<~ASCIIDOC
          == Example
          Foo::
          Bar:::
        ASCIIDOC
      end
      it "doesn't log anything" do
        expect(logs).to eq('')
      end
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
end
