-- stylua: ignore start

export type State<T...> = {
	update: (dt: number) -> ()?,
	enter: (T...) -> ()?,
	exit: (T...) -> ()?,
	canEnter: (...any) -> boolean?,
	canExit: (...any) -> boolean?
}

export type StateManager = {
	_runningStateId: string,
	currentState: State<...any>?,
	_states: { [string]: State<...any>? },

	getRunningState: (self: StateManager) -> string,
	update: (self: StateManager, deltaTime: number) -> (),
	add: (self: StateManager, newStateId: string, newState: State<...any>) -> (),
	exit: (self: StateManager, ...any) -> boolean,
	switch: (self: StateManager, stateId: string, ...any) -> (),
	remove: (self: StateManager, ...any) -> (),
}

local stateMachine = {}


--[[
	Creates a new state machine.

	Returns:
	StateManager: The new state machine.

	This function creates a new state machine with no states. The state machine has the following methods:

	- add: Adds a new state to the state machine.
	- exit: Exits the current state.
	- switch: Switches to a different state.
	- update: Updates the current state.
	- remove: Removes a state from the state machine.

	The state machine also has the following properties:
	- currentState: The current state of the state machine.
	- _states: A table of all states in the state machine.
	- _runningStateId: A string that represent the current running state id.
]]--
function stateMachine.new(): StateManager
	local self = {}

	self.currentState = nil
	self._runningStateId = nil

	self._states = {}

	self.add = stateMachine.add
	self.exit = stateMachine.exit
	self.switch = stateMachine.switch
	self.update = stateMachine.update
	self.remove = stateMachine.remove

	--[[
		RunService.Heartbeat:Connect(function(dt)
			StateManager:update(dt)
		end)
	]]

	return self :: StateManager
end

--[[
Adds a new state to the state machine.

Arguments:
- newStateId (string): The unique identifier for the new state.
- newState (State<...any>): The new state to be added to the state machine.

This function first checks if the state to be added already exists in the state machine's list of states. If it does, the function will exit early with a warning message. If the state does not exist, the function will add the new state to the list of states with the provided newStateId.

The function does not check if the newStateId is a string or not, or if the newState has the required functions (enter, exit, update, canEnter). It is up to the user to ensure that the newStateId is a valid string and that the newState has the required functions.
]]--
function stateMachine.add(self: StateManager, newStateId: string, newState: State<...any>)
	local lowerStateId = string.lower(newStateId)
	
	if self._states[lowerStateId] then
		warn(`{newStateId} is already existing state, Please try another id`)
		return
	end

	self._states[lowerStateId] = newState :: State<...any>
end


--[[
Updates the state machine with the current deltaTime.

This function will first check if the state machine has a current state. If it doesn't, the function exits early. It will also check if the current state has an `update` function. If it doesn't, the function exits early. If both conditions are met, the function calls the `update` function with the provided deltaTime.
]]--
function stateMachine.update(self: StateManager, dt: number)
	-- Check: Check if update function is a thing, If it doesn't exist there is no point in calling.
	if not self.currentState or not self.currentState.update then
		return
	end

	-- Call the .update function with deltaTime
	self.currentState.update(dt)
end

--[[
Returns the id of the current running state.

This function simply returns the id of the current running state. If there is no current state, it will return an empty string.

Returns:
string: The id of the current running state.
]]--
function stateMachine.getRunningState(self: StateManager): string
	return self._runningStateId
end

--[[
Switches to a different state.

Arguments:
- StateId (string): The unique identifier for the state to switch to.
- ... (any): Additional arguments that may be passed to the state's enter function.

This function will first check if the state machine is currently frozen. If it is, the function will exit early with a warning message. It will also check if the state to switch to is already the current state, and if so it will exit early without doing anything. If the state to switch to does not exist in the state machine's list of states, the function will exit early with a warning message.

The function will then exit the current state by calling its exit function, and then enter the new state by calling its enter function. If the new state has a canEnter function, the function will call it and check its return value. If the value is false, the function will exit early without switching states.

Finally, the function will set the state machine's currentState property to the new state, indicating that the state machine is now in the new state.
]]--
function stateMachine.switch(self: StateManager, StateId: string, ...)
	-- Lower the state id, So we can use it without having to care about the case-sensitivity
	local lowerStateId = string.lower(StateId)

	-- To avoid leaving the state that we're already in we use this method
	-- Check if currentstate matches previous state
	if lowerStateId == self:getRunningState() then
		return
	end

	-- Exit the state that we were in previously
	local _didStateExit = self:exit(...)

	-- So basically, We want to make sure we left the last State, otherwise we wouldn't be able to exit.
	if not _didStateExit then
		return
	end

	-- Enter to the current state
	self.currentState = self._states[lowerStateId] :: State<...any>?

	-- The state doesn't even exist, how do you expect it to work.
	if not self.currentState then
		return
	end

	if self.currentState.canEnter and not self.currentState.canEnter(...) then
		return
	end

	-- We set the stateId to this state, Because we can enter this state
	-- This will be used for "getRunningState" method
	self._runningStateId = lowerStateId

	-- Enter the state
	if self.currentState.enter then
		self.currentState.enter(...)
	end
end


--[[
Exit the current state.

Arguments:
- ... (any): Additional arguments that may be passed to the state's exit function.

This function will first check if a state is currently active. If a state is active, it will call its exit function before removing it from the list of states. If no state is active, the function will exit early. Finally, the function will set the state machine's currentState property to nil, indicating that no state is currently active.
]]--
function stateMachine.exit(self: StateManager, ...)
	if not self.currentState then
		return false
	end

	-- Check if the conditions are met for leaving the state
	-- First we check if we have canExit in our state, And then we use it to see
	-- If we can exit the state.
	if self.currentState.canExit and not self.currentState.canExit(...) then
		return
	end

	-- If state has exit
	-- Then run that exit function with all args that we passed to exit function.
	if self.currentState.exit then
		self.currentState.exit(...)
	end

	-- Set currentState to nil, Because exit method only work with currentState
	-- Alongside it set the _runningStateId to "" so it we can switch states
	self._runningStateId = ""
	self.currentState = nil

	-- We exit the state successfully, So we can switch to another state, Or just return the state of exit
	return true
end


--[[
Removes a state from the state machine.

Arguments:
- stateId (string): The unique identifier for the state to be removed.
- ... (any): Additional arguments that may be passed to the state's exit function.

This function will first check if the provided stateId exists in the state machine's list of states. If the state does not exist, the function exits early. If the state exists and is currently active, it will call its exit function before removing it from the list of states.
]]
function stateMachine.remove(self: StateManager, stateId: string, ...)
	-- example: "LOWer" to "lower" so we can make it case sensitive
	local lowerStateId = string.lower(stateId)
	
	if not self._states[lowerStateId] then
		return
	end

	-- First check if currentState is a thing
	-- Then exit the state before removing it
	if self.currentState and self.currentState == self._states[lowerStateId] then
		self:exit(...)
	end

	self._states[lowerStateId] = nil
end

return stateMachine.new() :: StateManager

--[[
Author: @ItzMrRatsP
Publish Date: 4/30/2025
]]
