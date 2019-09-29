--local world = require 'world'
--local anim8 = require 'lib.anim8'
require 'entities'
require 'maps'
require 'shaders'

console = {
  enabled = false,
  messages = {},
  font = love.graphics.newFont(16)
}

camera = {
  locked = false,
  entity = nil,
  x = 0,
  y = 0,
  scale = 8
}

function console:toggle()
  self.enabled = not self.enabled
end

function console:log(str)
  if not self.enabled then return end
  table.insert(self.messages, str)
end

function console:draw()
  if not self.enabled then return end

  love.graphics.push()
  love.graphics.origin()
  love.graphics.setFont(self.font)
  local h = self.font:getHeight()
  for i, m in ipairs(self.messages) do
    love.graphics.print(m, 0, h * (i-1))
  end
  love.graphics.pop()

  console.messages = {}
end

Debug = 0


function giveBorders(x,y,w,h)
  love.graphics.setColor(1,0,0)
  love.graphics.rectangle("line", x,y,w,h)
  love.graphics.setColor(1,1,1)
end

function drawTileBatch(tiles, teleport)
  for v, tile in pairs(tiles) do
    love.graphics.draw(tile)
  end
end

function drawTeleporters(teleport)
  for _, teleport in pairs(gridList) do
    if teleport:isInstanceOf(Teleport) then
      -- Gotta send those vars so the shader knows at wich corners he's gotta draw the star
      -- Get updated automatically in teleport class function 'update'
      teleportShader:send('hidden', teleport.hidden)
      teleportShader:send('renderedAmount', teleport.timer/teleport.loadSpeed)
      teleportShader:send('corners', teleport.rotations[1], teleport.rotations[2], teleport.rotations[3], teleport.rotations[4], teleport.rotations[5])
      love.graphics.setShader(teleportShader)
      if teleport.active or teleport.loading then
        love.graphics.drawLayer(teleport.image, 1, teleport.x, teleport.y, 0, teleport.scale, teleport.scale)
      else
        love.graphics.drawLayer(teleport.image, 2, teleport.x, teleport.y, 0, teleport.scale, teleport.scale)
      end
      love.graphics.drawLayer(teleport.image, 3, teleport.x, teleport.y, 0, teleport.scale, teleport.scale)
      love.graphics.setShader()
    end
  end
end

function drawWalls(walls)
  for _, table in pairs(walls) do
    local wall, x, y, r, sX, sY, oX, oY = table[1], table[2], table[3], table[4], table[5], table[6], table[7], table[8]
    love.graphics.draw(wall, x, y, r, sX, sY, oX, oY)
  end
end

function love.keypressed(key, code, isRepeat)
  if not isRepeat then
    if key == 'f5' then
      --scale = scale > 1 and scale - 1 or 1
      --love.window.setMode(64*scale, 64*scale)
      camera.scale = camera.scale - 0.5
      love.graphics.scale(camera.scale)
      print('f5')
    elseif key == 'f6' then
      --scale = scale + 1
      camera.scale = camera.scale + 0.5 
      love.graphics.scale(camera.scale) 
      --love.window.setMode(64*scale, 64*scale)
      print('f6')
    elseif key == 'f12' then
      console:toggle()
    end
  end
end

function camera:followEntity()
  local width, height, flags = love.window.getMode()
  local x, y = love.graphics.inverseTransformPoint(width/2, height/2)
  x, y = x/self.scale, y/self.scale
  love.graphics.scale(self.scale, self.scale)
  local w, h, scale = self.entity.animPos.w, self.entity.animPos.h, self.entity.scale
  love.graphics.translate(-self.entity.x+x-(w*scale), -self.entity.y+y-(h*scale/2))
end

function camera:keepLocked()
  love.graphics.scale(self.scale, self.scale)
  love.graphics.translate(-self.x, -self.y)
end

function camera:resetScale()
  self.scale = 8
end

function camera:lockToMap(map, size, x, y) 
  local w, h = getMapLengths(map, size)
  local width, height, flags = love.window.getMode()
  local minWindow = math.min(width, height)
  local xMod = 0
  local yMod = 0
  if minWindow == width then yMod = height/(self.scale*6) end
  if minWindow == height then xMod = width/(self.scale*6) end
  local maxMap = math.max(w, h)
  self.scale = minWindow/maxMap
  self.x = x + size - xMod
  self.y = y + size - yMod
  self.locked = true
end

local spawnEntitiesFunction = function(args)
  local x = args[1]
  local y = args[2]
  local entities = args[3]
  local map = args[4]
  local size = args[5] or 16
  for _,e in pairs(entities) do
    local obj = e[1]:new(x + e[2], y + e[3])
    obj:addToWorld()
    table.insert(entityIndexes, obj.mainIndex)
  end
  camera:lockToMap(map, size, x, y)
end

local goBackToSpawnFunc = function(args)
  camera.locked = false
  camera:followEntity()
  camera:resetScale()
end

function rearrangeListOnYaxis(item1, item2)
  if item1.y + (item1.h*item1.scale) ~= item2.y + (item2.h*item2.scale) then
    return item1.y + (item1.h*item1.scale) < item2.y + (item2.h*item2.scale)
  else
    return item1.mainIndex < item2.mainIndex
  end
end

function setShading(center, radii, positions)
  local centerX, centerY = love.graphics.transformPoint(center[1], center[2])
  local x1, y1 = love.graphics.transformPoint(positions[1][1], positions[1][2])
  local x2, y2 = love.graphics.transformPoint(positions[2][1], positions[2][2])
  shadingShader:send('center', {centerX, centerY})
  shadingShader:send('positions', {x1, y1}, {x2, y2})
  love.graphics.setColor(0,0,0)  
  love.graphics.setShader(shadingShader)
  love.graphics.ellipse("fill", center[1], center[2], radii[1], radii[2])
  love.graphics.setShader()
  love.graphics.setColor(1,1,1)
end

function love.draw()
  love.graphics.clear()
  if not camera.locked then
    camera:followEntity()
  else
    camera:keepLocked()
  end
  
  witch:draw()
  --[[
  drawTileBatch(defaultTiles)
  drawTeleporters()

  for _, e in ipairs(entityList) do
    if e:isInstanceOf(Ground) and e.spawned and not e:isInstanceOf(Shadow) then
      e:draw()
    end
  end

  for _,e in ipairs(entityList) do
    if e:isInstanceOf(Shadow) then
      e:draw()
    end
  end

  drawWalls(defaultWalls) 

  for _, e in ipairs(entityList) do
    if e.spawned and not e:isInstanceOf(Ground) and
    (e.invincible == nil or e.invincible == 0 or (e.invincible % 2 == 0)) then
      if e.overlayState == nil and (not e.hasOverlay or e.hasOverlay == nil) then
        e:draw()    
      elseif e.hasOverlay then
        for _, c in pairs(e.children) do
          if c.overlayState ~= nil and not c.overlayState then
            c:draw()
          end
        end
        e:draw()
        for _, c in pairs(e.children) do
          if c.overlayState then
            c:draw()
          end
        end
      end
    end
  end

  setShading(defaultCenter, defaultRadii, defaultPos)

  if console.enabled then
    for _, e in pairs(gridList) do 
      if e.col then
        giveBorders(world:getRect(e))    
      end
    end
    for _, e in pairs(entityList) do
      if e.col then
        giveBorders(world:getRect(e))
      end
    end
  end

  for _, h in pairs(HudElements) do
    h:draw()
  end

  ]]
  console:log("x: " .. witch.x .. " y: " .. witch.y)
  console:log(Debug, witch.x-24, witch.y-20)
  console:draw()
end

function love.update(dt)

  witch:update(dt)
  --[[
  Hud:update()

  table.sort(entityList, rearrangeListOnYaxis)

  for _,e in pairs(entityList) do
    --if e:isInstanceOf(Melee) or
    if e:isInstanceOf(Witch) or
    e:isInstanceOf(Bat) or 
    e:isInstanceOf(Skeleton) or 
    e:isInstanceOf(Cauldron) or 
    e:isInstanceOf(Shadow) then
      e:update(dt)
    end
    if e.isEnemy and e.invincible ~= 0 then
      e:flash(0.1)
    end
  end

  --testtest
  if hasBeenInRoom and (tele2 ~= nil and tele2 ~= -1) and next(entityIndexes) == nil then
    tele2:setToLoad()
    hasBeenInRoom = false
  end
  
  for _,e in pairs(gridList) do
    if e:isInstanceOf(Teleport) then
      e:update(dt)
    end
  end
  ]]
end

function love.load()
 -- love.window.setMode(scale*64,scale*64)
  love.window.setTitle('WitchDagger')
  love.graphics.setDefaultFilter("nearest")
 
  witch = Witch:new(0,0)
  camera.entity = witch
  --[[
  Hud:load(witch)
  witch:addToWorldWithChildren()

  local tileId = Tile:addImage('default', 'sprites/brick_tile.png')

  local teleId = Teleport:addImage('default', 'sprites/brick_tile.png')
  
  local wallId = Wall:addImage('default', 'sprites/brick_wall_no_border.png')
  Wall:addImage('default', 'sprites/brick_wall.png')
  local cornerId = Corner:addImage('default', 'sprites/brick_wall_1border.png')
  local doorId = Door:addImage('default', 'sprites/penta_wall.png')

  local settings = {Wall = wallId, Tile = tileId, Corner = cornerId, Door = doorId, Teleport = teleId}

  local roomMap = createBasicMap(defaultMapComplex2, 'default', settings)

  hellTiles = {}
  hellWalls = {}
  hellTiles[1] = love.graphics.newSpriteBatch(love.graphics.newImage('sprites/hell_tile.png'))
  hellWalls[2] = love.graphics.newSpriteBatch(love.graphics.newImage('sprites/hell_wall.png'))
  hellWalls[3] = love.graphics.newSpriteBatch(love.graphics.newImage('sprites/hell_corner.png'))
  
  local TestId = Teleport:addImage('test', 'sprites/black_layer.png')

  local teleImg = Teleport:getImage('test', TestId)

  local entryX, entryY = getEntryCoorMap(mapX, mapY, roomMap, 'default', 1/2)

  local tele = Teleport(-2, 30, 16, teleImg, 'test', 1/2, true, entryX, entryY)
  tele:addOnTeleport(spawnEntitiesFunction, mapX, mapY, defaultMapEntities2, roomMap)

  defaultTiles, defaultWalls, tele2 = genMapBatchComplex(mapX, mapY, 'default', roomMap, tele, 32, 1/2, true)
  defaultRadii, defaultCenter, defaultPos = getMapRadiusAndCenter(mapX, mapY, roomMap, 16)
  if tele2 ~= -1 then
    tele2:setchild(tele)
    tele2:addOnTeleport(goBackToSpawnFunc)
  end
  ]]
end
