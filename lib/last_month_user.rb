require 'yaml'
require 'twitter'
require 'active_support/all'

# This class will attempt to search the last user signed up in Twitter for a given month.
# All this class needs is a user from each month and then it will search on twitter for a
# Twitter user wich was signed up that month
class LastMonthUser

  # Singleton method for getting twitter client according to the configuration in the YML file
  def self.client
    @@client ||= Twitter::REST::Client.new do |config|
      yml_config = YAML.load_file( File.expand_path('../config/twitter.yml', File.dirname(__FILE__)) )['twitter'].symbolize_keys
      config.consumer_key        = yml_config[:consumer_key]
      config.consumer_secret     = yml_config[:consumer_secret]
      config.access_token        = yml_config[:access_token]
      config.access_token_secret = yml_config[:access_token_secret]
    end
  end

  # This method implements the actual search. It receives two users, one for each month.
  # Those users are just hashes with a user_id and a date
  # (i.e. { user_id: 20, signup_date: Date.parse('2006/03/21')})
  def self.find this_month_user, next_month_user



  end

  # This method give us an initial guess of the last user id signed up in date_guess,
  # along with the rate of users signed up on twitter each day.
  # It receives two hashes with the useer id and signup date for two users (see find for the hash format)
  # and the date the desired user signed up
  # THis method does not perform any twitter API call. It just guesses it from the ids and dates we give.
  def self.initial_user_id_guess this_month_user, next_month_user, date_guess

    days_between_users = next_month_user[:signup_date] - this_month_user[:signup_date]
    signups_rate = (next_month_user[:user_id] - this_month_user[:user_id]) / days_between_users

    [this_month_user[:user_id] + (signups_rate * (date_guess - this_month_user[:signup_date])), signups_rate]
  end

end
