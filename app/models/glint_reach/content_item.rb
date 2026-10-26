class GlintReach::ContentItem < ApplicationRecord
  include GlintReach::Lifecycle

  TRANSITIONS = {
    'draft' => %w[ready archived],
    'ready' => %w[draft archived]
  }.freeze

  belongs_to :account
  belongs_to :campaign, class_name: 'GlintReach::Campaign'
  has_many :variants, -> { order(:id) }, class_name: 'GlintReach::ContentVariant', dependent: :destroy, inverse_of: :content_item

  enum :content_type, { post: 0, image: 1, video: 2, carousel: 3, story: 4 }, validate: true
  enum :status, { draft: 0, ready: 1, archived: 2 }, validate: true

  validates :title, presence: true, length: { maximum: 255 }

  before_validation { self.account_id = campaign&.account_id }
end
