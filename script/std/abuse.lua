--[[

  Miscellaneous anti abuse tools.

]]--

local playermsg, module = require"std.playermsg", {}

--packet rate limit

local fp, lambda, tb = require"utils.fp", require"utils.lambda", require"utils.tokenbucket"
local noop, I, map, L, U = fp.noop, fp.I, fp.map, lambda.L, fp.U

function module.ratelimit(packets, rate, maxtokens, selector)
  if type(packets) == "number" then packets = {packets} end
  packets = {U(packets)}
  packets.hooks = map.m(function(_, p)
    return p, spaghetti.addhook(p, function(info)
      local skip, desc, client
      if selector then
        skip, desc, client = selector(info)
        if skip then return end
      end
      local extra = (client or info.ci).extra
      extra.ratelimit = extra.ratelimit or {}
      extra.ratelimit[packets] = extra.ratelimit[packets] or tb(rate, maxtokens)
      if extra.ratelimit[packets]() then return end
      info.skip, info.ratelimited = true, (desc or true)

    end, true) end
  , packets)
  return packets
end

module.delratelimit = spaghetti.removehook


--Sound that can be sent by vanilla clients

local clientsounds = map.sv(I, server.S_JUMP, server.S_LAND, server.S_NOAMMO)
function module.clientsound(s)
  return (server.m_capture and s == server.S_ITEMAMMO) or clientsounds[s]
end


--Reconnect spam
local ip = require"utils.ip"
local function makeip(enetevent)
  return ip.ip(engine.ENET_NET_TO_HOST_32(enetevent.peer.address.host)).ip
end

local reconnects, connecthook, cleanhook
function module.reconnectspam(rate, maxtokens)
  if reconnects then
    spaghetti.cancel(cleanhook)
    spaghetti.removehook(connecthook)
    reconnects, connecthook, cleanhook = nil
  end
  if not rate then return end
  reconnects = {}
  connecthook = spaghetti.addhook("enetevent", function(info)
    if info.event.type ~= engine.ENET_EVENT_TYPE_CONNECT then return end
    local idx = makeip(info.event)
    local limiter = reconnects[idx] or { tb = tb(rate, maxtokens) }
    if not limiter.tb() then
      info.skip = true
      engine.enet_peer_disconnect_now(info.event.peer, engine.DISC_OVERFLOW)
      if not limiter.logged then
        engine.writelog("Reconnect spam from " .. tostring(ip.ip(idx)))
        limiter.logged = true
      end
    else limiter.logged = false end
    reconnects[idx] = limiter
  end)
  cleanhook = spaghetti.later(30000, function()
    map.np(function(ip, limiter)
      limiter.tb(0)
      if limiter.tb.tokens == maxtokens then reconnects[ip] = nil end
    end, reconnects)
  end, true)
end

return module
