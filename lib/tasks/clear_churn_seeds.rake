# frozen_string_literal: true

namespace :db do
  desc "Clear churn analytics seed data from test database"
  task clear_churn_seeds: :environment do
    unless Rails.env.test?
      puts "This task only runs in test environment"
      exit 1
    end

    puts "Clearing churn seed data..."

    # Find churn products by unique_permalink (products are Links in this codebase)
    churn_products = Link.where("unique_permalink LIKE ?", "churn%")
    puts "Found #{churn_products.count} churn products"

    # Find subscriptions associated with churn products
    churn_subscriptions = Subscription.joins(:link).where("links.unique_permalink LIKE ?", "churn%")
    puts "Found #{churn_subscriptions.count} churn subscriptions"

    # Find purchases associated with churn subscriptions or churn products
    churn_purchases = Purchase.joins(:link).where("links.unique_permalink LIKE ?", "churn%")
    churn_purchases_from_subs = Purchase.where(subscription_id: churn_subscriptions.pluck(:id))
    all_churn_purchases = Purchase.where(id: (churn_purchases.pluck(:id) + churn_purchases_from_subs.pluck(:id)).uniq)
    puts "Found #{all_churn_purchases.count} churn purchases"

    # Find churn buyers (users with churnbuyer email pattern)
    churn_buyers = User.where("email LIKE ?", "churnbuyer%@gumroad.com")
    puts "Found #{churn_buyers.count} churn buyers"

    # Find the seller (but only delete if it only has churn products)
    seller = User.find_by(email: "seller@gumroad.com")
    if seller
      seller_products = seller.products
      churn_products_count = seller_products.where("unique_permalink LIKE ?", "churn%").count
      puts "Found seller: #{seller.email} with #{seller_products.count} products (#{churn_products_count} churn products)"
    end

    # Delete in correct order to avoid foreign key constraints
    puts "\nDeleting data..."

    # Delete subscriptions first (they reference purchases)
    churn_subscriptions.destroy_all
    puts "✓ Deleted subscriptions"

    # Delete purchases
    all_churn_purchases.destroy_all
    puts "✓ Deleted purchases"

    # Delete products
    churn_products.destroy_all
    puts "✓ Deleted products"

    # Delete buyers
    churn_buyers.destroy_all
    puts "✓ Deleted buyers"

    # Only delete seller if it has no products left
    if seller && seller.products.count == 0
      seller.destroy
      puts "✓ Deleted seller (no products remaining)"
    elsif seller
      puts "⚠ Kept seller (has #{seller.products.count} non-churn products)"
    end

    puts "\n✅ Churn seed data cleared!"
  end
end
