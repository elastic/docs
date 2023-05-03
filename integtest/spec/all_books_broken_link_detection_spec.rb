# frozen_string_literal: true

require_relative 'spec_helper'

##
# Assertions about when books are rebuilt based on changes in source
# repositories or the book's configuration.
RSpec.describe 'building all books' do
  KIBANA_LINKS_FILE = 'src/core/public/doc_links/doc_links_service.ts'
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
  shared_context 'there is a broken absolute link to master' do |check_links|
    include_context 'there is a broken link in the docs',
                    'https://www.elastic.co/guide/foo', check_links
  end
  shared_context 'there is a broken relative link in the docs' do |check_links|
    include_context 'there is a broken link in the docs',
                    'link:/guide/foo[]', check_links
  end
  shared_context 'there is a broken relative link to master' do |check_links|
    include_context 'there is a broken link in the docs',
                    'link:/guide/foo[]', check_links
  end
  shared_context 'there is a kibana link' do |check_links, url, expect_failure|
    convert_before do |src, dest|
      # Kibana is special and we check links in it with a little magic
      kibana_repo = src.repo 'kibana'
      kibana_repo.write KIBANA_LINKS_FILE, <<~JS
        export const documentationLinks = {
          foo: `#{url}`,
        };
      JS
      kibana_repo.commit 'init'

      # TODO: remove as part of https://github.com/elastic/docs/issues/2264,
      # and make "main" the default branch for all repos.
      kibana_repo.rename_branch 'main'

      # The preview of the book is important here because it is how we detect
      # the versions of kibana to check.
      # TODO: This is probably worth generalizing. Lots of repos reference docs.
      repo = src.repo_with_index 'repo', "Doesn't matter"

      # TODO: remove as part of https://github.com/elastic/docs/issues/2264
      repo.rename_branch 'main'

      book = src.book 'Test', prefix: 'en/kibana'
      book.source repo, 'index.asciidoc'

      # TODO: remove as part of https://github.com/elastic/docs/issues/2264
      book.branches = [{ "main": 'master' }]
      book.live_branches = ['main']
      book.current_branch = 'main'

      convert = dest.prepare_convert_all src.conf
      convert.skip_link_check unless check_links
      convert.convert(expect_failure: expect_failure)
    end
  end

  shared_context 'there is a broken link in kibana' do |check_links|
    # If we check links, we expect failure, and if we don't check links, we
    # don't expect failure.
    include_context 'there is a kibana link', check_links,
                    '${ELASTIC_WEBSITE_URL}guide/foo', check_links
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
    describe 'when there is a broken absolute link to master' do
      include_context 'there is a broken absolute link to master', false
      it 'logs but does not fail on master links' do
        expect(outputs[0]).to include('Bad master links')
      end
    end
    describe 'when there is a broken relative link to master' do
      include_context 'there is a broken relative link to master', false
      it 'logs but does not fail on master links' do
        expect(outputs[0]).to include('Bad master links')
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
    shared_examples 'there are links to master in the docs' do
      it 'logs there are master links' do
        expect(outputs[-1]).to include('Bad master links')
      end
      it 'logs the bad link' do
        expect(outputs[-1]).to include(indent(<<~LOG.strip, '  '))
          /tmp/docsbuild/target_repo/html/test/current/chapter.html contains broken master links to:
           - foo
        LOG
      end
    end
    shared_examples 'there are broken links in kibana' do |url|
      it 'logs there are bad cross document links' do
        expect(outputs[-1]).to include('Bad cross-document links:')
      end
      it 'logs the bad link' do
        expect(outputs[-1]).to include(indent(<<~LOG.strip, '  '))
          Kibana [master]: src/core/public/doc_links/doc_links_service.ts contains broken links to:
           - #{url}
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
    describe 'when there is a broken absolute link to master' do
      include_context 'there is a broken absolute link to master', false
      include_examples 'there are links to master in the docs'
    end
    describe 'when there is a broken relative link to master' do
      include_context 'there is a broken relative link to master', false
      include_examples 'there are broken links in the docs'
    end
    describe 'when there is a broken link in kibana' do
      include_context 'there is a broken link in kibana', true
      include_examples 'there are broken links in kibana', 'foo'
    end
    describe 'when a link in kibana goes to the website outside the guide' do
      include_context 'there is a kibana link', true,
                      '${ELASTIC_WEBSITE_URL}not-part-of-the-guide', false
      include_examples 'all links are ok'
    end
    describe 'when there is a broken Elasticsearch Guide link in Kibana' do
      include_context 'there is a kibana link', true,
                      '${ELASTICSEARCH_DOCS}missing-page.html', true
      include_examples 'there are broken links in kibana',
                       'en/elasticsearch/reference/current/missing-page.html'
    end
    describe 'when there is a broken Kibana guide link' do
      include_context 'there is a kibana link', true,
                      '${KIBANA_DOCS}not-a-kibana-page.html', true
      include_examples 'there are broken links in kibana',
                       'en/kibana/current/not-a-kibana-page.html'
    end
    describe 'when there is a broken ES Plugin link' do
      include_context 'there is a kibana link', true,
                      '${PLUGIN_DOCS}not-valid-plugin.html', true
      include_examples 'there are broken links in kibana',
                       'en/elasticsearch/plugins/current/not-valid-plugin.html'
    end
    describe 'when there is a broken Fleet link' do
      include_context 'there is a kibana link', true,
                      '${FLEET_DOCS}not-a-fleet-page.html', true
      include_examples 'there are broken links in kibana',
                       'en/fleet/current/not-a-fleet-page.html'
    end
    describe 'when there is a broken APM link' do
      include_context 'there is a kibana link', true,
                      '${APM_DOCS}not-an-apm-page.html', true
      include_examples 'there are broken links in kibana',
                       'en/apm/not-an-apm-page.html'
    end
    describe 'when there is a broken Stack link' do
      include_context 'there is a kibana link', true,
                      '${STACK_DOCS}not-a-stack-page.html', true
      include_examples 'there are broken links in kibana',
                       'en/elastic-stack/current/not-a-stack-page.html'
    end
    describe 'when there is a broken Security link' do
      include_context 'there is a kibana link', true,
                      '${SECURITY_SOLUTION_DOCS}not-a-security-page.html', true
      include_examples 'there are broken links in kibana',
                       'en/security/current/not-a-security-page.html'
    end
    describe 'when there is a broken Stack Getting Started link' do
      include_context 'there is a kibana link', true,
                      '${STACK_GETTING_STARTED}not-a-page.html', true
      include_examples 'there are broken links in kibana',
                       'en/elastic-stack-get-started/current/not-a-page.html'
    end
    describe 'when there is a broken App Search link' do
      include_context 'there is a kibana link', true,
                      '${APP_SEARCH_DOCS}not-a-search-page.html', true
      include_examples 'there are broken links in kibana',
                       'en/app-search/current/not-a-search-page.html'
    end
    describe 'when there is a broken Enterprise Search link' do
      include_context 'there is a kibana link', true,
                      '${ENTERPRISE_SEARCH_DOCS}not-a-search-page.html', true
      include_examples 'there are broken links in kibana',
                       'en/enterprise-search/current/not-a-search-page.html'
    end
    describe 'when there is a broken Workplace Search link' do
      include_context 'there is a kibana link', true,
                      '${WORKPLACE_SEARCH_DOCS}not-a-search-page.html', true
      include_examples 'there are broken links in kibana',
                       'en/workplace-search/current/not-a-search-page.html'
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

          # TODO: remove as part of https://github.com/elastic/docs/issues/2264,
          # and make "main" the default branch for all repos.
          kibana_repo.rename_branch 'main'

          kibana_repo.write KIBANA_LINKS_FILE, 'no links here'
          kibana_repo.commit 'add empty links file'
          kibana_book = src.book 'Kibana', prefix: 'en/kibana'
          kibana_book.source kibana_repo, 'index.asciidoc'

          # TODO: remove as part of https://github.com/elastic/docs/issues/2264
          kibana_book.branches = [{ "main": 'master' }]
          kibana_book.live_branches = ['main']
          kibana_book.current_branch = 'main'

          repo2 = src.repo_with_index 'repo2', "Also doesn't matter"

          # TODO: remove as part of https://github.com/elastic/docs/issues/2264
          repo2.rename_branch 'main'

          book2 = src.book 'Test2'
          book2.source repo2, 'index.asciidoc'

          # TODO: remove as part of https://github.com/elastic/docs/issues/2264
          book2.branches = [{ "main": 'master' }]
          book2.live_branches = ['main']
          book2.current_branch = 'main'

          dest.prepare_convert_all(src.conf).convert

          kibana_repo.write KIBANA_LINKS_FILE, <<~JS
            export const documentationLinks = {
              foo: `${ELASTIC_WEBSITE_URL}guide/bar`,
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
                .sub_dir(src.repo('kibana'), 'main')
                .convert(expect_failure: true)
          end
          include_examples 'there are broken links in kibana', 'bar'
        end
      end
    end
  end
end
