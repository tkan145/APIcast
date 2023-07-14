local tonumber = tonumber

local resty_url = require('resty.url')
local core_base = require('resty.core.base')
local str_find = string.find
local str_sub = string.sub
local concat = table.concat
local new_tab = core_base.new_tab

local _M = {}

function _M.split_path(path)
    if not path then return end

    local start = str_find(path, '?', 1, true)

    if start then
        return str_sub(path, 1, start - 1), str_sub(path, start + 1)
    else
        return path
    end
end



function _M.parse_url(url)
    local parsed, err = resty_url.split(url)

    if err then return nil, err end

    local uri = new_tab(0, 6)

    uri.scheme = parsed[1]
    uri.user = parsed[2]
    uri.password = parsed[3]
    uri.host = parsed[4]
    uri.port = tonumber(parsed[5])

    uri.path, uri.query = _M.split_path(parsed[6])

    return uri
end

-- parse_url_auth parse url with the following form
-- http(s)://<username>:<password>@<url>
function _M.parse_url_auth(url, default_path)
  local parsed, err = resty_url.split(url)

  if not parsed and err then
    return nil, nil, err
  end

  local scheme, user, pass, host, port, path = unpack(parsed)
  if port then host = concat({host, port}, ':') end

  url = concat({ scheme, '://', host, path or default_path }, '')

  -- TODO: escape special character in the userinfo
  --
  -- According to RFC 3986. §3.2.1
  -- The RFC allows ';', ':', '&', '=', '+', '$', and ',' in
  -- userinfo, so we must escape '@', '/', and '?'.
  --
  -- The following case should fail but valid at the moment
  -- http//j@ne:password@example.com'
  --
  -- And this should fail but valid at the moment
  -- "http://user^:passwo^rd@foo.com/"
  local auth
  if user or pass then
    auth = "Basic " .. ngx.encode_base64(concat({ user or '', pass or '' }, ':'))
  end

  return url, auth
end

return _M
