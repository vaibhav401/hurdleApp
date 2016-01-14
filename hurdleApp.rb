require 'sinatra'
require "sinatra/json"
require 'data_mapper'
require 'dm-core'
require 'dm-types'
require 'dm-validations'
require 'securerandom' # SecureRandom.urlsafe_base64 to generate a token
require 'redis'
require 'json'

DataMapper.setup(:default, ENV['DATABASE_URL'] ||  "sqlite3://#{Dir.pwd}/dev.db")
redis = Redis.new

class User
	include DataMapper::Resource

	property :id, Serial
	property :username, String, :length => 1..255
	property :password, BCryptHash
	property :created_at, DateTime   # handles by datamapper
	property :updated_at, DateTime   # handles by datamapper

	has n, :todos
	belongs_to :team
	has 1, :authorization

	validates_uniqueness_of :username
end

class Authorization
	include DataMapper::Resource

	property :id, Serial
	property :isScrumMaster, Boolean
	property :updateSubscribe, Boolean
	property :created_at, DateTime   # handles by datamapper
	property :updated_at, DateTime   # handles by datamapper
	belongs_to :user
end

class Team
	include DataMapper::Resource

	property :id, Serial
	property :hastag, String, :length => 1..255
	property :description, Text, :lazy => false
	property :created_at, DateTime   # handles by datamapper
	property :updated_at, DateTime   # handles by datamapper

	validates_uniqueness_of :hastag

	has n, :user
end

class Todo
	include DataMapper::Resource

	property :id, Serial
	property :title, String , :length => 1..255
	property :description, Text, :lazy => false
	property :isComplete, Boolean, :default => false 
	property :created_at, DateTime   # handles by datamapper
	property :updated_at, DateTime   # handles by datamapper

	belongs_to :user
end

DataMapper.finalize
DataMapper.auto_upgrade!



def protected!(redis)
	user = User.first("id" => redis.get( env["HTTP_X_AUTH_TOKEN"]))
	if user.nil?
		headers['WWW-Authenticate'] = 'Sign In'
		halt 401, "Not authorized\n"
	else
		return user
	end
end
def get_user(redis, req)
	user_id = redis.get req["token"]
	u = User.first("id" => user_id)
	(return u) if not u.nil?
	halt 401, "Not authorized\n"
end
def processJson (request)
	request.body.rewind
  	request_payload = JSON.parse request.body.read
  	request_payload
end





post '/signin' do
	req = processJson request 
	username = req["username"]
	password = req["password"]
	if username and password
		user = User.first(:username => username)
		if user and user.password == password
			token = SecureRandom.urlsafe_base64
			redis.setnx token, user.id
			req["token"] = token
			return (json req)
		end
		halt 401, "Wrong Username or Password"
	end
	headers['WWW-Authenticate'] = 'Wrong Username password'
    halt 401, "Not authorized\n"
end


post '/todo' do
	user = protected!(redis)
	req = processJson request 
	title = req["title"]
	description = req["description"]
	if title and description
		todo = Todo.create("title" => title, "description" => description, "user" => user)
		todo.save
		todo.errors.each do |error|
			puts error
		end
		 return json ({"id " => todo.id, "title" => todo.title, "description" => todo.description, "isComplete" => todo.isComplete}) if todo.saved?
	end
	halt 401, "Wrong Parameters "
end

post '/todo/:id' do
	user = 	protected!(redis)	
	req = processJson request
	todo = Todo.first(:id => req[:id].to_i)
	title = req[:title]
	description = req[:description]
	isComplete = req[:isComplete]
	if title and description and isComplete and todo
		todo.user = user
		todo.description = description
		todo.isComplete = isComplete
		todo.save
		json ({"id " => todo.id, "title" => todo.title, "description" => todo.description, "isComplete" => todo.isComplete}) if todo.saved?
	end
	halt 401, "Wrong Parameters"
end

get '/todos' do
	user = protected!(redis)
	result = {}
	user.todos.each do |todo|
		result[todo.id.to_s] = ({"id " => todo.id, "title" => todo.title, "description" => todo.description})
	end
	return json result
end

get '/user/:id/todos' do
	user = User.first("id" => params[:id].to_i)
	result = {}
	user.todos.each do |todo|
		result[todo.id.to_s] = ({"id " => todo.id, "title" => todo.title, "description" => todo.description})
	end
	return (json result)
end



post '/user' do 
	req = processJson request 
	username = req["username"]
	password = req["password"]
	team = Team.first(req["team_id"]) 
	if username and password and team
		user = User.create("username" => username, "password" => password, "team" => team)
		if user.saved?
			(return json({"id " => user.id, "username" => user.username}) ) 
		else
			message = "User creation failed "
			user.errors.each do |error|
				puts error
			end
		end
	end
	halt 401, (message ? message : "Insufficient Parameters")
end

post '/user/:id' do
	user = protected! (redis)
	req = processJson request 
	username = req[:username]
	password = req[:password]
	team_id = req[:team_id]
	if username and password and (user.username == username)
		u.username = username
		u.password = password
		if team_id and (team_id != user.team.id)
			t = Team.first("id" => team_id.to_i)
			(u.team = t ) if not t.nil?
			t.save
		end
		u.save
		return json ({"id " => u.id, "username" => u.username}) if user.saved?
	end
	halt 401, "Not authorized\n"
end

get '/teams' do
	teams = Team.all()
	result = {}
	teams.each do |team|
		result[team.id.to_s] = team.hastag 
	end
	json teams
end

post '/team' do
	req = processJson request 
	hastag = req["hastag"]
	description = req["description"]
	if hastag and description
		team = Team.create("hastag" => hastag, "description" => description)
		return json ({"id" => team.id, "description" => team.description, "hastag" => team.hastag}) if teams.saved?
	end
	halt 401, "Not authorized\n"
end

# post '/teams/:id' do
# 	req = processJson request 
# 	hastag = req["hastag"]
# 	description = req["description"]
# 	if hastag and description
# 		team.hastag = hastag
# 		team.description = description
# 		team.save
# 		json ({"id" => team.id, "description" => team.description, "hastag" => team.hastag}) if teams.saved?
# 	end
# 	halt 401, "Not authorized\n"
# end




