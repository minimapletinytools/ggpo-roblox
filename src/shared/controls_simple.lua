-- simple controls for a ggpo game. You will likely want to replace this with your own.

export type SimpleControls = {
  left : boolean,
  right : boolean,
  up : boolean,
  down : boolean,
  a : boolean,
  b : boolean,
  x : boolean,
  y : boolean,
}

local function SimpleControls_new() : SimpleControls
  return {
    left = false,
    right = false,
    up = false,
    down = false,
    a = false,
    b = false,
    x = false,
    y = false,
  }
end

export type SimpleControlsManager = {
    staging_controls : SimpleControls,
}

local function SimpleControlsManager_new() : SimpleControlsManager

    local UserInputService = game:GetService("UserInputService")
    local staging_controls = SimpleControls_new()

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then
            return
        end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Left then
                staging_controls.left = true
            elseif input.KeyCode == Enum.KeyCode.Right then
                staging_controls.right = true
            elseif input.KeyCode == Enum.KeyCode.Up then
                staging_controls.up = true
            elseif input.KeyCode == Enum.KeyCode.Down then
                staging_controls.down = true
            elseif input.KeyCode == Enum.KeyCode.A then
                staging_controls.a = true
            elseif input.KeyCode == Enum.KeyCode.B then
                staging_controls.b = true
            elseif input.KeyCode == Enum.KeyCode.X then
                staging_controls.x = true
            elseif input.KeyCode == Enum.KeyCode.Y then
                staging_controls.y = true
            end
        end
    end)

    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.UserInputType == Enum.UserInputType.Keyboard then
            if input.KeyCode == Enum.KeyCode.Left then
                staging_controls.left = false
            elseif input.KeyCode == Enum.KeyCode.Right then
                staging_controls.right = false
            elseif input.KeyCode == Enum.KeyCode.Up then
                staging_controls.up = false
            elseif input.KeyCode == Enum.KeyCode.Down then
                staging_controls.down = false
            elseif input.KeyCode == Enum.KeyCode.A then
                staging_controls.a = false
            elseif input.KeyCode == Enum.KeyCode.B then
                staging_controls.b = false
            elseif input.KeyCode == Enum.KeyCode.X then
                staging_controls.x = false
            elseif input.KeyCode == Enum.KeyCode.Y then
                staging_controls.y = false  
            end
        end
    end)

    return {
        staging_controls = staging_controls
    }
end


local function SimpleControlsManager_getInputs(scm : SimpleControlsManager) : SimpleControls

    -- make a copy of the controls
    local controls = SimpleControls_new()
    controls.left = scm.staging_controls.left
    controls.right = scm.staging_controls.right
    controls.up = scm.staging_controls.up
    controls.down = scm.staging_controls.down
    controls.a = scm.staging_controls.a
    controls.b = scm.staging_controls.b
    controls.x = scm.staging_controls.x
    controls.y = scm.staging_controls.y
    
    return controls
end


return {
    SimpleControls_new = SimpleControls_new,
    SimpleControlsManager_new = SimpleControlsManager_new,
    SimpleControlsManager_getInputs = SimpleControlsManager_getInputs,
}