#TODO: Remove this file

module Pay
  module Stripe
    module Billable
      extend ActiveSupport::Concern

      included do
        scope :stripe, -> { where(processor: :stripe) }
      end

      def stripe_subscription(subscription_id, options = {})
        ::Stripe::Subscription.retrieve(options.merge(id: subscription_id))
      end

      def stripe_invoice!(options = {})
        return unless processor_id?
      end

      def stripe_upcoming_invoice
      end

      # Used by webhooks when the customer or source changes
      def sync_card_from_stripe
        stripe_cust = stripe_customer
        default_payment_method_id = stripe_cust.invoice_settings.default_payment_method

        if default_payment_method_id.present?
          payment_method = ::Stripe::PaymentMethod.retrieve(default_payment_method_id)
          update(
            card_type: payment_method.card.brand,
            card_last4: payment_method.card.last4,
            card_exp_month: payment_method.card.exp_month,
            card_exp_year: payment_method.card.exp_year
          )

        # Customer has no default payment method
        else
          update(card_type: nil, card_last4: nil)
        end
      end

      private



      def stripe_trial_end_date(stripe_sub)
        # Times in Stripe are returned in UTC
        stripe_sub.trial_end.present? ? Time.at(stripe_sub.trial_end) : nil
      end

      # Save the card to the database as the user's current card
      def update_stripe_card_on_file(card)
        update!(
          card_type: card.brand.capitalize,
          card_last4: card.last4,
          card_exp_month: card.exp_month,
          card_exp_year: card.exp_year
        )

        self.card_token = nil
      end
    end
  end
end
