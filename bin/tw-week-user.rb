#!/usr/bin/env ruby

require 'rubygems'
require 'commander/import'
require 'lib/week_segmenter'
require 'vcr'
require 'debugger'

# We configure VCR
VCR.configure do |c|
  c.cassette_library_dir = 'data/vcr'
  c.hook_into :webmock # or :fakeweb

  # We hide the tokens from VCR
  yml_config = YAML.load_file( File.expand_path('../config/twitter.yml', File.dirname(__FILE__)) )['twitter']
  c.filter_sensitive_data('<CONSUMER KEY>') { yml_config['consumer_key'] }
  c.filter_sensitive_data('<ACCESS TOKEN>') { yml_config['access_token'] }

  # Don't playback errors and rate limits
  c.before_playback do |interaction|
    interaction.ignore! if interaction.request.uri.include? '/1.1/application/rate_limit_status.json?resources=users'
    interaction.ignore! if interaction.response.status.code >= 400 && interaction.response.status.code != 404
  end

  c.default_cassette_options = { :record => :new_episodes }
  c.allow_http_connections_when_no_cassette = true
end

program :version, '0.0.1'
program :description, 'This program Find Twitter last users of the week between two user signup dates'

command :find do |c|
  c.syntax = 'tw-week-user find username1 username2 [path/to/input/beacons/file]'
  c.summary = 'Find last users of the week between the two users'
  c.description = 'This command takes two users and their signup dates and find the lasr user of the week for each week between the two dates'
  c.example 'Find all the users between "pud" and "goldman" users' , 'find pud goldman'
  c.example 'Find all the users between "pud" and "goldman" users using beacons' , 'find pud goldman data/beacons.tsv'
  c.action do |args, options|

    # Just to know our rate limit status we print it out
    rate_limit_info = WeekSegmenter.rate_limit_info
    puts "Remaining #{rate_limit_info[:remaining]} of #{rate_limit_info[:limit]} until #{Time.at rate_limit_info[:reset]}"


    VCR.use_cassette('users_profiles') do

      # Now we get both users
      first_user = WeekSegmenter.client.user args[0]
      last_user = WeekSegmenter.client.user args[1]

      # And open the beacons file
      if args.length > 2
        beacons_file = File.open args[2]
        beacons = []
        beacons_file.each_line do |l|
          user_id, signup_date = l.split("\t")
          beacons << { user_id: user_id.to_i, signup_date: DateTime.parse(signup_date) }
        end
        WeekSegmenter.beacons = beacons.dup
      end

      # And now find the last users of the week
      users = WeekSegmenter.find({user_id: first_user.id, signup_date: first_user.created_at.to_date}, {user_id: last_user.id, signup_date: last_user.created_at.to_date})

      users.each do |u|
        puts "#{u.screen_name} signed up at #{u.created_at}"
      end
    end

    # Just to know our rate limit status we print it out
    rate_limit_info = WeekSegmenter.rate_limit_info
    puts "Remaining #{rate_limit_info[:remaining]} of #{rate_limit_info[:limit]} until #{Time.at rate_limit_info[:reset]}"
  end
end


command :file do |c|
  c.syntax = 'tw-week-user file path/to/file path/to/output/file [path/to/input/beacons/file] [path/to/output/beacons/file]'
  c.summary = 'Segments a period of time using users extracted from a TSV file'
  c.description = 'This command takes a file in TSV format with two columns, the user id on twitter and the creation date, ordered by the creation date (sooner first). Then finds the last user of every weeb from the first creation date to the last one'
  c.action do |args, options|

    # Just to know our rate limit status we print it out
    rate_limit_info = WeekSegmenter.rate_limit_info
    puts "Remaining #{rate_limit_info[:remaining]} of #{rate_limit_info[:limit]} until #{Time.at rate_limit_info[:reset]}"

    # We open the The users input file
    tsv_file = File.open args[0]
    previous_user = nil
    next_user = nil

    # And now the beacons file
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
      # Now, for each line of the file
      tsv_file.each_line do |l|
        # We get the user id and signup date
        user_id, signup_date = l.split("\t")
        # We store the previous user and create the new one
        previous_user = next_user
        next_user = { user_id: user_id.to_i, signup_date: Date.parse(signup_date) }

        # If there was a previous user (it's not the first file line)
        unless previous_user.nil?
          # We find the last users of the week
          results = WeekSegmenter.find(previous_user, next_user) do |user|
            # For each week we save the user into the output file
            output_file = File.open args[1], 'a'
            output_file << "#{user.id}\t#{user.screen_name}\t#{user.created_at}\n"
            output_file.close

            # And store the beacons
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
