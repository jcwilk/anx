#!/usr/bin/env ruby

require 'fileutils'
require 'pry'

def strip_whitespace_and_comments(line)
  line.gsub(/^[ ]+/,'').gsub(/--.*$/,'')
end


$skip_lines = 6
def compile_file(filename)
  tmp = File.open('out.tmp','w')
  inserting = false
  has_inserted = false
  File.readlines(filename).each do |line|
    if $skip_lines > 0
      $skip_lines-=1
    end

    if $skip_lines > 0 || line =~ /-- ?START EXT ([^ ]+)\w*$/i || line =~ /-- ?END EXT/i
      tmp << line
    else
      line = strip_whitespace_and_comments(line)
      if !line.strip.empty?
        tmp << line
      end
    end
  end
  tmp.close
  FileUtils.mv('out.tmp','publish.p8')
end

# Dir["./*"].each do |filename|
#   compile_file(filename) if File.file?(filename) && !(filename =~ /\.png$/)
# end

compile_file('anx.p8')

