# frozen_string_literal: true
module Pay
  class Engine < ::Rails::Engine
    engine_name "pay"

    initializer "pay.processors" do |app|
      # Include processor backends
      require "pay/stripe" if defined? ::Stripe
      require "pay/braintree" if defined? ::Braintree
      require "pay/paddle" if defined? ::PaddlePay

      if Pay.automount_routes
        app.routes.append do
          mount Pay::Engine, at: Pay.routes_path, as: "pay"
        end
      end
    end

    config.to_prepare do
      Pay::Stripe.setup if defined? ::Stripe
      Pay::Braintree.setup if defined? ::Braintree
      Pay::Paddle.setup if defined? ::PaddlePay

      Pay.charge_model.include Pay::Receipts if defined? ::Receipts::Receipt
    end
  end
end
