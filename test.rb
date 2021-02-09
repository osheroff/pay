require "active_support/core_ext/module/delegation"

class Stripe
  def charge(amount)
    puts "You sent #{amount}"
  end
end

class User
  def initialize
    @stripe = Stripe.new
  end

  attr_reader :stripe

  delegate :charge, to: :stripe
end

User.new.charge(1_00)
