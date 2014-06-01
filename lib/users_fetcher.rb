require 'yaml'
require 'twitter'

# This class will encapsulate the required code to access the Twitter gem and retrieveing information for a bulk of Twitter users
class UsersFetcher
  
  @@remaining_calls = 0

  def self.log message
    puts "[User Fetcher] #{message}"
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
    rate_info = self.client.get '/1.1/application/rate_limit_status.json?resources=users'
    rate_info.body[:resources][:users][:"/users/lookup"]
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

  def self.fetch user_ids
    sleep_until_rate_limit
    self.client.users user_ids
  end
end
