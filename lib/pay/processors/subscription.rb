module Pay
  module Processors
    class Subscription
      attr_reader :billable

      delegate :customer_name, :email, to: :billable

      def initialize(billable)
        @billable = billable
      end
    end
  end
end
