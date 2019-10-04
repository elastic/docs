# frozen_string_literal: true

##
# Assertions about what sources books can use.
RSpec.describe 'building all books' do
  describe 'with interesting sources' do
    describe 'the docs repo' do
      def self.init_docs_repo(src)
        repo = src.repo 'docs'
        repo.copy_shared_conf
        repo.commit 'add shared conf'
        repo
      end
      let(:docs_repo) { src.repo 'docs' }
      let(:hash) { docs_repo.short_hash }
      let(:master_version) do
        contents = docs_repo.read 'shared/versions/stack/master.asciidoc'
        m = contents.match(/:elasticsearch_version:\s+(.+)\n/)
        raise "couldn't parse #{contents}" unless m

        m[1]
      end
      let(:current_target) do
        contents = docs_repo.read 'shared/versions/stack/current.asciidoc'
        m = contents.match(/include::(.+)\[\]/)
        raise "couldn't parse #{contents}" unless m

        m[1]
      end
      let(:current_version) do
        contents = docs_repo.read "shared/versions/stack/#{current_target}"
        m = contents.match(/:elasticsearch_version:\s+(.+)\n/)
        raise "couldn't parse #{contents}" unless m

        m[1]
      end
      describe 'attributes file' do
        convert_all_before_context do |src|
          repo = src.repo_with_index 'repo', <<~ASCIIDOC
            include::{docs-root}/shared/attributes.asciidoc[]

            {stack}
          ASCIIDOC
          book = src.book 'Test'
          book.source repo, 'index.asciidoc'
          book.source init_docs_repo(src), 'shared/attributes.asciidoc'
        end
        page_context 'raw/test/current/chapter.html' do
          it 'resolves an attribute from the docs repo' do
            expect(body).to include(<<~HTML.strip)
              <p>Elastic Stack</p>
            HTML
          end
        end
        file_context 'html/branches.yaml' do
          it 'references the hash of the docs repo' do
            expect(contents).to include(<<~LOG.strip)
              Test/shared/attributes.asciidoc/master: #{hash}
            LOG
          end
        end
      end
      describe 'versions files' do
        convert_all_before_context do |src|
          extra_branches = ['5.5', '6.3', '7.2']
          repo = src.repo_with_index 'repo', <<~ASCIIDOC
            include::{docs-root}/shared/versions/stack/{source_branch}.asciidoc[]

            {elasticsearch_version}
          ASCIIDOC
          extra_branches.each { |b| repo.switch_to_new_branch b }
          docs_repo = init_docs_repo src
          book = src.book 'Test'
          book.branches << extra_branches
          book.source repo, 'index.asciidoc'
          book.source docs_repo, 'shared/versions/stack/{branch}.asciidoc'
        end
        shared_examples 'resolved attribute' do |branch, value|
          page_context "raw/test/#{branch}/chapter.html" do
            it 'resolves an attribute from the docs repo' do
              expect(body).to include(<<~HTML.strip)
                <p>#{value == 'master' ? master_version : value}</p>
              HTML
            end
          end
        end
        include_examples 'resolved attribute', 'master', 'master'
        include_examples 'resolved attribute', '7.2', '7.2.1'
        include_examples 'resolved attribute', '6.3', '6.3.2'
        include_examples 'resolved attribute', '5.5', '5.5.3'
        file_context 'html/branches.yaml' do
          shared_examples 'references the real path' do |branch|
            context "#{branch} branch" do
              it 'references the real path' do
                expect(contents).to include(<<~LOG.strip)
                  Test/shared/versions/stack/#{branch}.asciidoc/#{branch}: #{hash}
                LOG
              end
            end
          end
          include_examples 'references the real path', 'master'
          include_examples 'references the real path', '7.2'
          include_examples 'references the real path', '6.3'
          include_examples 'references the real path', '5.5'
        end
      end
      describe 'the current version file' do
        convert_all_before_context do |src|
          repo = src.repo_with_index 'repo', <<~ASCIIDOC
            include::{docs-root}/shared/versions/stack/current.asciidoc[]

            {elasticsearch_version}
          ASCIIDOC
          docs_repo = init_docs_repo src
          book = src.book 'Test'
          book.source repo, 'index.asciidoc'
          book.source docs_repo, 'shared/versions/stack/current.asciidoc'
        end
        page_context 'raw/test/current/chapter.html' do
          it 'resolves an attribute from the docs repo' do
            expect(body).to include(<<~HTML.strip)
              <p>#{current_version}</p>
            HTML
          end
        end
        file_context 'html/branches.yaml' do
          it 'references current.asciidoc' do
            expect(contents).to include(<<~LOG.strip)
              Test/shared/versions/stack/current.asciidoc/master: #{hash}
            LOG
          end
          it "references current.asciidoc's target" do
            expect(contents).to include(<<~LOG.strip)
              Test/shared/versions/stack/#{current_target}/master: #{hash}
            LOG
          end
        end
      end
      describe 'when the build fails' do
        convert_before do |src, dest|
          repo = src.repo_with_index 'repo', 'include::garbage.adoc[]'
          book = src.book 'Test'
          docs_repo = init_docs_repo src
          docs_repo.write 'garbage.txt', 'garbage'
          docs_repo.commit 'ignored by error reporting'
          book.source repo, 'index.asciidoc'
          book.source docs_repo, 'shared/attributes.asciidoc'
          dest.prepare_convert_all(src.conf).convert expect_failure: true
        end
        context 'the logs' do
          it 'contain the a sensible header for the docs' do
            expect(outputs[0]).to include(<<~LOGS.strip)
              Recent commits in docs/Test:HEAD:shared/attributes.asciidoc
            LOGS
          end
          let(:hash) { docs_repo.last_commit 'shared/attributes.asciidoc' }
          it 'contain the last commit that changed attributes.asciidoc' do
            expect(outputs[0]).to include(hash)
          end
        end
      end
    end
  end
end
