local ggporoblox = require(game.ReplicatedStorage.Shared.ggporoblox)
local GGPO = require(game.ReplicatedStorage.Shared.ggpo)


local myPlayer = 100

return function()
    describe("ggporoblox_rcc", function()
        it("basic", function()
          local callbacks = {
            SaveGameState = function(frame) 
              return nil
            end,
            LoadGameState = function(state, frame) 
            end,
            AdvanceFrame = function()
            end,
            OnPeerEvent = function(event, player) end,
            OnSpectatorEvent = function(event, spectator) end,
          }  
          local config = {
            gameConfig = GGPO.defaultGameConfig,
            callbacks = callbacks

          }
          local player = ggporoblox.GGPORobloxPlayer_new(config, myPlayer)
        end)
    end)
end