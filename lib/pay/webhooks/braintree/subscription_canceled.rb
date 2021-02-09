module Pay
  module Webhooks
    module Braintree
      class SubscriptionCanceled
        def call(event)
          subscription = event.subscription
          return if subscription.nil?

          pay_subscription = Pay.subscription_model.find_by(processor: :braintree, processor_id: subscription.id)
          return unless pay_subscription.present?

          billable = pay_subscription.owner
          return if billable.nil?

          # User canceled or failed to make payments
          billable.update(braintree_subscription_id: nil)
        end
      end
    end
  end
end
