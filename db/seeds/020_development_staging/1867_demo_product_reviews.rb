# frozen_string_literal: true

def seed_demo_product_reviews
  return unless Rails.env.development? || Rails.env.staging?

  product = Link.find_by(unique_permalink: "demo")
  unless product
    puts "Demo product not found. Please run seeds/020_development_staging/02_products.rb first"
    return
  end

  # Enable product reviews on the demo product
  product.update!(display_product_reviews: true)

  # Get existing users to use as buyers
  existing_users = User.limit(20).to_a
  if existing_users.empty?
    puts "No existing users found. Please run seeds/020_development_staging/01_users.rb first"
    return
  end

  # Sample review messages
  review_messages = [
    "This is a great product! Very useful for my workflow.",
    "Love the design and functionality. Highly recommend!",
    "Excellent quality and fast delivery. Will buy again.",
    "The widget works perfectly for my needs. Great value!",
    "Amazing product! Exceeded my expectations.",
    "Really helpful tool. Saved me a lot of time.",
    "Great customer support and a fantastic product.",
    "This widget is exactly what I was looking for.",
    "Very satisfied with my purchase. Works great!",
    "Top quality product. Worth every penny.",
    "Impressive features and easy to use.",
    "The best widget I've ever purchased. Highly recommended!",
    "Outstanding product quality and service.",
    "Perfect for my use case. Very happy!",
    "Great value for money. Would buy again.",
    "Excellent product with great documentation.",
    "This has become an essential tool for me.",
    "Really impressed with the quality and support.",
    "Fantastic product! Better than expected.",
    "Love it! Simple, effective, and well-designed."
  ]

  seller = product.user
  puts "Creating 20 purchases and product reviews for demo product..."

  20.times do |i|
    buyer = existing_users.sample

    # Create purchase
    purchase = Purchase.new(
      link_id: product.id,
      seller_id: seller.id,
      price_cents: product.price_cents || 0,
      displayed_price_cents: product.price_cents || 0,
      tax_cents: 0,
      gumroad_tax_cents: 0,
      total_transaction_cents: product.price_cents || 0,
      purchaser_id: buyer.id,
      email: buyer.email,
      card_country: "US",
      ip_address: "199.241.200.176",
      created_at: rand(30.days).seconds.ago
    )
    purchase.send(:calculate_fees)
    purchase.save!
    purchase.update_columns(purchase_state: "successful", succeeded_at: purchase.created_at)

    # Create product review with message (text)
    rating = (i % 5) + 1 # Ratings from 1 to 5
    purchase.post_review(
      rating: rating,
      message: review_messages.sample
    )

    puts "  Created purchase ##{i + 1} and review (rating: #{rating}) by #{buyer.name}"
  end

  puts "✓ Successfully created 20 product reviews for demo product"
end

if Rails.env.development?
  seed_demo_product_reviews
end
