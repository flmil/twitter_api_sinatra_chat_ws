class Messages < ActiveRecord::Migration
	def change
		create_table :messages do |t|
			t.string :body
			t.string :username
			t.integer :room_id

			t.timestamps null: false
		end
	end
end
