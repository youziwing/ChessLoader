local CHESS_URL   = "https://raw.githubusercontent.com/youziwing/Chess-/refs/heads/main/Main.lua"
local ROCHESS_URL = "https://raw.githubusercontent.com/youziwing/RoChessM/refs/heads/main/Main.lua"

local CHESS_IDS   = { 6222531507 }
local ROCHESS_IDS = { 139717576471404 }

if _G.__ChessLoaderStop then pcall(_G.__ChessLoaderStop) end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local Mouse      = Players.LocalPlayer:GetMouse()

-- Theme -------------------------------------------------------------
local C = {
    panel   = Color3.fromRGB(22, 25, 33),
    line    = Color3.fromRGB(45, 50, 64),
    text    = Color3.fromRGB(235, 238, 245),
    sub     = Color3.fromRGB(140, 148, 165),
    off     = Color3.fromRGB(52, 56, 68),
    blue    = Color3.fromRGB(58, 115, 210),
    blueHot = Color3.fromRGB(78, 138, 235),
    green   = Color3.fromRGB(46, 150, 98),
    greenHot= Color3.fromRGB(62, 175, 118),
}
local VK_1, VK_2, VK_CTRL = 0x31, 0x32, 0x11

-- Drawing helpers ---------------------------------------------------
local PW, PH = 320, 186
local originX, originY = 60, 140
local z, elements = 0, {}

local function set(obj, props)
    for k, v in pairs(props) do pcall(function() obj[k] = v end) end
end

local function add(kind, ox, oy, props)
    local o = Drawing.new(kind)
    z = z + 1
    set(o, props)
    set(o, { ZIndex = z, Position = Vector2.new(originX + ox, originY + oy), Visible = true })
    elements[#elements + 1] = { obj = o, ox = ox, oy = oy }
    return o
end

local function label(ox, oy, text, size, color, center, bold)
    return add("Text", ox, oy, {
        Text = text, Size = size, FontSize = size, Color = color,
        Center = center or false, Outline = false,
        Font = bold and Drawing.Fonts.SystemBold or Drawing.Fonts.System,
    })
end

-- Build UI ----------------------------------------------------------
add("Square", 0, 0, { Size = Vector2.new(PW, PH), Color = C.panel, Filled = true, Corner = 12 })
label(20, 14, "Chess Loader", 18, C.text, false, true)
label(20, 38, "Pick a game to load", 13, C.sub)
add("Square", 20, 62, { Size = Vector2.new(PW - 40, 1), Color = C.line, Filled = true })

local buttons = {}
local function makeButton(y, name, url, ids, key, base, hot)
    local w, h = PW - 40, 42
    local disabled = (url == "")
    local bg = add("Square", 20, y, {
        Size = Vector2.new(w, h), Color = disabled and C.off or base, Filled = true, Corner = 8,
    })
    label(PW / 2, y + 12, name, 16, C.text, true, true)
    label(PW - 38, y + 13, key, 14, disabled and C.sub or C.text, true)
    buttons[#buttons + 1] = {
        bg = bg, ox = 20, oy = y, w = w, h = h, name = name, url = url, ids = ids,
        base = base, hot = hot, disabled = disabled,
    }
end
makeButton(76,  "Chess!",  CHESS_URL,   CHESS_IDS,   "1", C.blue,  C.blueHot)
makeButton(128, "RoChess", ROCHESS_URL, ROCHESS_IDS, "2", C.green, C.greenHot)

-- State -------------------------------------------------------------
local selected, pending, busy, visible = nil, nil, false, true
local autoMode = false
local dragging, dragDX, dragDY, wasDown = false, 0, 0, false
local keyWas = {}

local function log(text) print("[Chess Loader] " .. text) end

local function reposition()
    for _, e in ipairs(elements) do
        e.obj.Position = Vector2.new(originX + e.ox, originY + e.oy)
    end
end

local function setVisible(v)
    visible = v
    for _, e in ipairs(elements) do e.obj.Visible = v end
end

local function pressed(vk)
    local d = iskeypressed(vk)
    local p = d and not keyWas[vk]
    keyWas[vk] = d
    return p
end

-- Loading -----------------------------------------------------------
local function runLoad(b)
    local okGet, src = pcall(httpget, b.url)
    if not okGet or not src or src == "" then
        return log("Download failed (check URL / connection)")
    end
    if src:sub(1, 3) == "404" then
        return log("404: file not found at that URL")
    end

    local fn = loadstring(src)
    if not fn then return log(b.name .. ": compile failed") end

    local okRun, err = pcall(fn)
    if not okRun then
        return log(b.name .. " error: " .. tostring(err))
    end

    selected = b.name
    log("Loaded " .. b.name)
    _G.__ChessLoaderStop() -- remove the UI and stop the loop
end

local function startLoad(b)
    if busy or selected then return end
    if b.disabled then return log(b.name .. " has no URL set") end
    busy = true
    log("Loading " .. b.name .. "...")
    pending = b -- runs next frame
end

-- Auto-detect by game id --------------------------------------------
local function matches(b)
    for _, id in ipairs(b.ids) do
        if id == game.PlaceId or id == game.GameId then return true end
    end
    return false
end

-- PlaceId can read 0 briefly right after injection, so give it a moment
for _ = 1, 20 do
    if game.PlaceId ~= 0 then break end
    task.wait(0.25)
end

local autoBtn
for _, b in ipairs(buttons) do
    if matches(b) then autoBtn = b break end
end

if autoBtn then
    autoMode = true
    setVisible(false)
    log("Detected " .. autoBtn.name .. " (PlaceId " .. tostring(game.PlaceId) .. ") - auto loading")
    startLoad(autoBtn)
else
    log("Unknown game (PlaceId " .. tostring(game.PlaceId) .. ") - pick manually")
end

-- Main loop ---------------------------------------------------------
local conn = RunService.Heartbeat:Connect(function()
    local k1, k2, kc = pressed(VK_1), pressed(VK_2), pressed(VK_CTRL)

    if pending then
        local b = pending; pending = nil
        runLoad(b)
        busy = false
        -- auto-load failed: fall back to the manual panel
        if autoMode and not selected then
            autoMode = false
            setVisible(true)
            log("Auto-load failed - pick a game manually")
        end
        return
    end

    if kc then setVisible(not visible) end
    if not visible then return end

    if k1 then startLoad(buttons[1]) end
    if k2 then startLoad(buttons[2]) end

    local mx, my = Mouse.X, Mouse.Y
    local down = ismouse1pressed() and isrbxactive()

    for _, b in ipairs(buttons) do
        local x, y = originX + b.ox, originY + b.oy
        b.over = mx >= x and mx <= x + b.w and my >= y and my <= y + b.h
        local col = b.base
        if b.disabled then col = C.off
        elseif b.over then col = b.hot end
        b.bg.Color = col
    end

    if down and not wasDown then
        for _, b in ipairs(buttons) do
            if b.over then startLoad(b) end
        end
        if mx >= originX and mx <= originX + PW and my >= originY and my <= originY + 62 then
            dragging, dragDX, dragDY = true, mx - originX, my - originY
        end
    end
    if dragging then
        if down then
            originX, originY = mx - dragDX, my - dragDY
            reposition()
        else
            dragging = false
        end
    end
    wasDown = down
end)

_G.__ChessLoaderStop = function()
    if conn then pcall(function() conn:Disconnect() end) end
    for _, e in ipairs(elements) do pcall(function() e.obj:Remove() end) end
    elements = {}
end

log("Ready.")
