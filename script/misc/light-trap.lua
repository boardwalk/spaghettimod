--[[

  Attract dumb players with a fancy server description.
  Showcasing functional programming utilities, hooks with deletion, bind to low level sauer structures and cubescript

]]--

local fp = require"utils.fp"
local map, range = fp.map, fp.range


local state
local cslfourcc = 1312969299 --CSL sends this always

require"std.extinfo"

local function set(f, wow)
  if state then
    spaghetti.removehook(state.pinghook)
    spaghetti.cancel(state.tickhook)
  end
  if not f or f == 0 then state = nil return end

  state = state or { pingers = {} }
  local oldlen = state.descs and #state.descs
  local concat = wow:rep(math.ceil(25/#wow) + 1)
  state.descs = map.f(function(i)
    return concat:sub(i, i + 24)
  end, range.z(1, #wow))
  if oldlen ~= #wow then state.nextdesc = 1 end
  local interval = 1000 / (f*#wow)

  local fakereq, fakep = engine.packetbuf(1, 0), engine.packetbuf(5000, 0)
  fakereq:putint(1)

  state.pinghook = spaghetti.addhook("extinfo", function(info)
    if info.millis == 0 or info.millis == cslfourcc then return end
    info.skip = true
    local pinger = state.pingers[engine.pongaddr.host] or {}
    pinger.lastping = engine.totalmillis
    pinger.millisoffset = info.millis - engine.totalmillis
    pinger.port = engine.pongaddr.port
    state.pingers[engine.pongaddr.host] = pinger
  end)

  state.tickhook = spaghetti.later(interval, function()
    local origdesc, orighost, origport = cs.serverdesc, engine.pongaddr.host, engine.pongaddr.port
    cs.serverdesc = state.descs[state.nextdesc]
    map.pn(function(ip, pinger)
      if engine.totalmillis - pinger.lastping > 10000 then state.pingers[ip] = nil return end
      fakereq.len, fakep.len = 0, 0
      fakep:putint(pinger.millisoffset + engine.totalmillis)
      engine.pongaddr.host, engine.pongaddr.port = ip, pinger.port
      server.serverinforeply(fakereq, fakep)
    end, state.pingers)
    cs.serverdesc = origdesc
    state.nextdesc = state.nextdesc % #state.descs + 1
  end, true)

end


return {set = set}
