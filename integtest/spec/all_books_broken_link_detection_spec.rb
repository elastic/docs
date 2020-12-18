# frozen_string_literal: true

require_relative 'spec_helper'

##
# Assertions about when books are rebuilt based on changes in source
# repositories or the book's configuration.
RSpec.describe 'building all books' do
  KIBANA_LINKS_FILE = 'src/ui/public/documentation_links/documentation_links.js'
  shared_context 'there is a broken link in the docs' do |text, check_links|
    convert_before do |src, dest|
      repo = src.repo_with_index 'repo', text
      book = src.book 'Test'
      book.source repo, 'index.asciidoc'
      convert = dest.prepare_convert_all src.conf
      convert.skip_link_check unless check_links
      convert.convert(expect_failure: check_links)
    end
  end
  shared_context 'there is a broken absolute link in the docs' do |check_links|
    include_context 'there is a broken link in the docs',
                    'https://www.elastic.co/guide/foo', check_links
  end
  shared_context 'there is a broken relative link in the docs' do |check_links|
    include_context 'there is a broken link in the docs',
                    'link:/guide/foo[]', check_links
  end
  shared_context 'there is a broken link in kibana' do |check_links|
    convert_before do |src, dest|
      # Kibana is special and we check links in it with a little magic
      kibana_repo = src.repo 'kibana'
      kibana_repo.write KIBANA_LINKS_FILE, <<~JS
        export const documentationLinks = {
          foo: `${ELASTIC_WEBSITE_URL}guide/foo`,
        };
      JS
      kibana_repo.commit 'init'

      # The preview of the book is important here because it is how we detect
      # the versions of kibana to check.
      # TODO: This is probably worth generalizing. Lots of repos reference docs.
      repo = src.repo_with_index 'repo', "Doesn't matter"
      book = src.book 'Test', prefix: 'en/kibana'
      book.source repo, 'index.asciidoc'
      convert = dest.prepare_convert_all src.conf
      convert.skip_link_check unless check_links
      convert.convert(expect_failure: check_links)
    end
  end

  describe 'when broken link detection is disabled' do
    describe 'when there is a broken absolute link in the docs' do
      include_context 'there is a broken absolute link in the docs', false
      it 'logs that it skipped link checking' do
        expect(outputs[0]).to include('Skipped Checking links')
      end
    end
    describe 'when there is a broken relative link in the docs' do
      include_context 'there is a broken relative link in the docs', false
      it 'logs that it skipped link checking' do
        expect(outputs[0]).to include('Skipped Checking links')
      end
    end
    describe 'when there is a broken link in kibana' do
      include_context 'there is a broken link in kibana', false
      it 'logs that it skipped link checking' do
        expect(outputs[0]).to include('Skipped Checking links')
      end
    end
  end
  describe 'when broken link detection is enabled' do
    shared_examples 'all links are ok' do
      it 'logs that all the links are ok' do
        expect(outputs[-1]).to include('All cross-document links OK')
      end
    end
    shared_examples 'there are broken links in the docs' do
      it 'logs there are bad cross document links' do
        expect(outputs[-1]).to include('Bad cross-document links:')
      end
      it 'logs the bad link' do
        expect(outputs[-1]).to include(indent(<<~LOG.strip, '  '))
          /tmp/docsbuild/target_repo/html/test/current/chapter.html contains broken links to:
           - foo
        LOG
      end
    end
    shared_examples 'there are broken links in kibana' do
      it 'logs there are bad cross document links' do
        expect(outputs[-1]).to include('Bad cross-document links:')
      end
      it 'logs the bad link' do
        expect(outputs[-1]).to include(indent(<<~LOG.strip, '  '))
          Kibana [master]: src/ui/public/documentation_links/documentation_links.js contains broken links to:
           - foo
        LOG
      end
    end
    describe 'when all of the links are intact' do
      convert_before do |src, dest|
        repo = src.repo_with_index(
          'repo',
          'https://www.elastic.co/guide/test/current/chapter.html'
        )
        book = src.book 'Test'
        book.source repo, 'index.asciidoc'
        dest.prepare_convert_all(src.conf).convert
      end
      include_examples 'all links are ok'
    end
    describe 'when there is a broken absolute link in the docs' do
      include_context 'there is a broken absolute link in the docs', true
      include_examples 'there are broken links in the docs'
    end
    describe 'when there is a broken relative link in the docs' do
      include_context 'there is a broken relative link in the docs', true
      include_examples 'there are broken links in the docs'
    end
    describe 'when there is a broken link in kibana' do
      include_context 'there is a broken link in kibana', true
      include_examples 'there are broken links in kibana'
    end
    describe 'when using --keep_hash and --sub_dir together like a PR test' do
      describe 'when there is a broken link in one of the books being built' do
        convert_before do |src, dest|
          repo1 = src.repo_with_index 'repo1', "Doesn't matter"
          book1 = src.book 'Test1'
          book1.source repo1, 'index.asciidoc'
          repo2 = src.repo_with_index 'repo2', "Also doesn't matter"
          book2 = src.book 'Test2'
          book2.source repo2, 'index.asciidoc'
          dest.prepare_convert_all(src.conf).convert

          repo2.write 'index.asciidoc', <<~ASCIIDOC
            = Title

            [[chapter]]
            == Chapter
            https://www.elastic.co/guide/foo
          ASCIIDOC
          dest.prepare_convert_all(src.conf)
              .keep_hash
              .sub_dir(repo2, 'master')
              .convert(expect_failure: true)
        end
        it 'logs there are bad cross document links' do
          expect(outputs[1]).to include('Bad cross-document links:')
        end
        it 'logs the bad link' do
          expect(outputs[1]).to include(indent(<<~LOG.strip, '  '))
            /tmp/docsbuild/target_repo/html/test2/current/chapter.html contains broken links to:
             - foo
          LOG
        end
      end
      describe "when there is a broken link in a book that isn't being built" do
        convert_before do |src, dest|
          repo1 = src.repo_with_index 'repo1', "Doesn't matter"
          book1 = src.book 'Test1'
          book1.source repo1, 'index.asciidoc'
          repo2 = src.repo_with_index 'repo2', "Also doesn't matter"
          book2 = src.book 'Test2'
          book2.source repo2, 'index.asciidoc'
          dest.prepare_convert_all(src.conf).convert

          repo1.write 'index.asciidoc', <<~ASCIIDOC
            = Title

            [[chapter]]
            == Chapter
            https://www.elastic.co/guide/foo
          ASCIIDOC
          dest.prepare_convert_all(src.conf)
              .keep_hash
              .sub_dir(repo2, 'master')
              .convert
        end
        include_examples 'all links are ok'
      end
      describe 'when there is a broken link in kibana' do
        def self.setup(src, dest)
          kibana_repo = src.repo_with_index 'kibana', "Doesn't matter"
          kibana_repo.write KIBANA_LINKS_FILE, 'no links here'
          kibana_repo.commit 'add empty links file'
          kibana_book = src.book 'Kibana', prefix: 'en/kibana'
          kibana_book.source kibana_repo, 'index.asciidoc'
          repo2 = src.repo_with_index 'repo2', "Also doesn't matter"
          book2 = src.book 'Test2'
          book2.source repo2, 'index.asciidoc'
          dest.prepare_convert_all(src.conf).convert

          kibana_repo.write KIBANA_LINKS_FILE, <<~JS
            export const documentationLinks = {
              foo: `${ELASTIC_WEBSITE_URL}guide/foo`,
            };
          JS
        end
        describe 'when the broken link is in an unbuilt branch' do
          convert_before do |src, dest|
            setup src, dest
            src.repo('kibana').commit 'add bad link'
            dest.prepare_convert_all(src.conf)
                .keep_hash
                .sub_dir(src.repo('repo2'), 'master')
                .convert
          end
          include_examples 'all links are ok'
        end
        describe 'when the broken link is in a *new* unbuilt branch' do
          convert_before do |src, dest|
            setup src, dest
            kibana = src.repo('kibana')
            kibana.switch_to_new_branch 'new_branch'
            kibana.commit 'add bad link'
            dest.prepare_convert_all(src.conf)
                .keep_hash
                .sub_dir(src.repo('repo2'), 'master')
                .convert
          end
          include_examples 'all links are ok'
        end
        describe 'when the broken link is in the --sub_dir' do
          convert_before do |src, dest|
            setup src, dest
            dest.prepare_convert_all(src.conf)
                .keep_hash
                .sub_dir(src.repo('kibana'), 'master')
                .convert(expect_failure: true)
          end
          include_examples 'there are broken links in kibana'
        end
      end
    end
  end
end
