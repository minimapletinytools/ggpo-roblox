local GGPORoblox = require(game.ReplicatedStorage.Shared.ggporoblox)
local GGPO = require(game.ReplicatedStorage.Shared.ggpo)

local gameConfig = GGPO.defaultGameConfig

-- TODO maybe pull out MockGameState?
--[[
local callbacks = {
    SaveGameState = function(frame) 
        assert(frame == stateref.frame, string.format("expected frame %d, got %d", frame, stateref.frame))
        return stateref.state
    end,
    LoadGameState = function(state, frame) 
        print("loading state " .. tostring(state) .. " frame " .. tostring(frame))
        stateref.state = state
        stateref.frame = frame
    end,
    AdvanceFrame = function()
        -- NOTE that inputs from frame n get added to the state for frame n+1
        --print(string.format("advancing frame %d for player %d", stateref.frame, i))
        stateref.state = stateref.state .. tostring(stateref.frame) .. ":\n"
        local pinputs = GGPO.GGPO_Peer_SynchronizeInput(ggporef, stateref.frame)
        for _,p in ipairs(playersIndices) do
            --assert(pinputs[p] ~= nil or stateref.frame == 0, string.format("expected input for player %d after frame 0", p))
            if pinputs[p] ~= nil then
                -- TODO also note pinputs[p].input could be nil, you need to handle that
                stateref.state = stateref.state .. "  " .. tostring(p) .. ":" .. pinputs[p].input .. "\n"
            end
        end
        stateref.state = stateref.state .. "\n"
        stateref.frame += 1
        GGPO.GGPO_Peer_AdvanceFrame(ggporef, stateref.frame)
    end,
    OnPeerEvent = function(event, player) end,
    OnSpectatorEvent = function(event, spectator) end,
}  
]]--

local config = {
    gameConfig = gameConfig,
    callbacks = nil
}
local ggporoblox = GGPORoblox.GGPORobloxPlayer_new(config)