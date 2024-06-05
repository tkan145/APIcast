--- Financial-grade API (FAPI) policy

local policy = require('apicast.policy')
local _M = policy.new('Financial-grade API (FAPI) Policy', 'builtin')

local uuid = require 'resty.jit-uuid'

local new = _M.new
local X_FAPI_TRANSACTION_ID_HEADER = "x-fapi-transaction-id"

function _M.new(config)
  local self = new(config)
  return self
end

function _M:header_filter()
  -- Get x-fapi-transaction-id from the request
  local transaction_id = ngx.req.get_headers()[X_FAPI_TRANSACTION_ID_HEADER]
  if not transaction_id or transaction_id == "" then
      -- Nothing found, generate one
    transaction_id = ngx.resp.get_headers()[X_FAPI_TRANSACTION_ID_HEADER]
    if not transaction_id or transaction_id == "" then
      transaction_id = uuid.generate_v4()
    end
  end
  ngx.header[X_FAPI_TRANSACTION_ID_HEADER] = transaction_id
end

return _M
