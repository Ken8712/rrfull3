class AddPairUserToUsers < ActiveRecord::Migration[7.2]
  def change
    add_reference :users, :pair_user, null: true, foreign_key: { to_table: :users }
  end
end
