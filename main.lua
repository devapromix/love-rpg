local config = {totalMobs = 10}

local SWING_RANGE = 90
local SWING_DURATION = 0.25
local HIT_DELAY = 0.1
local PLAYER_SWORD_DMG = 10
local MELEE_RANGE = 65
local RANGED_RANGE = MELEE_RANGE * 5
local HERO_SPEED = 200
local PROJECTILE_SPEED = HERO_SPEED * 2

local json = require("lib.json")
local Player = require("game.player")
local Enemy = require("game.enemy")
local Projectile = require("game.projectile")

local ENEMY_TYPES = {}
local ENEMY_SPAWN_POOL = {}
local ENEMY_DISPLAY_ORDER = {}

local currentLevelNum = 1
local currentBossType = nil
local currentLevelTitle = nil
local maxLevel = 1

local player = Player.new()
local enemies = {}
local projectiles = {}
local score = 0
local spawned = 0
local swing = {active=false, time=0, progress=0, startAngle=0, hit=false}
local cooldown = 0

local gameState = "main_menu"
local menuSelection = 1
local levelSelectSelection = 1

local killsByType = {}
local damageDealt = 0
local damageTaken = 0

local function levelFilePath(n)
    return string.format("assets/levels/level%02d.json", n)
end

local function loadLevel(n)
    local path = levelFilePath(n)
    if not love.filesystem.getInfo(path) then return false end
    local raw = love.filesystem.read(path)
    local data = json.decode(raw)

    config.totalMobs = data.totalMobs
    ENEMY_SPAWN_POOL = data.spawnPool
    currentBossType = data.boss
    currentLevelTitle = data.title
    currentLevelNum = n
    return true
end

local function findMaxLevel()
    local i = 1
    while love.filesystem.getInfo(levelFilePath(i)) do i = i + 1 end
    return i - 1
end

local function resetLevelState()
    enemies = {}
    projectiles = {}
    score = 0
    spawned = 0
    swing.active = false
    cooldown = 0
    Player.reset(player)
end

local function buildStatsText()
    local lines = {
        "Level reached: " .. currentLevelNum,
        "Killed: " .. score .. "/" .. config.totalMobs
    }
    for _, name in ipairs(ENEMY_DISPLAY_ORDER) do
        local t = ENEMY_TYPES[name]
        local label = t and t.label or name
        local kills = killsByType[name] or 0
        table.insert(lines, "  " .. label .. ": " .. kills)
    end
    table.insert(lines, "Damage dealt: " .. damageDealt)
    table.insert(lines, "Damage taken: " .. damageTaken)
    return table.concat(lines, "\n")
end

local function pickEnemyType()
    if not ENEMY_SPAWN_POOL or #ENEMY_SPAWN_POOL == 0 then
        return "goblin"
    end
    local totalWeight = 0
    for _, name in ipairs(ENEMY_SPAWN_POOL) do 
        if ENEMY_TYPES[name] and ENEMY_TYPES[name].weight then
            totalWeight = totalWeight + ENEMY_TYPES[name].weight 
        end
    end
    if totalWeight <= 0 then
        return ENEMY_SPAWN_POOL[1] or "goblin"
    end
    local r = math.random() * totalWeight
    local cumulative = 0
    for _, name in ipairs(ENEMY_SPAWN_POOL) do
        if ENEMY_TYPES[name] and ENEMY_TYPES[name].weight then
            cumulative = cumulative + ENEMY_TYPES[name].weight
            if r <= cumulative then return name end
        end
    end
    return ENEMY_SPAWN_POOL[#ENEMY_SPAWN_POOL]
end

local function angleDiff(a, b)
    local d = (a - b) % (2*math.pi)
    if d > math.pi then d = d - 2*math.pi end
    return d
end

function love.load()
    ENEMY_TYPES = Enemy.loadTypes(MELEE_RANGE, RANGED_RANGE)
    ENEMY_DISPLAY_ORDER = {"goblin", "orc", "skeleton", "lizard", "imp", "ogre"}
    for name,_ in pairs(ENEMY_TYPES) do killsByType[name] = 0 end
    maxLevel = findMaxLevel()
    gameState = "main_menu"
end

function love.update(dt)
    if gameState ~= "playing" then return end

    Player.updateMovement(player, dt, HERO_SPEED)

    if spawned < config.totalMobs and #enemies < 8 and math.random() < 0.015 then
        local typeName = (spawned == config.totalMobs - 1) and currentBossType or pickEnemyType()
        local t = ENEMY_TYPES[typeName]

        if not t then
            typeName = "goblin"
            t = ENEMY_TYPES[typeName]
        end

        if not t then
            -- Жоден тип ворога (навіть "goblin") не завантажився з JSON.
            -- Пропускаємо спавн цього кадру замість краху гри.
            print("Warning: no enemy type data available, skipping spawn")
        else
            local a = math.random()*math.pi*2
            local isBoss = (typeName == currentBossType)

            local enemyDef = {
                etype = typeName,
                speed = t.speed,
                hp = t.hp,
                radius = t.radius,
                range = t.range,
                color = t.color,
                dmg = t.dmg,
                ranged = t.ranged,
                projectile = t.projectile,
                name = typeName
            }
            local e = Enemy.new(400+math.cos(a)*500, 300+math.sin(a)*500, enemyDef, isBoss)
            table.insert(enemies, e)
            spawned = spawned + 1
        end
    end

    -- Update enemies
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        local dmgThisFrame = Enemy.update(e, dt, player, projectiles, SWING_DURATION, HIT_DELAY, PROJECTILE_SPEED)
        damageTaken = damageTaken + dmgThisFrame
    end

	damageTaken = damageTaken + Projectile.updateAll(projectiles, dt, player)

    Player.updateAngle(player)
    if cooldown > 0 then cooldown = cooldown - dt end

    if swing.active then
        swing.time = swing.time - dt
        swing.progress = 1 - swing.time / SWING_DURATION
        if swing.time <= 0 then swing.active = false end
        if not swing.hit and (SWING_DURATION - swing.time) >= HIT_DELAY then
            swing.hit = true
            for i = #enemies, 1, -1 do
                local e = enemies[i]
                local dx, dy = e.x - player.x, e.y - player.y
                local dist = math.sqrt(dx*dx + dy*dy)
                local eangle = math.atan2(dy, dx)
                local currAngle = swing.startAngle + swing.progress * 2.0
                if dist < SWING_RANGE and math.abs(angleDiff(eangle, currAngle)) < 1.0 then
                    e.hp = e.hp - PLAYER_SWORD_DMG
                    e.flash = 0.15
                    damageDealt = damageDealt + PLAYER_SWORD_DMG
                    if e.hp <= 0 then
                        killsByType[e.etype] = (killsByType[e.etype] or 0) + 1
                        table.remove(enemies, i)
                        score = score + 1
                    end
                end
            end
        end
    end

    if player.flash > 0 then player.flash = player.flash - dt end
    if player.hp <= 0 then gameState = "game_over" end
    if score >= config.totalMobs and #enemies == 0 then
        gameState = "level_complete"
    end
end

function love.keypressed(key)
    if gameState == "main_menu" then
        if key == "up" then menuSelection = math.max(1, menuSelection-1)
        elseif key == "down" then menuSelection = math.min(3, menuSelection+1)
        elseif key == "return" or key == "kpenter" then
            if menuSelection == 1 then
                if loadLevel(1) then
                    resetLevelState()
                    gameState = "level_intro"
                end
            elseif menuSelection == 2 then
                levelSelectSelection = 1
                gameState = "level_select"
            elseif menuSelection == 3 then
                love.event.quit()
            end
        end

    elseif gameState == "level_select" then
        if key == "up" then levelSelectSelection = math.max(1, levelSelectSelection-1)
        elseif key == "down" then levelSelectSelection = math.min(maxLevel, levelSelectSelection+1)
        elseif key == "return" or key == "kpenter" then
            if loadLevel(levelSelectSelection) then
                resetLevelState()
                gameState = "level_intro"
            end
        elseif key == "escape" then
            gameState = "main_menu"
        end

    elseif gameState == "level_intro" then
        if key == "return" or key == "kpenter" then
            gameState = "playing"
        elseif key == "escape" then
            gameState = "main_menu"
        end

    elseif gameState == "level_complete" then
        if key == "return" or key == "kpenter" then
            if loadLevel(currentLevelNum + 1) then
                resetLevelState()
                gameState = "level_intro"
            else
                gameState = "game_win"
            end
        end

    elseif gameState == "game_win" or gameState == "game_over" then
        if key == "return" or key == "kpenter" then
            gameState = "main_menu"
            menuSelection = 1
        end
    end
end

function love.mousepressed(x, y, button)
    if gameState ~= "playing" then return end
    if button == 1 and not swing.active and cooldown <= 0 then
        swing.active = true
        swing.time = SWING_DURATION
        swing.progress = 0
        swing.hit = false
        swing.startAngle = player.angle - 1.0
        cooldown = 0.5
    end
end

function love.draw()
    if gameState == "main_menu" then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("=== HERO SLAYER ===", 0, 120, love.graphics.getWidth(), "center")
        local items = {"New Game", "Levels", "Exit"}
        for i, text in ipairs(items) do
            love.graphics.setColor(menuSelection == i and {1, 0.8, 0} or {1,1,1})
            love.graphics.printf(text, 0, 220 + i*50, love.graphics.getWidth(), "center")
        end

    elseif gameState == "level_select" then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("SELECT LEVEL", 0, 100, love.graphics.getWidth(), "center")
        for i = 1, maxLevel do
            local title = "Level " .. i
            local raw = love.filesystem.read(levelFilePath(i))
            if raw then
                local data = json.decode(raw)
                title = data.title or title
            end
            love.graphics.setColor(levelSelectSelection == i and {1,0.8,0} or {1,1,1})
            love.graphics.printf(title, 0, 180 + i*35, love.graphics.getWidth(), "center")
        end
        love.graphics.setColor(0.7,0.7,0.7)
        love.graphics.printf("ESC - Back to Menu", 0, 480, love.graphics.getWidth(), "center")

    elseif gameState == "level_intro" then
        love.graphics.setColor(1,1,1)
        love.graphics.printf("LEVEL " .. currentLevelNum, 0, 150, love.graphics.getWidth(), "center")
        love.graphics.setColor(1, 0.8, 0)
        love.graphics.printf(currentLevelTitle or ("Level " .. currentLevelNum), 0, 200, love.graphics.getWidth(), "center")
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Enemies to defeat: " .. config.totalMobs, 0, 260, love.graphics.getWidth(), "center")
        love.graphics.printf("Press ENTER to start", 0, 380, love.graphics.getWidth(), "center")
        love.graphics.setColor(0.7,0.7,0.7)
        love.graphics.printf("ESC - Back to Menu", 0, 480, love.graphics.getWidth(), "center")

    elseif gameState == "playing" then
        Player.draw(player)

        if swing.active then
            local curr = swing.startAngle + swing.progress * 2.0
            love.graphics.line(player.x, player.y, player.x + math.cos(curr)*SWING_RANGE, player.y + math.sin(curr)*SWING_RANGE)
        end

        for _, e in ipairs(enemies) do
            Enemy.draw(e)
        end

		Projectile.drawAll(projectiles)

        love.graphics.setColor(1,1,1)
        love.graphics.print("HP: " .. player.hp, 10, 10)
        love.graphics.print(currentLevelTitle or ("Level " .. currentLevelNum), 10, 30)
        love.graphics.print("Killed: " .. score .. "/" .. config.totalMobs, 10, 50)

    elseif gameState == "level_complete" then
        love.graphics.setColor(0,1,0)
        love.graphics.printf("LEVEL COMPLETE!", 0, 160, love.graphics.getWidth(), "center")
        love.graphics.setColor(1,1,1)
        love.graphics.print(buildStatsText(), 200, 250)
        love.graphics.printf("Press ENTER to continue", 0, 420, love.graphics.getWidth(), "center")

    elseif gameState == "game_win" then
        love.graphics.setColor(0,1,0)
        love.graphics.printf("YOU WIN THE GAME!\n\n" .. buildStatsText(), 0, 160, love.graphics.getWidth(), "center")
        love.graphics.printf("Press ENTER to return to menu", 0, 420, love.graphics.getWidth(), "center")

    elseif gameState == "game_over" then
        love.graphics.setColor(1,0,0)
        love.graphics.printf("GAME OVER", 0, 160, love.graphics.getWidth(), "center")
        love.graphics.setColor(1,1,1)
        love.graphics.print(buildStatsText(), 200, 250)
        love.graphics.printf("Press ENTER to return to menu", 0, 420, love.graphics.getWidth(), "center")
    end
end