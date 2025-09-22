# frozen_string_literal: true

def create_or_find_churn_seller
  seller = User.find_by(email: "seller@gumroad.com")
  if seller.nil?
    # Create seller for test environment
    seller = User.create!(
      email: "seller@gumroad.com",
      name: "Seller",
      username: "seller",
      confirmed_at: Time.current,
      is_team_member: true,
      user_risk_state: "compliant",
      password: SecureRandom.hex(24)
    )

    # Skip validations to set a pwned but easy password
    seller.password = "password"
    seller.save!(validate: false)

    puts "Created seller: #{seller.email}"
  end
  seller
end

def find_or_create_product(seller, name, permalink, price_cents, recurrence)
  product = seller.products.find_by(unique_permalink: permalink)
  return product if product.present?

  seller.products.create!(
    name: name,
    unique_permalink: permalink,
    description: "Test subscription product for churn analytics",
    filetype: "link",
    price_cents: price_cents,
    is_recurring_billing: true,
    subscription_duration: recurrence,
    native_type: "membership"
  )
end

def find_or_create_buyer(index)
  email = "churnbuyer#{index}@gumroad.com"
  username = "churnbuyer#{index}"

  buyer = User.find_by(email: email)
  return buyer if buyer.present?

  User.create!(
    email: email,
    name: "Churn Buyer #{index}",
    username: username,
    confirmed_at: Time.current,
    user_risk_state: "compliant",
    password: SecureRandom.hex(24)
  ).tap do |user|
    # Skip validations to set a pwned but easy password
    user.password = "password"
    user.save!(validate: false)
  end
end

def create_subscription_with_purchase(seller, product, buyer, start_date, churn_date = nil)
  # Get the auto-created price from product
  price = product.prices.first

  # Build subscription (don't save yet)
  subscription = Subscription.new(
    seller: seller,
    link: product,
    user: buyer,
    created_at: start_date,
    deactivated_at: churn_date,
    cancelled_at: churn_date,
    ended_at: churn_date,
    failed_at: nil
  )

  # Build payment option (attached to subscription)
  payment_option = PaymentOption.new(
    subscription: subscription,
    price: price  # Only these two attributes!
  )

  # Add payment option to subscription before saving
  subscription.payment_options << payment_option
  subscription.save!

  # Create original purchase using test pattern to bypass validation
  purchase = Purchase.new(
    link: product,
    seller: seller,
    subscription: subscription,
    price_cents: price.price_cents,
    displayed_price_cents: price.price_cents,
    tax_cents: 0,
    gumroad_tax_cents: 0,
    total_transaction_cents: price.price_cents,
    purchaser: buyer,
    email: buyer.email,
    card_country: "US",
    ip_address: "199.241.200.176",
    purchase_state: "in_progress", # Start with in_progress
    succeeded_at: start_date,
    created_at: start_date,
    is_original_subscription_purchase: true
  )

  # Calculate fees (like the factory does)
  purchase.send(:calculate_fees)
  purchase.save!

  # Mark as test successful (bypasses financial validation)
  purchase.mark_test_successful!

  subscription
end

def create_churn_test_data
  puts "Creating 3 years of churn analytics test data with growth and randomness..."

  seller = create_or_find_churn_seller
  return if seller.nil?

  puts "Using existing seller: #{seller.email}"

  # Create subscription products
  products = []

  products << find_or_create_product(seller, "Monthly Premium Plan", "churnmonthly", 2999, "monthly")
  products << find_or_create_product(seller, "Yearly Pro Plan", "churnyearly", 29999, "yearly")
  products << find_or_create_product(seller, "Quarterly Business Plan", "churnquarterly", 9999, "quarterly")
  products << find_or_create_product(seller, "Biannual Creative Plan", "churnbiannual", 14999, "biannually")

  puts "Created/Found #{products.length} subscription products:"
  products.each do |product|
    price = product.prices.first
    mrr = case price.recurrence
          when "monthly" then price.price_cents / 100.0
          when "yearly" then price.price_cents / 1200.0
          when "quarterly" then price.price_cents / 300.0
          when "biannually" then price.price_cents / 600.0
    end
    puts "  * #{product.name}: $#{price.price_cents / 100.0} #{price.recurrence} (MRR: $#{mrr.round(2)})"
  end

  # Create buyers pool (we'll reuse them)
  buyers = []
  10.times do |i|
    buyers << find_or_create_buyer(i)
  end
  puts "Created/Found #{buyers.length} test buyers"

  subscriptions = []
  start_date = 3.years.ago
  end_date = Date.current

  puts "Generating subscriptions from #{start_date.strftime('%Y-%m-%d')} to #{end_date.strftime('%Y-%m-%d')}..."

  # Generate data month by month with growth and randomness
  current_date = start_date.beginning_of_month

  while current_date <= end_date
    # Growth multiplier: starts at 1.0, grows to 3.0 over 3 years (exponential growth)
    months_elapsed = ((current_date - start_date) / 1.month).to_i
    growth_multiplier = 1.0 + (months_elapsed / 36.0) * 2.0 # Linear growth from 1.0 to 3.0

    # Base subscriptions per month (with growth) - target ~401 total over 36 months
    base_subscriptions = (8 * growth_multiplier).round

    # Add randomness (±30%)
    random_factor = 0.7 + (rand * 0.6) # 0.7 to 1.3
    monthly_subscriptions = (base_subscriptions * random_factor).round

    # Seasonal variation (higher in Q4, lower in Q1)
    quarter = (current_date.month - 1) / 3 + 1
    seasonal_multiplier = case quarter
                          when 1 then 0.8  # Q1: Lower
                          when 2 then 1.0  # Q2: Normal
                          when 3 then 1.1  # Q3: Slightly higher
                          when 4 then 1.3  # Q4: Holiday season
    end

    monthly_subscriptions = (monthly_subscriptions * seasonal_multiplier).round

    # Generate subscriptions for this month
    monthly_subscriptions.times do |i|
      # Random day in the month
      signup_day = rand(1..current_date.end_of_month.day)
      signup_date = current_date + (signup_day - 1).days

      # Random product selection (weighted towards monthly)
      product_weights = [0.5, 0.2, 0.2, 0.1] # monthly, yearly, quarterly, biannually
      product = products[weighted_random_index(product_weights)]

      # Random buyer (reuse existing buyers)
      buyer = buyers.sample

      # Determine if this subscription will churn
      # Churn probability varies by product type and time
      base_churn_probability = case product.subscription_duration
                               when "monthly" then 0.50    # Increased to 0.50
                               when "quarterly" then 0.40  # Increased to 0.40
                               when "biannually" then 0.35 # Increased to 0.35
                               when "yearly" then 0.30     # Increased to 0.30
      end

      # Churn probability decreases over time (better retention as business matures)
      retention_improvement = months_elapsed / 36.0 * 0.2 # Reduced improvement from 0.3 to 0.2
      churn_probability = [base_churn_probability - retention_improvement, 0.10].max # Increased min from 0.05 to 0.10

      if rand < churn_probability
        # This subscription will churn
        # Churn timing: most churn happens in first 3 months, some later
        churn_timing = case rand
                       when 0..0.6 then rand(1..90)      # 60% churn in first 3 months
                       when 0.6..0.8 then rand(91..180)  # 20% churn in months 3-6
                       when 0.8..0.9 then rand(181..365)  # 10% churn in months 6-12
                       else rand(366..730)                # 10% churn after 1 year
        end

        churn_date = signup_date + churn_timing.days

        # Don't churn in the future
        churn_date = [churn_date, end_date].min

        subscription = create_subscription_with_purchase(seller, product, buyer, signup_date, churn_date)
      else
        # This subscription stays active
        subscription = create_subscription_with_purchase(seller, product, buyer, signup_date)
      end

      subscriptions << subscription
    end

    # Progress indicator
    if months_elapsed % 6 == 0 # Every 6 months
      puts "  Generated #{months_elapsed} months of data... (#{subscriptions.length} total subscriptions)"
    end

    current_date = current_date.next_month
  end

  puts ""
  puts "3-Year Subscription Data Summary:"
  puts "=" * 50

  # Calculate statistics
  total_subscriptions = subscriptions.length
  active_subscriptions = subscriptions.count { |s| s.deactivated_at.nil? }
  churned_subscriptions = subscriptions.count { |s| s.deactivated_at.present? }

  # Recent churn (last 30 days)
  recent_churn = subscriptions.count { |s| s.deactivated_at && s.deactivated_at >= 30.days.ago }

  # Last period churn (30-60 days ago)
  last_period_churn = subscriptions.count { |s| s.deactivated_at && s.deactivated_at >= 60.days.ago && s.deactivated_at < 30.days.ago }

  puts "📊 Total Subscriptions: #{total_subscriptions}"
  puts "✅ Active Subscriptions: #{active_subscriptions}"
  puts "❌ Churned Subscriptions: #{churned_subscriptions}"
  puts "📈 Recent Churn (30 days): #{recent_churn}"
  puts "📉 Last Period Churn (30-60 days): #{last_period_churn}"

  # Calculate MRR for churned subscriptions in current period
  current_period_churned_mrr = subscriptions.select { |s| s.deactivated_at && s.deactivated_at >= 30.days.ago }.sum do |sub|
    price = sub.last_payment_option.price
    case price.recurrence
    when "monthly" then price.price_cents / 100.0
    when "yearly" then price.price_cents / 1200.0
    when "quarterly" then price.price_cents / 300.0
    when "biannually" then price.price_cents / 600.0
    end
  end

  puts ""
  puts "💰 Current Period Churned MRR: $#{current_period_churned_mrr.round(2)}/month"
  puts "📊 Overall Churn Rate: #{(churned_subscriptions.to_f / total_subscriptions * 100).round(1)}%"

  puts ""
  puts "🎯 Test Credentials:"
  puts "   Login: seller@gumroad.com / password"
  puts "   URL: /dashboard/churn"
  puts ""
  puts "✅ 3 years of realistic churn data created successfully!"
end

# Helper method for weighted random selection
def weighted_random_index(weights)
  total_weight = weights.sum
  random_value = rand * total_weight

  cumulative_weight = 0
  weights.each_with_index do |weight, index|
    cumulative_weight += weight
    return index if random_value <= cumulative_weight
  end

  weights.length - 1
end

# Run in both development and test environments
if Rails.env.development?
  create_churn_test_data
end
