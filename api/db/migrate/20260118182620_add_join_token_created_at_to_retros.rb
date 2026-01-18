class AddJoinTokenCreatedAtToRetros < ActiveRecord::Migration[8.1]
  def change
    add_column :retros, :join_token_created_at, :datetime unless column_exists?(:retros, :join_token_created_at)
  end
end
