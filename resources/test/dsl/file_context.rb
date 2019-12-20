# frozen_string_literal: true

require_relative '../matcher/file_exist'

##
# Create a context to assert things about a file. By default it just
# asserts that the file was created but if you pass a block you can add
# assertions on `contents`.
# IMPORTANT: This requires a function to be in scope named `dest_file` that
# resolves the file name into the file's path.
def file_context(name, file_name = name, &block)
  context "for #{name}" do
    include_context 'Dsl_file', file_name

    # Yield to the block to add more tests.
    class_exec(&block) if block
  end
end
RSpec.shared_context 'Dsl_file' do |file_name|
  let(:file) do
    dest_file file_name
  end
  let(:contents) do
    File.open file, 'r:UTF-8', &:read if File.exist? file
  end

  it 'is created' do
    expect(file).to file_exist
  end
end
