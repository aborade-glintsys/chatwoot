class CreateGlintReachBrandProfiles < ActiveRecord::Migration[7.2]
  def change
    create_table :glint_reach_brand_profiles do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.text :description
      t.string :website_url, limit: 2048
      t.text :products_services
      t.text :target_audience
      t.text :geographic_market
      t.string :preferred_languages, array: true, null: false, default: []
      t.text :voice_and_tone
      t.text :messaging_guidelines
      t.text :prohibited_claims
      t.string :approved_ctas, array: true, null: false, default: []
      t.timestamps
    end

    # One profile per account for now. Supporting several later means dropping this unique index.
    add_index :glint_reach_brand_profiles, :account_id, unique: true
  end
end
