# frozen_string_literal: true

describe CheckSellerStripeFingerprintWorker do
  let(:banned_fingerprint) { SecureRandom.hex(16) }
  let(:blocked_fingerprint) { SecureRandom.hex(16) }

  let!(:previously_banned_user) do
    user = create(:user, user_risk_state: "suspended_for_fraud")
    create(:ach_account, user: user, stripe_fingerprint: banned_fingerprint)
    user
  end

  let!(:blocked_fingerprint_object) do
    BlockedObject.block!(BLOCKED_OBJECT_TYPES[:charge_processor_fingerprint],
                         blocked_fingerprint, nil)
  end

  it "does not flag the user for fraud if there are no other banned users with the same Stripe fingerprint" do
    user = create(:user)
    bank_account = create(:ach_account, user: user, stripe_fingerprint: "clean_fingerprint")

    expect(user.flagged?).to be(false)
    CheckSellerStripeFingerprintWorker.new.perform(bank_account.id)
    expect(user.reload.flagged?).to be(false)
  end

  it "flags the user for fraud if there are other banned users with the same Stripe fingerprint" do
    user = create(:user)
    bank_account = create(:ach_account, user: user, stripe_fingerprint: banned_fingerprint)

    expect(user.flagged?).to be(false)
    CheckSellerStripeFingerprintWorker.new.perform(bank_account.id)
    expect(user.reload.flagged?).to be(true)
    expect(user.comments.last.content).to include("Flagged for fraud automatically", "because of usage of Stripe fingerprint #{banned_fingerprint}")
  end

  it "flags the user for fraud if a blocked object exists for their stripe fingerprint" do
    user = create(:user)
    bank_account = create(:ach_account, user: user, stripe_fingerprint: blocked_fingerprint)

    expect(user.flagged?).to be(false)
    CheckSellerStripeFingerprintWorker.new.perform(bank_account.id)
    expect(user.reload.flagged?).to be(true)
    expect(user.comments.last.content).to include("Flagged for fraud automatically", "because of usage of Stripe fingerprint #{blocked_fingerprint}")
  end
end
