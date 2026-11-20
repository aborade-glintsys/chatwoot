class CreateGlintReachSocialAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :glint_reach_social_accounts do |t|
      identity_columns(t)
      credential_columns(t)
      t.timestamps
    end

    add_index :glint_reach_social_accounts, [:account_id, :provider, :provider_account_id],
              unique: true, name: 'index_glint_reach_social_accounts_unique_identity'
    add_index :glint_reach_social_accounts, [:account_id, :status]
    add_index :glint_reach_social_accounts, [:status, :token_expires_at]
    add_foreign_key :glint_reach_social_accounts, :accounts, column: :account_id, on_delete: :cascade
  end

  private

  def identity_columns(table)
    table.bigint :account_id, null: false
    table.bigint :connected_by_id, null: false
    table.string :provider, null: false
    table.string :provider_account_id, null: false
    table.string :provider_account_type, null: false, default: 'member'
    table.string :display_name, null: false
    table.string :profile_url
    table.string :avatar_url
  end

  def credential_columns(table)
    # Stored via Active Record Encryption; never serialized or logged.
    table.text :access_token
    table.text :refresh_token
    table.string :granted_scopes, array: true, null: false, default: []
    table.datetime :token_expires_at
    table.datetime :refresh_expires_at
    table.integer :status, null: false, default: 0
    table.string :last_error_code
    table.string :last_error_message, limit: 500
    table.datetime :last_verified_at
  end
end
