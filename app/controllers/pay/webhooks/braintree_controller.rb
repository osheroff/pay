module Pay
  module Webhooks
    class BraintreeController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        case webhook_notification.kind
        when "subscription_charged_successfully"
          Pay::Webhooks::Braintree::SubscriptionChargedSuccessfully.new.call(webhook_notification)
        when "subscription_canceled"
          Pay::Webhooks::Braintree::SubscriptionCanceled.new.call(webhook_notification)
        when "subscription_trial_ended"
          Pay::Webhooks::Braintree::SubscriptionTrialEnded.new.call(webhook_notification)
          subscription_trial_ended(webhook_notification)
        end

        head :ok
      rescue ::Braintree::InvalidSignature
        head :bad_request
      end

      private

      def webhook_notification
        @webhook_notification ||= Pay.braintree_gateway.webhook_notification.parse(
          params[:bt_signature],
          params[:bt_payload]
        )
      end
    end
  end
end
