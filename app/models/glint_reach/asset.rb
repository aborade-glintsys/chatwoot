# A creative uploaded to a campaign. The blob lives in the installation's Active Storage service;
# metadata is cached from GlintReach::AssetInspector, which validates the bytes before attaching.
# URLs are never stored: the API issues short-lived signed URLs to authorized users only.
# == Schema Information
#
# Table name: glint_reach_assets
#
#  id             :bigint           not null, primary key
#  alt_text       :string(1000)
#  byte_size      :bigint           not null
#  checksum       :string
#  content_type   :string           not null
#  filename       :string           not null
#  height         :integer          not null
#  width          :integer          not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :bigint           not null
#  campaign_id    :bigint           not null
#  uploaded_by_id :bigint           not null
#
# Indexes
#
#  index_glint_reach_assets_on_account_id_and_campaign_id  (account_id,campaign_id)
#  index_glint_reach_assets_on_campaign_id_and_created_at  (campaign_id,created_at)
#
# Foreign Keys
#
#  fk_rails_...  (campaign_id => glint_reach_campaigns.id) ON DELETE => cascade
#
class GlintReach::Asset < ApplicationRecord
  URL_EXPIRY = 5.minutes
  THUMBNAIL = { resize_to_limit: [480, 480] }.freeze

  belongs_to :account
  belongs_to :campaign, class_name: 'GlintReach::Campaign'
  belongs_to :uploaded_by, class_name: 'User'
  has_many :variant_assets, class_name: 'GlintReach::VariantAsset', dependent: :delete_all
  has_many :content_variants, through: :variant_assets

  has_one_attached :file

  attr_reader :upload

  validates :alt_text, length: { maximum: 1_000 }
  validate :upload_acceptable, if: -> { upload.present? }
  validate :file_present

  before_validation { self.account_id = campaign&.account_id }
  before_validation { self.alt_text = alt_text.to_s.strip.presence }

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # Assigning a new upload (create or replace) is validated on save; the previous blob is purged
  # by Active Storage after the replacement is committed.
  def upload=(uploaded_file)
    @upload = uploaded_file
    @inspected = nil
  end

  def url
    expiring_path { Rails.application.routes.url_helpers.rails_blob_path(file, only_path: true, expires_in: URL_EXPIRY) }
  end

  def thumbnail_url
    expiring_path do
      next url unless file.variable?

      Rails.application.routes.url_helpers.rails_representation_path(file.variant(THUMBNAIL), only_path: true, expires_in: URL_EXPIRY)
    end
  end

  private

  def expiring_path
    return nil unless file.attached?

    yield
  end

  def upload_acceptable
    result = GlintReach::AssetInspector.new(upload).inspect!
    assign_attributes(filename: result.filename, content_type: result.content_type, byte_size: result.byte_size,
                      width: result.width, height: result.height)
    # Assignment (not attach) defers the write until the record saves, so a failed save keeps the old file.
    self.file = { io: File.open(result.path, 'rb'), filename: result.filename, content_type: result.content_type, identify: false }
    self.checksum = file.blob.checksum
  rescue GlintReach::AssetInspector::Invalid => e
    errors.add(:file, e.message)
  end

  def file_present
    errors.add(:file, :blank) unless file.attached? || errors.key?(:file)
  end
end

GlintReach::Asset.include_mod_with('Audit::GlintReach::Asset')
