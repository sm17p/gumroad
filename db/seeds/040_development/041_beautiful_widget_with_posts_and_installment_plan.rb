# frozen_string_literal: true

# Load StripePaymentMethodHelper for development seeds
load Rails.root.join("spec", "support", "stripe_payment_method_helper.rb") unless defined?(StripePaymentMethodHelper)


# ============================================================================
# Seed Data: Product with Posts and Installment Payment Support
# ============================================================================
#
# This seed file creates:
#   1. A product "Installment Widget" priced at $999.99
#   2. 10 test buyer users (buyer1@gumroad.com through buyer10@gumroad.com)
#   3. 10 purchases for the product, all created within a single day
#   4. 3 published product posts (installments) with created_after filter
#   5. 5 scheduled product posts to be published in the future
#   6. Seller-level purchase workflow: Terms of Service email (sends 1 hour after purchase for ALL products)
#   7. Member cancellation workflow: 2 emails (0 hours and 24 hours after cancel) - specific to Installment Widget
#   8. Resend email sending enabled for the seller (all post emails will use Resend)
#   9. A bundle product "Widget Essentials Bundle" priced at $1,499.99
#   10. Bundle includes the Installment Widget product
#   11. Bundle has installment plan: 3 monthly installments
#   12. Bundle has 2 published posts and 3 scheduled posts
#   13. Bundle purchase workflow: Welcome email (sends 2 hours after purchase)
#   14. Bundle member cancellation workflow: 2 emails (0 hours and 48 hours after cancel)
#
# IMPORTANT: Posts are configured with created_after filter set to 1 day after
# the last purchase was created, ensuring they will NOT be sent to the existing
# buyers (only to future customers who purchase after the posts are created).
#
# ============================================================================
# HOW TO RUN:
# ============================================================================
#
# Option 1: Load this specific seed file in Rails console:
#   load 'db/seeds/040_development/041_beautiful_widget_with_posts_and_installment_plan.rb'
#
# Option 2: Run all seeds (this file runs automatically in development):
#   rails db:seed
#
# ============================================================================
# HOW TO VERIFY:
# ============================================================================
#
# 1. Verify product was created:
#    product = Link.find_by(name: "Installment Widget")
#    product.price_cents  # Should be 99999
#    product.installments.count  # Should be 8 (3 published + 5 scheduled)
#
# 2. Verify 10 purchases were created:
#    product = Link.find_by(name: "Installment Widget")
#    Purchase.where(link_id: product.id).count  # Should be 10
#    Purchase.where(link_id: product.id).pluck(:created_at).map(&:to_date).uniq.count  # Should be 1 (all same day)
#
# 3. Verify posts have created_after filter:
#    product.installments.each do |post|
#      puts "#{post.name}: created_after = #{post.created_after}"
#    end
#    # All should have created_after set to 1 day after last purchase.created_at
#
# 4. Verify scheduled posts:
#    product.installments.where(ready_to_publish: true).count  # Should be 5
#
# 5. Verify posts won't be sent to existing buyers:
#    last_purchase = Purchase.where(link_id: product.id).order(created_at: :desc).first
#    last_purchase.created_at < product.installments.first.created_after  # Should be true
#
# 6. Verify purchase workflow (Terms of Service - seller-level, applies to all products):
#    workflow = Workflow.find_by(name: "Terms of Service", seller_id: seller.id, link_id: nil)
#    workflow.workflow_type  # Should be "seller"
#    workflow.installments.count  # Should be 1
#    workflow.installments.first.installment_rule.delayed_delivery_time  # Should be 3600 (1 hour)
#
# 7. Verify member cancellation workflow:
#    workflow = Workflow.find_by(name: "Installment Widget - Member Cancellation")
#    workflow.workflow_trigger  # Should be "member_cancellation"
#    workflow.installments.count  # Should be 2
#    workflow.installments.map { |i| i.installment_rule.delayed_delivery_time }  # Should be [0, 86400]
#
# ============================================================================
# NOTES:
# ============================================================================
#
# - This seed only runs in development environment
# - Requires seller@gumroad.com user to exist (created by other seeds)
# - Uses Stripe test card (4242 4242 4242 4242) for payment
# - Scheduled posts use formula: n + n + 1 days (3, 5, 7, 9, 11 days from now)
# - Posts are idempotent (can be run multiple times safely)
# - 10 purchases are created with 2-hour intervals within a single day
# - Resend email sending is enabled:
#   * Globally via :resend feature flag
#   * For the seller via :use_resend_for_post_emails
#   * Force Resend for seller via :force_resend_for_post_emails (bypasses router probability logic)
# - All records are protected from recreation/overwriting:
#   * Uses find_or_create_by for products, posts, and workflows
#   * Checks existence before creating bundle products and installment plans
#   * Only updates records if they don't match expected values
#   * Safe to run multiple times without creating duplicates
#
# ============================================================================

def create_beautiful_widget_with_posts_and_installment_plan
  unless Rails.env.development?
    puts "This seed only runs in development environment"
    return
  end

  seller = User.find_by!(email: "seller@gumroad.com")

  Feature.activate(:resend)
  Feature.activate(:use_resend_for_post_emails)
  Feature.activate(:force_resend_for_post_emails)
  # puts "Enabled Resend email sending (global and for seller: #{seller.email}, force_resend enabled to bypass router)"

  product = Link.find_or_create_by!(name: "Installment Widget", user_id: seller.id) do |link|
    link.description = "An installment widget that creates amazing posts and supports installment plans"
    link.filetype = "link"
    link.price_cents = 99999
    link.display_product_reviews = true
    link.customizable_price = false
  end

  product.update_columns(customizable_price: false) if product.customizable_price?

  if product.prices.empty?
    price = product.prices.build(price_cents: product.price_cents)
    price.recurrence = 0
    product.save!
  end

  product.tag!("widget") unless product.tags.exists?(name: "widget")

  # Create 10 purchases within a single day (spread 2 hours apart)
  # PROTECTION: Checks if purchase already exists before creating to prevent duplicates
  base_time = Time.current.beginning_of_day + 8.hours  # Start at 8 AM
  purchases = []
  last_purchase_time = nil

  10.times do |n|
    buyer_number = n + 1
    buyer_email = "buyer#{buyer_number}@gumroad.com"

    buyer = User.find_or_create_by!(email: buyer_email) do |user|
      user.name = "Test Buyer #{buyer_number}"
      user.username = "testbuyer#{buyer_number}"
      user.password = SecureRandom.hex(24)
      user.user_risk_state = "compliant"
      user.confirmed_at = Time.current
      user.save!(validate: false)
      user.password = "password"
      user.save!(validate: false)
    end

    purchase_time = base_time + (n * 2).hours
    last_purchase_time = purchase_time

    unless Purchase.exists?(link_id: product.id, purchaser_id: buyer.id)
      chargeable = CardParamsHelper.build_chargeable(
        StripePaymentMethodHelper.success.with_zip_code("12345").to_stripejs_params,
        SecureRandom.uuid
      )

      params = {
        purchase: {
          email: buyer.email,
          quantity: 1,
          perceived_price_cents: product.price_cents,
          ip_address: "127.0.0.1",
          session_id: SecureRandom.hex(16),
          is_mobile: false,
          browser_guid: SecureRandom.uuid
        },
        chargeable: chargeable
      }

      purchase, error = Purchase::CreateService.new(product: product, params: params).perform

      if error
        puts "Error creating purchase for buyer #{buyer_number}: #{error}"
      else
        # Update created_at to spread purchases throughout the day
        purchase.update_columns(created_at: purchase_time, updated_at: purchase_time)
        purchases << purchase
        puts "Created purchase #{buyer_number}/10 for Installment Widget"
        puts "  Purchase ID: #{purchase.id}, State: #{purchase.purchase_state}, Created at: #{purchase_time}"
      end
    else
      purchase = Purchase.find_by(link_id: product.id, purchaser_id: buyer.id)
      purchases << purchase if purchase
      puts "Purchase #{buyer_number}/10 already exists, skipping"
    end
  end

  # Set created_after to 1 day after the last purchase
  purchase_created_at = last_purchase_time || Time.current
  created_after_date = (purchase_created_at + 1.day).to_date

  puts "\nAll purchases created within a single day. Setting created_after filter to: #{created_after_date}"

  Installment.find_or_create_by!(
    name: "Welcome to Installment Widget!",
    link_id: product.id,
    seller_id: seller.id
  ) do |installment|
    installment.message = "<p>Welcome to Installment Widget! This is an amazing product that will help you create beautiful content.</p><p>We're excited to have you as part of our community!</p>"
    installment.installment_type = Installment::PRODUCT_TYPE
    installment.published_at = Time.current
    installment.send_emails = true
    installment.shown_on_profile = true
    installment.allow_comments = true
    installment.created_after = created_after_date
  end

  Installment.find_or_create_by!(
    name: "New Features Available",
    link_id: product.id,
    seller_id: seller.id
  ) do |installment|
    installment.message = "<p>We've just released some amazing new features for Installment Widget!</p><p>Check them out and let us know what you think.</p>"
    installment.installment_type = Installment::PRODUCT_TYPE
    installment.published_at = Time.current
    installment.send_emails = true
    installment.shown_on_profile = true
    installment.allow_comments = true
    installment.created_after = created_after_date
  end

  Installment.find_or_create_by!(
    name: "Tips and Tricks for Installment Widget",
    link_id: product.id,
    seller_id: seller.id
  ) do |installment|
    installment.message = "<p>Here are some tips and tricks to get the most out of Installment Widget:</p><ul><li>Use the advanced settings for better results</li><li>Customize your posts to match your brand</li><li>Share your creations with the community</li></ul>"
    installment.installment_type = Installment::PRODUCT_TYPE
    installment.published_at = Time.current
    installment.send_emails = true
    installment.shown_on_profile = true
    installment.allow_comments = true
    installment.created_after = created_after_date
  end

  5.times do |n|
    post_number = n + 1
    days_from_now = post_number + post_number + 1
    to_be_published_at = days_from_now.days.from_now

    installment = Installment.find_or_create_by!(
      name: "Scheduled Post #{post_number} - Installment Widget Update",
      link_id: product.id,
      seller_id: seller.id
    ) do |inst|
      inst.message = "<p>This is scheduled post #{post_number} for Installment Widget!</p><p>This post will be published in #{days_from_now} days.</p>"
      inst.installment_type = Installment::PRODUCT_TYPE
      inst.send_emails = true
      inst.shown_on_profile = true
      inst.allow_comments = true
      inst.ready_to_publish = true
      inst.published_at = nil
      inst.created_after = created_after_date
    end

    installment_rule = installment.installment_rule || installment.build_installment_rule
    if installment_rule.to_be_published_at != to_be_published_at
      installment_rule.to_be_published_at = to_be_published_at
      installment_rule.version ||= 1
      installment_rule.save!

      PublishScheduledPostJob.perform_at(to_be_published_at, installment.id, installment_rule.version)
      puts "Created/updated scheduled post #{post_number} to be published in #{days_from_now} days (#{to_be_published_at})"
    else
      puts "Scheduled post #{post_number} already exists with correct schedule"
    end
  end

  # ============================================================================
  # WORKFLOW 1: Purchase Workflow - Terms of Service (1 hour after purchase)
  # ============================================================================
  # PROTECTION: Uses .alive.find_by to only find non-deleted workflows, preventing
  # reuse of soft-deleted workflows. Creates new workflow if none exists, or
  # updates existing one if it has wrong attributes.
  # NOTE: This is a SELLER-level workflow that applies to ALL products

  purchase_workflow = Workflow.alive.find_by(
    name: "Terms of Service",
    seller_id: seller.id,
    link_id: nil
  )

  if purchase_workflow.nil?
    purchase_workflow = Workflow.new(
      name: "Terms of Service",
      seller_id: seller.id,
      link_id: nil,
      workflow_type: Workflow::SELLER_TYPE,
      workflow_trigger: nil,
      published_at: Time.current,
      send_to_past_customers: false
    )
    purchase_workflow.save!
  elsif purchase_workflow.workflow_trigger != nil || purchase_workflow.workflow_type != Workflow::SELLER_TYPE
    purchase_workflow.workflow_type = Workflow::SELLER_TYPE
    purchase_workflow.link_id = nil
    purchase_workflow.workflow_trigger = nil
    purchase_workflow.published_at = Time.current unless purchase_workflow.published_at.present?
    purchase_workflow.send_to_past_customers = false
    purchase_workflow.save!
  elsif purchase_workflow.published_at.nil?
    purchase_workflow.update_columns(
      workflow_type: Workflow::SELLER_TYPE,
      link_id: nil,
      workflow_trigger: nil,
      published_at: Time.current
    )
  end

  tos_installment = Installment.find_or_create_by!(
    name: "Terms of Service",
    workflow_id: purchase_workflow.id,
    seller_id: seller.id,
    link_id: nil
  ) do |installment|
    installment.message = "<p>Thank you for your purchase!</p><p>Please review our Terms of Service:</p><ul><li>All sales are final</li><li>No refunds after 30 days</li><li>Product is provided as-is</li></ul><p>If you have any questions, please contact us.</p>"
    installment.installment_type = Installment::SELLER_TYPE
    installment.published_at = Time.current
    installment.send_emails = true
    installment.shown_on_profile = false
    installment.allow_comments = false
  end

  tos_installment.update_columns(
    published_at: Time.current,
    send_emails: true,
    installment_type: Installment::SELLER_TYPE,
    link_id: nil
  ) unless tos_installment.published_at.present?

  tos_rule = tos_installment.installment_rule || tos_installment.build_installment_rule
  if tos_rule.delayed_delivery_time != 1.hour.to_i
    tos_rule.time_period = InstallmentRule::HOUR
    tos_rule.delayed_delivery_time = 1.hour.to_i
    tos_rule.version ||= 1
    tos_rule.save!
  end

  puts "\nCreated seller-level purchase workflow: Terms of Service (sends 1 hour after purchase for ALL products)"

  # ============================================================================
  # WORKFLOW 2: Member Cancellation Workflow (0 hours and 24 hours after cancel)
  # ============================================================================
  # PROTECTION: Uses .alive.find_by to only find non-deleted workflows, preventing
  # reuse of soft-deleted workflows. Creates new workflow if none exists, or
  # updates existing one if it has wrong trigger type.

  cancellation_workflow = Workflow.alive.find_by(
    name: "Installment Widget - Member Cancellation",
    seller_id: seller.id,
    link_id: product.id
  )

  if cancellation_workflow.nil?
    cancellation_workflow = Workflow.new(
      name: "Installment Widget - Member Cancellation",
      seller_id: seller.id,
      link_id: product.id,
      workflow_type: Workflow::PRODUCT_TYPE,
      workflow_trigger: Workflow::MEMBER_CANCELLATION_WORKFLOW_TRIGGER,
      published_at: Time.current,
      send_to_past_customers: false
    )
    cancellation_workflow.save!
  elsif cancellation_workflow.workflow_trigger != Workflow::MEMBER_CANCELLATION_WORKFLOW_TRIGGER
    cancellation_workflow.workflow_type = Workflow::PRODUCT_TYPE
    cancellation_workflow.workflow_trigger = Workflow::MEMBER_CANCELLATION_WORKFLOW_TRIGGER
    cancellation_workflow.published_at = Time.current unless cancellation_workflow.published_at.present?
    cancellation_workflow.send_to_past_customers = false
    cancellation_workflow.save!
  elsif cancellation_workflow.published_at.nil?
    cancellation_workflow.update_columns(
      workflow_type: Workflow::PRODUCT_TYPE,
      workflow_trigger: Workflow::MEMBER_CANCELLATION_WORKFLOW_TRIGGER,
      published_at: Time.current
    )
  end

  cancel_email_1 = Installment.find_or_create_by!(
    name: "We're Sorry to See You Go",
    workflow_id: cancellation_workflow.id,
    seller_id: seller.id,
    link_id: product.id
  ) do |installment|
    installment.message = "<p>We're sorry to see you cancel your subscription to Installment Widget.</p><p>Your access will remain active until the end of your billing period.</p><p>If you change your mind, you can resubscribe anytime!</p>"
    installment.installment_type = Installment::PRODUCT_TYPE
    installment.published_at = Time.current
    installment.send_emails = true
    installment.shown_on_profile = false
    installment.allow_comments = false
  end

  cancel_email_1.update_columns(
    published_at: Time.current,
    send_emails: true
  ) unless cancel_email_1.published_at.present?

  cancel_rule_1 = cancel_email_1.installment_rule || cancel_email_1.build_installment_rule
  if cancel_rule_1.delayed_delivery_time != 0
    cancel_rule_1.time_period = InstallmentRule::HOUR
    cancel_rule_1.delayed_delivery_time = 0
    cancel_rule_1.version ||= 1
    cancel_rule_1.save!
  end

  cancel_email_2 = Installment.find_or_create_by!(
    name: "Last Chance - Special Offer",
    workflow_id: cancellation_workflow.id,
    seller_id: seller.id,
    link_id: product.id
  ) do |installment|
    installment.message = "<p>We noticed you cancelled your subscription to Installment Widget.</p><p>As a special offer, we'd like to give you 20% off if you resubscribe within the next 7 days.</p><p>Use code: SAVE20</p><p>We hope to see you back soon!</p>"
    installment.installment_type = Installment::PRODUCT_TYPE
    installment.published_at = Time.current
    installment.send_emails = true
    installment.shown_on_profile = false
    installment.allow_comments = false
  end

  cancel_email_2.update_columns(
    published_at: Time.current,
    send_emails: true
  ) unless cancel_email_2.published_at.present?

  cancel_rule_2 = cancel_email_2.installment_rule || cancel_email_2.build_installment_rule
  if cancel_rule_2.delayed_delivery_time != 24.hours.to_i
    cancel_rule_2.time_period = InstallmentRule::HOUR
    cancel_rule_2.delayed_delivery_time = 24.hours.to_i
    cancel_rule_2.version ||= 1
    cancel_rule_2.save!
  end

  puts "Created member cancellation workflow: 2 emails (0 hours and 24 hours after cancel)"
  puts "  - Email 1: 'We're Sorry to See You Go' (immediate)"
  puts "  - Email 2: 'Last Chance - Special Offer' (24 hours later)"

  puts "\nCreated Installment Widget product with #{product.installments.count} posts"
  puts "Total purchases created: #{Purchase.where(link_id: product.id).count}"
  puts "All purchases created within: #{Purchase.where(link_id: product.id).minimum(:created_at).to_date} to #{Purchase.where(link_id: product.id).maximum(:created_at).to_date}"

  # ============================================================================
  # BEAUTIFUL WIDGET WORKFLOWS: Purchase Workflow with 2 emails
  # ============================================================================
  # PROTECTION: Uses .alive.find_by to only find non-deleted workflows, preventing
  # reuse of soft-deleted workflows. Creates new workflow if none exists, or
  # updates existing one if it has wrong attributes.

  beautiful_widget = Link.find_by(unique_permalink: "demo", user_id: seller.id)
  if beautiful_widget.present?
    beautiful_purchase_workflow = Workflow.alive.find_by(
      name: "Beautiful widget - Purchase Welcome",
      seller_id: seller.id,
      link_id: beautiful_widget.id
    )

    if beautiful_purchase_workflow.nil?
      beautiful_purchase_workflow = Workflow.new(
        name: "Beautiful widget - Purchase Welcome",
        seller_id: seller.id,
        link_id: beautiful_widget.id,
        workflow_type: Workflow::PRODUCT_TYPE,
        workflow_trigger: nil,
        published_at: Time.current,
        send_to_past_customers: false
      )
      beautiful_purchase_workflow.save!
    elsif beautiful_purchase_workflow.workflow_type != Workflow::PRODUCT_TYPE || beautiful_purchase_workflow.link_id != beautiful_widget.id
      beautiful_purchase_workflow.workflow_type = Workflow::PRODUCT_TYPE
      beautiful_purchase_workflow.link_id = beautiful_widget.id
      beautiful_purchase_workflow.workflow_trigger = nil
      beautiful_purchase_workflow.published_at = Time.current unless beautiful_purchase_workflow.published_at.present?
      beautiful_purchase_workflow.send_to_past_customers = false
      beautiful_purchase_workflow.save!
    elsif beautiful_purchase_workflow.published_at.nil?
      beautiful_purchase_workflow.update_columns(
        workflow_type: Workflow::PRODUCT_TYPE,
        link_id: beautiful_widget.id,
        workflow_trigger: nil,
        published_at: Time.current
      )
    end

    beautiful_email_1 = Installment.find_or_create_by!(
      name: "Welcome to Beautiful widget!",
      workflow_id: beautiful_purchase_workflow.id,
      seller_id: seller.id,
      link_id: beautiful_widget.id
    ) do |installment|
      installment.message = "<p>Thank you for purchasing Beautiful widget!</p><p>We're excited to have you as part of our community.</p><p>If you have any questions, please contact us.</p>"
      installment.installment_type = Installment::PRODUCT_TYPE
      installment.published_at = Time.current
      installment.send_emails = true
      installment.shown_on_profile = false
      installment.allow_comments = false
    end

    beautiful_email_1.update_columns(
      published_at: Time.current,
      send_emails: true,
      installment_type: Installment::PRODUCT_TYPE,
      link_id: beautiful_widget.id
    ) unless beautiful_email_1.published_at.present?

    beautiful_rule_1 = beautiful_email_1.installment_rule || beautiful_email_1.build_installment_rule
    if beautiful_rule_1.delayed_delivery_time != 1.hour.to_i
      beautiful_rule_1.time_period = InstallmentRule::HOUR
      beautiful_rule_1.delayed_delivery_time = 1.hour.to_i
      beautiful_rule_1.version ||= 1
      beautiful_rule_1.save!
    end

    beautiful_email_2 = Installment.find_or_create_by!(
      name: "Beautiful widget - Getting Started Guide",
      workflow_id: beautiful_purchase_workflow.id,
      seller_id: seller.id,
      link_id: beautiful_widget.id
    ) do |installment|
      installment.message = "<p>Here's your getting started guide for Beautiful widget!</p><p>We've prepared some tips and tricks to help you get the most out of your purchase.</p><p>Enjoy!</p>"
      installment.installment_type = Installment::PRODUCT_TYPE
      installment.published_at = Time.current
      installment.send_emails = true
      installment.shown_on_profile = false
      installment.allow_comments = false
    end

    beautiful_email_2.update_columns(
      published_at: Time.current,
      send_emails: true,
      installment_type: Installment::PRODUCT_TYPE,
      link_id: beautiful_widget.id
    ) unless beautiful_email_2.published_at.present?

    beautiful_rule_2 = beautiful_email_2.installment_rule || beautiful_email_2.build_installment_rule
    if beautiful_rule_2.delayed_delivery_time != 24.hours.to_i
      beautiful_rule_2.time_period = InstallmentRule::HOUR
      beautiful_rule_2.delayed_delivery_time = 24.hours.to_i
      beautiful_rule_2.version ||= 1
      beautiful_rule_2.save!
    end

    puts "\nCreated/verified Beautiful widget purchase workflow: 2 emails (1 hour and 24 hours after purchase)"
    puts "  - Email 1: 'Welcome to Beautiful widget!' (1 hour after purchase)"
    puts "  - Email 2: 'Beautiful widget - Getting Started Guide' (24 hours after purchase)"
  end

  # ============================================================================
  # BUNDLE PRODUCT: Widget Essentials Bundle with Installment Plan
  # ============================================================================
  # PROTECTION: All records use find_or_create_by or existence checks to prevent
  # recreation or overwriting of existing records

  bundle = Link.find_or_create_by!(name: "Widget Essentials Bundle", user_id: seller.id, deleted_at: nil) do |link|
    link.description = "A bundle containing the Installment Widget with amazing features and installment plan support"
    link.filetype = "link"
    link.price_cents = 149999
    link.display_product_reviews = true
    link.customizable_price = false
  end

  if bundle.prices.empty?
    price = bundle.prices.build(price_cents: bundle.price_cents)
    price.recurrence = 0
    bundle.save!
  end

  bundle.tag!("bundle") unless bundle.tags.exists?(name: "bundle")
  bundle.tag!("widget") unless bundle.tags.exists?(name: "widget")

  unless bundle.is_bundle?
    bundle.is_bundle = true
    bundle.native_type = Link::NATIVE_TYPE_BUNDLE
    bundle.customizable_price = false
    bundle.save!(validate: false)
    bundle.reload
  end

  unless bundle.bundle_products.alive.exists?(product_id: product.id)
    BundleProduct.create!(
      bundle: bundle,
      product: product,
      variant: product.alive_variants.first,
      quantity: 1
    )
    puts "\nAdded Installment Widget to bundle"
  else
    puts "\nBundle already contains Installment Widget"
  end

  beautiful_widget = Link.find_by(unique_permalink: "demo", user_id: seller.id)
  if beautiful_widget.present?
    unless bundle.bundle_products.alive.exists?(product_id: beautiful_widget.id)
      BundleProduct.create!(
        bundle: bundle,
        product: beautiful_widget,
        variant: beautiful_widget.alive_variants.first,
        quantity: 1,
        position: 2
      )
      puts "Added Beautiful widget to bundle"
    else
      puts "Bundle already contains Beautiful widget"
    end
  end

  if bundle.installment_plan.nil?
    bundle.create_installment_plan!(
      number_of_installments: 3,
      recurrence: "monthly"
    )
    puts "Created installment plan for bundle: 3 monthly installments"
  else
    puts "Bundle already has installment plan: #{bundle.installment_plan.number_of_installments} installments, #{bundle.installment_plan.recurrence} recurrence"
  end

  # Create 3 purchases for the bundle AFTER all installment purchases are complete
  # Installment purchases: 10 purchases, 2 hours apart, starting at 8:00 AM
  # Last installment purchase: 8:00 AM + (9 * 2) hours = 2:00 AM next day
  # Bundle purchases start at 3:00 AM next day (spread 3 hours apart)
  # PROTECTION: Checks if purchase already exists before creating to prevent duplicates

  # Verify bundle and workflows exist before creating purchases
  unless bundle.is_bundle?
    puts "\n⚠️  WARNING: Bundle is not marked as bundle. Updating..."
    bundle.update_columns(is_bundle: true, native_type: Link::NATIVE_TYPE_BUNDLE)
  end

  bundle_workflows = Workflow.alive.where(link_id: bundle.id)
  if bundle_workflows.empty?
    puts "\n⚠️  WARNING: No workflows found for bundle. Bundle purchases may not work correctly."
  else
    puts "\n✅ Verified bundle has #{bundle_workflows.count} workflow(s) linked"
  end

  bundle_products_count = bundle.bundle_products.alive.count
  if bundle_products_count == 0
    puts "\n⚠️  WARNING: No products in bundle. Bundle purchases will fail."
  else
    puts "✅ Verified bundle has #{bundle_products_count} product(s)"
  end

  last_installment_purchase_time = base_time + (9 * 2).hours
  bundle_base_time = last_installment_purchase_time + 1.hour
  bundle_purchases = []
  bundle_last_purchase_time = nil

  3.times do |n|
    buyer_number = n + 11
    buyer_email = "buyer#{buyer_number}@gumroad.com"

    buyer = User.find_or_create_by!(email: buyer_email) do |user|
      user.name = "Test Buyer #{buyer_number}"
      user.username = "testbuyer#{buyer_number}"
      user.password = SecureRandom.hex(24)
      user.user_risk_state = "compliant"
      user.confirmed_at = Time.current
      user.save!(validate: false)
      user.password = "password"
      user.save!(validate: false)
    end

    bundle_purchase_time = bundle_base_time + (n * 3).hours
    bundle_last_purchase_time = bundle_purchase_time

    unless Purchase.exists?(link_id: bundle.id, purchaser_id: buyer.id)
      chargeable = CardParamsHelper.build_chargeable(
        StripePaymentMethodHelper.success.with_zip_code("12345").to_stripejs_params,
        SecureRandom.uuid
      )

      bundle_products_params = bundle.bundle_products.alive.map do |bp|
        {
          product_id: bp.product.external_id,
          variant_id: bp.variant&.external_id,
          quantity: bp.quantity
        }
      end

      params = {
        purchase: {
          email: buyer.email,
          quantity: 1,
          perceived_price_cents: bundle.price_cents,
          ip_address: "127.0.0.1",
          session_id: SecureRandom.hex(16),
          is_mobile: false,
          browser_guid: SecureRandom.uuid
        },
        bundle_products: bundle_products_params,
        chargeable: chargeable,
        pay_in_installments: false
      }

      purchase, error = Purchase::CreateService.new(product: bundle, params: params).perform

      if error
        puts "Error creating bundle purchase for buyer #{buyer_number}: #{error}"
      else
        purchase.update_columns(created_at: bundle_purchase_time, updated_at: bundle_purchase_time)
        bundle_purchases << purchase
        puts "Created bundle purchase #{n + 1}/3 for Widget Essentials Bundle"
        puts "  Purchase ID: #{purchase.id}, State: #{purchase.purchase_state}, Created at: #{bundle_purchase_time}"
        puts "  Is bundle purchase: #{purchase.is_bundle_purchase?}, Is installment payment: #{purchase.is_installment_payment?}"
      end
    else
      existing_purchase = Purchase.find_by(link_id: bundle.id, purchaser_id: buyer.id)
      bundle_purchases << existing_purchase if existing_purchase
      puts "Bundle purchase #{n + 1}/3 already exists, skipping (idempotent)"
    end
  end

  bundle_purchase_created_at = bundle_last_purchase_time || Time.current
  bundle_created_after_date = (bundle_purchase_created_at + 1.day).to_date

  puts "\nAll bundle purchases created within a single day. Setting created_after filter to: #{bundle_created_after_date}"

  Installment.find_or_create_by!(
    name: "Welcome to Widget Essentials Bundle!",
    link_id: bundle.id,
    seller_id: seller.id
  ) do |installment|
    installment.message = "<p>Welcome to the Widget Essentials Bundle!</p><p>This bundle includes the amazing Installment Widget and more.</p><p>We're excited to have you as part of our community!</p>"
    installment.installment_type = Installment::PRODUCT_TYPE
    installment.published_at = Time.current
    installment.send_emails = true
    installment.shown_on_profile = true
    installment.allow_comments = true
    installment.created_after = bundle_created_after_date
  end

  Installment.find_or_create_by!(
    name: "Bundle Features Update",
    link_id: bundle.id,
    seller_id: seller.id
  ) do |installment|
    installment.message = "<p>We've just released some amazing new features for the Widget Essentials Bundle!</p><p>Check them out and let us know what you think.</p>"
    installment.installment_type = Installment::PRODUCT_TYPE
    installment.published_at = Time.current
    installment.send_emails = true
    installment.shown_on_profile = true
    installment.allow_comments = true
    installment.created_after = bundle_created_after_date
  end

  3.times do |n|
    post_number = n + 1
    days_from_now = post_number * 2 + 1
    to_be_published_at = days_from_now.days.from_now

    installment = Installment.find_or_create_by!(
      name: "Scheduled Bundle Post #{post_number} - Update",
      link_id: bundle.id,
      seller_id: seller.id
    ) do |inst|
      inst.message = "<p>This is scheduled post #{post_number} for the Widget Essentials Bundle!</p><p>This post will be published in #{days_from_now} days.</p>"
      inst.installment_type = Installment::PRODUCT_TYPE
      inst.send_emails = true
      inst.shown_on_profile = true
      inst.allow_comments = true
      inst.ready_to_publish = true
      inst.published_at = nil
      inst.created_after = bundle_created_after_date
    end

    installment_rule = installment.installment_rule || installment.build_installment_rule
    if installment_rule.to_be_published_at != to_be_published_at
      installment_rule.to_be_published_at = to_be_published_at
      installment_rule.version ||= 1
      installment_rule.save!

      PublishScheduledPostJob.perform_at(to_be_published_at, installment.id, installment_rule.version)
      puts "Created/updated scheduled bundle post #{post_number} to be published in #{days_from_now} days (#{to_be_published_at})"
    else
      puts "Scheduled bundle post #{post_number} already exists with correct schedule"
    end
  end

  # ============================================================================
  # BUNDLE WORKFLOW 1: Purchase Workflow - Bundle Welcome (2 hours after purchase)
  # ============================================================================
  # PROTECTION: Uses .alive.find_by to only find non-deleted workflows, preventing
  # reuse of soft-deleted workflows. Creates new workflow if none exists, or
  # updates existing one if it has wrong attributes.

  bundle_purchase_workflow = Workflow.alive.find_by(
    name: "Widget Essentials Bundle - Purchase Welcome",
    seller_id: seller.id,
    link_id: bundle.id
  )

  if bundle_purchase_workflow.nil?
    bundle_purchase_workflow = Workflow.new(
      name: "Widget Essentials Bundle - Purchase Welcome",
      seller_id: seller.id,
      link_id: bundle.id,
      workflow_type: Workflow::PRODUCT_TYPE,
      workflow_trigger: nil,
      published_at: Time.current,
      send_to_past_customers: false
    )
    bundle_purchase_workflow.save!
  elsif bundle_purchase_workflow.workflow_type != Workflow::PRODUCT_TYPE || bundle_purchase_workflow.link_id != bundle.id
    bundle_purchase_workflow.workflow_type = Workflow::PRODUCT_TYPE
    bundle_purchase_workflow.link_id = bundle.id
    bundle_purchase_workflow.workflow_trigger = nil
    bundle_purchase_workflow.published_at = Time.current unless bundle_purchase_workflow.published_at.present?
    bundle_purchase_workflow.send_to_past_customers = false
    bundle_purchase_workflow.save!
  elsif bundle_purchase_workflow.published_at.nil?
    bundle_purchase_workflow.update_columns(
      workflow_type: Workflow::PRODUCT_TYPE,
      link_id: bundle.id,
      workflow_trigger: nil,
      published_at: Time.current
    )
  end

  bundle_welcome_installment = Installment.find_or_create_by!(
    name: "Bundle Welcome Email",
    workflow_id: bundle_purchase_workflow.id,
    seller_id: seller.id,
    link_id: bundle.id
  ) do |installment|
    installment.message = "<p>Thank you for purchasing the Widget Essentials Bundle!</p><p>You now have access to all the amazing features included in this bundle.</p><p>If you have any questions, please contact us.</p>"
    installment.installment_type = Installment::PRODUCT_TYPE
    installment.published_at = Time.current
    installment.send_emails = true
    installment.shown_on_profile = false
    installment.allow_comments = false
  end

  bundle_welcome_installment.update_columns(
    published_at: Time.current,
    send_emails: true,
    installment_type: Installment::PRODUCT_TYPE,
    link_id: bundle.id
  ) unless bundle_welcome_installment.published_at.present?

  bundle_welcome_rule = bundle_welcome_installment.installment_rule || bundle_welcome_installment.build_installment_rule
  if bundle_welcome_rule.delayed_delivery_time != 2.hours.to_i
    bundle_welcome_rule.time_period = InstallmentRule::HOUR
    bundle_welcome_rule.delayed_delivery_time = 2.hours.to_i
    bundle_welcome_rule.version ||= 1
    bundle_welcome_rule.save!
  end

  puts "\nCreated/verified bundle purchase workflow: Widget Essentials Bundle - Purchase Welcome (sends 2 hours after purchase)"

  # ============================================================================
  # BUNDLE WORKFLOW 2: Member Cancellation Workflow (0 hours and 48 hours after cancel)
  # ============================================================================
  # PROTECTION: Uses .alive.find_by to only find non-deleted workflows, preventing
  # reuse of soft-deleted workflows. Creates new workflow if none exists, or
  # updates existing one if it has wrong trigger type.

  bundle_cancellation_workflow = Workflow.alive.find_by(
    name: "Widget Essentials Bundle - Member Cancellation",
    seller_id: seller.id,
    link_id: bundle.id
  )

  if bundle_cancellation_workflow.nil?
    bundle_cancellation_workflow = Workflow.new(
      name: "Widget Essentials Bundle - Member Cancellation",
      seller_id: seller.id,
      link_id: bundle.id,
      workflow_type: Workflow::PRODUCT_TYPE,
      workflow_trigger: Workflow::MEMBER_CANCELLATION_WORKFLOW_TRIGGER,
      published_at: Time.current,
      send_to_past_customers: false
    )
    bundle_cancellation_workflow.save!
  elsif bundle_cancellation_workflow.workflow_trigger != Workflow::MEMBER_CANCELLATION_WORKFLOW_TRIGGER
    bundle_cancellation_workflow.workflow_type = Workflow::PRODUCT_TYPE
    bundle_cancellation_workflow.workflow_trigger = Workflow::MEMBER_CANCELLATION_WORKFLOW_TRIGGER
    bundle_cancellation_workflow.published_at = Time.current unless bundle_cancellation_workflow.published_at.present?
    bundle_cancellation_workflow.send_to_past_customers = false
    bundle_cancellation_workflow.save!
  elsif bundle_cancellation_workflow.published_at.nil?
    bundle_cancellation_workflow.update_columns(
      workflow_type: Workflow::PRODUCT_TYPE,
      workflow_trigger: Workflow::MEMBER_CANCELLATION_WORKFLOW_TRIGGER,
      published_at: Time.current
    )
  end

  bundle_cancel_email_1 = Installment.find_or_create_by!(
    name: "Bundle Cancellation - We're Sorry",
    workflow_id: bundle_cancellation_workflow.id,
    seller_id: seller.id,
    link_id: bundle.id
  ) do |installment|
    installment.message = "<p>We're sorry to see you cancel your subscription to the Widget Essentials Bundle.</p><p>Your access will remain active until the end of your billing period.</p><p>If you change your mind, you can resubscribe anytime!</p>"
    installment.installment_type = Installment::PRODUCT_TYPE
    installment.published_at = Time.current
    installment.send_emails = true
    installment.shown_on_profile = false
    installment.allow_comments = false
  end

  bundle_cancel_email_1.update_columns(
    published_at: Time.current,
    send_emails: true
  ) unless bundle_cancel_email_1.published_at.present?

  bundle_cancel_rule_1 = bundle_cancel_email_1.installment_rule || bundle_cancel_email_1.build_installment_rule
  if bundle_cancel_rule_1.delayed_delivery_time != 0
    bundle_cancel_rule_1.time_period = InstallmentRule::HOUR
    bundle_cancel_rule_1.delayed_delivery_time = 0
    bundle_cancel_rule_1.version ||= 1
    bundle_cancel_rule_1.save!
  end

  bundle_cancel_email_2 = Installment.find_or_create_by!(
    name: "Bundle Cancellation - Special Offer",
    workflow_id: bundle_cancellation_workflow.id,
    seller_id: seller.id,
    link_id: bundle.id
  ) do |installment|
    installment.message = "<p>We noticed you cancelled your subscription to the Widget Essentials Bundle.</p><p>As a special offer, we'd like to give you 25% off if you resubscribe within the next 7 days.</p><p>Use code: BUNDLE25</p><p>We hope to see you back soon!</p>"
    installment.installment_type = Installment::PRODUCT_TYPE
    installment.published_at = Time.current
    installment.send_emails = true
    installment.shown_on_profile = false
    installment.allow_comments = false
  end

  bundle_cancel_email_2.update_columns(
    published_at: Time.current,
    send_emails: true
  ) unless bundle_cancel_email_2.published_at.present?

  bundle_cancel_rule_2 = bundle_cancel_email_2.installment_rule || bundle_cancel_email_2.build_installment_rule
  if bundle_cancel_rule_2.delayed_delivery_time != 48.hours.to_i
    bundle_cancel_rule_2.time_period = InstallmentRule::HOUR
    bundle_cancel_rule_2.delayed_delivery_time = 48.hours.to_i
    bundle_cancel_rule_2.version ||= 1
    bundle_cancel_rule_2.save!
  end

  puts "Created/verified bundle member cancellation workflow: 2 emails (0 hours and 48 hours after cancel)"
  puts "  - Email 1: 'Bundle Cancellation - We're Sorry' (immediate)"
  puts "  - Email 2: 'Bundle Cancellation - Special Offer' (48 hours later)"

  puts "\nCreated/verified Widget Essentials Bundle with #{bundle.installments.count} posts"
  puts "Bundle includes: Installment Widget"
  puts "Bundle installment plan: #{bundle.installment_plan.number_of_installments} installments, #{bundle.installment_plan.recurrence} recurrence"
  puts "Total bundle purchases created: #{Purchase.where(link_id: bundle.id).count}"
  puts "All bundle purchases created within: #{Purchase.where(link_id: bundle.id).minimum(:created_at).to_date} to #{Purchase.where(link_id: bundle.id).maximum(:created_at).to_date}"
  bundle_purchases_are_installments = Purchase.where(link_id: bundle.id).any?(&:is_installment_payment?)
  puts "Bundle purchases are installment payments: #{bundle_purchases_are_installments} (should be false)"
end

create_beautiful_widget_with_posts_and_installment_plan
