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
program :description, 'This program takes two twitter users, with their signup date and find the las user of each week between the dates'

command :find do |c|
  c.syntax = 'tw-week-user find [options]'
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

