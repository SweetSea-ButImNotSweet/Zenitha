local sendCHN=love.thread.getChannel('inputChannel')
local recvCHN=love.thread.getChannel('outputChannel')

local threads={}
local threadCount=0
local threadCode=[[
    local id=...

    local http=require'socket.http'
    local ltn12=require'ltn12'

    local sendCHN=love.thread.getChannel('inputChannel')
    local recvCHN=love.thread.getChannel('outputChannel')

    while true do
        local arg=sendCHN:demand()

        if arg._destroy then break end

        local data={}
        local _,code,detail=http.request{
            method=arg.method,
            url=arg.url,
            headers=arg.headers,
            source=ltn12.source.string(arg.body),

            sink=ltn12.sink.table(data),
        }

        recvCHN:push{
            arg.pool or '_default',
            code,
            table.concat(data),
            detail
        }
    end

    recvCHN:push{
        destroy=true,
        id=id,
    }
]]

local msgPool=setmetatable({},{
    __index=function(self,k)
        self[k]={}
        return self[k]
    end
})

local HTTP={
    _msgCount=0,
    _trigTime=0,
    _trigInterval=.626,
    _host=false,
}

local function addThread(num)
    for i=1,26 do
        if num<=0 then break end
        if not threads[i] then
            threads[i]=love.thread.newThread(threadCode)
            threads[i]:start(i)
            threadCount=threadCount+1
            num=num-1
        end
    end
end

function HTTP.request(arg)
    arg.method=arg.method or arg.body and 'POST' or 'GET'
    if arg.url then
        assert(type(arg.url)=='string',"Field 'url' need string, get "..type(arg.url))
        if arg.url:sub(1,7)~='http://' then arg.url='http://'..arg.url end
    else
        arg.url=HTTP._host or error("Need url=<string> or set default host with HTTP.setHost")
    end
    if arg.path then
        assert(type(arg.path)=='string',"Field 'path' need string, get "..type(arg.path))
        arg.url=arg.url..arg.path
    end
    assert(arg.headers==nil or type(arg.headers)=='table',"Field 'headers' need table, get "..type(arg.headers))

    if arg.method=='POST' then
        if arg.body~=nil then
            assert(type(arg.body)=='table',"Field 'body' need table, get "..type(arg.body))
            arg.body=JSON.encode(arg.body)
            if not arg.headers then arg.headers={} end
            TABLE.cover({
                ['Content-Type']="application/json",
                ['Content-Length']=#arg.body,
            },arg.headers)
        end
    end

    sendCHN:push(arg)
end

function HTTP.reset()
    for i=1,#threads do
        threads[i]:release()
        threads[i]=false
    end
    TABLE.clear(msgPool)
    sendCHN:clear()
    recvCHN:clear()
    addThread(threadCount)
end
function HTTP.setThreadCount(n)
    assert(type(n)=='number' and n>=1 and n<=26 and n%1==0,"function HTTP.setThreadCount(n): n must be integer from 1 to 26")
    if n>threadCount then
        addThread(n-threadCount)
    else
        for _=n+1,threadCount do
            sendCHN:push{_destroy=true}
        end
    end
end
function HTTP.getThreadCount()
    return threadCount
end
function HTTP.setInterval(interval)
    if interval<=0 then interval=1e99 end
    assert(type(interval)=='number',"Interval must be number")
    HTTP._trigInterval=interval
end
function HTTP.pollMsg(pool)
    if not (type(pool)=='nil' or type(pool)=='string') then error("Pool must be nil or string") end
    HTTP.update()
    local p=msgPool[pool or '_default']
    if #p>0 then
        HTTP._msgCount=HTTP._msgCount-1
        return table.remove(p)
    end
end
function HTTP.setHost(host)
    assert(type(host)=='string',"Host must be string")
    if host:sub(1,7)~='http://' then host='http://'..host end
    HTTP._host=host
end

function HTTP.update(dt)
    if dt then
        HTTP._trigTime=HTTP._trigTime+dt
        if HTTP._trigTime>HTTP._trigInterval then
            HTTP._trigTime=HTTP._trigTime%HTTP._trigInterval
        else
            return
        end
    end
    while recvCHN:getCount()>0 do
        local m=recvCHN:pop()
        if m.destroy then
            threads[m.id]:release()
            threads[m.id]=false
        else
            table.insert(msgPool[m[1]],{
                code=m[2],
                body=m[3],
                detail=m[4],
            })
            HTTP._msgCount=HTTP._msgCount+1
        end
    end
end

setmetatable(HTTP,{__call=function(self,arg)
    self.request(arg)
end,__metatable=true})

HTTP.reset()

return HTTP