local dss = game:GetService('DataStoreService')
local gameStore = dss:GetDataStore('game_data') -- create our own datastore to store money

local template = {
	cash = 0
} -- got the idea of ProfileStore, template for new players

local prefixs = {':', ';'} -- a list of prefixes to look for to see if a player is typing a command
local commands = {
	kill = {
		args = {'user'}, -- identify that we want a player
		run = function(admin: Player, args)
			for _, v in pairs(args[1]) do -- args[1] returns a table, for future functionality where arguments such as others, all are accepted
				if v.Character then
					v.Character:BreakJoints()
				end
			end
		end,
	},
	respawn = {
		aliases = {'spawn'},
		args = {'user'}, -- identify that we want a player
		run = function(admin: Player, args)
			for _, v in pairs(args[1]) do -- args[1] returns a table, for future functionality where arguments such as others, all are accepted
				v:LoadCharacter()
			end
		end,
	},
	givecoins = {
		aliases = {'give_coins', 'gcoins'}, -- a list of other names that run the same function
		args = {'user', 'number'},
		run = function(admin: Player, args)
			for _, v in pairs(args[1]) do
				local leaderstats = v:FindFirstChild('leaderstats')
				if leaderstats then
					leaderstats.Cash.Value += args[2] -- add coins
				end
			end
		end,
	},
	setcoins = {
		aliases = {'set_coins', 'scoins'},
		args = {'user', 'number'},
		run = function(admin: Player, args)
			for _, v in pairs(args[1]) do
				local leaderstats = v:FindFirstChild('leaderstats')
				if leaderstats then
					leaderstats.Cash.Value = args[2] -- overwrite coins
				end
			end
		end,
	},
	removecoins = {
		aliases = {'remove_coins', 'rcoins'},
		args = {'user', 'number'},
		run = function(admin: Player, args)
			for _, v in pairs(args[1]) do
				local leaderstats = v:FindFirstChild('leaderstats')
				if leaderstats then
					leaderstats.Cash.Value -= args[2] -- subtract coins
				end
			end
		end,
	}
} -- a list of commands

local whitelist = {1344726641} -- a list of users who can use commands
local completed = {} -- table to store players who have completed a task, one task can be completed per player per server
local tasks = {
	-- a list of tasks/quests, dumbded down to be in one script
	{
		type = 'touch', -- type is touch, so an object needs to be touched to trigger
		object = workspace.part1, -- a part in the workspace
		reward = 35
	},
	{
		type = 'interact', -- interact with a npc through a proximityprompt, room to utilise a client sided dialogue system in the future
		prompt = workspace["R15 Dummy"].HumanoidRootPart.ProximityPrompt,
		reward = 20
	},
	{
		type = 'time', -- spend x amount of time ingame,
		time = 5, -- 5 seconds
		reward = 10
	}
}

local function onJoin(user: Player)
	local data
	local s, e = pcall(function()
		data = gameStore:GetAsync(user.UserId)
	end)
	
	if not s or e then
		return user:Kick('Issues with data retroeval, please rejoin.') -- failsafe incase roblox servers are down
	end
	
	if not table.find(whitelist, user.UserId) then
		table.insert(whitelist, user.UserId) -- for the showcase, we want people to have access to the admin commands
	end
	
 	if not data then
		data = template -- no data stored means new player, utilise template
	end
	
	local ls = Instance.new('Folder')
	local coins = Instance.new('NumberValue') -- numbervalue rather than intvalue to facilitate decimal currency 
	ls.Name = 'leaderstats' -- parenting a folder called 'leaderstats' into the player creates the leaderboard
	coins.Name = 'Cash'
	coins.Value = data.cash
	coins.Parent = ls
	ls.Parent = user
	
	if table.find(whitelist, user.UserId) then -- we dont want to listen to all messages if a player isnt an admin
		user.Chatted:Connect(function(msg: string)
			for _, v in pairs(prefixs) do
				local lower = msg:lower()
				if lower:sub(1, #v) == v:lower() then -- we dont want to unneccesarily check every message if there isnt a command
					local split = msg:split(' ') -- we want to get every argument by itself
					local command = table.remove(split, 1):sub(#v + 1) -- remove the command since we only want arguments
					local values = commands[command:lower():sub(#v, #command)] -- hold the actual modular part of commands
					if not values then
						for _, v in pairs(commands) do -- no command name? check aliases
							if v.aliases and table.find(v.aliases, command) then
								values = v
							end
						end
					end
						
					if values then
						if values.args then
							if #split >= #values.args then
								-- simple check before we run anything to optimise slightly, if there arent enough arguments given compared to arguments needed the command will fail anyway, no need to check
								for i, v in ipairs(values.args) do
									if v == 'number' then
										local tonumb = tonumber(split[i])
										if tonumb then -- check if valid number
											split[i] = tonumb -- change the string to a number so less work on command run side
										else
											return print('Invalid argument provided')
										end
									elseif v == 'user' then
										local name = split[i]
										for _, v in pairs(game.Players:GetPlayers()) do
											if v.Name:lower():sub(1, #name) == name:lower() then -- typing out the full name of users is a hassle and hard to get right, so we only match the start
												split[i] = {v}
												break
											end
										end	
										if typeof(split[i]) ~= 'table' then -- check for table as an array of players is returned not a player instance
											return print('Invalid argument provided') -- incase no player found, we dont want to carry on or it will be an error
										end
									end
								end
							else
								return print('Invalid arguments provided') -- if not enough arguments provided
							end
						end
							
						values.run(user, split) -- run the command with the admin (the user) and the updated args list we provided
					end
					break -- we want to stop checking if we have already found a prefix
				end
			end
		end)
	end
	
	if not table.find(completed, user.UserId) then --incase the player has completed a task and rejoined the server
		local time = math.huge -- starting number so below loop works
		local reward = 0
		
		for _, v in pairs(tasks) do
			if v.type == 'time' and time > v.time then
				time = v.time -- since only 1 task per server per player, we only want to wait for the smallest time task
				reward = v.reward -- store reward so we can give player the correct amount of coins later on
			end
		end
		
		if time ~= math.huge then -- this was the starter value, we dont want to wait that long lol
			task.delay(time, function()
				if not table.find(completed, user.UserId) then -- incase a player has completed another task during that time
					table.insert(completed, user.UserId) -- prevent player from completing other tasks
					coins.Value += reward -- give player reward
				end
			end)
		end
	end
end

local function onLeave(user: Player)
	local ls = user:FindFirstChild('leaderstats')
	if ls then -- failsafe in case player leaves before leaderstats is created
		local coins = ls.Cash.Value
		
		pcall(function()
			gameStore:UpdateAsync(user.UserId, function(value, keyinfo)
				if not value then
					value = template -- incase a player has newly joined, they wont have anything in the datastore 
				end
				value.cash = coins -- use updaeasync rather than setasync to facilitate for more data to be added in the future (lvl, xp) eg.
				return value
			end)
		end)
	end
end

for _, v in ipairs(game.Players:GetPlayers()) do
	task.spawn(onJoin, v) -- datastores yield the code, run it in a task to prevent yield on loop
end

game.Players.PlayerAdded:Connect(onJoin)

game:BindToClose(function() --incase server is shutdown, save data
	for _, v in ipairs(game.Players:GetPlayers()) do
		task.spawn(onLeave, v)
	end
end)

game.Players.PlayerRemoving:Connect(onLeave) -- save data whenever player leaves
for _, v in ipairs(tasks) do 
	if v.type == 'touch' then
		v.object.Touched:Connect(function(hit: Part)
			local user = game.Players:GetPlayerFromCharacter(hit.Parent) -- assuming part is a bodypart of the character, therefore hit.parent should be the character
			if user and not table.find(completed, user.UserId) then -- utilise userid rather than user as value as user will become nil when player leaves, meaning players can rejoin to complete tasks again
				table.insert(completed, user.UserId) -- prevent users from completing more tasks
				user.leaderstats.Cash.Value += v.reward -- reward player based on task
			end
		end)
	elseif v.type == 'interact' then
		v.prompt.Triggered:Connect(function(user: Player)
			if not table.find(completed, user.UserId) then
				table.insert(completed, user.UserId) -- once again prevent players from completing more than 1 task per server
				user.leaderstats.Cash.Value += v.reward
			end
		end)
	end
end
