require 'bundler/setup'
Bundler.require

if development?
	ActiveRecord::Base.establish_connection("sqlite3:db/development.db")
end

#unless ENV['RACK_ENV'] == 'production'
#    ActiveRecord::Base.establish_connection("sqlite3:db/development.db")
#end
class Room < ActiveRecord::Base
	has_many :messages
end

class Message < ActiveRecord::Base
	belongs_to :room
end
