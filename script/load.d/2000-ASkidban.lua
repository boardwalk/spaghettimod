--[[

  Ban IPs belonging to AS numbers.

]]--

local fs = require"utils.fs"
if not fs.readsome then engine.writelog("Cannot ban AS numbers, missing lua-posix") return end
local ban, ip = require"std.ban", require"utils.ip"

local function parselist(bans)
  ban.clear("ASkidban")
  for s in bans:gmatch("([^\n]+)\n?") do
    local ip = ip.ip(s)
    if not ip then engine.writelog("ASkidban: cannot parse " .. s)
    else
      local ok, overlap = ban.ban("ASkidban", ip, nil, nil, false, nil, nil, true)
      if not ok then engine.writelog("ASkidban: cannot add " .. tostring(ip)) end
    end
  end
  engine.writelog("ASkidban: updated")
end

local reloadlist
reloadlist = function()
  local wget, err = io.popen"wget -qO- https://raw.githubusercontent.com/pisto/ASkidban/master/compiled/ip"
  if not wget then
    engine.writelog("Cannot fetch ASkidban list: " .. err)
    spaghetti.later(60 * 60 * 1000, reloadlist)
    return
  end
  local bans, fetcher = ""
  fetcher = spaghetti.later(100, function()
    local str = fs.readsome(wget)
    if not str then
      local ret = wget:close()
      spaghetti.cancel(fetcher)
      spaghetti.later(60 * 60 * 1000, reloadlist)
      if ret == true or ret == 0 then parselist(bans)
      else engine.writelog("Cannot fetch ASkidban list (wget failed)") end
      return
    end
    bans = bans .. str
  end, true)
end

ban.newlist("ASkidban", "Your IP appears to be a proxy, see \fs\f0github.com/pisto/ASkidban\fr for more info.\nIf this is an error please contact \fs\f0pisto\fr: \fs\f0blaffablaffa@gmail.com\fr", { client = server.PRIV_ADMIN })

reloadlist()
