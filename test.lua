local RunService = game:GetService("RunService")
local StateMachine = require(script.Parent).new()

RunService.PreRender:Connect(function(deltaTime: number)
	StateMachine:update(deltaTime)
end)

StateMachine:add("Test", {
	enter = function()
		print("I believe this will print when you enter the test state")
	end,

	update = function(dt)
		print("deltaTime: " .. dt)
	end,

	exit = function()
		print("I believe this will print when you exit the test state")
	end,
})

StateMachine:switch("Test")
