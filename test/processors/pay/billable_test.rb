require "test_helper"

class Pay::Processors::Pay::Billable::Test < ActiveSupport::TestCase
  setup do
    @billable = User.new email: "gob@bluth.com"
    @processor = Pay::Processors::Pay::Billable.new(@billable)
  end

  test "implements base functionality" do
    assert @processor.respond_to?(:customer)
    assert @processor.respond_to?(:update_payment_method)
    assert @processor.respond_to?(:charge)
    assert @processor.respond_to?(:subscribe)
  end
end
