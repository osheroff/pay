require "test_helper"

class Pay::PaddleWebhooksSubscriptionCreatedTest < ActiveSupport::TestCase
  setup do
    @data = JSON.parse(File.read("test/support/fixtures/paddle/subscription_created.json"))
  end

  test "webhook signature is verified correctly" do
    verifier = Pay::Webhooks::Paddle::SignatureVerifier.new(@data)
    assert verifier.verify
  end
end
