 require 'data_mapper'
require 'dm-core'
require 'dm-types'
require 'dm-validations'
require 'date'
require 'dm-serializer'
# Time interaction with user is done in epoch  
#create a unique identifier composed of token:modified_at:client_id and it sould be unique

class User
	include DataMapper::Resource


	property :id, Serial 
	property :username, String, :length => 5..255
	property :full_name, String, :length => 6..255
	property :password, BCryptHash
	property :image_url, String 	# to get image from imgur
		
	property :reg_token, String, :length => 5..255
		#server only
	property :created_at, DateTime   # handles by datamapper 
	property :updated_at, DateTime   # handles by datamapper
		
		# for mobile interation , will always be provided by client
	property :modified_after, Integer , :default => 0
	
	
	has n, :tasks 					# for task related to this user
	belongs_to :team , :required => false 				# to accociate a team with a user
	
	validates_uniqueness_of :username #username should be unique

	after :save do
		if not self.team.nil?
			team = self.team
			team.user_modified_after = self.modified_after
			team.save
		end
		true
	end

	after :create do
		if not self.team.nil?
			self.team.user_modified_after = self.modified_after
			self.team.save
		end
		true
	end

	before :create do
		self.modified_after = Time.now.to_i
	end

	before :save do
		self.modified_after = Time.now.to_i
	end
	def to_hash
		{
			:id => id,
			:username => username,
			:full_name => full_name,
			:created_at => created_at.strftime("%s").to_i,
			:updated_at => updated_at.strftime("%s").to_i,
			:modified_after => modified_after,
			:team_id => team.id,
			:image_url => image_url,
			:tasks  => tasks.map {|task| task.to_hash},
			:reg_token => reg_token
			
		}
	end
	def to_json(*a)
		self.to_hash.to_json
	end

	def self.from_hash(hash)
		user = User.new
		user.password = hash["password"]
		user.update_from_hash(hash)
		user
	end

	def update_from_hash(hash)
		self.username = hash["username"]
		self.full_name = hash["full_name"]
		self.image_url = hash["image_url"]
		if not hash["reg_token"].nil?
			self.reg_token =hash["reg_token"]
		end
	end

end


class Team
	include DataMapper::Resource

	property :id, Serial
	property :name, String, :length => 5..255
	property :pass, String, :length => 3..255

	property :image_url, String 

		# for server only 
	property :created_at, DateTime   # handles by datamapper
	property :updated_at, DateTime   # handles by datamapper
	
		# to handle mobile data
	property :task_modified_after, Integer, :default => 0
	property :user_modified_after, Integer, :default => 0
	property :modified_after, Integer, :default => 0

	has 1, :scrum_master, 'User'
	has n, :members, 'User'
	has n, :tasks
	
	validates_uniqueness_of :name

	before :save do
		self.modified_after = Time.now.to_i
		true
	end
	def to_hash 
		{
			:id => id,
			:name => name,
			:image_url => image_url,
			:scrum_master => scrum_master.id,
			:created_at => created_at.strftime("%s").to_i,
			:updated_at => updated_at.strftime("%s").to_i,
			:task_modified_after => task_modified_after,		
			:user_modified_after => user_modified_after,
			:modified_after => modified_after,
			:members  => members.map {|member| member.to_hash},
			:tasks  => tasks.map {|task| task.to_hash},	
		}
	end

	def to_json(*a)
		self.to_hash.to_json
	end

	def self.from_hash(hash)
		team = Team.new
		team.update_from_hash
	end

	def update_from_hash(hash)
		self.name = hash["name"]
		self.pass = hash["pass"]
		self.image_url = hash["image_url"]	
	end


	def users_modified_after (time) # time should be string of epoch
		members.all(:modified_after.gt =>  time)
	end 
	def tasks_modified_after(time) # time should be string 
		tasks.all(:modified_after.gt => time)
	end
end

class Task
	include DataMapper::Resource

	property :id, Serial
	property :title, String , :length => 1..80
	property :detail, String , :length => 1..255
	property :isComplete, Boolean, :default => false 
	property :image_url, String
	property :priority, Integer	

			# for server only 
	property :created_at, DateTime   # handles by datamapper
	property :updated_at, DateTime   # handles by datamapper

			# for server only 
	property :m_created_at, Integer   # to be passed by client
	property :m_updated_at, Integer   # to be passed by client

	property :complete_on, Integer 

		# for server interaction	
	property :modified_after, Integer, :default => 0  
	property :created_after, Integer, :default => 0   # as time need to be synced and passed to other clients

	property :sync_code , String, :length => 1..255

	belongs_to :user
	belongs_to :team

	validates_presence_of :user, :team

	after :save do 
		if not self.team.nil?
			team = self.team
			team.task_modified_after = self.updated_at.strftime("%s")
			team.save
		end
		true
	end
	before :save do
		self.modified_after =  Time.now.to_i
		true
	end

	before :create do 
		self.modified_after = Time.now.to_i
	end
	after :create do 
		if not self.team.nil?
			team = self.team
			team.task_modified_after = self.updated_at.strftime("%s")
			team.save
		end
		true
	end

	def to_hash
		{
			:id => id,
			:title => title,
			:detail => detail,
			:is_complete => isComplete,
			:user_id => user.id,
			:team_id => team.id,
			:image_url => image_url,
			:created_at => created_at.strftime("%s").to_i,
			:updated_at => updated_at.strftime("%s").to_i,
			:m_updated_at => m_updated_at,
			:m_created_at => m_created_at,
			:priority => priority,
			:sync_code => sync_code,
			:complete_on => complete_on,

		}
	end
	def to_json(*a)
		self.to_hash.to_json(*a)
	end

	def self.from_hash(hash)
		task  = Task.new
		task.update_from_hash(hash)
		task
	end

	def update_from_hash(hash)
		self.title = hash["title"]
		self.detail = hash["detail"]
		self.isComplete =  hash["is_complete"] 
		self.image_url = hash["image_url"]
		self.priority = hash["priority"]
		self.sync_code = hash["sync_code"]
		self.m_created_at = hash["m_created_at"]
		self.m_updated_at = hash["m_updated_at"]
		self.complete_on = hash["complete_on"]
	end

end

class Session
	include DataMapper::Resource
	property :id, Serial
	property :digest, String, :length => 1..255

	belongs_to :user

	def to_json(*a){
		:id => id,
		:token => digest,
		:user => user
		}.to_json(*a)
	end

end

def users_modified_after (time) # time should be string of epoch
	User.all(:modified_after.gt =>  time)
end
def tasks_modified_after(time) # time should be string 
	Task.all(:modified_after.gt => time)
end

DataMapper.setup(:default, ENV['DATABASE_URL'] ||  "sqlite3://#{Dir.pwd}/dev.db")
DataMapper.finalize
DataMapper.auto_upgrade!