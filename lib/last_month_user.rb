require 'active_support/all'

# This class will attempt to search the last user signed up in Twitter for a given month.
# All this class needs is a user from each month and then it will search on twitter for a
# Twitter user wich was signed up that month
class LastMonthUser

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

    [this_month_user[:user_id] + (signups_rate * days_between_users/2), signups_rate]
  end

end
