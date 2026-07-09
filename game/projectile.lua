local Projectile = {}

function Projectile.spawn(projectiles, x, y, angle, speed, dmg, kind)
table.insert(projectiles, {
x = x,
y = y,
vx = math.cos(angle) * speed,
vy = math.sin(angle) * speed,
dmg = dmg,
kind = kind
})
end

function Projectile.updateAll(projectiles, dt, player)
local ww, wh = love.graphics.getDimensions()
local damageTaken = 0
for i = #projectiles, 1, -1 do
    local p = projectiles[i]

    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt

    local dx = player.x - p.x
    local dy = player.y - p.y
    local dist = math.sqrt(dx*dx + dy*dy)

    if dist < player.size/2 + 5 then
        player.hp = player.hp - p.dmg
        player.flash = 0.15
        damageTaken = damageTaken + p.dmg

        table.remove(projectiles, i)

    elseif p.x < -50 or p.x > ww+50 or p.y < -50 or p.y > wh+50 then
        table.remove(projectiles, i)
    end
end

return damageTaken

end

function Projectile.drawAll(projectiles)
for _, p in ipairs(projectiles) do
if p.kind == "fireball" then
love.graphics.setColor(1, 0.3, 0)
love.graphics.circle("fill", p.x, p.y, 6)
else
love.graphics.setColor(1,1,1)
        local angle = math.atan2(p.vy, p.vx)

        love.graphics.push()
        love.graphics.translate(p.x, p.y)
        love.graphics.rotate(angle)

        love.graphics.line(-8, 0, 8, 0)

        love.graphics.pop()
    end
end

end

return Projectile
