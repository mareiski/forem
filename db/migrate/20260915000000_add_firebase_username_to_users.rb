class AddFirebaseUsernameToUsers < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :users, :firebase_username, :string
    add_index :users, :firebase_username, unique: true, algorithm: :concurrently
  end
end