# frozen_string_literal: true

RSpec.describe 'building all books' do
  context 'for a minimal config' do
    convert_all_before_context do |src|
      src.write 'source/index.asciidoc', <<~ASCIIDOC
        = Title

        == Chapter

        Some text.
      ASCIIDOC
      src.init_repo 'source'
      src.write 'conf.yaml', <<~YAML
        template:
          defaults:
            POSTHEAD: |
              <link rel="stylesheet" type="text/css" href="styles.css" />
            FINAL: |
              <script type="text/javascript" src="docs.js"></script>
              <script type='text/javascript' src='https://cdn.rawgit.com/google/code-prettify/master/loader/run_prettify.js?lang=yaml'></script>

        paths:
          build:          html/
          branch_tracker: html/branches.yaml
          repos:          #{src.path 'repos'}

        # This configures all of the repositories used to build the docs
        repos:
            # Normally we use the `https://` prefix to clone from github but this file
            # is for testing so use a string that we can find with sed and replace with
            # a file.
            source:         #{src.path 'source'}

        # The title to use for the table of contents
        contents_title:     Elastic Stack and Product Documentation

        # The actual books to build
        contents:
          -
            title:      Test book
            prefix:     test
            current:    master
            branches:   [ master ]
            index:      index.asciidoc
            tags:       test tag
            subject:    Test
            sources:
              -
                repo:   source
                path:   index.asciidoc
      YAML
    end
  end
end
