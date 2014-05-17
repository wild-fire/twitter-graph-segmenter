#!/usr/bin/env ruby

require 'rubygems'
require 'commander/import'
require 'active_support/core_ext/date/calculations'

program :version, '0.0.1'
program :description, 'This program segments a graph of twitter relationships according to a input file of users and dates of sign up'

command :segment do |c|
  c.syntax = 'tw-segment-graph segment graph.tsv signup_dates.tsv output_folder [end_of_week]'
  c.summary = 'Segments the graph in the graph.tsv file according to the dates in the signup_dates.tsv file'
  c.description = "This command takes two TSV input files.\n" +
    "The first one contains a Twitter user graph with the syntax 'followee\\tfollower' sorted by the followee id.\n" +
    "The second one contains user signup dates with the format 'user_id\\tsignup_date'.\n" +
    "One file for each date will be creted containing the relationships where both users were already in twitter for that date.\n" +
    "If end of week is enabled then files will be named by the last day of the week, not by the signup date."
  c.action do |args, options|
    if args.length < 3
      puts "You missed some argument"
    else

      output_folder = args[2]
      output_folder += '/' unless output_folder.end_with? '/'

      users_file = File.open args[1]

      users_file.each_line do |line|

        user_id, username, signup_date = line.split("\t")
        signup_date = Date.parse signup_date
        signup_date = signup_date.end_of_week if args.count >= 4

        puts "#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}: Segmenting until #{signup_date.strftime('%Y-%m-%d')} (#{username})"

        cmd = "awk -F\"\t\" '{OFS=\"\\t\"} $2 <= #{user_id} && $1 <= #{user_id}{print $1,$2}; $1 > #{user_id} {exit}' #{args[0]} | gzip > #{output_folder}/#{signup_date.strftime('%Y-%m-%d')}.gz"
        puts " >> #{cmd}"
        system( cmd )
      end
    end
  end
end
