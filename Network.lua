-- -----------------------------------------------------------------------------
--                        Network Implementation for Luau                      --
-- A robust networking module for Roblox games that handles RemoteEvents      --
-- and RemoteFunctions automatically. Provides a clean API for client-server  --
-- communication with type checking, error handling, and Promise support.     --
--                                                                            --
-- License:                                                                   --
--   Licensed under the MIT license.                                          --
--                                                                            --
-- Authors:                                                                   --
--   FordNGuns - March 11th 2025 - Created the file                           --
-- -----------------------------------------------------------------------------

--!strict
--[=[
    @class Network
    Network module that handles RemoteEvents and RemoteFunctions automatically.
    Provides a clean API for client-server communication with type checking.
    
    @server
    ```lua
    local Network = require("Network")
    
    -- Create a remote event
    Network.createEvent("PlayerDied")
    Network:fire("PlayerDied", player, reason)
    
    -- Create a remote function
    Network.createFunction("GetPlayerData")
    Network:setCallback("GetPlayerData", function(player)
        return {coins = 100}
    end)
    ```
    
    @client
    ```lua
    local Network = require("Network")
    
    -- Listen to events
    Network:on("PlayerDied", function(player, reason)
        print(player.Name, "died because of", reason)
    end)
    
    -- Call remote functions (returns Promise)
    Network:invoke("GetPlayerData"):andThen(function(data)
        print("Player has", data.coins, "coins")
    end)
    ```
]=]

local RunService = game:GetService("RunService")
local Promise = require("Promise")

local IS_SERVER = RunService:IsServer()
local IS_CLIENT = RunService:IsClient()

local Network = {}
Network.__index = Network

-- Constants
local FOLDER_NAME = "NetworkRemotes"
local EVENT_PREFIX = "Event_"
local FUNCTION_PREFIX = "Function_"

-- Private variables
local remoteFolder
local events = {}
local functions = {}
local callbacks = {}

--[=[
    @private
    @param name string
    @return string
    Sanitizes remote names to prevent injection and ensure valid names
]=]
local function sanitizeName(name: string): string
    return name:gsub("[^%w_]", "")
end

--[=[
    @private
    Initializes the remote folder and sets up existing remotes if any
]=]
local function init()
    if IS_SERVER then
        remoteFolder = Instance.new("Folder")
        remoteFolder.Name = FOLDER_NAME
        remoteFolder.Parent = game:GetService("ReplicatedStorage")
    else
        remoteFolder = game:GetService("ReplicatedStorage"):WaitForChild(FOLDER_NAME)
    end
end

--[=[
    @server
    @param name string -- Name of the RemoteEvent
    Creates a new RemoteEvent with the given name
]=]
function Network.createEvent(name: string)
    assert(IS_SERVER, "RemoteEvents can only be created on the server")
    name = sanitizeName(name)
    
    if events[name] then
        warn(string.format("RemoteEvent '%s' already exists", name))
        return
    end
    
    local event = Instance.new("RemoteEvent")
    event.Name = EVENT_PREFIX .. name
    event.Parent = remoteFolder
    events[name] = event
end

--[=[
    @server
    @param name string -- Name of the RemoteFunction
    Creates a new RemoteFunction with the given name
]=]
function Network.createFunction(name: string)
    assert(IS_SERVER, "RemoteFunctions can only be created on the server")
    name = sanitizeName(name)
    
    if functions[name] then
        warn(string.format("RemoteFunction '%s' already exists", name))
        return
    end
    
    local func = Instance.new("RemoteFunction")
    func.Name = FUNCTION_PREFIX .. name
    func.Parent = remoteFolder
    functions[name] = func
end

--[=[
    @param name string -- Name of the RemoteEvent
    @param ... any -- Arguments to fire
    Fires the RemoteEvent to all clients (if called from server) or to the server (if called from client)
]=]
function Network:fire(name: string, ...: any)
    name = sanitizeName(name)
    local event = if IS_SERVER then events[name] else remoteFolder:FindFirstChild(EVENT_PREFIX .. name)
    
    assert(event, string.format("RemoteEvent '%s' does not exist", name))
    if IS_SERVER then
        event:FireAllClients(...)
    else
        event:FireServer(...)
    end
end

--[=[
    @param name string -- Name of the RemoteEvent
    @param player Player -- Player to fire to
    @param ... any -- Arguments to fire
    Fires the RemoteEvent to a specific player (server-only)
]=]
function Network:firePlayer(player: Player, name: string, ...: any)
    assert(IS_SERVER, "firePlayer can only be called on the server")
    name = sanitizeName(name)
    local event = events[name]
    
    assert(event, string.format("RemoteEvent '%s' does not exist", name))
    event:FireClient(player, ...)
end

--[=[
    @param name string -- Name of the RemoteEvent
    @param callback function -- Function to call when event is fired
    @return function -- Disconnect function
    Listens for the RemoteEvent
]=]
function Network:on(name: string, callback: (...any) -> ()): () -> ()
    name = sanitizeName(name)
    local event = if IS_SERVER then events[name] else remoteFolder:FindFirstChild(EVENT_PREFIX .. name)
    
    assert(event, string.format("RemoteEvent '%s' does not exist", name))
    local connection = if IS_SERVER 
        then event.OnServerEvent:Connect(callback)
        else event.OnClientEvent:Connect(callback)
    
    return function()
        connection:Disconnect()
    end
end

--[=[
    @param name string -- Name of the RemoteFunction
    @param callback function -- Function to call when function is invoked
    Sets the callback for a RemoteFunction (server-only)
]=]
function Network:setCallback(name: string, callback: (...any) -> ...any)
    assert(IS_SERVER, "setCallback can only be called on the server")
    name = sanitizeName(name)
    local func = functions[name]
    
    assert(func, string.format("RemoteFunction '%s' does not exist", name))
    callbacks[name] = callback
    func.OnServerInvoke = callback
end

--[=[
    @param name string -- Name of the RemoteFunction
    @param ... any -- Arguments to pass to the function
    @return Promise -- Promise that resolves with the function result
    Invokes the RemoteFunction (client-only)
]=]
function Network:invoke(name: string, ...: any): any
    assert(IS_CLIENT, "invoke can only be called on the client")
    name = sanitizeName(name)
    local func = remoteFolder:FindFirstChild(FUNCTION_PREFIX .. name)
    
    assert(func, string.format("RemoteFunction '%s' does not exist", name))
    return Promise.new(function(resolve, reject)
        local success, result = pcall(func.InvokeServer, func, ...)
        if success then
            resolve(result)
        else
            reject(result)
        end
    end)
end

-- Initialize the module
init()

return Network
