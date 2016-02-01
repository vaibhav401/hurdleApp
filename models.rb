 require 'data_mapper'
require 'dm-core'
require 'dm-types'
require 'dm-validations'

class User
	include DataMapper::Resource

	property :id, Serial 
	property :username, String, :length => 5..255
	property :full_name, String, :length => 6..255
	property :password, BCryptHash
	property :created_at, DateTime   # handles by datamapper
	property :updated_at, DateTime   # handles by datamapper
	property :sync_code, String		# to ensure sync is correct and make it unique
	property :image_url, String 	# to get image from imgur
	
	has n, :tasks 					# for task related to this user
	belongs_to :team , :required => false 				# to accociate a team with a user
	
	validates_uniqueness_of :username #username should be unique

	def to_json(*a)
		{
			:id => id,
			:username => username,
			:full_name => full_name,
			:created_at => created_at,
			:updated_at => updated_at,
			:sync_code => sync_code,
			:task_ids  => tasks.map {|task| task.id},
			:team_id => team.id,
			:image_url => image_url
			
		}.to_json(*a)
	end

	def self.from_hash(hash)
		user = User.new
		user.password = password
		user.update_from_hash(hash)
		user
	end

	def update_from_hash(hash)
		self.username = hash["username"]
		self.full_name = hash["full_name"]
		self.created_at = hash["created_at"]
		self.updated_at = hash["updated_at"]
		self.sync_code = hash["sync_code"]
		self.image_url = hash["image_url"]
		self.sync_code = hash["sync_code"]

	end
end


class Team
	include DataMapper::Resource

	property :id, Serial
	property :name, String, :length => 5..255
	property :created_at, DateTime   # handles by datamapper
	property :updated_at, DateTime   # handles by datamapper
	property :sync_code, String
	property :image_url, String 

	has 1, :scrum_master, 'User'
	has n, :members, 'User'
	has n, :tasks
	def to_json (*a)
		{
			:name => name,
			:sync_code => sync_code,
			:image_url => image_url,
			:members_ids  => members.map {|member| member.id},
			:task_ids  => tasks.map {|task| task.id},
			:scrum_master => scrum_master.id		
		}.to_json(*a)
	end
	def self.from_hash(hash)
		team = Team.new
		team.update_from_hash
	end
	def update_from_hash(hash)
		self.name = hash["name"]
		self.sync_code = hash["sync_code"]
		self.image_url = hash["image_url"]	
	end
	validates_uniqueness_of :name

end

class Task
	include DataMapper::Resource

	property :id, Serial
	property :title, String , :length => 1..80
	property :detail, String , :length => 1..255
	property :isComplete, Boolean, :default => false 
	property :created_at, DateTime   # handles by datamapper
	property :updated_at, DateTime   # handles by datamapper
	property :sync_code, String
	property :image_url, String
	property :priority

	belongs_to :user
	belongs_to :team

	validates_presence_of :user, :team


	def to_json(*a)
		{
			:id => id,
			:title => title,
			:details => details,
			:is_complete => isComplete,
			:sync_code => sync_code,
			:user_id => user.id,
			:team_id => team_id,
			:image_url => image_url,
			:created_at => created_at,
			:updated_at => updated_at,
		}.to_json(*a)
	end

	def self.from_hash(hash)
		task  = Task.new
		task.update_from_hash(hash)
		task
	end

	def update_from_hash(hash)
		self.title = hash["title"]
		self.details = hash["details"]
		self.isComplete = hash["is_complete"]
		self.sync_code = hash["sync_code"]
		self.image_url = hash["image_url"]
	end

end

class Session
	include DataMapper::Resource
	property :id, Serial
	property :digest, String, :length => 1..255

	belongs_to :user

end



DataMapper.setup(:default, ENV['DATABASE_URL'] ||  "sqlite3://#{Dir.pwd}/dev.db")
DataMapper.finalize
DataMapper.auto_upgrade!