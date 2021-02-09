module Pay
  module Billable
    extend ActiveSupport::Concern

    # Keep track of which Billable models we have
    class << self
      attr_reader :includers
    end

    def self.included(base = nil, &block)
      @includers ||= []
      @includers << base if base
      super
    end

    included do |base|
      include Pay::Billable::SyncEmail

      has_many :charges, class_name: Pay.chargeable_class, foreign_key: :owner_id, inverse_of: :owner, as: :owner
      has_many :subscriptions, class_name: Pay.subscription_class, foreign_key: :owner_id, inverse_of: :owner, as: :owner

      # Convenience methods so you can assign these fields
      attribute :plan, :string
      attribute :quantity, :integer
      attribute :payment_method_token, :string

      # Save old customer IDs
      store_accessor :pay_data, :stripe_id
      store_accessor :pay_data, :braintree_id
      store_accessor :pay_data, :paddle_id
    end

    def payment_processor
      @payment_processor ||= payment_processor_for(processor).new(self)
    end

    def payment_process_for(name)
      "Pay::Processors::#{name.classify}::Billable".constantize
    end

    # Reset the payment processor when it changes
    def processor=(value)
      super(value)
      @payment_processor = nil
    end

    def processor
      super.inquiry
    end

    # Primary interface to interact with
    delegate :customer, to: :payment_processor
    delegate :charge, to: :payment_processor
    delegate :subscribe, to: :payment_processor
    delegate :update_payment_method, to: :payment_processor

    def customer_name
      [try(:first_name), try(:last_name)].compact.join(" ")
    end

    def on_trial?(name: "default", plan: nil)
      return true if default_generic_trial?(name, plan)

      sub = payment_processor.subscription(name: name)
      return sub&.on_trial? if plan.nil?

      sub&.on_trial? && sub.processor_plan == plan
    end

    def on_generic_trial?
      trial_ends_at? && trial_ends_at > Time.zone.now
    end

    def subscribed?(name: "default", processor_plan: nil)
      subscription = subscription(name: name)

      return false if subscription.nil?
      return subscription.active? if processor_plan.nil?

      subscription.active? && subscription.processor_plan == processor_plan
    end

    def on_trial_or_subscribed?(name: "default", processor_plan: nil)
      on_trial?(name: name, plan: processor_plan) ||
        subscribed?(name: name, processor_plan: processor_plan)
    end

    # Returns Pay::Subscription
    def subscription(name: "default")
      payment_processor.subscriptions.for_name(name).last
    end

    private

    def check_for_processor
      raise StandardError, "No payment processor selected. Make sure to set the #{self.class.name}'s `processor` attribute to either 'stripe' or 'braintree'." unless processor
    end

    def default_generic_trial?(name, plan)
      # Generic trials don't have plans or custom names
      plan.nil? && name == "default" && on_generic_trial?
    end
  end
end
