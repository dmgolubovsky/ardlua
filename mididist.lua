ardour {
 ["type"]    = "dsp",
 name        = "Midi Distributor @dev@",
 category    = "Utility",
 license     = "MIT",
 author      = "Dmitry Golubovsky",
 description = [[Midi Distributor - based on midi filter example - v1.0]]
}

function dsp_ioconfig ()
 return { { midi_in = 1, midi_out = 1, audio_in = 0, audio_out = 0}, }
end

function dsp_params ()
 return {
   { ["type"] = "input", name = "Velocity", min = 1, max = 127, default = 100, integer = true } ,
 } 
end

local rate = 0

local drawn = 0

local notebuf
local evcnt, drcnt = 0, 0

function dsp_init (dsprate)
  rate = dsprate
  self:shmem():allocate(10)
  notebuf = self:shmem():to_int(0):array()
  for i = 1, 10  do
    notebuf[i] = -1
  end
end


local vel_all = 100

function dsp_run (_, _, n_samples)
  assert (type(midiin) == "table")
  assert (type(midiout) == "table")
  local ctrl = CtrlPorts:array()
  vel_all = ctrl[1]
  local cnt = 1

  if drawn == 0 then
	  self:queue_draw()
          drawn = 1
  end

  function tx_midi (time_, data_)
    midiout[cnt] = {}
    midiout[cnt]["time"] = time_;
    midiout[cnt]["data"] = data_;
    cnt = cnt + 1;
  end

 -- for each incoming midi event
 
  for _,b in pairs (midiin) do
    local t = b["time"] -- t = [ 1 .. n_samples ]
    local d = b["data"] -- get midi-event
    local event_type
    local note_val
    local note_vel
    local midichan
    if #d ~=3 then goto nextevent end
    drawn = 0
    evcnt = evcnt + 1
    event_type = d[1] >> 4 
    note_val = d[2]
    note_vel = d[3]

  -- if note on then find place it if there is room in the buffer
  -- if note is already in the buffer ignore it
  -- if note off and it is in the buffer then mark its slot as free

    if (#d == 3 and event_type == 9) then -- note on
      for ni = 1, 10 do
	 if notebuf[ni] == note_val then break end
         if notebuf[ni] == -1 then
           notebuf[ni] = note_val
	   break
	 end
      end
    elseif (#d == 3 and event_type == 8) then -- note off
      for ni = 1, 10 do
	 if notebuf[ni] == note_val then
	   notebuf[ni] = -1
	   break
	 end
      end
    end


  -- if a note is set in the current buffer then send note on
--[[
    midichan = 0
    for k, v in pairs (notebuf) do
      local noff = {}
      noff[1] = (9 << 4) | midichan
      noff[2] = k
      noff[3] = vel_all
      if v == 1 then 
        tx_midi(t, noff)
        midichan = midichan + 1
        if midichan > 15 then break end
      end
    end
]]--

    ::nextevent::
  end

end

local hpadding, vpadding = 4, 2
local txt = nil

function format_note_name(b)
  return string.format ("%5s", ARDOUR.ParameterDescriptor.midi_note_name (b))
end

function render_inline (ctx, displaywidth, max_h)
        local count = 10
	if not txt then 
          txt = Cairo.PangoLayout (ctx, "Mono 6")
	end
	-- compute the size of the display
	local _, lineheight = txt:get_pixel_size()
	local displayheight = math.min(vpadding + (lineheight + vpadding) * count, max_h)

	-- clear background
	ctx:rectangle (0, 0, displaywidth, displayheight)
	ctx:set_source_rgba (.2, .3, .4, 1.0)
	ctx:fill ()
	ctx:move_to (hpadding, vpadding)
	ctx:set_source_rgba (.9, .9, .9, 1.0)
        notebuf = self:shmem():to_int(0):array()
	for i = 1, count do
	  txt:set_text(string.format("[%02u]: %s", i, format_note_name(notebuf[i])))
	  txt:show_in_cairo_context (ctx)
	  ctx:move_to(hpadding, vpadding + i * lineheight)
	end
	drcnt = drcnt + 1
	return {displaywidth, displayheight}
end


