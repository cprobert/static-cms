#!/usr/bin/env ruby
# This software code is made available "AS IS" without warranties of any
# kind.  You may copy, display, modify and redistribute the software
# code either by itself or as incorporated into your code; provided that
# you do not remove any proprietary notices.  Your use of this software
# code is at your own risk and you waive any claim against the author
# with respect to your use of this software code.
# (c) 2007 Static-CMS

require 'optparse'
require 'fileutils'
require 'scms'

options = {}
optparse = OptionParser.new do|opts|
  # Set a banner, displayed at the top
  # of the help screen.
  opts.banner = "Usage: scms [options]"
 
  # Define the options, and what they do
  opts.on('-w', '--website WEBSITE', "Website directory (full path)") do |w|
    options[:website] = w
  end
  
  opts.on('-o', '--output BuildDIR', "Website build dir (full path)") do |o|
    options[:pub] = o
  end
 
  options[:action] = "build"
   opts.on( '-a', '--action ACTION', 'Build, Deploy, Create or Clean' ) do|a|
     options[:action] = a
  end
   
  options[:mode] = "pub"
  opts.on( '-m', '--mode MODE', 'CMS or Publish' ) do|m|
     options[:mode] = m
  end
   
  options[:html] = "true"
  opts.on( '-f', '--html HTML', 'true or false' ) do|h|
     options[:html] = h
  end

  options[:verbose] = false
  opts.on( '-v', '--verbose', 'Output more information' ) do
     options[:verbose] = true
  end
  # This displays the help screen, all programs are
  # assumed to have this option.
   opts.on( '-h', '--help', 'Display this help screen' ) do
     puts opts
     exit
   end
end
optparse.parse!
#Now raise an exception if we have not found a website option
if options[:website].nil?
    puts "Please specify a website directory, e.g."
    puts "staticcms -w ~/websites/mystaticwebsite"
    raise OptionParser::MissingArgument 
end

$stdout.sync = true
root_folder = File.expand_path("../", File.dirname(__FILE__))
@pub = File.join("#{options[:website]}/compiled")
unless options[:pub].nil?
    @pub = options[:pub]
end

Folders = {
  :root => root_folder,
  :website => File.join(options[:website]),
  :pub => (ENV["SCMS_PUBLISH_FOLDER"] or @pub),
  :assets => (ENV["SCMS_STATICCMS_FOLDER"] or File.join(root_folder, "assets")),
  :config => (ENV["SCMS_CONFIG_FOLDER"] or File.join(options[:website]))
}

if options[:action] == "create"
    if Dir.exists? Folders[:website]
        throw "Website already exists!!!"
    else
        puts "Making website: #{Folders[:website]}"
        FileUtils.mkdir_p Folders[:website]
        Dir.chdir(File.join(Folders[:assets], "blank-template")) do
            files = Dir.glob('*')
            FileUtils.cp_r files, Folders[:website]
        end
    end
    exit
end

if options[:action] == "createapp"
    if Dir.exists? Folders[:website]
        throw "App already exists!!!"
    else
        puts "Making Air app: #{Folders[:website]}"
        FileUtils.mkdir_p Folders[:website]
        Dir.chdir(File.join(Folders[:assets], "blank-app-template")) do
            files = Dir.glob('*')
            FileUtils.cp_r files, Folders[:website]
        end
    end
    exit
end

raise "No website in folder #{Folders[:website]}" if !File::directory?(Folders[:website])

#puts "System root folder = #{Folders[:root]}"
#puts "Website folder = #{Folders[:website]}"
#puts "Pub dir = #{Folders[:pub]}"
#puts "Config dir = #{Folders[:config]}"
#puts "Mode = #{options[:mode]}"

##Set globals
$website = Folders[:website]
$html = (ENV["SCMS_HTML_OUT"] or "false")

deployDir = StaticCMS.build(Folders[:pub], Folders[:config], options[:mode])

if options[:action] == "crunch"
    StaticCMS.crunch(deployDir)
end
#puts "deployDir = #{deployDir}"
if options[:action] == "deploy"
    StaticCMS.crunch(deployDir)
    StaticCMS.deploy(deployDir, Folders[:config])
end