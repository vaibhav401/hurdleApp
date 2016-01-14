(1..200).each do |i|
	t = Team.create(:hastag => "RandomTeam" + i.to_s, :description => "Random content" * 5)
	u = User.create(:username => "random" + i.to_s, :password => (i.to_s * 3))
	to = Todo.create(:title => "Randome Title No " + i.to_s, :description => "Random content" * 5, :isComplete => false)
	u.team = t
	to.user = u
	t.save
	to.save
	u.save
end