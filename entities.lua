class = require 'lib.middleclass'
anim8 = require 'lib.anim8'
world = require 'world'

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

--[[
                             __
                            / ()      _|_ o_|_
                            >-   /|/|  |  | |  |  |
                            \___/ | |_/|_/|/|_/ \/|/
                                                 (|
]]
local index = {}

function index:getMainClass(class)
  while(class.super ~= nil) do
    class = class.super
  end
  return class
end

function index:included(class)
  class.index = 0
  class = index:getMainClass(class)
  class.mainIndex = 0
end

function index:setIndex()
  self.class.index = self.class.index + 1
  self.index = self.class.index
  local class = index:getMainClass(self.class)
  class.mainIndex = class.mainIndex + 1
  self.mainIndex = class.mainIndex
end

Entity = class('Entity'):include(index)

function Entity:initialize(spawn,x,y,sheet,w,h,anims,visible,col,colShape,colValues,colFilter,scale,shadow,children)
  self.spawned = spawn
  self.x = x
  self.y = y
  self.sheet = sheet
  self.anims = anims
  self.animValues = {
    x = x - w/2,
    y = y - h,
    w = w,
    h = h
  }
  self.visible = visible
  self.col = col
  self.colShape = colShape
  self.colValues = colValues
  self.colFilter = colFilter
  if self.speed == nil then self.speed = 1 end -- still needs a fix
  self.scale = scale or 2/3
  children = children or {}
  if shadow ~= nil then
    children['Shadow'] = {Shadow(x,y,unpack(shadow),self.scale)}
  end
  self.children = {}
  if children ~= nil then
    local hasOverlay = false
    for key, e in pairs(children) do
      local child = e[1]
      local overlayState = e[2]
      self.children[key] = child
      self.children[key].Parent = self
      self.children[key].overlayState = overlayState
      if overlayState ~= nil then hasOverlay = true end
    end
    self.hasOverlay = hasOverlay
  end
  self:setIndex()
  table.insert(entityList, self)
end

function Entity:addToWorldWithChildren()
  world:addToWorld(self, self.colShape, unpack(self.colValues))
  if self.children ~= nil then
    for _,e in pairs(self.children) do
      if not e:isInstanceOf(Ground) then
        world:addToWorld(e, e.colShape, unpack(e.colValues))
      end
    end
  end
end

function Entity:removeFromWorldWithChildren()
  world:removeFromWorld(self)
  if self.children ~= nil then
    for _,e in pairs(self.children) do
      world:removeFromWorld(e)
    end
  end
end

function Entity:moveDir(dir, dt, knockBack)
  speed = knockBack or self.speed
  local dx = dir == directions.WEST  and -1 or dir == directions.EAST  and 1 or 0
  local dy = dir == directions.NORTH and -1 or dir == directions.SOUTH and 1 or 0
  local vx, vy = speed*dt*dx, speed*dt*dy
  self.x, self.y = self.x + vx, self.y + vy
  self.animValues.x, self.animValues.y = self.animValues.x + vx, self.animValues.y + vy
  if self.col then
    local cx, cy = self.colShape:center()
    self.colShape:moveTo(cx + vx, cy + vy)
  end
end

function Entity:draw()
  if self.animValues ~= nil and self.sheet ~= nil then
    if self.anims.current ~= nil then
      self.anims.current:draw(self.sheet, self.animValues.x, self.animValues.y, 0, self.scale, self.scale)
      return 
    end
    love.graphics.draw(self.sheet, self.animValues.x, self.animValues.y, 0, self.scale, self.scale)
  else
    error("No sheet or no animvalues, can't draw image/animation")
  end
end

function Entity:resetAnimations()
  for _,anim in pairs(self.anims) do
    anim:gotoFrame(1)
    anim:resume()
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
                                                      
                                          
                    ________  ________   ________     
                   |\   __  \|\   ___  \|\   ___ \    
                   \ \  \|\  \ \  \\ \  \ \  \_|\ \   
                    \ \   __  \ \  \\ \  \ \  \ \\ \  
                     \ \  \ \  \ \  \\ \  \ \  \_\\ \ 
                      \ \__\ \__\ \__\\ \__\ \_______\
                       \|__|\|__|\|__| \|__|\|_______|
                                                        
                       ________  ________  ________  ________      ___    ___ 
                      |\   __  \|\   __  \|\   __  \|\   __  \    |\  \  /  /|
                      \ \  \|\  \ \  \|\  \ \  \|\  \ \  \|\  \   \ \  \/  / /
                       \ \   ____\ \   __  \ \   _  _\ \   _  _\   \ \    / / 
                        \ \  \___|\ \  \ \  \ \  \\  \\ \  \\  \|   \/  /  /  
                         \ \__\    \ \__\ \__\ \__\\ _\\ \__\\ _\ __/  / /    
                          \|__|     \|__|\|__|\|__|\|__|\|__|\|__|\___/ /     
                                                                \|___|/      

]]

Melee = class('Melee', Entity)

function Melee:initialize(x,y,sheet,anims,scale)
  local values = {main = {2.5,4,1,1},
                  west = {-8, -1, 7, 12}, 
                  east = {7, -1, 7, 12}, 
                  north = {-3, -7.5, 12, 7}, 
                  south = {-3, 10, 12, 7}}
  self.leftToRight = true
  self.active = false
  self.isPlayerAttack = true -- should be removed or smth
  self.damage = 10
  self.direction = 2
  Melee.super.initialize(self,true,x,y,sheet,w,h,anims,true,values,true,"rectangle",values,nil,scale)
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
    eastAnimationRTL = anim8.newAnimation(StaffGrid('1-4', 4), 0.1875, 'pauseAtEnd'),
    current = nil
  }
  anims.northAnimationRTL = anims.southAnimationLTR:clone():flipV()
  anims.northAnimationLTR = anims.southAnimationRTL:clone():flipV()
  anims.westAnimationRTL = anims.eastAnimationLTR:clone():flipH()
  anims.westAnimationLTR = anims.eastAnimationRTL:clone():flipH()
  Staff.super.initialize(self,x,y,sheet,w,h,anims,scale)
end


function Melee:reset()
  self:resetAnimations()
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
  local playerAnims = player.anims
  local canMelee = love.keyboard.isDown("space")

  local p1, p2 = player:getValues()
  local v1, v2, v3, v4 = self:getValues()
  self.x, self.y = player.x + p1, player.y + p2 
  world:update(self, self.x + v1, self.y + v2, v3, v4)
  
  local actualX, actualY, cols, len = self:checkMovement()

  self.direction = player.faceDirection
  self:setOverlay()

  if canMelee and not self.active and player.stamina >= player.slashStaminaLoss and not player.staminaExhausted then
    
    player.stamina = player.stamina - player.slashStaminaLoss
    
    if player.stamina < 0 then
      player.stamina = 0
    end
    --self.Parent.cooldown = self.Parent.timer + 0.5
    self.active = true

    local leftToRight = self.leftToRight and 'LTR' or 'RTL'
    
    local anim = self.direction == directions.WEST and 'westAnimation' or
    self.direction == directions.EAST and 'eastAnimation' or 
    self.direction == directions.NORTH and 'northAnimation' or 'southAnimation'
    self.anims.current = self.anims[anim..leftToRight] 
  elseif self.active then
    
    self.anims.current:update(dt)

    if self.anims.current.position == math.floor(#self.anims.current.frames/2) + 1 then

      if self.leftToRight then self.leftToRight = false else self.leftToRight = true end
      
      if self.direction == directions.WEST then
        self.valuesKey = 'west'
      elseif self.direction == directions.EAST then
        self.valuesKey = 'east'
      elseif self.direction == directions.NORTH then
        self.valuesKey = 'north'
      elseif self.direction == directions.SOUTH then
        self.valuesKey = 'south'
      end

    else
      self.valuesKey = 'main'
    end
    for i=1,len do
      if cols[i].other.isEnemy and cols[i].other.invincible == 0 then
        cols[i].other:getHit(dt, self.damage, player.lastDirection)
      end
    end
    if self.anims.current.status == 'paused' then
      self:reset()
    end
  end
end

function Staff:draw()
  if self.active then
    if self.direction == 3 then
      self.anims.current:draw(self.sheet, self.x - 10, self.y - 6, 0, self.scale, self.scale)
    elseif self.direction == 1 then
      self.anims.current:draw(self.sheet, self.x - 5, self.y - 6, 0, self.scale, self.scale)
    elseif self.direction == 2 then
      self.anims.current:draw(self.sheet, self.x - 8, self.y - 4, 0, self.scale, self.scale)
    elseif self.direction == 0 then
      self.anims.current:draw(self.sheet, self.x - 8, self.y - 12, 0, self.scale, self.scale)
    end
  else
    local x, y = self.x, self.y
    if self.direction == directions.NORTH then
      y = y - 9
      if self.leftToRight then x = x - 4 else x = x - 12 end
    elseif self.direction == directions.SOUTH then
      y = y - 7
      if self.leftToRight then x = x - 11 else x = x - 5 end
    elseif self.direction == directions.WEST then
      x = x - 11
      y = y - 7
    elseif self.direction == directions.EAST then
      x = x - 5.5
      y = y - 7
    end
    self.anims.idle:draw(self.sheet, x, y, 0, self.scale, self.scale)
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
    eastWalk = anim8.newAnimation(grid('2-5',4), 0.125),
    current = nil
  }
  anims.current = anims.southIdle
  h = h - 6
  local values = { main = {7.5, 10, 6, 9.5}}
  local children = { Staff = {Staff(x,y), false}}
  self.direction = -1
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
  self.speed = self.baseSpeed
  Witch.super.initialize(self,true,x,y,sheet,w,h,anims,true,true,'rectangle',values,nil,scale,{6.5},children)
end

function Witch:update(dt)
  self:checkMoveStatus(dt)
  self:checkLocked()
  self:move(dt)
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

function Witch:move(dt)
  if self.moveStatus ~= 'idle' then
    local direction = self.lastDirection
    local dx = (direction == 1 and 1 or direction == 3 and -1 or 0) *dt*self.speed
    local dy = (direction == 2 and 1 or direction == 0 and -1 or 0) *dt*self.speed
    local v1, v2 = self:getValues()
    local x, y, cols, len = world:move(self, self.x + dx + v1, self.y + dy + v2, self.filter)
    self.x, self.y = x - v1, y - v2
    -- Fuck with this and get eaten by TàNy teH P0nY
    for i = 1, len do
      if cols[i].other.isEnemy then
        if self.speed > self.baseSpeed then
          cols[i].other:getHit(dt, 10, self.faceDirection)
          self:bump()
        else
          self:resetWalk()
        end
      elseif cols[i].other:isInstanceOf(Grid) then 
        if self.speed > self.baseSpeed then
          self:bump()
        else
          self:resetWalk()
        end
      end
    end
  end
  Debug = 'Direction: ' .. self.direction .. ' Last: ' .. self.lastDirection .. ' Face: ' .. self.faceDirection .. ' moveStatus: ' .. self.moveStatus .. ' Speed: ' .. self.speed
  --Debug = 'WalkTime ' .. self.walkTime .. ' speed ' .. self.speed
end

function Witch:draw()
  local playerAnims = self.anims
  if self.moveStatus == 'idle' then
    self:resetAnimations()
    playerAnims.current = self.faceDirection == 0 and playerAnims.northIdle or
                          self.faceDirection == 1 and playerAnims.eastIdle or
                          self.faceDirection == 2 and playerAnims.southIdle or
                          playerAnims.westIdle
    playerAnims.current:draw(self.sheet, self.x, self.y, 0, self.scale, self.scale)
  elseif self.faceDirection == 1 then
    playerAnims.eastWalk:draw(self.sheet, self.x, self.y, 0, self.scale, self.scale)
  elseif self.faceDirection == 3 then
    playerAnims.westWalk:draw(self.sheet, self.x, self.y, 0, self.scale, self.scale)
  elseif self.faceDirection == 2 then
    playerAnims.southWalk:draw(self.sheet, self.x, self.y, 0, self.scale, self.scale)
  elseif self.faceDirection == 0 then
    playerAnims.northWalk:draw(self.sheet, self.x, self.y, 0, self.scale, self.scale)
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

function NPC:initialize(spawn,x,y,sheet,w,h,anims,vis,col,shape,colValues,filter,scale,hp,enemy,flying,shadow,children)
  -- Not sure what values should be given here, but i'm certain it's probably gonna be handy in the longrun
  self.hp = hp
  self.isEnemy = enemy
  self.flying = flying
  self.time = 0
  self.invincible = 0
  self.invTime = 0
  NPC.super.initialize(self,spawn,x,y,sheet,w,h,anims,vis,col,shape,colValues,filter,scale,shadow,children)
end

local enemyFilter = function(item, other)
  if other.isPlayerAttack or other.isHazard then return 'cross'
  else return 'touch'
  end
end

function NPC:update(dt)
  if self.hp > 0 then
    self:move(dt)
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
  if self.invincible == 0 then
    for _,e in pairs(self.anims) do
      e:update(dt)
    end
  end
end

function NPC:getHit(dt, damage, dir, knockBack)
  self.hp = self.hp - damage
  knockBack = knockBack or 500
  self.invTime = love.timer.getTime()
  self.invincible = 6
  if self.AI ~= nil then
    self.AI.time = 0 
    self.AI.cooldown = 1 
  end
  self:moveDir(dir, dt, knockBack)
  if self.hp <= 0 then
    self:resetAnimations()
    self:setToDie()
    self:removeFromWorld()
  end
end

function NPC:flash(timeBetweenFlash)
  if self.invTime + timeBetweenFlash <= love.timer.getTime() then
    self.invTime = self.invTime + timeBetweenFlash
    self.invincible = self.invincible - 1
    if self.invincible <= 0 then self.invincible = 0 return end
  end
end

function NPC:setToDie()
  self.anims.current = self.anims.death
end

function NPC:draw()
  self.anims.current:draw(self.sheet, self.x, self.y, 0, self.scale, self.scale)
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
  anims.current = anims.south
  local values = {main = {2.5, 6, 6.5, 11}}
  local children = {}
  local hp = 100
  self.speed = 10
  Skeleton.super.initialize(self,true,x,y,sheet,w,h,anims,true,true,'rectangle',values,nil,scale,hp,true,false,{6.5},children)
  self.AI = Wander()
end

function Skeleton:move(dt)
  self.AI:move(self, dt)
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
    current = anim8.newAnimation(grid('1-3', 1, 2,1), 0.2),
    death = anim8.newAnimation(grid('1-3', 3, 1,4), 1, 'pauseAtEnd')
  }
  local values = {main = {0.5,0,8,8.5}}
  local children = {}
  local scale = 1/3
  local hp = 20
  self.speed = 15
  Bat.super.initialize(self,true,x,y,sheet,w,h,anims,true,true,'rectangle',values,nil,scale,hp,true,true,{5},children)
  self.AI = Wander()
end

function Bat:move(dt)
  self.AI:move(self,dt)
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

function Wander:move(entity, dt)
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
function Ground:initialize(spawn,x,y,sheet,w,h,anims,vis,col,shape,values,filter,scale,children,hazard)
  -- Not sure what values should be given here, but i'm certain it's probably gonna be handy in the longrun
  self.isHazard = hazard
  Ground.super.initialize(self,spawn,x,y,sheet,w,h,anims,vis,col,shape,values,filter,scale,nil,children)
end

Shadow = class('Shadow', Ground)

-- Should only be used as a childEntity

function Shadow:initialize(x,y,w,h,scale)
  if h == nil or h == 0 then
    scale = w
    w, h = 6.5, 0.65
  elseif scale == nil or scale == 0 then
    scale = h
    h = w/10
  end
  Shadow.super.initialize(self,true,x,y,nil,w,h,nil,true,false,nil,nil,nil,scale,nil,false)
end
 
function Shadow:update(dt)
  self:move(dt)
end

function Shadow:move(dt)
  self.x = self.Parent.x
  self.y = self.Parent.y
end

function Shadow:draw()
  love.graphics.setColor(0,0,0,0.5)  
  love.graphics.ellipse('fill', self.x, self.y, self.w*self.scale, self.h*self.scale)
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

Grid = class('Grid'):include(index)

function Grid:initialize(x,y,w,h,imageKey,scale,col,colValues,direction,filter)
  self.x = x
  self.y = y
  self.w = w
  self.h = h
  self.current = nil
  if self.images[imageKey] == nil then
    error("Didn't find '".. tostring(imageKey) .."' in images. Use the static method 'Grid:addImage(imagekey, fileLocation)' first before initializing object with that key...")
  else
    self.current = self.images[imageKey]
  end
  self.scale = scale
  self.col = col
  if colValues == nil then
    colValues = {0,0,0,0}
  else
    for i=1, #colValues do
      if colValues[i] == nil then
        colValues[i] = 0
      end
    end
  end
  self:setValues(x+colValues[1], y+colValues[2], colValues[3], colValues[4])
  self.direction = direction
  self.filter = filter
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

function Grid:addToWorld()
  local xMod = self.values[1]
  local yMod = self.values[2]
  local wMod = self.values[3]
  local hMod = self.values[4]
  world:add(self, xMod, yMod, wMod, hMod)
  self.col = true
end

function Grid:removeFromWorld()
  world:remove(self)
  self.col = false
end


function Grid:setValues(x,y,w,h)
  x = x or self.values[1] or self.x
  y = y or self.values[2] or self.y
  w = w or self.values[3] or self.w
  h = h or self.values[4] or self.h
  self.values = {x,y,w,h}
end


Tile = class('Tile', Grid)

function Tile:initialize(x,y,size,image,imageKey,scale)
  self.image = image
  Tile.super.initialize(self,x,y,w,h,imageKey,scale,false,nil,-1)
end

Wall = class('Wall', Grid)

function Wall:initialize(x,y,w,h,imageKey,scale,dir)
  local filter = function(item, other)  
    if other.isPlayerAttack then
      return 'cross'
    else
      return 'slide'
    end
  end
  local colValues = {0,0,w,h}
  Wall.super.initialize(self,x,y,w,h,imageKey,scale,true,colValues,dir,filter)
end

Corner = class('Corner', Wall)

function Corner:initialize(x,y,w,h,imageKey,scale,dir)
  Corner.super.initialize(self,x,y,w,h,imageKey,scale,dir)
end

Door = class('Door', Grid)

function Door:initialize(x,y,w,h,imageKey,scale,dir)
  local filter = function(item, other) return 'cross' end
  local colValues = {0,0,w,h}
  Door.super.initialize(self,x,y,w,h,imageKey,scale,true,colValues,dir,filter)
end

function Door:checkCollision()
  local actualX, actualY, cols, len = world:check(self, self.values[1], self.values[2], self.filter)
  for i=1, len do
    if cols[i].other:isInstanceOf(Witch) then
      
    end
  end
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
  local filter = function(item, other)  return 'cross' end
  local col = false
  if active then col = true end
  self.rotationSpeed = 80
  self.timer = 0
  self.loadSpeed = 8
  self.loading = shouldLoad
  if shouldLoad then
    self:setToLoad()
  end
  self.active = false 
  self.hidden = false
  local colValues = {5,5,6,6}
  if type(unkown) == 'table' then
    self:setchild(unkown)
  elseif type(unkown) == 'number' and desY ~= nil then
    self.desX = unkown
    self.desY = desY
  end
  self:resetRotations()
  Teleport.super.initialize(self,x,y,size,size,imageKey,scale,col,colValues,-1,filter)
end

function Teleport:setchild(child)
  self.child = child
  self.child.child = self
  self.desX = child.values[1]
  self.desY = child.values[2]
end

function Teleport:teleportEntity(entity)
  entity.x = self.desX
  entity.y = self.desY
  world:update(entity, self.desX, self.desY) 
end

function Teleport:addOnTeleport(f, ...)
  self.onTeleport = {f, {...}}
end

function Teleport:deactivate()
  self.active = false
  self.loading = false
  self.timer = 0
  self:removeFromWorld()
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
  self:addToWorld()
end

function Teleport:checkCollision()
  local actualX, actualY, cols, len = world:check(self, self.x, self.y, self.filter)
  for i = 1, len do
    if cols[i].other:isInstanceOf(Witch) then
      self:teleportEntity(cols[i].other)
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