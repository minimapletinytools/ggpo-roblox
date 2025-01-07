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

return {
  SimpleControls_new = SimpleControls_new,
}