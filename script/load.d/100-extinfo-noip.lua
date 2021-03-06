--[[

  Protect the privacy of players by either sending no ip, or sending a fake ip with corresponding geolocalization.

]]--

local fp, it, putf, L = require"utils.fp", require"std.iterators", require"std.putf", require"utils.lambda"
local map, first = fp.map, fp.first

require"std.extinfo"
local fakeip = L"0"

spaghetti.addhook("extinfo", function(info)
  if info.code ~= server.EXT_PLAYERSTATS then return end
  local req, p = info.req, info.p
  info.skip = true
  putf(p, server.EXT_ACK, server.EXT_VERSION)
  local which = req:getint()
  local players = {}
  for ci in it.all() do
    if which < 0 or ci.clientnum == which then
      players[ci] = true
      if which >= 0 then break end
    end
  end
  if not next(players) and which >= 0 then
    p:putint(server.EXT_ERROR)
    engine.sendserverinforeply(p)
    return
  end
  p:putint(server.EXT_NO_ERROR)
  local q = p.len
  p:putint(server.EXT_PLAYERSTATS_RESP_IDS)
  for ci in pairs(players) do p:putint(ci.clientnum) end
  engine.sendserverinforeply(p)
  for ci in pairs(players) do
    p.len = q
    local ip = fakeip(ci)
    putf(p,
      server.EXT_PLAYERSTATS_RESP_STATS,
      ci.clientnum,
      ci.ping,
      ci.name,
      ci.team,
      ci.state.frags,
      ci.state.flags,
      ci.state.deaths,
      ci.state.teamkills,
      ci.state.damage*100/math.max(ci.state.shotdamage, 1),
      ci.state.health,
      ci.state.armour,
      ci.state.gunselect,
      ci.privilege,
      ci.state.state,
      {math.floor(ip / 0x1000000) % 0x100},
      {math.floor(ip / 0x10000) % 0x100},
      {math.floor(ip / 0x100) % 0x100}
      )
    engine.sendserverinforeply(p)
  end
end)

local fakegeoip = io.open(os.getenv"GEOIPCSV" or "GeoIPCountryWhois.csv")

if not fakegeoip then
  return engine.writelog("Cannot load GeoIPCountryWhois.csv, adjust the GEOIPCSV environment variable. Will be sending 0 in the ip field of extinfo.")
end

engine.writelog("Generating fake extinfo IPs from geoip csv data...")
local locations = {}
for line in fakegeoip:lines() do
  local s, e, code = line:match('"(%d+)","(%d+)","(..)"')
  if s then
    s, e = tonumber(s), tonumber(e)
    local list = locations[code] or { tot = 0 }
    table.insert(list, { s = s, tot = e - s + 1 })
    list.tot = list.tot + e - s + 1
    locations[code] = list
  end
end
fakegeoip:close()
locations = map.mp(function(code, list)
  local r = math.random(0, list.tot - 1)
  for _, range in ipairs(list) do
    if r >= range.tot then r = r - range.tot
    else return code, range.s + r end
  end
end, locations)
engine.writelog("... done")

fakeip = function(ci) return locations[ci.extra.geoip and ci.extra.geoip.country and ci.extra.geoip.country.iso_code] or 0 end
