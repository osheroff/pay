# frozen_string_literal: true

require "test_helper"

class WebhookRoutesTest < ActionDispatch::IntegrationTest
  test "stripe webhook routes get mounted correctly" do
    post "/pay/webhooks/stripe", as: :json
    assert_equal 400, response.status
  end

  test "braintree webhook routes get mounted correctly" do
    post "/pay/webhooks/braintree", as: :json
    assert_equal 400, response.status
  end

  test "paddle webhook routes get mounted correctly" do
    post "/pay/webhooks/paddle", as: :json
    assert_equal 400, response.status
  end
end
