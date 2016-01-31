(1..20).each do |i|
	team = Team.create(:name => "RandomTeam" + i.to_s)
	user = User.create(:username => "random" + i.to_s, :full_name => "random" + i.to_s, :password => (i.to_s * 3))
	task = Task.create(:title => "Randome Title No " + i.to_s, :details => "Random content" * 5, :isComplete => false,
			:user => user, :team => team)
	team.members << user
	user.team = team
	team.scrum_master = user
	user.tasks << task
	team.tasks << task
	user.save
	team.save
	task.save
end