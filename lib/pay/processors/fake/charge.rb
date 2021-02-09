module Pay
  module Processors
    module Fake
      class Charge < Processors::Charge
        def processor_charge
          self
        end

        def refund!(amount)
          update(amount_refunded: amount_refunded + amount)
        end
      end
    end
  end
end
