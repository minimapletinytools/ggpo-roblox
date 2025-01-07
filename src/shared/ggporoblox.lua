--!strict
local GGPO = require(script.Parent.ggpo)
local Bimap = require(script.Parent.util.bimap)

export type GGPORobloxConfig<T,I> = {
  gameConfig : GGPO.GameConfig<I>,
  callbacks : GGPO.GGPOCallbacks<T,I>,
}
export type GGPORobloxState = "Unkown" | "Initializing" | "Synchronizing" | "Running" |  "Disconnected" | "Disconnected"


export type GGPORobloxEvents = {
  reliableRemoteEvent : RemoteEvent,
  unreliableRemoteEvent : UnreliableRemoteEvent,
}

export type GGPORobloxServerToClientReliableEvents = "StartGame"
function isGGPORobloxServerToClientReliableEvents(value : string) : boolean
  return value == "StartGame"
end
export type GGPORobloxClientToServerReliableEvents = "Ready"
function isGGPORobloxClientToServerReliableEvents(value : string) : boolean
  return value == "Ready"
end


export type GGPORobloxCommon = {
  state : GGPORobloxState,
}

export type GGPORobloxRCC_ = {
  playerMapping : Bimap.Bimap<GGPO.PlayerHandle, Player>,
  
}


export type GGPORobloxRCC = GGPORobloxRCC_ & GGPORobloxEvents & GGPORobloxCommon


local function isMessageInput(message : any) : boolean
  -- TODO
  return type(message) == "table" and message.input ~= nil
end

local function processServerToClientReliableEvent(ggporoblox : GGPORobloxRCC, player : Player, event : GGPORobloxClientToServerReliableEvents, ...)
  if event == "Ready" then
    print("Received Ready event")
    -- TODO 
  else
    error("Unknown event " .. event)
  end
end

local function GGPORobloxRCC_new<T,I>(config: GGPORobloxConfig<T,I>) : GGPORobloxRCC

  -- initialize the required Instances
  local root = Instance.new("Folder", game.Workspace)
  root.Name = "ggpo-roblox"
  local reliableRemoteEvent = Instance.new("RemoteEvent", root)
  local unreliableRemoteEvent = Instance.new("UnreliableRemoteEvent", root)

  local ggporoblox = {} :: GGPORobloxRCC

  reliableRemoteEvent.OnServerEvent:Connect(function(player : Player, ... : any)
    print("Received reliable event from player " .. tostring(player.UserId))
    local args = {...}
    if args[1] == nil or not isGGPORobloxServerToClientReliableEvents(args[1]) then
      error("Received reliable event with no event type")
    end
    local eventType : GGPORobloxClientToServerReliableEvents = args[1]
    processServerToClientReliableEvent(ggporoblox, player, eventType, table.unpack(args, 1))
  end)
  unreliableRemoteEvent.OnServerEvent:Connect(function(player : Player, ...)
    print("Received unreliable event from player " .. tostring(player.UserId))

    if isMessageInput(...) then
      print("Received input message from player " .. tostring(player.UserId))
      -- TODO pass input to ggpo
    end
  end)

  
  ggporoblox.reliableRemoteEvent = reliableRemoteEvent
  ggporoblox.unreliableRemoteEvent = unreliableRemoteEvent
  ggporoblox.playerMapping = Bimap.new()
  ggporoblox.state = "Initializing" :: GGPORobloxState

  return ggporoblox
end


-- initialize the agme 
local function GGPORobloxRCC_initializeGameAndBeginSynchronization(ggporoblox : GGPORobloxRCC, players :  {[GGPO.PlayerHandle] : Player}, timeout : number)
  
  ggporoblox.playerMapping:insertMany(players)

  ggporoblox.state = "Synchronizing" :: GGPORobloxState

end



-- TODO add comments

local function GGPORobloxRCC_startGame(ggporoblox : GGPORobloxRCC)


  local config = GGPO.defaultGameConfig

  --TODO where do these come from
  local callbacks = {
    SaveGameState = function(frame : GGPO.Frame)
      return {}
    end,
    LoadGameState = function(data : {}, frame : GGPO.Frame)
    end,
    AdvanceFrame = function()
      -- TODO
    end,
  }

  local ggpo = GGPO.GGPO_Peer_new(config, callbacks, GGPO.carsHandle)

  
end



local function GGPORobloxRCC_addRealtimePlayer(ggporoblox : GGPORobloxRCC, player : Player)
  error("not supported yet")
end

export type GGPORobloxPlayer_ = {
  owner : GGPO.PlayerHandle,
}

export type GGPORobloxPlayer = GGPORobloxPlayer_ & GGPORobloxEvents & GGPORobloxCommon

local function processServerToClientReliableEvent(ggporoblox : GGPORobloxPlayer, event : GGPORobloxServerToClientReliableEvents, ...)
  if event == "StartGame" then
    print("Received StartGame event")
    -- TODO 
  else
    error("Unknown event " .. event)
  end
end

local function GGPORobloxPlayer_new<T,I>(config: GGPORobloxConfig<T,I>, owner : GGPO.PlayerHandle) : GGPORobloxPlayer

  -- grab the required Instances (they were created by the server)
  local reliableRemoteEvent = game.Workspace:WaitForChild("ggpo-roblox"):WaitForChild("RemoteEvent")
  local unreliableRemoteEvent = game.Workspace:WaitForChild("ggpo-roblox"):WaitForChild("UnreliableRemoteEvent")
  assert(unreliableRemoteEvent, "UnreliableRemoteEvent not found, this probably means you forgot to initialize the ggpo CARS server or you're having serious connection issues")

  local ggporoblox = {} :: GGPORobloxPlayer

  reliableRemoteEvent.OnClientEvent:Connect(function(...)
    print("Received reliable event from server")
    local args = {...}
    if args[1] == nil or not isGGPORobloxServerToClientReliableEvents(args[1]) then
      error("Received reliable event with no event type")
    end
    local eventType : GGPORobloxServerToClientReliableEvents = args[1]
    processServerToClientReliableEvent(ggporoblox, eventType, table.unpack(args, 1))
  end)
  unreliableRemoteEvent.OnClientEvent:Connect(function(...)
    print("Received unreliable event from server")

    local args = {...}

    -- TODO pass input to ggpo
  end)

  ggporoblox.reliableRemoteEvent = reliableRemoteEvent
  ggporoblox.unreliableRemoteEvent = unreliableRemoteEvent
  ggporoblox.owner = owner
  ggporoblox.state = "Initializing"  :: GGPORobloxState

  return ggporoblox
end




return {
  GGPORobloxRCC_new = GGPORobloxRCC_new,
  GGPORobloxPlayer_new = GGPORobloxPlayer_new,
}
