# frozen_string_literal: true

def find_or_create_recommendable_user(category_name)
  user = User.find_by(email: "gumbo_#{category_name}@gumroad.com")
  return user if user

  user = User.create!(
    name: "Gumbo #{category_name}",
    username: "gumbo#{category_name}",
    email: "gumbo_#{category_name}@gumroad.com",
    password: SecureRandom.hex(24),
    user_risk_state: "compliant",
    confirmed_at: Time.current,
    payment_address: "gumbo_#{category_name}@gumroad.com"
  )

  # Skip validations to set a pwned but easy password
  user.password = "password"
  user.save!(validate: false)

  user
end

def find_or_create_universal_free_offer_code_for(seller)
  offer_code = seller.offer_codes
    .universal
    .alive
    .find_by(amount_percentage: 100)
  return offer_code if offer_code.present?

  OfferCode.create!(
    user: seller,
    universal: true,
    amount_percentage: 100,
    code: "seed-#{seller.id}-#{SecureRandom.hex(3)}"
  )
end

def create_purchase(seller, buyer, product)
  purchase = Purchase.new(
    link_id: product.id,
    seller_id: seller.id,
    price_cents: 0,
    displayed_price_cents: 0,
    tax_cents: 0,
    gumroad_tax_cents: 0,
    total_transaction_cents: 0,
    purchaser_id: buyer.id,
    email: buyer.email,
    card_country: "US",
    ip_address: "199.241.200.176",
    offer_code: find_or_create_universal_free_offer_code_for(seller)
  )
  purchase.send(:calculate_fees)
  purchase.save!
  purchase.update!(purchase_state: "successful", succeeded_at: Time.current)

  purchase.post_review(rating: 3)
end

def create_recommendable_product_if_not_exists(user, taxonomy_slug)
  product_name = "Beautiful #{taxonomy_slug} widget"

  # Create main product
  unless user.links.exists?(name: product_name)
    product = user.links.create!(
      name: product_name,
      description: "Description for demo product",
      filetype: "link",
      price_cents: 500,
      taxonomy: Taxonomy.find_by(slug: taxonomy_slug),
      display_product_reviews: true
    )
    product.tag!(taxonomy_slug[0..19])
    buyer = User.find_by(email: "seller@gumroad.com")
    create_purchase(user, buyer, product)
  end

  # Create trial products
  %w[1 2].each do |trial_number|
    trial_name = "Trial #{trial_number} | #{product_name}"
    create_or_update_trial_product(user, trial_name, trial_number, taxonomy_slug)
  end
end

private
def create_or_update_trial_product(user, trial_name, trial_number, taxonomy_slug)
  existing_product = user.links.find_by(name: trial_name)

  if existing_product
    Rails.logger.debug "Trial product #{trial_number} already exists: #{trial_name} for user #{user.id}"
    ensure_correct_trial_purchases(existing_product, trial_name, trial_number, user)
  else
    Rails.logger.debug "Creating trial product #{trial_number}: #{trial_name} for user #{user.id}"

    trial_product = user.links.create!(
      name: trial_name,
      description: "Trial #{trial_number} | Description for demo product",
      filetype: "link",
      price_cents: 0,
      taxonomy: Taxonomy.find_by(slug: taxonomy_slug),
      display_product_reviews: true
    )

    Rails.logger.debug "Trial product #{trial_number} created with ID: #{trial_product.id}"
    trial_product.tag!(taxonomy_slug[0..19])
    Rails.logger.debug "Trial product #{trial_number} tagged with: #{taxonomy_slug[0..19]}"

    gumbo_buyer = User.find_by(email: "gumbo_writing@gumroad.com")
    if gumbo_buyer
      create_purchase(user, gumbo_buyer, trial_product)
    else
      Rails.logger.warn "User with email 'gumbo_writing@gumroad.com' not found. Skipping purchase creation for trial product #{trial_number}."
    end
  end
end

def ensure_correct_trial_purchases(trial_product, trial_name, trial_number, user)
  # Remove any purchases from seller@gumroad.com
  seller_purchases = trial_product.sales.joins(:purchaser).where(users: { email: "seller@gumroad.com" })
  if seller_purchases.exists?
    Rails.logger.debug "Deleting purchases from seller@gumroad.com for trial product #{trial_number}: #{trial_name}"
    seller_purchases.destroy_all
  end

  # Ensure at least one purchase from gumbo_writing exists
  gumbo_purchases = trial_product.sales.joins(:purchaser).where(users: { email: "gumbo_writing@gumroad.com" })
  if gumbo_purchases.empty?
    gumbo_buyer = User.find_by(email: "gumbo_writing@gumroad.com")
    if gumbo_buyer
      Rails.logger.debug "Creating purchase for trial product #{trial_number} with gumbo_writing buyer: #{trial_name}"
      create_purchase(user, gumbo_buyer, trial_product)
    else
      Rails.logger.warn "User with email 'gumbo_writing@gumroad.com' not found. Cannot create purchase for trial product #{trial_number}."
    end
  end
end

create_recommendable_product_if_not_exists(find_or_create_recommendable_user("film"), "films")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("music"), "music-and-sound-design")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("writing"), "writing-and-publishing")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("education"), "education")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("software"), "software-development")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("comics"), "comics-and-graphic-novels")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("drawing"), "drawing-and-painting")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("animation"), "3d")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("audio"), "audio")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("games"), "gaming")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("photography"), "photography")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("crafts"), "self-improvement")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("design"), "design")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("sports"), "fitness-and-health")
create_recommendable_product_if_not_exists(find_or_create_recommendable_user("merchandise"), "fiction-books")

DevTools.delete_all_indices_and_reindex_all
