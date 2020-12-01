Timer = require 'timer'

---------------------------------------
-- configs
---------------------------------------

WIDTH = 1280
HEIGHT = 720

function init()
    PAD_WIDTH = 100
    PAD_HEIGHT = 10
    PAD_INIT_X = WIDTH / 2 - PAD_WIDTH / 2
    PAD_INIT_Y = HEIGHT - PAD_HEIGHT - 10
    PAD_SPEED = 400
    PAD_SIDE_BUFFER = 5
    PAD_WIGGLE = 1.5
    PAD_WIGGLE_DURATION = .5

    BALL_SIZE = 10
    BALL_X = WIDTH/2 - BALL_SIZE/2
    BALL_Y = 500
    BALL_VEL = 4
    BALL_VEL_SCALE = 2
    BALL_ACC_TIME = 120
    BALL_THETA_VARIATION = .1
    BALL_COLOR = { r = 1, g = .92, b = .23 }

    NOTIF_DELAY = 5
    NOTIF_FADE = 2
    NOTIF_X = 15
    NOTIF_Y = 15
    FONT_HEIGHT = love.graphics.getFont():getHeight()

    BRICK_ROWS = 5
    BRICK_COLS = 10
    BRICK_WIDTH = 75
    BRICK_HEIGHT = 40
    BRICK_FADE = 1

    BRICK_COLORS = {
        [1] = {r = .96, g = .26, b = .21}, -- red
        [2] = {r = .91, g = .12, b = .39}, -- pink
        [3] = {r = .61, g = .15, b = .69}, -- purple
        [4] = {r = .40, g = .23, b = .72}, -- deep purple
        [5] = {r = .25, g = .32, b = .71}  -- indigo
    }
end
---------------------------------------
-- love2d callbacks
---------------------------------------

function love.load()
    if love.system.getOS() == "NX" then
        PLATFORM = "SWITCH"
    else
        PLATFORM = "PC"
    end

    if PLATFORM == "PC" then
        WIDTH = 1000
        HEIGHT = 600
        love.window.setMode(WIDTH, HEIGHT, {borderless = true, centered = true})
    elseif PLATFORM == "SWITCH" then
        joystick = love.joystick.getJoysticks()[1]
    end

    init()

    lives = 3
    score = 0
    gameLose = false
    gameWin = false

    if PLATFORM == "SWITCH" then
        font = love.graphics.newFont(20)
        FONT_HEIGHT = 22
        love.graphics.setFont(font)
    else
        font = love.graphics.getFont()
    end
    
    text = love.graphics.newText(font, 'time: XXX\nlives: '..lives)

    timer = Timer()
    paddle = createPaddle()
    ball = createBall()
    notification = createNotification()
    bricks = createBricks()

    notification:notify('platform: '..PLATFORM)
    notification:notify('resolution: '..WIDTH..'x'..HEIGHT)
    notification:notify('paused')
    gamePause = true
    gameTime = 0
end

function love.update(dt)
    if score >= BRICK_COLS * BRICK_ROWS then
        gameWin = true
    end
    if not gameWin and not gameLose then
        gameTime = gameTime + dt
        timer:update(dt)
        if not gamePause then
            paddle:update(dt)
            ball:update(dt)
        end
    end
end

function love.draw()
    if gameWin then drawWin()
    elseif gameLose then drawLose()
    else
        notification:draw()
        if gamePause then drawPause()
        else
            bricks:draw()
            paddle:draw()
            ball:draw()
            drawTimeLives()
        end
    end
    drawWindowOutline()
end

-- PC controls
function love.keypressed(key, scancode, isrepeat)
    if key == 'escape' then
        if gamePause or gameLose or gameWin then love.event.quit()
        else
            gamePause = true
            notification:notify('paused')
        end
    end

    if key == 'space' then
        if gamePause then notification:notify('unpaused') end
        gamePause = false
    end

    if key == 'r' then
        love.load()
    end

end

-- SWITCH controls
function love.gamepadpressed(joystick, button)
    if button == 'start' or button == 'back' then
        if gamePause or gameLose or gameWin then love.event.quit()
        else
            gamePause = true
            notification:notify('paused')
        end
    end

    if button == 'b' then
        if gamePause then notification:notify('unpaused') end
        gamePause = false
    end

    if button == 'y' then
        love.load()
    end
end


---------------------------------------
-- create game objects
---------------------------------------

function createPaddle()
    local p = {
        rect = { x = PAD_INIT_X, y = PAD_INIT_Y, width = PAD_WIDTH, height = PAD_HEIGHT },
        wiggleFactor = 0,
        animHandle = nil,
        speed = PAD_SPEED
    }

    function p:draw()
        love.graphics.setColor(1,1,1)
        love.graphics.rectangle('fill', 
            self.rect.x - self.wiggleFactor, self.rect.y - self.wiggleFactor,
            self.rect.width + self.wiggleFactor * 2, self.rect.height + self.wiggleFactor)
    end

    function p:update(dt)
        if PLATFORM == "SWITCH" then
            local a1, a2, a3, a4 = joystick:getAxes()
            if joystick:isGamepadDown('dpleft') or a1 < -.5 or a3 < -.5 then self.rect.x = self.rect.x - self.speed * dt end
            if joystick:isGamepadDown('dpright') or a1 > .5 or a3 > .5 then self.rect.x = self.rect.x + self.speed * dt end
        elseif PLATFORM == "PC" then
            if love.keyboard.isDown('left') then self.rect.x = self.rect.x - self.speed * dt end
            if love.keyboard.isDown('right') then self.rect.x = self.rect.x + self.speed * dt end
        end

        self.rect.x = math.max(PAD_SIDE_BUFFER, self.rect.x)
        self.rect.x = math.min(WIDTH - PAD_SIDE_BUFFER - PAD_WIDTH, self.rect.x)
    end

    function p:wiggle()
        if self.animHandle then timer:cancel(self.animHandle) end
        self.wiggleFactor = PAD_WIGGLE
        self.animHandle = timer:tween(PAD_WIGGLE_DURATION, self, {wiggleFactor=0}, 'out-elastic', function()
            self.wiggleFactor = 0
        end)
    end

    return p
end

function createBall()
    local b = {
        pos = nil,
        vel = nil,
        vel_scale = 1,
        size = BALL_SIZE,
        col = BALL_COLOR
    }

    function b:initBall()
        self.pos = { x = BALL_X, y = BALL_Y }
        self:setRandomTheta()
    end

    function b:setRandomTheta()
        local t = math.pi * (.5 - (BALL_THETA_VARIATION/2) + (math.random() * BALL_THETA_VARIATION))
        self.vel = { x = BALL_VEL * math.cos(t), y = BALL_VEL * math.sin(t) }
    end

    function b:draw()
        love.graphics.setColor(self.col.r, self.col.g, self.col.b)
        love.graphics.circle('fill', self.pos.x, self.pos.y, self.size / 2)
    end

    local function collideBricks(x1, y1, x2, y2)
        local gx, gy = bricks:pos_to_grid(x1, y1)
        local gx2, gy2 = bricks:pos_to_grid(x2, y2)

        local dx = gx2 - gx
        local dy = gy2 - gy

        if gx2 > 0 and gx2 <= BRICK_COLS and gy2 > 0 and gy2 <= BRICK_ROWS and bricks:hit(gx2, gy2) then
            notification:notify('brick ('..gx2..', '..gy2..')')
            -- get pixel coords of top left corner of current grid pos
            local px, py = bricks:grid_to_pos(gx, gy)

            local top_active = bricks:is_active(gx, gy-1)
            local bottom_active = bricks:is_active(gx, gy+1)
            local left_active = bricks:is_active(gx-1,gy)
            local right_active = bricks:is_active(gx+1, gy)

            if dx > 0 then
                if dy > 0 then -- bottom right
                    if bottom_active then
                        bricks:hit(gx, gy+1)
                        b:bounceUp(py + BRICK_HEIGHT)
                    end
                    if right_active then
                        bricks:hit(gx+1, gy)
                        b:bounceLeft(px + BRICK_WIDTH)
                    end

                elseif dy < 0 then -- top right
                    if top_active then
                        bricks:hit(gx, gy-1)
                        b:bounceDown(py)
                    end
                    if right_active then
                        bricks:hit(gx+1, gy)
                        b:bounceLeft(px + BRICK_HEIGHT)
                    end
                else -- right
                    bricks:hit(gx+1, gy)
                    b:bounceLeft(px + BRICK_WIDTH)
                end

            elseif dx < 0 then
                if dy > 0 then -- bottom left
                    if bottom_active then
                        bricks:hit(gx, gy+1)
                        b:bounceUp(py + BRICK_HEIGHT)
                    end
                    if left_active then
                        bricks:hit(gx-1, gy)
                        b:bounceLeft(px)
                    end

                elseif dy < 0 then -- top left
                    if top_active then
                        bricks:hit(gx, gy-1)
                        b:bounceDown(py)
                    end
                    if left_active then
                        bricks:hit(gx-1, gy)
                        b:bounceRight(px)
                    end

                else -- left
                    bricks:hit(gx-1, gy)
                    b:bounceRight(px)
                end

            else -- dx == 0
                if dy > 0 then -- bottom
                    bricks:hit(gx, gy+1)
                    b:bounceUp(py + BRICK_HEIGHT)
                elseif dy < 0 then -- top
                    bricks:hit(gx, gy-1)
                    b:bounceDown(py)
                end -- else inside brick but did not change grid pos, don't bounce
            end
        end
    end

    function b:bounceLeft(reflect_x)
        self.vel.x = math.abs(self.vel.x) * -1
        self.pos.x = self.pos.x - ((self.pos.x - reflect_x) * 2)
    end
    function b:bounceRight(reflect_x)
        self.vel.x = math.abs(self.vel.x)
        self.pos.x = self.pos.x - ((self.pos.x - reflect_x) * 2)
    end
    function b:bounceUp(reflect_y)
        self.vel.y = math.abs(self.vel.y) * -1
        self.pos.y = self.pos.y - ((self.pos.y - reflect_y) * 2)
    end
    function b:bounceDown(reflect_y)
        self.vel.y = math.abs(self.vel.y)
        self.pos.y = self.pos.y - ((self.pos.y - reflect_y) * 2)
    end

    function b:update(dt)
        -- save to compare later
        local oldx = self.pos.x
        local oldy = self.pos.y

        -- add velocity to pos
        self.pos.x = self.pos.x + (self.vel.x * self.vel_scale)
        self.pos.y = self.pos.y + (self.vel.y * self.vel_scale)

        -- left wall
        if self.pos.x <= 0 then
            notification:notify('left wall')
            self:bounceRight(0)
        end

        -- right wall
        if self.pos.x > WIDTH then
            notification:notify('right wall')
            self:bounceLeft(WIDTH)
        end

        -- ceiling
        if self.pos.y <= 0 then
            notification:notify('ceiling')
            self:bounceDown(0)
        end

        -- paddle
        if oldy <= paddle.rect.y and self.pos.y > paddle.rect.y then
            if (oldx + self.size/2 > paddle.rect.x and oldx  - self.size/2 <= paddle.rect.x + paddle.rect.width) or 
            (self.pos.x + self.size/2 > paddle.rect.x and self.pos.x - self.size/2 <= paddle.rect.x + paddle.rect.width) then
                notification:notify('paddle')

                -- map paddle collision point to bounce angle
                -- hit left side of paddle -> bounce left, hit middle -> bounce up etc
                local new_theta = map_range(paddle.rect.x + paddle.rect.width, paddle.rect.x, 1.9*math.pi, 1.1*math.pi, self.pos.x)
                
                self:bounceUp(paddle.rect.y)

                -- polar to cartesian
                self.vel.x = BALL_VEL * math.cos(new_theta)
                self.vel.y = BALL_VEL * math.sin(new_theta)
                paddle:wiggle()
            end
        -- floor
        elseif self.pos.y > HEIGHT then
            notification:notify('floor')
            lives = lives - 1
            if lives < 1 then gameLose = true end
            --self:bounceUp(HEIGHT)
            paddle.rect.x = PAD_INIT_X
            b:initBall()
        end

        -- bricks, don't want to collide with anything else + bricks in same frame
        -- if not collided then collideBricks(oldx, oldy, self.pos.x, self.pos.y) end
        collideBricks(oldx, oldy, self.pos.x, self.pos.y)
    end

    b:initBall()
    timer:tween(BALL_ACC_TIME, b, {vel_scale=BALL_VEL_SCALE})
    return b
end

function createNotification() 
    local n = {}

    n.nodeQueue = { first = 0, last = -1 }

    local function push(node)
        local q = n.nodeQueue
        local last = q.last + 1
        q.last = last
        q[last] = node
    end

    local function pop()
        local q = n.nodeQueue
        local first = q.first
        if first > q.last then error('tried to pop empty notification queue') end
        q[first] = nil
        q.first = first + 1
    end

    local function isEmpty()
        return n.nodeQueue.first > n.nodeQueue.last
    end

    function n:notify(message)
        print(message)
        local node = { text = message, opacity = 1 }
        push(node)

        timer:script(function(wait)
            wait(NOTIF_DELAY)
            timer:tween(NOTIF_FADE, node, {opacity = 0}, 'linear', pop)
        end)
    end

    function n:draw()
        local q = self.nodeQueue
        local i = q.first
        while i <= q.last do
            love.graphics.setColor(1,1,1, q[i].opacity)
            love.graphics.print(q[i].text, NOTIF_X, NOTIF_Y - (FONT_HEIGHT * (i - q.last)))
            i = i + 1
        end
    end

    return n
end

function createBricks()
    b = {
        base_x = WIDTH / 2 - (BRICK_COLS * BRICK_WIDTH / 2),
        base_y = BRICK_HEIGHT * BRICK_ROWS / 2,
        rows = {}
    }

    for y=1,BRICK_ROWS do
        local row = {}
        for x=1,BRICK_COLS do
            row[x] = {opacity = 1, is_active = true}
        end
        b.rows[y] = row
    end

    function b:draw()
        for y=1,BRICK_ROWS do
            local row = self.rows[y]
            local color = BRICK_COLORS[y]
            for x=1,BRICK_COLS do
                local brick = row[x]
                love.graphics.setColor(color.r, color.g, color.b, brick.opacity)
                local px, py = self:grid_to_pos(x, y)
                love.graphics.rectangle('fill', px, py, BRICK_WIDTH, BRICK_HEIGHT)
            end
        end
    end

    function b:pos_to_grid(px, py)
        px = px - self.base_x
        px = px - (px % BRICK_WIDTH)

        py = py - self.base_y
        py = py - (py % BRICK_HEIGHT)

        local gx = (px/BRICK_WIDTH) + 1
        local gy = (py/BRICK_HEIGHT) + 1

        return gx, gy
    end

    function b:grid_to_pos(gx, gy)
        return self.base_x + ((gx-1) * BRICK_WIDTH), self.base_y + ((gy-1) * BRICK_HEIGHT)
    end

    local function is_out_of_bounds(gx, gy)
        return gx < 1 or gy < 1 or gy > BRICK_ROWS or gx > BRICK_COLS
    end

    function b:hit(gx, gy)
        if is_out_of_bounds(gx, gy) then return false end
        local brick = self.rows[gy][gx]
        local a = brick.is_active
        if a then
            score = score + 1
            brick.is_active = false
            timer:tween(BRICK_FADE, brick, {opacity = 0}, 'out-quint')
        end
        return a
    end

    function b:is_active(gx, gy)
        if is_out_of_bounds(gx, gy) then return false end
        return self.rows[gy][gx].is_active
    end

    return b
end

---------------------------------------
-- utilities, misc.
---------------------------------------

function initBall()

end

function drawWindowOutline()
    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', 0, 0, WIDTH-1, HEIGHT-1)
end

function drawPause()
    love.graphics.setColor(1,1,1)

    if PLATFORM == "PC" then
        love.graphics.print('[escape] pause, exit game\n[space] unpause\n[r] reset game', NOTIF_X, HEIGHT - (FONT_HEIGHT * 3) - NOTIF_Y)
    elseif PLATFORM == "SWITCH" then
        love.graphics.print('[-/+] pause, exit game\n[a] unpause\n[x] reset game', NOTIF_X, HEIGHT - (FONT_HEIGHT * 3) - NOTIF_Y)
    end
end

function drawWin()
    love.graphics.setColor(1,1,1)

    if PLATFORM == "PC" then
        love.graphics.print('you win! time: \n[esc] to exit\n[r] to reset\ntime: '..gameTime, NOTIF_X, NOTIF_Y)
    elseif PLATFORM == "SWITCH" then
        love.graphics.print('you win! time: \n[-/+] to exit\n[x] to reset\ntime: '..gameTime, NOTIF_X, NOTIF_Y)
    end
end

function drawLose()
    love.graphics.setColor(1,1,1)
    if PLATFORM == "PC" then
        love.graphics.print('you lose :,(\n[esc] to exit\n[r] to reset', NOTIF_X, NOTIF_Y)
    elseif PLATFORM == "SWITCH" then
        love.graphics.print('you lose :,(\n[-/+] to exit\n[x] to reset', NOTIF_X, NOTIF_Y)
    end
end

function drawTimeLives()
    love.graphics.setColor(1,1,1)
    love.graphics.print('time: '..(math.floor(gameTime))..'\nlives: '..lives..'\nscore: '..score, WIDTH - text:getWidth() - NOTIF_X, NOTIF_Y)
end

function intersect(rect1, rect2)
    if rect1.y < rect2.y + rect2.height or rect1.y + rect1.height > rect2.y then
        return false
    end
    if rect1.x + rect1.width < rect2.x or rect1.x > rect2.x + rect2.width then
        return false
    end

    return true
end

function map_range(a1, a2, b1, b2, s)
    return b1 + (s-a1)*(b2-b1)/(a2-a1)
end

function cross_product(x1, y1, x2, y2)
    return (x1*y2) - (y1*x2)
end
