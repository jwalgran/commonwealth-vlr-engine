module CommonwealthVlrEngine

  class Notifier < ActionMailer::Base

    def feedback(details)

      @message = details[:message]
      @email = details[:email]
      @name = details[:name]
      @recipient = route_email(details[:topic])

      mail(:to => @recipient,
           :from => t('blacklight.email.record_mailer.name') + ' <' + t('blacklight.email.record_mailer.email') + '>',
           :subject => t('blacklight.feedback.text.subject'))

    end

    private

    def route_email(topic)
      if topic == t('blacklight.feedback.form.topic.options.repro')
        recipient_email = CONTACT_EMAILS['image_requests']
      else
        recipient_email = CONTACT_EMAILS['site_admin']
      end
      recipient_email
    end

  end

end

