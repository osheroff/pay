module Pay
  module Webhooks
    class PaddleController < Pay::ApplicationController
      if Rails.application.config.action_controller.default_protect_from_forgery
        skip_before_action :verify_authenticity_token
      end

      def create
        verifier = Pay::Webhooks::Paddle::SignatureVerifier.new(check_params)
        if verifier.verify
          case params["alert_name"]
          when "subscription_created"
            Pay::Webhooks::Paddle::SubscriptionCreated.new(check_params)
          when "subscription_updated"
            Pay::Webhooks::Paddle::SubscriptionUpdated.new(check_params)
          when "subscription_cancelled"
            Pay::Webhooks::Paddle::SubscriptionCancelled.new(check_params)
          when "subscription_payment_succeeded"
            Pay::Webhooks::Paddle::SubscriptionPaymentSucceeded.new(check_params)
          when "subscription_payment_refunded"
            Pay::Webhooks::Paddle::SubscriptionPaymentRefunded.new(check_params)
          end

          head :ok
        else
          head :bad_request
        end
      end

      private

      def check_params
        @check_params ||= params.except(:action, :controller).permit!.as_json
      end
    end
  end
end
