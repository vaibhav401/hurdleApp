require 'time'

def popDB
	(1..20).each do |i|
		user = User.create(:username => "random" + i.to_s, :full_name => "random" + i.to_s,
		 :password => (i.to_s * 3), :image_url => "www.google.com", :modified_after => Time.now.to_i)
		team = Team.create(:name => "RandomTeam" + i.to_s, :image_url => "www.google.com",
			:scrum_master => user, :modified_after => Time.now.to_i, :pass => (i.to_s * 3))	
		
		task = Task.create(:title => "Randome Title No " + i.to_s, :detail => "Random content" * 5, 
			:isComplete => false,:user => user, :team => team, :modified_after => Time.now.to_i, 
			:priority => (i % 5),:image_url =>"www.google.com")
		team.members << user
		user.team = team
		user.tasks << task
		team.tasks << task
		user.save
		team.save
		task.save
		showError team
		showError task
		showError user
	end
end

def showError ( object)
	i = 0  # refactor it
	object.errors.full_messages.each do |msg|
		puts msg
	end	
end 