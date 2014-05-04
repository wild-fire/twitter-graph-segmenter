#!/usr/bin/env ruby

require 'rubygems'
require 'commander/import'
require 'lib/week_segmenter'
require 'vcr'
require 'debugger'

VCR.configure do |c|
  c.cassette_library_dir = 'data/vcr'
  c.hook_into :webmock # or :fakeweb

  yml_config = YAML.load_file( File.expand_path('../config/twitter.yml', File.dirname(__FILE__)) )['twitter']
  c.filter_sensitive_data('<CONSUMER KEY>') { yml_config['consumer_key'] }
  c.filter_sensitive_data('<ACCESS TOKEN>') { yml_config['access_token'] }

  # Don't playback transient errors
  c.before_playback do |interaction|
    interaction.ignore! if interaction.request.uri.include? '/1.1/application/rate_limit_status.json?resources=users'
    interaction.ignore! if interaction.response.status.code >= 400 && interaction.response.status.code != 404
  end

  c.default_cassette_options = { :record => :new_episodes }
  c.allow_http_connections_when_no_cassette = true
end

program :version, '0.0.1'
program :description, 'This program segments a period of times  '

command :find do |c|
  c.syntax = 'tw-week-user find username1 username2'
  c.summary = 'Find last users of the week between the two users'
  c.description = 'This command takes two users and their signup dates and find the lasr user of the week for each week between the two dates'
  c.example 'Find all the users between "pud" and "goldman" users' , 'find pud goldman'
  c.action do |args, options|
    rate_limit_info = WeekSegmenter.rate_limit_info
    puts "Remaining #{rate_limit_info[:remaining]} of #{rate_limit_info[:limit]} until #{Time.at rate_limit_info[:reset]}"
    VCR.use_cassette('users_profiles') do

      first_user = WeekSegmenter.client.user args[0]
      last_user = WeekSegmenter.client.user args[1]

      users = WeekSegmenter.find({user_id: first_user.id, signup_date: first_user.created_at.to_date}, {user_id: last_user.id, signup_date: last_user.created_at.to_date})

      users.each do |u|
        puts "#{u.screen_name} signed up at #{u.created_at}"
      end
    end
    rate_limit_info = WeekSegmenter.rate_limit_info
    puts "Remaining #{rate_limit_info[:remaining]} of #{rate_limit_info[:limit]} until #{Time.at rate_limit_info[:reset]}"
  end
end


command :file do |c|
  c.syntax = 'tw-week-user file path/to/file path/to/output/file [path/to/input/beacons/file] [path/to/output/beacons/file]'
  c.summary = 'Segments a period of time using users extracted from a TSV file'
  c.description = 'This command takes a file in TSV format with two columns, the user id on twitter and the creation date, ordered by the creation date (sooner first). Then finds the last user of every weeb from the first creation date to the last one'
  c.action do |args, options|
    rate_limit_info = WeekSegmenter.rate_limit_info
    puts "Remaining #{rate_limit_info[:remaining]} of #{rate_limit_info[:limit]} until #{Time.at rate_limit_info[:reset]}"

    tsv_file = File.open args[0]
    previous_user = nil
    next_user = nil

    if args.length > 2
      beacons_file = File.open args[2]
      beacons = []
      beacons_file.each_line do |l|
        user_id, signup_date = l.split("\t")
        beacons << { user_id: user_id.to_i, signup_date: DateTime.parse(signup_date) }
      end
      WeekSegmenter.beacons = beacons.dup
    end

    VCR.use_cassette('users_profiles') do
      tsv_file.each_line do |l|
        user_id, signup_date = l.split("\t")
        previous_user = next_user
        next_user = { user_id: user_id.to_i, signup_date: Date.parse(signup_date) }

        unless previous_user.nil?
          results = WeekSegmenter.find(previous_user, next_user) do |user|
            output_file = File.open args[1], 'a'
            output_file << "#{user.id}\t#{user.screen_name}\t#{user.created_at}\n"
            output_file.close

            if args.length > 3
              beacons_output_file = File.open args[3], 'a'
              WeekSegmenter.beacons.each do |b|
                beacons_output_file << "#{b[:user_id]}\t#{b[:signup_date]}\n"
              end
            end

          end

          results.each do |r|
            puts "#{r.screen_name} signed up at #{r.created_at}"
          end

          # We reset the beacons, or we're gonna have too much in memory
          WeekSegmenter.beacons = beacons.dup
        end
      end

    end
    rate_limit_info = WeekSegmenter.rate_limit_info
    puts "Remaining #{rate_limit_info[:remaining]} of #{rate_limit_info[:limit]} until #{Time.at rate_limit_info[:reset]}"
  end
end
