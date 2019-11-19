# frozen_string_literal: true

require 'docbook_compat/extension'
require 'fileutils'
require 'tmpdir'

RSpec.describe DocbookCompat do
  before(:each) do
    Asciidoctor::Extensions.register DocbookCompat
  end

  after(:each) do
    Asciidoctor::Extensions.unregister_all
  end

  include_context 'convert without logs'
  let(:backend) { :html5 }

  context 'the header' do
    let(:standalone) { true }
    let(:convert_attributes) do
      # Shrink the output slightly so it is easier to read
      {
        'stylesheet!' => false,
        'dc.type' => 'FooType',
        'dc.subject' => 'BarSubject',
        'dc.identifier' => 'BazIdentifier',
      }
    end
    let(:input) do
      <<~ASCIIDOC
        = Title

        [[section]]
        == Section
      ASCIIDOC
    end
    it 'has an empty html tag' do
      expect(converted).to include('<html>')
    end
    it "doesn't declare edge compatibility" do
      expect(converted).not_to include('content="IE=edge"')
    end
    it "doesn't declare a viewport" do
      expect(converted).not_to include('name="viewport"')
    end
    it "doesn't declare a generator" do
      expect(converted).not_to include('name="generator"')
    end
    it 'has DC.type' do
      expect(converted).to include(<<~HTML)
        <meta name="DC.type" content="FooType"/>
      HTML
    end
    it 'has DC.subject' do
      expect(converted).to include(<<~HTML)
        <meta name="DC.subject" content="BarSubject"/>
      HTML
    end
    it 'has DC.identifier' do
      expect(converted).to include(<<~HTML)
        <meta name="DC.identifier" content="BazIdentifier"/>
      HTML
    end
    context 'the title' do
      it 'includes Elastic' do
        expect(converted).to include('<title>Title | Elastic</title>')
      end
    end
    context 'the body' do
      it "doesn't have attributes" do
        expect(converted).to include('<body>')
      end
      it 'is immediately followed by wrappers' do
        expect(converted).to include(<<~HTML)
          <body>
          <div class="book" lang="en">
        HTML
      end
    end
    context 'the header' do
      it "is wrapped in docbook's funny titlepage" do
        expect(converted).to include(<<~HTML)
          <div class="titlepage"><div><div>
          <h1 class="title">
          <a id="id-1"></a>Title
          </h1>
          </div></div><hr></div>
        HTML
      end
    end
  end
end
