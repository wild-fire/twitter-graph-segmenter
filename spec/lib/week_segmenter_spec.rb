require 'spec_helper'
require 'lib/week_segmenter'


describe WeekSegmenter, vcr: true do
  context 'when guessing the id without any call to Twitter API' do

    # We have two users (100 and 300) signed up with 20 days of difference,
    # so we can guess that 10 users signed up each day and that user 150
    # signed up in the 5th day

    let(:first_user) { { user_id: 100, signup_date: Date.today } }
    let(:second_user) { { user_id: 300, signup_date: (Date.today + 20.days) } }

    before do
      @user_id, @user_rate = WeekSegmenter.initial_user_id_guess first_user, second_user, Date.today + 5.days
    end

    it "should find user 150 as the last signed up 3 days from now" do
      @user_id.should eq 150
    end

    it "should find that 10 users signed up each day" do
      @user_rate.should eq 10
    end

  end

  context 'when accessing twitter' do

    it "should fetch users" do
      WeekSegmenter.client.user(20).screen_name.should eq 'ev'
    end

  end

end
