local RunService = game:GetService("RunService")

type State<T...> = {
	update: (dt: number) -> ()?,
	enter: (T...) -> ()?,
	exit: (T...) -> ()?,
}

export type StateManager = {
	_currentState: State<...any>?,
	_currentConnection: RBXScriptConnection?,
	_states: { State<...any>? },
	_disconnectConnection: () -> (),
	_bindUpdate: (StateManager, event: RunServiceEvents) -> (),

	add: (StateManager, initialStateId: string, initalState: State<...any>) -> (),
	exit: (StateManager, ...any) -> (),
	switch: (StateManager, ...any) -> (),
}

type RunServiceEvents = "Heartbeat" | "PreRender" | "PreSimulation" | "PreAnimation"

local stateMachine = {}

function stateMachine.new(): StateManager
	local self = {}
	self._currentState = nil
	self._currentConnection = nil
	self._states = {}
	self._disconnectConnection = function()
		if self._currentConnection and self._currentConnection.Connected then
			self._currentConnection:Disconnect()
		end
	end

	self._bindUpdate = stateMachine.bindUpdate

	self.add = stateMachine.add
	self.exit = stateMachine.exit
	self.switch = stateMachine.switch

	return self :: StateManager
end

function stateMachine:add(initalStateId, initalState)
	if self._states[initalStateId] then
		warn(`{initalStateId} is already existing state, Please try another id`)
		return
	end

	self._states[initalStateId] = initalState :: State<...any>
end

--[[
.update(event: RunServiceEvents): ()
    Update functions will connect one of the runservice signals to the current running state update function.
    If the state doesn't have update function then it won't work.
]]
function stateMachine:bindUpdate()
	-- Disconnect the current running loop
	self._disconnectConnection()

	-- First check if state is there, Second check if state have .update function
	if not self._currentState or not self._currentState.update then
		return
	end

	self._currentConnection = RunService.Heartbeat:Connect(self._currentState.update)
end

--[[
Switch to the desired state, But the state must be added using .new() method
state: The state id we're trying to switch to
]]
function stateMachine:switch(initialStateId, ...)
	-- The state doesn't even exist, how do you expect it to work.
	local initialState = self._states[initialStateId]
	if not initialState then
		return
	end

	if self._currentState ~= nil then
		if self._currentState == initialState then
			return
		end

		-- Leave the current state so we can move to the next state
		self:exit()
	end

	-- Enter to the current state
	self._currentState = self._states[initialStateId] :: State<...any>
	if not self._currentState then
		return
	end

	-- Enter the state
	self._currentState.enter(...)

	-- Start the update after state is entered
	self:_bindUpdate()
end

--[[
This will exit the currently running state, So for example if our currently running state is "Run" then we will exit the state "Run"
No arguments required
]]
function stateMachine:exit(...)
	if not self._currentState then
		return
	end

	-- Disconnect the update loop
	self._disconnectConnection()

	-- Leave the state
	self._currentState.exit(...)
	self._currentState = nil
end

-- Remove states?
return stateMachine
