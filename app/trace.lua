module(...,package.seeall)
require "log"

require "utils"
require"string"
require"ntp"


--[[
注意：此demo测试过程中，硬件上使用的是标准的SPI_1引脚
硬件连线图如下：
Air模块--flash模块
GND--GND
SPI_CS--CS
SPI_CLK--CLK
SPI_DO--DI
SPI_DI--DO
VDDIO--VCC
]]


tabledu	    ={}
tabledu2	={}
tabledu["0"]	=		"fc"--0
tabledu["1"]	=		"60"--1
tabledu["2"]	=		"da"--2
tabledu["3"]	=		"f2"--3
tabledu["4"]	=		"66"--4
tabledu["5"]	=		"b6"--5
tabledu["6"]	=		"be"--6
tabledu["7"]	=		"e0"--7
tabledu["8"]	=		"fe"--8
tabledu["9"]	=		"f6"--9
tabledu["10"]	=		"00"-- 空 10
tabledu["11"]	=		"ce"-- p 11
tabledu["12"]	=		"02"--  - 12
tabledu2["0"]	=		"fd"--0
tabledu2["1"]	=		"61"--1
tabledu2["2"]	=		"db"--2
tabledu2["3"]	=		"f3"--3
tabledu2["4"]	=		"67"--4
tabledu2["5"]	=		"b7"--5
tabledu2["6"]	=		"bf"--6
tabledu2["7"]	=		"e1"--7
tabledu2["8"]	=		"ff"--8
tabledu2["9"]	=		"f7"--9
tabledu2["10"]	=		"00"-- 空 10
tabledu2["11"]	=		"cf"-- p 11
tabledu2["12"]	=		"03"--  - 12



local function senddat(add,dat)
    --拉低CS开始传输数据
    pio.pin.setval(0,pio.P0_10)

    spi.send(spi.SPI_1,add)
    spi.send(spi.SPI_1,dat)
    --传输结束拉高CS
    pio.pin.setval(1,pio.P0_10)
end
local function sendcom(com)
    --拉低CS开始传输数据
    pio.pin.setval(0,pio.P0_10)

    spi.send(spi.SPI_1,com)
	
    --传输结束拉高CS
    pio.pin.setval(1,pio.P0_10)
end
	


local function TM1638_init()
	sendcom(string.fromHex("40"))	
	sendcom(string.fromHex("44"))
	sendcom(string.fromHex("8f"))
	
--	senddat(string.fromHex("c0"),string.fromHex("00"))
--	senddat(string.fromHex("c2"),string.fromHex("00"))
--	senddat(string.fromHex("c4"),string.fromHex("00"))
--	senddat(string.fromHex("c6"),string.fromHex("00"))
--	senddat(string.fromHex("ce"),string.fromHex("00"))
--	senddat(string.fromHex("cc"),string.fromHex("00"))
--	senddat(string.fromHex("ca"),string.fromHex("00"))
--	senddat(string.fromHex("c8"),string.fromHex("00"))
--	print("OK++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")


end

function display(a)

	sendcom(string.fromHex("02"))	
	sendcom(string.fromHex("22"))
	sendcom(string.fromHex("f1"))
	
	senddat(string.fromHex("03"),string.fromHex(tabledu[  a[1]  ]  )  )
	senddat(string.fromHex("43"),string.fromHex(tabledu2[  a[2]  ]  )  )
	senddat(string.fromHex("23"),string.fromHex(tabledu[  a[3]  ]  )  )
	senddat(string.fromHex("63"),string.fromHex(tabledu[  a[4]  ]  )  )
	senddat(string.fromHex("73"),string.fromHex(tabledu[  a[5]  ]  )  )
	senddat(string.fromHex("33"),string.fromHex(tabledu2[  a[6]  ]  )  )
	senddat(string.fromHex("53"),string.fromHex(tabledu[  a[7]  ]  )  )
	senddat(string.fromHex("13"),string.fromHex(tabledu[  a[8]  ]  )  )
end

function display2(a)

	sendcom(string.fromHex("02"))	
	sendcom(string.fromHex("22"))
	sendcom(string.fromHex("f1"))
	
	senddat(string.fromHex("03"),string.fromHex(tabledu[  a[1]  ]  )  )
	senddat(string.fromHex("43"),string.fromHex(tabledu[  a[2]  ]  )  )
	senddat(string.fromHex("23"),string.fromHex(tabledu[  a[3]  ]  )  )
	senddat(string.fromHex("63"),string.fromHex(tabledu2[  a[4]  ]  )  )
	senddat(string.fromHex("73"),string.fromHex(tabledu[  a[5]  ]  )  )
	senddat(string.fromHex("33"),string.fromHex(tabledu[  a[6]  ]  )  )
	senddat(string.fromHex("53"),string.fromHex(tabledu[  a[7]  ]  )  )
	senddat(string.fromHex("13"),string.fromHex(tabledu[  a[8]  ]  )  )
end


function init()
    --打开SPI引脚的供电
    pmd.ldoset(7,pmd.LDO_VMMC) 
    	
    local result = spi.setup(spi.SPI_1,0,1,8,110000,0)
	
    log.info("testSpiScreen.init",result)
    
    --重新配置GPIO10 (CS脚) 配为输出,默认高电平
    pio.pin.close(pio.P0_10)
    pio.pin.setdir(pio.OUTPUT,pio.P0_10)
    pio.pin.setval(1,pio.P0_10)
	
    TM1638_init()
end



function LED()
	b={}
	a={}
	
	--a	=	misc.getClock()
	
	
	if false	then
		b[1]	=	tostring(a.month/10%10)
		b[2]	=	tostring(a.month/1%10)
		b[3]	=	tostring(a["day"]/10%10)
		b[4]	=	tostring(a["day"]/1%10)
		b[5]	=	tostring(a.hour/10%10)
		b[6]	=	tostring(a.hour/1%10)
		b[7]	=	tostring(a.min/10%10)
		b[8]	=	tostring(a.min/1%10)
		display(b)
	
	
	
	else
	
		b[1]	=	"1"
		b[2]	=	"2"
		b[3]	=	"3"
		b[4]	=	"4"
		b[5]	=	"5"
		b[6]	=	"6"
		b[7]	=	"7"
		b[8]	=	"8"
		display(b)
	
	end
	a=nil
	b=nil
end


local function trace_log()
		log.info("Version:",_G.VERSION)

end


--[[
function trace_task_start()
	
	init()
	
	while true do
		
		
		trace_log()
		
		
		LED()
		
		sys.wait(200)
	
	end
end

function time_get()
ntp.timeSync(1) 
end

sys.taskInit(time_get)
sys.taskInit(trace_task_start)
]]
