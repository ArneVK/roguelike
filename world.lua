HC = require 'lib.HC'
--[[
           ______,      ___    _            __   , __     _     ____
          (_) | /|   | / (_)  (_|   |   |_//\_\//|/  \ \_|_)   (|   \
              |  |___| \__      |   |   | |    | |___/   |      |    |
            _ |  |   |\/        |   |   | |    | | \    _|     _|    |
           (_/   |   |/\___/     \_/ \_/   \__/  |  \_/(/\___/(/\___/
                              (za warudo)
]]

local World = HC.new()


function World:addToWorld(item, shape, ...)
  if shape == 'rectangle' then
    item.hitShape = self:rectangle(...)
  elseif shape == 'circle' then
    item.hitShape = self:circle(...)
  elseif shape == 'polygon' then
    item.hitShape = self:polygon(...)
  end
  item.col = true
end

function World:removeFromWorld(item)
  item.col = false
  self:remove(item.hitShape)
end

return World
