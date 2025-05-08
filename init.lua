-- stylua: ignore start

type State<T...> = {
	update: (dt: number) -> ()?,
	enter: (T...) -> ()?,
	exit: (T...) -> ()?,
	canEnter: (...any) -> boolean?,
}

export type StateManager = {
	currentState: State<...any>?,
	_states: { [string]: State<...any>? },
	_freeze: boolean,
	_runningTaskDelay: thread?,

	update: (self: StateManager, deltaTime: number) -> (),
	add: (self: StateManager, newStateId: string, newState: State<...any>) -> (),
	exit: (self: StateManager, ...any) -> (),
	switch: (self: StateManager, stateId: string, ...any) -> (),
	remove: (self: StateManager, ...any) -> (),
	freeze: (self: StateManager, requiredTimeForUnfreeze: number, afterFreeze: () -> ()) -> ()
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
	- freeze: Freezes the state machine for a given amount of time.

	The state machine also has the following properties:

	- currentState: The current state of the state machine.
	- _states: A table of all states in the state machine.
	- _freeze: A boolean indicating if the state machine is currently frozen.
	- _runningTaskDelay: A thread representing the current freeze task.
]]--
function stateMachine.new(): StateManager
	local self = {}
	self.currentState = nil
	self._freeze = false
	self._runningTaskDelay = nil

	self._states = {}

	self.add = stateMachine.add
	self.exit = stateMachine.exit
	self.switch = stateMachine.switch
	self.update = stateMachine.update
	self.remove = stateMachine.remove
	self.freeze = stateMachine.freeze

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
	if self._states[newStateId] then
		warn(`{newStateId} is already existing state, Please try another id`)
		return
	end

	self._states[newStateId] = newState :: State<...any>
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
Switches to a different state.

Arguments:
- StateId (string): The unique identifier for the state to switch to.
- ... (any): Additional arguments that may be passed to the state's enter function.

This function will first check if the state machine is currently frozen. If it is, the function will exit early with a warning message. It will also check if the state to switch to is already the current state, and if so it will exit early without doing anything. If the state to switch to does not exist in the state machine's list of states, the function will exit early with a warning message.

The function will then exit the current state by calling its exit function, and then enter the new state by calling its enter function. If the new state has a canEnter function, the function will call it and check its return value. If the value is false, the function will exit early without switching states.

Finally, the function will set the state machine's currentState property to the new state, indicating that the state machine is now in the new state.
]]--
function stateMachine.switch(self: StateManager, StateId: string, ...)
	if self._freeze then
		warn("State is freezed, Wait until the freeze is removed")
		return
	end

	-- The state doesn't even exist, how do you expect it to work.
	-- To avoid leaving the state that we're already in we use this method
	-- Check if currentstate matches previous state
	if self.currentState == self._states[StateId] then
		return
	end

	-- Exit the state that we were in previously
	self:exit()

	-- Enter to the current state
	self.currentState = self._states[StateId] :: State<...any>?
	if not self.currentState then
		return
	end

	if self.currentState.canEnter and not self.currentState.canEnter(...) then
		return
	end

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
		return
	end

	-- Leave the state
	if self.currentState.exit then
		self.currentState.exit(...)
	end

	self.currentState = nil
end


--[[
Removes a state from the state machine.

Arguments:
- stateId (string): The unique identifier for the state to be removed.
- ... (any): Additional arguments that may be passed to the state's exit function.

This function will first check if the provided stateId exists in the state machine's list of states. If the state does not exist, the function exits early. If the state exists and is currently active, it will call its exit function before removing it from the list of states.
]]
function stateMachine.remove(self: StateManager, stateId: string, ...)
	if not self._states[stateId] then
		return
	end

	if not self.currentState then 
		return 
	end

	if self.currentState == self._states[stateId] then
		self:exit(...)
	end

	self._states[stateId] = nil
end

--[[
Freeze the state machine for a given amount of time, When the time is over then afterFreeze callback will be called.

This function is useful if you want to freeze the state machine for a given amount of time when a certain event happens. For example, You might want to freeze the state machine after player teleports, So that the state machine doesn't do anything until the teleportation is complete.

You can also use this function to freeze the state machine when the player is in a cinematic, Or when the player is in a cutscene.

The function takes two arguments, The first argument is the amount of time you want to freeze the state machine for, And the second argument is the callback that will be called after the state machine is unfrozen.

Note: If you call this function when the state machine is already freezed, Then it will cancel the previous freezed state machine and start a new one.
]]--
function stateMachine.freeze(self: StateManager, requiredTimeForUnfreeze: number, afterFreeze: () -> ())
	if self._freeze and self._runningTaskDelay then
		task.cancel(self._runningTaskDelay)
	end

	self._freeze = true
	self._runningTaskDelay = task.delay(requiredTimeForUnfreeze, function()
		self._freeze = false
		afterFreeze()
	end)
end

return stateMachine

--[[
Author: @ItzMrRatsP
Publish Date: 4/30/2025
]]
