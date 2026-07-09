local Player = {}

function Player.new()
    return {
        x = 400,
        y = 300,
        size = 20,
        hp = 100,
        angle = 0,
        color = {1, 1, 0},
        flash = 0
    }
end

function Player.updateMovement(player, dt, HERO_SPEED)
    if love.keyboard.isDown("left") then player.x = player.x - HERO_SPEED * dt end
    if love.keyboard.isDown("right") then player.x = player.x + HERO_SPEED * dt end
    if love.keyboard.isDown("up") then player.y = player.y - HERO_SPEED * dt end
    if love.keyboard.isDown("down") then player.y = player.y + HERO_SPEED * dt end
end

function Player.updateAngle(player)
    player.angle = math.atan2(love.mouse.getY() - player.y, love.mouse.getX() - player.x)
end

function Player.draw(player)
    love.graphics.setColor(player.flash > 0 and {1, 0, 0} or player.color)
    love.graphics.push()
    love.graphics.translate(player.x, player.y)
    love.graphics.rotate(player.angle)
    love.graphics.rectangle("fill", -player.size/2, -player.size/2, player.size, player.size)
    love.graphics.pop()
end

function Player.reset(player)
    player.x, player.y = 400, 300
    player.hp = 100
    player.flash = 0
end

return Player