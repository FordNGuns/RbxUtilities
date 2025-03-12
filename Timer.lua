-- -----------------------------------------------------------------------------
--                        Timer Implementation for Luau                       --
-- A comprehensive Timer implementation that provides precise time tracking   --
-- and event handling. Features include start, stop, pause, and resume        --
-- functionality, along with duration-based timing and event signals for      --
-- various timer states. Perfect for game development, animations, and        --
-- time-based operations.                                                     --
--                                                                            --
-- License:                                                                   --
--   Licensed under the MIT license.                                          --
--                                                                            --
-- Authors:                                                                   --
--   FordNGuns - March 11th 2025 - Created the file                           --
-- -----------------------------------------------------------------------------

--[=[
    @class Timer

    Basic usage:
    ```lua
    local Timer = require(path.to.Timer)

    -- Create a 5-second timer
    local timer = Timer.new(5)

    -- Connect to timer events
    timer.Started:Connect(function()
        print("Timer started!")
    end)

    timer.Updated:Connect(function(elapsed)
        print("Time elapsed:", elapsed)
    end)

    timer.Finished:Connect(function()
        print("Timer finished!")
    end)

    -- Start the timer
    timer:Start()
    ```

    Advanced usage:
    ```lua
    local timer = Timer.new()

    -- Set up all event handlers
    local connections = {
        Started = timer.Started:Connect(function()
            print("Timer started")
        end),
        
        Updated = timer.Updated:Connect(function(elapsed)
            -- Updated fires 10 times per second
            print("Progress:", elapsed)
        end),
        
        Paused = timer.Paused:Connect(function()
            print("Timer paused")
        end),
        
        Resumed = timer.Resumed:Connect(function()
            print("Timer resumed")
        end),
        
        Finished = timer.Finished:Connect(function()
            print("Timer finished!")
        end)
    }

    -- Set duration after creation
    timer:SetDuration(10)

    -- Full timer control
    timer:Start()
    task.wait(2)
    timer:Pause()
    task.wait(1)
    timer:Resume()

    -- Clean up when done
    timer:Destroy()
    ```
]=]

local Signal = require(script.Parent.Signal)
local Maid = require(script.Parent.Maid)

local Timer = {}
Timer.__index = Timer

--[=[
    @desc Creates a new Timer instance
    @param duration - Optional duration in seconds for the timer
    @return Timer - A new Timer instance
]=]
function Timer.new(duration)
    local self = setmetatable({}, Timer)
    
    -- Initialize maid for cleanup
    self._maid = Maid.new()
    
    -- Timer state
    self._startTime = 0
    self._pausedTime = 0
    self._isPaused = false
    self._isRunning = false
    self._duration = duration or 0
    
    -- Create signals
    self.Started = Signal.new()
    self.Finished = Signal.new()
    self.Paused = Signal.new()
    self.Resumed = Signal.new()
    self.Stopped = Signal.new()
    self.Updated = Signal.new()
    
    -- Add signals to maid for cleanup
    self._maid:GiveTask(self.Started)
    self._maid:GiveTask(self.Finished)
    self._maid:GiveTask(self.Paused)
    self._maid:GiveTask(self.Resumed)
    self._maid:GiveTask(self.Stopped)
    self._maid:GiveTask(self.Updated)
    
    return self
end

--[=[
    @desc Sets the duration for the timer
    @param duration - Duration in seconds
]=]
function Timer:SetDuration(duration)
    self._duration = duration
end

--[=[
    @desc Gets the current duration setting
    @return number - Duration in seconds
]=]
function Timer:GetDuration()
    return self._duration
end

--[=[
    @desc Internal function to handle the update thread
    @private
]=]
function Timer:_startUpdateThread()
    -- Clean up existing update thread if it exists
    if self._maid._tasks.updateThread then
        self._maid:DoCleaning("updateThread")
    end
    
    -- Create new update thread
    self._maid:GiveTask("updateThread", task.spawn(function()
        while self._isRunning and not self._isPaused do
            local elapsed = self:GetElapsed()
            self.Updated:Fire(elapsed)
            
            if self._duration > 0 and elapsed >= self._duration then
                self:Stop()
                self.Finished:Fire()
                break
            end
            
            task.wait(0.1) -- Update 10 times per second
        end
    end))
end

--[=[
    @desc Starts the timer
    @fires Started - When the timer starts
    @fires Updated - Periodically while the timer is running
    @fires Finished - When the timer reaches its duration
]=]
function Timer:Start()
    if not self._isRunning then
        self._startTime = os.clock()
        self._isRunning = true
        self._isPaused = false
        self.Started:Fire()
        self:_startUpdateThread()
    end
end

--[=[
    @desc Stops and resets the timer
    @fires Stopped - When the timer is stopped
]=]
function Timer:Stop()
    if self._isRunning then
        if self._maid._tasks.updateThread then
            self._maid:DoCleaning("updateThread")
        end
        
        self._isRunning = false
        self._isPaused = false
        self._startTime = 0
        self._pausedTime = 0
        self.Stopped:Fire()
    end
end

--[=[
    @desc Pauses the timer
    @fires Paused - When the timer is paused
]=]
function Timer:Pause()
    if self._isRunning and not self._isPaused then
        if self._maid._tasks.updateThread then
            self._maid:DoCleaning("updateThread")
        end
        
        self._pausedTime = os.clock() - self._startTime
        self._isPaused = true
        self.Paused:Fire()
    end
end

--[=[
    @desc Resumes the timer from a paused state
    @fires Resumed - When the timer is resumed
    @fires Updated - Periodically after resuming
    @fires Finished - When the timer reaches its duration after resuming
]=]
function Timer:Resume()
    if self._isRunning and self._isPaused then
        self._startTime = os.clock() - self._pausedTime
        self._isPaused = false
        self.Resumed:Fire()
        self:_startUpdateThread()
    end
end

--[=[
    @desc Gets the current elapsed time
    @return number - Elapsed time in seconds
]=]
function Timer:GetElapsed()
    if not self._isRunning then
        return 0
    end
    
    if self._isPaused then
        return self._pausedTime
    end
    
    return os.clock() - self._startTime
end

--[=[
    @desc Checks if the timer is currently running
    @return boolean - True if running, false otherwise
]=]
function Timer:IsRunning()
    return self._isRunning
end

--[=[
    @desc Checks if the timer is currently paused
    @return boolean - True if paused, false otherwise
]=]
function Timer:IsPaused()
    return self._isPaused
end

--[=[
    @desc Cleans up the timer, all signals, and threads
]=]
function Timer:Destroy()
    self:Stop()
    self._maid:Destroy()
    self._maid = nil
    setmetatable(self, nil)
end

return Timer
