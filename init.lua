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
	_update: (StateManager) -> (),

	add: (StateManager, initialStateId: string, initalState: State<...any>) -> (),
	exit: (StateManager, ...any) -> (),
	switch: (StateManager, ...any) -> (),
}

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

	self.add = stateMachine.add
	self.exit = stateMachine.exit
	self.switch = stateMachine.switch
	self._update = stateMachine.update

	RunService.Heartbeat:Connect(function(dt)
		self:_update(dt)
	end)

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
function stateMachine:update(dt)
	-- Fatal: First check if state is there, Second check if state have .update function
	if not self._currentState then
		return
	end

	-- No update function
	if not self._currentState.update then
		return
	end

	self._currentState.update(dt)
end

--[[
Switch to the desired state, But the state must be added using :add() method
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
	if self._currentState.enter then
		self._currentState.enter(...)
	end

	-- Start the update after state is entered
end

--[[
This will exit the currently running state, So for example if our currently running state is "Run" then we will exit the state "Run"
No arguments required
]]
function stateMachine:exit(...)
	if not self._currentState then
		return
	end

	-- Leave the state
	if self._currentState.exit then
		self._currentState.exit(...)
	end

	self._currentState = nil
end

-- Remove states?
return stateMachine
