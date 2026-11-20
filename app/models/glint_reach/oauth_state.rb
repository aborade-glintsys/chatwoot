# Single-use server-side OAuth state bound to the initiating admin, account, provider and an
# HttpOnly browser cookie nonce. The raw state and nonce are never stored (SHA-256 digests only);
# the PKCE code_verifier is encrypted at rest.
class GlintReach::OauthState < ApplicationRecord
  TTL = 10.minutes

  encrypts :code_verifier if ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'].present?

  belongs_to :account
  belongs_to :user

  validates :provider, :state_digest, :browser_nonce_digest, :code_verifier, :expires_at, presence: true
  validate :encryption_must_be_configured

  scope :expired_records, -> { where(expires_at: ...Time.current) }

  def self.digest(value)
    Digest::SHA256.hexdigest(value.to_s)
  end

  def self.issue!(account:, user:, provider:)
    raw_state = SecureRandom.urlsafe_base64(32)
    raw_nonce = SecureRandom.urlsafe_base64(32)
    verifier = SecureRandom.urlsafe_base64(48)
    record = create!(
      account: account, user: user, provider: provider.to_s,
      state_digest: digest(raw_state), browser_nonce_digest: digest(raw_nonce),
      code_verifier: verifier, expires_at: TTL.from_now
    )
    [record, raw_state, raw_nonce]
  end

  def code_challenge
    Base64.urlsafe_encode64(Digest::SHA256.digest(code_verifier), padding: false)
  end

  def usable?(provider:, raw_nonce:)
    consumed_at.nil? &&
      expires_at > Time.current &&
      self.provider == provider.to_s &&
      raw_nonce.present? &&
      ActiveSupport::SecurityUtils.secure_compare(browser_nonce_digest, self.class.digest(raw_nonce))
  end

  private

  def encryption_must_be_configured
    return if Chatwoot.encryption_configured?

    errors.add(:base, I18n.t('errors.glint_reach.social.encryption_required'))
  end
end
