local socket=require("socket")

local C_confCHN=love.thread.getChannel("tcp_c_config")
local C_sendCHN=love.thread.getChannel("tcp_c_send")
local C_recvCHN=love.thread.getChannel("tcp_c_receive")

---@type LuaSocket.master
local client

---@return Zenitha.TCP.MsgPack
local function parseMessage(message)
    local sep=message:find('|')
    return sep and {
        data=message:sub(sep+1),
        sender=message:sub(1,sep-1),
    } or {data=message}
end

local function clientLoop()
    while true do
        local config=C_confCHN:pop()
        if config then
            if config.action=='close' then
                client:close()
                print("[TCP_C] Disconnected from server")
                return
            end
        end

        local message,status,partial=client:receive()
        if message then C_recvCHN:push(parseMessage(message)) end
        if status=='closed' then
            print("[TCP_C] Server disconnected")
            return
        end

        ---@type Zenitha.TCP.MsgPack
        local data=C_sendCHN:pop()
        if data then
            if type(data.receiver)=='table' then data.receiver=table.concat(data.receiver,',') end
            local mes=data.receiver..'|'..data.data
            client:send(mes)
            print("[TCP_C] Message sent: "..mes)
        end
    end
end

while true do
    local ip=C_confCHN:demand()
    local port=C_confCHN:demand()
    local err
    client,err=socket.connect(ip,port)
    if err then
        C_recvCHN:push{
            success=false,
            message="Cannot bind to "..ip..":"..port..", reason: "..err,
        }
    else
        print("[TCP_C] Connected to "..ip..":"..port)
        client:settimeout(0.01)
        C_recvCHN:push{success=true}
        clientLoop()
    end
end
