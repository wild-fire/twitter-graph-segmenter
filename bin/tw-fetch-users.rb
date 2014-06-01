#!/usr/bin/env ruby

require 'rubygems'
require 'commander/import'
require 'active_support/core_ext/date/calculations'
require_relative '../lib/users_fetcher.rb'

program :version, '0.0.1'
program :description, 'This command fetches information from users falling into the interval passed as parameter'

command :fetch do |c|
  c.syntax = 'tw-fetch-users fetch first_user_id last_user_id path/to/output_users_file.tsv' 
  c.summary = 'This command fetches users information between the first_user_id and the last_user_id' 
  c.action do |args, options|

    if args.length < 3

      puts "We need the first and last user_id and the output file so we can store user id, screen name and signup date"

    else

      first_user_id, last_user_id, output_file = args
      first_user_id = first_user_id.to_i
      last_user_id = last_user_id.to_i

      needed_requests = ((last_user_id - first_user_id)/100.0).ceil

      needed_requests.times do |i|
        current_interval_start = first_user_id+100*i
        current_interval_end = current_interval_start + 99
        current_interval_end = last_user_id if current_interval_end > last_user_id

        user_ids = (current_interval_start..current_interval_end).to_a

        puts "[#{Time.now}] Fetching users from #{current_interval_start} to #{current_interval_end}"
        users = UsersFetcher.fetch user_ids

        output = File.open output_file, 'a'

        users.each do |user|
          output << "#{user.id}\t#{user.screen_name}\t#{user.created_at}\n"
        end

        output.close

      end
    end
  end
end
