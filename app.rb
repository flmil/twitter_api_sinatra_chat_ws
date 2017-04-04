require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?
require 'sinatra'
require 'sinatra-websocket'
require 'sinatra/json'
require './models.rb'
require 'open-uri'
require 'time'
require 'json'

require 'twitter_oauth'

Time.zone = "Tokyo"
ActiveRecord::Base.default_timezone = :local

set :server, 'thin'
set :sockets, Hash.new { |h, k| h[k] = [] }

enable :sessions

before do
	key = ''
	secret = ''
	@twitter = TwitterOAuth::Client.new(
		:consumer_key => key,
		:consumer_secret => secret,
		:token => session[:access_token],
		:secret => session[:secret_token])
end

get '/' do
	@session = session
	@room_name = Room.order('id DESC').all
	erb :index
end

get '/request_token' do
	callback_url = "#{base_url}/access_token"
	request_token = @twitter.request_token(:oauth_callback => callback_url)
	session[:request_token] = request_token.token
	session[:request_token_secret] = request_token.secret
	redirect request_token.authorize_url
end

def base_url
	default_port = (request.scheme == "http") ? 80 : 443
	port = (request.port == default_port) ? "" : ":#{request.port.to_s}"
	"#{request.scheme}://#{request.host}#{port}"
end

get '/request_token' do
	callback_url = "#{base_url}/access_token"
	request_token = @twitter.request_token(:oauth_callback => callback_url)
	session[:request_token] = request_token.token
	session[:request_token_secret] = request_token.secret
	redirect request_token.authorize_url
end

get '/access_token' do
	begin
		@access_token = @twitter.authorize(session[:request_token], session[:request_token_secret],
																			 :oauth_verifier => params[:oauth_verifier])
	rescue OAuth::Unauthorized => @exception
		return erb :authorize_fail
	end

	session[:access_token] = @access_token.token
	session[:access_token_secret] = @access_token.secret
	session[:user_id] = @twitter.info['user_id']
	session[:screen_name] = @twitter.info['screen_name']
	session[:profile_image] = @twitter.info['profile_image_url_https']

	redirect '/'
end

get '/logout' do
	session.clear
	redirect '/'
end

post '/create_room' do
	room = Room.create({
		roomname: params[:room_name],
	})
	redirect '/'
end

#get '/rooms/:room_id' do
#	@session = session
#	@room_name = Room.find_by(id: params[:room_id])
#	@message = @room_name.messages
#	erb :rooms
#end

get '/rooms/:room_id' do
	@session = session
	logger.info @session
	@id = Room.find_by(id: params[:room_id])
	@message = @id.messages

	if !request.websocket?
		# websocketのリクエストじゃないときはrooms.erb返す
		erb :rooms
	else
		# websocketのリクエストだった時
		request.websocket do |ws|
			# websocketのコネクションが開かれたとき
			ws.onopen do
				# ws.send("Hello World!")
				#message = JSON.parse(m)
				# ハッシュにidをキーにして保存
				settings.sockets[@id] << ws
			end
			ws.onmessage do |msg|
				json = JSON.parse(msg)
				Message.create(
					body: json['msg'],
					room_id: json['room_id'],
					username: session[:screen_name] 
				)	
				#@id = Room.first
				EM.next_tick do
					# 同じidにつながってるクライアントすべてにメッセージ送信
					settings.sockets[@id].each do |s|
						# DBからuserとりだして，user.idとuser.nameとmsgをjsonの文字列にする
						# 発言をDBに格納するのもココで！
						# 発言をDBに格納するのもココで！
						s.send({ user: session[:screen_name],  body: json['msg'] }.to_json)
					end
				end
=begin
				EM.next_tick do
					# 同じidにつながってるクライアントすべてにメッセージ送信
					settings.sockets.each do |s|
						# DBからuserとりだして，user.idとuser.nameとmsgをjsonの文字列にする
						# 発言をDBに格納するのもココで！
						# s.send({ user: session[:screen_name],  body: msg }.to_json)
						s.send("hello")
					end
				end
=end
			end
			# websocketのコネクションが閉じられたとき
			ws.onclose do
				warn("websocket closed")
				# socketをハッシュから削除する
				settings.sockets[@id].delete(ws)
			end
		end
	end
end


post '/send/message' do
	p params[:room_id]
	p params[:body]
	Message.create({
		body: params[:body],
		room_id: params[:room_id],
		username: params[:username], 
	})	
	#redirect "/rooms/#{params[:room_id]}"
	redirect back
end
