-- moments
-- 
-- moments that once were
-- 


m_dots = include 'lib/m_dots'


function init()
  m_dots.build_params()
  m_dots.init()
end

function redraw()
  screen.aa(0)

  local p = nil
  local baseline_y = 30

  -- baseline
  screen.move(14, baseline_y)
  screen.line(114, baseline_y)

  -- voice position (above or below line)
  for i=1,4 do
    p = m_dots.positions[i]
    p = util.linlin(0, params:get('dots_loop_length'), 14, 114, p)

    screen.move(p, baseline_y)
    lr = i % 2 == 0 and 1 or -1

    if i < 3 then
      screen.line_rel(0, 12 * lr)
    else
      screen.move_rel(0, 6 * lr)
      screen.text('.')
    end
  end

  screen.stroke()
end

function key(n,z)
  if n == 3 and z == 1 then
    if m_dots.moving then
      m_dots:stop()
    else
      m_dots:start()
    end
  end
end

function enc(n,d)
  print('dots encoder')
end