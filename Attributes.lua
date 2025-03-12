-- -----------------------------------------------------------------------------
--               C# Style Attributes Implementation for Lua                   --
-- This is an Attributes system which simulates C#-like attributes in Lua,    --
-- allowing for function decoration and metadata. The implementation provides  --
-- a way to add metadata, validation, and behavior modification to functions  --
-- similar to C#'s attribute system. Common attributes like Obsolete,         --
-- Conditional, and Range are included as examples.                           --
--                                                                            --
-- License:                                                                   --
--   Licensed under the MIT license.                                          --
--                                                                            --
-- Authors:                                                                   --
--   FordNGuns - March 11th 2025 - Created the file.                         --
-- -----------------------------------------------------------------------------

-- Example usage:
--[[
    local function MyFunction(x, y)
        return x + y
    end

    -- Apply multiple attributes
    MyFunction = Attributes.Range({min = 0, max = 100})
        .Obsolete("Use NewFunction instead")
        .Conditional("DEBUG")
        .Apply(MyFunction)

    -- The function now has validation and metadata
    MyFunction(50, 75) -- Works
    MyFunction(-1, 101) -- Throws error: "Arguments out of range"

    -- Additional Examples:
    Obsolete: Marks functions as deprecated
    MyFunction = Attributes.Obsolete("Use NewFunction instead").Apply(MyFunction)

    Range: Validates numeric arguments
    MyFunction = Attributes.Range({min = 0, max = 100}).Apply(MyFunction)

    Conditional: Only executes under specific conditions
    MyFunction = Attributes.Conditional("DEBUG").Apply(MyFunction)

    ValidateType: Enforces type checking
    MyFunction = Attributes.ValidateType({"string", "number"}).Apply(MyFunction)
]]

local Attributes = {}
Attributes.__index = Attributes

-- Store metadata for functions
local functionMetadata = setmetatable({}, {__mode = "k"}) -- Weak keys

--[=[
    @desc: Creates a new attribute chain
    @return: table - A new attribute chain instance
]=]
local function createAttributeChain()
    local chain = {
        attributes = {},
        currentAttribute = nil
    }
    
    function chain:Apply(func)
        if not functionMetadata[func] then
            functionMetadata[func] = {}
        end
        
        -- Apply all attributes in the chain
        for _, attr in ipairs(self.attributes) do
            table.insert(functionMetadata[func], attr)
        end
        
        -- Create wrapper function to handle attributes
        local wrapped = function(...)
            local args = {...}
            
            -- Pre-execution attribute checks
            for _, attr in ipairs(functionMetadata[func]) do
                if attr.preCheck then
                    local success, result = attr.preCheck(args)
                    if not success then
                        error(result, 2)
                    end
                end
            end
            
            -- Execute function
            local results = {func(...)}
            
            -- Post-execution attribute checks
            for _, attr in ipairs(functionMetadata[func]) do
                if attr.postCheck then
                    local success, result = attr.postCheck(results)
                    if not success then
                        error(result, 2)
                    end
                end
            end
            
            return unpack(results)
        end
        
        -- Copy metadata
        functionMetadata[wrapped] = functionMetadata[func]
        
        return wrapped
    end
    
    return chain
end

--[=[
    @desc: Creates an Obsolete attribute
    @param: message - Message to display when function is called
    @return: table - Attribute chain
]=]
function Attributes.Obsolete(message)
    local chain = createAttributeChain()
    table.insert(chain.attributes, {
        name = "Obsolete",
        message = message,
        preCheck = function()
            warn(string.format("Warning: This function is obsolete. %s", message or ""))
            return true
        end
    })
    return chain
end

--[=[
    @desc: Creates a Range attribute for numeric arguments
    @param: options - Table with min and max values
    @return: table - Attribute chain
]=]
function Attributes.Range(options)
    local chain = createAttributeChain()
    table.insert(chain.attributes, {
        name = "Range",
        options = options,
        preCheck = function(args)
            for _, value in ipairs(args) do
                if type(value) == "number" then
                    if value < options.min or value > options.max then
                        return false, string.format(
                            "Arguments must be between %s and %s", 
                            options.min, 
                            options.max
                        )
                    end
                end
            end
            return true
        end
    })
    return chain
end

--[=[
    @desc: Creates a Conditional attribute that only executes in specific conditions
    @param: condition - Condition name that must be true
    @return: table - Attribute chain
]=]
function Attributes.Conditional(condition)
    local chain = createAttributeChain()
    table.insert(chain.attributes, {
        name = "Conditional",
        condition = condition,
        preCheck = function()
            -- You can implement your own condition checking logic here
            local conditions = {
                DEBUG = game:GetService("RunService"):IsStudio(),
                -- Add more conditions as needed
            }
            
            if not conditions[condition] then
                return false, string.format(
                    "Condition '%s' is not met", 
                    condition
                )
            end
            return true
        end
    })
    return chain
end

--[=[
    @desc: Creates a ValidateType attribute for type checking
    @param: types - Table of expected types for each argument
    @return: table - Attribute chain
]=]
function Attributes.ValidateType(types)
    local chain = createAttributeChain()
    table.insert(chain.attributes, {
        name = "ValidateType",
        types = types,
        preCheck = function(args)
            for i, expectedType in ipairs(types) do
                if type(args[i]) ~= expectedType then
                    return false, string.format(
                        "Argument %d must be of type %s, got %s", 
                        i, 
                        expectedType, 
                        type(args[i])
                    )
                end
            end
            return true
        end
    })
    return chain
end

--[=[
    @desc: Gets all attributes applied to a function
    @param: func - Function to get attributes for
    @return: table - Table of attributes
]=]
function Attributes.GetAttributes(func)
    return functionMetadata[func] or {}
end

--[=[
    @desc: Checks if a function has a specific attribute
    @param: func - Function to check
    @param: attributeName - Name of the attribute to check for
    @return: boolean - True if function has the attribute
]=]
function Attributes.HasAttribute(func, attributeName)
    local attrs = Attributes.GetAttributes(func)
    for _, attr in ipairs(attrs) do
        if attr.name == attributeName then
            return true
        end
    end
    return false
end

return Attributes
