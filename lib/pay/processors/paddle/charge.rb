module Pay
  module Processors
    module Paddle
      class Charge < Processors::Charge
        def processor_charge
          return unless owner.subscription
          payments = PaddlePay::Subscription::Payment.list({subscription_id: owner.subscription.processor_id})
          charges = payments.select { |p| p[:id].to_s == processor_id }
          charges.try(:first)
        rescue ::PaddlePay::PaddlePayError => e
          raise Error, e.message
        end

        def refund!(amount_to_refund)
          return unless owner.subscription
          payments = PaddlePay::Subscription::Payment.list({subscription_id: owner.subscription.processor_id, is_paid: 1})
          if payments.count > 0
            PaddlePay::Subscription::Payment.refund(payments.last[:id], {amount: amount_to_refund})
            update(amount_refunded: amount_to_refund)
          else
            raise Error, "Payment not found"
          end
        rescue ::PaddlePay::PaddlePayError => e
          raise Error, e.message
        end
      end
    end
  end
end
