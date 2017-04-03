class Rooms < ActiveRecord::Migration
	def change
		create_table :rooms do |t|
			t.string :roomname

			t.timestamps null: false
		end
	end
end
