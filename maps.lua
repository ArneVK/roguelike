--local world = require 'world'
--local anim8 = require 'lib.anim8'
require 'entities'

--[[
local wallDirections = {
  UP = 0,
  RIGHT = 1,
  DOWN = 2,
  LEFT = 3 
}
  
local cornerDirections = {
  TOPLEFT = 0,
  TOPRIGHT = 1,
  DOWNLEFT = 2,
  DOWNRIGHT = 3
}

defaultMap = {
    {2,3,3,3,3,2},
    {3,1,1,1,1,3},
    {3,1,1,1,1,3},
    {3,1,1,1,1,3},
    {3,1,1,1,1,3},
    {2,3,4,3,3,2}
}

-- HellLevel
tileMap = {
  {7,6,3,6,6,7},
  {6,5,5,5,5,6},
  {6,5,5,5,5,6},
  {6,5,5,5,5,6},
  {6,5,5,5,5,6},
  {7,6,6,6,6,7}
}

]]



mapX, mapY = -72, -140

defaultMapComplex = { -- test
  {{NOTH, 0}, {CORN, 0},{CORN, 3},{TILE, 0},{CORN, 2},{CORN, 1},{NOTH, 0}},
  {{CORN, 0}, {CORN, 3},{TILE, 0},{TILE, 0},{TILE, 0},{CORN, 2},{CORN, 1}},
  {{WALL, 3}, {TILE, 0},{TILE, 0},{TILE, 0},{TILE, 0},{TILE, 0},{CORN, 2}},
  {{WALL, 3}, {TILE, 0},{TILE, 0},{TELE, 0},{TILE, 0},{TILE, 0},{TILE, 0}},
  {{WALL, 3}, {TILE, 0},{TILE, 0},{TILE, 0},{TILE, 0},{TILE, 0},{CORN, 0}},
  {{CORN, 2}, {CORN, 1},{TILE, 0},{TILE, 0},{TILE, 0},{CORN, 0},{CORN, 3}},
  {{NOTH, 0}, {WALL, 3},{TILE, 0},{CORN, 0},{WALL, 2},{CORN, 3},{NOTH, 0}}
}

defaultMapEntities = {
  {Bat, 48, 80},
  {Bat, 85, 80},
  {Skeleton, 48, 47},
  {Cauldron, 85, 47}
}

defaultMapComplex2 = {
  {{NOTH, 0}, {CORN, 0},{WALL, 0},{DOOR, 0},{WALL, 0},{CORN, 1},{NOTH, 0}},
  {{NOTH, 0}, {WALL, 3},{TILE, 0},{TILE, 0},{TILE, 0},{WALL, 1},{NOTH, 0}},
  {{CORN, 0}, {CORN, 3},{TILE, 0},{TILE, 0},{TILE, 0},{CORN, 2},{CORN, 1}},
  {{WALL, 3}, {TELE, 2},{TILE, 0},{TILE, 0},{TILE, 0},{TELE, 1},{WALL, 1}},
  {{CORN, 2}, {CORN, 1},{TILE, 0},{TILE, 0},{TILE, 0},{CORN, 0},{CORN, 3}},
  {{NOTH, 0}, {WALL, 3},{TILE, 0},{TILE, 0},{TILE, 0},{WALL, 1},{NOTH, 0}},
  {{NOTH, 0}, {CORN, 2},{WALL, 2},{WALL, 2},{WALL, 2},{CORN, 3},{NOTH, 0}}
}


defaultMapEntities2 = {
  {Bat, 50, 30},
  {Bat, 86, 30},
  {Bat, 50, 95},
  {Bat, 86, 95}
}

function isTableAndValueEqual(table, value)
  local bool = false
  for _,v in ipairs(table) do
    if v == value then bool = true end
  end
  return bool
end
  
function getMapLengths(map, size)
  local width, height = 0, 0
  for y, r in ipairs(map) do
      height = height + 1
      if #r > width then
      width = #r
      end
  end
  return width*size, height*size
end

--[[
function getTrueMapLengths(map, size)
  for y, r in ipairs(map) do
    for x, m in ipairs(y) do
       local grid = m[1]

    end
  end
end
]]

function getDistanceBetweenPoints(x1, y1, x2, y2)
  return math.sqrt(math.pow(x1-x2, 2) + math.pow(y1-y2, 2))
end

function getMapRadiusAndCenter(sX, sY, map, size)
  local w, h = getMapLengths(map, size)
  local cX, cY = sX + (w/2) + size, sY + (h/2) + size
  local rad = { (w/2) + size, (h/2) + size}
  local x1, y1 = sX + (w/2) + size, sY
  local x2, y2 = sX, sY + (h/2) + size
  local pos = {{x1, y1}, {x2, y2}}
  return rad, {cX, cY}, pos 
  --[[
  for y, r in ipairs(map) do
    for x, m in ipairs(r) do
      local e = m[1]
      if e ~= NOTH then
        local eX, eY = sX + x*size, sY + y*size
        if eX > c[1] and eY < c[2] then
          eX = eX + size
        elseif eX < c[1] and eY > c[2] then
          eY = eY + size
        elseif eX > c[1] and eY > c[2] then
          eX = eX + size
          eY = eY + size
        end
        local dist = getDistanceBetweenPoints(eX, eY, c[1], c[2])
        if dist > rad then
          rad = dist
        end
      end
    end
    
  end]]
end

--[[
function prepareBatch(key, batch, id, class, scale, batchId)
    local classImage, wSize, hSize    
    classImage, wSize, hSize = class:getImage(key, batchId)
    local classBatch = love.graphics.newSpriteBatch(classImage)
    table.insert(batch, id, classBatch)
    classBatch:clear()
    return wSize*scale, hSize*scale
end
]]

function getWallData(startx, starty, x, y, wallDir, size, scale)
    local xCor, yCor, orient, xScale, yScale = 0, 0, 0, scale, scale
    if wallDir == 2 then
        -- Wall DOWN
        xCor, yCor, yScale = startx + x*size, starty + y*size+size, yScale * -1
    elseif wallDir == 3 then
        -- Wall LEFT
        xCor, yCor, orient = startx + x*size, starty + y*size+size, math.rad(270)
    elseif wallDir == 1 then
        --Wall RIGHT
        xCor, yCor, orient = startx + x*size+size, starty + y*size, math.rad(90)
    elseif wallDir == 0 then
        -- Wall UP
        xCor, yCor = startx + x*size, starty + y*size
    end
    return xCor, yCor, orient, xScale, yScale
end

function setWallFromCornerData(wall, walls, startx, starty, cx, cy, cDir, dir, scale, size)
  local w, h = wall:getDimensions()
--  w, h = w*scale, h*scale
  local horizontal = (dir == directions.WEST or dir == directions.EAST) and true or false
  local x, y, r, sX, sY, oX, oY = startx + cx*size, starty + cy*size, 0, scale, scale, 0, 0

  if cDir == 1 then
  -- Corner TOP RIGHT
    x = x + size
    if horizontal then
      sX = sX * -1
    else
      r = math.rad(90)
    end 
  elseif cDir == 3 then
  -- Corner DOWN RIGHT
      x = x + size
      y = y + size
    if horizontal then
      r = math.rad(180)
    else
      sY = sY * -1
      r = math.rad(270)
    end
  elseif cDir == 2 then
  -- Corner DOWN LEFT
    y = y + size  
    if horizontal then
      sY = sY * -1
    else
      r = math.rad(270)
    end
  elseif cDir == 0 then
  -- Corner TOP LEFT
    if not horizontal then
      x = x + size
      sY = sY * -1
      oY = h
      r = math.rad(90)
    end
  end
  table.insert(walls, {wall, x, y, r, sX, sY, oX, oY})
end

function setTrueCornerCoor(dir, x, y, size)
    if dir == 1 then
        x = x + size
    elseif dir == 2 then
        y = y + size
    elseif dir == 3 then
        x = x + size
        y = y + size
    end
    return x, y
end

-- Getting the length, middleX and middleY 
-- Length = length t'ill next corner
-- MiddleX and MiddleY = the coordinates for the middle between the next corner

function getLengthAndMiddleCoor(startx, starty, currx, curry, cornx, corny, dir, walldir, size)
    local newCornX, newCornY = setTrueCornerCoor(dir, startx + currx*size, starty + curry*size, size)
    local length = math.abs(newCornX - cornx)
    local modifierx = walldir == 0 and length/2 or walldir == 2 and (length/2)*-1 or 0
    local modifiery = walldir == 3 and length/2 or walldir == 1 and (length/2)*-1 or 0
    local middlex, middley = cornX + modifierx, cornY + modifiery
    return length, middlex, middley
end

function setCorner(startx, starty, x, y, batchKey, size, scale, dir, nextDir, bigGap)
    local cornrObject = Corner(startx + x*size, starty + y*size, size, batchKey, scale, dir)            
    local h = size
    if dir == 3 or dir == 2 then
      h = size - bigGap
    end
    cornrObject:setHitShape("main", true, "rectangle", 0,0, size, h)
    local xMod = nextDir == directions.EAST and 1 or nextDir == directions.WEST and -1 or 0
    local yMod = nextDir == directions.SOUTH and 1 or nextDir == directions.NORTH and -1 or 0
    local nextX, nextY = x + xMod, y + yMod
    return nextX, nextY
end

function setWall(startx, starty, x, y, batchKey, size, scale, dir, nextDir, bigGap)
  local wall = Wall(startx + x*size, starty + y*size, size, batchKey, scale, dir)
  local h = size
  if dir == 0 or dir == 2 then
    h = size - bigGap
  end
  wall:setHitShape("main", true, "rectangle", 0,0, size, h)
  local xMod = nextDir == directions.EAST and 1 or nextDir == directions.WEST and -1 or 0
  local yMod = nextDir == directions.SOUTH and 1 or nextDir == directions.NORTH and -1 or 0
  return x + xMod, y + yMod
end

function getNewDirectionFromCorner(oldDirection, newCornerDirection, counter)
  local Dir1 = (newCornerDirection == 0 or newCornerDirection == 2) and directions.EAST or
               (newCornerDirection == 1 or newCornerDirection == 3) and directions.WEST
  local Dir2 = (newCornerDirection == 0 or newCornerDirection == 1) and directions.SOUTH or
               (newCornerDirection == 2 or newCornerDirection == 3) and directions.NORTH       
  if (oldDirection == directions.SOUTH and Dir2 == directions.NORTH) or
  (oldDirection == directions.NORTH and Dir2 == directions.SOUTH) then
    return Dir1
  elseif (oldDirection == directions.EAST and Dir1 == directions.WEST) or
  (oldDirection == directions.WEST and Dir1 == directions.EAST) then
    return Dir2
  else
    --error('Corner: ' .. newCornerDirection .. ', oldDir: '.. oldDirection .. ', Dir1: ' .. Dir1 .. ', Dir2: ' .. Dir2 .. ', Counter: ' .. counter)
    error("Didn't find the new CornerDirection, something must have gone wrong...")
  end
end

function setNewXAndYFromDir(x, y, dir, isReset)
  if dir == directions.EAST then
    if isReset then y = y - 1 end
    x = x + 1  
  elseif dir == directions.WEST then
    if isReset then y = 1 end
    x = x - 1
  elseif dir == directions.NORTH then
    if isReset then x = 1 end
    y = y + 1
  elseif dir == directions.SOUTH then
    if isReset then x = x - 1 end
    y = y - 1
  end
  return x, y 
end

-- UNUSED
function setImageDataByDimensions(oldImageData, startx, starty, width, height)
  local newImageData = love.image.newImageData(width, height)
  for x=0, width-1 do
    for y=0, height-1 do
      local r,g,b,a = oldImageData:getPixel(startx + x, starty + y)
      newImageData:setPixel(x, y, r, g, b, a)
    end
  end
  return newImageData
end

function burpsMagicFunction(x, y, r, g, b, a)
  local minShear = 45
  local maxShear = 90
  local angle

  if x == 0 then
    angle = math.rad(minShear)
  elseif x < _G.wallLength - 1 then
    -- Got this from the Arduino 'map' function
    -- Basically 'maps' the angle to the walllength
    -- So when the wall is longer, it will take longer for the shear value to go
                    --(x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min
    angle = math.rad( x * minShear/(_G.wallLength - 1) + minShear )
  elseif x == _G.wallLength - 1 then
    angle = math.rad(maxShear)
  end

  local shear = 1/math.tan(angle)
  
  local newX = math.floor(x + shear*y) 
  
  if y > 0 then
    table.insert(_G.pixels, { x = newX, y = y, r = r, g = g, b = b, a = a})
    for i, pixelTable in pairs(_G.pixels) do
      if pixelTable.x == x and pixelTable.y == y then
        r, g, b, a = pixelTable.r, pixelTable.g, pixelTable.b, pixelTable.a
        table.remove(_G.pixels, i)
        return r, g, b, a
      end
    end
    return 0,0,0,0
  else
    return r, g, b, a
  end
end

function setWallWithShear(batchkey, newW, newH, images)
  local data = love.image.newImageData(newW, newH)
  local x,y = 0,0
  local idx = 1
  while(x < data:getWidth()-1) 
  do
    local currentImageData = images[idx]
    local width, height = currentImageData:getWidth(), currentImageData:getHeight()
    for X = 0, width - 1 do
      for Y = 0, height - 1 do
        local r,g,b,a = currentImageData:getPixel(X, Y)
        data:setPixel(x + X, Y, r, g, b, a)
      end
    end
    x = x + width
    idx = idx + 1
    if idx > #images then
      idx = 1
    end
  end

  _G.pixels = {}
  _G.wallLength = data:getWidth()
  
  data:mapPixel(burpsMagicFunction)
  -- Just so the global table doens't carry a table full of pixeldata forever
  _G.pixels = {}
  
  return data
end

function createBasicMap(map, key, settings)
  local sprite
  for y, Yvalues in ipairs(map) do
    for x, values in ipairs(Yvalues) do
      local ent = values[1]
      values[3] = ent == TILE and settings.Tile or
                  ent == TELE and settings.Teleport or
                  ent == CORN and settings.Corner or
                  ent == WALL and settings.Wall or
                  ent == DOOR and settings.Door or 0
    end
  end
  return map
end


                        --(*xCord,*yCord,*name,*map,*tele/*entryX,<*entryY>,<table>)
                                              -- /explanation settings/
                                              -- {wall,corner,door,tile,teleport,size,scale,complexMap} 
                                              -- All tablevalues must have keys for corresponding settings
                                              -- wall, door, corner, tile and teleport should be tables, with each value
                                              -- being the value of the sprite for that gridentity
                                              -- When you use 'addImage', the return value is the key for the sprite
                                              --  EXAMPLE     
                                              -- {wall = {4, 3}, door = {5, 1} , teleport = {2, 1}, size = 16, scale = 1/2 }
                                              -- if left nil, defaults will be used (not recommended)


function genMapBatchComplex(startx, starty, batchKey, map, entry, entryY, size, scale, invertedSymmetry)

    local tiles = {}
    local walls = {}
    
    local returnTeleport 

    local bigGap = 8
    --  witch.h/2, so walls that are up have a 'higher' hitbox. Makes standing near walls more 'realistic looking'
    local smallGap = 4
    -- Unused  

    if entry:isInstanceOf(Teleport) then
        invertedSymmetry = scale
        scale = size
        size = entryY
    end

    settings = settings or {}

    scale = scale or 1/2
    local actualSize = size or 32
    size = actualSize*scale
    invertedSymmetry = invertedSymmetry or false

    local lastCornerDir, lastCornerSprite
    local cornerX, cornerY, cornerDirection
    local newX, newY
    local startCornerX, startCornerY
    local startCornerFound, finishedWalls = false, false
    local wallTable = {}

    for y, r in ipairs(map) do
      for x, m in ipairs(r) do
      
      local v = m[1]
      local dir = m[2]
      local sprite = m[3]

      if v == CORN then
        -- Gotta start searching for a corner first before we get the data of each wall
        -- I just start searching for a random corner that's positioned TOPLEFT, and start getting Walldata while going DOWN, then RIGHT, UP and end with going LEFT
        if dir == cornerDirections.TOPLEFT and not startCornerFound then
            cornerDirection = directions.SOUTH
            lastCornerDir, lastCornerSprite = dir, sprite
            newX, newY = setCorner(startx, starty, x, y, batchKey, size, scale, dir, cornerDirection, bigGap)
            cornerX, cornerY = x, y
            startCornerX, startCornerY = x, y
            startCornerFound = true
        end   
      else
        if v == TELE then
          local teleImg = Teleport:getImage(batchKey, sprite)
          if dir == teleportDirections.EXIT or dir == teleportDirections.HIDDENEXIT then
            returnTeleport = Teleport(startx + x*size, starty + y*size, size, teleImg, batchKey, scale, false, entry, entryY)
            if dir == teleportDirections.HIDDENEXIT then
              returnTeleport:hideToggle()
            end
          else
            local tele = Teleport(startx + x*size, starty + y*size, size, teleImg, batchKey, scale, false, entry, entryY)
            if dir == teleportDirections.HIDDENENTRY then
              tele:hideToggle()
            end
          end
        elseif v == TILE then
          if tiles[sprite] == nil then
            local tileImg = Tile:getImage(batchKey, sprite)
            tiles[sprite] = love.graphics.newSpriteBatch(tileImg)
          end
          tiles[sprite]:add(startx + x*size, starty + y*size, 0, scale, scale)
        end
      end
    end
  end

  local counter = 0

  while(startCornerFound and not finishedWalls and counter < 100) do
      -- counter == failsafe
      -- Remove it (or increase the limit) when you want bigger maps or w/e
      -- Like, probably only is a problem with REAL big maps
      counter = counter + 1    
      
        -- So, what happens if the wall doesn't reach a new corner?
        if newY > #map or newY < 1 or newX > #map[1] or newX < 1 or (map[newY][newX][1] ~= WALL and map[newY][newX][1] ~= CORN and map[newY][newX][1] ~= DOOR) then
          -- First, draw the wall to whatever end it's facing
          local images = {}
          local image = Corner:getImageData(batchKey, lastCornerSprite)
          table.insert(images, image)
          local newWidth = actualSize
          for key, value in ipairs(wallTable) do
            image = Wall:getImageData(batchKey, wallTable[key][4])
            newWidth = newWidth + actualSize
            table.insert(images, image)
          end               
                            --setWallWithShear(batchkey, newW, newH, images)
          local walldata = setWallWithShear(batchKey, newWidth, actualSize, images)
          local wall1 = love.graphics.newImage(walldata)
          
          setWallFromCornerData(wall1, walls, startx, starty, cornerX, cornerY, lastCornerDir, cornerDirection, scale, size)
          
          wallTable = {}

          -- Then, try and get a new corner/wall/door (by going in the direction it should be going)
          -- These next values are assuming that the walls started drawing in the TOP LEFT (important)
          local newCornerDirection
          if cornerDirection == directions.SOUTH then
            cornerDirection = directions.NORTH
            newCornerDirection = directions.EAST
          elseif cornerDirection == directions.NORTH then
            cornerDirection = directions.SOUTH
            newCornerDirection = directions.WEST
          elseif cornerDirection == directions.WEST then
            cornerDirection = directions.EAST
            newCornerDirection = directions.NORTH
          elseif cornerDirection == directions.EAST then
            cornerDirection = directions.WEST                        
            newCornerDirection = directions.SOUTH
          end
          if newY > #map or newY < 1 or newX > #map[1] or newX < 1 then
            newX, newY = setNewXAndYFromDir(newX, newY, newCornerDirection, true)
          else
            newX, newY = setNewXAndYFromDir(newX, newY, newCornerDirection, false)
          end
          -- I honestly don't know how this works
          -- *'waving my dick in the wind' plays in background*
          for y, r in pairs(map) do
            for x, m in pairs(r) do
              local v = m[1]
              local newDir2 = m[2]
              local sprite = m[3]
              if y == newY and x == newX then
                if v == TILE then
                  newX, newY = setNewXAndYFromDir(newX, newY, newCornerDirection, false)
                else
                  if v == CORN then
                    local images = {}
                    local image = Corner:getImageData(batchKey, sprite)
                    table.insert(images, image)
                    local newWidth = actualSize
                    for key, value in ipairs(wallTable) do
                      image = Wall:getImageData(batchKey, wallTable[key][4])
                      newWidth = newWidth + actualSize
                      table.insert(images, image)
                    end               
                                      --setWallWithShear(batchkey, newW, newH, images)
                    local walldata = setWallWithShear(batchKey, newWidth, actualSize, images)
                    local wall1 = love.graphics.newImage(walldata)
                    
                    setWallFromCornerData(wall1, walls, startx, starty, newX, newY, newDir2, cornerDirection, scale, size)
                    
                    wallTable = {}

                    cornerDirection = getNewDirectionFromCorner(cornerDirection, map[newY][newX][2], counter)
                    cornerX, cornerY = newX, newY
                    lastCornerDir, lastCornerSprite = map[newY][newX][2], sprite
                    newX, newY = setCorner(startx, starty, newX, newY, batchKey, size, scale, map[newY][newX][2], cornerDirection, bigGap)

                    break
                  else
                    table.insert(wallTable, {newX, newY, map[newY][newX][2], map[newY][newX][3]})
                    setWall(startx, starty, newX, newY, batchKey, size, scale, map[newY][newX][2], cornerDirection, bigGap)
                    newX, newY = setNewXAndYFromDir(newX, newY, newCornerDirection, false)
                  end
                end
              end
            end
          end
        elseif map[newY][newX][1] == WALL or map[newY][newX][1] == DOOR then
          table.insert(wallTable, {newX, newY, map[newY][newX][2], map[newY][newX][3]})
          newX, newY = setWall(startx, starty, newX, newY, batchKey, size, scale, map[newY][newX][2], cornerDirection, bigGap)
        elseif map[newY][newX][1] == CORN then 
          if #wallTable % 2 ~= 0 then
            -- Do smth for the (possible) doors
            -- also, have some /weird/ code to get the middle index of a table with an odd amount of elements
            local middle = #wallTable/2 + 0.5
            local middleX, middleY = wallTable[middle][1], wallTable[middle][2]
            -- DOORS SHOULD ONLY BE IN THE MIDDLE OF AN ODD WALL ANYWAY
            if map[middleY][middleX][1] == DOOR then
              local doorId = map[middleY][middleX][3]
              middleImage = Door:getImage(batchKey, doorId)
              local xCor, yCor, orient, xScale, yScale = getWallData(startx, starty, wallTable[middle][1], wallTable[middle][2], wallTable[middle][3], size, scale)
              table.insert(walls, {middleImage, xCor, yCor, orient, xScale, yScale, 0, 0})
              table.remove(wallTable, middle)
            end
          end
          
          local images1, images2 = {}, {}
          local image1 = Corner:getImageData(batchKey, lastCornerSprite)
          table.insert(images1, image1)
          local image2 = Corner:getImageData(batchKey, map[newY][newX][3])
          table.insert(images2, image2)


          local newWidth = actualSize
          local isEven = #wallTable % 2 == 0 and true or false
          local passedMiddle = false
          local lastImage
          for i = 0.5, #wallTable, 0.5 do
            
            if not passedMiddle then
              if not isEven and i == #wallTable/2 then
                newWidth = newWidth + actualSize/2
                local image = Wall:getImageData(batchKey, wallTable[i + 0.5][4])
                local half = invertedSymmetry and setImageDataByDimensions(image, actualSize/2, 0, actualSize/2, actualSize) or
                setImageDataByDimensions(image, 0, 0, actualSize/2, actualSize)
                lastImage = half
                table.insert(images1, half)
                passedMiddle = true
              else
                if i == math.floor(i) then
                  newWidth = newWidth + actualSize
                  local image = Wall:getImageData(batchKey, wallTable[i][4])
                  table.insert(images1, image)
                  if isEven and i == #wallTable/2 then
                    passedMiddle = true
                  end
                end
              end
            else
              if i == math.floor(i) then
                local image = Wall:getImageData(batchKey, wallTable[i][4])
                table.insert(images2, image)
              end
            end
          end
          if lastImage ~= nil then
            table.remove(images2, #images2)
            table.insert(images2, lastImage)
          end               
                            --setWallWithShear(batchkey, newW, newH, images)
          local walldata1 = setWallWithShear(batchKey, newWidth, actualSize, images1)
          local walldata2 = setWallWithShear(batchKey, newWidth, actualSize, images2)
          local wall1 = love.graphics.newImage(walldata1)
          local wall2 = love.graphics.newImage(walldata2)
          
          setWallFromCornerData(wall1, walls, startx, starty, cornerX, cornerY, lastCornerDir, cornerDirection, scale, size)
          setWallFromCornerData(wall2, walls, startx, starty, newX, newY, map[newY][newX][2], cornerDirection, scale, size)
          
          wallTable = {}
          
          if newX == startCornerX and newY == startCornerY then
            finishedWalls = true
            break
          end

          cornerDirection = getNewDirectionFromCorner(cornerDirection, map[newY][newX][2], counter)
          cornerX, cornerY = newX, newY
          lastCornerDir, lastCornerSprite = map[newY][newX][2], map[newY][newX][3]
          newX, newY = setCorner(startx, starty, newX, newY, batchKey, size, scale, map[newY][newX][2], cornerDirection, bigGap)

        end
    end
  return tiles, walls, returnTeleport or -1
end

function getEntryCoorMap(startx, starty, map, key, scale, tele)
    tele = tele or 2
    local image = Teleport:getImage(key, 1)
    local size = image:getWidth()
    local returnX, returnY
    for y, r in ipairs(map) do
        for x, m in ipairs(r) do
        local v = m[1]
        local w = m[2]
        if v == tele and (w == teleportDirections.ENTRY or w == teleportDirections.HIDDENENTRY) then
            returnX, returnY = startx + x*size*scale + size*scale/2, starty + y*size*scale + size*scale/2
            return returnX, returnY
        end
        end
    end
    return -1, -1
end