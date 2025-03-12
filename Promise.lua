-- -----------------------------------------------------------------------------
--                       Promise Implementation for Luau                      --
-- A robust Promise implementation that follows Promise/A+ specification.     --
-- Provides a way to handle asynchronous operations with proper error         --
-- handling, chaining, and state management. Includes support for all         --
-- standard Promise operations including then, catch, finally, and all.       --
--                                                                            --
-- License:                                                                   --
--   Licensed under the MIT license.                                          --
--                                                                            --
-- Authors:                                                                   --
--   FordNGuns - March 11th 2025 - Created the file                           --
-- -----------------------------------------------------------------------------

--[=[
    @class Promise

    Basic usage:
    ```lua
    local Promise = require(path.to.Promise)

    -- Create and use a promise
    local function fetchData()
        return Promise.new(function(resolve, reject)
            -- Simulate async operation
            task.delay(1, function()
                local success = true
                if success then
                    resolve("Data fetched!")
                else
                    reject("Failed to fetch data")
                end
            end)
        end)
    end

    fetchData()
        :andThen(function(result)
            print("Success:", result)
        end)
        :catch(function(error)
            warn("Error:", error)
        end)
    ```

    Advanced usage:
    ```lua
    -- Promise.all
    local promises = {
        Promise.new(function(resolve) task.delay(2, function() resolve(1) end) end),
        Promise.new(function(resolve) task.delay(1, function() resolve(2) end) end)
    }

    Promise.all(promises):andThen(function(results)
        for i, result in ipairs(results) do
            print(i, result)
        end
    end)

    -- Promise.race
    Promise.race(promises):andThen(print)

    -- Promise with timeout
    local function fetchWithTimeout(timeout)
        return Promise.race({
            fetchData(),
            Promise.new(function(_, reject)
                task.delay(timeout, function()
                    reject("Timeout")
                end)
            end)
        })
    end

    -- Chaining promises
    fetchData()
        :andThen(function(data)
            return Promise.new(function(resolve)
                resolve(data .. " - Processed")
            end)
        end)
        :andThen(print)
        :catch(warn)
        :finally(function()
            print("Operation complete")
        end)
    ```
]=]

local Promise = {}
Promise.__index = Promise

-- Promise states
local PENDING = "pending"
local FULFILLED = "fulfilled"
local REJECTED = "rejected"

--[=[
    @desc Creates a new Promise
    @param executor - Function that receives resolve and reject functions
    @return Promise - A new Promise instance
]=]
function Promise.new(executor)
    if type(executor) ~= "function" then
        error("Promise executor must be a function", 2)
    end

    local self = setmetatable({
        _state = PENDING,
        _value = nil,
        _reason = nil,
        _thenQueue = {},
        _finallyQueue = {},
        _handled = false
    }, Promise)

    local function resolve(value)
        if self._state ~= PENDING then return end
        
        -- Handle promise resolution
        if type(value) == "table" and value.andThen then
            value:andThen(
                function(val) resolve(val) end,
                function(reason) reject(reason) end
            )
            return
        end

        self._state = FULFILLED
        self._value = value
        self:_processQueue()
    end

    local function reject(reason)
        if self._state ~= PENDING then return end
        
        self._state = REJECTED
        self._reason = reason
        self:_processQueue()
        
        -- Warn if unhandled rejection
        task.delay(0, function()
            if not self._handled and self._state == REJECTED then
                warn("Unhandled promise rejection:", reason)
            end
        end)
    end

    -- Execute the promise
    task.spawn(function()
        local success, result = pcall(executor, resolve, reject)
        if not success then
            reject(result)
        end
    end)

    return self
end

--[=[
    @desc Internal method to process the queue of callbacks
    @private
]=]
function Promise:_processQueue()
    -- Process then queue
    while #self._thenQueue > 0 do
        local item = table.remove(self._thenQueue, 1)
        local success, result = pcall(function()
            if self._state == FULFILLED then
                if item.onFulfilled then
                    return item.onFulfilled(self._value)
                end
                return self._value
            elseif self._state == REJECTED then
                if item.onRejected then
                    self._handled = true
                    return item.onRejected(self._reason)
                end
                return Promise.reject(self._reason)
            end
        end)

        if success then
            item.resolve(result)
        else
            item.reject(result)
        end
    end

    -- Process finally queue
    while #self._finallyQueue > 0 do
        local callback = table.remove(self._finallyQueue, 1)
        callback()
    end
end

--[=[
    @desc Attaches callbacks for the resolution and/or rejection of the Promise
    @param onFulfilled - Function called when promise is fulfilled
    @param onRejected - Function called when promise is rejected
    @return Promise - A new Promise
]=]
function Promise:andThen(onFulfilled, onRejected)
    return Promise.new(function(resolve, reject)
        table.insert(self._thenQueue, {
            onFulfilled = type(onFulfilled) == "function" and onFulfilled or nil,
            onRejected = type(onRejected) == "function" and onRejected or nil,
            resolve = resolve,
            reject = reject
        })

        if self._state ~= PENDING then
            self:_processQueue()
        end
    end)
end

--[=[
    @desc Attaches a callback for only the rejection of the Promise
    @param onRejected - Function called when promise is rejected
    @return Promise - A new Promise
]=]
function Promise:catch(onRejected)
    return self:andThen(nil, onRejected)
end

--[=[
    @desc Attaches a callback that is invoked when the Promise is settled
    @param onFinally - Function called when promise is settled
    @return Promise - A new Promise
]=]
function Promise:finally(onFinally)
    if type(onFinally) == "function" then
        table.insert(self._finallyQueue, onFinally)
        
        if self._state ~= PENDING then
            self:_processQueue()
        end
    end
    return self
end

--[=[
    @desc Creates a Promise that is resolved with a given value
    @param value - Value to resolve the promise with
    @return Promise - A new Promise that is resolved with the given value
]=]
function Promise.resolve(value)
    return Promise.new(function(resolve)
        resolve(value)
    end)
end

--[=[
    @desc Creates a Promise that is rejected with a given reason
    @param reason - Reason for rejection
    @return Promise - A new Promise that is rejected with the given reason
]=]
function Promise.reject(reason)
    return Promise.new(function(_, reject)
        reject(reason)
    end)
end

--[=[
    @desc Returns a promise that resolves when all promises have resolved
    @param promises - Array of promises to wait for
    @return Promise - A new Promise that resolves with an array of results
]=]
function Promise.all(promises)
    if type(promises) ~= "table" then
        return Promise.reject("Promise.all requires an array of promises")
    end

    return Promise.new(function(resolve, reject)
        if #promises == 0 then
            resolve({})
            return
        end

        local results = {}
        local completed = 0
        local rejected = false

        for i, promise in ipairs(promises) do
            if type(promise) ~= "table" or not promise.andThen then
                promise = Promise.resolve(promise)
            end

            promise:andThen(
                function(result)
                    if rejected then return end
                    results[i] = result
                    completed = completed + 1
                    if completed == #promises then
                        resolve(results)
                    end
                end,
                function(reason)
                    if rejected then return end
                    rejected = true
                    reject(reason)
                end
            )
        end
    end)
end

--[=[
    @desc Returns a promise that resolves or rejects as soon as one of the promises resolves or rejects
    @param promises - Array of promises to race
    @return Promise - A new Promise that resolves or rejects with the first result
]=]
function Promise.race(promises)
    if type(promises) ~= "table" then
        return Promise.reject("Promise.race requires an array of promises")
    end

    return Promise.new(function(resolve, reject)
        for _, promise in ipairs(promises) do
            if type(promise) ~= "table" or not promise.andThen then
                promise = Promise.resolve(promise)
            end

            promise:andThen(resolve, reject)
        end
    end)
end

--[=[
    @desc Returns a promise that resolves when all promises have settled
    @param promises - Array of promises to wait for
    @return Promise - A new Promise that resolves with an array of results
]=]
function Promise.allSettled(promises)
    if type(promises) ~= "table" then
        return Promise.reject("Promise.allSettled requires an array of promises")
    end

    local function createSettledResult(state, value)
        return {
            status = state,
            value = state == FULFILLED and value or nil,
            reason = state == REJECTED and value or nil
        }
    end

    local wrappedPromises = {}
    for i, promise in ipairs(promises) do
        wrappedPromises[i] = Promise.resolve(promise):andThen(
            function(value)
                return createSettledResult(FULFILLED, value)
            end,
            function(reason)
                return createSettledResult(REJECTED, reason)
            end
        )
    end

    return Promise.all(wrappedPromises)
end

--[=[
    @desc Delays the resolution of a promise by a specified time
    @param seconds - Number of seconds to delay
    @return Promise - A new Promise that resolves after the delay
]=]
function Promise.delay(seconds)
    return Promise.new(function(resolve)
        task.delay(seconds, resolve)
    end)
end

--[=[
    @desc Retries a promise-returning function with a specified number of attempts
    @param fn - Function that returns a promise
    @param attempts - Number of attempts to make
    @param delay - Delay between attempts in seconds
    @return Promise - A new Promise that resolves when the operation succeeds
]=]
function Promise.retry(fn, attempts, delay)
    return Promise.new(function(resolve, reject)
        local attempt = 0
        local function tryFn()
            attempt = attempt + 1
            return Promise.resolve(fn()):andThen(
                resolve,
                function(err)
                    if attempt >= attempts then
                        reject(err)
                    else
                        task.delay(delay or 0, tryFn)
                    end
                end
            )
        end
        tryFn()
    end)
end

return Promise
