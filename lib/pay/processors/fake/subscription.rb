module Pay
  module Processors
    module Fake
      class Subscription < Processors::Subscription
        def processor_subscription(options = {})
          self
        end

        def cancel
          new_ends_at = on_trial? ? trial_ends_at : 1.week.from_now
          update(ends_at: new_ends_at)
        end

        def cancel_now!
          update(ends_at: Time.current, status: :canceled)
        end

        def resume
          update(ends_at: nil)
        end

        def swap(plan)
        end
      end
    end
  end
end
