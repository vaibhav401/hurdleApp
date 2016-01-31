require 'sinatra'
require "sinatra/json"
require 'json'
require 'digest'
require 'pry'
require_relative 'models'

# to dos
# Use GET, POST, PATCH and DELETE verbs , only using GET and POST, so edit with Put
	# create input  first point out things you are expecting at first
	# Only creation should handle the sync phase
# No need for an extra key sync, choose _id to be unique 
	# handle sync staus  
	# create routes for srcum_master and user in a team 
	# design spicifc and sensible points
	# check creation on new user and weird edge case
	# handle creation of team
	# handle insertion of new user into team
	# handle deletion of user from team
	# handle creation of scrum master -> handled
	#JSON.parse (request.body.read)
	# handle sync code and imageurl - > handled





 #auto_migrate! to destroy db and then recrete it



def protected!
	session = Session.first( :digest => env["HTTP_HTTP_X_AUTH_TOKEN"] ) #checks for token in passed header
	if session.nil?
		headers['WWW-Authenticate'] = 'Sign In'
		halt 401, "Not authorized\n"
	end
	@user =  session.user

end


def processJson (request)
	request.body.rewind
  	request_payload = JSON.parse request.body.read
  	request_payload
end

def errorHash ( object)
	i = 0  # refactor it
	errors = {}
	object.errors.full_messages.each do |msg|
		errors[i] = msg
	end	
	error["error_code"] = "" #put error code here
	errors
end 


post '/signin' do
	req = processJson request # process the json request body
	username = req["username"]
	password = req["password"]
	if username and password
		user = User.first(:username => username) 
		if user and user.password == password
			session = Session.first(:user => user) # if a session already exists return it 
			if not session.nil?
				return { :token => session.digest}.to_json
			end
			token = digest(user.username, user.full_name)
			session = Session.create(:user => user, :digest => token)
			session.save
			req["token"] = token
			# binding.pry for debugging
			return json req # return json with token
		end
	end
	headers['WWW-Authenticate'] = 'Wrong Username password'
    halt 401, "Not authorized\n"
end

# Task Related routes
	before '/tasks*' do
		protected!
	end
	before '/task/*' do 
		protected!
	end

	post '/tasks' do
		request_hash = processJson request
		task = Task.from_hash(request_hash)
		task.user = @user
		task.team = @user.team
		return_value = nil
		if task.save
			json task
		else
			json (errorHash task)
		end
	end

	patch '/task/:id' do
		request_hash = processJson request
		task = Task.first(:id => params[:id].to_i)
		task.update_from_hash request_hash
		return_value = nil
		if task.save
			json task
		else
			json errorHash task
		end
	end


	get '/tasks' do
		json @user.tasks
	end

	# tasks for a particular user
	get '/tasks/user/:id' do
		user = User.first("id" => params[:id].to_i)
		if not user.nil?
			return json user.tasks
		else
			halt 401, "Wrong arguments"
		end
	end

	# tasks of users
	get '/tasks/team/:id' do
		team = Team.first("id" => params[:id].to_i)
		if not team.nil?
			return json team.tasks
		else
			halt 401, "Wrong arguments"
		end
	end


	# tasks for users team
	get '/tasks/team' do
		team = @user.team
		if not team.nil?
			return  json team.tasks 
		else
			halt 401, "Wrong arguments"
		end
	end


# user related routes
	before '/user*' do
		protected!
	end

	post '/user' do  
		req = processJson request
		user = User.from_hash(req)
		binding.pry
		if user.save
			json user
		else
			json (errorHash user)
		end
	end

	patch '/user/:id' do
		req = processJson request
		@user.update_from_hash(req)
		if @user.save
			json @user
		else
			json (errorHash @user)
		end
	end

	get '/user/:id' do
		user = User.first(:id => params[:id].to_i)
		if user
			json user
		else
			halt 401, "Invalid arguments\n"
		end
	end

# put passowrd change in different thread

get '/teams' do
	teams = Team.all()
	json teams
end


# team code to be handleed {"name" : "", "details" : "", "sync_code" : "" }
	before '/team*' do
		protected!
	end

	get '/team' do
		json @user.team
	end

	post '/team' do
		req = processJson request 
		team =  Team.new(req)
		team.scrum_master = @user
		if team.save
			json team
		else
			json (errorHash team)
		end
	end


	post '/team/members/' do 
		protected!
		req = processJson request 
		user = User.first("id" => req["user_id"])
		if user and @user.team
			@user.team.members.push user
				# check if previous link is broken 
			if @user.team.save and user.save
				return @user.team
			end
		else
			halt 401, "Insufficient arguments\n"
		end
	end

	# to delete a memeber from members
	delete '/team/members/' do 
		protected!
		user_to_remove= User.first("id" => req["user_id"])
		if user_to_remove and @user.team
			@user.team.members.delete user_to_remove
			json @team
		else
			halt 401, "Insufficient arguments\n"
		end
	end

	# post '/team/scrum_master' do 
	# 	protected! 
	# 	team = @user.team
	# 	team.scrum_master = @user
	# 	if team.save
	# 		json team
	# 	else
	# 		json (errorHash team)
	# end


# # post '/teams/:id' do
# # 	req = processJson request 
# # 	name = req["name"]
# # 	details = req["details"]
# # 	if name and details
# # 		team.name = name
# # 		team.details = details
# # 		team.save
# # 		json ({"id" => team.id, "details" => team.details, "name" => team.name}) if teams.saved?
# # 	end
# # 	halt 401, "Not authorized\n"
# # end


def digest(username, full_name)
	Digest::SHA256.hexdigest (username + full_name)
end


