-- -----------------------------------------------------------------------------
--                        Queue Implementation for Luau                       --
-- A robust Queue data structure implementation that provides FIFO (First-    --
-- In-First-Out) operations. Supports push, pop, peek, clear, and iteration  --
-- with type safety and error handling. Ideal for managing ordered data      --
-- processing, task scheduling, and buffered operations.                     --
--                                                                           --
-- License:                                                                  --
--   Licensed under the MIT license.                                         --
--                                                                           --
-- Authors:                                                                  --
--   FordNGuns - March 11th 2025 - Created the file                          --
-- -----------------------------------------------------------------------------

--!strict

--[=[
    @class Queue
    A Queue class implementing FIFO (First-In-First-Out) operations.
    
    @example
    ```lua
    local queue = Queue.new()
    
    -- Add items
    queue:push("first")
    queue:push("second")
    
    -- Get items
    print(queue:pop()) -- "first"
    print(queue:peek()) -- "second"
    
    -- Check state
    print(queue:size()) -- 1
    print(queue:isEmpty()) -- false
    
    -- Iterate
    for item in queue:iterate() do
        print(item)
    end
    ```
]=]

local Queue = {}
Queue.__index = Queue

export type Queue<T> = {
    push: (self: Queue<T>, item: T) -> (),
    pop: (self: Queue<T>) -> T?,
    peek: (self: Queue<T>) -> T?,
    clear: (self: Queue<T>) -> (),
    size: (self: Queue<T>) -> number,
    isEmpty: (self: Queue<T>) -> boolean,
    toArray: (self: Queue<T>) -> {T},
    iterate: (self: Queue<T>) -> (() -> T?),
}

--[=[
    @return Queue
    Creates a new empty Queue instance
]=]
function Queue.new<T>(): Queue<T>
    local self = setmetatable({
        _first = 0,
        _last = -1,
        _items = {} :: {T},
    }, Queue)
    return self
end

--[=[
    @param item T -- Item to add to the queue
    Adds an item to the end of the queue
]=]
function Queue:push<T>(item: T)
    self._last += 1
    self._items[self._last] = item
end

--[=[
    @return T? -- The first item in the queue, or nil if empty
    Removes and returns the first item in the queue
]=]
function Queue:pop<T>(): T?
    if self:isEmpty() then
        return nil
    end
    
    local item = self._items[self._first]
    self._items[self._first] = nil
    self._first += 1
    
    -- Reset indices if queue is empty
    if self._first > self._last then
        self._first = 0
        self._last = -1
    end
    
    return item
end

--[=[
    @return T? -- The first item in the queue without removing it, or nil if empty
    Returns the first item in the queue without removing it
]=]
function Queue:peek<T>(): T?
    if self:isEmpty() then
        return nil
    end
    return self._items[self._first]
end

--[=[
    Removes all items from the queue
]=]
function Queue:clear()
    self._items = {}
    self._first = 0
    self._last = -1
end

--[=[
    @return number -- The number of items in the queue
    Returns the current size of the queue
]=]
function Queue:size(): number
    return self._last - self._first + 1
end

--[=[
    @return boolean -- Whether the queue is empty
    Returns true if the queue is empty, false otherwise
]=]
function Queue:isEmpty(): boolean
    return self._first > self._last
end

--[=[
    @return {T} -- Array containing all items in queue order
    Returns an array containing all items in the queue
]=]
function Queue:toArray<T>(): {T}
    local array = table.create(self:size())
    local index = 1
    
    for i = self._first, self._last do
        array[index] = self._items[i]
        index += 1
    end
    
    return array
end

--[=[
    @return () -> T? -- Iterator function
    Returns an iterator function for the queue
    
    @example
    ```lua
    for item in queue:iterate() do
        print(item)
    end
    ```
]=]
function Queue:iterate<T>(): () -> T?
    local i = self._first - 1
    return function()
        i += 1
        if i <= self._last then
            return self._items[i]
        end
        return nil
    end
end

return Queue
