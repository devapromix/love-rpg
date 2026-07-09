local Projectile = require("game.projectile")
local json = require("lib.json")

local Enemy = {}

local SWING_DURATION = 0.25
local HIT_DELAY = 0.1

local ENEMY_TYPES = {}

local function resolveRange(rawRange, MELEE_RANGE, RANGED_RANGE)
    if rawRange == "melee" then return MELEE_RANGE
    elseif rawRange == "ranged" then return RANGED_RANGE
    else return rawRange end
end

function Enemy.loadTypes(MELEE_RANGE, RANGED_RANGE)
    local names = {"goblin", "orc", "skeleton", "lizard", "imp", "ogre"}
    for _, name in ipairs(names) do
        local path = "assets/data/enemies/" .. name .. ".json"
        local raw = love.filesystem.read(path)
        if raw then
            local def = json.decode(raw)
            ENEMY_TYPES[name] = {
                label = def.label, hp = def.hp, dmg = def.dmg, speed = def.speed,
                radius = def.radius, range = resolveRange(def.range, MELEE_RANGE, RANGED_RANGE), color = def.color,
                ranged = def.ranged, projectile = def.projectile, weight = def.weight,
                boss = def.boss
            }
        end
    end
    return ENEMY_TYPES
end

function Enemy.getType(name)
    return ENEMY_TYPES[name]
end

function Enemy.new(x, y, typeDef, isBoss)
    local radius = typeDef.radius
    local hp = typeDef.hp
    local dmg = typeDef.dmg
    local range = typeDef.range

    if isBoss then
        radius = radius * 1.5
        hp = hp * 2
        dmg = dmg * 1.2
        range = range * 1.25
    end

    return {
        x = x,
        y = y,
        speed = typeDef.speed,
        hp = hp,
        maxHp = hp,
        radius = radius,
        range = range,
        attackTimer = 0,
        swing = {active = false, time = 0, progress = 0, startAngle = 0, hit = false},
        flash = 0,
        etype = typeDef.etype or typeDef.name,
        color = typeDef.color,
        dmg = dmg,
        ranged = typeDef.ranged,
        projectile = typeDef.projectile,
        isBoss = isBoss or false
    }
end

function Enemy.update(e, dt, player, projectiles, SWING_DURATION, HIT_DELAY, PROJECTILE_SPEED)
    local dx, dy = player.x - e.x, player.y - e.y
    local d = math.sqrt(dx*dx + dy*dy)

    if e.ranged then
        if d > e.range then
            e.x = e.x + (dx/d) * e.speed * dt
            e.y = e.y + (dy/d) * e.speed * dt
        else
            e.attackTimer = (e.attackTimer or 0) - dt
            if e.attackTimer <= 0 then
                local angle = math.atan2(dy, dx)
                Projectile.spawn(
projectiles,
e.x,
e.y,
angle,
PROJECTILE_SPEED,
e.dmg,
e.projectile
)

                e.attackTimer = e.isBoss and 1.2 or 1.5
                e.flash = 0.12
            end
        end
    else
        local attackRange = e.radius + player.size/2 + 8

        if d > attackRange then
            e.x = e.x + (dx/d) * e.speed * dt
            e.y = e.y + (dy/d) * e.speed * dt
        else
            e.attackTimer = (e.attackTimer or 0) - dt
            if e.attackTimer <= 0 and not (e.swing and e.swing.active) then
                e.swing = e.swing or {active=false, time=0, progress=0, startAngle=0, hit=false}
                e.swing.active = true
                e.swing.time = SWING_DURATION
                e.swing.progress = 0
                e.swing.hit = false
                e.swing.startAngle = math.atan2(dy, dx) - 1.0
                e.attackTimer = e.isBoss and 1.0 or 1.2
            end
        end

        if e.swing and e.swing.active then
            e.swing.time = e.swing.time - dt
            e.swing.progress = 1 - e.swing.time / SWING_DURATION
            local elapsed = SWING_DURATION - e.swing.time

            if not e.swing.hit and elapsed >= HIT_DELAY then
                e.swing.hit = true
                local hdx = player.x - e.x
				local hdy = player.y - e.y
				local hd = math.sqrt(hdx*hdx + hdy*hdy)

				if hd < attackRange + 10 then
                    player.hp = player.hp - e.dmg
                    player.flash = 0.18
                    return e.dmg
                end
            end
            if e.swing.time <= 0 then e.swing.active = false end
        end
    end

    if e.flash then e.flash = math.max(0, e.flash - dt) end
    return 0
end

function Enemy.draw(e)
    love.graphics.setColor((e.flash or 0) > 0 and {1,0,0} or e.color)
    love.graphics.circle("fill", e.x, e.y, e.radius)
    if e.swing and e.swing.active then
        local curr = e.swing.startAngle + e.swing.progress * 2.0
        love.graphics.line(e.x, e.y, e.x + math.cos(curr)*(e.radius*3), e.y + math.sin(curr)*(e.radius*3))
    end
end

return Enemy