class AlertMailer < ApplicationMailer
  def flight_alert(notification_id)
    @notification = Notification.find(notification_id)
    @alert = @notification.alert
    @flight_request = @alert.flight_request
    @recipient = @notification.recipient

    mail(
      to: @recipient.email,
      subject: @notification.subject,
      from: "alerts@presidentialflight.ae"
    )
  end
end
