#!/usr/bin/env ruby

require 'fileutils'
require 'pry'


def extract_from_file(filename)
  reading = false
  lines = []
  indentation = nil
  File.readlines(filename).each do |line|
    if !reading
      if line =~ /-- ?START LIB/i
        reading = true
      end
      next
    end
    return lines if line =~ /^-- ?END LIB/i
    if !indentation && line =~ /^([ ]+)[^ ]/
      indentation = $1.size
    end
    if indentation
      line = line.gsub(/^[ ]+/) {|s| ' '*(s.size/indentation) }
    end
    lines << line
  end
  lines
end

def compile_file(filename)
  tmp = File.open('out.tmp','w')
  inserting = false
  has_inserted = false
  File.readlines(filename).each do |line|
    if !inserting
      tmp << line
      if line =~ /-- ?START EXT ([^ ]+)\w*$/i
        has_inserted = true
        extract_from_file($1.strip).each {|l| tmp << l }
        inserting = true
      end
    elsif line =~ /-- ?END EXT/i
      tmp << line
      inserting = false
    end
  end
  tmp.close
  if has_inserted
    FileUtils.mv('out.tmp',filename)
  else
    FileUtils.rm('out.tmp')
  end
end

Dir["./*"].each do |filename|
  compile_file(filename) if File.file?(filename) && !(filename =~ /\.png$/)
end



