local HC = require 'lib.HC'
--[[
           ______,      ___    _            __   , __     _     ____
          (_) | /|   | / (_)  (_|   |   |_//\_\//|/  \ \_|_)   (|   \
              |  |___| \__      |   |   | |    | |___/   |      |    |
            _ |  |   |\/        |   |   | |    | | \    _|     _|    |
           (_/   |   |/\___/     \_/ \_/   \__/  |  \_/(/\___/(/\___/
                              (za warudo)
]]

local World = HC.new()
local polygon = require 'lib.HC.polygon'

function World:addToWorld(shape, ...)
  local item
  if shape == 'rectangle' then
    item = self:rectangle(...)
  elseif shape == 'circle' then
    item = self:circle(...)
  elseif shape == 'polygon' then
    item = self:polygon(...)
  elseif shape == 'newPolygon' then
    item = self:newPolygonShape(...)
  end
  return item
end

return World, polygon
