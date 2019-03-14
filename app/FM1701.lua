module(...,package.seeall)
require "log"

require "utils"
require"string"
require"ntp"
require"mymath"

local buffer	=	{}
local UID		=	{}


local Format_table={}
Format_table[0x0]	=	string.fromHex("00")
Format_table[0x1]	=	string.fromHex("01")
Format_table[0x2]	=	string.fromHex("02")
Format_table[0x3]	=	string.fromHex("03")
Format_table[0x4]	=	string.fromHex("04")
Format_table[0x5]	=	string.fromHex("05")
Format_table[0x6]	=	string.fromHex("06")
Format_table[0x7]	=	string.fromHex("07")
Format_table[0x8]	=	string.fromHex("08")
Format_table[0x9]	=	string.fromHex("09")
Format_table[0xA]	=	string.fromHex("0A")
Format_table[0xB]	=	string.fromHex("0B")
Format_table[0xC]	=	string.fromHex("0C")
Format_table[0xD]	=	string.fromHex("0D")
Format_table[0xE]	=	string.fromHex("0E")
Format_table[0xF]	=	string.fromHex("0F")


local Command_table={}
-- FM1715命令码 
Command_table["Transceive"]	=	0x1E			-- 发送接收命令 */
Command_table["Transmit"]	=	0x1a			-- 发送命令 */
Command_table["ReadE2"]		=	0x03			--/* 读FM1715 EEPROM命令 */
Command_table["WriteE2"]	=	0x01			--/* 写FM1715 EEPROM命令 */
Command_table["Authent1"]	=	0x0c			--/* 验证命令认证过程第1步 */
Command_table["Authent2"]	=	0x14			--/* 验证命令认证过程第2步 */
Command_table["LoadKeyE2"]	=	0x0b			--/* 将密钥从EEPROM复制到KEY缓存 */
Command_table["LoadKey"]	=	0x19			--/* 将密钥从FIFO缓存复制到KEY缓存 */
--//#define RF_TimeOut	0xfff			/* 发送命令延时时间 */
Command_table["RF_TimeOut"]	=	0x7f
Command_table["Req"]		=   0x01
Command_table["Sel"]		=   0x02


--[[
/* 卡片类型定义定义 */
#define TYPEA_MODE	    0			/* TypeA模式 */
#define TYPEB_MODE	    1			/* TypeB模式 */
#define SHANGHAI_MODE	2			/* 上海模式 */
#define TM0_HIGH	    0xf0		/* 定时器0高位,4MS定时 */
#define TM0_LOW		    0x60		/* 定时器0低位 */
#define TIMEOUT		    100			/* 超时计数器4MS×100=0.4秒 */
]]


--/* 射频卡通信命令码定义 */
Command_table["RF_CMD_REQUEST_STD"]	=	0x26
Command_table["RF_CMD_REQUEST_ALL"]	=	0x52
Command_table["RF_CMD_ANTICOL"]		=	0x93
Command_table["RF_CMD_SELECT"]		=	0x93
Command_table["RF_CMD_AUTH_LA"]		=	0x60
Command_table["RF_CMD_AUTH_LB"]		=	0x61
Command_table["RF_CMD_READ"]		=   0x30
Command_table["RF_CMD_WRITE"]		=	0xa0
Command_table["RF_CMD_INC"]		    =	0xc1
Command_table["RF_CMD_DEC"]		    =	0xc0
Command_table["RF_CMD_RESTORE"]		=	0xc2
Command_table["RF_CMD_TRANSFER"]	=	0xb0
Command_table["RF_CMD_HALT"]		=   0x50

--[[/* Status Values */
#define ALL	    0x01
#define KEYB	0x04
#define KEYA	0x00
#define _AB	    0x40
#define CRC_A	1
#define CRC_B	2
#define CRC_OK	0
#define CRC_ERR 1
#define BCC_OK	0
#define BCC_ERR 1

/* 卡类型定义 */
#define MIFARE_8K	    0			/* MIFARE系列8KB卡片 */
#define MIFARE_TOKEN	1			/* MIFARE系列1KB TOKEN卡片 */
#define SHANGHAI_8K	    2			/* 上海标准系列8KB卡片 */
#define SHANGHAI_TOKEN	3			/* 上海标准系列1KB TOKEN卡片 */
]]


--[[/* 函数错误代码定义 */]]
local RFIDerr_code	=	{}
RFIDerr_code["FM1715_OK"]		    	=	0		--/* 正确 */
RFIDerr_code["FM1715_NOTAGERR"]			=	1		--/* 无卡 */
RFIDerr_code["FM1715_CRCERR"]			=	2		--/* 卡片CRC校验错误 */
RFIDerr_code["FM1715_EMPTY"]			=	3		--/* 数值溢出错误 */
RFIDerr_code["FM1715_AUTHERR"]			=	4		--/* 验证不成功 */
RFIDerr_code["FM1715_PARITYERR"]		=	5		--/* 卡片奇偶校验错误 */
RFIDerr_code["FM1715_CODEERR"]			=	6		--/* 通讯错误(BCC校验错) */
RFIDerr_code["FM1715_SERNRERR"]			=	8		--/* 卡片序列号错误(anti-collision 错误) */
RFIDerr_code["FM1715_SELECTERR"]		=	9		--/* 卡片数据长度字节错误(SELECT错误) */
RFIDerr_code["FM1715_NOTAUTHERR"]		=	10		--/* 卡片没有通过验证 */
RFIDerr_code["FM1715_BITCOUNTERR"]		=	11		--/* 从卡片接收到的位数错误 */
RFIDerr_code["FM1715_BYTECOUNTERR"]		=	12		--/* 从卡片接收到的字节数错误仅读函数有效 */
RFIDerr_code["FM1715_RESTERR"]			=	13		--/* 调用restore函数出错 */
RFIDerr_code["FM1715_TRANSERR"]			=	14		--/* 调用transfer函数出错 */
RFIDerr_code["FM1715_WRITEERR"]			=	15		--/* 调用write函数出错 */
RFIDerr_code["FM1715_INCRERR"]			=	16		--/* 调用increment函数出错 */
RFIDerr_code["FM1715_DECRERR"]			=	17		--/* 调用decrement函数出错 */
RFIDerr_code["FM1715_READERR"]			=	18		--/* 调用read函数出错 */
RFIDerr_code["FM1715_LOADKEYERR"]		=	19		--/* 调用LOADKEY函数出错 */
RFIDerr_code["FM1715_FRAMINGERR"]		=	20		--/* FM1715帧错误 */
RFIDerr_code["FM1715_REQERR"]			=	21		--/* 调用req函数出错 */
RFIDerr_code["FM1715_SELERR"]			=	22		--/* 调用sel函数出错 */
RFIDerr_code["FM1715_ANTICOLLERR"]		=	23		--/* 调用anticoll函数出错 */
RFIDerr_code["FM1715_INTIVALERR"]		=	24		--/* 调用初始化函数出错 */
RFIDerr_code["FM1715_READVALERR"]		=	25		--/* 调用高级读块值函数出错 */
RFIDerr_code["FM1715_DESELECTERR"]		=	26
RFIDerr_code["FM1715_CMD_ERR"]			=	42		--/* 命令错误 */


--寄存器
Command_table["Page_Sel"]			=	0x00	--/* 页写寄存器 */
Command_table["Command"]			=	0x01	--/* 命令寄存器 */
Command_table["FIFO"]				=	0x02	--/* 64字节FIFO缓冲的输入输出寄存器 */
Command_table["PrimaryStatus"]		=	0x03	--/* 发射器接收器及FIFO的状态寄存器1 */
Command_table["FIFO_Length"]		=	0x04	--/* 当前FIFO内字节数寄存器 */
Command_table["SecondaryStatus"]	=	0x05	--/* 各种状态寄存器2 */
Command_table["InterruptEn"]		=	0x06	--/* 中断使能/禁止寄存器 */
Command_table["Int_Req"]			=	0x07	--/* 中断请求标识寄存器 */
Command_table["Control"]			=	0x09	--/* 控制寄存器 */
Command_table["ErrorFlag"]			=	0x0A	--/* 错误状态寄存器 */
Command_table["CollPos"]			=	0x0B	--/* 冲突检测寄存器 */
Command_table["TimerValue"]			=	0x0c	--/* 定时器当前值 */
Command_table["Bit_Frame"]			=	0x0F	--/* 位帧调整寄存器 */
Command_table["TxControl"]			=	0x11	--/* 发送控制寄存器 */
Command_table["CWConductance"]		=	0x12	--/* 选择发射脚TX1和TX2发射天线的阻抗 */
Command_table["ModConductance"]		=	0x13	--/* 定义输出驱动阻抗 */
Command_table["CoderControl"]		=	0x14	--/* 定义编码模式和时钟频率 */
Command_table["TypeBFraming"]		=	0x17	--/* 定义ISO14443B帧格式 */
Command_table["DecoderControl"]		=	0x1a	--/* 解码控制寄存器 */
Command_table["Rxcontrol2"]			=	0x1e	--/* 解码控制及选择接收源 */
Command_table["RxWait"]				=	0x21	--/* 选择发射和接收之间的时间间隔 */
Command_table["ChannelRedundancy"]	=	0x22	--/* RF通道检验模式设置寄存器 */
Command_table["CRCPresetLSB"]		=	0x23
Command_table["CRCPresetMSB"]		=	0x24
Command_table["MFOUTSelect"]		=	0x26	--/* mf OUT 选择配置寄存器 */
Command_table["TimerClock"]			=	0x2a	--/* 定时器周期设置寄存器 */
Command_table["TimerControl"]		=	0x2b	--/* 定时器控制寄存器 */
Command_table["TimerReload"]		=	0x2c	--/* 定时器初值寄存器 */
Command_table["TypeSH"]				=	0x31	--/* 上海标准选择寄存器 */
Command_table["TestDigiSelect"]		=	0x3d	--/* 测试管脚配置寄存器 */










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



local function mathpow(a,b)
	local back=0
	local cnt1=1
	local cnt2=1
	
	if b == 0 then  
		return 1 
	elseif b==1	then
		return a
	end
	
	cnt1 = a
	
	for v=1,b-1  do
		cnt2=a*cnt1	
		cnt1=cnt2
	end
	
	return cnt1
end


--[[
	SPI底层函数，发送地址+数据
]]
local function senddat(add,dat)
    --拉低CS开始传输数据
    pio.pin.setval(0,pio.P0_3)

    spi.send(spi.SPI_1,add)
    spi.send(spi.SPI_1,dat)
    --传输结束拉高CS
    pio.pin.setval(1,pio.P0_3)
end


--[[
	SPI底层函数，发送命令
]]
local function Send(com)					--RFID_SPI底层发送函数，CS位为GPIO_03
    --拉低CS开始传输数据
    pio.pin.setval(0,pio.P0_3)

    spi.send(spi.SPI_1,com)
	local callbackdata = string.byte(spi.send_recv(spi.SPI_1,string.fromHex("00")))
    --传输结束拉高CS
    pio.pin.setval(1,pio.P0_3)
	
	return callbackdata
end

-----------------------------------------------------------功能性底层--------------------------------------------
local function Judge_Req(tabl)
	local temp1	=	tabl[1]
	local temp2	=	tabl[2]
	
	if	temp1	~=	0x00	then
		if	temp2	==	0x00	then
			return	true

		end
	end
	return false
end


local function	Save_UID(row,col,length)

	if row	==	0x00	then
		if	col	==	0x00	then
		
			for	v=1	,length+1	do
				UID[v]	=	buffer[v]
				
			end
		return	nil
		end
	end

	local	temp	=	buffer[1]
	local	temp1	=	UID[row]
	
	if	col	==	0	then
		temp1	=	0x00
		row		=	row	+	1
		
	elseif	col	==	1	then
		temp	=	mymath.ZZMathBitandOp(temp,0xfe)
		temp1	=	mymath.ZZMathBitandOp(temp1,0x01)
	elseif	col	==	2	then
		temp	=	mymath.ZZMathBitandOp(temp,0xfc)
		temp1	=	mymath.ZZMathBitandOp(temp1,0x03)		
	elseif	col	==	3	then
		temp	=	mymath.ZZMathBitandOp(temp,0xf8)
		temp1	=	mymath.ZZMathBitandOp(temp1,0x07)
	elseif	col	==	4	then
		temp	=	mymath.ZZMathBitandOp(temp,0xf0)
		temp1	=	mymath.ZZMathBitandOp(temp1,0x0f)
	elseif	col	==	5	then
		temp	=	mymath.ZZMathBitandOp(temp,0xe0)
		temp1	=	mymath.ZZMathBitandOp(temp1,0x1f)
	elseif	col	==	6	then
		temp	=	mymath.ZZMathBitandOp(temp,0xc0)
		temp1	=	mymath.ZZMathBitandOp(temp1,0x3f)
	elseif	col	==	7	then
		temp	=	mymath.ZZMathBitandOp(temp,0x80)
		temp1	=	mymath.ZZMathBitandOp(temp1,0x7f)
	end
	
	buffer[1]	=	temp
	
	local	cnt1=0
	local	cnt2=0
	local	cnt3=0

	UID[row]	=	mymath.ZZMathBitorOp(temp,temp1)

	
	for v = 1,length  do
		UID[row+v]	=	buffer[v+1]
	end
	
end

local function	Check_UID()

	local	temp	=	0x00
	
	for v=1,5 do
	
		temp=mymath.ZZMathBitxorOp(temp,UID[v])
	
	end
	
	if temp	==	0	then
		return true
	end
	
	return false
end	




local function 	M500HostCodeKey(uncoded, coded)

	local ln = 0
	local hn = 0
	
	for v=1,6 do
		ln	=	mymath.ZZMathBitandOp(uncoded[v],0x0f)          --取低四位
		hn	=	mymath.ZZMath8BitrShiftOp(uncoded[v],4)			--取高四位
	
		--coded[v * 2]		=	mymath.ZZMathBitorOp(mymath.ZZMath8BitnotOp(mymath.ZZMath8BitlShiftOp(ln,4)),ln)
		--coded[v * 2 - 1]	=	mymath.ZZMathBitorOp(mymath.ZZMath8BitnotOp(mymath.ZZMath8BitlShiftOp(hn,4)),hn)
	
		coded[v * 2]		=	mymath.ZZMathBitorOp(mymath.ZZMath8BitlShiftOp(mymath.ZZMath8BitnotOp(ln),4),ln)
		coded[v * 2	-  1]	=	mymath.ZZMathBitorOp(mymath.ZZMath8BitlShiftOp(mymath.ZZMath8BitnotOp(hn),4),hn)
		
	end


	return RFIDerr_code["FM1715_OK"]
end


--[[
	SPI底层函数，初始化SPI
]]
local function init()
    --打开SPI引脚的供电
    pmd.ldoset(7,pmd.LDO_VMMC) 
    	
    local result = spi.setup(spi.SPI_1,1,1,8,110000,1)
	
    log.info("testSpiRFID.init",result)
    
    --重新配置GPIO3 (CS脚) 配为输出,默认高电平
    pio.pin.close(pio.P0_3)
    pio.pin.setdir(pio.OUTPUT,pio.P0_3)
    pio.pin.setval(1,pio.P0_3)
	
	
	
	--pio.pin.setval(1,pio.P0_8)


end


--[[
	FM1702底层函数，向FM1702发送地址，并读取寄存器值
]]
local function read_reg(adr)

	local callbackdata
    local temp,temp1     		--temp number
	
	
	temp  = adr * 2     		--左移一位
	temp1 = temp %256   		--取低八位
	
	if temp1  <= 127  then                    --保证最高位为1
		temp1	=	temp1	+	128
	end
	              
	
	if temp1 > 0xF then 
		local adr_send	=	string.fromHex(string.format("%x",temp1))   --十六进制格式输出
		callbackdata	=	Send(adr_send)
	else
		callbackdata	=	Send(Format_table[temp1])
	end

	return callbackdata
	
end

--[[
	FM1702底层函数，发送地址+数据
]]
local function write_reg(adr,dat)
	
    local temp,temp1     					  --temp number
	
	
	temp  = adr * 2 			  --左移一位
	temp1 = temp %256   		  --取低八位
	
	if temp1  > 127  then                    --保证最高位为0
		temp1	=	temp1	-	128
	end
	
	
	
	local adr_send	=	string.fromHex(string.format("%x",temp1))   --十六进制格式输出
	
	local data  =	string.fromHex(string.format("%x",dat))
    
	
	
	
	if temp1 > 0xF   then
		if  dat  >0xF	then
			senddat(adr_send,data)		--SPI发送数据
		else
			senddat(adr_send,Format_table[dat])
		end
	else
		if dat > 0xF then
			senddat(Format_table[temp1],data)
		else
			senddat(Format_table[temp1],Format_table[dat])
		end
	end
	
end




------------------------------------FIFO相关函数----------------------------------

--[[
	FM1702底层函数，清空FIFO
]]
local function Clear_FIFO()

	local temp	=	read_reg(Command_table["Control"])	--清空FIFO
	
	if temp%2	==	0	then			--	保证最低位为1
		temp	=	temp	+	1
	end

	write_reg(Command_table["Control"],temp)
	
	for v=1,Command_table["RF_TimeOut"]	do	--检查FIFO是否被清空
		temp	=	read_reg(Command_table["FIFO_Length"])
		if	temp	==	0	then
			return	true
		end
	end
	return	false	
end

--[[
	FM1702底层函数，写入FIFO										
]]
local function Write_FIFO(count,tabl)

	for v=1,count do
		write_reg(Command_table["FIFO"],tabl[v])
	end

end

--[[
	FM1702底层函数，读取FIFO										
]]

local function Read_FIFO(tabl)

	local temp	=	read_reg(Command_table["FIFO_Length"])
	if temp	==	0	then
		return	0
	elseif temp>=	24	then
		temp	=	24
	end

	for v=1,temp	do
		tabl[v]	=	read_reg(Command_table["FIFO"])
	end

	return temp
end


------------------------------------命令相关函数---------------------------------------
--[[
	FM1702底层函数，发送操作命令
]]
local function	Command_send(count,tabl,Com)
	
	write_reg(Command_table["Command"],0x00)
	
	Clear_FIFO()
	
	if count	~=	0 then
		Write_FIFO(count,tabl)
	end

	local	temp	=	read_reg(Command_table["FIFO_Length"])
	
	write_reg(Command_table["Command"],Com)		--执行命令
	
	for v=1,Command_table["RF_TimeOut"] do		--检查命令是否执行
	
		temp	=	read_reg(Command_table["Command"])
		if	temp	==	0x00	then
			return	true
		end
		
	end

	return	false
	
end



local function	Set_BitFraming(row,col)

	local	cnt1	=	0
	local	cnt2	=	0
	local	cnt3	=	0


	if	row	==	0	then
		buffer	[2]	=	0x20
	elseif	row	==	1	then
		buffer	[2]	=	0x30
	elseif	row	==	2	then
		buffer	[2]	=	0x40
	elseif	row	==	3	then
		buffer	[2]	=	0x50
	elseif	row	==	4	then
		buffer	[2]	=	0x60
	end
	
	if	col	==	0	then
		write_reg(0x0F,0x00)
		
		
	elseif	col	==	1	then
		write_reg(0x0F,0x11)
		
		cnt1	=	buffer[2]%2
		if	cnt1	==	0	then
			buffer[2]	=	buffer[2]	+	1			--	|=0x01		位运算
		end
		
		
	elseif	col	==	2	then
		write_reg(0x0F,0x22)
		
		cnt2	=	math.floor(buffer[2]/2)%2			--	|=0x02
		if	cnt2	==	0	then
			buffer[2]	=	buffer[2]	+	2
		end
	
	elseif	col	==	3	then
		write_reg(0x0F,0x33)

		cnt1	=	buffer[2]%2							--	|=0x03
		cnt2	=	math.floor(buffer[2]/2)%2
		if	cnt1	==	0	then
			buffer[2]	=	buffer[2]	+	1
		end
		if  cnt2	==	0	then
			buffer[2]	=	buffer[2]	+	2
		end

	
	elseif	col	==	4	then
		write_reg(0x0F,0x44)							--	|=0x04
		cnt3	=	math.floor(buffer[2]/4)%2
		if	cnt3	==	0	then
			buffer[2]	=	buffer[2]	+	4
		end
	
	elseif	col	==	5	then							--	|=0x05
		write_reg(0x0F,0x55)
		
		cnt1	=	buffer[2]%2
		cnt3	=	math.floor(buffer[2]/4)%2
		if	cnt1	==	0	then
			buffer[2]	=	buffer[2]	+	1
		end
		if	cnt3	==	0	then
			buffer[2]	=	buffer[2]	+	4
		end
	
	elseif	col	==	6	then							--	|=0x06
		write_reg(0x0F,0x66)

		cnt2	=	math.floor(buffer[2]/2)%2
		cnt3	=	math.floor(buffer[2]/4)%2
		if	cnt2	==	0	then
			buffer[2]	=	buffer[2]	+	2
		end
		if	cnt3	==	0	then
			buffer[2]	=	buffer[2]	+	4
		end
	
	elseif	col	==	7	then							--	|=0x07
		write_reg(0x0F,0x77)
		
		cnt1	=	buffer[2]%2
		cnt2	=	math.floor(buffer[2]/2)%2
		cnt3	=	math.floor(buffer[2]/4)%2
		if	cnt1	==	0	then
			buffer[2]	=	buffer[2]	+	1
		end
		if	cnt2	==	0	then
			buffer[2]	=	buffer[2]	+	2
		end
		if	cnt3	==	0	then
			buffer[2]	=	buffer[2]	+	4
		end
	
	end

end


------------------------------------应用层函数---------------------------------------
--[[
	FM1702应用层函数，初始化FM1702
]]
function RFID_init()

	init()
	
	local rec	=	read_reg(0x05)
	
	while rec ~= 0x60 do
		rec	=	read_reg(0x05)
	end
	
	print("Choose BUS")
	
	write_reg(Command_table["Page_Sel"],0x80)						--RFID总线选择
	
	for v=1,Command_table["RF_TimeOut"]	do
		local	temp	=	read_reg(Command_table["Command"])
		
		print("The type of recv:",type(temp))
		
		if	temp	==	0x00 then
			write_reg(Command_table["Page_Sel"],0x00)
			log.info("RFID_init","RFID Initial Success!")
			return	nil
		end
	
	end
	
	log.error("RFID_init","RFID Initial Faild! Redo!")
	
	RFID_init()
end



--[[
	FM1702应用层函数，寻卡
]]

function	Request(mode)

	write_reg(Command_table["TxControl"],0x58)
	write_reg(Command_table["TxControl"],0x5b)
	write_reg(Command_table["CRCPresetLSB"],0x63)
	write_reg(Command_table["CWConductance"],0x3f)
	write_reg(Command_table["Bit_Frame"],0x07)
	write_reg(Command_table["ChannelRedundancy"],0x03)
	write_reg(Command_table["TxControl"],0x5b)
	write_reg(Command_table["Control"],0x01)
	
	buffer[1]	=	mode
	local	temp	=	Command_send(1,buffer,Command_table["Transceive"])
	
	if temp	== false	then
		return	RFIDerr_code["FM1715_NOTAGERR"]
	end

	Read_FIFO(buffer)
	
	temp	=	Judge_Req(buffer)
	
	if	temp	==	true	then
	
		return RFIDerr_code["FM1715_OK"]
	end
	
	return	RFIDerr_code["FM1715_READERR"]
end


--[[
	FM1702应用层函数，冲突检测
]]
function AntiColl()

	local	row	=	0
	local	col	=	0
	local	pre_row	=	0
	
	write_reg(0x23,0x63)
	write_reg(0x12,0x3f)
	write_reg(0x13,0x3f)
	buffer[1]	=	Command_table["RF_CMD_ANTICOL"]
	buffer[2]	=	0x20
	write_reg(0x22,0x03)
	local	temp	=	Command_send(2,buffer,Command_table["Transceive"])
	
	while true do
		if temp	==	false then
			return RFIDerr_code["FM1715_NOTAGERR"]
		end
	
		temp	=	read_reg(0x04)			--有卡的话temp为5
		
		if temp == 0 then
			return	RFIDerr_code["FM1715_BYTECOUNTERR"]
		end
	
		Read_FIFO(buffer)
		
		
		Save_UID(row,col,temp)

		

	
		temp	=	read_reg(0x0A)
		if	temp%2	==	0	then	temp	=	0	else	temp	=	1	end
		
			
		if	temp	==	0x00	then
		
			temp	=	Check_UID()
			
			if	temp	==	false	then
			
				return	RFIDerr_code["FM1715_SERNRERR"]
			end
						
			return	RFIDerr_code["FM1715_OK"]
		
		else
		
			temp	=	read_reg(0x0B)
			
			row	=	math.floor(temp/8)
			col	=	math.floor(temp%8)
			buffer[1]	=	RFIDerr_code["RF_CMD_ANTICOL"]
			
			Set_BitFraming(row+pre_row,col)
			
			pre_row	=	pre_row	+	row
			
			for v=1,pre_row+2 do
				buffer[v+2]	=	UID[v]
			end
			
			if col	~=	0x00	then
				row	=	pre_row	+	1
			
			else
				row	=	pre_row
			end
			temp	=	Command_send(row+2,buffer,Command_table["Transceive"])
			
		end
		
	
	end
end


--[[
	FM1702应用层函数，选卡
]]
function Select_Card()

	write_reg(0x23,0x63)
	write_reg(0x12,0x3f)
	buffer[1]	=	Command_table["RF_CMD_SELECT"]
	buffer[2]	=	0x70
	
	for v=1,6 do
		buffer[v+2]	=	UID[v]
	end

	write_reg(0x22,0x0f)
	local temp	=	Command_send(7,buffer,Command_table["Transceive"])
	if	temp	==	false	then
		return	RFIDerr_code["FM1715_NOTAGERR"]
	else
	
		temp	=	read_reg(0x0a)		
		if mymath.ZZMathBitandOp(temp,0x02)	==	0x02 then return RFIDerr_code["FM1715_PARITYERR"]	end
		if mymath.ZZMathBitandOp(temp,0x04)	==	0x04 then return RFIDerr_code["FM1715_FRAMINGERR"]	end
		if mymath.ZZMathBitandOp(temp,0x08)	==	0x08 then return RFIDerr_code["FM1715_CRCERR"]	end


		temp	=	read_reg(0x04)
		if temp ~= 1 then  return RFIDerr_code["FM1715_BYTECOUNTERR"]  end
		
		
		Read_FIFO(buffer)
		if	buffer[1]	==	0x08	then
			return	RFIDerr_code["FM1715_OK"]
		
		elseif	buffer[1]	==	0x88	then
			return	RFIDerr_code["FM1715_OK"]
		
		elseif	buffer[1]	==	0x53	then
			return	RFIDerr_code["FM1715_OK"]
		
		elseif	buffer[1]	==	0x18	then
			return	RFIDerr_code["FM1715_OK"]
		
		else
			return	RFIDerr_code["FM1715_SELERR"]

		end
		
	end

end

--[[
	FM1702应用层函数，加载密码
]]
function Load_keyE2_CPY(uncoded_keys)

	local coded_keys={0,0,0,0,0,0,0,0,0,0,0,0}
	
	M500HostCodeKey(uncoded_keys, coded_keys)
	

	
	local temp	=	Command_send(12,coded_keys,Command_table["LoadKey"])

	log.info("the command fb:",temp)
	temp	=	mymath.ZZMathBitandOp((read_reg(0x0a))%256,0x40)
	
	if temp == 0x40 then 
		return false
	end
	return true
end

--[[
	FM1702应用层函数，验证密码
]]
function Authentication(SecNR,mode)

	write_reg(0x23,0x63)
	write_reg(0x12,0x3f)
	write_reg(0x13,0x3f)
	
	local temp1	=	read_reg(0x09)
	temp1	=	mymath.ZZMathBitandOp(temp1,0xf7)
	
	write_reg(0x09,temp1)
	if mode == Command_table["RF_CMD_AUTH_LB"] then
		buffer[1]	=	Command_table["RF_CMD_AUTH_LB"]
	else
		buffer[1]	=	Command_table["RF_CMD_AUTH_LA"]
	end
	
	buffer[2]	=	SecNR * 4 + 3
	
	for v=1,4 do 
		buffer[v+2]	=	UID[v]
		
	end
		
	write_reg(0x22,0x0f)
	local temp	=	Command_send(6,buffer,Command_table["Authent1"])
	if temp	==	false	then
		return RFIDerr_code["FM1715_NOTAGERR"]
	end
	
	temp	=	read_reg(0x0a)
	if mymath.ZZMathBitandOp(temp,0x02)	==	0x02 then return RFIDerr_code["FM1715_PARITYERR"]	end
	if mymath.ZZMathBitandOp(temp,0x04)	==	0x04 then return RFIDerr_code["FM1715_FRAMINGERR"]	end
	if mymath.ZZMathBitandOp(temp,0x08)	==	0x08 then return RFIDerr_code["FM1715_CRCERR"]	end
	
	temp	=	Command_send(0,buffer,Command_table["Authent2"])
	if temp	==	false	then 	return 	RFIDerr_code["FM1715_NOTAGERR"] end
	
	temp	=	read_reg(0x0a)
	if mymath.ZZMathBitandOp(temp,0x02)	==	0x02 then return RFIDerr_code["FM1715_PARITYERR"]	end
	if mymath.ZZMathBitandOp(temp,0x04)	==	0x04 then return RFIDerr_code["FM1715_FRAMINGERR"]	end
	if mymath.ZZMathBitandOp(temp,0x08)	==	0x08 then return RFIDerr_code["FM1715_CRCERR"]	end
	
	temp1	=	read_reg(0x09)

	temp1	=	mymath.ZZMathBitandOp(temp1%256,0x08)
	

	
	if	temp1	==	0x08	then	
		return RFIDerr_code["FM1715_OK"] 
	
	else
		return RFIDerr_code["FM1715_AUTHERR"]
		
	end
	
	
	
end


--[[
	FM1702应用层函数，读取扇区
]]
function MIF_READ(buff, Block_Adr)

	write_reg(0x23,0x63)
	write_reg(0x12,0x3f)
	write_reg(0x13,0x3f)
	write_reg(0x22,0x0f)

	buff[1] = Command_table["RF_CMD_READ"]
	buff[2] = Block_Adr;
--[[	for v=1,2 do
		print("buff in line 941")
		print(buff[v])
	end]]
	local temp 
	temp	= Command_send(2,buff,Command_table["Transceive"])
	if temp == 0 then
		return RFIDerr_code["FM1715_NOTAGERR"]
	end

	temp = read_reg(0x0A)
	if mymath.ZZMathBitandOp(temp,0x02)	==	0x02 then return RFIDerr_code["FM1715_PARITYERR"]	end
	if mymath.ZZMathBitandOp(temp,0x04)	==	0x04 then return RFIDerr_code["FM1715_FRAMINGERR"]	end
	if mymath.ZZMathBitandOp(temp,0x08)	==	0x08 then return RFIDerr_code["FM1715_CRCERR"]	end
	
	temp = read_reg(0x04)
	if temp == 0x10 then 	--/* 8K卡读数据长度为16 */
	
		Read_FIFO(buff)
		return RFIDerr_code["FM1715_OK"]
	
	elseif temp == 0x04 then	--/* Token卡读数据长度为16 */
	
		Read_FIFO(buff)
		return RFIDerr_code["FM1715_OK"]
	
	else
	
		return RFIDerr_code["FM1715_BYTECOUNTERR"]
	
	end

end



--[[
	FM1702应用层函数，写入扇区
]]
function MIF_Write(buff, Block_Adr)

	local	temp
	local   F_buff	= {}
	write_reg(0x23,0x63)
	write_reg(0x12,0x3f)
	
--	F_buff = buff + 0x10		这条语句需要考究一下！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！！
	
	
	write_reg(0x22,0x07)
	
	F_buff[1] = Command_table["RF_CMD_WRITE"]
	
	F_buff[2] = Block_Adr
	
	temp = Command_send(2, F_buff, Command_table["Transceive"])
	
	if temp == false then
	
		return RFIDerr_code["FM1715_NOTAGERR"]
	
	end

	temp = read_reg(0x04)
	
	if temp == 0 then 
	
		return RFIDerr_code["FM1715_BYTECOUNTERR"]
	
	end

	Read_FIFO(F_buff)
	temp = F_buff[1]
	if temp == 0x00 then		return RFIDerr_code["FM1715_NOTAUTHERR"]
	
	elseif temp == 0x04 then 	return RFIDerr_code["FM1715_EMPTY"] 
	elseif temp == 0x0a then 	
	elseif temp == 0x01 then 	return RFIDerr_code["FM1715_CRCERR"]
	elseif temp == 0x05 then 	return RFIDerr_code["FM1715_PARITYERR"]
	else	return RFIDerr_code["FM1715_WRITEERR"]
	end

	temp = Command_send(16, buff, Command_table["Transceive"])
	
	if temp == true then	
		return RFIDerr_code["FM1715_OK"]
	else
	
		temp = read_reg(0x0A)
		
		if mymath.ZZMathBitandOp(temp,0x02) == 0x02 then 
			return RFIDerr_code["FM1715_PARITYERR"]
		elseif mymath.ZZMathBitandOp(temp , 0x04) == 0x04 then
			return RFIDerr_code["FM1715_FRAMINGERR"]
		elseif mymath.mymath.ZZMathBitandOp(temp , 0x08) == 0x08 then
			return RFIDerr_code["FM1715_CRCERR"]
		else
			return RFIDerr_code["FM1715_WRITEERR"]
		end
		
	end


end

require "trace"
function trace_task_start()
	RFID_init()
	
	local	password_old	=	{0x20, 0x12, 0x12, 0x14, 0x09, 0x39}
	local 	databuff		=	{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
	local   testwritebuf	=	{0x01,0x23,0x45,0x67,0x01,0x23,0x45,0x67,0x01,0x23,0x45,0x67,0x01,0x23,0x45,0x67}
	
--	local	password_old	= 	{0x34, 0xC2, 0xE6, 0x7A, 0x8D, 0x9F}
	while true do
		
		trace.init()
		trace.LED()

		spi.setup(spi.SPI_1,1,1,8,110000,1)
		local	temp	=	Request(Command_table["RF_CMD_REQUEST_ALL"])	--	寻卡
		
		if	temp	==	RFIDerr_code["FM1715_OK"]	then	--	冲突检测
			temp	=	AntiColl()
				print("A")
			if	temp	==	RFIDerr_code["FM1715_OK"]	then
				temp	=	Select_Card()
				   print("B")                                            
				if	temp	==	RFIDerr_code["FM1715_OK"]	then
					temp	=	Load_keyE2_CPY(password_old)
					print("C")
					if	temp	==	true	then 
						temp	=	Authentication(3,Command_table["RF_CMD_AUTH_LA"])
						print("D")
						if  temp	== RFIDerr_code["FM1715_OK"] then
						
							MIF_READ(databuff,12)
							MIF_Write(testwritebuf,12)
							print("I got it! The data is :")	
							for v=1,16 do
								print(databuff[v])
							end
							
						end
					end					
				end
			end
		end

		log.error("RFID_Error!Error code:",temp)
		
--[[
		
		local c=mymath.ZZMath8BitnotOp(0x10)
		print(c)
]]		
		
		print("Heartbeat")
		sys.wait(200)
	end
end


sys.taskInit(trace_task_start)

