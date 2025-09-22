# frozen_string_literal: true

# ============================================================================
# Bundle Cleanup Script for seller@gumroad.com
# ============================================================================
#
# This script removes all bundle-related records for seller@gumroad.com,
# including soft-deleted records. It deletes records in the correct order
# to avoid foreign key violations.
#
# HOW TO RUN:
#   In Rails console:
#     load 'db/seeds/040_development/cleanup_bundles.rb'
#
# ============================================================================

def cleanup_bundles_for_seller
  seller = User.find_by(email: "seller@gumroad.com")

  unless seller
    puts "❌ Seller seller@gumroad.com not found"
    return
  end

  puts "\n🔍 Finding all bundles for seller@gumroad.com (including soft-deleted)..."

  bundles = Link.unscoped.where(user_id: seller.id).is_bundle
  bundle_ids = bundles.pluck(:id)

  if bundle_ids.empty?
    puts "✅ No bundles found for seller@gumroad.com"
    return
  end

  puts "📦 Found #{bundle_ids.count} bundle(s): #{bundle_ids.join(', ')}"
  puts "\n🗑️  Starting deletion process...\n"

  deleted_counts = {}

  # Get bundle purchase IDs first
  bundle_purchases = Purchase.unscoped.where(link_id: bundle_ids)
  bundle_purchase_ids = bundle_purchases.pluck(:id)

  # Get product purchase IDs (bundle product purchases) linked to these bundle purchases
  product_purchase_ids = []
  if bundle_purchase_ids.any?
    product_purchase_ids = BundleProductPurchase.where(bundle_purchase_id: bundle_purchase_ids).pluck(:product_purchase_id).compact.uniq
  end

  # 1. Delete EmailInfo records for product purchases (must be before deleting purchases)
  if product_purchase_ids.any?
    deleted_counts[:email_infos] = EmailInfo.unscoped.where(purchase_id: product_purchase_ids).delete_all
    puts "  ✓ Deleted #{deleted_counts[:email_infos]} EmailInfo record(s) for product purchases"
  else
    deleted_counts[:email_infos] = 0
    puts "  ✓ No EmailInfo records to delete"
  end

  # 2. Delete UrlRedirect records for product purchases (must be before deleting purchases)
  if product_purchase_ids.any?
    deleted_counts[:url_redirects] = UrlRedirect.unscoped.where(purchase_id: product_purchase_ids).delete_all
    puts "  ✓ Deleted #{deleted_counts[:url_redirects]} UrlRedirect record(s) for product purchases"
  else
    deleted_counts[:url_redirects] = 0
    puts "  ✓ No UrlRedirect records to delete"
  end

  # 3. Delete License records for product purchases (must be before deleting purchases)
  if product_purchase_ids.any?
    deleted_counts[:licenses] = License.unscoped.where(purchase_id: product_purchase_ids).delete_all
    puts "  ✓ Deleted #{deleted_counts[:licenses]} License record(s) for product purchases"
  else
    deleted_counts[:licenses] = 0
    puts "  ✓ No License records to delete"
  end

  # 4. Delete BundleProductPurchase records (both directions - must be before deleting purchases)
  if bundle_purchase_ids.any?
    deleted_counts[:bundle_product_purchases] = BundleProductPurchase.where(bundle_purchase_id: bundle_purchase_ids).delete_all
    puts "  ✓ Deleted #{deleted_counts[:bundle_product_purchases]} BundleProductPurchase record(s)"
  else
    deleted_counts[:bundle_product_purchases] = 0
    puts "  ✓ No BundleProductPurchase records to delete"
  end

  # 5. Delete product purchase records (bundle product purchases)
  if product_purchase_ids.any?
    deleted_counts[:product_purchases] = Purchase.unscoped.where(id: product_purchase_ids).delete_all
    puts "  ✓ Deleted #{deleted_counts[:product_purchases]} Product purchase record(s) (bundle product purchases)"
  else
    deleted_counts[:product_purchases] = 0
    puts "  ✓ No product purchase records to delete"
  end

  # 6. Get bundle_product_ids before deletion for PurchaseCustomField cleanup
  bundle_product_ids = BundleProduct.unscoped.where(bundle_id: bundle_ids).pluck(:id)

  # 7. Delete PurchaseCustomField records that reference bundle_products
  if bundle_product_ids.any?
    deleted_counts[:purchase_custom_fields] = PurchaseCustomField.where(bundle_product_id: bundle_product_ids).delete_all
    puts "  ✓ Deleted #{deleted_counts[:purchase_custom_fields]} PurchaseCustomField record(s) referencing bundle products"
  else
    deleted_counts[:purchase_custom_fields] = 0
    puts "  ✓ No PurchaseCustomField records to delete"
  end

  # 8. Delete BundleProduct records (linked via bundle_id)
  deleted_counts[:bundle_products] = BundleProduct.unscoped.where(bundle_id: bundle_ids).delete_all
  puts "  ✓ Deleted #{deleted_counts[:bundle_products]} BundleProduct record(s)"

  # 9. Delete ProductInstallmentPlan records (linked via link_id)
  deleted_counts[:installment_plans] = ProductInstallmentPlan.unscoped.where(link_id: bundle_ids).delete_all
  puts "  ✓ Deleted #{deleted_counts[:installment_plans]} ProductInstallmentPlan record(s)"

  # 10. Get installment_ids before deletion for InstallmentRule cleanup
  installment_ids = Installment.unscoped.where(link_id: bundle_ids).pluck(:id)

  # 11. Delete InstallmentRule records (linked via installment_id)
  if installment_ids.any?
    deleted_counts[:installment_rules] = InstallmentRule.unscoped.where(installment_id: installment_ids).delete_all
    puts "  ✓ Deleted #{deleted_counts[:installment_rules]} InstallmentRule record(s)"
  else
    deleted_counts[:installment_rules] = 0
    puts "  ✓ No InstallmentRule records to delete"
  end

  # 12. Delete Installment records (linked via link_id)
  deleted_counts[:installments] = Installment.unscoped.where(link_id: bundle_ids).delete_all
  puts "  ✓ Deleted #{deleted_counts[:installments]} Installment record(s)"

  # 13. Delete Purchase records (bundle purchases)
  deleted_counts[:purchases] = Purchase.unscoped.where(link_id: bundle_ids).delete_all
  puts "  ✓ Deleted #{deleted_counts[:purchases]} Purchase record(s) (bundle purchases)"

  # 14. Delete Workflow records (linked via link_id)
  deleted_counts[:workflows] = Workflow.unscoped.where(link_id: bundle_ids).delete_all
  puts "  ✓ Deleted #{deleted_counts[:workflows]} Workflow record(s)"

  # 15. Delete Link records (the bundles themselves)
  deleted_counts[:bundles] = Link.unscoped.where(id: bundle_ids).delete_all
  puts "  ✓ Deleted #{deleted_counts[:bundles]} Link record(s) (bundles)"

  puts "\n✅ Cleanup complete!"
  puts "\n📊 Summary:"
  deleted_counts.each do |model, count|
    puts "  - #{model.to_s.humanize}: #{count}"
  end
  puts "\n"
end

cleanup_bundles_for_seller
