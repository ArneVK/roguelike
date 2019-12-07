class = require 'lib.middleclass'
anim8 = require 'lib.anim8'
shapes = require 'world'

directions = {
  NO_DIRECTION = -1,
  NORTH = 0,
  EAST = 1,
  SOUTH = 2,
  WEST = 3
}

wallDirections = {
  UP = 0,
  RIGHT = 1,
  DOWN = 2,
  LEFT = 3 
}

cornerDirections = {
  TOPLEFT = 0,
  TOPRIGHT = 1,
  DOWNLEFT = 2,
  DOWNRIGHT = 3
}

teleportDirections = {
  ENTRY = 0,
  EXIT = 1,
  HIDDENENTRY = 2,
  HIDDENEXIT = 3
}

NOTH = 0
TILE = 1
TELE = 2
WALL = 3
CORN = 4
DOOR = 5

timers = {}
HudElements = {}
entityList = {}
entityIndexes = {}
gridList = {}
hasBeenInRoom = false

function findKey(table, item)
  for key, value in pairs(table) do
    if value == item then
      return key
    end
  end
  return nil
end

function findOpposite(dir)
  return dir == 0 and 2 or 
         dir == 2 and 0 or
         dir == 1 and 3 or 1
end

--[[

     ___  ___  ___  ___  ________     
    |\  \|\  \|\  \|\  \|\   ___ \    
    \ \  \\\  \ \  \\\  \ \  \_|\ \   
     \ \   __  \ \  \\\  \ \  \ \\ \  
      \ \  \ \  \ \  \\\  \ \  \_\\ \ 
       \ \__\ \__\ \_______\ \_______\
        \|__|\|__|\|_______|\|_______|
                                      
]]


Hud = class('Hud')

function Hud:initialize(x,y,img,value,maxValue,scale)
  self.x = x
  self.y = y
  self.img = img
  self.value = value
  self.maxValue = maxValue
  self.scale = scale or 1/2
  table.insert(HudElements, self)
end

function Hud.static:load(player)
  self.font = love.graphics.setNewFont('font/cg_pixel_3x5.ttf', 5)
  self.player = player
  self.staminaBar = Bar:new(2, 2, {0,225,0}, player.stamina, player.maxStamina)
end

Heart = class('Heart', Hud)

function Heart:initialize(x,y,sheet,images,value,maxValue,scale)
end

Bar = class('Bar', Hud)

function Bar:initialize(x,y,color,value,maxValue,scale)
  self.color = color
  local img = love.graphics.newImage('sprites/bar.png')
  Bar.super.initialize(self,x,y,img,value,maxValue,scale)
end

function Hud.static:update()
  self.staminaBar.value = math.floor(self.player.stamina)
  self.staminaBar.maxValue = self.player.maxStamina
end

function Bar:draw()
  love.graphics.push()
  love.graphics.origin()
  love.graphics.scale(8, 8) -- THESE SHOULD STAY CONSTANTS
  chargeBarShader:send('color', self.color)
  chargeBarShader:send('value', self.value)
  chargeBarShader:send('maxValue', self.maxValue)
  love.graphics.setShader(chargeBarShader)
  love.graphics.draw(self.img, self.x, self.y, 0, self.scale, self.scale)
  love.graphics.setShader()
  love.graphics.setFont(self.class.font)
  love.graphics.printf({{255,255,255,1},self.value}, self.x, self.y + 0.5, self.img:getWidth(), 'center', 0, self.scale, self.scale)
  love.graphics.pop()
end

Timer = class('Timer')

function Timer:initialize(duration, func, endFunc)
  self.duration = duration
  self.time = love.timer.getTime()
  self.between = func
  self.onEnd = endFunc
  table.insert(timers, self)
end

function Timer:update(dt)
  if self.time + self.duration >= love.timer.getTime() then
    table.remove(timers, self)
    if self.onEnd ~= nil then
      local val = self.timerEnd()
      if val ~= nil then
        return val
      end
    end
  else
    self.between()
  end
end

--[[
                             __
                            / ()      _|_ o_|_
                            >-   /|/|  |  | |  |  |
                            \___/ | |_/|_/|/|_/ \/|/
                                                 (|
]]
local index = {}

function index:included(class)
  class.index = 0
  class = index:getMainClass(class)
  class.mainIndex = 0
end

function index:getMainClass(class)
  while(class.super ~= nil) do
    class = class.super
  end
  return class
end

function index:setIndex()
  self.class.index = self.class.index + 1
  self.index = self.class.index
  local class = index:getMainClass(self.class)
  class.mainIndex = class.mainIndex + 1
  self.mainIndex = class.mainIndex
end

Entity = class('Entity')
Entity:include(index)
Entity:include(shapes)

function Entity:initialize(x,y,scale,w,h,arx,ary,sheet,anims,currentAnim,speed,children)
  self.spawned = true
  self.position = {
    x = x,
    y = y
  }
  self.direction = directions.SOUTH
  self.scale = scale
  self.sheet = sheet
  self.anims = anims
  if currentAnim ~= nil then
    self.anims.current = currentAnim
  end
  self.dimensions = {
    w = w,
    h = h
  }
  -- Top Left position of an animation/images
  self.animPos = {
    x = x,
    y = y,
    rx = arx,
    ry = ary
  }
  self.angle = {
    
  }
  self.visible = true
  self.speed = speed
  self.children = {}
  children = children or {}
  if children ~= nil then
    if type(children) ~= 'table' then
      error('Children needs to be a table with each entity you want as a childentity')
    end
    for key, e in pairs(children) do
      self:addChild(key, e[1], e[2], e[3])
    end
  end
  self:setIndex()
  table.insert(entityList, self)
end


function Entity:setRelativeAnimPos(rx, ry, angle)
  self.animPos.rx, self.animPos.ry = rx, ry
  if angle ~= nil then
    self.animPos.angle = angle
  end
end

function Entity:setChildRelativePos()
  self.position.x = self.Parent.position.x - self.position.rx
  self.position.y = self.Parent.position.y - self.position.ry
end

function Entity:removeAllHitShapes()
  self:removeActiveHitShapes()
  for _,e in pairs(self.children) do
    e:removeActiveHitShapes()
  end
end

function Entity:moveDir(dir, dt, knockBack)
  speed = knockBack or self.speed
  local dx = dir == directions.WEST  and -1 or dir == directions.EAST  and 1 or 0
  local dy = dir == directions.NORTH and -1 or dir == directions.SOUTH and 1 or 0
  local vx, vy = speed*dt*dx, speed*dt*dy
  self:move(vx, vy)
end

function Entity:move(dx, dy, withChildren)
  self.position.x, self.position.y = self.position.x + dx, self.position.y + dy
  local actives = self:getActiveHitShapes()
  for _, shape in pairs(actives) do
    shape:move(dx, dy)
  end
  if withChildren then
    for _, child in pairs(self.children) do
      child.position.x, child.position.y = child.position.x + dx, child.position.y + dy
      if child.isRelative and child.hitShapes ~= nil then
        actives = child:getActiveHitShapes()
        for _, shape in pairs(actives) do 
          shape:move(dx, dy)
        end
      end
    end
  end
end

function Entity:teleport(dx, dy, withChildren)
  self.position.x, self.position.y = dx, dy
  local actives = self:getActiveHitShapes()
  for key, shape in pairs(actives) do
    local rx,ry = self:getHitShapeRelativePos(key)
    shape:moveTo(dx + rx, dy + ry)
  end
  if withChildren then
    for _, child in pairs(self.children) do
      child.position.x, child.position.y = dx, dy
      if child.isRelative and child.hitShapes ~= nil then
        actives = child:getActiveHitShapes()
        for key, shape in pairs(actives) do
          local rx,ry = child:getHitShapeRelativePos(key) 
          shape:moveTo(dx + rx, dy + ry)
        end
      end
    end
  end
end

function Entity:addChild(key, child, relativeChild, overlayState)
  if type(child) ~= 'table' or type(key) == 'number' then
    error('Each child needs to be a table (with a key for reference).\n1st element needs to be the child already initialized.\n2nd element is a boolean that checks whether the child follows the parent. (optional - x and y values from parent become same as from child).\n3nd element is a boolean that checks whether a relative child is drawn OVER (true) or UNDER (false) the parent. (optional)')
  end
  local overlayState = overlayState and relativeChild
  self.children[key] = child
  self.children[key].Parent = self
  self.children[key].isRelative = relativeChild
  if relativeChild then
    self.children[key].position.rx = self.children[key].position.x
    self.children[key].position.ry = self.children[key].position.y
  end
  self.children[key].overlayState = overlayState
end

function Entity:addShadow(ry)
  w = self.dimensions.w*self.scale
  h = w/5
  if ry == nil then
    ry = self.dimensions.h/2*self.scale - h/2
  else
    ry = ry*self.scale - h/2
  end
  self:addChild("Shadow", Shadow(self.position.x,self.position.y, w, h, ry, self.scale), true, false)
end


function Entity:getRelativeAnimPos()
  return self.position.x - self.animPos.rx, self.position.y - self.animPos.ry
end

function Entity:draw()
  if self.animPos ~= nil and self.sheet ~= nil then
    local x, y = self:getRelativeAnimPos()
    if self.anims.current ~= nil then
      self.anims.current:draw(self.sheet, x, y , 0, self.scale, self.scale)
      return 
    end
    love.graphics.draw(self.sheet, x, y, 0, self.scale, self.scale)
  else
    error("No sheet or no animPosition, can't draw image/animation")
  end
end

function Entity:resetAnimations()
  for _,anim in pairs(self.anims) do
    anim:gotoFrame(1)
    anim:resume()
  end
end

function Entity:update_children(dt)
  if self.isRelative then
    self:setChildRelativePos()
  end
end

function Entity:update_anims(dt)
  if self.anims ~= nil and self.anims.current ~= nil and self.visible then
    self.anims.current:update(dt)
  end
end


--[[
                    ________  ___       ________  ________  ___  ___     
                  |\   ____\|\  \     |\   __  \|\   ____\|\  \|\  \    
                  \ \  \___|\ \  \    \ \  \|\  \ \  \___|\ \  \\\  \   
                   \ \_____  \ \  \    \ \   __  \ \_____  \ \   __  \  
                    \|____|\  \ \  \____\ \  \ \  \|____|\  \ \  \ \  \ 
                      ____\_\  \ \_______\ \__\ \__\____\_\  \ \__\ \__\
                     |\_________\|_______|\|__|\|__|\_________\|__|\|__|
                     \|_________|                  \|_________|             

]]

Melee = class('Melee', Entity)

function Melee:initialize(x,y,scale,w,h,arx,ary,sheet,anims,current,damage)
  self.damage = damage
  self.leftToRight = true
  self.active = false
  self.isPlayerAttack = true
  Melee.super.initialize(self,x,y,scale,w,h,arx,ary,sheet,anims,current)
  self:setHitShape('down', false, 'rectangle', -9,-2, 18,9)
  self:setHitShape('up', false, 'rectangle', -9,-20.5, 18,9)
  self:setHitShape('left', false, 'rectangle', -12,-15.5, 9,18)
  self:setHitShape('right', false, 'rectangle', 3,-15.5, 9,18)
end

Staff = class('Staff', Melee)

function Staff:initialize(x,y)
  local w, h = 64, 64
  local scale = 1/3
  local sheet = love.graphics.newImage('sprites/Staff_2.png')
  local StaffGrid = anim8.newGrid(w,h, sheet:getWidth(), sheet:getHeight())
  local anims = {
    idle = anim8.newAnimation(StaffGrid(1,5), 0.1),
    southAnimationLTR = anim8.newAnimation(StaffGrid('1-4', 1), 0.1875, 'pauseAtEnd'),
    southAnimationRTL = anim8.newAnimation(StaffGrid('1-4', 2), 0.1875, 'pauseAtEnd'),
    eastAnimationLTR = anim8.newAnimation(StaffGrid('1-4', 3), 0.1875, 'pauseAtEnd'),
    eastAnimationRTL = anim8.newAnimation(StaffGrid('1-4', 4), 0.1875, 'pauseAtEnd')
  }
  anims.northAnimationRTL = anims.southAnimationLTR:clone():flipV()
  anims.northAnimationLTR = anims.southAnimationRTL:clone():flipV()
  anims.westAnimationRTL = anims.eastAnimationLTR:clone():flipH()
  anims.westAnimationLTR = anims.eastAnimationRTL:clone():flipH()
  Staff.super.initialize(self,x,y,scale,w,h,w,h,sheet,anims,anims.idle,10)
end

function Staff:setIdle()
  self.anims.current = self.anims.idle
  local x, y
  if self.direction == directions.NORTH then
    y = 18.5
    if self.leftToRight then x = 7.5 else x = 14 end
  elseif self.direction == directions.SOUTH then
    y = 18
    if self.leftToRight then x = 14 else x = 8 end
  elseif self.direction == directions.WEST then
    x = 14.5
    y = 18.5
  elseif self.direction == directions.EAST then
    x = 7.25
    y = 18.5
  end
  
  if self.animPos.rx ~= x or self.animPos.ry ~= y then
    self:setRelativeAnimPos(x,y)
  end
end

function Melee:reset()
  self:resetAnimations()
  self:setIdle()
  self.active = false
end

function Melee:setOverlay()
  if self.direction == directions.NORTH then
    self.overlayState = false
  elseif self.direction == directions.SOUTH then
    self.overlayState = true 
  elseif self.direction == directions.WEST then
    if self.leftToRight then self.overlayState = false else self.overlayState = true end
  elseif self.direction == directions.EAST then
    if self.leftToRight then self.overlayState = true else self.overlayState = false end
  end
end

function Melee:update(dt)
  local player = self.Parent
  local canMelee = love.keyboard.isDown("space")

  self.direction = player.faceDirection
  self:setOverlay()

  if not self.active then

    self:setIdle()

    if canMelee and player.stamina >= player.slashStaminaLoss and not player.staminaExhausted then
      
      player.stamina = player.stamina - player.slashStaminaLoss
      
      if player.stamina < 0 then
        player.stamina = 0
      end
      --self.Parent.cooldown = self.Parent.timer + 0.5

      local leftToRight = self.leftToRight and 'LTR' or 'RTL'

      local anim 
      if self.direction == directions.WEST then
        x,y,anim = 13.5, 17, 'westAnimation'
        self:hitShape('left')
      elseif self.direction == directions.EAST then
        x,y,anim = 7.5, 17, 'eastAnimation'
        self:hitShape('right')
      elseif self.direction == directions.NORTH then
        x,y,anim = 10.5, 21, 'northAnimation'
        self:hitShape('up')
      elseif self.direction == directions.SOUTH then
        x,y,anim = 10.5, 14, 'southAnimation'
        self:hitShape('down')
      end

      self:setRelativeAnimPos(x,y)
      self.anims.current = self.anims[anim..leftToRight]
      
      self.active = true
      
    end
  else

    if self.anims.current.position == math.floor(#self.anims.current.frames/2) + 1 then

      if self.leftToRight then self.leftToRight = false else self.leftToRight = true end
    
    end
    if self.anims.current.status == 'paused' then
      self:reset()
      self:removeActiveHitShapes()
    end
  end
end

--[[
                            (|  |  |_/o_|_  _  |)
                             |  |  |  | |  /   |/\
                              \/ \/   |/|_/\__/|  |/
]]
Witch = class('Witch', Entity)

function Witch:initialize(x,y)
  local w, h = 64, 64
  local scale = 1/3
  local sheet = love.graphics.newImage('sprites/witch_2.png')
  local grid = anim8.newGrid(w, h, sheet:getWidth(), sheet:getHeight())
  local anims = {
    southIdle = anim8.newAnimation(grid(1,1), 0.1),
    southWalk = anim8.newAnimation(grid('2-5', 1), 0.125),
    westIdle = anim8.newAnimation(grid(1,2), 0.1),
    westWalk = anim8.newAnimation(grid('2-5', 2), 0.125),
    northIdle = anim8.newAnimation(grid(1,3), 0.1),
    northWalk = anim8.newAnimation(grid('2-5', 3), 0.125),
    eastIdle = anim8.newAnimation(grid(1,4), 0.1),
    eastWalk = anim8.newAnimation(grid('2-5',4), 0.125)
  }
  self.lastDirection = 2
  self.faceDirection = 2
  self.lockLast = {false, nil}
  self.lockFace = {false, nil}
  self.moveStatus = 'idle'
  self.walkTime = 0
  self.isTired = false
  self.cooldown = 0 
  self.maxStamina = 100
  self.stamina = self.maxStamina
  self.staminaExhausted = false
  self.slashStaminaLoss = 10
  self.minSpeed = 25
  self.baseSpeed = 50
  self.tiredSpeed = 75
  self.maxSpeed = 100
  local children = { Staff = {Staff(0,-10), true, true}}
  Witch.super.initialize(self,x,y,scale,w,h,w/2*scale,h/2*scale,sheet,anims,anims.southIdle,self.baseSpeed,children)
  self:setHitShape('main', true, 'rectangle', -3, -4.75, 6, 13)
  self:addShadow()
  self.direction = -1
end

function Witch:update(dt)
  self:checkMoveStatus(dt)
  self:checkLocked()

  if self.moveStatus ~= 'idle' then
    local direction = self.lastDirection
    local dx = (direction == 1 and 1 or direction == 3 and -1 or 0) *dt*self.speed
    local dy = (direction == 2 and 1 or direction == 0 and -1 or 0) *dt*self.speed
    self:move(dx, dy, true)
  end
  
  self:checkStamina(dt)
  self:updateAnims(dt)
end

function Witch:checkLocked()
  if self.lockLast[1] and not self.lockLast[2]() then
    self.lockLast = {false, nil}
  end
  if self.lockFace[1] and not self.lockFace[2]() then
    self.lockFace = {false, nil}
  end
  if not self.lockLast[1] and self.direction > -1 then
    self.lastDirection = self.direction
  end
  if not self.lockFace[1] then
    self.faceDirection = self.lastDirection
  end
end

function Witch:lockDir(f, mode)
  if mode == 'both' or mode == 'last' then
    self.lockLast = {true, f}
  end
  if mode == 'both' or mode == 'face' then
    self.lockFace = {true, f}
  end
end 

function Witch:bump()
  self.lastDirection = findOpposite(self.lastDirection)
  self.moveStatus = 'slowing'
  self:resetWalk()
  local slowDown = function()
    if self.speed <= self.baseSpeed then
      self.lastDirection = self.faceDirection
    end
    return self.speed > self.baseSpeed
  end
  self:lockDir(slowDown, 'last')
end

function Witch:resetWalk()
  self.walkTime = 0
end

function Witch:useStamina(amount, dt)
  self.stamina = self.stamina - dt*amount
  self.cooldown = love.timer.getTime() + 0.5
end

function Witch:checkStamina(dt)
  if self.stamina <= 0 then
    self.staminaExhausted = true
    self.stamina = 0 
  end

  local staminaRegen = 20

  if self.cooldown == 0 and self.stamina < self.maxStamina then
    self.stamina = self.stamina + dt*staminaRegen
  elseif self.cooldown > 0 and self.cooldown <= love.timer.getTime() then
    self.cooldown = 0
  end

  if self.stamina >= self.maxStamina then
    self.stamina = self.maxStamina
    self.staminaExhausted = false 
 end
end


function Witch:checkMoveStatus(dt)
  self.direction = love.keyboard.isDown('right') and 1 or
                    love.keyboard.isDown('left') and 3 or
                    love.keyboard.isDown('down') and 2 or
                    love.keyboard.isDown('up') and 0 or -1

  for k, child in pairs(self.children) do 
    if child.isPlayerAttack and child.active then
      local isChildActive = function()
        return child.active
      end
      self:lockDir(isChildActive, 'face')
    end
  end
  
  if self.walkTime >= 2 and self.direction > -1 and self.speed >= self.baseSpeed then
    self.moveStatus = 'running'
    if not self.lockLast[1] then
      local f = function()
        if self.direction ~= self.lastDirection then
          local slow = findOpposite(self.direction) == self.lastDirection or self.direction == -1
          if not slow then
            self.lastDirection = self.direction
          else
            self.moveStatus = 'slowing'
            self:resetWalk()
          end
        end
        return self.speed > self.baseSpeed
      end
      self:lockDir(f, 'last')
    end
  elseif self.isTired then
    self.moveStatus = 'crawling'
  elseif self.direction > -1 and self.speed <= self.baseSpeed then
    self.moveStatus = 'walking'
  elseif self.direction == -1 and not self.isTired and self.speed <= self.baseSpeed then
    self.moveStatus = 'idle'
    self:resetWalk()
  end

  if self.moveStatus == 'walking' then
    if self.speed < self.baseSpeed then
      self.speed = self.speed + dt*10
    else
      self.speed = self.baseSpeed
      if not self.staminaExhausted then
        self.walkTime = self.walkTime + dt
      end   
    end
  end

  if self.moveStatus == 'running' then
    self:useStamina(10, dt)
    local multiplier = 10
    if self.speed >= self.tiredSpeed then
      self.isTired = true
      multiplier = 5
      if self.speed >= self.maxSpeed then
        self.speed = self.maxSpeed
        multiplier = 0
      end
    end
    self.speed = self.speed + dt*multiplier
  end 

  if self.moveStatus == 'slowing' then
    self:useStamina(10, dt)
    self.speed = self.speed - dt*25
    if self.speed <= self.baseSpeed then
      self.speed = self.baseSpeed
    end
  end
      
  if self.moveStatus == 'crawling' then
    if self.speed > self.minSpeed then
      --self:useStamina(10, dt)
      self.speed = self.speed - dt*25
    else
      self.speed = self.minSpeed
      self.isTired = false
    end
  end
  
end

function Witch:updateAnims(dt)
  if self.moveStatus ~= 'idle' then 
    if self.faceDirection == 1 then
      self.anims.eastWalk:update(dt)
    elseif self.faceDirection == 3 then
      self.anims.westWalk:update(dt)
    elseif self.faceDirection == 2 then
      self.anims.southWalk:update(dt)
    elseif self.faceDirection == 0 then
      self.anims.northWalk:update(dt)
    end
  end
end


function Witch:draw()
  local playerAnims = self.anims
  local x, y = self:getRelativeAnimPos()
  if self.moveStatus == 'idle' then
    self:resetAnimations()
    playerAnims.current = self.faceDirection == 0 and playerAnims.northIdle or
                          self.faceDirection == 1 and playerAnims.eastIdle or
                          self.faceDirection == 2 and playerAnims.southIdle or
                          playerAnims.westIdle
    playerAnims.current:draw(self.sheet, x, y, 0, self.scale, self.scale)
  elseif self.faceDirection == 1 then
    playerAnims.eastWalk:draw(self.sheet, x, y, 0, self.scale, self.scale)
  elseif self.faceDirection == 3 then
    playerAnims.westWalk:draw(self.sheet, x, y, 0, self.scale, self.scale)
  elseif self.faceDirection == 2 then
    playerAnims.southWalk:draw(self.sheet, x, y, 0, self.scale, self.scale)
  elseif self.faceDirection == 0 then
    playerAnims.northWalk:draw(self.sheet, x, y, 0, self.scale, self.scale)
  end
end

--[[
                          , _    , __   ___ 
                          /|/ \  /|/  \ / (_)
                          |   |  |___/|     
                         |   |  |    |     
                        |   |_/|     \___/
                   
]]

NPC = class('NPC', Entity)

function NPC:initialize(x,y,scale,w,h,arx,ary,sheet,anims,current,speed,children,hp,invincible,flying)
  -- Not sure what values should be given here, but i'm certain it's probably gonna be handy in the longrun
  self.hp = hp
  self.invincible = invincible
  self.flying = flying
  self.invTime = 6
  NPC.super.initialize(self,x,y,scale,w,h,arx,ary,sheet,anims,current,speed,children)
end

function NPC:update(dt)
  if self.hp > 0 then
    self:wander(dt)
  else
    if self.anims.current.status == 'paused' then
      for _,child in pairs(self.children) do
        local key = findKey(entityList, child)
        if key ~= nil then
          table.remove(entityList, key)
        end
        local id = findKey(entityIndexes, child.mainIndex)
        if id ~= nil then
          table.remove(entityIndexes, id)
        end
      end
      local e = findKey(entityList, self)
      local i = findKey(entityIndexes, self.mainIndex)
      if e ~= nil then
        table.remove(entityList, e)
      end
      if i ~= nil then
        table.remove(entityIndexes, i)
      end
    end
  end
end

function NPC:getHit(dt, damage, dir, knockBack)
  self.hp = self.hp - damage
  knockBack = knockBack or 500
  if self.AI ~= nil then
    self.AI.time = 0 
    self.AI.cooldown = 1 
  end
  self:moveDir(dir, dt, knockBack)
  self.invincible = true
  Timer(self.invTime, function() 
    if love.timer.getTime() % 2 == 0 then 
      self.visible = false
    else
      self.visible = true
    end
  end, function()
    self.visible = true
    self.invincible = false
  end)
  if self.hp <= 0 then
    self:resetAnimations()
    self:setToDie()
    self:removeFromWorld()
  end
end

function NPC:setToDie()
  self.anims.current = self.anims.death
end

--[[
                          () |)   _ |\  __|_  _
                          /\ |/) |/ |/ |/ |  / \_/|/|
                         /(_)| \/|_/|_/|_/|_/\_/  | |_/
]]
Skeleton = class('Skeleton', NPC)

function Skeleton:initialize(x,y)
  local scale = 1/3
  local w, h = 34, 50
  local sheet = love.graphics.newImage('sprites/skelly1.png')
  local grid = anim8.newGrid(w,h,sheet:getWidth(), sheet:getHeight())
  local anims = {
    south = anim8.newAnimation(grid('1-2', 1), 0.5),
    west = anim8.newAnimation(grid('1-2', 4), 0.5),
    east = nil,
    north = anim8.newAnimation(grid('1-2', 7), 0.5),
    current = nil
  }
  anims.east = anims.west:clone():flipH()
  local values = {main = {2.5, 6, 6.5, 11}}
  local children = {}
  local hp = 100
  local speed = 10
  Skeleton.super.initialize(self,true,x,y,scale,w,h,w/2*scale,h*scale,sheet,anims,anims.south,speed,nil,hp,false,false)
  self:addShadow()
  self.AI = Wander()
end

function Skeleton:wander(dt)
  self.AI:wander(self, dt)
  if self.AI.direction == 0 then
    self.anims.current = self.anims.north
  elseif self.AI.direction == 2 then
    self.anims.current = self.anims.south
  elseif self.AI.direction == 1 then
    self.anims.current = self.anims.east
  elseif self.AI.direction == 3 then
    self.anims.current = self.anims.west
  end
end


--[[
                                 /|/_) _, _|_
                                  |  \/ |  |
                                  |(_/\/|_/|_/
]]
Bat = class('Bat', NPC)

function Bat:initialize(x,y)
  local w, h = 27, 16
  local sheet = love.graphics.newImage('sprites/bat.png')
  local grid = anim8.newGrid(w, h, sheet:getWidth(), sheet:getHeight())
  local anims = {
    main = anim8.newAnimation(grid('1-3', 1, 2,1), 0.2),
    death = anim8.newAnimation(grid('1-3', 3, 1,4), 1, 'pauseAtEnd')
  }
  local children = {}
  local scale = 1/3
  local hp = 20
  local speed = 15
  Bat.super.initialize(self,x,y,scale,w,h,w/2*scale,h/2*scale,sheet,anims,anims.main,speed,nil,hp,false,true)
  self:setHitShape('main', true, 'rectangle',-w/2*scale,-h/2*scale, w*scale, h*scale)
  self:addShadow(h*2)
  self.AI = Wander()
end

function Bat:wander(dt)
  self.AI:wander(self,dt)
end

--[[
  Look at you, hacker.
  A pathetic creature of meat and bone.
  Panting and sweating as you run through my corridors.
  How can you challenge a perfect immortal machine?
]]
AI = class('AI')

function AI:move(entity, dt)
  -- idle by default
end

Wander = class('Wander', AI)

function Wander:initialize()
  self.time = 0
  self.direction = 2
  self.cooldown = 3
end

function Wander:wander(entity, dt)
  if self.time > 0 then
    self.time = self.time - dt
    entity:moveDir(self.direction, dt)
  elseif self.cooldown > 0 then
    self.cooldown = self.cooldown - dt
  else
    self.time = love.math.random(2,7)
    self.cooldown = love.math.random(2)
    self.direction = love.math.random(0,4)
  end
end

--[[
                   ________  ________  ________  ___  ___  ________   ________     
                  |\   ____\|\   __  \|\   __  \|\  \|\  \|\   ___  \|\   ___ \    
                  \ \  \___|\ \  \|\  \ \  \|\  \ \  \\\  \ \  \\ \  \ \  \_|\ \   
                   \ \  \  __\ \   _  _\ \  \\\  \ \  \\\  \ \  \\ \  \ \  \ \\ \  
                    \ \  \|\  \ \  \\  \\ \  \\\  \ \  \\\  \ \  \\ \  \ \  \_\\ \ 
                     \ \_______\ \__\\ _\\ \_______\ \_______\ \__\\ \__\ \_______\
                      \|_______|\|__|\|__|\|_______|\|_______|\|__| \|__|\|_______|
]]

Ground = class('Ground', Entity)

function Ground:initialize(x,y,scale,w,h,arx,ary,sheet,speed,children,hazard)
  -- Not sure what values should be given here, but i'm certain it's probably gonna be handy in the longrun
  self.isHazard = hazard
  Ground.super.initialize(self,x,y,scale,w,h,arx,ary,sheet,nil,nil,nil,speed,children)
end

Shadow = class('Shadow', Ground)

-- Should only be used as a childEntity

function Shadow:initialize(x,y,w,h,ry,scale)
  Shadow.super.initialize(self,x,y,scale,w,h,nil,ry,nil,nil,nil,false)
end
 
function Shadow:update(dt)
  self:move(dt)
end

function Shadow:move(dt)
  self.position.x = self.Parent.position.x
  self.position.y = self.Parent.position.y + self.animPos.ry
end

function Shadow:draw()
  love.graphics.setColor(0,0,0,0.5)  
  love.graphics.ellipse('fill', self.position.x, self.position.y, self.dimensions.w*self.scale, self.dimensions.h*self.scale)
  love.graphics.setColor(1,1,1,1)
end

--[[
                      __
                     / ()  _,        |\  _|   ,_   _
                    |     / |  |  |  |/ / |  /  | / \_/|/|
                     \___/\/|_/ \/|_/|_/\/|_/   |/\_/  | |_/
                    ________  ________   ________                                  
                   |\   __  \|\   ___  \|\   ___ \                                 
                   \ \  \|\  \ \  \\ \  \ \  \_|\ \                                
                    \ \   __  \ \  \\ \  \ \  \ \\ \                               
                     \ \  \ \  \ \  \\ \  \ \  \_\\ \                              
                      \ \__\ \__\ \__\\ \__\ \_______\                             
                       \|__|\|__|\|__| \|__|\|_______|                                                                                                                                                                                                                             
                    ________  ___  ___  ________  ________  ___       _______      
                   |\   __  \|\  \|\  \|\   ___ \|\   ___ \|\  \     |\  ___ \     
                   \ \  \|\  \ \  \\\  \ \  \_|\ \ \  \_|\ \ \  \    \ \   __/|    
                    \ \   ____\ \  \\\  \ \  \ \\ \ \  \ \\ \ \  \    \ \  \_|/__  
                     \ \  \___|\ \  \\\  \ \  \_\\ \ \  \_\\ \ \  \____\ \  \_|\ \ 
                      \ \__\    \ \_______\ \_______\ \_______\ \_______\ \_______\
                       \|__|     \|_______|\|_______|\|_______|\|_______|\|_______|
                                                                
  (Why make the ASCII art yourself when you can use G O O G E L to do it for you?)
]]

Cauldron = class('Cauldron', Entity)

function Cauldron:initialize(x,y)
  local w, h = 32, 32
  local sheet = love.graphics.newImage('sprites/cauldron.png')
  local grid = anim8.newGrid(w, h, sheet:getWidth(), sheet:getHeight())
  local anims = {
    current = anim8.newAnimation(grid('1-2', 1), 0.3),
    rightAnim = anim8.newAnimation(grid('3-4', 1, '1-4', 2), 0.3, 'pauseAtEnd'),
    leftAnim = anim8.newAnimation(grid('3-4', 1, '1-4', 2), 0.3, 'pauseAtEnd'):flipH(),
    frontAnim = anim8.newAnimation(grid('1-4', 3, '1-2', 4), 0.3, 'pauseAtEnd'),
    backAnim = anim8.newAnimation(grid('3-4', 4, '1-4', 5), 0.3, 'pauseAtEnd')
  }
  local values = {main = {6.5,12,9,5}} 
  local children = { Puddle = {Puddle(x,y)}}
  local scale = 2/3
  local filter = function(item, other)  return 'touch' end
  self.time = nil
  Cauldron.super.initialize(self,x,y,w,h,true,sheet,anims,true,values,'main',scale,filter,nil,children)
end

function Cauldron:update(dt)
  local anims = self.anims
  local puddle = self.children["Puddle"]
  if anims.current.position ~= 6 then
    anims.current:update(dt)
  end
  if self.col then
    local actualX, actualY, cols, len = self:checkMovement()
    for i=1, len do
      if cols[i].other.isPlayerAttack then
        local player = cols[i].other.Parent
        if player.lastDirection == 3  then
          self.anims.current = anims.leftAnim
        elseif player.lastDirection == 1  then
          self.anims.current = anims.rightAnim
        elseif player.lastDirection == 0  then
          self.anims.current = anims.backAnim
        elseif player.lastDirection == 2  then
          self.anims.current = anims.frontAnim
        end
        self.col = false
        world:remove(self)
      end
    end
  elseif not self.col then
    puddle:update()
    if self.anims.current.position >= 4 and self.anims.current.position ~= 6 then
      if self.time == nil then
        self.time = love.timer.getTime()
        self.anims.current:pause()
      elseif self.time + 2 <= love.timer.getTime() then
        self.time = nil
        self.anims.current:gotoFrame(self.anims.current.position + 1)
      end
    end 
  end
end

Puddle = class('Puddle', Ground)

function Puddle:initialize(x,y)
  self.time = nil
  self.maxSize = 2
  self.pause = 5
  self.speed = 0.01
  self.isShrinking = false
  local size = 0
  local sheet = love.graphics.newImage('sprites/puddle.png')
  local colValues = {main = {-9.5,-10, 18, 16}}
  local scale = 2/3
  local filter = function(item, other)  return 'cross' end
  Puddle.super.initialize(self,x+10,y+18,size,size,false,sheet,false,colValues,'main',scale,filter,true,size)
end


function Puddle:prepare()
  self.time = love.timer.getTime()
  world:add(self, self.x, self.y, 1, 1)
  self.col = true
  self.spawned = true
end

function Puddle:update()
  local cauldron = self.Parent
  local v1, v2, v3, v4 = self:getValues()
  if not cauldron.col and cauldron.anims.current.position == 4 and not self.col then
    self:prepare()
  end
  if self.col then
    local actualX, actualY, cols, len = world:check(self, self.x+(self.size*v1), self.y+(self.size*v2), self.filter)
    for i = 1, len do
      if cols[i].other.isEnemy then
        -- Give them poison damage or smth idk lol
      end
    end
    if self.size > 0 then
      world:update(self, self.x+(self.size*v1), self.y+(self.size*v2), self.size*v3, self.size*v4)
    elseif not self.spawned then
      world:remove(self)
      self.col = false
    end
  end
end


function Puddle:draw()
  if not self.isShrinking then
    if self.size < self.maxSize then
      self.size = self.size + self.speed
      self.time = love.timer.getTime()
    elseif self.size >= self.maxSize then
      if self.time + self.pause <= love.timer.getTime() then self.isShrinking = true end
    end
  else
    if self.size > 0 then
      self.size = self.size - self.speed
      self.time = love.timer.getTime()
    else 
      self.spawned = false
    end 
  end
  love.graphics.draw(self.sheet, self.x-self.size*10, self.y-self.size*10, 0, self.scale*self.size, self.scale*self.size)
end

--[[

            ________  ________  ________  _____ ______      
          |\   __  \|\   __  \|\   __  \|\   _ \  _   \    
          \ \  \|\  \ \  \|\  \ \  \|\  \ \  \\\__\ \  \   
           \ \   _  _\ \  \\\  \ \  \\\  \ \  \\|__| \  \  
            \ \  \\  \\ \  \\\  \ \  \\\  \ \  \    \ \  \ 
             \ \__\\ _\\ \_______\ \_______\ \__\    \ \__\
              \|__|\|__|\|_______|\|_______|\|__|     \|__|
]]

Room = class('Room'):include(index)

function Room:initialize(self,x,y,levelName,layout,entities,size,scale)
  self.x = x
  self.y = y
  self.size = size or 16
  self.scale = scale or 1/2
  self.level = levelName
  self.layout = layout
  self.entities = entities
  self.gridList = {}
  self.time = love.timer.getTime()
  self.timerAmount = 3
  self:setIndex()
end
--[[
              
              ________  ________  ___  ________     
             |\   ____\|\   __  \|\  \|\   ___ \    
             \ \  \___|\ \  \|\  \ \  \ \  \_|\ \   
              \ \  \  __\ \   _  _\ \  \ \  \ \\ \  
               \ \  \|\  \ \  \\  \\ \  \ \  \_\\ \ 
                \ \_______\ \__\\ _\\ \__\ \_______\
                 \|_______|\|__|\|__|\|__|\|_______|
                                                                                                      
]]

Grid = class('Grid'):include(index):include(shapes)

function Grid:initialize(x,y,size,imageKey,scale,direction)
  self.position = {
    x = x,
    y = y,
    cx = x + (size/2),
    cy = y + (size/2)
  }
  self.size = size
  if self.images[imageKey] == nil then
    error("Didn't find '".. tostring(imageKey) .."' in images. Use the static method 'Grid:addImage(imagekey, fileLocation)' first before initializing object with that key...")
  else
    self.current = self.images[imageKey]
  end
  self.scale = scale
  self.direction = direction
  self:setIndex()
  table.insert(gridList, self)
end

function Grid.static:subclassed(class)
  class.imageValues = {}
end

function Grid.static:addImage(key, file)
  if Grid.images == nil then
    Grid.images = {}
  end
  if Grid.images[key] == nil then
    Grid.images[key] = {}
  end
  if self.imageValues[key] == nil then
    self.imageValues[key] = {}
  end
  local imageAmount = table.maxn(Grid.images[key]) + 1
  Grid.images[key][imageAmount] = file
  table.insert(self.imageValues[key], imageAmount)
  return imageAmount, self.imageValues[key]  
end

function Grid.static:getImageValues(key)
  return table.maxn(self.imageValues[key])
end

function Grid.static:getImage(key, imageId)
  if Grid.images[key] == nil then
    error("Didn't find '".. tostring(key) .."' in images. Use the static method 'Grid:addImage(imageKey, fileLocation)' first before initializing object with that key...")
  elseif Grid.images[key][imageId] == nil then
    error("Found '".. tostring(key) .."' in images, but not ".. tostring(imageId) ..". Use the static method 'Grid:getImageAmount()' to get the max amount of images.")
  else
    local image = love.graphics.newImage(Grid.images[key][imageId])
    local wSize, hSize = image:getDimensions()
    return image, wSize, hSize
  end
end

function Grid.static:getImageData(key, imageId)
  if Grid.images[key] == nil then
    error("Didn't find '".. tostring(key) .."' in images. Use the static method 'Grid:addImage(imageKey, fileLocation)' first before initializing object with that key...")
  elseif Grid.images[key][imageId] == nil then
    error("Found '".. tostring(key) .."' in images, but not ".. tostring(imageId) ..". Use the static method 'Grid:getImageAmount()' to get the max amount of images.")
  else
    local image = love.image.newImageData(Grid.images[key][imageId])
    local wSize, hSize = image:getDimensions()
    return image, wSize, hSize
  end
end

Tile = class('Tile', Grid)

function Tile:initialize(x,y,size,image,imageKey,scale)
  self.image = image
  Tile.super.initialize(x,y,size,imageKey,nil,-1)
end

Wall = class('Wall', Grid)

function Wall:initialize(x,y,size,imageKey,scale,dir)
  Wall.super.initialize(self,x,y,size,imageKey,scale,dir)
end

Corner = class('Corner', Wall)

function Corner:initialize(x,y,size,imageKey,scale,dir)
  Corner.super.initialize(self,x,y,size,imageKey,scale,dir)
end

function Wall:update(dt)
  local shape = self:getHitShape("main")
  local cols = self:getCollisions("main")
  for other, separating_vector in pairs(cols) do
    --shape:move( separating_vector.x/2,  separating_vector.y/2)
    if other.parent:isInstanceOf(Entity) and not other.parent:isInstanceOf(Melee) then
      other.parent:move(-separating_vector.x, -separating_vector.y, true)
    end
  end
end

Door = class('Door', Grid)

function Door:initialize(x,y,size,imageKey,scale,dir)
  Door.super.initialize(self,x,y,size,imageKey,scale,dir)
end

function Door:checkCollision()
  
end

Teleport = class('Teleport', Grid)

function Teleport.static:getImage(key, imageId)
  if Grid.images[key] == nil then
    error("Didn't find '".. tostring(key) .."' in images. Use the static method 'Teleport:addImage(imageKey, fileLocation)' first before initializing object with that key...")
  elseif Grid.images[key][imageId] == nil then
    error("Found '".. tostring(key) .."' in images, but not ".. tostring(imageId) ..". Use the static method 'Teleport:getImageAmount()' to get the max amount of images.")
  else
    local layers = {"sprites/black_layer.png", "sprites/black_layer.png", Grid.images[key][imageId]}
    local image = love.graphics.newArrayImage(layers)
    local wSize, hSize = image:getDimensions()
    return image, wSize, hSize
  end
end

                                                                  -- unkown == tele or desX 
function Teleport:initialize(x,y,size,image,imageKey,scale,shouldLoad,unkown,desY)
  self.image = image
  self.rotationSpeed = 80
  self.timer = 0
  self.loadSpeed = 1
  self.loading = shouldLoad
  if shouldLoad then
    self:setToLoad()
  end
  self.active = false 
  self.hidden = false
  if type(unkown) == 'table' then
    self:setDestiny(unkown)
  elseif type(unkown) == 'number' and desY ~= nil then
    self.destiny = {
      obj = -1,
      x = unkown,
      y = desY
    }
  end
  self:resetRotations()
  Teleport.super.initialize(self,x,y,size,imageKey,scale,-1)
  self:setHitShape("main", false, "circle", size*scale,size*scale, size/2*scale)
end

function Teleport:setDestiny(destiny)
  self.destiny = {
    obj = destiny,
    x = destiny.position.cx,
    y = destiny.position.cy
  } 
end

function Teleport:addOnTeleport(f, ...)
  self.onTeleport = {f, {...}}
end

function Teleport:deactivate()
  self.active = false
  self.loading = false
  self.timer = 0
  self:removeHitShape("main")
end

function Teleport:resetRotations()
  self.rotations = {36,108,180,252,324}
end

function Teleport:hideToggle()
  self.hidden = self.hidden and false or true 
end

function Teleport:setToLoad()
  self:resetRotations()
  self.loading = true
end

function Teleport:activate()
  self.active = true
  self.loading = false
  self:hitShape("main")
end

function Teleport:checkCollision()
  local cols = self:getCollisions("main")
  for other, vector in pairs(cols) do
    if other.parent:isInstanceOf(Witch) then
      other.parent:teleport(self.destiny.x, self.destiny.y, true)
      self:deactivate()
      if self.onTeleport ~= nil then
        self.onTeleport[1](self.onTeleport[2])
      end
      hasBeenInRoom = true
    end
  end
end

function Teleport:setTeleShader(dt)
  local isPenta = false
  for i = 1, #self.rotations do
    local corner = self.rotations[i] 
    --36,108,180,252,324
    if (corner > 35 and corner < 37) or
       (corner > 107 and corner < 109) or
       (corner > 179 and corner < 181) or
       (corner > 251 and corner < 253) or
       (corner > 323 and corner < 325) then
        self:resetRotations()
      isPenta = true
    end
  end

  if self.timer/self.loadSpeed >= 1 and isPenta then
    self:activate()
  else
    self.timer = self.timer + (1 * dt)
    local teleShaderTime = 80 * dt
    for i = 1, #self.rotations do
      self.rotations[i] = self.rotations[i] + teleShaderTime
      if self.rotations[i] >= 360 then
        self.rotations[i] = 0
      end
    end
  end
end

function Teleport:update(dt)
  if self.loading then
    self:setTeleShader(dt)
  elseif self.active then
    self:checkCollision()
  end
end