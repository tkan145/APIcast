local httpc = require "resty.resolver.http"

local _M = {
}

local cr_lf = "\r\n"

-- chunked_reader return a body reader that translates the data read from
-- lua-resty-http client_body_reader to HTTP "chunked" format before returning it
--
-- The chunked reader return nil when the final 0-length chunk is read
local function chunked_reader(sock, chunksize)
    chunksize = chunksize or 65536
    local eof = false
    local reader = httpc:get_client_body_reader(chunksize, sock)
    if not reader then
        return nil
    end

    return function()
        if eof then
            return nil
        end

        local buffer, err = reader()
        if err then
            return nil, err
        end
        if buffer then
            local chunk = string.format("%x\r\n", #buffer) .. buffer .. cr_lf
            return chunk
        else
            eof = true
            return "0\r\n\r\n"
        end
    end
end

function _M.get_client_body_reader(sock, chunksize, is_chunked)
    if is_chunked then
        return chunked_reader(sock, chunksize)
    else
        return httpc:get_client_body_reader(chunksize, sock)
    end
end

return _M
