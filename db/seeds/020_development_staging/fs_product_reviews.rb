# frozen_string_literal: true

def seed_fs_product_reviews
  return unless Rails.env.development? || Rails.env.staging?

  product = Link.find_by(unique_permalink: "fs")
  unless product
    puts "Product with unique_permalink 'fs' not found"
    return
  end

  # Enable product reviews on the product
  product.update!(display_product_reviews: true)

  # Get existing users to use as buyers
  existing_users = User.limit(20).to_a
  if existing_users.empty?
    puts "No existing users found. Please run seeds/020_development_staging/01_users.rb first"
    return
  end

  # Review messages for the two reviews
  review_messages = [
    "This product has been incredibly helpful for my workflow. The features are well-designed and easy to use. Highly recommend!",
    "Great value for money. The product exceeded my expectations and has become an essential tool in my daily work."
  ]

  seller = product.user
  puts "Creating 2 purchases and product reviews for product 'fs'..."

  2.times do |i|
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
    rating = [4, 5].sample # Random rating between 4 and 5
    purchase.post_review(
      rating: rating,
      message: review_messages[i]
    )

    puts "  Created purchase ##{i + 1} and review (rating: #{rating}) by #{buyer.name}"
  end

  puts "✓ Successfully created 2 product reviews for product 'fs'"
end

if Rails.env.development?
  seed_fs_product_reviews
end
