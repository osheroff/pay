module Pay
  module Processors
    module Stripe
      class Subscription < Processors::Subscription
        def processor_subscription(options = {})
          ::Stripe::Subscription.retrieve(options.merge(id: subscription_id))
        end

        def cancel
          subscription = processor_subscription
          subscription.cancel_at_period_end = true
          subscription.save

          new_ends_at = on_trial? ? trial_ends_at : Time.at(subscription.current_period_end)
          update(ends_at: new_ends_at)
        rescue ::Stripe::StripeError => e
          raise Error, e.message
        end

        def cancel_now!
          processor_subscription.delete
          update(ends_at: Time.zone.now, status: :canceled)
        rescue ::Stripe::StripeError => e
          raise Error, e.message
        end

        def resume
          subscription = processor_subscription
          subscription.plan = processor_plan
          subscription.trial_end = on_trial? ? trial_ends_at.to_i : "now"
          subscription.cancel_at_period_end = false
          subscription.save
        rescue ::Stripe::StripeError => e
          raise Error, e.message
        end

        def swap(plan)
          subscription = processor_subscription
          subscription.cancel_at_period_end = false
          subscription.plan = plan
          subscription.proration_behavior = (prorate ? "create_prorations" : "none")
          subscription.trial_end = on_trial? ? trial_ends_at.to_i : "now"
          subscription.quantity = quantity if quantity?
          subscription.save
        rescue ::Stripe::StripeError => e
          raise Error, e.message
        end
      end
    end
  end
end
