local GGPO = require(script.Parent.Parent.ggpo)


-- simple deep copy, does not handle metatables or recursive tables!!
function deep_copy_simple(obj)
    if type(obj) ~= 'table' then return obj end
    local res = {}
    for k, v in pairs(obj) do res[deep_copy_simple(k)] = deep_copy_simple(v) end
    return res
end

function deep_copy(obj : any, seen : ({ [any]: {} })?)
    -- Handle non-tables and previously-seen tables.
    if type(obj) ~= 'table' then return obj end
    if seen and seen[obj] then return seen[obj] end
  
    -- New table; mark it as seen and copy recursively.
    local s = seen or ({} :: { [any]: {} })
    local res = {}
    s[obj] = res
    for k, v in pairs(obj) do res[deep_copy(k, s)] = deep_copy(v, s) end
    return setmetatable(res, getmetatable(obj))
end


export type MockUDPEndpointStuff<I> = {
    --configuration
    delayMin : number,
    delayMax : number,
    dropRate : number,

    -- actual data
    -- key is when to send in epochMs
    msgQueue : { [number] : {GGPO.UDPMsg<I>} },
    subscriber : ((GGPO.UDPMsg<I>) -> ())?,

    -- for debuggng, may not always be set
    sender : GGPO.PlayerHandle,
    receiver : GGPO.PlayerHandle,
}

function tprint(s : string) 
    print(s)
    --print(debug.traceback())
end

function MockUDPEndointStuff_new<I>() : MockUDPEndpointStuff<I>
    local r = {
        delayMin = 1,
        delayMax = 2,
        dropRate = 0,
        msgQueue = {},
        subscriber = nil,
        sender = GGPO.nullHandle,
        receiver = GGPO.nullHandle,
    }
    return r
end


export type MockUDPEndpointManager<I> = {
    -- TODO maybe don't manage this here because yo ucan't get the player mappings, combine with MockGame
    endpoints : {[number] : GGPO.UDPEndpoint<I> },
    time : number,
}

function MockUDPEndpointManager_new<I>() : MockUDPEndpointManager<I>
    local r = {
        endpoints = {},
        time = -1,
    }
    return r
end

function MockUDPEndpointManager_SetTime<I>(manager : MockUDPEndpointManager<I>, time_ : number?)
    local time = time_ or GGPO.now()

    if manager.time > time then
        error("mock time must be monotonic")
    end
    manager.time = time
end

function MockUDPEndpointManager_PollUDP<I>(manager : MockUDPEndpointManager<I>)
    --print("going through endpoints " .. tostring(#manager.endpoints))
    for _, stuff in pairs(manager.endpoints) do
        --print("endpoint " .. tostring(endpoint) .. " stuff " .. tostring(stuff))
        for t, msgs in stuff.msgQueue do
            if t <= manager.time then
                assert(stuff.subscriber ~= nil, "expected subscriber")
                if stuff.subscriber ~= nil then
                    for _, msg in pairs(msgs) do
                        stuff.subscriber(msg, stuff.sender)
                    end
                end
                stuff.msgQueue[t] = nil
            end
        end
    end
end

-- TODO just replace with table.insert
function array_append<T>(t : {[number] : T}, value : T)
    table.insert(t, value)
end



local function makeSendFn<I>(manager : MockUDPEndpointManager<I>, endpointStuff : MockUDPEndpointStuff<I>) : (GGPO.UDPMsg<I>) -> ()
    return function(msg : GGPO.UDPMsg<I>)
        local delay = endpointStuff.delayMin + math.random() * (endpointStuff.delayMax - endpointStuff.delayMin)
        local epochMs = manager.time + math.floor(delay)
        if endpointStuff.msgQueue[epochMs] == nil then
            endpointStuff.msgQueue[epochMs] = {}
        end
        array_append(endpointStuff.msgQueue[epochMs], deep_copy_simple(msg))
    end
end

-- creates a pair of endpoints that are connected to each other and adds them to the manager
local function MockUDPEndpointManager_AddPairedUDPEndpoints<I>(manager : MockUDPEndpointManager<I>) : { A: GGPO.UDPEndpoint<I>, B: GGPO.UDPEndpoint<I> }

    local endpointStuffA = MockUDPEndointStuff_new()
    local endpointStuffB = MockUDPEndointStuff_new()
    local rA = {
        send = makeSendFn(manager, endpointStuffA),
        subscribe = function(f) 
            -- subscribe to send events in rB
            endpointStuffB.subscriber = f
        end,
        stuff = endpointStuffA,
    }
    
    local rB = {
        send = makeSendFn(manager, endpointStuffB),
        subscribe = function(f) 
            -- subscribe to send events in rA
            endpointStuffA.subscriber = f
        end,
        stuff = endpointStuffB,
    }

    array_append(manager.endpoints, endpointStuffA)
    array_append(manager.endpoints, endpointStuffB)
    return {A = rA, B = rB}
end




export type MockGameState = {
    frame : Frame,
    state : string,
}

function MockGameState_new() : MockGameState
    local r = {
        frame = GGPO.frameInit,
        state = "\n",
    }
    return r
end

-- a mock game, input is just a string with letters only! 
export type MockGame = {
    manager : MockUDPEndpointManager<string>,
    players : { [GGPO.PlayerHandle] : {ggpo : GGPO.GGPO_Peer<string, string, {}>, state : MockGameState, endpoints : {[number] : MockUDPEndpointStuff<string>} } },
    -- TODO
    --spectators : { [number] : {ggpo : GGPO_Spectator<string, string, ()>, state : MockGameState, endpoints : {[number] : MockUDPEndpointManager<string>} } },
}

function MockGame_new(numPlayers : number, isCars : boolean) : MockGame

    local config = GGPO.defaultGameConfig
    local manager = MockUDPEndpointManager_new()
    local players = {}
    local playersIndices = {}
    for i = 1, numPlayers, 1 do
        playersIndices[i] = i
    end
    if isCars then
        playersIndices[GGPO.carsHandle] = GGPO.carsHandle
    end

    for i,_ in pairs(playersIndices) do
        local ggporef = nil
        local stateref = MockGameState_new()
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
        ggporef = GGPO.GGPO_Peer_new(config, callbacks, i)
        players[i] = {
            ggpo = ggporef,
            state = stateref,
            endpoints = {}
        }
    end




    if isCars then
        -- create CARS network
        assert(players[GGPO.carsHandle] ~= nil)
        for i = 1, numPlayers, 1 do
            local pairedeps = MockUDPEndpointManager_AddPairedUDPEndpoints(manager)
            pairedeps.A.stuff.sender = GGPO.carsHandle
            pairedeps.A.stuff.receiver = i
            array_append(players[GGPO.carsHandle].endpoints, pairedeps.A)
            GGPO.GGPO_Peer_AddPeer(players[GGPO.carsHandle].ggpo, i, pairedeps.A)
            pairedeps.B.stuff.sender = i
            pairedeps.B.stuff.receiver = GGPO.carsHandle
            array_append(players[i].endpoints, pairedeps.B)
            GGPO.GGPO_Peer_AddPeer(players[i].ggpo, GGPO.carsHandle, pairedeps.B)
        end
    else
        -- create P2P network
        for i = 1, numPlayers, 1 do
            for j = i+1, numPlayers, 1 do
                print("CONNECTING PLAYERS " .. tostring(i) .. " AND " .. tostring(j))
                local pairedeps = MockUDPEndpointManager_AddPairedUDPEndpoints(manager)
                pairedeps.A.stuff.sender = i
                pairedeps.A.stuff.receiver = j
                array_append(players[i].endpoints, pairedeps.A)
                GGPO.GGPO_Peer_AddPeer(players[i].ggpo, j, pairedeps.A)
                pairedeps.B.stuff.sender = j
                pairedeps.B.stuff.receiver = i
                array_append(players[j].endpoints, pairedeps.B)
                GGPO.GGPO_Peer_AddPeer(players[j].ggpo, i, pairedeps.B)
            end
        end
    end

    local r = {
        manager = manager,
        players = players,    
        --spectators = {},
    }
    return r
end

-- update the game for totalMs at random intervals between min and max ms
function MockGame_Poll(mockGame : MockGame, totalMs : number, min : number, max : number)
    local acc = 0
    while acc < totalMs do
        local delay = min + math.random() * (max - min)
        acc = math.floor(acc + delay)
        if acc > totalMs then
            acc = totalMs
        end 
        -- TODO allow per player random updating...
        MockUDPEndpointManager_SetTime(mockGame.manager, mockGame.manager.time + acc)
        MockUDPEndpointManager_PollUDP(mockGame.manager)
    end

    -- NOTE that the time inside ggpo will not match the mocked time above
    for i, player in pairs(mockGame.players) do
        GGPO.GGPO_Peer_DoPoll(player.ggpo)
    end
end

function MockGame_PressRandomButtons(mockGame : MockGame, player : GGPO.PlayerHandle)
    local randomlowercase = function()
        return string.char(math.random(65, 65 + 25)):lower()
    end
    local inputs = ""
    for i = 1, math.random(0,7), 1 do
        inputs = inputs .. randomlowercase()
    end
    local ggpoinput = GGPO.GameInput_new(mockGame.players[player].state.frame, inputs)
    GGPO.GGPO_Peer_AddLocalInput(mockGame.players[player].ggpo, ggpoinput)
end

function MockGame_AdvanceFrame(mockGame : MockGame, player : GGPO.PlayerHandle)
    mockGame.players[player].ggpo.callbacks.AdvanceFrame()
end

function MockGame_AdvanceCars(mockGame : MockGame)
    local cars = mockGame.players[GGPO.carsHandle]
    local ggpoinput = GGPO.GameInput_new(cars.state.frame, nil)
    GGPO.GGPO_Peer_AddLocalInput(cars.ggpo, ggpoinput)
    mockGame.players[GGPO.carsHandle].ggpo.callbacks.AdvanceFrame()
end

function MockGame_IsStateSynchronized(mockGame : MockGame) : boolean
    
    local last_confirmed_frame = GGPO.frameMax
    for i, player in pairs(mockGame.players) do
        --print("MockGame_IsStateSynchronized: last confirmed frame for player " .. tostring(i) .. " is " .. tostring(player.ggpo.sync.last_confirmed_frame))
        last_confirmed_frame = math.min(last_confirmed_frame, player.ggpo.sync.last_confirmed_frame)
    end

    print("MockGame_IsStateSynchronized: last confirmed frame: " .. tostring(last_confirmed_frame))

    local playerStates = {}
    for i, player in pairs(mockGame.players) do
        playerStates[i] = player.ggpo.sync.savedstate[last_confirmed_frame]

        print("MockGame_IsStateSynchronized: saved state for player: " .. tostring(i) .. " state: " .. tostring(playerStates[i].state))
    end

    -- TODO this can be better lol
    for player, state in pairs(playerStates) do
        for otherPlayer, otherState in pairs(playerStates) do
            if state.state ~= otherState.state then
                print("MockGame_IsStateSynchronized: player " .. tostring(player) .. " state " .. tostring(state.state) .. " != player " .. tostring(otherPlayer) .. " state " .. tostring(otherState.state))
                return false
            end
        end
    end

    return true
end



local disableTestSpam = true

return function()
    if disableTestSpam then
        return
    end
    describe("table helpers", function()
        it("isempty", function()
            expect(GGPO.isempty({})).to.equal(true)
            expect(GGPO.isempty({1})).to.equal(false)
            expect(GGPO.isempty({1,2})).to.equal(false)
        end)
        it("tablecount", function()
            expect(GGPO.tablecount({})).to.equal(0)
            expect(GGPO.tablecount({1})).to.equal(1)
            expect(GGPO.tablecount({1,2})).to.equal(2)
        end)
    end)
    describe("FrameMap", function()
        it("FrameMap_firstFrame/lastFrame", function()
            local msg = {}
            expect(GGPO.FrameMap_lastFrame(msg)).to.equal(GGPO.frameNull)
            expect(GGPO.FrameMap_firstFrame(msg)).to.equal(GGPO.frameNull)
            msg[1] = GGPO.GameInput_new(1, "a")
            expect(GGPO.FrameMap_lastFrame(msg)).to.equal(1)
            expect(GGPO.FrameMap_firstFrame(msg)).to.equal(1)
            msg[2] = GGPO.GameInput_new(2, "b")
            expect(GGPO.FrameMap_lastFrame(msg)).to.equal(2)
            expect(GGPO.FrameMap_firstFrame(msg)).to.equal(1)
            msg[0] = GGPO.GameInput_new(0, "c")
            expect(GGPO.FrameMap_lastFrame(msg)).to.equal(2)
            expect(GGPO.FrameMap_firstFrame(msg)).to.equal(0)
        end)
    end)

    describe("UDPProto", function()
        it("UDPProto_ClearInputsBefore", function()
            local udpproto = GGPO.UDPProto_new(2, 1, GGPO.uselessUDPEndpoint)
            udpproto.playerData[1] = GGPO.UDPProto_Player_new()
            udpproto.playerData[1].pending_output[0] = GGPO.GameInput_new(0, "a")
            udpproto.playerData[1].pending_output[1] = GGPO.GameInput_new(1, "b")
            udpproto.playerData[1].pending_output[2] = GGPO.GameInput_new(2, "c")
            udpproto.playerData[1].pending_output[3] = GGPO.GameInput_new(3, "meow")
            GGPO.UDPProto_ClearInputsBefore(udpproto, 0)
            expect(GGPO.tablecount(udpproto.playerData[1].pending_output)).to.equal(3)
            expect(udpproto.playerData[1].pending_output[0]).to.equal(nil)
            GGPO.UDPProto_ClearInputsBefore(udpproto, 0)
            expect(GGPO.tablecount(udpproto.playerData[1].pending_output)).to.equal(3)
            GGPO.UDPProto_ClearInputsBefore(udpproto, 2)
            expect(GGPO.tablecount(udpproto.playerData[1].pending_output)).to.equal(1)
            GGPO.UDPProto_ClearInputsBefore(udpproto, 3)
            expect(GGPO.isempty(udpproto.playerData[1].pending_output))
        end)
    end)

    describe("MockGame", function()
        it("n player p2p basic", function()
            local numPlayers = 4
            local game = MockGame_new(numPlayers, false)
            local nframes = 15
            for n = 1, nframes, 1 do
                
                print("SENDING RANDOM INPUTS ON FRAME " .. tostring(n))
                for p = 1, numPlayers, 1 do
                    MockGame_PressRandomButtons(game, p)
                end

                print("ADVANCING FROM FRAME " .. tostring(n))
                for p = 1, numPlayers, 1 do
                    MockGame_AdvanceFrame(game, p)
                end
                
                print("BEGIN FRAME " .. tostring(n+1))

                print("POLLING FOR FRAME " .. tostring(n+1))
                MockGame_Poll(game, 100, 10, 20)
                
                -- NOTE that we should have polled long enough to guarantee states to be synchronized here
                print("CHECKING FOR SYNCHRONIZATION")
                expect(MockGame_IsStateSynchronized(game)).to.equal(true)
            end
        end)

        it("n player p2p rift", function()
            local numPlayers = 4
            print("initializing mock p2p game with 2 players)")
            local game = MockGame_new(numPlayers, false)
            local nframes = 5
            for p = 1, numPlayers, 1 do
                for n = 1, nframes, 1 do
                    MockGame_PressRandomButtons(game, p)
                    MockGame_AdvanceFrame(game, p)
                    MockGame_Poll(game, 100, 10, 20)
                end
            end
            expect(MockGame_IsStateSynchronized(game)).to.equal(true)
        end)


        it("n player CARS basic", function()
            local numPlayers = 4
            print("initializing mock CARS game with 2 players)")
            local game = MockGame_new(numPlayers, true)
            local nframes = 15
            for n = 1, 15, 1 do
                

                --print("SENDING RANDOM INPUTS ON FRAME " .. tostring(n))
                for p = 1, numPlayers, 1 do
                    MockGame_PressRandomButtons(game, p)
                end

                --print("ADVANCING FROM FRAME " .. tostring(n))
                for p = 1, numPlayers, 1 do
                    MockGame_AdvanceFrame(game, p)
                end

                --print("ADVANCE CARS")
                MockGame_AdvanceCars(game)
                
                --print("BEGIN FRAME " .. tostring(n+1))

                --print("POLLING FOR FRAME " .. tostring(n+1))
                -- triple poll needed due to CARS requiring 2 hops for inputs to propogate and then one more for input ack
                MockGame_Poll(game, 100, 10, 20)
                MockGame_Poll(game, 100, 10, 20)
                MockGame_Poll(game, 100, 10, 20)
                
                -- NOTE that we should have polled long enough to guarantee states to be synchronized here
                print("CHECKING FOR SYNCHRONIZATION")
                expect(MockGame_IsStateSynchronized(game)).to.equal(true)
            end

        end)

    end)
end