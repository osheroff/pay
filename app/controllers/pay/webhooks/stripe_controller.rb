module Pay
  module Webhooks
    class StripeController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        event = verified_event
        klass = class_for_event(event)
        klass.new.call(event) if klass
        head :ok
      rescue ::Stripe::SignatureVerificationError => e
        log_error(e)
        head :bad_request
      end

      private

      def delegate_event(event)
        case event.type
          # Listen to the charge event to make sure we get non-subscription
          # purchases as well. Invoice is only for subscriptions and manual creation
          # so it does not include individual charges.
        when "charge.succeeded"
          Pay::Stripe::Webhooks::ChargeSucceeded.new
        when "charge.refunded"
          Pay::Stripe::Webhooks::ChargeRefunded.new

          # Warn user of upcoming charges for their subscription. This is handy for
          # notifying annual users their subscription will renew shortly.
          # This probably should be ignored for monthly subscriptions.
        when "invoice.upcoming"
          Pay::Stripe::Webhooks::SubscriptionRenewing.new

          # Payment action is required to process an invoice
        when "invoice.payment_action_required"
          Pay::Stripe::Webhooks::PaymentActionRequired.new

          # If a subscription is manually created on Stripe, we want to sync
        when "customer.subscription.created"
          Pay::Stripe::Webhooks::SubscriptionCreated.new

          # If the plan, quantity, or trial ending date is updated on Stripe, we want to sync
        when "customer.subscription.updated"
          Pay::Stripe::Webhooks::SubscriptionUpdated.new

          # When a customers subscription is canceled, we want to update our records
        when "customer.subscription.deleted"
          Pay::Stripe::Webhooks::SubscriptionDeleted.new

          # Monitor changes for customer's default card changing
        when "customer.updated"
          Pay::Stripe::Webhooks::CustomerUpdated.new

          # If a customer was deleted in Stripe, their subscriptions should be cancelled
        when "customer.deleted"
          Pay::Stripe::Webhooks::CustomerDeleted.new

          # If a customer's payment source was deleted in Stripe, we should update as well
        when "payment_method.attached"
          Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        when "payment_method.updated"
          Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        when "payment_method.card_automatically_updated"
          Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        when "payment_method.detached"
          Pay::Stripe::Webhooks::PaymentMethodUpdated.new
        end
      end

      def verified_event
        payload = request.body.read
        signature = request.headers["Stripe-Signature"]
        possible_secrets = secrets(payload, signature)

        possible_secrets.each_with_index do |secret, i|
          return ::Stripe::Webhook.construct_event(payload, signature, secret.to_s)
        rescue ::Stripe::SignatureVerificationError
          raise if i == possible_secrets.length - 1
          next
        end
      end

      def secrets(payload, signature)
        secret = Pay::Processors::Stripe.signing_secret
        return secret if secret
        raise Pay::Error.new("Cannot verify signature without a Stripe signing secret", signature, http_body: payload)
      end

      def log_error(e)
        logger.error e.message
        e.backtrace.each { |line| logger.error "  #{line}" }
      end
    end
  end
end
