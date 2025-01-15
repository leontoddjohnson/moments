-- all the basic grid operations (?)
-- redraw thing?

-- navigate on grid --> navigate on norns
-- navigate on norns --> grid remains static
-- all screen pages (except dots) correspond to grid pages
-- add dots to the end, maybe with a | separator from the rest

local m_grid = {}

g = grid.connect()  -- requires 8x16 grid

g_brightness = {
  level_met = 8,
  level_not_met = 3
}

options = {}
options.level = {1/8, 2/8, 3/8, 4/8, 5/8, 6/8, 7/8, 1}
options.pan = {-1, -0.75, -0.5, -0.25, 0.25, 0.5, 0.75, 1}
options.rate = {0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4}
options.time = {8, 7, 6, 5, 4, 3, 2, 1}

REVERSE = false


-- ========================================================================== --
-- LEVELS
-- ========================================================================== --

function m_grid.draw_levels()
  for y = 1,4 do
    for i = 1,8 do
      p = 'dot_' .. y .. '_level'

      if params:get(p) >= options.level[i] - 0.0001 then
        g:led(i, y, g_brightness.level_met)
      else
        g:led(i, y, g_brightness.level_not_met)
      end

    end
  end

end


function m_grid.key_levels(x, y, z)

  set_param(x, y, 'level')

end


-- ========================================================================== --
-- PAN
-- ========================================================================== --

function m_grid.draw_pan()
  local dot

  for y=5,8 do
    dot = y - 4
    for i=1,8 do
      p = 'dot_' .. dot .. '_pan'

      if params:get(p) > 0 and i >= 5 then
        if params:get(p) >= options.pan[i] then
          g:led(i, y, g_brightness.level_met)
        end
      elseif params:get(p) < 0 and i <= 4 then
        if params:get(p) <= options.pan[i] then
          g:led(i, y, g_brightness.level_met)
        end
      end

    end
  end

end


function m_grid.key_pan(x, y, z)

  set_param(x, y - 4, 'pan')

end


-- ========================================================================== --
-- TIME
-- ========================================================================== --

function m_grid.draw_time()
end


function m_grid.key_time(x, y, z)
end


-- ========================================================================== --
-- RATE
-- ========================================================================== --

function m_grid.draw_rate()
end


function m_grid.key_rate(x, y, z)
end


-- ========================================================================== --
-- GRID FUNCTIONS
-- ========================================================================== --

function m_grid:grid_redraw()
  g:all(0)

  m_grid.draw_levels()  -- upper left
  m_grid.draw_pan()     -- lower left
  m_grid.draw_time()    -- upper right
  m_grid.draw_rate()    -- lower right

  g:refresh()
end


function g.key(x, y, z)

  -- simple, only down encoding
  if z == 1 then
    if x < 9 and y < 5 then
      m_grid.key_levels(x, y, z)
    elseif x < 9 and y >= 5 then
      m_grid.key_pan(x, y, z)
    elseif x >= 9 and y < 5 then
      m_grid.key_time(x, y, z)
    else
      m_grid.key_rate(x, y, z)
    end
  end

  grid_dirty = true

end


-- ========================================================================== --
-- UTILITY
-- ========================================================================== --

-- **horizontal selector**
-- set `dot` param value to the `x`th of `options`, where `x` == 1 indicates the
-- first option. If selecting an already set value, set parameter to `zero`.
-- `param` is the string to go after "dot_*_". E.g., `param` = "level" is valid
-- Default for `zero` is 0.
function set_param(x, dot, param, zero)
  zero = zero or 0
  local v = options[param][x]

  -- when selecting current value, set to 0
  if params:get('dot_' .. dot .. '_' .. param) == v then
    params:set('dot_' .. dot .. '_' .. param, zero)
  else
    params:set('dot_' .. dot .. '_' .. param, v)
  end

end

-- return index of value in table
function index_of(array, value)
  for i, v in ipairs(array) do
      if v == value then
          return i
      end
  end
  return nil
end

return m_grid