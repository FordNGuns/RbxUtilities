-- -----------------------------------------------------------------------------
--                        Maid Implementation for Luau                        --
-- A utility module that helps manage cleanup of objects, connections, and    --
-- tasks. The Maid automatically handles the destruction of objects and       --
-- disconnection of signals when they are no longer needed. This is           --
-- particularly useful for maintaining clean and memory-efficient code.       --
--                                                                            --
-- License:                                                                   --
--   Licensed under the MIT license.                                          --
--                                                                            --
-- Authors:                                                                   --
--   FordNGuns - March 11th 2025 - Created the file                           --
-- -----------------------------------------------------------------------------

--[=[
    @class Maid

    Basic usage:
    ```lua
    local Maid = require(path.to.Maid)

    -- Create a new maid
    local maid = Maid.new()

    -- Add a connection to clean up
    local connection = someSignal:Connect(function() end)
    maid:GiveTask(connection)

    -- Add a function to run during cleanup
    maid:GiveTask(function()
        print("Cleaning up!")
    end)

    -- Clean everything up
    maid:Destroy()
    ```

    Advanced usage:
    ```lua
    local maid = Maid.new()

    -- Give tasks with unique keys
    maid:GiveTask("connection1", someSignal:Connect(function() end))
    maid:GiveTask("connection2", otherSignal:Connect(function() end))

    -- Clean up specific task
    maid:DoCleaning("connection1")

    -- Add an instance to clean up
    local part = Instance.new("Part")
    maid:GiveTask(part)

    -- Add a table with a destroy method
    local customObject = {
        Destroy = function(self)
            print("Custom cleanup!")
        end
    }
    maid:GiveTask(customObject)

    -- Clean up everything
    maid:Destroy()
    ```
]=]

local Maid = {}
Maid.__index = Maid

--[=[
    @desc Creates a new Maid instance
    @return Maid - A new Maid instance
]=]
function Maid.new()
    local self = setmetatable({
        _tasks = {}
    }, Maid)
    return self
end

--[=[
    @desc Gives the Maid a task to clean up
    @param taskOrKey - Task to clean up, or key if second parameter is provided
    @param task - Optional task if first parameter is a key
]=]
function Maid:GiveTask(taskOrKey, task)
    if task == nil then
        -- Handle numeric keys
        if type(taskOrKey) == "number" then
            self._tasks[taskOrKey] = nil
        end
        
        self._tasks[#self._tasks + 1] = taskOrKey
    else
        self._tasks[taskOrKey] = task
    end
end

--[=[
    @desc Cleans up a specific task
    @param key - Key of the task to clean up
]=]
function Maid:DoCleaning(key)
    local task = self._tasks[key]
    if task then
        self._tasks[key] = nil
        self:_cleanupTask(task)
    end
end

--[=[
    @desc Internal function to clean up a single task
    @param task - Task to clean up
    @private
]=]
function Maid:_cleanupTask(task)
    local taskType = type(task)
    
    if taskType == "function" then
        task()
    elseif taskType == "table" then
        if typeof(task) == "RBXScriptConnection" then
            task:Disconnect()
        elseif type(task.Destroy) == "function" then
            task:Destroy()
        elseif type(task.destroy) == "function" then
            task:destroy()
        end
    elseif typeof(task) == "Instance" then
        task:Destroy()
    end
end

--[=[
    @desc Cleans up all tasks and removes them from the Maid
]=]
function Maid:Destroy()
    local tasks = self._tasks
    for key, task in pairs(tasks) do
        tasks[key] = nil
        self:_cleanupTask(task)
    end
end

--[=[
    @desc Returns whether the Maid has any tasks
    @return boolean - True if the Maid has tasks, false otherwise
]=]
function Maid:HasTasks()
    return next(self._tasks) ~= nil
end

return Maid
