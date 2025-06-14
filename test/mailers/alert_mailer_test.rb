require "test_helper"

class AlertMailerTest < ActionMailer::TestCase
  test "flight_alert" do
    mail = AlertMailer.flight_alert
    assert_equal "Flight alert", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
