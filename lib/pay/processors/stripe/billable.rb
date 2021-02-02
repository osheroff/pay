module Pay
  module Processors
    module Stripe
      class Billable < Processors::Billable

        def initialize(billable)
          super

          raise StandardError, "Add Stripe to your Gemfile to use the Stripe payment processor. `bundle add stripe`" unless defined?(::Stripe)
        end

        def customer
          if processor_id?
            ::Stripe::Customer.retrieve(processor_id)
          else
            create_customer(name: customer_name, email: email)
          end
        rescue ::Stripe::StripeError => e
          raise Error, e.message
        end

        def update_payment_method(payment_method_id)
          return true if payment_method_id == customer.invoice_settings.default_payment_method

          payment_method = ::Stripe::PaymentMethod.attach(payment_method_id, customer: customer.id)
          ::Stripe::Customer.update(customer.id, invoice_settings: {default_payment_method: payment_method.id})

          update_stripe_card_on_file(payment_method.card)
          true
        rescue ::Stripe::StripeError => e
          raise Error, e.message
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

        def subscribe(name, plan, options = {})
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

        # Extra Stripe functionality

        # Used for syncing email changes to Stripe
        def sync_customer(**options)
          Stripe::Customer.update(processor_id, options.merge(email: email, name: customer_name))
        end

        def create_setup_intent
          ::Stripe::SetupIntent.create(customer: processor_id, usage: :off_session)
        end

        # Create customer and automatically set payment method if set
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

        def invoice!(options = {})
          ::Stripe::Invoice.create(options.merge(customer: processor_id)).pay
        end

        def upcoming_invoice
          ::Stripe::Invoice.upcoming(customer: processor_id)
        end

        def has_incomplete_payment?(name: "default")
          subscription(name: name)&.has_incomplete_payment?
        end

      end
    end
  end
end
