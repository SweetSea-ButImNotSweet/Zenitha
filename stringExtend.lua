local data=love.data
local assert,tostring,tonumber=assert,tostring,tonumber
local floor,lg=math.floor,math.log10
local find,format=string.find,string.format
local sub,gsub=string.sub,string.gsub
local rep,upper=string.rep,string.upper
local char,byte=string.char,string.byte

local b16={[0]='0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'}

local STRING={}

--- Install stringExtend into the lua basic "string library", so that you can use these extended functions with `str:xxx(...)` format
function STRING.install()
    function STRING.install()
        error("attempt to install stringExtend library multiple times")
    end
    for k,v in next,STRING do
        string[k]=v
    end
end

--- "Replace dollars". Replace all $n with ..., like string.format
---@param str string
---@vararg any
---@return string
function STRING.repD(str,...)
    local l={...}
    for i=#l,1,-1 do
        str=gsub(str,'$'..i,l[i])
    end
    return str
end

--- "Scan arg", scan if str has the arg (format of str is like '-json -q', arg is like '-q')
---@param str string
---@param switch string
---@return boolean
function STRING.sArg(str,switch)
    if find(str..' ',switch..' ') then
        return true
    else
        return false
    end
end


local shiftMap={
    ['1']='!',['2']='@',['3']='#',['4']='$',['5']='%',
    ['6']='^',['7']='&',['8']='*',['9']='(',['0']=')',
    ['`']='~',['-']='_',['=']='+',
    ['[']='{',[']']='}',['\\']='|',
    [';']=':',['\'']='"',
    [',']='<',['.']='>',['/']='?',
}
--- "Capitalize" a character like string.upper, but can also shift numbers to signs
---@param c string
---@return string
function STRING.shiftChar(c)
    return shiftMap[c] or upper(c)
end

--- Trim %s at both ends of the string
---@param str string
---@return string
function STRING.trim(str)
    if not str:find('%S') then return'' end
    str=str:sub((str:find('%S'))):reverse()
    return str:sub((str:find('%S'))):reverse()
end

--- Split a string by sep
---@param str string
---@param sep string
---@param regex? boolean
---@return string[]
function STRING.split(str,sep,regex)
    local L={}
    local p1=1-- start
    local p2-- target
    if regex then
        while p1<=#str do
            p2=find(str,sep,p1) or #str+1
            L[#L+1]=sub(str,p1,p2-1)
            p1=p2+#sep
        end
    else
        while p1<=#str do
            p2=find(str,sep,p1,true) or #str+1
            L[#L+1]=sub(str,p1,p2-1)
            p1=p2+#sep
        end
    end
    return L
end

--- Check if the string is a valid email address
---@param str string
---@return boolean
function STRING.simpEmailCheck(str)
    local list=STRING.split(str,'@')
    if #list~=2 then return false end
    if list[1]:sub(-1)=='.' or list[2]:sub(-1)=='.' then return false end
    local e1,e2=STRING.split(list[1],'.'),STRING.split(list[2],'.')
    if #e1*#e2==0 then return false end
    for _,v in next,e1 do if #v==0 then return false end end
    for _,v in next,e2 do if #v==0 then return false end end
    return true
end

--- Convert time (second) to MM:SS
---@param t number
---@return string
function STRING.time_simp(t)
    return format('%02d:%02d',floor(t/60),floor(t%60))
end

--- Convert time (second) to SS or MM:SS or HH:MM:SS
---@param t number
---@return string
function STRING.time(t)
    if t<60 then
        return format('%.3f″',t)
    elseif t<3600 then
        return format('%d′%05.2f″',floor(t/60),floor(t%60*100)/100)
    else
        return format('%d:%.2d′%05.2f″',floor(t/3600),floor(t/60%60),floor(t%60*100)/100)
    end
end

--- Warning: don't support number format like .26, must have digits before the dot, like 0.26
---@param s string
---@return number|nil,string|nil
function STRING.cutUnit(s)
    local _s,_e=s:find('^-?%d+%.?%d*')
    if _e==#s then-- All numbers
        return tonumber(s),nil
    elseif not _s then-- No numbers
        return nil,s
    else
        return tonumber(s:sub(_s,_e)),s:sub(_e+1)
    end
end

--- Get the type of a character
---@param c string
---@return 'space'|'word'|'sign'|'other'
function STRING.type(c)
    assert(type(c)=='string' and #c==1,'function STRING.type(c): c must be a single-charater string')
    local t=byte(c)
    if t==9 or t==10 or t==13 or t==32 then
        return 'space'
    elseif t>=48 and t<=57 or t>=65 and t<=90 or t>=97 and t<=122 then
        return 'word'
    elseif t>=33 and t<=47 or t>=58 and t<=64 or t>=91 and t<=96 or t>=123 and t<=126 then
        return 'sign'
    else
        return 'other'
    end
end

--- Base64 character list
---@type string[]
STRING.base64={} for c in string.gmatch('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/','.') do
    table.insert(STRING.base64,c)
end

--- Simple utf8 coding
---@param num number
---@return string
function STRING.UTF8(num)
    assert(type(num)=='number','Wrong type ('..type(num)..')')
    if num<=0 then
        error('Out of range ('..num..')')
    elseif num<2^7  then return char(num)
    elseif num<2^11 then return char(192+floor(num/2^06),128+num%2^6)
    elseif num<2^16 then return char(224+floor(num/2^12),128+floor(num/2^06)%2^6,128+num%2^6)
    elseif num<2^21 then return char(240+floor(num/2^18),128+floor(num/2^12)%2^6,128+floor(num/2^06)%2^6,128+num%2^6)
    elseif num<2^26 then return char(248+floor(num/2^24),128+floor(num/2^18)%2^6,128+floor(num/2^12)%2^6,128+floor(num/2^06)%2^6,128+num%2^6)
    elseif num<2^31 then return char(252+floor(num/2^30),128+floor(num/2^24)%2^6,128+floor(num/2^18)%2^6,128+floor(num/2^12)%2^6,128+floor(num/2^06)%2^6,128+num%2^6)
    else
        error('Out of range ('..num..')')
    end
end

local units={'','K','M','B','T','Qa','Qt','Sx','Sp','Oc','No'}
local preUnits={'','U','D','T','Qa','Qt','Sx','Sp','O','N'}
local secUnits={'Dc','Vg','Tg','Qd','Qi','Se','St','Og','Nn','Ce'}-- Ce is next-level unit, but DcCe is not used so used here
for _,preU in next,preUnits do for _,secU in next,secUnits do table.insert(units,preU..secU) end end
--- Convert a number to a approximate integer with large unit
---@param num number
---@return string
function STRING.bigInt(num)
    if num<1000 then
        return tostring(num)
    elseif num~=1e999 then
        local e=floor(lg(num)/3)
        return (num/10^(e*3))..units[e+1]
    else
        return 'INF'
    end
end

--- Convert a number to binary string
---@param num number
---@param len? number
---@return string
function STRING.toBin(num,len)
    local s=''
    while num>0 do
        s=(num%2)..s
        num=floor(num/2)
    end
    return tonumber(len) and rep('0',tonumber(len)-#s)..s or s
end

--- Convert a number to octal string
---@param num number
---@param len? number
---@return string
function STRING.toOct(num,len)
    local s=''
    while num>0 do
        s=(num%8)..s
        num=floor(num/8)
    end
    return tonumber(len) and rep('0',tonumber(len)-#s)..s or s
end

--- Convert a number to hexadecimal string
---@param num number
---@param len? number
---@return string
function STRING.toHex(num,len)
    local s=''
    while num>0 do
        s=b16[num%16]..s
        num=floor(num/16)
    end
    return tonumber(len) and rep('0',tonumber(len)-#s)..s or s
end

local rshift=bit.rshift
--- Simple url encoding
---@param str string
---@return string
function STRING.urlEncode(str)
    local out=''
    for i=1,#str do
        if str:sub(i,i):match('[a-zA-Z0-9]') then
            out=out..str:sub(i,i)
        else
            local b=str:byte(i)
            out=out..'%'..b16[rshift(b,4)]..b16[b%16]
        end
    end
    return out
end

--- Simple vcs encryption
---@param text string
---@param key string
---@return string
function STRING.vcsEncrypt(text,key)
    local keyLen=#key
    local result=''
    local buffer=''
    for i=0,#text-1 do
        buffer=buffer..char((byte(text,i+1)-32+byte(key,i%keyLen+1))%95+32)
        if #buffer==26 then
            result=result..buffer
            buffer=''
        end
    end
    return result..buffer
end

--- Simple vcs decryption
---@param text string
---@param key string
---@return string
function STRING.vcsDecrypt(text,key)
    local keyLen=#key
    local result=''
    local buffer=''
    for i=0,#text-1 do
        buffer=buffer..char((byte(text,i+1)-32-byte(key,i%keyLen+1))%95+32)
        if #buffer==26 then
            result=result..buffer
            buffer=''
        end
    end
    return result..buffer
end

--- Return 16 byte string. Not powerful hash, just simply protect the original text
---@param text string
---@param seedRange? number @default to 26
---@param seed? number @default to 0
---@return string
function STRING.digezt(text,seedRange,seed)
    if not seed then seed=0 end
    if not seedRange then seedRange=26 end
    local out={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

    for i=1,#text do
        local c=byte(text,i)
        seed=(seed+c)%seedRange
        c=c+seed
        local pos=c*i%16
        local step=(c+i)%4+1
        local times=2+(c%6)
        for _=1,times do
            out[pos+1]=(out[pos+1]+c)%256
            pos=(pos+step)%16
        end
    end
    local result=''
    for i=1,16 do result=result..char(out[i]) end
    return result
end

--- Cut a line off a string
---@param str string
---@return string,string @one line (do not include \n), and the rest of string
function STRING.readLine(str)
    local p=str:find('\n')
    if p then
        return str:sub(1,p-1),str:sub(p+1)
    else
        return str,''
    end
end

--- Cut n bytes off a string
---@param str string
---@param n number
---@return string,string @n bytes, and the rest of string
function STRING.readChars(str,n)
    return sub(str,1,n),sub(str,n+1)
end

--- Shorten a path by cutting off long directory name
--- ## Example
--- ```lua
--- STRING.simplifyPath('Documents/Project/xxx.lua') --> 'D/P/xxx.lua'
--- STRING.simplifyPath('Documents/Project/xxx.lua',3) --> 'Doc/Pro/xxx.lua'
--- ```
function STRING.simplifyPath(path,len)
    local l=STRING.split(path,'/')
    for i=1,#l-1 do l[i]=l[i]:sub(1,len or 1) end
    return table.concat(l,'/')
end

--- Pack binary data into string (Zlib+Base64)
---@param str string
---@return string|love.Data
function STRING.packBin(str)
    return data.encode('string','base64',data.compress('string','zlib',str))
end

--- Unpack binary data from string (Zlib+Base64)
---@param str string
---@return string|love.Data|nil
function STRING.unpackBin(str)
    local success,res
    success,res=pcall(data.decode,'string','base64',str)
    if not success then return end
    success,res=pcall(data.decompress,'string','zlib',str)
    if success then return res end
end

--- Pack text data into string (Gzip+Base64)
---@param str string
---@return string|love.Data
function STRING.packText(str)
    return data.encode('string','base64',data.compress('string','gzip',str))
end

--- Unpack text data from string (Gzip+Base64)
---@param str string
---@return string|love.Data|nil
function STRING.unpackText(str)
    local success,res
    success,res=pcall(data.decode,'string','base64',str)
    if not success then return end
    success,res=pcall(data.decompress,'string','gzip',str)
    if success then return res end
end

--- Pack table into string (JSON+Gzip+Base64)
---@param t table
---@return string|love.Data|nil
function STRING.packTable(t)
    return STRING.packText(JSON.encode(t))
end

--- Unpack table from string (JSON+Gzip+Base64)
---@param str string
---@return table|love.Data|nil
function STRING.unpackTable(str)
    return JSON.decode(STRING.unpackText(str))
end

return STRING
