local love = _G.love
local ffi = require "ffi"
local playState = require "class" ()

ffi.cdef [[typedef struct { int8_t x, y;} vec2_t;

typedef struct {
    uint8_t positions[24][10];
  } board;
]]

local vec2i
local mt = {
    __add = function(a, b)
        return vec2i(a.x + b.x, a.y + b.y)
    end,
    __len = function(a)
        return math.sqrt(a.x * a.x + a.y * b.y)
    end,
    __index = {
        -- Waring, these functions take action on vectors directly
        rotate_by_90 = function(a)
            a.x, a.y = -a.y, a.x
        end,
        rotate_by_neg90 = function(a)
            a.x, a.y = a.y, -a.x
        end,
        offset = function(x, y)
            a.x, a.y = a.x + x, a.y + y
        end
    },
    __eq = function(a, b)
        return a.x == b.x and a.y == b.y
    end
}
vec2i = ffi.metatype("vec2_t", mt)

local tetrominoes = {
    { vec2i(-2, 0), vec2i(-1, 0), vec2i(0, 0),   vec2i(1, 0) },   -- I
    { vec2i(0, 0),  vec2i(0, -1), vec2i(-1, 0),  vec2i(-1, -1) }, -- O
    { vec2i(-1, 0), vec2i(0, 0),  vec2i(1, 0),   vec2i(1, -1) },  -- J
    { vec2i(-1, 0), vec2i(0, 0),  vec2i(1, 0),   vec2i(-1, -1) }, -- L
    { vec2i(0, 0),  vec2i(1, 0),  vec2i(-1, -1), vec2i(0, -1) },  -- S
    { vec2i(-1, 0), vec2i(0, 0),  vec2i(1, 0),   vec2i(0, -1) },  -- T
    { vec2i(-1, 0), vec2i(0, 0),  vec2i(0, -1),  vec2i(1, -1) }   -- Z
}

local rgba = function(r, g, b, a) return { love.math.colorFromBytes(r, g, b, a) } end
local colors = { rgba(1, 237, 250, 255), rgba(254, 251, 52, 255),
    rgba(46, 46, 132, 255), rgba(255, 200, 46, 255), rgba(83, 218, 63, 255),
    rgba(221, 10, 178, 255), rgba(234, 20, 28, 255) }


function playState:init(gameManager)
    self.gameManager         = gameManager
    self.requestEnd          = false
    self.score               = 0
    self.timePerUpdate       = .16
    self.timeSinceLastUpdate = 0
    self.moveInterval        = 0
    self.lastClickTime       = 0
    self.doubleClickMax      = .14
    self.board               = ffi.new("int8_t[24][10]")
    self.tetrominoes         = tetrominoes
    self.queue               = { math.random(7), math.random(7), math.random(7) }
    self.dropTetromino       = self:newTetromino({ shape = {} })
    self.gridSize            = 32
    self.gameOver            = false

    -- background
    self.playField           = love.graphics.newCanvas()
    love.graphics.setCanvas(self.playField)
    love.graphics.scale(4, 4)
    love.graphics.draw(gameManager.textures.playField, gameManager.quads.fieldA, 0, 0)
    love.graphics.setCanvas()
end

function playState:update(dt)
    if self.gameOver then return end
    self.timeSinceLastUpdate = self.timeSinceLastUpdate + dt
    self.moveInterval = self.moveInterval + dt
    if self.timeSinceLastUpdate > self.timePerUpdate then
        self.timeSinceLastUpdate = self.timeSinceLastUpdate - self.timePerUpdate
        if self:collide(0, -1) then -- If collide bottom
            local tetro = self.dropTetromino
            for _, v in ipairs(tetro.shape) do
                local freezed = tetro.origin + v
                self.board[freezed.y][freezed.x] = tetro.shapeId
            end
            tetro = self:newTetromino(tetro) -- tetro is reused instead of creating new one

            self:clearRow()                  -- Score if any
            if self:checkGameOver() then     -- If lose
                self.gameManager.audios.lose:play()
                self.gameOver = true
            end
        else
            self.dropTetromino.origin.y = self.dropTetromino.origin.y - 1
        end
    end
    if self.moveInterval > .1 then
        if love.keyboard.isDown("left") and not self:collide(-1, 0) then
            self.dropTetromino.origin.x = self.dropTetromino.origin.x - 1
            self.moveInterval = 0
        elseif love.keyboard.isDown("right") and not self:collide(1, 0) then
            self.dropTetromino.origin.x = self.dropTetromino.origin.x + 1
            self.moveInterval = 0
        elseif love.keyboard.isDown("down") and not self:collide(0, -1) then
            self.dropTetromino.origin.y = self.dropTetromino.origin.y - 1
            self.moveInterval = 0
        end
    end
end

function playState:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.playField, 0, 0)
    local size = self.gridSize
    local board_x, board_y = 386, 801
    for i = 0, 19 do
        for j = 0, 9 do
            if self.board[i][j] ~= 0 then
                love.graphics.setColor(colors[self.board[i][j]])
                love.graphics.rectangle("fill", board_x + j * size + 1,
                    board_y - (i + 1) * size + 1, size - 2, size - 2, 4, 4)
            end
        end
    end

    -- draw flying tetromino
    local tetro = self.dropTetromino
    love.graphics.setColor(colors[tetro.shapeId])
    for _, vec in ipairs(tetro.shape) do
        if vec.y + tetro.origin.y < 20 then
            love.graphics.rectangle("fill",
                board_x + (tetro.origin.x + vec.x) * size + 1,
                board_y - (tetro.origin.y + vec.y + 1) * size + 1,
                size - 2, size - 2, 4, 4)
        end
    end

    self:showQueue()
    love.graphics.setColor(1, 1, 1, 1)
end

function playState:keypressed(key)
    if key == "escape" then
        self.requestEnd = true
    elseif key == "up" and self.dropTetromino.rotatable then
        self.gameManager.audios.rotate:play()
        for _, vec in ipairs(self.dropTetromino.shape) do
            vec:rotate_by_neg90()
        end
        if self:collide(0, 0) then
            -- rotate back if collide after rotate
            for _, vec in ipairs(self.dropTetromino.shape) do
                vec:rotate_by_90()
            end
        end
    elseif key == "down" then
        --self.dropTetromino.origin.y = self.dropTetromino.origin.y - 1
        local time = os.time()
        if time - self.lastClickTime < self.doubleClickMax then
            while not self:collide(0, -1) do
                self.dropTetromino.origin.y = self.dropTetromino.origin.y - 1
            end
            self.gameManager.audios.landing:play()
        end
        self.lastClickTime = time
    end
end

function playState:collide(offsetX, offsetY)
    -- determine collision after adding offset to tetromino
    local tetro = self.dropTetromino
    for _, vec in ipairs(tetro.shape) do
        local newPosition = vec + tetro.origin + vec2i(offsetX, offsetY)
        -- board is 0 to 9 instead, sorry for inconvinience
        if newPosition.x < 0 or newPosition.x > 9 or newPosition.y < 0 then return true end
        if self.board[newPosition.y][newPosition.x] ~= 0 then
            return true
        end
    end
    return false
end

function playState:endState()
    print("Close play state, do stuff before close here")
end

function playState:showScore()

end

function playState:showQueue()
    local size = self.gridSize
    -- draw next tetromino
    --local x, y = love.mouse.getPosition()
    local x, y = self.queue[1] <= 2 and 836 or 818, self.queue[1] == 1 and 474 or 452
    love.graphics.setColor(colors[self.queue[1]])
    for _, vec in ipairs(tetrominoes[self.queue[1]]) do
        love.graphics.rectangle("fill", x + vec.x * size + 1,
            y - vec.y * size + 1, size - 2, size - 2, 4, 4)
    end
end

function playState:newTetromino(recycle)
    local shape = table.remove(self.queue, 1) -- new shape is drawn from the queue
    table.insert(self.queue, math.random(7))  -- insert one to the queue
    local dropTetromino = recycle
    dropTetromino.shapeId = shape
    dropTetromino.origin = vec2i(math.random(2, 7), 23)
    dropTetromino.rotatable = shape ~= 2
    for i = 1, 4 do
        dropTetromino.shape[i] = vec2i(tetrominoes[shape][i].x, tetrominoes[shape][i].y)
    end
    return dropTetromino
end

function playState:clearRow()
    local counter, n = 0, 19
    while counter <= n do
        local fullRow = true
        for j = 0, 9 do
            if self.board[counter][j] == 0 then
                fullRow = false
                break
            end
        end
        if fullRow then
            self.gameManager.audios.clear:play()
            -- shift every row down, start from row i + 1
            for row = counter, 19 do
                for j = 0, 9 do
                    self.board[row][j] = self.board[row + 1][j]
                end
            end
            n, counter = n - 1, counter - 1 -- check the row being shifted down.
        end
        counter = counter + 1
    end
end

function playState:checkGameOver()
    for i = 0, 9 do
        if self.board[20][i] ~= 0 then return true end
    end
    return false
end

return playState
