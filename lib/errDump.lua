--- 模块功能：系统错误日志管理(强烈建议用户开启此模块的“错误日志上报调试服务器”功能).
-- 错误日志包括三种：
-- 1、系统主任务运行时的错误日志
--    此类错误会导致软件重启，错误日志保存在/luaerrinfo.txt文件中
-- 2、调用sys.taskInit创建的协程运行过程中的错误日志
--    此类错误会终止当前协程的运行，但是不会导致软件重启，错误日志保存在/lib_err.txt中
-- 3、调用errDump.appendErr或者sys.restart接口保存的错误日志
--    此类错误日志保存在/lib_err.txt中
--
-- 其中2和3保存的错误日志，最多支持5K字节
-- 每次上报错误日志给调试服务器之后，会清空已保存的日志
-- @module errDump
-- @author openLuat
-- @license MIT
-- @copyright openLuat
-- @release 2017.09.26
require"socket"
require"misc"
module(..., package.seeall)

--错误信息文件以及错误信息内容
local LIB_ERR_FILE,libErr,LIB_ERR_MAX_LEN = "/lib_err.txt","",5*1024
local LUA_ERR_FILE,luaErr = "/luaerrinfo.txt",""
local sReporting,sProtocol,sWritingFile

-- 初始化LIB_ERR_FILE文件中的错误信息(读取到内存中，并且打印出来)
-- @return nil
-- @usage readTxt.initErr()
local function initErr()
    libErr = io.readFile(LIB_ERR_FILE) or ""
    if libErr~="" then
        log.error("errDump.libErr", libErr)
    end

    luaErr = io.readFile(LUA_ERR_FILE) or ""
    if luaErr~="" then
        log.error("errDump.luaErr", luaErr)
    end
end


--- 追加错误信息到LIB_ERR_FILE文件中（文件最多允许存储5K字节的数据）
-- @string s：用户自定义的错误信息，errDump功能模块会对此错误信息做如下处理：
-- 1、重启后会通过Luat下载调试工具输出，在trace中搜索errDump.libErr，可以搜索到错误信息
-- 2、如果用户调用errDump.request接口设置了错误信息要上报的调试服务器地址和端口，则每次重启会自动上报错误信息到调试服务器
-- 3、如果用户调用errDump.request接口设置了定时上报，则定时上报时会上报错误信息到调试服务器
-- 其中第2和第3种情况，上报成功后，会自动清除错误信息
-- @return bool result，true表示成功，false或者nil表示失败
-- @usage errDump.appendErr("net working timeout!")
function appendErr(s)
    if s and (s:len()+libErr:len())<=LIB_ERR_MAX_LEN then
        s=s.."\r\n"
        log.info("errDump.appendErr", s)
        libErr = libErr .. s
        sWritingFile = true
        local result = io.writeFile(LIB_ERR_FILE, libErr)
        sWritingFile = false
        return result
    end
end

local function reportData()
    return _G.PROJECT.."_"..rtos.get_version()..",".._G.VERSION..","..misc.getImei()..","..misc.getSn()..","..luaErr..(luaErr:len()>0 and "\r\n" or "")..libErr
end

local function httpPostCbFnc(result,statusCode)
    log.info("errDump.httpPostCbFnc",result,statusCode)
    sys.publish("ERRDUMP_HTTP_POST",result,statusCode)
end

function clientTask(protocol,addr,period)
    sReporting = true
    while true do
        if not socket.isReady() then sys.waitUntil("IP_READY_IND") end
        --log.info("errDump.clientTask","err",luaErr~="" or libErr~="")
        if luaErr~="" or libErr~="" then
            local retryCnt,result,data = 0
            while true do
                if protocol=="http" then
                    http.request("POST",addr,nil,nil,reportData(),20000,httpPostCbFnc)                     
                    _,result = sys.waitUntil("ERRDUMP_HTTP_POST")
                else
                    local host,port = addr:match("://(.+):(%d+)$")
                    if not host then log.error("errDump.request invalid host port") return end
                    
                    local sck = protocol=="udp" and socket.udp() or socket.tcp()
                    
                    if sck:connect(host,port) then
                        result = sck:send(reportData())
                        if result and protocol=="udp" then
                            result,data = sck:recv(20000)
                            if result then
                                result = data=="OK"
                            end
                        end
                    end
                    
                    sck:close()
                end
                
                if result then
                    if not sWritingFile then
                        libErr = ""
                        os.remove(LIB_ERR_FILE)
                    end
                    luaErr = ""
                    os.remove(LUA_ERR_FILE)
                    break
                else
                    retryCnt = retryCnt+1
                    if retryCnt==3 then
                        break
                    end
                    sys.wait(5000)
                end
            end
        end
        
        if period then
            --log.info("errDump.clientTask","wait",period)
            sys.wait(period)
        else
            break
        end
    end
    sReporting = false
end

--- 配置调试服务器地址，启动错误信息上报给调试服务器的功能，上报成功后，会清除错误信息
-- @string addr，调试服务器地址信息，支持http，udp，tcp
-- 1、如果调试服务器使用http协议，终端将采用POST命令，把错误信息上报到addr指定的URL中，addr的格式如下
--   (除protocol和hostname外，其余字段可选；目前的实现不支持hash)
--   |------------------------------------------------------------------------------|
--   | protocol |||   auth    |      host       |           path            | hash  |
--   |----------|||-----------|-----------------|---------------------------|-------|
--   |          |||           | hostname | port | pathname |     search     |       |
--   |          |||           |----------|------|----------|----------------|       |
--   "   http   :// user:pass @ host.com : 8080   /p/a/t/h ?  query=string  # hash  " 
--   |          |||           |          |      |          |                |       |
--   |------------------------------------------------------------------------------|
-- 2、如果调试服务器使用udp协议，终端将错误信息，直接上报给调试服务器，调试服务器收到信息后，要回复大写的OK；addr格式如下：
--   |----------|||----------|------|
--   | protocol ||| hostname | port |
--   |          |||----------|------|
--   "   udp    :// host.com : 8081 | 
--   |          |||          |      |
--   |------------------------------|
-- 3、如果调试服务器使用tcp协议，终端将错误信息，直接上报给调试服务器；addr格式如下：
--   |----------|||----------|------|
--   | protocol ||| hostname | port |
--   |          |||----------|------|
--   "   tcp    :// host.com : 8082 | 
--   |          |||          |      |
--   |------------------------------|
-- @number[opt=600000] period，单位毫秒，定时检查错误信息并上报的间隔
-- @return bool result，成功返回true，失败返回nil
-- @usage
-- errDump.request("http://www.user_server.com/errdump")
-- errDump.request("udp://www.user_server.com:8081")
-- errDump.request("tcp://www.user_server.com:8082")
-- errDump.request("tcp://www.user_server.com:8082",6*3600*1000)
function request(addr,period)
    local protocol = addr:match("(%a+)://")
    if protocol~="http" and protocol~="udp" and protocol~="tcp" then
        log.error("errDump.request invalid protocol",protocol)
        return
    end
    
    if not sReporting then        
        sys.taskInit(clientTask,protocol,addr,period or 600000)
    end
    return true
end

initErr()
