# frozen_string_literal: true

class CheckSellerStripeFingerprintWorker
  include Sidekiq::Job
  sidekiq_options retry: 5, queue: :default

  def perform(id)
    bank_account = BankAccount.includes(:user).find_by(id:)
    return if bank_account.blank?

    user = bank_account.user
    return if !user.can_flag_for_fraud? || bank_account.stripe_fingerprint.blank?

    banned_accounts_with_same_payment_address = User.suspended.joins(:bank_accounts).merge(BankAccount.with_stripe_fingerprint(bank_account.stripe_fingerprint).alive).where.not(id: user.id)

    if banned_accounts_with_same_payment_address.exists? || bank_account.blocked_by_stripe_fingerprint?
      user.flag_for_fraud!(author_name: "CheckStripeFingerprintAddress", content: "Flagged for fraud automatically on #{Time.current.to_fs(:formatted_date_full_month)} because of usage of Stripe fingerprint #{bank_account.stripe_fingerprint}")
    end
  end
end
