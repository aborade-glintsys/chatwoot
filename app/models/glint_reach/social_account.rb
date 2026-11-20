# A connected external social account owned by a Chatwoot account.
# OAuth tokens are encrypted at rest with Active Record Encryption; storing any token is refused
# when encryption keys are not configured. Tokens are never serialized, logged or audited.
class GlintReach::SocialAccount < ApplicationRecord
  if ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'].present?
    encrypts :access_token
    encrypts :refresh_token
  end

  belongs_to :account
  belongs_to :connected_by, class_name: 'User'

  enum :status, { connected: 0, expired: 1, revoked: 2, missing_scopes: 3, error: 4 }, validate: true

  validates :provider, presence: true, inclusion: { in: ->(_) { GlintReach::Social::Providers.keys } }
  validates :provider_account_id, presence: true, uniqueness: { scope: [:account_id, :provider] }
  validates :provider_account_type, presence: true
  validates :display_name, presence: true, length: { maximum: 255 }
  validates :last_error_message, length: { maximum: 500 }
  validate :encryption_must_be_configured, if: -> { access_token.present? || refresh_token.present? }

  scope :active_connection, -> { where(status: :connected) }
  scope :recent, -> { order(updated_at: :desc, id: :desc) }

  def provider_client
    GlintReach::Social::Providers.build(provider)
  end

  def capabilities
    provider_client.capabilities(account_type: provider_account_type)
  end

  def token_expired?(at: Time.current)
    token_expires_at.present? && token_expires_at <= at
  end

  def clear_tokens!
    update!(access_token: nil, refresh_token: nil, token_expires_at: nil, refresh_expires_at: nil)
  end

  def mark_status!(new_status, code: nil, message: nil)
    update!(status: new_status, last_error_code: code, last_error_message: message&.to_s&.truncate(500),
            last_verified_at: Time.current)
  end

  private

  def encryption_must_be_configured
    return if Chatwoot.encryption_configured?

    errors.add(:base, I18n.t('errors.glint_reach.social.encryption_required'))
  end
end

GlintReach::SocialAccount.include_mod_with('Audit::GlintReach::SocialAccount')
