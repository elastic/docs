# frozen_string_literal: true

require 'chunker/extension'
require 'fileutils'
require 'tmpdir'

RSpec.describe Chunker do
  before(:each) do
    Asciidoctor::Extensions.register Chunker
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  include_context 'convert without logs'
  let(:backend) { :html5 }
  let(:standalone) { true }

  shared_examples 'healthy head' do
    context 'the <head>' do
      it 'contains the charset' do
        expect(contents).to include(<<~HTML)
          <meta charset="UTF-8">
        HTML
      end
      it "doesn't contain the builtin asciidoctor stylesheet" do
        # We turned the stylesheet off
        expect(contents).not_to include('<style')
      end
    end
  end

  context 'when outdir is configured' do
    let(:outdir) { Dir.mktmpdir }
    after(:example) { FileUtils.remove_entry outdir }
    context 'when chunk level is 1' do
      let(:convert_attributes) do
        {
          'outdir' => outdir,
          'chunk_level' => 1,
          # Shrink the output slightly so it is easier to read
          'stylesheet!' => false,
        }
      end
      context 'there is are two level 1 sections' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            [[s1]]
            == Section 1

            Words words.

            [[s2]]
            == Section 2

            Words again.
          ASCIIDOC
        end
        context 'the main output' do
          let(:contents) { converted }
          include_examples 'healthy head'
          it 'contains a link to the first section' do
            expect(converted).to include(<<~HTML.strip)
              <li><span class="chapter"><a href="s1.html">Section 1</a></span></li>
            HTML
          end
          it 'contains a link to the second section' do
            expect(converted).to include(<<~HTML.strip)
              <li><span class="chapter"><a href="s1.html">Section 1</a></span></li>
            HTML
          end
        end
        file_context 'the first section', 's1.html' do
          include_examples 'healthy head'
          it 'contains the heading' do
            expect(contents).to include('<h2 id="s1">Section 1</h2>')
          end
          it 'contains the contents' do
            expect(contents).to include '<p>Words words.</p>'
          end
        end
        file_context 'the first section', 's2.html' do
          include_examples 'healthy head'
          it 'contains the heading' do
            expect(contents).to include('<h2 id="s2">Section 2</h2>')
          end
          it 'contains the contents' do
            expect(contents).to include '<p>Words again.</p>'
          end
        end
      end
      context 'there is a level 2 section' do
        let(:input) do
          <<~ASCIIDOC
            = Title

            [[l1]]
            == Level 1

            Words words.

            [[l2]]
            === Level 2

            Words again.
          ASCIIDOC
        end
        context 'the main output' do
          it 'contains a link to the level 1 section' do
            expect(converted).to include(<<~HTML.strip)
              <li><span class="chapter"><a href="l1.html">Level 1</a></span></li>
            HTML
          end
          it "doesn't contain a link to the level 2 section" do
            expect(converted).not_to include(<<~HTML.strip)
              <a href="l2.html">
            HTML
          end
        end
        file_context 'the level one section', 'l1.html' do
          it 'contains the header of the level 1 section' do
            expect(contents).to include('<h2 id="l1">Level 1</h2>')
          end
          it 'contains first paragraph' do
            expect(contents).to include('<p>Words words.</p>')
          end
          it 'contains the header of the level 2 section' do
            expect(contents).to include('<h3 id="l2">Level 2</h3>')
          end
          it 'contains the contents of the level 2 section' do
            expect(contents).to include('<p>Words again.</p>')
          end
          it "doesn't contain a link to the level 2 section" do
            expect(converted).not_to include(<<~HTML.strip)
              <a href="l2.html">
            HTML
          end
        end
        it 'there is no file named for the level 2 section' do
          expect(File.join(outdir, 'l2.html')).not_to file_exist
        end
      end
    end
  end
  context "when outdir isn't configured" do
    context 'the plugin does nothing' do
    end
  end
end
