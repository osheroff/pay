module Pay
  module Processors
    module Stripe
      class Charge < Processors::Charge
        def processor_charge
          ::Stripe::Charge.retrieve(processor_id)
        rescue ::Stripe::StripeError => e
          raise Error, e.message
        end

        def refund!(amount)
          ::Stripe::Refund.create(charge: processor_id, amount: amount)
          update(amount_refunded: amount_refunded + amount)
        rescue ::Stripe::StripeError => e
          raise Error, e.message
        end
      end
    end
  end
end
