PROJECT = "CarWasher"
VERSION = "1.0.4"


--[[
使用Luat物联云平台固件升级的功能，必须按照以下步骤操作：
1、打开Luat物联云平台前端页面：https://iot.openluat.com/
2、如果没有用户名，注册用户
3、注册用户之后，如果没有对应的项目，创建一个新项目
4、进入对应的项目，点击左边的项目信息，右边会出现信息内容，找到ProductKey：把ProductKey的内容，赋值给PRODUCT_KEY变量

PRODUCT_KEY = "NsOST9NTLvewgEvLzDAEMpO5t7fdMNSJ"

require"audio"
require"update"
update.request(
function(feedback)
	if feedback	==	true then
		log.info("Update Success!",tostring(feedback))
		sys.restart("Update success restart")
	else
		log.error("Update Error!",tostring(feedback))
		
	end
end,
nil,
600000
)
]]
--加载日志功能模块，并且设置日志输出等级
--如果关闭调用log模块接口输出的日志，等级设置为log.LOG_SILENT即可
require "log"
LOG_LEVEL = log.LOGLEVEL_TRACE

require "sys"

require "net"
--每1分钟查询一次GSM信号强度
--每1分钟查询一次基站信息
net.startQueryAll(60000, 60000)




require "wdt"
wdt.setup(pio.P0_30, pio.P0_31)


--加载网络指示灯功能模块
require "netLed"
netLed.setup(true,pio.P1_1)

--加载错误日志管理功能模块【强烈建议打开此功能】
--如下2行代码，只是简单的演示如何使用errDump功能，详情参考errDump的api
require "errDump"
errDump.request("udp://ota.airm2m.com:9072")


require "FM1701"




--启动系统框架
sys.init(0, 0)
sys.run()

