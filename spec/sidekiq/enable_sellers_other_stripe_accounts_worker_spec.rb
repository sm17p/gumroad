# frozen_string_literal: true

describe EnableSellersOtherStripeAccountsWorker do
  describe "#perform" do
    it "marks compliant users with same Stripe fingerprint" do
      fingerprint = SecureRandom.hex(16)
      user = create(:user, user_risk_state: "suspended_for_fraud")
      user_2 = create(:user, user_risk_state: "suspended_for_fraud")
      user_3 = create(:user, user_risk_state: "flagged_for_fraud")
      create(:ach_account, user:, stripe_fingerprint: fingerprint)
      create(:ach_account, user: user_2, stripe_fingerprint: fingerprint)
      create(:ach_account, user: user_3, stripe_fingerprint: fingerprint)

      expect(user_3.reload.user_risk_state).to eq("flagged_for_fraud")
      described_class.new.perform(fingerprint)

      expect(user_2.reload.user_risk_state).to eq("compliant")
      expect(user_2.comments.last.content).to include("Stripe fingerprint #{fingerprint} is now unblocked")
      expect(user_3.reload.user_risk_state).to eq("flagged_for_fraud")
    end
  end
end
