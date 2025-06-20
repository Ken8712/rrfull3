class AddEmotionToRooms < ActiveRecord::Migration[7.2]
  def change
    add_column :rooms, :user1_emotion, :string
    add_column :rooms, :user2_emotion, :string
    add_index :rooms, :user1_emotion
    add_index :rooms, :user2_emotion
  end
end
