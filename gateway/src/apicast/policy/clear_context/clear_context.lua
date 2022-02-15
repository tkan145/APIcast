local _M = require('apicast.policy').new('Clear Context')
local new = _M.new

function _M.new(...)
  ssl_ctx_reset = false
  return new(...)
end

function _M:ssl_certificate(context)
  reset_context(context)
  ssl_ctx_reset = true
end

function _M:rewrite(context)
  --Do not reset the context again if the ssl_certificate phase
  --was executed for this request. This way other policies that edited 
  --the context in their ssl_* phases won't have their changes cleared
  if not ssl_ctx_reset then
    reset_context(context)
  end
  ssl_ctx_reset = false
end

function reset_context(context)
  context.current = {}
end

return _M
