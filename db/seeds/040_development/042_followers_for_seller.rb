# frozen_string_literal: true

# ============================================================================
# Seed Data: 25 Followers for seller@gumroad.com
# ============================================================================
#
# This seed file creates:
#   1. 25 confirmed followers for seller@gumroad.com
#   2. Uses existing user records (should be around 50 users from other seeds)
#   3. Followers are created with alternating sources: FOLLOW_PAGE and PROFILE_PAGE
#   4. Followers are created in reverse ID order (highest ID first when sorted DESC)
#
# IMPORTANT: This seed runs AFTER 041_beautiful_widget_with_posts_and_installment_plan.rb
# to ensure the seller and other users exist before creating followers.
#
# ============================================================================
# HOW TO RUN:
# ============================================================================
#
# Option 1: Load this specific seed file in Rails console:
#   load 'db/seeds/040_development/042_followers_for_seller.rb'
#
# Option 2: Run all seeds (this file runs automatically in development):
#   rails db:seed
#
# ============================================================================
# HOW TO VERIFY:
# ============================================================================
#
# 1. Verify followers were created:
#    seller = User.find_by(email: "seller@gumroad.com")
#    seller.followers.active.count  # Should be 25
#
# 2. Verify followers are in reverse ID order:
#    seller.followers.active.order(id: :desc).pluck(:id, :email).first(5)
#    # Should show highest IDs first
#
# 3. Verify all followers are confirmed:
#    seller.followers.active.where(confirmed_at: nil).count  # Should be 0
#
# 4. Verify followers use existing users:
#    seller.followers.active.joins("LEFT JOIN users ON users.id = followers.follower_user_id")
#         .where.not(follower_user_id: nil).count  # Should show users linked
#
# ============================================================================
# NOTES:
# ============================================================================
#
# - This seed only runs in development environment
# - Requires seller@gumroad.com user to exist (created by other seeds)
# - Requires existing users to exist (buyer1-10, gumbuyer0-9, gumbo0-9, etc.)
# - Followers are created with alternating sources: FOLLOW_PAGE (even indices) and PROFILE_PAGE (odd indices)
# - All followers are auto-confirmed
# - Uses existing user records (around 50 should exist from other seeds)
# - Selects users in reverse ID order (highest ID first)
# - Seed is idempotent (checks for existing followers before creating)
#
# ============================================================================

def create_followers_for_seller
  unless Rails.env.development?
    puts "This seed only runs in development environment"
    return
  end

  seller = User.find_by(email: "seller@gumroad.com")
  unless seller
    puts "Error: seller@gumroad.com not found. Please run previous seed files first."
    return
  end

  puts "Creating up to 25 followers for seller: #{seller.email} using existing users"

  existing_followers_count = seller.followers.active.count
  followers_to_create = 25 - existing_followers_count

  if followers_to_create <= 0
    puts "Seller already has #{existing_followers_count} followers (25 or more). Skipping creation."
    return
  end

  existing_users = User.where.not(id: seller.id)
                       .where.not(email: seller.email)
                       .order(id: :desc)
                       .limit(50)

  if existing_users.count < followers_to_create
    puts "Warning: Only found #{existing_users.count} existing users, but need #{followers_to_create} followers."
    puts "Will create followers from available users."
  end

  available_users = existing_users.reject do |user|
    seller.followers.active.exists?(email: user.email)
  end

  if available_users.count < followers_to_create
    puts "Warning: Only #{available_users.count} users available (not already following)."
    puts "Will create #{[available_users.count, followers_to_create].min} followers."
    followers_to_create = [available_users.count, followers_to_create].min
  end

  puts "Seller currently has #{existing_followers_count} followers."
  puts "Found #{available_users.count} available users. Creating #{followers_to_create} new followers..."

  created_count = 0
  skipped_count = 0
  error_count = 0

  available_users.first(followers_to_create).each_with_index do |user, index|
    follower_number = index + 1

    source = index.even? ? Follower::From::FOLLOW_PAGE : Follower::From::PROFILE_PAGE
    source_name = index.even? ? "FOLLOW_PAGE" : "PROFILE_PAGE"

    existing_follower = seller.followers.find_by(email: user.email)

    if existing_follower
      if existing_follower.deleted?
        existing_follower.mark_undeleted!
        existing_follower.update!(
          source: source,
          confirmed_at: Time.current,
          follower_user_id: user.id
        )
        created_count += 1
        puts "  Reactivated follower #{follower_number}/#{followers_to_create}: #{user.email} (User ID: #{user.id}, Source: #{source_name})"
      else
        skipped_count += 1
        puts "  Skipped follower #{follower_number}/#{followers_to_create}: #{user.email} (already exists)"
      end
    else
      follower = seller.add_follower(
        user.email,
        source: source,
        follower_user_id: user.id
      )

      if follower&.persisted?
        follower.confirm! unless follower.confirmed?
        created_count += 1
        puts "  Created follower #{follower_number}/#{followers_to_create}: #{user.email} (User ID: #{user.id}, Follower ID: #{follower.id}, Source: #{source_name})"
      else
        error_count += 1
        puts "  Error creating follower #{follower_number}/#{followers_to_create}: #{user.email}"
        if follower
          puts "    Errors: #{follower.errors.full_messages.join(', ')}"
        end
      end
    end
  end

  final_count = seller.followers.active.count
  puts "\nFollowers creation complete!"
  puts "  Created: #{created_count}"
  puts "  Skipped: #{skipped_count}"
  puts "  Errors: #{error_count}"
  puts "  Total active followers: #{final_count}"

  if final_count > 0
    highest_id = seller.followers.active.maximum(:id)
    lowest_id = seller.followers.active.minimum(:id)
    confirmed_count = seller.followers.active.where.not(confirmed_at: nil).count
    users_linked_count = seller.followers.active.where.not(follower_user_id: nil).count

    follow_page_count = seller.followers.active.where(source: Follower::From::FOLLOW_PAGE).count
    profile_page_count = seller.followers.active.where(source: Follower::From::PROFILE_PAGE).count

    puts "  ID range: #{lowest_id} - #{highest_id}"
    puts "  Confirmed followers: #{confirmed_count}/#{final_count}"
    puts "  Followers linked to users: #{users_linked_count}/#{final_count}"
    puts "  Source distribution: FOLLOW_PAGE: #{follow_page_count}, PROFILE_PAGE: #{profile_page_count}"
    puts "  Reverse ID order: When sorted by ID DESC, follower with ID #{highest_id} appears first"
  end
end

create_followers_for_seller
