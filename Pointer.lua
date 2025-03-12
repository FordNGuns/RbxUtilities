-- -----------------------------------------------------------------------------
--               C++ Style Pointer Implementation for Lua                     --
-- This is a Pointer class which simulates C++-like pointer behavior in Lua   --
-- allowing for reference-based operations and memory management simulation.  --
-- The implementation provides safe pointer dereferencing, null checking,     --
-- and simulated memory addresses while maintaining Lua's simplicity.         --
-- This allows for C++-style pointer patterns while protecting against common --
-- pointer-related issues like null pointer dereferencing.                    --
--                                                                            --
-- License:                                                                   --
--   Licensed under the MIT license.                                          --
--                                                                            --
-- Authors:                                                                   --
--   FordNGuns - March 11th 2025 - Created the file.                          --
-- -----------------------------------------------------------------------------

-- Example usage:
--[[
    local ptr = Pointer.new(42)
    print(ptr:deref()) -- 42
    print(ptr:address()) -- simulated memory address
    
    local nullPtr = Pointer.null()
    print(nullPtr:isNull()) -- true
    
    local ref = ptr:reference()
    ref:set(100)
    print(ptr:deref()) -- still 42 (independent reference)
    
    -- Error handling
    pcall(function()
        nullPtr:deref() -- will throw error
    end)
]]

local Pointer = {}
Pointer.__index = Pointer

--[=[
    @desc: Creates a new pointer to a value
    @param: value - The initial value to point to
    @return: Pointer - A new pointer instance
]=]
function Pointer.new(value)
    local self = setmetatable({
        _value = value,
        _address = tostring({}):match("table: (.+)"), -- Simulate memory address
        _isNull = value == nil
    }, Pointer)
    return self
end

--[=[
    @desc: Creates a null pointer
    @return: Pointer - A new null pointer instance
]=]
function Pointer.null()
    local ptr = Pointer.new(nil)
    ptr._isNull = true
    return ptr
end

--[=[
    @desc: Dereferences the pointer to get the value
    @return: any - The value being pointed to
    @throws: Error if pointer is null
]=]
function Pointer:deref()
    if self._isNull then
        error("Attempt to dereference null pointer", 2)
    end
    return self._value
end

--[=[
    @desc: Gets the memory address (simulated) of the pointer
    @return: string - The simulated memory address
]=]
function Pointer:address()
    return self._address
end

--[=[
    @desc: Checks if the pointer is null
    @return: boolean - True if pointer is null, false otherwise
]=]
function Pointer:isNull()
    return self._isNull
end

--[=[
    @desc: Sets the value the pointer points to
    @param: value - The new value to point to
]=]
function Pointer:set(value)
    self._value = value
    self._isNull = value == nil
end

--[=[
    @desc: Creates a new pointer pointing to the same value (like reference in C++)
    @return: Pointer - A new pointer to the same value
]=]
function Pointer:reference()
    return Pointer.new(self._value)
end

--[=[
    @desc: Compares two pointers for equality
    @param: other - Another pointer to compare with
    @return: boolean - True if both pointers point to the same value
]=]
function Pointer:equals(other)
    if not other or getmetatable(other) ~= Pointer then
        return false
    end
    return self._value == other._value
end

-- Metamethods for operator overloading
function Pointer:__eq(other)
    return self:equals(other)
end

function Pointer:__tostring()
    if self._isNull then
        return "nullptr"
    end
    return string.format("Pointer(addr: %s, value: %s)", self._address, tostring(self._value))
end

return Pointer
