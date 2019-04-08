# frozen_string_literal: true

RSpec.describe 'building a single book' do
  def convert_args(from, to)
    %W[
      --doc #{from}
      --out #{to}
    ]
  end

  HEADER = <<~ASCIIDOC
    = Title

    [[chapter]]
    == Chapter
  ASCIIDOC

  context 'for a minimal book' do
    shared_context 'expected' do |file_name|
      convert_single_before_context do |src|
        src.write file_name, <<~ASCIIDOC
          #{HEADER}
          This is a minimal viable asciidoc file for use with build_docs. The
          actual contents of this paragraph aren't important but having a
          paragraph here is required.
        ASCIIDOC
      end

      page_context 'index.html' do
        it 'has the right title' do
          expect(title).to eq('Title')
        end
      end
      page_context 'chapter.html' do
        it 'has the right title' do
          expect(title).to eq('Chapter')
        end
      end
    end

    context 'when the file ends in .asciidoc' do
      include_context 'expected', 'minimal.asciidoc'
    end

    context 'when the file ends in .adoc' do
      include_context 'expected', 'minimal.adoc'
    end
  end

  context 'when one file includes another' do
    convert_single_before_context do |src|
      src.write 'included.asciidoc', 'I am tiny.'
      src.write 'index.asciidoc', <<~ASCIIDOC
        #{HEADER}
        I include "included" between here

        include::included.asciidoc[]

        and here.
      ASCIIDOC
    end

    page_context 'chapter.html' do
      it 'contains the index text' do
        expect(body).to include('I include "included"')
      end
      it 'contains the included text' do
        expect(body).to include('I am tiny.')
      end
    end
  end
  context 'when the book contains beta[]' do
    convert_single_before_context do |src|
      src.write 'index.asciidoc', <<~ASCIIDOC
        #{HEADER}
        beta[]

        Words
      ASCIIDOC
    end

    it 'copies the warning image' do
      expect(dest_file('images/icons/warning.png')).to file_exist
    end
    page_context 'chapter.html' do
      it 'includes the warning image' do
        expect(body).to include(
          '<img alt="Warning" src="images/icons/warning.png" />'
        )
      end
      it 'includes the beta text' do
        expect(body).to include(
          'The design and code is less mature than official GA features'
        )
      end
    end
  end
end
