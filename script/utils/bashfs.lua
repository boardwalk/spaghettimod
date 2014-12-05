--[[

  Some hacky but safe file manipulation functions to use bash instead of requiring lua-filesystem.

]]--

local module = {}

function module.mkdir(fname)
  local bash = io.popen('mkdir -p "`cat`" &>/dev/null', "w")
  bash:write(fname)
  local result = bash:close()
  if result then return true end
  --can only do this in 5.1
  bash = io.popen('touch "`cat`"/bashfstest 2>/dev/null', "w")
  bash:write(fname)
  bash:close()
  local bashfstest = io.open(fname .. "/bashfstest")
  if bashfstest then bashfstest:close() end
  os.remove(fname .. "/bashfstest")
  return not not bashfstest
end

return module