local class = require 'lib.middleclass'
local HC = require 'lib.HC'
local Shapes = require 'lib.HC.shapes'
local Polygon = require 'lib.HC.polygon'
World = HC.new()

--[[
           ______,      ___    _            __   , __     _     ____
          (_) | /|   | / (_)  (_|   |   |_//\_\//|/  \ \_|_)   (|   \
              |  |___| \__      |   |   | |    | |___/   |      |    |
            _ |  |   |\/        |   |   | |    | | \    _|     _|    |
           (_/   |   |/\___/     \_/ \_/   \__/  |  \_/(/\___/(/\___/
                              (za warudo)
]]

shapes = {
  --[[
    position is a table containing x and y values
    shape is can be a 'rectangle', 'circle', 'polygon' or 'newPolygon'
    (newPolygon can be a concave or convex polygon, not sure how this works yet)
    
    position is (somewhat) optional; 
    position is only needed when base table doesn't have a property position;
    
    shape and the args can be derived from the hitshapes (after being set with shapes:setHitShape)

    Every kind of shape has different params, with the first 2 params /always/ being a vector (x,y),
    meaning that the respective values are being added to the entity's position x and y values (they're NOT actual points)
    other params differ dependent on shape
    
    - rectangle: LeftMost X, TopMost Y, Width, Length
    - circle: Center X, Center Y, Radius
    - polygon and newPolygon: X1, Y1, X2, Y2, ... Xn, Yn (Needs at LEAST 3 non-colinear points, meaning 3 points given don't end up being a line)

    All this data is being put in a table 'Entity.hitShapes[keyname][..]'
    - [1] : hitShape (actual reference)
    - [2] : shape (name)
    - [3] : shapeData (For respawning after removal)
    - [4] : is it active?
    - [5] : relative position (x and y in table)
    ]]
    

  hitShape = function(self,keyName,position,shape,...)
    local hitShape, x, y, s, arg 
    if type(position) == 'nil' then
      x,y,s,arg = self.position.x, self.position.y, self.hitShapes[keyName][2], self.hitShapes[keyName][3]
    elseif type(position) == 'string' then
      x,y,s = self.position.x, self.position.y, shape
      arg = {...}
    elseif type(shape) == 'nil' then 
      x,y,s,arg = position[1], position[2], self.hitShapes[keyName][2], self.hitShapes[keyName][3]
    end
    if s == 'rectangle' then
      hitShape = World:rectangle(arg[1] + x, arg[2] + y, arg[3], arg[4])
    elseif s == 'circle' then
      hitShape = World:circle(arg[1] + x, arg[2] + y, arg[3])
    else
      if #arg % 2 == 0 then
        
        local newArg = {}
        for i = 1, #arg do
          if i % 2 == 0 then
            newArg[i] = arg[i] + y
          else
            newArg[i] = arg[i] + x
          end
        end
        if s == "polygon" then
          hitShape = World:polygon(unpack(newArg))
        elseif s == "newPolygon" then
          hitShape = Shapes.newPolygonShape(unpack(newArg))
          World:register(hitShape)
        end
      else
        error("When using shape 'polygon' or 'newPolygon', you need a x and an y value for each point")
      end
    end
    hitShape.parent = self
    self.hitShapes[keyName][1] = hitShape
    self.hitShapes[keyName][4] = true
    self:checkHasCol()
    return hitShape
  end,

  -- Give position if you want the hitshape to also spawn

  setHitShape = function(self,keyName,keepSpawned,shape,...)
    if self.hitShapes == nil then self.hitShapes = {} end
    self.hitShapes[keyName] = {}
    self.hitShapes[keyName][2] = shape
    self.hitShapes[keyName][3] = {...}
    self.hitShapes[keyName][4] = false
    local shape = self:hitShape(keyName)
    local cx,cy = shape:center()
    cx = cx - self.position.x 
    cy = cy - self.position.y
    self.hitShapes[keyName][5] = { x = cx, y = cy}
    if not keepSpawned then
      self:removeHitShape(keyName)
    end
  end,

  getHitShape = function(self, keyName)
    return self.hitShapes[keyName][1]
  end,

  getHitShapeData = function(self,keyName,position)
    local x,y
    if type(position) == 'table' then
      x,y = position[1], position[2]
    else
      x,y = self.position.x, self.position.y
    end
    local s, arg = self.hitShapes[keyName][2], self.hitShapes[keyName][3]
    if s == 'rectangle' then
      return {arg[1] + x, arg[2] + y, arg[3], arg[4]}
    elseif s == 'circle' then
      return {arg[1] + x, arg[2] + y, arg[3]}
    else    
      local newArg = {}
      for i = 1, #arg do
        if i % 2 == 0 then
          newArg[i] = arg[i] + y
        else
          newArg[i] = arg[i] + x
        end
      end
      return newArg
    end
  end,

  getHitShapeRelativePos = function(self,keyName)
    return self.hitShapes[keyName][5].x, self.hitShapes[keyName][5].y
  end,

  removeActiveHitShapes = function(self)
    local actives = self:getActiveHitShapes()
    for key, shape in pairs(actives) do
      World:remove(shape)
      self.hitShapes[key][4] = false
    end
    self.hasCol = false
  end,

  removeHitShape = function(self,keyName)
    World:remove(self.hitShapes[keyName][1])
    self.hitShapes[keyName][4] = false
    self:checkHasCol()
  end,

  checkHasCol = function(self)
    for _, c in pairs(self.hitShapes) do
      if c[4] then
        self.hasCol = true
        return
      end
    end
    self.hasCol = false
  end,

  getActiveHitShapes = function(self)
    local shapes = {}
    for key, shape in pairs(self.hitShapes) do
      if shape[4] then
        shapes[key] = shape[1]
      end
    end
    return shapes
  end,

  getCollisions = function(self, keyName)
    return World:collisions(self.hitShapes[keyName][1])
  end,

  update_shape_properties = function(self)
    local rules = self.class.shapeProperties
    for class, rule in pairs(rules) do
      
    end
  end
}

function shapes:included(class)
  class.defaultShape = "rectangle"
  class.shapeProperties = {}
  class.static.addShapeProperties = function(class1, f)
    self.shapeProperties[class1] = f
  end

  class.static.subclassed = function(sub)
    sub.shapeProperties = {}
    sub.static.addShapeProperties = function(class1, f)
      self.shapeProperties[class1] = f
    end
  end
end

return shapes
