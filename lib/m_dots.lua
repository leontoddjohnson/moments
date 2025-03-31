-- dots effect

local m_dots = {}

-- max loop length for dots
local MAX_LENGTH = 15

-- [1-2] == rec, [3-6] == dots
m_dots.positions = {0, 0, MAX_LENGTH, MAX_LENGTH, MAX_LENGTH, MAX_LENGTH}
m_dots.moving = false

-- clocks set for each dot, [1] - [4]
m_dots.clocks = {}

-- boolean value for whether input (L/R) is making sound above threshold
m_dots.input_sound = {false, false}

-----------------------------------------------------------------
-- PARAMETERS
-----------------------------------------------------------------

amp_l = 0
amp_r = 0

function m_dots.build_params()

  spec_amp_thresh = controlspec.new(0.001, 0.5, 'lin', 0, 0.1, '', 0.01, false)
  spec_check_time = controlspec.new(0.1, 2, 'lin', 0.1, 0.5, 's', 0.1)
  spec_slew_time = controlspec.new(0, 1, 'lin', 0.01, 0, 's', 0.1)
  spec_amp_1 = controlspec.new(0, 1, 'lin', 0, 1, '', 0.01)

  -- total buffer loop length
  params:add_number('loop_length', 'loop length', 1, MAX_LENGTH, 5,
    function(p) return p:get() .. ' s' end)
  params:set_action('loop_length',
  function (x)
    softcut.loop_end(1, x)
    softcut.loop_end(2, x)
    screen_dirty = true
  end)

  -- overdub level for input
  params:add_control('loop_preserve_level', 'loop preserve level',
    controlspec.AMP)
  params:set_action('loop_preserve_level',
  function (x)
    for i=1,2 do
      softcut.pre_level(i, x)
    end
  end)

  -- slew time for dot jumps
  params:add_control('rate_slew_time', 'rate slew time', spec_slew_time)
  params:set_action('rate_slew_time',
  function (t)
    for i=3,6 do
      softcut.rate_slew_time(i, t)
    end
  end)

  -- time between input amplitude checks
  params:add_control('check_time_l', 'check time left', spec_check_time)
  params:set_action('check_time_l', function (x) poll_amp_l.time = x end)
  params:add_control('check_time_r', 'check time right', spec_check_time)
  params:set_action('check_time_r', function (x) poll_amp_r.time = x end)

  -- amplitude thresholds
  params:add_control('amp_threshold_l', 'amp threshold left', spec_amp_thresh, 
        function(p) return util.round(ampdb(p:get()), 1) .. ' db' end)
  params:add_control('amp_threshold_r', 'amp threshold right', spec_amp_thresh, 
        function(p) return util.round(ampdb(p:get()), 1) .. ' db' end)


  -- dot parameters --------------------------------------------------------- --
  params:add_group('dots', 'dots', 4 * 5)
  for i = 1,4 do 
    -- synchronized time between dot jumps
    params:add_number('dot_'.. i .. '_move_frac',
      'dot '.. i .. ' move fraction', 1, 8, 1, 
      function(p) 
        if p:get() == 1 then s = "1" else s = "1/"..p:get() end
        grid_dirty = true
        return s
      end)

    -- dot level
    params:add_control('dot_'.. i .. '_level', 'dot '.. i .. ' level',
      spec_amp_1)
    params:set_action('dot_'.. i .. '_level', 
      function(x)
        softcut.level(i + 2, x)  -- dots start at voice 3
        grid_dirty = true
    end)

    -- dot rate
    params:add_number('dot_'.. i .. '_rate', 'dot ' .. i .. ' rate',
      -24, 24, 0, function(p) return p:get() .. ' st' end)
    params:set_action('dot_'.. i .. '_rate', 
      function(x)
        local r = music.interval_to_ratio(x)
        local d = params:get('dot_' .. i .. '_direction')

        -- forward or reverse
        r = d == 1 and r or -r
        softcut.rate(i + 2, r)
        grid_dirty = true
    end)

    -- dot direction
    params:add_option('dot_'.. i .. '_direction', 'dot '.. i .. ' direction', 
      {'forward', 'reverse'}, 1)
    params:set_action('dot_'.. i .. '_direction',
      function(x)
        local transpose = params:get('dot_' .. i .. '_rate')
        local r = music.interval_to_ratio(transpose)
        
        if x == 1 then
          softcut.rate(i + 2, r)
        else
          softcut.rate(i + 2, -r)
        end

        grid_dirty = true
      end)

    -- dot pan
    params:add_control('dot_'.. i .. '_pan', 'dot ' .. i .. ' pan', 
      controlspec.PAN)
    params:set_action('dot_'.. i .. '_pan', 
      function(x)
        softcut.pan(i + 2, x)  -- dots start at voice 3
        grid_dirty = true
    end)
    
  end

  -- input type
  params:add_option('input_type', 'input type', {'mono', 'stereo'}, 2)
  params:set_action('input_type',
    function(x)
      for i = 1,6 do
        if i < 3 then
          if x == 1 then
            -- when mono, only record to left buffer
            softcut.buffer(i, 1)
          else
            -- otherwise, use both
            softcut.buffer(i, i)
          end
        else
          if x == 1 then
            -- when mono, only read from left buffer
            softcut.buffer(i, 1)
            softcut.pan(i, 0)
          else
            -- otherwise, send dots 1 and 2 to left, and 3 and 4 to right
            softcut.buffer(i, i < 5 and 1 or 2)
            softcut.pan(i, i < 5 and -1 or 1)
          end
        end
      end
    end
)

end

-- ========================================================================== --
-- INIT
-- ========================================================================== --

function m_dots.init()
  -- input level
  audio.level_adc_cut(1)

  -- track amplitude
  poll_amp_l = poll.set("amp_in_l", update_amp_l)
  poll_amp_l.time = params:get('check_time_l')

  poll_amp_r = poll.set("amp_in_r", update_amp_r)
  poll_amp_r.time = params:get('check_time_r')

end

-----------------------------------------------------------------
-- UTILITY
-----------------------------------------------------------------

-- start all dots
function m_dots:start()
  self.input_poll(true)
  self.sc_start()

  for i = 1,4 do
    m_dots.clocks[i] = clock.run(m_dots.move_dot, i)
  end

  self.moving = true
end

-- stop all dots
function m_dots:stop()
  self.sc_stop()
  self.input_poll(false)

  for i = 1,4 do
    clock.cancel(m_dots.clocks[i])
  end

  self.moving = false
  screen_dirty = true
end

function m_dots.input_poll(start)
  if start then
    poll_amp_l:start()
    poll_amp_r:start()
  else
    poll_amp_l:stop()
    poll_amp_r:stop()
  end
end

function m_dots.sc_stop()
  for i=1,6 do
    softcut.rec(i, 0)
    softcut.play(i, 0)
    softcut.enable(i, 0)

    -- input
    if i < 3 then
      softcut.position(i, 0)
      m_dots.positions[i] = 0

    -- dots
    else
      softcut.position(i, params:get('loop_length'))
      m_dots.positions[i] = params:get('loop_length')
    end
  end

  softcut.poll_stop_phase()
  softcut.buffer_clear()
end

function m_dots.sc_start()
  softcut.buffer_clear()

  for i=1,6 do
    -- init for all
    softcut.enable(i, 1)
    softcut.loop(i, 1)
    softcut.rate(i, 1)
    softcut.fade_time(i, 0.1)
    softcut.loop_start(i, 0)
    softcut.loop_end(i, params:get('loop_length'))

    -- watch position
    softcut.phase_quant(i, 1 / REDRAW_FRAMERATE)

    -- input
    if i < 3 then
      if params:get('input_type') == 1 then
        -- when mono, only record to left buffer
        softcut.buffer(i, 1)
      else
        -- otherwise, use both
        softcut.buffer(i, i)
      end

      softcut.position(i, 0)
      softcut.rec_level(i, 1)
      softcut.pre_level(i, 0)
      softcut.level_input_cut(i, i, 1)
      softcut.level(i, 0)
      softcut.play(i, 1)
      softcut.rec(i, 1)

    -- dots
    else
      if params:get('input_type') == 1 then
        -- when mono, only read from left buffer
        softcut.buffer(i, 1)
        softcut.pan(i, 0)
      else
        -- otherwise, send dots 1 and 2 to left, and 3 and 4 to right
        softcut.buffer(i, i < 5 and 1 or 2)
        softcut.pan(i, i < 5 and -1 or 1)
      end

      softcut.play(i, 0)
      softcut.level(i, params:get('dot_' .. i - 2 .. '_level'))
      softcut.position(i, params:get('loop_length'))
      m_dots.positions[i] = params:get('loop_length')
    end

  end

  softcut.event_phase(m_dots.update_position)
  softcut.poll_start_phase()
end

-- move an individual dot `dot` (1-4) for play somewhere ..
function m_dots.move_dot(dot)
  while true do
    clock.sync(1 / params:get('dot_' .. dot .. '_move_frac'))

    -- choose a dot start location somewhere in the loop (with buffer)
    local p = math.random() * (params:get('loop_length'))
    local sound

    if params:get('input_type') == 1 then
      -- mono
      sound = m_dots.input_sound[1] or m_dots.input_sound[2]
    else
      -- stereo
      i = dot < 5 and 1 or 2  -- first two dots are left
      sound = m_dots.input_sound[i]
    end

    if sound then
      softcut.position(dot + 2, p)
      softcut.loop(dot + 2, 1)
      softcut.play(dot + 2, 1)
    else
      softcut.loop(dot + 2, 0)
    end

    screen_dirty = true
  end
end

function m_dots.update_position(i,pos)
  softcut.loop_end(i, params:get('loop_length'))
  m_dots.positions[i] = pos
  screen_dirty = true
end

function update_amp_l(a)
  amp_l = a

  if amp_l >= params:get('amp_threshold_l') then
    m_dots.input_sound[1] = true
  else
    m_dots.input_sound[1] = false
  end
end

function update_amp_r(a)
  amp_r = a

  if amp_r >= params:get('amp_threshold_r') then
    m_dots.input_sound[2] = true
  else
    m_dots.input_sound[2] = false
  end
end

-- convert amp [0, 1] to decibels [-inf, 0]
function ampdb(amp)
  return math.log(amp, 10) * 20.0
end

return m_dots

