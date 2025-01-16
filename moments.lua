-- moments
-- 
-- moments that once were
-- 
-- K2/K3: toggle dots
-- E2/E3: adjust loop length
--

m_dots = include 'lib/m_dots'
m_grid = include 'lib/m_grid'

REDRAW_FRAMERATE = 30

-----------------------------------------------------------------
-- INIT
-----------------------------------------------------------------

function init()
  m_dots.build_params()
  m_dots.init()

  -- redraw clock
  screen_dirty = true
  grid_dirty = true
  clock.run(redraw_clock)
end

-----------------------------------------------------------------
-- UI
-----------------------------------------------------------------

function redraw()
  screen.clear()
  screen.aa(0)

  local p = nil
  local baseline_y = 30
  local dot_buffer = 6

  screen.move(64, 10)
  if m_dots.moving then
    screen.text_center('•')
  else
    screen.text_center('----')
  end

  -- baseline
  screen.move(14, baseline_y)
  screen.line(114, baseline_y)

  -- voice position (above or below line)
  for i=1,6 do
    p = m_dots.positions[i]
    p = util.linlin(0, params:get('loop_length'), 14, 114, p)

    screen.move(p, baseline_y)
    lr = i % 2 == 0 and 1 or -1

    if i < 3 then
      screen.line_rel(0, 12 * lr)
    -- dots 1 and 4
    elseif i == 3 or i == 6 then
      screen.move_rel(0, lr * 2 * dot_buffer)  -- 1 is l (top), 4 is r (btm)
      screen.text('.')
    -- dots 2 and 3
    else
      screen.move_rel(0, -lr * dot_buffer)  -- 2 is l (top), 3 is r (btm)
      screen.text('.')
    end
  end

  screen.stroke()

  screen.move(14, 60)
  screen.text("loop length:")

  screen.move(114, 60)
  screen.text_right(params:string('loop_length'))

  screen.update()
end

function key(n,z)
  if (n == 3 or n == 2) and z == 1 then
    if m_dots.moving then
      m_dots:stop()
    else
      m_dots:start()
    end
    screen_dirty = true
  end
end

function enc(n,d)
  if n > 1 then
    params:delta('loop_length', d)
  end
end

function redraw_clock()
  while true do
    clock.sleep(1/REDRAW_FRAMERATE)
    
    if screen_dirty then
      redraw()
      screen_dirty = false
    end

    if grid_dirty then
      m_grid:grid_redraw()
      grid_dirty = false
    end

  end
end

-----------------------------------------------------------------
-- DATA
-----------------------------------------------------------------

function manage_data()

  -- save
  params.action_write = function(filename,name,number)
    print("finished writing '"..filename.."' as '"..name.."'", number)
    os.execute("mkdir -p "..norns.state.data.."/"..number.."/")

    tab.save(m_dots, norns.state.data.."/"..number.."/dots.data")

  end

  -- load
  params.action_read = function(filename,silent,number)
    print("finished reading '"..filename.."'", number)

    m_dots = tab.load(norns.state.data.."/"..number.."/dots.data")
    
  end

  -- delete
  params.action_delete = function(filename,name,number)
    print("finished deleting '"..filename, number)
    norns.system_cmd("rm -r "..norns.state.data.."/"..number.."/")
  end

end