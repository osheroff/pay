module Pay
  module Webhooks
    module Braintree
      class SubscriptionChargedSuccessfully
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          pay_subscription = Pay.subscription_model.find_by(processor: :braintree, processor_id: subscription.id)
          return unless pay_subscription.present?

          billable = pay_subscription.owner
          charge = billable.payment_processor.save_transaction(subscription.transactions.first)

          if Pay.send_emails
            Pay::UserMailer.with(billable: billable, charge: charge).receipt.deliver_later
          end
        end
      end
    end
  end
end
