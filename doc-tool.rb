#!/usr/bin/env ruby

require 'set'
require 'pp'
require 'subcommander'
include Subcommander

#
# Get all of the attribute defs and uses from all of the asciidoc files
#
@defs = Set.new(["docdir", "asciidoc-dir"])
@files_with_defs = {} # path => defs
@uses = {} # path => defs_used
@subs = []

def blocks_removed data, path
  result = data
  # if the following block should substitute attributes
  if /(\[.*?subs=.*?attributes.*?\])/ =~ data
    result = ""
    remove_count = 0
    data.each_line do |line|
      if remove_count < 1 && /(\[.*?subs=.*?attributes.*?\])/ =~ line
        remove_count = 2 # both --- lines need to go
        result << line
      elsif remove_count > 0 && /^---[\-]+/ =~ line
        remove_count = remove_count - 1
      else
        result << line
      end
    end
  end
  result = result.gsub(/^---[\-]+.*?---[\-]+/m, "")
  result = result.gsub(/`.*?`/, "")
  return result
end

def inspect_attributes path
  file_defs = []
  file_uses = Set.new
  
  blocks_removed(IO.read(path), path).each_line do |line|
    # Find the blocks with attr substitutions
    if /subs=.*?attributes.*?\]/ =~ line
      @subs << line
    end
    
    # Record the attribute definitions in the line
    if /^:([A-Za-z\-]+):\s+/ =~ line
      @defs << $1
      file_defs << $1
    end

    # Record the attribute uses in the line
    file_uses.merge(line.scan(/{([A-Za-z\-]+)}/).flatten)
  end
  
  unless file_defs.empty?
    @files_with_defs[path] = file_defs
  end
  unless file_uses.empty?
    @uses[path] = file_uses
  end
end

inspect_attributes("./shared/attributes.asciidoc")

`find .repos -name "*.asciidoc"`.each_line do |path|
  inspect_attributes(path.strip())
end

#
# Command handling
#
subcommander.version = "1.0.0"
subcommander.desc = "This tool helps analyze the use of attributes within the asciidoc files."

subcommand :subs, "Finds attribute sub blocks." do |sc|
  sc.exec {
    puts @subs
  }
end

subcommand :files_with_defs, "Lists the files that define attributes." do |sc|
  sc.exec {
    @files_with_defs.each do |path, defs|
      puts "#{path} => #{defs.to_a}"
    end
  }
end

subcommand :find_missing, "Finds files that contain undefined attributes." do |sc|
  sc.exec {
    @uses.each do |path, uses|
      lacks_defs = uses.select {|u| !@defs.include?(u)}
      unless lacks_defs.empty?
        puts "#{path} => #{lacks_defs}"
      end
    end
  }
end

subcommander.go!
