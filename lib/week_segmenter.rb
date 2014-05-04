require 'yaml'
require 'twitter'
require 'active_support/all'

# This class will attempt to split a period of time between two signed up users in weeks
# For every week between the two signup dates it will find each last signed up user
class WeekSegmenter

  cattr_accessor :beacons
  @@beacons = []
  @@tried_users = {}
  @@remaining_calls = 0

  def self.log message
    puts "[Week Segmenter] #{message}"
  end

  # Singleton method for getting twitter client according to the configuration in the YML file
  def self.client
    @@client ||= Twitter::REST::Client.new do |config|
      yml_config = YAML.load_file( File.expand_path('../config/twitter.yml', File.dirname(__FILE__)) )['twitter'].symbolize_keys
      config.consumer_key        = yml_config[:consumer_key]
      config.consumer_secret     = yml_config[:consumer_secret]
      config.access_token        = yml_config[:access_token]
      config.access_token_secret = yml_config[:access_token_secret]
    end
    @@remaining_calls -= 1
    @@client
  end

  def self.rate_limit_info
    rate_info = WeekSegmenter.client.get '/1.1/application/rate_limit_status.json?resources=users'
    rate_info.body[:resources][:users][:"/users/show/:id"]
  end

  def self.sleep_until_rate_limit
    if @@remaining_calls < 5
      rate_info = rate_limit_info
      if rate_info[:remaining] < 20
        log "Now I'm going to sleep until I have enough rate (#{rate_info[:reset]} - #{Time.at(rate_info[:reset]) - Time.now} seconds)"
        sleep(Time.at(rate_info[:reset]) - Time.now)
      else
        log "Remaining calls #{rate_info[:remaining]} until #{Time.at rate_info[:reset]}"
      end
      @@remaining_calls = [20, rate_info[:remaining]/2].min
    end
  end

  # This method implements the actual search. It receives two users, just hashes with a user_id and a date
  # (i.e. { user_id: 20, signup_date: Date.parse('2006/03/21')})
  # Then it will try to find the last user signed up on each week between the sign up date from the two users
  def self.find first_user, last_user

    # count the weeks between the users
    weeks_between_users = (last_user[:signup_date] - first_user[:signup_date])/7
    weeks_between_users = weeks_between_users.floor

    # If there's no weeks between the users, we return
    return [] unless weeks_between_users > 1

    # We try to get last user for the first week
    end_of_week = first_user[:signup_date].to_datetime.end_of_week

    # Now we get the first guess and the users' signup rate
    guess, global_signups_rate = initial_user_id_guess first_user, last_user, end_of_week

    # From 1 to the numbers of week
    (1..weeks_between_users).map do |week|

      log "Searching user for week ending #{end_of_week} with #{global_signups_rate} new users per day"

      # If we are not in the firest week we adjust the guess based on
      # the last user of the previous week. This way, if our initial guess was too wrong
      # we will now work with a more accurated guess
      unless week == 1
        guess += global_signups_rate * 7
        end_of_week += 7.days
      end

      # Here we are going to store the result
      user = nil

      # We are going to implement a little binary search method
      # This variable will control which side of the end of the week are we
      past_week = true
      # signups_rate will be our increment variable so we are going to decrement it until we find the last user of the week
      signups_rate = global_signups_rate
      while signups_rate >= 1

        guess = guess.to_i
        # We get the information about the currently guessed user
        begin
          log "-- Trying #{guess}"
          user = nil
          if @@tried_users.has_key? guess
            user = @@tried_users[guess]
            while user.nil? && @@tried_users.has_key?(guess+1)
              guess += past_week ? 1 : -1
              user = @@tried_users[guess]
            end
          end

          if user.nil?
            sleep_until_rate_limit
            user = client.user(guess)
            @@tried_users[guess] = user
            @@beacons << { user_id: user.id, signup_date: user.created_at }
          end

          log "-- Rate #{signups_rate} - User #{guess} (#{user.screen_name}) created at: #{user.created_at}"

          case
            # If we are still in the past week, then we are going to find another future user
            when past_week && (user.created_at <= end_of_week)
              guess += signups_rate
            # If we are in the next week, and the user is from the next week, then we get a past user
            when !past_week && (user.created_at > end_of_week)
              guess -= signups_rate
            # If we are in the past week BUT the user is from the next week, then we cut signups rate
            # in half and search in the oposite direction
            when past_week && (user.created_at > end_of_week)
              # WAIT!! if the user is in the "next" side we can't cut the signups rate to 0 or
              # it would mean that the last user of a week is in fact the first user of the next one
              signups_rate = (signups_rate/2).ceil unless signups_rate == 1
              past_week = false
              guess -= signups_rate
            # If we are in the next week BUT the user is from the past one, then we cut signups rate
            # in half and search in the oposite direction
            when !past_week && (user.created_at <= end_of_week)
              signups_rate = (signups_rate/2).ceil
              past_week = true
              guess += signups_rate
          end
        rescue Twitter::Error::NotFound, Twitter::Error::Forbidden
          @@tried_users[guess] = nil
          guess += past_week ? signups_rate : -signups_rate
          # If we get lower than one of our beacons from the previous week then turn around and search again
          beacon = if !past_week
            @@beacons.detect{|b| b[:user_id] > guess && b[:signup_date] <= end_of_week }
          # If we get further than one of our beacons from the next week, then turn around and search again, again
          else
            @@beacons.detect{|b| b[:user_id] < guess && b[:signup_date] > end_of_week }
          end
          unless beacon.nil?
            log "-- User not found but beacon #{beacon[:user_id]} created at #{beacon[:signup_date] } found"
            guess = beacon[:user_id]
          end
        rescue Twitter::Error::RequestTimeout
        end
      end

      user

    end

  end

  # This method give us an initial guess of the last user id signed up in date_guess,
  # along with the rate of users signed up on twitter each day.
  # It receives two hashes with the useer id and signup date for two users (see find for the hash format)
  # and the date the desired user signed up
  # THis method does not perform any twitter API call. It just guesses it from the ids and dates we give.
  def self.initial_user_id_guess first_user, last_user, date_guess

    days_between_users = last_user[:signup_date] - first_user[:signup_date]
    signups_rate = (last_user[:user_id] - first_user[:user_id]) / days_between_users
    signups_rate = signups_rate.ceil

    [first_user[:user_id] + (signups_rate * (date_guess - first_user[:signup_date])), signups_rate]
  end

end
