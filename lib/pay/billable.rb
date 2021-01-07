require "pay/billable/sync_email"

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
      include Pay::Stripe::Billable if defined? ::Stripe
      include Pay::Braintree::Billable if defined? ::Braintree
      include Pay::Paddle::Billable if defined? ::PaddlePay

      has_many :charges, class_name: Pay.chargeable_class, foreign_key: :owner_id, inverse_of: :owner, as: :owner
      has_many :subscriptions, class_name: Pay.subscription_class, foreign_key: :owner_id, inverse_of: :owner, as: :owner

      attribute :plan, :string
      attribute :quantity, :integer
      attribute :card_token, :string

      # Save old customer IDs
      store_accessor :pay_data, :stripe_id
    end

    def payment_processor
      @payment_processor ||= payment_processor_for(processor).new(self)
    end

    def payment_process_for(name)
      "Pay::Processors::#{name.classify}".constantize
    end

    delegate :customer, :charge, :subscribe, :update_card, to: :payment_processor

    def processor=(value)
      super(value)

      # Cleans up old processor ID when you switch payment processors
      self.processor_id = nil if processor_changed?
    end

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
      subscriptions.for_name(name).last
    end

    def invoice!(options = {})
      send("#{processor}_invoice!", options)
    end

    def upcoming_invoice
      send("#{processor}_upcoming_invoice")
    end

    def processor
      super.inquiry
    end

    def has_incomplete_payment?(name: "default")
      subscription(name: name)&.has_incomplete_payment?
    end

    private

    def check_for_processor
      raise StandardError, "No payment processor selected. Make sure to set the #{self.class.name}'s `processor` attribute to either 'stripe' or 'braintree'." unless processor
    end

    # Used for creating a Pay::Subscription in the database
    def create_subscription(subscription, processor, name, plan, options = {})
      options[:quantity] ||= 1

      options.merge!(
        name: name || "default",
        processor: processor,
        processor_id: subscription.id,
        processor_plan: plan,
        trial_ends_at: send("#{processor}_trial_end_date", subscription),
        ends_at: nil
      )
      subscriptions.create!(options)
    end

    def default_generic_trial?(name, plan)
      # Generic trials don't have plans or custom names
      plan.nil? && name == "default" && on_generic_trial?
    end
  end
end
