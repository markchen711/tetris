local Game = require "Game"
function love.load()
    math.randomseed(os.time())
end

function love.update(dt)
    Game:update(dt)
end

function love.draw()
    Game:draw()
end

function love.keypressed(key)
    Game:keypressed(key)
end
