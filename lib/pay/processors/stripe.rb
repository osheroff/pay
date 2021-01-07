module Pay
  module Processors
    class Stripe < Base
      def customer
        if processor_id?
          ::Stripe::Customer.retrieve(processor_id)
        else
          create_customer(name: customer_name, email: email)
        end
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end

      def create_setup_intent
        ::Stripe::SetupIntent.create(customer: processor_id, usage: :off_session)
      end

      def charge(amount, options = {})
        args = {
          amount: amount,
          confirm: true,
          confirmation_method: :automatic,
          currency: "usd",
          customer: customer.id,
          payment_method: customer.invoice_settings.default_payment_method
        }.merge(options)

        payment_intent = ::Stripe::PaymentIntent.create(args)
        Pay::Payment.new(payment_intent).validate

        # Create a new charge object
        Stripe::Webhooks::ChargeSucceeded.new.create_charge(self, payment_intent.charges.first)
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end

      def create_stripe_subscription(name, plan, options = {})
        quantity = options.delete(:quantity) || 1
        opts = {
          expand: ["pending_setup_intent", "latest_invoice.payment_intent"],
          items: [plan: plan, quantity: quantity],
          off_session: true
        }.merge(options)

        # Inherit trial from plan unless trial override was specified
        opts[:trial_from_plan] = true unless opts[:trial_period_days]

        opts[:customer] = stripe_customer.id

        stripe_sub = ::Stripe::Subscription.create(opts)
        subscription = create_subscription(stripe_sub, "stripe", name, plan, status: stripe_sub.status, quantity: quantity)

        # No trial, card requires SCA
        if subscription.incomplete?
          Pay::Payment.new(stripe_sub.latest_invoice.payment_intent).validate

          # Trial, card requires SCA
        elsif subscription.on_trial? && stripe_sub.pending_setup_intent
          Pay::Payment.new(stripe_sub.pending_setup_intent).validate
        end

        subscription
      rescue ::Stripe::StripeError => e
        raise Error, e.message
      end

      def create_customer(name:, email:)
        customer = ::Stripe::Customer.create(email: email, name: name)
        update(processor: :stripe, processor_id: customer.id)

        # Update the user's card on file if a token was passed in
        if card_token.present?
          payment_method = ::Stripe::PaymentMethod.attach(card_token, {customer: customer.id})
          customer.invoice_settings.default_payment_method = payment_method.id
          customer.save

          update_stripe_card_on_file ::Stripe::PaymentMethod.retrieve(card_token).card
        end

        customer
      end

    end
  end
end
