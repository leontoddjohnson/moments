-- all the basic grid operations (?)
-- redraw thing?

-- navigate on grid --> navigate on norns
-- navigate on norns --> grid remains static
-- all screen pages (except dots) correspond to grid pages
-- add dots to the end, maybe with a | separator from the rest

local m_grid = {}

g = grid.connect()  -- requires 8x16 grid

g_brightness = {
  situation = 0
}

-- keys held [y][x] or [row][col]
-- 1 == held and 0 == not held
KEY_HOLD = {}

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function m_grid.init()

  -- key_hold map
  for r = 1,8 do
    KEY_HOLD[r] = {}
    for c = 1,16 do
      KEY_HOLD[r][c] = 0
    end
  end

end

return m_grid