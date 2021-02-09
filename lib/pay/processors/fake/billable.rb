module Pay
  module Processors
    module Fake
      class Billable < Processors::Billable
        def customer
          self
        end

        def update_payment_method(token)
          self
        end

        def charge(amount, options = {})
          # Fake IDs with sequential integers
          last_id = billbable.charges.where(processor: :pay).order(processor_id: :asc).last.to_i

          billable.charges.create(
            processor: :pay,
            processor_id: last_id + 1,
            amount: amount,
            card_type: :none
          )
        end

        def subscribe(name, plan, options = {})
          # Fake IDs with sequential integers
          last_id = billbable.subscriptions.where(processor: :pay).order(processor_id: :asc).last.to_i

          billable.subscriptions.create(
            name: name,
            processor: :pay,
            processor_id: last_id + 1,
            processor_plan: plan,
            status: :active
          )
        end
      end
    end
  end
end
