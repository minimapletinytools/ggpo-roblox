--!strict
local Queue = require(script.Parent.util.queue)

-- helpers
export type TimeMS = number
local function now() : TimeMS
    return DateTime.now().UnixTimestampMillis
end

local function Log(s, ...)
    return print(s:format(...))
end

local function isempty(t)
    return next(t) == nil
end

local function tablecount(t)
    local count = 0
    for _, _ in pairs(t) do
        count += 1
    end
    return count
end

-- simple deep copy, does not handle metatables or recursive tables!!
local function deep_copy_simple(obj)
    if type(obj) ~= 'table' then return obj end
    local res = {}
    for k, v in pairs(obj) do res[deep_copy_simple(k)] = deep_copy_simple(v) end
    return res
end

local function deep_copy(obj : any, seen : ({ [any]: {} })?)
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


-- debug helpers that you want to delete 
local function debug_tablekeystostring(t)
    local r = ""
    for k, _ in pairs(t) do
        r = r .. tostring(k) .. ", "
    end
    return "[" .. r .. "]"
end



-- custom logging

type PotatoFakeEnum = {
    ASSERT : number,
    Error : number,
    Warn : number,
    Info : number,
    Debug : number,
    Trace : number,


    Normal : number,
    Verbose : number
}


local Potato : PotatoFakeEnum = {
    ASSERT = -1,
    Error = 0,
    Warn = 1,
    Info = 2,
    Debug = 3,
    Trace = 4,

    Normal = 0,
    Verbose = 1,
}

export type PotatoSeverity = number
export type PotatoVerbosity = number

export type Potato = { potato : (Potato, PotatoVerbosity) -> string, potato_severity : number }

local function extractFirstLineOfTraceback(traceback : string, linecount_ : number?) : {[number]:string}
    local linecount = linecount_ or 1
    local r = {}
    -- first line just says stack
    -- second line is the indirect in __call
    local skip = 2
    local i = 0
    -- Use string.gmatch to iterate over each line in the traceback string
    for line in string.gmatch(traceback, "[^\r\n]+") do
        if skip > 0 then
            skip -= 1
        else
            r[i] = line
            i += 1
            if i >= linecount then
                break
            end
        end
    end
    return r 
end

export type PotatoContext = {
    context : Potato,
    verbosity : number,
    stackLines : number,
}

local function ctx(p : Potato, verbosity : PotatoVerbosity?, stackLines : number?) : PotatoContext
    return {
        context = p,
        verbosity = verbosity or 0,
        stackLines = stackLines or 1,
    }
end

local function potatoformat(severity : PotatoSeverity, pc : PotatoContext?, s : string, ...) : string
    local ctxstr = nil
    local stackLines = 1
    if pc ~= nil then
        ctxstr = pc.context.potato(pc.context, pc.verbosity)
        stackLines = pc.stackLines
    end
    local lines = extractFirstLineOfTraceback(debug.traceback(), stackLines)
    local msg = s:format(...)

    local finals = ""
    
    if severity == Potato.Error then
        finals = "ERROR: "
    elseif severity == Potato.Warn then
        finals = "WARN: "
    elseif severity == Potato.Info then
        finals = "INFO: "
    elseif severity == Potato.Debug then
        finals = "DEBUG: "
    elseif severity == Potato.Trace then
        finals = "TRACE: "
    end
    finals = finals .. msg .. "\n"
    if ctxstr ~= nil then
        finals = finals .. "context: " .. ctxstr .. "\n"
    end
    finals = finals .. "stack: "
    if tablecount(lines) > 1 then
        finals = finals .. "\n"
    end
    for i = 0, tablecount(lines)-1, 1 do
        finals = finals .. "    " .. lines[i] .. "\n"
    end
    return finals
end

local potatometatable = {
    __call = function(self, severity : PotatoSeverity, pc : PotatoContext?, s : string, ...)
        if pc and severity > pc.context.potato_severity then
            return
        end
        print(potatoformat(severity, pc, s, ...))
    end
}
setmetatable(Potato, potatometatable)

-- assert for game-breaking errors
local function Tomato(pc : PotatoContext?, condition : any, s_ : string?, ...)
    if condition == nil or condition == false then
        local s = s_ or "assertion failed"
        error(potatoformat(Potato.ASSERT, pc, s, ...))
    end
end

-- TODO maybe rename to Pomato or Totato?
local function Eggplant(pc : PotatoContext?, condition : any, s_ : string?, ...)
    -- disable these when deploying to production
    Tomato(pc, condition, ...)
    --Potato(Potato.Error, pc, s_ or "", ...)
end




-- TYPES
export type Frame = number
export type FrameCount = number
export type PlayerHandle = number


-- CONSTANTS
local carsHandle = 999
local spectatorHandle = -1
local nullHandle = -2
local frameInit = 0
local frameNegOne = -1
local frameNull = -99999999
local frameMax = 99999999
local frameMin = frameNull+1 -- just so we can distinguish between null and min







-- GGPOEvent types
export type GGPOEventType = "synchronized" | "input" | "interrupted" | "resumed" | "timesync" | "disconnected"
export type GGPOEvent_synchronized = {
    t: "synchronized",
    player: PlayerHandle,
}

-- TODO Rename field to inputs
export type GGPOEvent_Input<I> = { t : "input", input : PlayerFrameInputMap<I> }

export type GGPOEvent_interrupted = { t: "interrupted" }
export type GGPOEvent_resumed = { t: "resumed"  }
export type GGPOEvent_timesync = { t: "timesync", framesAhead : FrameCount } -- sleep for this number of frame to adjust for frame advantage
-- can we also embed this in the input, perhaps as a serverHandle input
export type GGPOEvent_disconnected = {
    t: "disconnected",
    player: PlayerHandle,
}


export type GGPOEvent<I> = GGPOEvent_synchronized | GGPOEvent_Input<I> | GGPOEvent_interrupted | GGPOEvent_resumed | GGPOEvent_timesync | GGPOEvent_disconnected
  


-- TODO add comments
export type GGPOCallbacks<T,I> = {
    SaveGameState: (frame: Frame) -> T,
    LoadGameState: (T, frame: Frame) -> (),
    AdvanceFrame: () -> (),

    -- TODO these should not be GGPOEvent, they should be some new type, because caller cares about a different set of events
    --OnPeerEvent: (event: GGPOEvent<I>, player: PlayerHandle) -> (),
    --OnSpectatorEvent: (event: GGPOEvent<I>, spectator: number) -> (),
    --DisconnectPlayer: (PlayerHandle) -> ()
}

export type GameInput<I> = {
    -- this is not really needed but conveient to have
    -- the destination frame of this input
    frame: Frame,

    -- TODO disconnect info 

    -- set to whatever type best represents your game input. Keep this object small! Maybe use a buffer! https://devforum.roblox.com/t/introducing-luau-buffer-type-beta/2724894
    -- nil represents no input? (i.e. AddLocalInput was never called)
    input: I?,

    -- TODO DELETE
    potato : (GameInput<I>) -> string,
    potato_severity : number,
}



local function GameInput_new<I>(frame : Frame, input : I?) : GameInput<I>
    assert(frame ~= nil, "expected frame to not be nil")
    local r = {
        frame = frame,
        input = input,

        -- TODO DELETE
        potato = function(self : GameInput<I>)
            return string.format("GameInput: frame: %d, input: %s", self.frame, tostring(self.input))
        end,
        potato_severity = Potato.Info,
    }
    return r
end


export type PredictionFn<I> = (frame : Frame, pastInputs : FrameInputMap<I>) -> I?

-- helper type intended to be used as the `I` type in GameConfig
-- the `info` parameter always has nil prediction
-- note that there is a redundant nil representation when both input and info are nil :(
export type InputWithInfo<I,J> = {
    input : I?,
    info : J?,
}

-- add nil prediction to the info field with a regular prediction function
local function makeInputWithInfoPrediction<I,J>(inputPrediction : PredictionFn<I>) : PredictionFn<InputWithInfo<I,J>>
    return function(frame : Frame, pastInputs : FrameInputMap<InputWithInfo<I,J>>)
        local filteredPastInputs = {}
        for f, x in pairs(pastInputs) do
            if x.input ~= nil and x.input.input ~= nil then
                filteredPastInputs[f] = GameInput_new(f, x.input.input)
            end
        end
        local p = inputPrediction(frame, filteredPastInputs)
        return { input = p, info = nil }
    end
end


export type GameConfig<I> = {
    inputDelay: FrameCount,
    maxPredictionFrames: FrameCount,

    -- TODO should probbaly return any type? We are going to rely on Roblox's built in serialization which takes Any
    -- if nil, then default serialization is used which may be inefficient
    inputToString : ((I) -> string)?,
    inputEquals : ((I?,I?) -> boolean),

    -- TODO
    --prediction : PredictionFn<I>,

    -- TODO eventually for performance
    --serializeInput : (I,J) -> string,
}

local defaultGameConfig = {
    inputDelay = 0,
    maxPredictionFrames = 8,
    inputToString = nil,
    infoToString = nil,
    inputEquals = function(a : any, b : any) return a == b end,
    --prediction = prediction_use_last_input,
}



export type FrameMap<T> = {[Frame] : T}

-- returns the last frame in the frame map or frameNull if the map is empty
local function FrameMap_lastFrame<T>(msg : FrameMap<T>) : Frame
    if isempty(msg) then
        return frameNull
    end

    local lastFrame = frameMin
    for frame, _ in pairs(msg) do
        if frame > lastFrame then
            lastFrame = frame
        end
    end
    return lastFrame
end

-- returns the first frame in the frame map or frameNull if the map is empty
local function FrameMap_firstFrame<T>(msg : FrameMap<T>) : Frame
    if isempty(msg) then
        return frameNull
    end

    local firstFrame = frameMax
    for frame, _ in pairs(msg) do
        if frame < firstFrame then
            firstFrame = frame
        end
    end
    return firstFrame
end

export type FrameInputMap<I> = FrameMap<GameInput<I> >

local function FrameInputMap_potato<I>(msg : FrameInputMap<I>) : string
    local r = ""
    for frame, input in pairs(msg) do
        r = r .. string.format("(%d,%s)", frame, tostring(input.input))
    end
    return r
end

export type PlayerInputMap<I> = {[PlayerHandle] : GameInput<I>}

export type PlayerFrameInputMap<I> = {[PlayerHandle] : FrameInputMap<I>}

local function PlayerFrameInputMap_addInputs<I>(a : PlayerFrameInputMap<I>, b : PlayerFrameInputMap<I>)
    for player, frameData in pairs(b) do
        for frame, input in pairs(frameData) do
            -- TODO assert inputs are equal if present in a
            --if table.contains(a, player) and table.contains(a[player][frame]) and a[player][frame] ~= a[player][frame] then 
            a[player][frame] = input
        end
    end
end


local function prediction_use_last_input<I>(frame : Frame, pastInputs : FrameInputMap<I>) : I?
    local lastFrame = FrameMap_lastFrame(pastInputs)
    if lastFrame == frameNull then
        return nil
    end
    assert(lastFrame < frame, "expected last frame to be less than prediction frame")
    return pastInputs[lastFrame].input
end





export type UDPEndpoint<I> = {
    send: (UDPMsg<I>) -> (),
    -- PlayerHandle is the player that sent the message
    -- TODO remove this argument, it's just for debugging
    subscribe: ((UDPMsg<I>, PlayerHandle)->()) -> (),
}

local uselessUDPEndpoint : UDPEndpoint<any> = {
    send = function(msg) end,
    subscribe = function(cb) end
}



export type UDPNetworkStats = {
    max_send_queue_len : number,
    ping : number,
    kbps_sent : number,
    local_frames_behind : FrameCount,
    remote_frames_behind : FrameCount,
}

-- DONE UNTESTED
export type InputQueue<I> = {

    gameConfig : GameConfig<I>,

    owner : PlayerHandle, -- the player that owns this InputQueue, for debug purposes only
    player : PlayerHandle, -- the player this InputQueue represents

    last_user_added_frame : Frame, -- does not include frame_delay
    last_added_frame : Frame, -- accounts for frame_delay, will equal last_user_added_frame + frame_delay if there were no frame delay shenanigans
    first_incorrect_frame : Frame,
    last_frame_requested : Frame,

    prediction_map : FrameInputMap<I>, 

    frame_delay : FrameCount,

    inputs : FrameInputMap<I>,

    potato : (InputQueue<I>) -> string,
    potato_severity : number,
}

local function InputQueue_new<I>(gameConfig : GameConfig<I>, owner : PlayerHandle, player: PlayerHandle, startFrame : Frame, currentFrame : Frame, frame_delay : FrameCount) : InputQueue<I>
    local prediction_map = {}
    -- no InputQueue = we were effectively predicting up until just before the currentFrame (assumes we have not called GetInput on the currentFrame)
    for i = startFrame, currentFrame-1, 1 do
        prediction_map[i] = GameInput_new(i, nil)
    end
    local r = {
        gameConfig = gameConfig,

        owner = owner, 
        player = player,

        last_user_added_frame = frameNull,
        last_added_frame = frameNull,
        first_incorrect_frame = frameNull,
        last_frame_requested = frameNull,
        

        prediction_map = prediction_map,

        frame_delay = frame_delay,

        inputs = {},

        potato = function(self : InputQueue<I>)
            return string.format("InputQueue: owner %d, player: %d, last_user_added_frame: %d, last_added_frame: %d, first_incorrect_frame: %d, last_frame_requested: %d, frame_delay: %d, firstFrame(prediction_map): %d", 
                self.owner, self.player, self.last_user_added_frame, self.last_added_frame, self.first_incorrect_frame, self.last_frame_requested, self.frame_delay, FrameMap_firstFrame(self.prediction_map))
        end,
        potato_severity = Potato.Warn,
    }
    return r
end

local function InputQueue_SetFrameDelay<I>(inputQueue : InputQueue<I>, delay : number)
    inputQueue.frame_delay = delay
end

-- TODO rename to GetLastAddedFrame, because in CARS networks case, only CARS can confirm frames but we may be still add input locally or from non-auth peers
local function InputQueue_GetLastConfirmedFrame<I>(inputQueue : InputQueue<I>) : Frame
    return inputQueue.last_added_frame
end

local function InputQueue_GetFirstIncorrectFrame<I>(inputQueue : InputQueue<I>) : Frame
    return inputQueue.first_incorrect_frame
end

-- cleanup confirmed frames, we will never roll back to these
local function InputQueue_DiscardConfirmedFrames<I>(inputQueue : InputQueue<I>, frame : Frame)
    assert(frame >= 0)

    -- don't discard frames further back then we've last requested them :O
    --if inputQueue.last_frame_requested ~= frameNull then
    --    frame = math.min(frame, inputQueue.last_frame_requested)
    --end
    Tomato(ctx(inputQueue), inputQueue.last_frame_requested == frameNull or inputQueue.last_frame_requested >= frame, "expected last_frame_requested: %d to be nil or >= frame: %d", inputQueue.last_frame_requested, frame)

    Potato(Potato.Info, ctx(inputQueue), "InputQueue_DiscardConfirmedFrames: frame: %d", frame)

    local start = FrameMap_firstFrame(inputQueue.inputs)

    local endFrame = frame

    -- we need at least one frame in our map for prediction (TODO maybe keep more than one frame)
    if endFrame == FrameMap_lastFrame(inputQueue.inputs) then
        endFrame = endFrame-1
    end

    if start ~= frameNull and start <= endFrame then
        for i = start, endFrame, 1 do
            inputQueue.inputs[i] = nil
        end
    end
    
end

-- resets the prediction 
local function InputQueue_ResetPrediction<I>(inputQueue : InputQueue<I>, frame : Frame)
    Tomato(ctx(inputQueue), inputQueue.first_incorrect_frame == frameNull or frame <= inputQueue.first_incorrect_frame, "expected reset past first_incorrect_frame")
    inputQueue.first_incorrect_frame = frameNull

    
    -- we've rolled back at least as far back as first_incorrect_frame so we can just clear the prediction map, the predictions will get regenerated as we request inputs
    local firstpredictedframe = FrameMap_firstFrame(inputQueue.prediction_map)
    Tomato(ctx(inputQueue), firstpredictedframe == frameNull or firstpredictedframe >= frame, "expected first frame of prediction map %d to be >= %d", firstpredictedframe, frame)     
    inputQueue.prediction_map = {}

    -- this is safe to do as because at the start of rollback, Sync will always ResetPrediction to at least as far back as our first_incorrect_frame, then it will call GetInput a bunch of times putting this back to where it was before and updating the prediction stuff above
    inputQueue.last_frame_requested = frameNull
end



local function InputQueue_GetConfirmedInput<I>(inputQueue : InputQueue<I>, frame : Frame) : GameInput<I>
    Tomato(ctx(inputQueue), inputQueue.first_incorrect_frame == frameNull or frame < inputQueue.first_incorrect_frame)
    local fd = inputQueue.inputs[frame]
    Tomato(ctx(inputQueue), fd, "expected frame %d to exist, this probably means the frame has not been confirmed for this player!", frame)
    return fd
end


local function InputQueue_GetLastAddedInput<I>(inputQueue : InputQueue<I>) : GameInput<I>
    if inputQueue.last_added_frame == frameNull then
        return GameInput_new(frameNull, nil)
    end
    return inputQueue.inputs[inputQueue.last_added_frame]
end

local function InputQueue_GetInput<I>(inputQueue : InputQueue<I>, frame : Frame) : GameInput<I>
    Potato(Potato.Debug, ctx(inputQueue), "requesting input frame %d.", frame);

    --[[
    No one should ever try to grab any input when we have a prediction
    error.  Doing so means that we're just going further down the wrong
    path.  ASSERT this to verify that it's true.
    ]]
    Tomato(ctx(inputQueue), inputQueue.first_incorrect_frame == frameNull, "expected first_incorrect_frame: %d to be nil", inputQueue.first_incorrect_frame);

    inputQueue.last_frame_requested = frame;

    local fd = inputQueue.inputs[frame]
    if fd then
        return fd
    else
        Potato(Potato.Info, ctx(inputQueue), "requested frame %d not found in queue.", frame);
        local basedInput = deep_copy(InputQueue_GetLastAddedInput(inputQueue))
        -- eventually we may drop this requirement and use a more complex prediction algorithm, in particular, we may have inputs from the future 
        Tomato(ctx(inputQueue), basedInput.frame < frame, "expected frame used for prediction to be less than requested frame (frame:%d, basedInput.frame:%d)", frame, basedInput.frame)
        Potato(Potato.Debug, ctx(inputQueue), "basing new prediction frame from previously added frame (frame:%d).", basedInput.frame)
        basedInput.frame = frame
        inputQueue.prediction_map[frame] = basedInput
        return basedInput
    end
end

local function InputQueue_AddInput_Internal<I>(inputQueue : InputQueue<I>, input : GameInput<I>)       
    Potato(Potato.Trace, ctx(inputQueue), "adding input %s for frame %d ", tostring(input.input), input.frame)
    if 
        -- if we attempted to predict this frame 
        (inputQueue.prediction_map[input.frame] ~= nil) 
        --OR another peer sent us a frame in the past (TODO peer can only do this if peer == carsHandle)
        or (inputQueue.player == carsHandle and inputQueue.inputs[input.frame]) 
    then

        local basedInput = inputQueue.inputs[input.frame] or inputQueue.prediction_map[input.frame]
        local match = inputQueue.gameConfig.inputEquals(basedInput.input, input.input)
        Potato(Potato.Trace, ctx(inputQueue), "checking prediction for frame %d based on frame %d match: %s", input.frame, basedInput.frame, tostring(match))
        if match then  
            Potato(Potato.Info, ctx(inputQueue), "prediction correct for frame %d (prev first_incorrect_frame %d)", input.frame, inputQueue.first_incorrect_frame)
            inputQueue.prediction_map[input.frame] = nil
        else
            Potato(Potato.Info, ctx(inputQueue), "MISSED PREDICTION for frame %d (prev first_incorrect_frame %d)", input.frame, inputQueue.first_incorrect_frame)
            if inputQueue.first_incorrect_frame ~= frameNull then
                if input.frame < inputQueue.first_incorrect_frame then
                    inputQueue.first_incorrect_frame = input.frame
                end
            else    
                inputQueue.first_incorrect_frame = input.frame
            end
        end
    else
        Tomato(ctx(inputQueue), inputQueue.inputs[input.frame] == nil, "expected frame to not exist in queue")
    end
    
    Tomato(ctx(inputQueue), inputQueue.inputs[input.frame] == nil, "expected frame to not exist in queue")
    inputQueue.inputs[input.frame] = input
    inputQueue.last_added_frame = input.frame
end

-- NOTE this function will not work for out of order inputs, it can not tell the difference between frame delay shenanigans and out of order inputs
-- TODO rename this function, we dont have a queue head concept anymore, instead, just call it AdjustFrameDelay or something
-- advance the queue head to target frame and returns frame with delay applied
local function InputQueue_AdjustForFrameDelay<I>(inputQueue : InputQueue<I>, frame : Frame) : Frame
    Potato(Potato.Info, ctx(inputQueue), "adjusting frame %d for frame delay", frame)

    -- NOTE in the future, when players can join mid game, the first input may not be on frame 0
    local expected_frame = (inputQueue.last_added_frame == frameNull and 0) or inputQueue.last_added_frame + 1
    frame += inputQueue.frame_delay

    Tomato(ctx(inputQueue), expected_frame >= frameInit, "expected_frame %d must be >= 0", expected_frame)


    if expected_frame > frame then
        -- this can occur when the frame delay has dropped since the last time we shoved a frame into the system.  In this case, there's no room on the queue.  Toss it.
        Potato(Potato.Warn, ctx(inputQueue), "Dropping input frame %d (expected next frame to be %d).", frame, expected_frame)
        return frameNull
    end

    -- this can occur when the frame delay has been increased since the last time we shoved a frame into the system.  We need to replicate the last frame in the queue several times in order to fill the space left.
    if expected_frame < frame then
        local last_frame = FrameMap_lastFrame(inputQueue.inputs)
        while expected_frame < frame do
            Potato(Potato.Warn, ctx(inputQueue), "Adding padding frame %d to account for change in frame delay.", expected_frame)
            local input : I?
            if last_frame == frameNull then 
                input = nil
            else 
                input = inputQueue.inputs[last_frame].input
            end
            inputQueue.inputs[expected_frame] = GameInput_new(expected_frame, input)
            expected_frame += 1
        end
    end
    return frame
end

-- returns nil if the input was not added (due to already being in the queue)
-- returns the GameInput with frame adjusted for frame delay
local function InputQueue_AddLocalInput<I>(inputQueue : InputQueue<I>, input : GameInput<I>) : GameInput<I>?

    Tomato(ctx(inputQueue), inputQueue.owner == inputQueue.player, "expected local input!")
    -- verify that inputs are passed in sequentially by the user, regardless of frame delay
    -- NOTE in the future, when players can join mid game, the first input may not be on frame 0, 
    Tomato(ctx(inputQueue), inputQueue.last_user_added_frame == frameNull or input.frame == inputQueue.last_user_added_frame + 1, string.format("expected input frames to be sequential %d == %d+1", input.frame, inputQueue.last_user_added_frame))


    inputQueue.last_user_added_frame = input.frame

    local new_frame = InputQueue_AdjustForFrameDelay(inputQueue, input.frame)
    local new_input = GameInput_new(new_frame, input.input)
    if new_frame ~= frameNull then
        InputQueue_AddInput_Internal(inputQueue, new_input)
    end

    return new_input
end

local function InputQueue_AddRemoteInput<I>(inputQueue : InputQueue<I>, input : GameInput<I>)
    Tomato(ctx(inputQueue), inputQueue.owner ~= inputQueue.player, "expected remote input!")
    Potato(Potato.Info, ctx(inputQueue), "adding input %s for frame %d ", tostring(input.input), input.frame)

    -- NOTE in the future, we want to support out of order inputs, then remove this check
    -- verify that inputs are passed in sequentially by the user, regardless of frame delay
    -- NOTE in the future, when players can join mid game, the first input may not be on frame 0, 
    Tomato(ctx(inputQueue), inputQueue.last_user_added_frame == frameNull or input.frame <= inputQueue.last_user_added_frame + 1, string.format("expected input frames to be sort-of sequential %d <= %d+1", input.frame, inputQueue.last_user_added_frame))
    -- TODO use this check once we actually have per player input ack tracking in CARS case (NOTE, you will have to prune the seen input in udpproto before it gets added to the queue, at least that's how OG ggpo does it)
    --Tomato(ctx(inputQueue), inputQueue.last_user_added_frame == frameNull or input.frame == inputQueue.last_user_added_frame + 1, string.format("expected input frames to be sequential %d == %d+1", input.frame, inputQueue.last_user_added_frame))
    -- TODO remove this guard once the assert above is enabled
    if input.frame < inputQueue.last_user_added_frame + 1 then
        -- expected to happen since we don't prune in udpproto before adding to msg queue
        Potato(Potato.Info, ctx(inputQueue), "Input frame %d is <= than the most recently added frame %d.  Ignoring.", input.frame, inputQueue.last_user_added_frame)
        return 
    end

    inputQueue.last_user_added_frame = input.frame
    InputQueue_AddInput_Internal(inputQueue, input)
end
   

-- DONE UNTESTED
export type Sync<T,I> = {
    -- TODO maybe rename to owner
    player : PlayerHandle,

    gameConfig : GameConfig<I>,
    callbacks : GGPOCallbacks<T,I>,
    -- TODO need cleanup routine (with opt-out for testing)
    savedstate : FrameMap<{ state : T, checksum : string }>,
    rollingback : boolean,
    last_confirmed_frame : Frame,
    framecount : Frame, -- TODO rename to currentFrame
    max_prediction_frames : FrameCount,
    -- TODO rename input_queues
    input_queue : {[PlayerHandle] : InputQueue<I>},

    potato : (Sync<T,I>) -> string,
    potato_severity : number,
}


local function Sync_new<T,I>(gameConfig: GameConfig<I>, callbacks: GGPOCallbacks<T,I>, player : PlayerHandle, max_prediction_frames: FrameCount) : Sync<T,I>
    local r = {
        player = player,
        gameConfig = gameConfig,
        callbacks = callbacks,
        savedstate = {},
        max_prediction_frames = max_prediction_frames,
        rollingback = false,
        last_confirmed_frame = frameNull,
        framecount = frameInit,

        -- TODO preallocate players
        input_queue = {},

        potato = function(self : Sync<T,I>)
            return string.format("Sync: player: %d, max_prediction_frames: %d, rollingback: %s, last_confirmed_frame: %d, framecount: %d", 
                self.player, self.max_prediction_frames, tostring(self.rollingback), self.last_confirmed_frame, self.framecount)
        end,

        potato_severity = Potato.Warn,
    }
    return r
end

local function Sync_LazyAddPlayer<T,I>(sync : Sync<T,I>, player : PlayerHandle)
    if sync.input_queue[player] == nil then
        -- for now, start frame is just frameInit but we will change this to something else if/when we allow players to join mid game
        sync.input_queue[player] = InputQueue_new(sync.gameConfig, sync.player, player, frameInit, sync.framecount, sync.gameConfig.inputDelay)
    end
end

local function Sync_LoadFrame<T,I>(sync : Sync<T,I>, frame : Frame) 
    if frame == sync.framecount then
        Potato(Potato.Info, ctx(sync), "Skipping LoadFame %d NOP.", frame)
    end

    local state = sync.savedstate[frame]
    Tomato(ctx(sync), state, "expected state to exist for frame %d", frame)
    Potato(Potato.Info, ctx(sync), "Loading frame info %d checksum: %s", frame, state.checksum)
    sync.callbacks.LoadGameState(state.state, frame)
    sync.framecount = frame
end

local function Sync_SaveCurrentFrame<T,I>(sync : Sync<T,I>)
    local state = sync.callbacks.SaveGameState(sync.framecount)
    local checksum = "TODO"
    sync.savedstate[sync.framecount] = { state = state, checksum = checksum }
    Potato(Potato.Info, ctx(sync), "Saved frame info %d (checksum: %s).", sync.framecount, checksum)

    -- delete all frames in the future, we will never rollback to them
    local lastFrame = FrameMap_lastFrame(sync.savedstate)
    for i = sync.framecount+1, lastFrame, 1 do
        sync.savedstate[i] = nil
    end
end

local function Sync_GetSavedFrame<T,I>(sync : Sync<T,I>, frame : Frame) 
    return sync.savedstate[frame]
end


local function Sync_SetLastConfirmedFrame<T,I>(sync : Sync<T,I>, frame : Frame)
    sync.last_confirmed_frame = frame
    
    -- we may eventually allow input on frameInit (to transmit per-player data) so use >= here (to discard frameInit inputs I guess lol)
    if frame >= frameInit then
        for player, iq in pairs(sync.input_queue) do
            InputQueue_DiscardConfirmedFrames(iq, frame)
        end
    end

    -- clear the saved states up until frame (exclusive) since we will never rollback past a confirmed frame
    local firstFrame = FrameMap_firstFrame(sync.savedstate)
    if firstFrame ~= frameNull then
        for i = firstFrame, frame-1, 1 do
            sync.savedstate[i] = nil
        end
    end
end



-- returns nil if the input was rejected (either due to being too far ahead, or already in the queue)
-- returns the GameInput with frame adjusted for frame delay
local function Sync_AddLocalInput<T,I>(sync : Sync<T,I>, player : PlayerHandle, input : GameInput<I>) : GameInput<I>?
    Tomato(ctx(sync), input ~= nil, "expected input to not be nil")
    Tomato(ctx(sync), player == sync.player, "expected player to be the owner of this sync object")

    Sync_LazyAddPlayer(sync, player)

    -- reject local input if we've gone too far ahead
    local frames_behind = sync.framecount - sync.last_confirmed_frame
    if sync.framecount >= sync.max_prediction_frames and frames_behind >= sync.max_prediction_frames then
        Potato(Potato.Warn, ctx(sync), "Rejecting input from emulator: reached prediction barrier.");
        return nil
    end

    if sync.framecount == 0 then
        -- TODO this is a little werid, better to do this in the ctor, but I guess the callback might not be ready then, so I guess this is fine too
        Sync_SaveCurrentFrame(sync)
    end

    Potato(Potato.Info, ctx(sync), "Adding undelayed local frame %d for player %d.", sync.framecount, player)
    Tomato(ctx(sync), input.frame == sync.framecount, string.format("expected input frame %d to match current frame %d", input.frame, sync.framecount))
    return InputQueue_AddLocalInput(sync.input_queue[player], input)
end

local function Sync_AddRemoteInput<T,I>(sync : Sync<T,I>, player : PlayerHandle, input : GameInput<I>)
    Sync_LazyAddPlayer(sync, player)

    if player == sync.player then
        if sync.input_queue[player][input.frame] ~= nil then
            Potato(Potato.Warn, ctx(sync), "Received remote self input for frame %d", input.frame)
        end
    end
    InputQueue_AddRemoteInput(sync.input_queue[player], input)
end


local function Sync_GetConfirmedInputs<T,I>(sync : Sync<T,I>, frame: Frame) : PlayerInputMap<I>
    local r = {}
    for player, iq in pairs(sync.input_queue) do
        r[player] = InputQueue_GetConfirmedInput(iq, frame)
    end
    return r
end


local function Sync_SynchronizeInputs<T,I>(sync : Sync<T,I>) : PlayerInputMap<I>
    local r = {}
    for player, iq in pairs(sync.input_queue) do
        r[player] = InputQueue_GetInput(iq, sync.framecount)
    end
    return r
end

local function Sync_AdjustSimulation<T,I>(sync : Sync<T,I>, seek_to : number)
    local framecount = sync.framecount
    local count = sync.framecount - seek_to

    Tomato(ctx(sync), count > 0, "expected to rollback more than 0 frames")
    Potato(Potato.Warn, ctx(sync), "Rollback from %d to %d", sync.framecount, seek_to)
    sync.rollingback = true

    Sync_LoadFrame(sync, seek_to)
    Tomato(ctx(sync), sync.framecount == seek_to, "expected sync.framecount: %d to be %d after rollback", sync.framecount, seek_to)

    for _, iq in pairs(sync.input_queue) do
        InputQueue_ResetPrediction(iq, sync.framecount)
    end

    for i = 0, count-1, 1 do
        -- NOTE this is reentrant!
        sync.callbacks.AdvanceFrame()
    end
    Tomato(ctx(sync), sync.framecount == framecount, "expected sync.framecount: %d to be %d after replay during rollback", sync.framecount, framecount)
    sync.rollingback = false
end

local function Sync_CheckSimulationConsistency<T,I>(sync : Sync<T,I>) : Frame
    local first_incorrect = frameNull
    for player, iq in pairs(sync.input_queue) do
        local incorrect = InputQueue_GetFirstIncorrectFrame(iq)
        --print(tostring(sync.player) .. " GOT INCORRECT " .. tostring(incorrect) .. " FROM " .. tostring(player))
        if incorrect ~= frameNull and (first_incorrect == frameNull or incorrect < first_incorrect) then
            first_incorrect = incorrect
        end
    end

    if first_incorrect == frameNull then
        Potato(Potato.Info, ctx(sync), "prediction ok.  proceeding.")
    end

    return first_incorrect
end

-- returns the frame we rolled back to (or current frame if no rollback was needed)
local function Sync_CheckSimulation<T,I>(sync : Sync<T,I>) : Frame
    local seekto = Sync_CheckSimulationConsistency(sync)
    if seekto ~= frameNull then
        Sync_AdjustSimulation(sync, seekto);
    end
    return seekto
end

local function Sync_IncrementFrame<T,I>(sync : Sync<T,I>)
    sync.framecount += 1
    Sync_SaveCurrentFrame(sync)
end

local function Sync_SetFrameDelay<T,I>(sync : Sync<T,I>, player : PlayerHandle, delay : FrameCount)
    Sync_LazyAddPlayer(sync, player)
    sync.input_queue[player].frame_delay = delay
end

local function Sync_InRollback<T,I>(sync : Sync<T,I>) : boolean
    return sync.rollingback
end


-- TODO make these configureable
local MIN_FRAME_ADVANTAGE = 3
local MAX_FRAME_ADVANTAGE = 9

-- DONE untested
export type TimeSync = {
    localRollingFrameAdvantage : number,
    remoteRollingFrameAdvantage : {[PlayerHandle] : number},
}

local function TimeSync_new() : TimeSync
    local r = {
        localRollingFrameAdvantage = 0,
        remoteRollingFrameAdvantage = {},
    }
    return r
end

local function TimeSync_advance_frame(timesync : TimeSync, advantage : number, radvantage : {[PlayerHandle] : number})
    local w = 0.5
    timesync.localRollingFrameAdvantage = timesync.localRollingFrameAdvantage * (1-w) + advantage*w
    for player, adv in pairs(radvantage) do
        if timesync.remoteRollingFrameAdvantage[player] == nil then
            timesync.remoteRollingFrameAdvantage[player] = adv
        else
            timesync.remoteRollingFrameAdvantage[player] = timesync.remoteRollingFrameAdvantage[player] * (1-w) + adv*w
        end
    end
end

local function TimeSync_recommend_frame_wait_duration(timesync : TimeSync) : number
    if isempty(timesync.remoteRollingFrameAdvantage) then
        return 0
    end

    local advantage = timesync.localRollingFrameAdvantage


    local radvantagemin
    local radvantagemax
    
    for player, adv in pairs(timesync.remoteRollingFrameAdvantage) do
        if radvantagemin == nil then
            radvantagemin = adv
            radvantagemax = adv
        else
            radvantagemin = math.min(adv, radvantagemin)
            radvantagemax = math.max(adv, radvantagemax)
        end
    end

    -- LOL why not IDK
    local radvantage = (radvantagemin + radvantagemax) / 2

    -- See if someone should take action.  The person furthest ahead needs to slow down so the other user can catch up. Only do this if both clients agree on who's ahead!!
    if advantage >= radvantage then
        return 0
    end

    -- Both clients agree that we're the one ahead.  Split the difference between the two to figure out how many frames too  to sleep for.
    local sleep_frames = math.floor(((radvantage - advantage) / 2) + 0.5)

    Log("sleep frames is %d", sleep_frames)

    if sleep_frames < MIN_FRAME_ADVANTAGE then
        return 0
    end

    -- original ggpo does input checking here, but in our implementation we leave it up to the caller to determine whether to follow the rec or not.

    return math.min(sleep_frames, MAX_FRAME_ADVANTAGE)
end







export type UDPProto_Player<I> = {
    -- alternatively, consider storing these values as a { [PlayerHandle] : number } table, but this would require sending per player stats rather than just max
    -- (according to peer) frame peer - frame player
    frame_advantage : number,
    pending_output : {[Frame] : GameInput<I>},
    lastFrame : Frame,

   --disconnect_event_sent : number,
   --disconnect_timeout : number;
   --disconnect_notify_start : number;
   --disconnect_notify_sent : number;
    --TimeSync                   _timesync;
    --RingBuffer<UdpProtocol::Event, 64>  _event_queue;
}

local function UDPProto_Player_new() : UDPProto_Player<any>
    local r = {
        frame_advantage = 0,
        pending_output = {},
        lastFrame = frameNegOne,
        
    }
    return r
end



local UDPPROTO_MAX_SEQ_DISTANCE = 8
local UDPPROTO_NO_QUEUE_NIL_INPUT = true

export type UDPMsg_Type = "Ping" | "Pong" | "InputAck" | "Input" | "QualityReport" 

-- TODO get rid of these underscores
-- UDPMsg types
-- these replace sync packets which are not needed for Roblox
export type UDPPeerMsg_Ping = { t: "Ping", time: TimeMS }
export type UDPPeerMsg_Pong = { t: "Pong", time: TimeMS }
export type UDPPeerMsg_InputAck = { t: "InputAck", frame : Frame }


export type QualityReport = { 
    frame_advantage : FrameCount, 
}

export type UDPMsg_QualityReport = {
    t: "QualityReport", 
    peer : QualityReport,
    player: {[PlayerHandle] : QualityReport},
    time : TimeMS,
}


export type UDPMsg_Input<I> = {
    t : "Input",
    ack_frame : Frame,
    peerFrame : Frame, -- TODO DELETE this should alwasy mattch the frame inside inputs[peer].lastFrame
    inputs : {[PlayerHandle] : { inputs : FrameInputMap<I>, lastFrame : Frame } },
}


export type UDPMsg_Contents<I> = 
    UDPPeerMsg_Ping
    | UDPPeerMsg_Pong
    | UDPPeerMsg_InputAck 
    | UDPMsg_QualityReport 
    | UDPMsg_Input<I> 
    | UDPMsg_QualityReport

export type UDPMsg<I> = {
    m : UDPMsg_Contents<I>,
    seq : number,
}

local function UDPMsg_Size<I>(UDPMsg : UDPMsg<I>) : number
    -- TODO
    return 0
end

local function UDPMsg_potato<I>(UDPMsg : UDPMsg<I>) : string
    if UDPMsg.m.t == "Ping" then
        return string.format("UDPMsg: Ping: time: %d", UDPMsg.m.time)
    elseif UDPMsg.m.t == "Pong" then
        return string.format("UDPMsg: Pong: time: %d", UDPMsg.m.time)
    elseif UDPMsg.m.t == "InputAck" then
        return string.format("UDPMsg: InputAck: frame: %d", UDPMsg.m.frame)
    elseif UDPMsg.m.t == "QualityReport" then
        return string.format("UDPMsg: QualityReport: frame_advantage: %d", UDPMsg.m.peer.frame_advantage)
    elseif UDPMsg.m.t == "Input" then
        local inputs = ""
        for p, i in pairs(UDPMsg.m.inputs) do
            inputs = inputs .. string.format("player: %d ", p) .. FrameInputMap_potato(i.inputs)
        end
        return string.format("UDPMsg: Input: ack_frame: %d, peerFrame: %d, inputs: \n%s", UDPMsg.m.ack_frame, UDPMsg.m.peerFrame, inputs)
    else
        return "UDPMsg: unknown"
    end
end


-- DONE UNTESTED
-- manages synchronizing with a single peer
-- in particular, manages the following:
-- sending and acking input
-- synchronizing (initialization)






-- tracks ping for frame advantage computation
export type UDPProto<I> = {

    -- id
    owner : PlayerHandle, -- the player that owns this UDPProto
    player : PlayerHandle, -- the player we are connected to
    endpoint : UDPEndpoint<I>,

    -- configuration
    sendLatency : number,
    msPerFrame: number,

    -- rift calculation

    -- TODO rename to lastReceivedPeerFrame
    lastReceivedFrame : Frame, -- this will always match playerData[player].lastFrame

    round_trip_time : TimeMS,
    -- (according to peer) frame peer - frame self
    remote_frame_advantage : FrameCount,
    -- (according to self) frame self - frame peer
    local_frame_advantage : FrameCount,

    -- right now, this should always match match playerData[owner].lastFrame
    -- however in the future, if we have cars auth input these will not match, playerData[player].lastFrame will be the last input received from cars
    lastAddedLocalFrame : Frame,

    lastAckedFrame : Frame,

    -- stats
    packets_sent : number,
    bytes_sent : number,
    kbps_sent: number,
    stats_start_time : TimeMS,
    
    -- logging
    last_sent_input : GameInput<I>,

    -- running state
    --last_quality_report_time : number,
    --last_network_stats_interval : number,
    --last_input_packet_recv_time : number, 

    -- packet counting
    next_send_seq : number,
    next_recv_seq : number,

    event_queue : Queue.Queue<GGPOEvent<I>>,

    playerData : {[PlayerHandle] : UDPProto_Player<I>},

    timesync : TimeSync,

    -- shutdown/keepalive timers
    --shutdown_timeout : number,
    --last_send_time : number,
    --last_recv_time : number,

    potato : (UDPProto<I>, PotatoVerbosity) -> string,
    potato_severity : number,
}

-- NOTE due to lazy init, players may not be in the map, yikes!
local function UDPProto_lastSynchronizedFrame<I>(udpproto : UDPProto<I>) : Frame
    local lastFrame = frameMax
    for player, data in pairs(udpproto.playerData) do
        if data.lastFrame < lastFrame then
            lastFrame = data.lastFrame
        end
    end
    lastFrame = math.min(udpproto.lastReceivedFrame, lastFrame)
    return lastFrame
end

local function UDPProto_new<I>(owner : PlayerHandle, player : PlayerHandle, endpoint : UDPEndpoint<I>) : UDPProto<I>

    -- initialize playerData
    local playerData = {}
    playerData[owner] = UDPProto_Player_new()

    local r = {
        owner = owner,
        player = player,
        endpoint = endpoint,

        -- TODO configure
        sendLatency = 0,
        msPerFrame = 50,

        lastReceivedFrame = frameNegOne,
        round_trip_time = 0,
        remote_frame_advantage = 0,
        local_frame_advantage = 0,

        lastAddedLocalFrame = frameNegOne,

        lastAckedFrame = frameNull,

        packets_sent = 0,
        bytes_sent = 0,
        kbps_sent = 0,
        stats_start_time = 0,


        last_sent_input = GameInput_new(frameNull, nil),


        next_send_seq = 0,
        next_recv_seq = 0,

        --last_send_time = 0,
        --last_recv_time = 0,

        event_queue = Queue.new(),

        playerData = playerData,

        timesync = TimeSync_new(),

        potato = function(self : UDPProto<I>, verbosity : PotatoVerbosity)
            if verbosity == Potato.Verbose then
                return string.format("UDPProto: owner %d, player: %d, lastReceivedFrame: %d, round_trip_time: %d, remote_frame_advantage: %d, local_frame_advantage: %d, lastAddedLocalFrame: %d, packets_sent: %d, bytes_sent: %d, kbps_sent: %d, stats_start_time: %d, next_send_seq: %d, next_recv_seq: %d", 
                    self.owner, self.player, self.lastReceivedFrame, self.round_trip_time, self.remote_frame_advantage, self.local_frame_advantage, self.lastAddedLocalFrame, self.packets_sent, self.bytes_sent, self.kbps_sent, self.stats_start_time, self.next_send_seq, self.next_recv_seq)
            else
                return string.format("UDPProto: owner %d, player: %d", self.owner, self.player)
            end
        end,
        potato_severity = Potato.Warn,
    }

    endpoint.subscribe(function(msg : UDPMsg<I>, player : PlayerHandle) 
        assert(player == r.player, "expected player to match")
        -- TODO assert that we aren't in rollback
        UDPProto_OnMsg(r, msg) 
    end)

    return r
end

-- TODO don't allow lazy player init
-- replace these calls with an assert and do pre init when calling GGPO_Peer_AddPlayer
local function UDPProto_LazyInitPlayer<I>(udpproto : UDPProto<I>, player : PlayerHandle) : UDPProto_Player<I>
    local r = udpproto.playerData[player]
    if r == nil then
        -- TODO may need to init with different values if player was added mid game
        r = UDPProto_Player_new()
        udpproto.playerData[player] = r
    end
    return r
end

local function UDPProto_SendMsg<I>(udpproto : UDPProto<I>, msgc : UDPMsg_Contents<I>)
    local msg = {
        m = msgc,
        seq = udpproto.next_send_seq,
    }
    udpproto.next_send_seq += 1
    udpproto.packets_sent += 1
    udpproto.bytes_sent += UDPMsg_Size(msg)

    --Log("SendMsg: %s", msg)
    --_last_send_time = Platform::GetCurrentTimeMS();
    udpproto.endpoint.send(msg)
end

local function UDPProto_SendPendingOutput<I>(udpproto : UDPProto<I>)
    local inputs = {}
    for player, data in pairs(udpproto.playerData) do
        if 
            player ~= udpproto.player -- don't replicate events back to the player who sent them to us
            and data.lastFrame > udpproto.lastAckedFrame -- don't send anything if we're all caught up, NOTE data.lastFrame should never be < udpproto.lastAckedFrame
        then
            inputs[player] = { inputs = data.pending_output, lastFrame = data.lastFrame }
        end
    end
    UDPProto_SendMsg(udpproto, { t = "Input", ack_frame = udpproto.lastReceivedFrame, peerFrame = udpproto.lastAddedLocalFrame, inputs = inputs })
end

-- MUST be called once each frame!!! If there is no input, just call with { frame = frame, input = nil }
local function UDPProto_SendOwnerInput<I>(udpproto : UDPProto<I>, input : GameInput<I>)

    -- Check to see if this is a good time to adjust for the rift...
    local remoteFrameAdvantages = {}
    for player, data in pairs(udpproto.playerData) do
        -- convert frame advantages to be relative to us, they were reported relative to peer
        remoteFrameAdvantages[player] = udpproto.remote_frame_advantage - data.frame_advantage
    end
    -- peer never reports its own frame advantage relative to itself since it's always 0
    remoteFrameAdvantages[udpproto.player] = udpproto.remote_frame_advantage
    TimeSync_advance_frame(udpproto.timesync, udpproto.local_frame_advantage, remoteFrameAdvantages)


    Tomato(ctx(udpproto), input.frame == udpproto.lastAddedLocalFrame + 1, string.format("expected input frame %d to be %d + 1", input.frame, udpproto.lastAddedLocalFrame))


    udpproto.lastAddedLocalFrame = input.frame
    -- TODO, don't do this if you want server to override player input
    -- if not udpproto.localInputAuthority
    udpproto.playerData[udpproto.owner].lastFrame = input.frame

    -- add our own input to our pending output
    if UDPPROTO_NO_QUEUE_NIL_INPUT and input.input == nil then
        Potato(Potato.Info, ctx(udpproto), "UDPProto_SendOwnerInput: input is nil, no need to queue it")
    else
        udpproto.playerData[udpproto.owner].pending_output[input.frame] = input
    end
    UDPProto_SendPendingOutput(udpproto);
end

local function UDPProto_AddToPendingOutput<I>(udpproto : UDPProto<I>, playerInputs : PlayerFrameInputMap<I>)
    for player, inputs in pairs(playerInputs) do
        UDPProto_LazyInitPlayer(udpproto, player)
        local lastFrame = frameNull
        for frame, input in pairs(inputs) do
            -- TODO check that there is no conflict between input and what's already in pending output
            if UDPPROTO_NO_QUEUE_NIL_INPUT and input.input == nil then
                Potato(Potato.Info, ctx(udpproto), "UDPProto_OnInput: remote input for player %d frame %d is nil, no need to queue it", player, frame)
            else
                udpproto.playerData[player].pending_output[frame] = input
            end
            lastFrame = math.max(frame, lastFrame)
        end
        udpproto.playerData[player].lastFrame = lastFrame
    end

    -- TODO we would have less redundancy if we could this after we process all the messages in the udp queue
    UDPProto_SendPendingOutput(udpproto)
end

local function UDPProto_SendInputAck<I>(udpproto : UDPProto<I>)
    -- ack the minimum of all the last received inputs for now
    -- TODO ack the sequence number in the future, and the server needs to keep track of seq -> player -> frames sent
    -- or you could ack the exact players/frames too 
    local minFrame = frameNull
    for player, data in pairs(udpproto.playerData) do
        if data.lastFrame < minFrame then
            minFrame = data.lastFrame
        end
    end
    UDPProto_SendMsg(udpproto, { t = "InputAck", frame = minFrame })
end

local function UDPProto_SendQualityReport<I>(udpproto: UDPProto<I>)
    local playerFrameAdvantages = {}
    for player, data in pairs(udpproto.playerData) do
        playerFrameAdvantages[player] = {frame_advantage = data.frame_advantage}
    end
    UDPProto_SendMsg(udpproto, { t = "QualityReport", peer = { frame_advantage = udpproto.local_frame_advantage }, player = playerFrameAdvantages, time = now() })
end

local function UDPProto_GetEvent<I>(udpproto : UDPProto<I>) : GGPOEvent<I>?
    return udpproto.event_queue:dequeue()
end


local function UDPProto_OnLoopPoll<I>(udpproto : UDPProto<I>)
   
    local now = now()
    local next_interval = 0

    -- TODO add some timer stuff here and finish

    -- sync requests (not needed)

    -- send pending output
    --UDPProto_SendPendingOutput(udpproto)

    -- send qulaity report
    --UDPProto_SendQualityReport(udpproto)
    
    -- update nteworkstats
    --UDPProto_UpdateNetworkStats(udpproto)

    -- send keep alive (not needed)

    -- send disconnect notification (omit)
    -- determine self disconnect (omit)
end



local UDP_HEADER_SIZE = 0
local function UDPProto_UpdateNetworkStats<I>(udpproto : UDPProto<I>) 
   local now = now()
   
   if udpproto.stats_start_time == 0 then
      udpproto.stats_start_time = now
   end

   local total_bytes_sent = udpproto.bytes_sent + (UDP_HEADER_SIZE * udpproto.packets_sent)
   local seconds = (now - udpproto.stats_start_time) / 1000
   local bps = total_bytes_sent / seconds;
   local udp_overhead = (100.0 * (UDP_HEADER_SIZE * udpproto.packets_sent) / udpproto.bytes_sent)

   udpproto.kbps_sent = bps / 1024;

   Potato(Potato.Info, ctx(udpproto), "Network Stats -- Bandwidth: %.2f KBps   Packets Sent: %5d (%.2f pps)   KB Sent: %.2f    UDP Overhead: %.2f %%.",
       udpproto.kbps_sent,
       udpproto.packets_sent,
       udpproto.packets_sent * 1000 / (now - udpproto.stats_start_time),
       total_bytes_sent / 1024.0,
       udp_overhead)
end

local function UDPProto_QueueEvent<I>(udpproto : UDPProto<I>, evt : GGPOEvent<I>)
    --Log("Queuing event: %s", evt);
    udpproto.event_queue:enqueue(evt)
end

local function UDPProto_ClearInputsBefore<I>(udpproto : UDPProto<I>, frame : Frame)
    -- remember, the peer will ack the min frame of all inputs they receive for now so it's OK to clear frames for ALL players
    for player, data in pairs(udpproto.playerData) do
        local start = FrameMap_firstFrame(data.pending_output)
        if start ~= frameNull and start <= frame then
            
            for i = start, frame, 1 do
                data.pending_output[i] = nil
            end

            --local keys = debug_tablekeystostring(data.pending_output)
            --Potato(Potato.Debug, ctx(udpproto), "Cleared pending output for player %d from %d to %d, left with keys: %s)", player, start, frame, keys)
        end
    end
end

local function UDPProto_OnInput<I>(udpproto : UDPProto<I>, msg :  UDPMsg_Input<I>) 

    local ds = ""
    for player, data in pairs(msg.inputs) do
        local fs = ""
        for frame, input in pairs(data.inputs) do
            fs = fs .. tostring(frame) .. ","
        end
        ds = ds .. string.format("(%d: %s),", player, fs)
    end
    Potato(Potato.Info, ctx(udpproto), "Received input packet (player, frame count) %s (peer frame: %d, ack: %d)", ds, msg.peerFrame, msg.ack_frame)
    

    local inputs = msg.inputs
    if isempty(inputs)then
        Potato(Potato.Info, ctx(udpproto), "UDPProto_OnInput: Received empty msg")
        return
    end

    for player, _ in pairs(inputs) do
        UDPProto_LazyInitPlayer(udpproto, player)
    end

    -- now fill in empty inputs from udpproto.playerData[player].lastFrame+1 to msg.inputs[player].lastFrame because they get omitted for performance if they were nil
    Tomato(ctx(udpproto), inputs[udpproto.player] ~= nil, "expected to receive inputs for peer") -- (need to add player to subscribe callback to do this)
    for player, data in pairs(inputs) do
        for i = udpproto.playerData[player].lastFrame+1, data.lastFrame, 1 do
            if data.inputs[i] == nil then
                Eggplant(ctx(udpproto), UDPPROTO_NO_QUEUE_NIL_INPUT, "nil inputs should only be possible if UDPPROTO_NO_QUEUE_NIL_INPUT is true") 
                Potato(Potato.Info, ctx(udpproto), "did not receive inputs for player %d frame %d assume their inputs are nil", player, i)
                data.inputs[i] = GameInput_new(i, nil)
            end
        end
    end

    -- update the last frame  
    udpproto.lastReceivedFrame = msg.peerFrame
    for player, data in pairs(inputs) do
        udpproto.playerData[player].lastFrame = data.lastFrame
    end

    UDPProto_SendInputAck(udpproto)

    udpproto.lastAckedFrame = msg.ack_frame
    UDPProto_ClearInputsBefore(udpproto, msg.ack_frame)


    -- pass the event up
    -- TODO I tried to just delete data.lastFrame but that wasn't enough to make the luau typechecker happy :(
    local inputs2 = {}
    for player, data in pairs(inputs) do
        if not isempty(data.inputs) then
            inputs2[player] = data.inputs
        end
    end
    UDPProto_QueueEvent(udpproto, {t = "input", input = inputs2})

end

local function UDPProto_OnInputAck<I>(udpproto : UDPProto<I>, msg : UDPPeerMsg_InputAck) 
    udpproto.lastAckedFrame = msg.frame
    UDPProto_ClearInputsBefore(udpproto, msg.frame)
end


local function UDPProto_OnPing<I>(udpproto : UDPProto<I>, msg : UDPPeerMsg_Ping) 
    UDPProto_SendMsg(udpproto, { t = "Pong", time = msg.time })
end

local function UDPProto_OnPong<I>(udpproto : UDPProto<I>, msg : UDPPeerMsg_Pong) 
    -- TODO maybe rolling average this?
    udpproto.round_trip_time = now() - msg.time
end

local function UDPProto_OnQualityReport<I>(udpproto : UDPProto<I>, msg : UDPMsg_QualityReport) 
    udpproto.remote_frame_advantage = msg.peer.frame_advantage
    for player, data in pairs(msg.player) do
        local pd = UDPProto_LazyInitPlayer(udpproto, player)
        pd.frame_advantage = data.frame_advantage
    end

    UDPProto_SendMsg(udpproto, { t = "Pong", time = msg.time })
end

-- non local function so it can be called in ctor (just for syntactic niceness)
function UDPProto_OnMsg<I>(udpproto : UDPProto<I>, msg : UDPMsg<I>) 

    --filter out out-of-order packets
    local skipped = msg.seq - udpproto.next_recv_seq
    if skipped > UDPPROTO_MAX_SEQ_DISTANCE then
        Potato(Potato.Warn, ctx(udpproto), "Dropping out of order packet (seq: %d, last seq: %d)", msg.seq, udpproto.next_recv_seq)
        return
    end

    udpproto.next_recv_seq = msg.seq;
    --Potato(Potato.Debug, ctx(udpproto), "recv %s", msg)

    if msg.m.t == "Ping" then
        UDPProto_OnPing(udpproto, msg.m)
    elseif msg.m.t == "Pong" then
        UDPProto_OnPong(udpproto, msg.m)
    elseif msg.m.t == "InputAck" then
        UDPProto_OnInputAck(udpproto, msg.m)
    elseif msg.m.t == "Input" then
        UDPProto_OnInput(udpproto, msg.m)
    elseif msg.m.t == "QualityReport" then
        UDPProto_OnQualityReport(udpproto, msg.m)
    else
        Potato(Potato.Info, ctx(udpproto), "Unknown message type: %s", msg.m.t)
    end

    -- TODO resume if disconnected
    --_last_recv_time = Platform::GetCurrentTimeMS();
end

local function UDPProto_GetNetworkStats<I>(udpproto : UDPProto<I>) : UDPNetworkStats

    local maxQueueLength = 0
    for player, data in pairs(udpproto.playerData) do
        if tablecount(data.pending_output) > maxQueueLength then
            maxQueueLength = tablecount(data.pending_output)
        end
    end
    
    local s = {
        max_send_queue_len = maxQueueLength,
        ping = udpproto.round_trip_time,
        kbps_sent = udpproto.kbps_sent,
        local_frames_behind = udpproto.local_frame_advantage,
        remote_frames_behind = udpproto.remote_frame_advantage,
    }

    return s
end
   
-- set the current local frame number so that we can update our frame advantage computation
local function UDPProto_SetLocalFrameNumber<I>(udpproto : UDPProto<I>, localFrame : number)
    -- TODO I think this computation is incorrect, I think it should actually be
    --local remoteFrame = udpproto.lastReceivedFrame + (udpproto.round_trip_time / 2 + msSinceLastReceivedFrame) / udpproto.msPerFrame 
    local remoteFrame = udpproto.lastReceivedFrame + udpproto.round_trip_time / udpproto.msPerFrame / 2
    udpproto.local_frame_advantage = remoteFrame - localFrame
end
   
local function UDPProto_RecommendFrameDelay<I>(udpproto : UDPProto<I>) : number
    -- TODO
   --// XXX: require idle input should be a configuration parameter
   --return _timesync.recommend_frame_wait_duration(false);
   return 0
end







-- GGPO_Peer
-- T: game state type
-- I: player input type
export type GGPO_Peer<T,I> = {
    
    gameConfig : GameConfig<I>,
    callbacks : GGPOCallbacks<T,I>,
    sync : Sync<T,I>,
    udps : { [PlayerHandle] : UDPProto<I> },
    spectators : { [number] : UDPProto<I> },
    player : PlayerHandle, -- TODO maybe rename to owner
    isProxy : boolean,
    next_recommended_sleep : FrameCount,

    potato : (GGPO_Peer<T,I>, PotatoVerbosity) -> string,
    potato_severity : number,
}

local function GGPO_Peer_new<T,I>(gameConfig : GameConfig<I>, callbacks : GGPOCallbacks<T,I>, player : PlayerHandle) : GGPO_Peer<T,I>
    local r = {
        gameConfig = gameConfig,
        callbacks = callbacks,
        sync = Sync_new(gameConfig, callbacks, player, gameConfig.maxPredictionFrames),
        udps = {},
        spectators = {},
        player = player,
        isProxy = player == carsHandle,
        next_recommended_sleep = 0,

        potato = function(self : GGPO_Peer<T,I>, verbosity : PotatoVerbosity)
            return string.format("GGPO_Peer: player: %d", self.player)
        end,
        potato_severity = Potato.Warn,
        
    }
    return r
end



local function GGPO_Peer_AddSpectator<T,I>(peer : GGPO_Peer<T,I>, endpoint: UDPEndpoint<I>)
    error("not implemented")
    --peer.spectators[tablecount(peer.spectators)] = UDPProto_new({ player = spectatorHandle, proxy = {}, endpoint = endpoint })
end


-- NOTE this is only for setting up our peers, not the game!
-- in particular, if CARS this is called for all peers on the server
-- and called for just the server on each peer
local function GGPO_Peer_AddPeer<T,I>(peer : GGPO_Peer<T,I>, player : PlayerHandle, endpoint : UDPEndpoint<I>)

    if player == spectatorHandle then
        GGPO_Peer_AddSpectator(peer, endpoint)
        return
    end

    assert(peer.udps[player] == nil, "expected peer to not already exist")
    peer.udps[player] = UDPProto_new(peer.player, player, endpoint)

    -- TODO init peer in Sync

    if peer.isProxy then
        Tomato(ctx(peer), peer.sync.framecount == frameInit, "adding peers after frameInit not supported")
        -- TODO send most recently synced state to newly added peer
        -- TODO send all inputs since synced state to newly added peer
    end
end

local function GGPO_Peer_GetStats<T,I>(peer : GGPO_Peer<T,I>) : {[PlayerHandle] : UDPNetworkStats}
    local r = {}
    for player, udp in pairs(peer.udps) do
        r[player] = UDPProto_GetNetworkStats(udp)
    end
    return r
end

local function GGPO_Peer_SetFrameDelay<T,I>(peer : GGPO_Peer<T,I>, delay : FrameCount) 
    Sync_SetFrameDelay(peer.sync, peer.player, delay)
end

local function GGPO_Peer_SynchronizeInput<T,I>(peer : GGPO_Peer<T,I>, frame : Frame) : PlayerInputMap<I>
    Tomato(ctx(peer,nil,10), frame == peer.sync.framecount, "expected peer.sync.framecount %d to match requested frame %d", peer.sync.framecount, frame)
    return Sync_SynchronizeInputs(peer.sync)
end

local function GGPO_Peer_OnUdpProtocolEvent<T,I>(peer : GGPO_Peer<T,I>, event : GGPOEvent<I>, player : PlayerHandle)
    -- TODO
    --peer.callbacks.OnPeerEvent(evt, player)
end


local function GGPO_Peer_OnUdpProtocolPeerEvent<T,I>(peer : GGPO_Peer<T,I>, event : GGPOEvent<I>, sender : PlayerHandle)
    GGPO_Peer_OnUdpProtocolEvent(peer, event, sender)
    if event.t == "input" then
        for player, inputs in pairs(event.input) do
            
            -- TODO maybe make this more efficient...
            -- iterate through the frame in order and add them to sync
            local first = FrameMap_firstFrame(inputs)
            local last = FrameMap_lastFrame(inputs)

            print(tostring(peer.player) .. " GOT INPUTS FOR PLAYER " .. tostring(player) .. " FRAME: " .. tostring(first) .. " TO " .. tostring(last))

            -- you can allow this, but upstream should not be sending inputs for empty players
            Eggplant(ctx(peer), first ~= frameNull, "expected there to be inputs for player " .. tostring(player))

            if first ~= frameNull then
                for frame = first, last , 1 do
                    local input = inputs[frame]
                    assert(input ~= nil, "expected input to not be nil for frame:" .. tostring(frame))
                    Sync_AddRemoteInput(peer.sync, player, input)
                end
            end

            -- add the input to pending output for each of our peers
            if peer.isProxy then
                for _, udpproto in pairs(peer.udps) do

                    
                    -- don't replicate events back to the player who sent them to us
                    -- NOTE this is redundant to the one in UDPProto_SendPendingOutput
                    if udpproto.player ~= sender then
                        Eggplant(ctx(peer), udpproto.player ~= player, "expected sender %d not to send inputs for udpproto.player %d", sender, udpproto.player)
                        UDPProto_AddToPendingOutput(udpproto, event.input)
                    end
                end
            end

        end
    end


end


local function GGPO_Peer_OnUdpProtocolSpectatorEvent<T,I>(peer : GGPO_Peer<T,I>, event : GGPOEvent<I>, spectator : number)
    -- TODO
    --peer.callbacks.OnSpectatorEvent(evt, i)
end

local function GGPO_Peer_PollUdpProtocolEvents<T,I>(peer : GGPO_Peer<T,I>)
    for player, udp in pairs(peer.udps) do
        local evt = UDPProto_GetEvent(udp)
        while evt ~= nil do
            GGPO_Peer_OnUdpProtocolPeerEvent(peer, evt, player)
            evt = UDPProto_GetEvent(udp)
        end
    end
    for i, udp in pairs(peer.spectators) do
        local evt = UDPProto_GetEvent(udp)
        while evt ~= nil do
            GGPO_Peer_OnUdpProtocolSpectatorEvent(peer, evt, i)
            evt = UDPProto_GetEvent(udp)
        end
    end
end

local function GGPO_Peer_DoPoll<T,I>(peer : GGPO_Peer<T,I>)

    assert(not peer.sync.rollingback, "do not poll during rollback!")

    for player, udp in pairs(peer.udps) do
        UDPProto_OnLoopPoll(udp)
    end

    GGPO_Peer_PollUdpProtocolEvents(peer)

    --if (!_synchronizing) {

    -- do rollback if needed
    local rollback_frame = Sync_CheckSimulation(peer.sync)

    -- TODO should be ok to uncomment?
    --if peer.udps[carsHandle] then
        -- we should never rollback past the last received frame from cars (which is authoritative)
        -- TODO note that subscribe calls are asynchronous so the below may fail if the script has yielded since the last time we polled for events and updated Sync 
        -- WAIT no, I think this is ok, because we polled just earlier in this function so it should not have yielded between then and now.
        --assert(rollback_frame >= peer.udps[carsHandle].lastReceivedFrame )
    --end

    local current_frame = peer.sync.framecount
    for player, udp in pairs(peer.udps) do
        UDPProto_SetLocalFrameNumber(udp, current_frame)
    end

    -- we are on current_frame which means we still need the input for current_frame
    local total_min_confirmed = current_frame - 1

    for player, udp in pairs(peer.udps) do

        -- TODO this won't always work due to lazy init. If we have a lazy init player, we won't have a lastFrame for them in the map, and we will confirm past their frames which is bad :(
        local lastSyncFrame = UDPProto_lastSynchronizedFrame(udp)

        -- TODO NOTE this is different than original GGPO in P2P case, in original GGPO, the peer has the  last received frame and connected status for all peers connected to player (N^2 pieces of data)
        -- and takes the min of all those. I don't quite know why it does this at all, doing just one hop here seems sufficient/better. I guess because we might be disconnected to the peer so we rely on relayed information to get the last frame?
        total_min_confirmed = math.min(lastSyncFrame, total_min_confirmed)
    end

    Potato(Potato.Warn, ctx(peer), "setting last confirmed frame to: %d", total_min_confirmed)
    Sync_SetLastConfirmedFrame(peer.sync, total_min_confirmed)

end

-- ggpo_advance_frame
local function GGPO_Peer_AdvanceFrame<T,I>(peer : GGPO_Peer<T,I>, frame)
    Sync_IncrementFrame(peer.sync)
    Tomato(ctx(peer), peer.sync.framecount == frame, "expected peer.sync.framecount %d to be frame %d after advancing", peer.sync.framecount, frame)

    if not Sync_InRollback(peer.sync) then
        GGPO_Peer_DoPoll(peer)
    end 
end


-- returns nil if input was dropped for whatever reason
-- returns the added input with frame adjusted for frame delay
-- TODO return an error code instead
local function GGPO_Peer_AddLocalInput<T,I>(peer : GGPO_Peer<T,I>, input: GameInput<I>) : GameInput<I>?
    assert(not peer.sync.rollingback, "do not add inputs during rollback!")
    
    -- TODO assert no inputs send during synchronization

    local outinput = Sync_AddLocalInput(peer.sync, peer.player, input)

    -- input got rejected due to being too far ahead (common) or already in the queue (uncommon).
    if not outinput then
        return nil
    end

    -- input dropped due to frame delay shenanigans
    if input.frame == frameNull then
        return nil
    else
        for _, udp in pairs(peer.udps) do 
            UDPProto_SendOwnerInput(udp, input)
        end
    end

    return outinput
end

-- Called only as the result of a local decision to disconnect
-- if peers is CARS then this decision is authoritatively sent to all peers
-- otherwise, there will probably be a desync 
-- TODO figure out how this was intended to be used in original GGPO in p2p case
local function GGPO_Peer_DisconnectPlayer<T,I>(peer : GGPO_Peer<T,I>, player : PlayerHandle)
    -- TODO
    error("not implemented")
end




return {
    now = now,

    -- constants
    frameInit = frameInit,
    frameNull = frameNull,
    frameMax = frameMax,
    frameNegOne = frameNegOne,
    defaultGameConfig = defaultGameConfig,
    carsHandle = carsHandle,
    spectatorHandle = spectatorHandle,
    nullHandle = nullHandle,

    -- helpers exposed for testing
    isempty = isempty,
    tablecount = tablecount,

    -- exposed for testing
    FrameMap_lastFrame = FrameMap_lastFrame,
    FrameMap_firstFrame = FrameMap_firstFrame,

    UDPMsg_potato = UDPMsg_potato,

    -- UDPProto stuff 
    -- exposed for testing
    uselessUDPEndpoint = uselessUDPEndpoint,
    UDPProto_Player_new = UDPProto_Player_new,
    UDPProto_ClearInputsBefore = UDPProto_ClearInputsBefore,
    UDPProto_new = UDPProto_new,

    GameInput_new = GameInput_new,
    GGPO_Peer_new = GGPO_Peer_new,
    GGPO_Peer_AddPeer = GGPO_Peer_AddPeer,
    GGPO_Peer_AddSpectator = GGPO_Peer_AddSpectator,
    GGPO_Peer_GetStats = GGPO_Peer_GetStats,
    GGPO_Peer_SetFrameDelay = GGPO_Peer_SetFrameDelay,
    GGPO_Peer_SynchronizeInput = GGPO_Peer_SynchronizeInput,
    GGPO_Peer_AdvanceFrame = GGPO_Peer_AdvanceFrame,
    GGPO_Peer_AddLocalInput = GGPO_Peer_AddLocalInput,
    GGPO_Peer_DoPoll = GGPO_Peer_DoPoll,
    GGPO_Peer_DisconnectPlayer = GGPO_Peer_DisconnectPlayer,
}