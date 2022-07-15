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
   { ["type"] = "input", name = "N Channels", min = 1, max = 9, default = 2, integer = true } ,
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
local pnchan, nchan = 2, 2

function dsp_run (_, _, n_samples)
  assert (type(midiin) == "table")
  assert (type(midiout) == "table")
  local ctrl = CtrlPorts:array()
  vel_all = ctrl[1]
  nchan = ctrl[2]
  if nchan ~= pnchan then
    drawn = 0
    pnchan = nchan
  end
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
  -- send note on if stored
  -- if note off and it is in the buffer then send it off and mark its slot as free

    if (#d == 3 and event_type == 9) then -- note on
      for ni = 1, 10 do
	 if notebuf[ni] == note_val then break end
         if notebuf[ni] == -1 then
           notebuf[ni] = note_val
	   local notechan =  (ni - 1) % nchan
	   local non = {}
	   non[1] = 9 << 4 | notechan
	   non[2] = note_val
	   non[3] = vel_all
           tx_midi(t, non)
	   break
	 end
      end
    elseif (#d == 3 and event_type == 8) then -- note off
      for ni = 1, 10 do
	 if notebuf[ni] == note_val then
           notebuf[ni] = note_val
	   local notechan =  (ni - 1) % nchan
	   local noff = {}
	   noff[1] = 8 << 4 | notechan
	   noff[2] = note_val
	   noff[3] = 0
           tx_midi(t, noff)
	   notebuf[ni] = -1
	   break
	 end
      end
    end


    ::nextevent::
  end

end

local hpadding, vpadding = 4, 2
local txt = nil

function format_note_name(b)
  if b == -1 then return "Free" end
  return string.format ("%4s", ARDOUR.ParameterDescriptor.midi_note_name (b))
end

function render_inline (ctx, displaywidth, max_h)
        local ctrl = CtrlPorts:array()
        local nchan = ctrl[2]
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
	  txt:set_text(string.format("[%02u]: %s -> %02u", i, format_note_name(notebuf[i]), (i - 1) % nchan))
	  txt:show_in_cairo_context (ctx)
	  ctx:move_to(hpadding, vpadding + i * lineheight)
	end
	drcnt = drcnt + 1
	return {displaywidth, displayheight}
end


