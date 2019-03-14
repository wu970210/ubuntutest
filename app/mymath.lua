module(...,package.seeall)
require "log"
require "string"


--与   同为1，则为1
 
--或   有一个为1，则为1  

--非   true为 false，其余为true

--异或 相同为0，不同为1


--ZZMathBit = {}

function ZZMathBitandBit(left,right)    --与
    return (left == 1 and right == 1) and 1 or 0
end

function ZZMathBitorBit(left, right)    --或
    return (left == 1 or right == 1) and 1 or 0
end

function ZZMathBitxorBit(left, right)   --异或
    return (left + right) == 1 and 1 or 0
end

function ZZMathBitbase(left, right, op) --对每一位进行op运算，然后将值返回
    if left < right then
        left, right = right, left
    end
    local res = 0
    local shift = 1
    while left ~= 0 do
        local ra = left % 2    --取得每一位(最右边)
        local rb = right % 2   
        res = shift * op(ra,rb) + res
        shift = shift * 2
        left = math.floor( left / 2)  --右移
        right = math.floor( right / 2)
    end
    return res
end




function ZZMathBitandOp(left, right)
    return ZZMathBitbase(left, right, ZZMathBitandBit)
end

function ZZMathBitxorOp(left, right)
    return ZZMathBitbase(left, right, ZZMathBitxorBit)
end

function ZZMathBitorOp(left, right)
    return ZZMathBitbase(left, right, ZZMathBitorBit)
end

function ZZMathBitnotOp(left)
    return left > 0 and -(left + 1) or -left - 1
end

function ZZMathBitlShiftOp(left, num)  --left左移num位
    return left * (2 ^ num)
end

function ZZMathBitrShiftOp(left,num)  --right右移num位
    return math.floor(left / (2 ^ num))
end




function ZZMath8BitnotOp(left)

    local res = 0
    local shift = 1
    for v=1,8 do
        local ra = left % 2    --取得每一位(最右边)

		if ra == 1 then ra = 0 
		else ra = 1 end

        res = shift * ra + res
        shift = shift * 2
        left = math.floor( left / 2)  --右移
    end
    return res
end

function ZZMath8BitlShiftOp(left, num)  --left左移num位
    return (left * (2 ^ num))%256
end



function ZZMath8BitrShiftOp(left,num)  --right右移num位
    return math.floor(left / (2 ^ num))
end
