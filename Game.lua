local Game = {}
local love = _G.love

local menuState = require "MenuState"

function Game:init()
    -- Initialize member attributes
    self.score = 0
    self.gameOver = false
    self.stateStack = {}

    -- resources
    self.audios = {
        --triple = love.audio.newSource("Assets/Sfx/triple.wav", "static"),
        landing = love.audio.newSource("Assets/Sfx/landing.wav", "static"),
        rotate = love.audio.newSource("Assets/Sfx/rotate.wav", "static"),
        clear = love.audio.newSource("Assets/Sfx/clear.wav", "static"),
        lose = love.audio.newSource("Assets/Sfx/lose.wav", "static"),
    }

    self.textures = {
        playField = love.graphics.newImage("Assets/Images/NES-playfield.png")
    }
    self.textures.playField:setFilter("nearest", "nearest")
    self.quads = {
        fieldA = love.graphics.newQuad(6, 6, 257, 225, self.textures.playField:getDimensions()),
        fieldB = love.graphics.newQuad(267, 6, 257, 225, self.textures.playField:getDimensions()),
    }

    -- Initialize game
    table.insert(self.stateStack, menuState(self))
    return self
end

function Game:update(dt)
    local topState = self.stateStack[#self.stateStack]
    if not topState then love.event.quit() end
    topState:update(dt)

    if topState.requestEnd then
        topState:endState()
        table.remove(self.stateStack)
        if #self.stateStack == 0 then love.event.quit() end
    end
end

function Game:draw()
    local empty = #self.stateStack == 0
    if not empty then
        self.stateStack[#self.stateStack]:draw()
    end
end

function Game:keypressed(key)
    if #self.stateStack > 0 then
        self.stateStack[#self.stateStack]:keypressed(key)
    end
end

function Game:pushState(state, param)
    table.insert(Game.stateStack, self.states[state](param))
end

return Game:init()
