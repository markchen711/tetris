local MenuState = require "class" ()
local playState = require "PlayingState"

function MenuState:init(gameManager)
    self.requestEnd = false
    self.gameManager = gameManager
end

function MenuState:update()

end

function MenuState:draw()
    local w, h = love.graphics.getDimensions()
    love.graphics.printf("From game menu, Hello world!", 0, h / 2 - 10, w, "center")
end

function MenuState:keypressed(key)
    if key == "return" then
        table.insert(self.gameManager.stateStack, playState(self.gameManager))
    elseif key == "escape" then
        self.requestEnd = true
    end
end

function MenuState:endState()
    print("end menu state")
end

return MenuState
