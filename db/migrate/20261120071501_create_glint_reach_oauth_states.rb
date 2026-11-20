class CreateGlintReachOauthStates < ActiveRecord::Migration[7.2]
  def change
    create_table :glint_reach_oauth_states do |t|
      t.bigint :account_id, null: false
      t.bigint :user_id, null: false
      t.string :provider, null: false
      # SHA-256 hex digests of the random state token and the HttpOnly browser-binding cookie nonce.
      t.string :state_digest, null: false
      t.string :browser_nonce_digest, null: false
      # PKCE code_verifier, encrypted at rest.
      t.text :code_verifier, null: false
      t.datetime :expires_at, null: false
      t.datetime :consumed_at
      t.timestamps
    end

    add_index :glint_reach_oauth_states, :state_digest, unique: true
    add_index :glint_reach_oauth_states, :expires_at
    add_foreign_key :glint_reach_oauth_states, :accounts, column: :account_id, on_delete: :cascade
  end
end
