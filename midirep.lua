ardour {
 ["type"]    = "dsp",
 name        = "Midi Repeater",
 category    = "Utility",
 license     = "MIT",
 author      = "Dmitry Golubovsky",
 description = [[Midi Repeater - based on midi filter example - v1.]]
}

function dsp_ioconfig ()
 return { { midi_in = 1, midi_out = 1, audio_in = 0, audio_out = 0}, }
end

function dsp_params ()
 return
 {
  { ["type"] = "input", name = "Pass Thru", min = 0, max = 1, default = 0, toggled = true },
  { ["type"] = "input", name = "Buffer Length", min = 3, max = 31, default = 7, integer = true } ,
  { ["type"] = "input", name = "Beats/Bar", min = 1, max = 32, default = 4, integer = true },
  { ["type"] = "input", name = "Fade By", min = 0, max = 10, default = 4, integer = true, unit = "Velocity" },
 }
end

local rate = 0

function dsp_init (dsprate)
  rate = dsprate
end

local notebuf = {}


local mididx = 0
local midrdx = 3

local time = 0
local tme = 0

local prevstop = 1

function dsp_run (_, _, n_samples)
 assert (type(midiin) == "table")
 assert (type(midiout) == "table")
 local ctrl = CtrlPorts:array()
 local pt = ctrl[1]
 local buflen = ctrl[2]
 local beats = ctrl[3]
 local fadeby = ctrl[4]
 local cnt = 1
 local tstop = Session:transport_stopped ()
 local tm = Session:tempo_map ()
 local ts = tm:tempo_section_at_sample (0)
 local bpm = ts:to_tempo():note_types_per_minute ()
 local nt = ts:to_tempo():note_type ()

 function tx_midi (time_, data_)
  midiout[cnt] = {}
  midiout[cnt]["time"] = time_;
  midiout[cnt]["data"] = data_;
  cnt = cnt + 1;
 end

 -- replay buffer if transport is running
 -- sync time when transport starts running (previous state was stopped)

 if not tstop then 
   if tstop ~= prevstop then tme = 0 end
   for time = 1, n_samples do
     tme = tme + 1;
     if tme >= rate * 60 * nt / (bpm * beats) then
	   local ridx = midrdx%buflen
	   local pn = notebuf [ridx]
	   if pn ~= nil and #pn == 3 then
	           local chan = pn [1] & 15
                   pn[1] = (8 << 4) | chan
		   tx_midi(1, pn)
	   end
	   midrdx = midrdx + 1;
	   ridx = midrdx%buflen
	   pn = notebuf [ridx]
	   if pn ~= nil and #pn == 3 then
	           local chan = pn [1] & 15
                   pn[1] = (9 << 4) | chan
		   tx_midi(2, pn)
		   if pn[3] > fadeby then pn[3] = pn[3] - fadeby else pn[3] = 0 end
	   end
  	   tme = 0
     end
   end
 end
 prevstop = tstop

 -- for each incoming midi event
 for _,b in pairs (midiin) do
  local t = b["time"] -- t = [ 1 .. n_samples ]
  local d = b["data"] -- get midi-event
  local event_type
  if #d == 0 then event_type = -1 else event_type = d[1] >> 4 end

  if (#d == 3 and event_type == 9) then -- note on
  if (pt == 1) then tx_midi (t, d) end
   notebuf[mididx%buflen] = d
   mididx = mididx + 1
  elseif (#d == 3 and event_type == 8) then -- note off
  if (pt == 1) then  tx_midi (t, d) end
  end
 end
end

