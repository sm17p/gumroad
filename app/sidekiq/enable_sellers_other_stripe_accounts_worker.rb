# frozen_string_literal: true

class EnableSellersOtherStripeAccountsWorker
  include Sidekiq::Job
  sidekiq_options retry: 5, queue: :default, lock: :until_executed

  def perform(stripe_fingerprint)
    return if stripe_fingerprint.blank?

    BankAccount
    .with_stripe_fingerprint(stripe_fingerprint).alive
    .joins(:user)
    .merge(User.suspended)
    .find_each do
      _1.user.mark_compliant!(
        author_name: "enable_sellers_other_accounts",
        content: "Marked compliant automatically on #{Time.current.to_fs(:formatted_date_full_month)} as Stripe fingerprint #{stripe_fingerprint} is now unblocked"
        )
    end
  end
end
