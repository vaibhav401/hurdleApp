require 'sinatra'
require "sinatra/json"
require 'json'
require 'digest'
require 'pry'
require 'gcm'
require 'rest-client'


require_relative 'models'
load 'gcm_key.secret'

# to dos
# Use GET, POST, PATCH and DELETE verbs , only using GET and POST, so edit with Put
	# create input  first point out things you are expecting at first
	# Only creation should handle the sync phase
# No need for an extra key sync,x
# get error handling up and running
	#JSON.parse (request.body.read)





 #auto_migrate! to destroy db and then recrete it

class HurdleApp < Sinatra::Base

set :root, File.dirname(__FILE__)
set :bind, '0.0.0.0'

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
	  	# puts request_payload
	  	request_payload
	end

	def errorHash ( object)
		i = 0  # refactor it
		errors = {}
		object.errors.full_messages.each do |msg|
			errors[i] = msg
		end	
		errors["error_code"] = "" #put error code here
		errors
	end 

	def objectArrayToJson(obj)
		(obj).map { |o| Hash[o.to_hash.each_pair.to_a] }.to_json
	end

	post '/signin' do
		req = processJson request # process the json request body
		# binding.pry
		username = req["username"]
		password = req["password"]
		if username and password
			user = User.first(:username => username) 
			if user and user.password == password
				session = Session.first(:user => user) # if a session already exists return it 
				if not session.nil?
					result = session.user.to_hash
					result["token"] = session.digest
					# puts "session already exists", result
					return (json result)
				end
					token = digest(user.username, user.full_name)
					session = Session.create(:user => user, :digest => token)
					session.save
					result = JSON.parse user.to_json
					result["token"] = token 
					# puts " new session created", result
				return (json session) # return json with token
			end
			halt 400, "wrong username or password"
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

		def verify_task_sync (sync_code)
			task = Task.first(:sync_code => sync_code)
			if task
				task
			else
				nil
			end
		end

		post '/tasks' do
			request_hash = processJson request
			sync_code = request_hash["sync_code"]
			verified_task = verify_task_sync(sync_code)
			if not verified_task.nil? 
				json verified_task
			end
			task = Task.from_hash(request_hash)
			task.user = @user
			task.team = @user.team
			return_value = nil
			if task.save
				# puts task.to_json
				# puts task.user.to_json
				gcm_tokens = task.team.members.collect { |user| user.reg_token if user != task.user}
				send_gcm_message_to_devices(GCM_TYPE_UPDATE_DB, @user.full_name + " inserted new task", 
						gcm_tokens)
				json task
			else
				# puts errorHash task
				json (errorHash task)
			end
		end

		patch '/task/:id' do
			request_hash = processJson request
			# puts request_hash
			sync_code = request_hash["sync_code"]
			verified_task = verify_task_sync(sync_code)
			if not verified_task.nil? 
				# puts "Existing patch"
				# puts verified_task
				return json verified_task
			end
			task_done_now = request_hash["is_complete"]
			task = Task.first(:id => params[:id].to_i)
			task_done_status_before = task.isComplete
			task.update_from_hash request_hash
			return_value = nil
			if task.save 
				# puts task.to_json
				# puts task.user.to_json
				gcm_tokens = task.team.members.collect { |user| user.reg_token if user != task.user}
				title = "perform sync"
				body = {}
				if task_done_now and not task_done_status_before #and @user.team.scrum_master != @user
					send_gcm_message_to_devices(GCM_TYPE_TASK_DONE, @user.full_name + " completed his task", [task.team.scrum_master.reg_token])
				end
				send_gcm_message_to_devices(GCM_TYPE_UPDATE_DB, @user.full_name + " inserted new task", 
						gcm_tokens)
				# binding.pry
				# send_gcm_message_to_devices(GCM_TYPE_UPDATE_DB, "", gcm_tokens)
				# puts task
				json task
			else
				json errorHash task
			end
		end


		get '/tasks' do
			objectArrayToJson @user.tasks
		end

		# tasks for a particular user
		get '/tasks/user/:id' do
			user = User.first("id" => params[:id].to_i)
			if not user.nil?
				return objectArrayToJson( user.tasks)
			else
				halt 401, "Wrong arguments"
			end
		end

		# tasks of users
		get '/tasks/team/:id' do
			team = Team.first("id" => params[:id].to_i)
			if not team.nil?
				return json (team.tasks)
			else
				halt 401, "Wrong arguments"
			end
		end


		# tasks for users team
		get '/tasks/team' do
			team = @user.team
			if not team.nil?
				return  objectArrayToJson(team.tasks) 
			else
				halt 401, "Wrong arguments"
			end
		end


	# user related routes
		before '/user/*' do
			protected!
		end
		before '/register*' do
			protected!
		end

		get '/user' do
			protected!
			json @user
		end

		# to associate a gcm token with user
		post '/register/:gcm_token' do
			# puts "saving token"
			@user.reg_token = params[:gcm_token]
			if @user.save
				return @user.to_json
			end
			halt 401, "Check User data"
		end

		post '/user' do  
			request_hash = processJson request
			# puts request_hash
			allowed = false
			team_error = false
			team_name = request_hash["team_name"]
			team_pass = request_hash["team_pass"]
			if(request_hash["new_team"]) 
				team = Team.new
				team.name = team_name
				team.pass = team_pass
				if  team.save
					allowed = true
				else
					team_error = true
				end
			else
				team = Team.first(:name => team_name)
				if team and team.pass == team_pass
					allowed = true
				end
			end

			user = User.from_hash(request_hash)

			if team and allowed
				user.team = team
				if user.save
					if request_hash["new_team"] == "true"
						team.scrum_master = user
						team.save
					end
					token = digest(user.username, user.full_name)
					session = Session.create(:user => user, :digest => token)
					session.save
					result = JSON.parse user.to_json
					result["token"] = token 
					# puts result
					gcm_tokens = user.team.members.collect { |user_inside| user_inside.reg_token if user_inside != user}
					send_gcm_message_to_devices(GCM_TYPE_UPDATE_DB, user.full_name + " is new user", 
						gcm_tokens)
					return (json result)
				else
					halt 400, "Username must be unique"
				end
			end
			halt 400, "Unknown Team name or Pass"
		end

		patch '/user/:id' do
			request_hash = processJson request
			id = params[:id]
			user = User.first(:id => id)
			if not user or not (user == @user)
				halt 401, "Not authorized"
			end
			@user.update_from_hash(request_hash)
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

	# team code to be handleed {"name" : "", "details" : "", "sync_code" : "" }
		
		before '/team*' do
			protected!
			@team = @user.team
		end


		before '/team/[a-zA-Z]' do
			@team = @user.team
			request_hash = processJson request 
			# sync_code = request_hash["sync_code"]
			# verify_task_sync(sync_code)
			@user_to_modify = User.first("id" => request_hash["user_id"])
			if not @team and @user_to_modify and @team.scrum_master != @user
				halt 404, "not found"
			end
		end

		get '/team' do
			json @user.team
		end

		get '/team/members/:time' do
			time = params[:time].to_i
			if (time < 0 or time > Time.now.to_i ) 
				halt 401, "Unknown entity"
			end
			objectArrayToJson (@team.users_modified_after time)
		end 

		get '/team/tasks/:time' do
			time = params[:time].to_i
			if time < 0 or time > Time.now.to_i 
				halt 401, "Unknown entity"
			end
			objectArrayToJson (@team.tasks_modified_after time )
		end


		post '/team' do
			request_hash = processJson request 
			team =  Team.from_hash request_hash
			team.from_hash ()
			team.scrum_master = @user
			team.members.push @user
			if team.save
				json team
			else
				json (errorHash team)
			end
		end

		patch '/team' do
			request_hash = processJson request 
			team = @user.team
			team.update_from_hash request_hash
			team.scrum_master = @user
			if team.save
				json team
			else
				json (errorHash team)
			end
		end

		patch '/team/members' do 
			@team.members.push @user_to_modify
			if @team.save
				json @team
			else
				json errorHash @team
			end
		end

		# # to delete a memeber from members
		delete '/team/members' do 
			@team.members.delete user_to_modify
			if @team.save
				json @team
			else
				json errorHash @team
			end
		end

		post '/team/scrum_master' do 
			protected! 
			team = @user.team
			team.scrum_master = @user
			if team.save
				json team
			else
				json (errorHash team)
			end
		end


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
	GCM_TYPE_TASK_DONE = "task_done"
	GCM_TYPE_UPDATE_DB = "update_db"


	def send_gcm_message_to_devices(type, message, registration_ids)
		# puts registration_ids
		# puts "sending message"
		gcm = GCM.new(GCM_AUTHORIZE_KEY)
		options = {data: {type: type, message: message}}
	    response = gcm.send(registration_ids, options)
	end

	def send_gcm_message_to_server(title, body, reg_tokens)
	  # Construct JSON payload
	  post_args = {
	    # :to field can also be used if there is only 1 reg token to send
	    :registration_ids => reg_tokens,
	    :data => {
	      :title  => title,
	      :body => body,
	      # additional data here 
	    }
	  }

	  # Send the request with JSON args and headers
	  RestClient.post 'https://gcm-http.googleapis.com/gcm/send', post_args.to_json,
	    :Authorization => 'key=' + GCM_AUTHORIZE_KEY, :content_type => :json, :accept => :json
	end

run! if app_file == $0 
end