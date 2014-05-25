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
  # WARNING: client must not be stored in a variable and it always must be used directly: WeekSegmenter.client.user(...)
  # Otherwise, the counter method for controlling the rate limit would be useless
  def self.client
    @@client ||= Twitter::REST::Client.new do |config|
      yml_config = YAML.load_file( File.expand_path('../config/twitter.yml', File.dirname(__FILE__)) )['twitter'].symbolize_keys
      config.consumer_key        = yml_config[:consumer_key]
      config.consumer_secret     = yml_config[:consumer_secret]
      config.access_token        = yml_config[:access_token]
      config.access_token_secret = yml_config[:access_token_secret]
    end
    # Since we can't control when the API is called we decrement the counter here, hoping that when the client is called only 1 API call is made
    @@remaining_calls -= 1
    @@client
  end

  # This method obtains the rate limit info for the users API
  def self.rate_limit_info
    rate_info = WeekSegmenter.client.get '/1.1/application/rate_limit_status.json?resources=users'
    rate_info.body[:resources][:users][:"/users/show/:id"]
  end

  # This method uses the information returned by rate_limit_info to make the whole script sleep until we have enough rate limit again
  def self.sleep_until_rate_limit
    # Rate limit info calls also have a rate limit, so we use a counter to limit the amount of API calls made
    # When this counter is less than 5, we make the check
    if @@remaining_calls < 5
      # We get the rate limit info
      rate_info = rate_limit_info
      # Since we are using a counter and not perform this check with every API call we must give some space or we can fall into the rate limit without noticing
      # Our space are 20 API calls. If we have less than 20 we stop
      if rate_info[:remaining] < 20
        # And now here we sleep until the reset time for the rate limit
        log "Now I'm going to sleep until I have enough rate (#{Time.at rate_info[:reset]} - #{Time.at(rate_info[:reset]) - Time.now} seconds)"
        sleep(Time.at(rate_info[:reset]) - Time.now)
      else
        log "Remaining calls #{rate_info[:remaining]} until #{Time.at rate_info[:reset]}"
      end
      # We reset the counter now
      @@remaining_calls = [20, rate_info[:remaining]/2].min
    end
  end

  # This method implements the actual search. It receives two users, just hashes with a user_id and a date
  # (i.e. { user_id: 20, signup_date: Date.parse('2006/03/21')})
  # Then it will try to find the last user signed up on each week between the sign up date from the two users
  def self.find first_user, last_user

    # We try to get last user for the first week
    end_of_week = first_user[:signup_date].to_datetime.end_of_week

    # Now we get the first guess and the users' signup rate
    guess, global_signups_rate = initial_user_id_guess first_user, last_user, end_of_week

    week = 0
    results = []
    # While we don't go further the last user signup date...
    while (end_of_week <= last_user[:signup_date]) do

      week += 1

      log "Searching user for week ending #{end_of_week} with #{global_signups_rate} new users per day"

      # Here we are going to store the result
      user = nil

      # We are going to implement a little binary search method
      # This variable will control which side of the end of the week we are in
      past_week = false
      # signups_rate will be our increment variable so we are going to decrement it until we find the last user of the week
      signups_rate = global_signups_rate
      while signups_rate >= 1

        guess = guess.to_i
        # We get the information about the currently guessed user
        begin
          log "-- Trying #{guess}"
          user = nil
          # We try with our local cache "Have we asked about this user before?"
          if @@tried_users.has_key? guess
            user = @@tried_users[guess]
            # If we asked but the user was nil (didn't exist) then we keep trying
            while user.nil? && @@tried_users.has_key?(guess+signups_rate)
              guess += past_week ? signups_rate : -signups_rate
              user = @@tried_users[guess]
            end
          end

          # If there was no user in our cache we ask to the client
          if user.nil?
            sleep_until_rate_limit
            user = client.user(guess)
            # And now we save itin the cache and in the beacons array
            @@tried_users[guess] = user
            @@beacons << { user_id: user.id, signup_date: user.created_at }
          end

          log "-- Rate #{signups_rate} - User #{guess} (#{user.screen_name}) created at: #{user.created_at}"

          case
            # If we are still in the past week, then we are going to find another future user
            when past_week && (user.created_at <= end_of_week)
              guess += signups_rate
            # If we are in the next week, and the user is from the next week, then we get a previous user
            when !past_week && (user.created_at > end_of_week)
              guess -= signups_rate
            # If we are in the past week BUT the user is from the next week, then we cut signups rate
            # in half and search in the oposite direction
            when past_week && (user.created_at > end_of_week)
              # WAIT!! if the user is in the "next" side we can't cut the signups rate to 0 or
              # it would mean that the last user of a week is in the next week (in fact, the first user of the next one)
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
        # We control deleted and private users
        rescue Twitter::Error::NotFound, Twitter::Error::Forbidden
          # We store in the cache that the user doesn't exist
          @@tried_users[guess] = nil

          # And now move forward (or backwards, depending on the week)
          guess += past_week ? signups_rate : -signups_rate

          # If we get lower than one of our beacons from the previous week then turn around and search again
          beacon = if !past_week
            @@beacons.detect{|b| b[:user_id] > guess && b[:signup_date] <= end_of_week }
          # If we get further than one of our beacons from the next week, then turn around and search again, again
          else
            @@beacons.detect{|b| b[:user_id] < guess && b[:signup_date] > end_of_week }
          end

          # If we have a beacon then we can use it
          unless beacon.nil?
            log "-- User not found but beacon #{beacon[:user_id]} created at #{beacon[:signup_date] } found"
            # Our guess will be the beacon id, so we fill guess and past_week as they should
            guess = beacon[:user_id]
            past_week = beacon[:signup_date] < end_of_week
            # We cut signups_rate in half (after all, we have reached a limit)
            signups_rate = (signups_rate/2).ceil
            # WAIT!! if the user is in the "next" side we can't cut the signups rate to 0 or
              # it would mean that the last user of a week is in fact the first user of the next one
            signups_rate = 1 if (signups_rate == 0) && !past_week
          end
        # Sometimes twitter returns a Timeout
        rescue Twitter::Error::RequestTimeout
        end
      end

      # Here we already have our last week user, so we prepare our next week
      guess += global_signups_rate * 7
      end_of_week += 7.days

      # If a block was given then we yield it
      yield user if block_given?

      # And store this last week user as a result
      results << user

    end

    results

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
