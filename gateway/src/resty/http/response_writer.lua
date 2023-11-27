local _M = {
}

local cr_lf = "\r\n"

local function send(socket, data)
    if not data or data == '' then
        ngx.log(ngx.DEBUG, 'skipping sending nil')
        return
    end

    return socket:send(data)
end

-- write_response writes response body reader to sock in the HTTP/1.x server response format,
-- The connection is closed if send() fails or when returning a non-zero
function _M.send_response(sock, response, chunksize)
    local bytes, err
    chunksize = chunksize or 65536

    if not response then
        ngx.log(ngx.ERR, "no response provided")
        return
    end

    if not sock then
        return nil, "socket not initialized yet"
    end

    -- Status line
    local status  = "HTTP/1.1 " .. response.status .. " " .. response.reason .. cr_lf
    bytes, err = send(sock, status)
    if not bytes then
        return nil, "failed to send status line, err: " .. (err or "unknown")
    end

    -- Write body
    local reader = response.body_reader
    repeat
        local chunk, read_err

        chunk, read_err = reader(chunksize)
        if read_err then
            return nil, "failed to read response body, err: " .. (err or "unknown")
        end

        if chunk then
            bytes, err = send(sock, chunk)
            if not bytes then
                return nil, "failed to send response body, err: " .. (err or "unknown")
            end
        end
    until not chunk

    return true, nil
end

return _M
