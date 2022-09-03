ardour {
 ["type"]    = "dsp",
 name        = "Midi Octave Confine @dev@",
 category    = "Utility",
 license     = "MIT",
 author      = "Dmitry Golubovsky",
 description = [[Midi Octave Confine - based on midi filter example - v1.0]]
}

function dsp_ioconfig ()
 return { { midi_in = 1, midi_out = 1, audio_in = 0, audio_out = 0}, }
end

function dsp_params ()
 return {
   { ["type"] = "input", name = "Velocity", min = 1, max = 127, default = 100, integer = true } ,
   { ["type"] = "input", name = "Base note", min = 1, max = 127, default = 64, integer = true } ,
   { ["type"] = "input", name = "MIDI Chan", min = 0, max = 15, default = 0, integer = true } ,
 } 
end

local rate = 0

local drawn = 0

local notebuf
local evcnt, drcnt = 0, 0

function dsp_init (dsprate)
  rate = dsprate
  self:shmem():allocate(1)
  notebuf = self:shmem():to_int(0):array()
  notebuf[1] = -1
end


local vel_all = 100
local pbnote, bnote = 64, 64
local outchan = 0

function dsp_run (_, _, n_samples)
  assert (type(midiin) == "table")
  assert (type(midiout) == "table")
  local ctrl = CtrlPorts:array()
  vel_all = ctrl[1]
  bnote = ctrl[2]
  outchan = ctrl[3]
  if bnote ~= pbnote then
    drawn = 0
    pbnote = bnote
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
  
  function transpose (note, xbnote)
    if note < xbnote then
	    while note < xbnote do
		    note = note + 12
	    end
	    return note
    elseif note > xbnote + 11 then
	    while note > xbnote + 11 do
		    note = note - 12
	    end
	    return note
    end
    return note
  end


 -- for each incoming midi event
 
  for _,b in pairs (midiin) do
    local t = b["time"] -- t = [ 1 .. n_samples ]
    local d = b["data"] -- get midi-event
    local event_type
    local note_val
    local note_vel
    if #d ~=3 then goto nextevent end
    drawn = 0
    evcnt = evcnt + 1
    event_type = d[1] >> 4 
    note_val = transpose(d[2], bnote)
    note_vel = d[3]

  -- transpose each note octave-wise to fit between the base note and base note + 11 inclusive
  -- if any note is playing then cancel it and play the new note
  -- if note off then send it off, and if it is playing. clear the buffer
  

    if (#d == 3 and event_type == 9) then -- note on
      if notebuf[1] == note_val then break end
      if notebuf[1] ~= -1 then -- note is playing, cancel it
  	local noff = {}
	noff[1] = 8 << 4 | outchan
        noff[2] = notebuf[1]
	noff[3] = 0
        tx_midi(t, noff)
	notebuf[1] = -1
      end
      notebuf[1] = note_val
      local non = {}
      non[1] = 9 << 4 | outchan
      non[2] = note_val
      non[3] = vel_all
      tx_midi(t, non)
      notebuf[1] = note_val
      break
    elseif (#d == 3 and event_type == 8) then -- note off
      if notebuf[1] == note_val then -- same note is playing
        notebuf[1] = -1
      end
      local noff = {}
      noff[1] = 8 << 4 | outchan
      noff[2] = note_val
      noff[3] = 0
      tx_midi(t, noff)
      break
    end


    ::nextevent::
  end

end

local hpadding, vpadding = 4, 2
local txt = nil

function format_note_name(b)
  if b == -1 then return "Free" end
  return string.format ("%-4s", ARDOUR.ParameterDescriptor.midi_note_name (b))
end

-- Draw note names in 2 columns, highlight notes that are on (notebuf[i] = 1)

function render_inline (ctx, displaywidth, max_h)
        local ctrl = CtrlPorts:array()
        local bnote = ctrl[2]
        local count = 6
	if not txt then 
          txt = Cairo.PangoLayout (ctx, "Mono 12")
	  txt:set_text("A4#")
	end
	-- compute the size of the display
	local linewid, lineheight = txt:get_pixel_size()
	local displayheight = math.min(vpadding + (lineheight + vpadding) * count, max_h)

	-- clear background
	ctx:rectangle (0, 0, displaywidth, displayheight)
	ctx:set_source_rgba (.2, .3, .4, 1.0)
	ctx:fill ()
	ctx:move_to (hpadding, vpadding)
        notebuf = self:shmem():to_int(0):array()
	ctx:set_source_rgba(0.9, 0.9, 0.9, 1.0)
	txt:set_text(format_note_name(bnote + 11))
	txt:show_in_cairo_context (ctx)
	ctx:move_to(hpadding, vpadding + lineheight)
	txt:set_text(format_note_name(notebuf[1]))
	txt:show_in_cairo_context (ctx)
	ctx:move_to(hpadding, vpadding + lineheight * 2)
	txt:set_text(format_note_name(bnote))
	txt:show_in_cairo_context (ctx)
	drcnt = drcnt + 1
	return {displaywidth, displayheight}
end


