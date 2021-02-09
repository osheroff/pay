module Pay
  module Webhooks
    module Stripe
      class PaymentMethodUpdated
        def call(event)
          object = event.data.object
          billable = Pay.find_billable(processor: :stripe, processor_id: object.customer)

          # Couldn't find user, we can skip
          return unless billable.present?

          billable.sync_card_from_stripe
        end
      end
    end
  end
end
