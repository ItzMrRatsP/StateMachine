-- stylua: ignore start

type State<T...> = {
	update: (dt: number) -> ()?,
	enter: (T...) -> ()?,
	exit: (T...) -> ()?,
	canEnter: (...any) -> boolean,
}

export type StateManager = {
	currentState: State<...any>?,
	_states: { State<...any>? },

	update: (StateManager) -> (),
	add: (StateManager, initialStateId: string, initalState: State<...any>) -> (),
	exit: (StateManager, ...any) -> (),
	switch: (StateManager, ...any) -> (),
	remove: (StateManager, ...any) -> (),
}

local stateMachine = {}

function stateMachine.new(): StateManager
	local self = {}
	self.currentState = nil
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

	return table.freeze(self) :: StateManager
end

function stateMachine:add(newStateId, newState)
	if self._states[newStateId] then
		warn(`{newStateId} is already existing state, Please try another id`)
		return
	end

	self._states[newStateId] = newState :: State<...any>
end

--[[
.update(event: RunServiceEvents): ()
    Update functions will connect one of the runservice signals to the current running state update function.
    If the state doesn't have update function then it won't work.
]]
function stateMachine:update(dt: number)
	-- Check: Check if update function is a thing, If it doesn't exist there is no point in calling.
	if not self.currentState or not self.currentState.update then
		return
	end

	-- Call the .update function with deltaTime
	self.currentState.update(dt)
end

--[[
Switch to the desired state, But the state must be added using :add() method
state: The state id we're trying to switch to
]]
function stateMachine:switch(StateId, ...)
	-- The state doesn't even exist, how do you expect it to work.
	-- To avoid leaving the state that we're already in we use this method
	if not self.currentState or self.currentState == StateId then
		return
	end

	-- We leave the previous state so we won't have 2 state running, Thats the whole point of statemachine.
	self:exit()

	-- Enter to the current state
	self.currentState = self._states[StateId] :: State<...any>
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
This will exit the currently running state, So for example if our currently running state is "Run" then we will exit the state "Run"
No arguments required
]]
function stateMachine:exit(...)
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
Remove the state from state machine, But becareful if the state you're removing get called later then it will cause an error
]]
function stateMachine:remove(stateId: string, ...)
	-- There is no point in going forward, Because the stateId doesn't exist in self_states.
	if not self._states[stateId] then
		return
	end

	-- Remove the state from statemachine if we happend to have a case that we needed to remove state.
	if self.currentState == self._state[stateId] then
		self.currentState.exit(...)
	end

	self._state[stateId] = nil
end

return stateMachine

--[[
Author: @ItzMrRatsP
Publish Date: 4/30/2025
]]
