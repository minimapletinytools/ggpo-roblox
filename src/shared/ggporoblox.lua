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
  -- uses UserId as PlayerHandle for Players
  peer : GGPO.GGPO_Peer,
}

local GGPOROBLOX_POLL_INTERVAL = 0.01 -- seconds

local function GGPORobloxCommon_Run(ggporoblox : GGPORobloxCommon)
  while true do
    GGPO.GGPO_Peer_DoPoll(ggporoblox.peer)
    wait(GGPOROBLOX_POLL_INTERVAL)
  end
end

local function GGPORobloxCommon_AddLocalInput(ggporoblox : GGPORobloxCommon)

  -- TODO
  local inputs = {}

  local ggpoinput = GGPO.GameInput_new(ggporoblox.peer.sync.framecount, inputs)
  GGPO.GGPO_Peer_AddLocalInput(ggporoblox.peer, ggpoinput)
end

export type GGPORobloxRCC_ = {
  playerMapping : Bimap.Bimap<GGPO.PlayerHandle, Player>,
  
}


export type GGPORobloxRCC = GGPORobloxRCC_ & GGPORobloxEvents & GGPORobloxCommon


local function isMessageInput(message : any) : boolean
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

  local ggporoblox = {} :: GGPORobloxRCC

  -- initialize the required Instances
  local root = Instance.new("Folder", game.Workspace)
  root.Name = "ggpo-roblox"
  local reliableRemoteEvent = Instance.new("RemoteEvent", root)
  local unreliableRemoteEvent = Instance.new("UnreliableRemoteEvent", root)
  ggporoblox.reliableRemoteEvent = reliableRemoteEvent
  ggporoblox.unreliableRemoteEvent = unreliableRemoteEvent

  reliableRemoteEvent.OnServerEvent:Connect(function(player : Player, ... : any)
    print("Received reliable event from player " .. tostring(player.UserId))
    local args = {...}
    if args[1] == nil or not isGGPORobloxServerToClientReliableEvents(args[1]) then
      error("Received reliable event with no event type")
    end
    local eventType : GGPORobloxClientToServerReliableEvents = args[1]
    processServerToClientReliableEvent(ggporoblox, player, eventType, table.unpack(args, 1))
  end)
  
  ggporoblox.playerMapping = Bimap.new()
  ggporoblox.state = "Initializing" :: GGPORobloxState

  ggporoblox.peer = GGPO.GGPO_Peer_new(config.gameConfig, config.callbacks, GGPO.carsHandle)


  return ggporoblox
end


-- initialize the agme 
local function GGPORobloxRCC_initializeGameAndBeginSynchronization(ggporoblox : GGPORobloxRCC, players :  {[GGPO.PlayerHandle] : Player}, timeout : number)
  
  ggporoblox.playerMapping:insertMany(players)

  ggporoblox.state = "Synchronizing" :: GGPORobloxState

end



local function GGPORobloxRCC_addAllPlayers(ggporoblox : GGPORobloxRCC)
  -- TODO better way to filter for what players to add
  -- add all players
  local Players = game:GetService("Players") -- you should use GetService over game.Players!
  for _, player in pairs(Players:GetPlayers()) do
      local endpoint = {
        send = function(msg : GGPO.UDPMsg<I>)
          ggporoblox.unreliableRemoteEvent:FireClient(player, msg)
        end,
        subscribe = function(callback : (GGPO.UDPMsg<I>, player: GGPO.PlayerHandle)->())
          ggporoblox.unreliableRemoteEvent.OnServerEvent:Connect(function(player : Player, ...)
            print("Received unreliable event from player " .. tostring(player.UserId))
        
            local args = {...}
      
            -- TODO pass input to ggpo
          end)    
        end
      }
      GGPO.GGPO_Peer_AddPeer(ggporoblox.peer, player.UserId, endpoint)
  end

end

local function GGPORobloxRCC_startGame(ggporoblox : GGPORobloxRCC)

  GGPORobloxRCC_addAllPlayers(ggporoblox)

  -- TODO start the game

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

local function GGPORobloxPlayer_new<T,I>(config: GGPORobloxConfig<T,I>) : GGPORobloxPlayer

  local ggporoblox = {} :: GGPORobloxPlayer

  -- grab the required Instances (they were created by the server)
  local reliableRemoteEvent = game.Workspace:WaitForChild("ggpo-roblox"):WaitForChild("RemoteEvent")
  local unreliableRemoteEvent = game.Workspace:WaitForChild("ggpo-roblox"):WaitForChild("UnreliableRemoteEvent")
  assert(unreliableRemoteEvent, "UnreliableRemoteEvent not found, this probably means you forgot to initialize the ggpo CARS server or you're having serious connection issues")
  ggporoblox.reliableRemoteEvent = reliableRemoteEvent
  ggporoblox.unreliableRemoteEvent = unreliableRemoteEvent

  

  reliableRemoteEvent.OnClientEvent:Connect(function(...)
    print("Received reliable event from server")
    local args = {...}
    if args[1] == nil or not isGGPORobloxServerToClientReliableEvents(args[1]) then
      error("Received reliable event with no event type")
    end
    local eventType : GGPORobloxServerToClientReliableEvents = args[1]
    processServerToClientReliableEvent(ggporoblox, eventType, table.unpack(args, 1))
  end)

  local Players = game:GetService("Players") -- you should use GetService over game.Players!
  ggporoblox.owner = Players.LocalPlayer.UserId
  ggporoblox.state = "Initializing"  :: GGPORobloxState

  ggporoblox.peer = GGPO.GGPO_Peer_new(config.gameConfig, config.callbacks, GGPO.carsHandle)


  local endpoint = {
    send = function(msg : GGPO.UDPMsg<I>)
      ggporoblox.unreliableRemoteEvent:FireServer(msg)
    end,
    subscribe = function(callback : (GGPO.UDPMsg<I>, player: GGPO.PlayerHandle)->())
      unreliableRemoteEvent.OnClientEvent:Connect(function(...)
        print("Received unreliable event from server")
    
        local args = {...}
    
        -- TODO pass input to ggpo
      end)    
    end
  }
  GGPO.GGPO_Peer_AddPeer(ggporoblox.peer, GGPO.carsHandle, endpoint)
  return ggporoblox
end



return {
  GGPORobloxRCC_new = GGPORobloxRCC_new,
  GGPORobloxPlayer_new = GGPORobloxPlayer_new,
}
