module Pay
  class Charge < Pay::ApplicationRecord
    self.table_name = Pay.chargeable_table

    # Only serialize for non-json columns
    serialize :data unless json_column?("data")

    # Associations
    belongs_to :owner, polymorphic: true

    # Scopes
    scope :sorted, -> { order(created_at: :desc) }
    default_scope -> { sorted }

    # Validations
    validates :amount, presence: true
    validates :processor, presence: true
    validates :processor_id, presence: true
    validates :card_type, presence: true

    store_accessor :data, :paddle_receipt_url

    def payment_processor
      @payment_processor ||= payment_processor_for(processor).new(self)
    end

    def payment_processor_for(name)
      "Pay::Processors::#{name.to_s.classify}::Charge".constantize
    end

    def processor
      super.inquiry
    end

    def processor_charge
      send("#{processor}_charge")
    end

    def refund!(refund_amount = nil)
      refund_amount ||= amount
      send("#{processor}_refund!", refund_amount)
    end

    def charged_to
      "#{card_type} (**** **** **** #{card_last4})"
    end
  end
end
