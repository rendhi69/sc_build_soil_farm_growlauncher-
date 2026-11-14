---@diagnostic disable: undefined-global, lowercase-global
-- ============================================================================
-- AUTO SOIL & BLOCK BUILDER BY BOREN STORE - GROWLAUNCHER
-- Sesuai Layout Gambar 1 (Soil Rows & Water Elevator) & Gambar 2 (Lock Setup)
-- Fitur: Auto Blast World, Multi-Storage Restock, Multi-World Farm Management,
--        Water Column, Persistent File Backup di Folder Download HP / PC
-- ============================================================================

-- ============================================================================
-- 1. SAFE PREFERENCES & CONFIGURATION
-- ============================================================================
local ok_pref, PreferencesMod = pcall(require, "Preferences")
if not (ok_pref and PreferencesMod) then
    ok_pref, PreferencesMod = pcall(require, "preferences")
end
if not (ok_pref and PreferencesMod) and Preferences then
    ok_pref = true
    PreferencesMod = Preferences
end

local saved = nil
if ok_pref and PreferencesMod and PreferencesMod.new then
    pcall(function()
        local p = PreferencesMod:new("boren_soil_v1.json")
        if p and p.load then pcall(p.load, p) end
        saved = p
    end)
end

local function loadPref(key, default)
    if saved and saved.get then
        local ok, val = pcall(function() return saved:get(key, default) end)
        if ok and val ~= nil then
            return val
        end
    end
    return default
end

local function setPref(key, val)
    if not saved or not saved.set then return end
    pcall(function()
        saved:set(key, val)
        if saved.save then saved:save() end
    end)
end

local CFG = {
    -- Mode Operasi: "MANUAL" (antrean world) atau "RANDOM" (cari & blast otomatis)
    world_mode              = loadPref("world_mode", "MANUAL"),
    
    -- Random World Search Settings
    random_letter_count     = tonumber(loadPref("random_letter_count", 8)) or 8,
    random_with_number      = (loadPref("random_with_number", true) == true),
    random_prefix           = tostring(loadPref("random_prefix", "")),
    random_target_count     = tonumber(loadPref("random_target_count", 20)) or 20,
    
    -- Auto Blast Settings
    auto_use_blast          = (loadPref("auto_use_blast", false) == true),
    blast_item_id           = tonumber(loadPref("blast_item_id", 1336)) or 1336, -- 1336 = World Blast, 2810 = Cave Blast
    
    -- Lock Enclosure Settings (Sesuai Gambar 2)
    enable_lock_enclosure   = (loadPref("enable_lock_enclosure", true) == true),
    lock_id_wl              = tonumber(loadPref("lock_id_wl", 242)) or 242,       -- World Lock (Bawah Kiri)
    lock_id_sl              = tonumber(loadPref("lock_id_sl", 202)) or 202,       -- Small Lock (Atas Tengah)
    lock_id_jammer          = tonumber(loadPref("lock_id_jammer", 226)) or 226,   -- Signal Jammer (Bawah Tengah)
    lock_id_blocker         = tonumber(loadPref("lock_id_blocker", 828)) or 828,  -- Blocker Door (Atas White Door, misal Air Vent)
    lock_id_door            = tonumber(loadPref("lock_id_door", 12)) or 12,       -- Wooden Door (Atas Kiri)
    farm_door_id            = tostring(loadPref("farm_door_id", "BOREN")),        -- Label / ID Door
    wl_make_public          = (loadPref("wl_make_public", false) == true),
    
    -- Water Column Elevator (Sesuai Gambar 1)
    enable_water_column     = (loadPref("enable_water_column", true) == true),
    water_item_id           = tonumber(loadPref("water_item_id", 822)) or 822,    -- 822 = Water
    water_x                 = tonumber(loadPref("water_x", 0)) or 0,              -- Kolom elevator X = 0
    water_start_y           = tonumber(loadPref("water_start_y", 1)) or 1,
    water_end_y             = tonumber(loadPref("water_end_y", 54)) or 54,
    
    -- Block / Soil Placement Layout (Sesuai Gambar 1)
    block_id                = tonumber(loadPref("block_id", 2)) or 2,             -- 2 = Dirt, 100 = Soil, 102 = Platform
    row_step                = tonumber(loadPref("row_step", 2)) or 2,             -- Tiap 2 baris (Y genap: 2, 4, 6... 54)
    row_start_y             = tonumber(loadPref("row_start_y", 2)) or 2,
    row_end_y               = tonumber(loadPref("row_end_y", 54)) or 54,
    row_start_x             = tonumber(loadPref("row_start_x", 2)) or 2,          -- X mulai (setelah kolom water)
    row_end_x               = tonumber(loadPref("row_end_x", 99)) or 99,
    
    -- Multi-Storage Restock Settings
    restock_threshold       = tonumber(loadPref("restock_threshold", 30)) or 30,  -- Ambil ke gudang jika sisa di tas < 30
    storage_door_default    = tostring(loadPref("storage_door_default", "")),
    
    -- Pacing & Delays (ms)
    delay_place             = tonumber(loadPref("delay_place", 120)) or 120,
    delay_walk              = tonumber(loadPref("delay_walk", 150)) or 150,
    delay_punch             = tonumber(loadPref("delay_punch", 160)) or 160,
    
    -- Persistent File Names (Folder Download HP / PC)
    world_file_name         = loadPref("world_file_name", "boren_soil_worlds.txt"),
    storage_file_name       = loadPref("storage_file_name", "boren_soil_storages.txt"),
    
    -- Discord Webhook
    webhook_url             = tostring(loadPref("webhook_url", "")),
    
    -- World & Storage Lists
    farm_world_list         = {},
    storage_list            = {},
}

local STATE = {
    running                 = false,
    paused                  = false,
    current_world           = "",
    current_door            = "",
    current_world_index     = 1,
    total_placed_blocks     = 0,
    total_worlds_completed  = 0,
    status_text             = "IDLE",
    log_messages            = {},
    
    -- Dirty input tracking (UI Save Indicators)
    dirty_block_id          = false,
    dirty_blast_id          = false,
    dirty_door_id           = false,
    
    -- Active world progression
    active_row              = 2,
    active_col              = 2,
}

local function savePrefs(cfg)
    if not saved or not saved.set or not saved.save then return end
    pcall(function()
        for k, v in pairs(cfg) do
            local vt = type(v)
            if vt == "string" or vt == "number" or vt == "boolean" then
                saved:set(k, v)
            end
        end
        -- Simpan daftar world sebagai serialized string
        local wParts = {}
        if type(cfg.farm_world_list) == "table" then
            for _, entry in ipairs(cfg.farm_world_list) do
                if type(entry) == "table" and entry.name and entry.name ~= "" then
                    local flag = entry.done and "1" or "0"
                    table.insert(wParts, tostring(entry.name) .. "|" .. tostring(entry.door or "") .. "|" .. flag)
                end
            end
        end
        saved:set("farm_world_list_str", table.concat(wParts, ";"))

        -- Simpan daftar storage
        local sParts = {}
        if type(cfg.storage_list) == "table" then
            for _, entry in ipairs(cfg.storage_list) do
                if type(entry) == "table" and entry.name and entry.name ~= "" then
                    table.insert(sParts, tostring(entry.name) .. "|" .. tostring(entry.door or ""))
                end
            end
        end
        saved:set("storage_list_str", table.concat(sParts, ";"))
        saved:save()
    end)
end

-- Load initial lists from Preferences string if available
pcall(function()
    local wStr = loadPref("farm_world_list_str", "")
    if wStr and wStr ~= "" then
        CFG.farm_world_list = {}
        for token in string.gmatch(wStr, "[^;]+") do
            local pName, pDoor, pDone = string.match(token, "^([^|]*)|([^|]*)|?([^|]*)$")
            if pName and pName ~= "" then
                table.insert(CFG.farm_world_list, {
                    name = pName:upper(),
                    door = (pDoor or ""):upper(),
                    done = (pDone == "1")
                })
            end
        end
    end

    local sStr = loadPref("storage_list_str", "")
    if sStr and sStr ~= "" then
        CFG.storage_list = {}
        for token in string.gmatch(sStr, "[^;]+") do
            local sName, sDoor = string.match(token, "^([^|]*)|?([^|]*)$")
            if sName and sName ~= "" then
                table.insert(CFG.storage_list, {
                    name = sName:upper(),
                    door = (sDoor or ""):upper()
                })
            end
        end
    end
end)

-- ============================================================================
-- 2. ITEM CONSTANTS & SAFE NAME RESOLVER
-- ============================================================================
local KNOWN_ITEMS = {
    [0]    = "Blank / Udara",
    [2]    = "Dirt",
    [3]    = "Dirt Seed",
    [4]    = "Lava",
    [6]    = "Main White Door",
    [8]    = "Bedrock",
    [10]   = "Rock",
    [12]   = "Wooden Door",
    [14]   = "Cave Background",
    [18]   = "Fist / Punch",
    [32]   = "Wrench",
    [100]  = "Soil Block / Mars Rock",
    [102]  = "Wood Platform",
    [202]  = "Small Lock",
    [204]  = "Big Lock",
    [206]  = "Huge Lock",
    [226]  = "Signal Jammer",
    [242]  = "World Lock",
    [822]  = "Water",
    [828]  = "Air Vent",
    [1336] = "World Blast",
    [1796] = "Diamond Lock",
    [2810] = "Cave Blast",
    [9640] = "Blue Gem Lock",
}

local LOCK_IDS = {
    242, 9640, 202, 204, 206, 1796, 4994, 7188, 408, 2950,
    4428, 4802, 5814, 5260, 5980, 8470, 10410, 11550, 11586
}

local function getItemNameSafe(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then return "None" end
    if KNOWN_ITEMS[itemID] then return KNOWN_ITEMS[itemID] end

    if getItemInfoByID then
        local ok, info = pcall(getItemInfoByID, itemID)
        if ok and info and info.name and info.name ~= "" then
            return tostring(info.name)
        end
    end

    if growtopia and growtopia.getItemName then
        local ok, n = pcall(growtopia.getItemName, itemID)
        if ok and n and n ~= "" then
            return tostring(n)
        end
    end

    if item_info_manager and item_info_manager.getItemName then
        local ok, n = pcall(item_info_manager.getItemName, itemID)
        if ok and n and n ~= "" then
            return tostring(n)
        end
    end

    return "Item #" .. tostring(itemID)
end

-- ============================================================================
-- 3. LOGGING, WEBHOOK & STATUS ENGINE
-- ============================================================================
local function addLog(msg)
    local tStr = os.date("%H:%M:%S")
    local line = string.format("[%s] %s", tStr, msg)
    table.insert(STATE.log_messages, 1, line)
    while #STATE.log_messages > 60 do
        table.remove(STATE.log_messages)
    end
    if LogToConsole then
        pcall(LogToConsole, "`9[Boren Soil] `0" .. tostring(msg))
    else
        print("[Boren Soil] " .. tostring(msg))
    end
    if updateLogDisplayList then pcall(updateLogDisplayList) end
end

local function notifyUser(msg)
    if sendNotification then
        pcall(sendNotification, msg)
    elseif growtopia and growtopia.notify then
        pcall(growtopia.notify, msg)
    end
end

local function safeSleep(ms)
    ms = tonumber(ms) or 100
    if ms <= 0 then return end
    if sleep then
        sleep(ms)
    else
        local st = os.clock()
        while (os.clock() - st) * 1000 < ms do end
    end
end

local function sendWebhookNotification(eventTitle, eventDesc)
    if not CFG.webhook_url or CFG.webhook_url == "" then return end
    local payload = string.format([[
        $url = "%s"
        $embed = @{
            title = "%s"
            description = "%s"
            color = 3447003
            footer = @{ text = "Boren Soil Builder - %s" }
        }
        $body = @{ embeds = @($embed) } | ConvertTo-Json -Depth 4
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-RestMethod -Uri $url -Method Post -Body $body -ContentType 'application/json'
    ]], CFG.webhook_url, eventTitle, eventDesc, os.date("%Y-%m-%d %H:%M:%S"))

    pcall(function()
        local pipe = io.popen("powershell -command -", "w")
        if pipe then
            pipe:write(payload)
            pipe:close()
        end
    end)
end

-- ============================================================================
-- 4. SAFE FILE PERSISTENCE ENGINE (FOLDER DOWNLOAD HP / PC)
-- ============================================================================
local function resolveFilePath(fileName, fallbackName)
    fileName = (fileName and fileName ~= "") and fileName or fallbackName
    local dirs = {
        "/sdcard/Download/",
        "/storage/emulated/0/Download/",
        "Download/",
        ""
    }
    local userProfile = os.getenv("USERPROFILE")
    if userProfile and userProfile ~= "" then
        table.insert(dirs, 1, userProfile:gsub("\\", "/") .. "/Downloads/")
    end

    for _, d in ipairs(dirs) do
        local testP = d .. fileName
        local ok, fh = pcall(io.open, testP, "a")
        if ok and fh then
            fh:close()
            return testP, d, fileName
        end
    end
    return fileName, "", fileName
end

local function saveWorldsToFile()
    local path, dir, fn = resolveFilePath(CFG.world_file_name, "boren_soil_worlds.txt")
    local fh = io.open(path, "w")
    if not fh then
        fh = io.open("/sdcard/Download/" .. fn, "w")
    end
    if not fh then
        addLog("`4[Gagal Simpan] `oTidak dapat membuka file download.")
        return false
    end

    for _, w in ipairs(CFG.farm_world_list) do
        local d = (w.door and w.door ~= "") and ("|" .. w.door) or ""
        local s = w.done and "|DONE" or ""
        fh:write(w.name .. d .. s .. "\n")
    end
    fh:close()
    addLog(string.format("`2[Berhasil Simpan] `w%d world ke %s", #CFG.farm_world_list, path))
    notifyUser(string.format("Berhasil simpan %d world", #CFG.farm_world_list))
    return true
end

local function loadWorldsFromFile()
    local path, dir, fn = resolveFilePath(CFG.world_file_name, "boren_soil_worlds.txt")
    local fh = io.open(path, "r")
    if not fh then
        fh = io.open("/sdcard/Download/" .. fn, "r")
    end
    if not fh then
        addLog("`4[Gagal Muat] `oFile " .. fn .. " tidak ditemukan di Download.")
        return false
    end

    local count = 0
    CFG.farm_world_list = {}
    for line in fh:lines() do
        local cleanLine = line:gsub("[\r\n]", ""):match("^%s*(.-)%s*$")
        if cleanLine ~= "" and not cleanLine:match("^#") then
            local pName, pDoor, pDone = cleanLine:match("^([^|]+)|?([^|]*)|?([^|]*)$")
            if pName and pName ~= "" then
                table.insert(CFG.farm_world_list, {
                    name = pName:upper(),
                    door = (pDoor or ""):upper(),
                    done = (pDone:upper() == "DONE" or pDone == "1")
                })
                count = count + 1
            end
        end
    end
    fh:close()
    savePrefs(CFG)
    addLog(string.format("`2[Berhasil Muat] `w%d world dari %s", count, path))
    notifyUser(string.format("Berhasil muat %d world", count))
    if updateWorldDisplayList then pcall(updateWorldDisplayList) end
    return true
end

local function saveStoragesToFile()
    local path, dir, fn = resolveFilePath(CFG.storage_file_name, "boren_soil_storages.txt")
    local fh = io.open(path, "w")
    if not fh then
        fh = io.open("/sdcard/Download/" .. fn, "w")
    end
    if not fh then
        addLog("`4[Gagal Simpan] `oTidak dapat membuka file storage.")
        return false
    end

    for _, s in ipairs(CFG.storage_list) do
        local d = (s.door and s.door ~= "") and ("|" .. s.door) or ""
        fh:write(s.name .. d .. "\n")
    end
    fh:close()
    addLog(string.format("`2[Berhasil Simpan] `w%d gudang ke %s", #CFG.storage_list, path))
    notifyUser(string.format("Berhasil simpan %d gudang", #CFG.storage_list))
    return true
end

local function loadStoragesFromFile()
    local path, dir, fn = resolveFilePath(CFG.storage_file_name, "boren_soil_storages.txt")
    local fh = io.open(path, "r")
    if not fh then
        fh = io.open("/sdcard/Download/" .. fn, "r")
    end
    if not fh then
        addLog("`4[Gagal Muat] `oFile " .. fn .. " tidak ditemukan di Download.")
        return false
    end

    local count = 0
    CFG.storage_list = {}
    for line in fh:lines() do
        local cleanLine = line:gsub("[\r\n]", ""):match("^%s*(.-)%s*$")
        if cleanLine ~= "" and not cleanLine:match("^#") then
            local sName, sDoor = cleanLine:match("^([^|]+)|?([^|]*)$")
            if sName and sName ~= "" then
                table.insert(CFG.storage_list, {
                    name = sName:upper(),
                    door = (sDoor or ""):upper()
                })
                count = count + 1
            end
        end
    end
    fh:close()
    savePrefs(CFG)
    addLog(string.format("`2[Berhasil Muat] `w%d gudang dari %s", count, path))
    notifyUser(string.format("Berhasil muat %d gudang", count))
    if updateStorageDisplayList then pcall(updateStorageDisplayList) end
    return true
end

-- ============================================================================
-- 5. INVENTORY & BOT HELPERS
-- ============================================================================
local function getInvCount(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then return 0 end
    local inv = (getInventory and getInventory()) or (getBot and getBot().getInventory and getBot():getInventory())
    if not inv then return 0 end

    if inv.findItem then
        local ok, cnt = pcall(inv.findItem, inv, itemID)
        if ok and cnt then return cnt end
    end
    if inv.getItemCount then
        local ok, cnt = pcall(inv.getItemCount, inv, itemID)
        if ok and cnt then return cnt end
    end
    if inv.items then
        for _, it in pairs(inv.items) do
            if it.id == itemID then return it.count or 0 end
        end
    end
    return 0
end

local function getPlayerPos()
    local p = (getLocal and getLocal()) or (getBot and getBot())
    if not p then return 0, 0 end
    local px = p.posX or (p.pos and p.pos.x) or (p.x and p.x * 32) or 0
    local py = p.posY or (p.pos and p.pos.y) or (p.y and p.y * 32) or 0
    return math.floor(px / 32), math.floor(py / 32)
end

local function sendRawAction(tx, ty, value)
    local p = (getLocal and getLocal()) or (getBot and getBot())
    local px = p and (p.posX or (p.pos and p.pos.x) or (tx * 32)) or (tx * 32)
    local py = p and (p.posY or (p.pos and p.pos.y) or (ty * 32)) or (ty * 32)
    local state = (px > (tx * 32)) and 48 or 32

    if sendPacketRaw then
        pcall(sendPacketRaw, false, {
            type   = 3,
            value  = value,
            px     = tx,
            py     = ty,
            x      = px,
            y      = py,
            state  = state,
        })
    elseif getBot and getBot().place then
        pcall(getBot().place, getBot(), tx, ty, value)
    end
    return true
end

local function sendHitAction(tx, ty)
    local p = (getLocal and getLocal()) or (getBot and getBot())
    local px = p and (p.posX or (p.pos and p.pos.x) or (tx * 32)) or (tx * 32)
    local py = p and (p.posY or (p.pos and p.pos.y) or (ty * 32)) or (ty * 32)
    local state = (px > (tx * 32)) and 48 or 32

    if sendPacketRaw then
        pcall(sendPacketRaw, false, {
            type   = 3,
            value  = 18, -- Fist / Hit
            px     = tx,
            py     = ty,
            x      = px,
            y      = py,
            state  = state,
        })
    elseif getBot and getBot().hit then
        pcall(getBot().hit, getBot(), tx, ty)
    end
    return true
end

local function wrenchTile(tx, ty)
    local p = (getLocal and getLocal()) or (getBot and getBot())
    local px = p and (p.posX or (p.pos and p.pos.x) or (tx * 32)) or (tx * 32)
    local py = p and (p.posY or (p.pos and p.pos.y) or (ty * 32)) or (ty * 32)

    if sendPacketRaw then
        pcall(sendPacketRaw, false, {
            type   = 3,
            value  = 32, -- Wrench
            px     = tx,
            py     = ty,
            x      = px,
            y      = py,
            state  = 32,
        })
    elseif getBot and getBot().wrench then
        pcall(getBot().wrench, getBot(), tx, ty)
    end
    return true
end

-- ============================================================================
-- 6. MOVEMENT & PATHFINDING
-- ============================================================================
local function isTileSafe(tx, ty)
    if tx < 0 or tx > 99 or ty < 0 or ty > 59 then return false end
    local ok, t = pcall(getTile, tx, ty)
    if not ok or not t then return false end
    if t.fg == 4 or t.fg == 8 then return false end -- Lava / Bedrock
    return true
end

local function moveSafeTo(tx, ty)
    tx = math.max(0, math.min(99, tx))
    ty = math.max(0, math.min(59, ty))
    local curX, curY = getPlayerPos()
    if curX == tx and curY == ty then return true end

    local pFn = FindPath or findPath or (getBot and getBot().findPath)
    if not pFn then return false end

    local CHUNK_LIMIT = 5
    local stuck = 0
    while STATE.running and not STATE.paused do
        curX, curY = getPlayerPos()
        if curX == tx and curY == ty then return true end

        local dx = tx - curX
        local dy = ty - curY
        local dist = math.max(math.abs(dx), math.abs(dy))
        if dist == 0 then return true end

        local stepX, stepY = tx, ty
        if dist > CHUNK_LIMIT and stuck < 2 then
            local ratio = CHUNK_LIMIT / dist
            stepX = math.max(0, math.min(99, math.floor(curX + (dx * ratio) + 0.5)))
            stepY = math.max(0, math.min(59, math.floor(curY + (dy * ratio) + 0.5)))
        end

        local walkDelay = math.max(60, CFG.delay_walk)
        safeSleep(math.floor(walkDelay * (0.85 + math.random() * 0.3)))
        if not STATE.running then break end

        if getBot and getBot().findPath then
            pcall(getBot().findPath, getBot(), stepX, stepY)
        else
            pcall(pFn, stepX, stepY)
        end

        local waited = 0
        local maxWait = math.max(120, math.min(1500, math.max(math.abs(curX - stepX), math.abs(curY - stepY)) * 60))
        while waited < maxWait and STATE.running do
            local nx, ny = getPlayerPos()
            if math.abs(nx - stepX) <= 1 and math.abs(ny - stepY) <= 1 then break end
            safeSleep(25)
            waited = waited + 25
        end

        local npx, npy = getPlayerPos()
        if npx == tx and npy == ty then return true end
        if npx == curX and npy == curY then
            stuck = stuck + 1
            if stuck >= 3 then break end
        else
            stuck = 0
        end
        safeSleep(math.floor(walkDelay * (0.85 + math.random() * 0.3)))
    end
    local fx, fy = getPlayerPos()
    return (fx == tx and fy == ty)
end

-- ============================================================================
-- 7. TILE ACTIONS & VALIDATION
-- ============================================================================
local function breakTileAt(tx, ty)
    if tx < 0 or tx > 99 or ty < 0 or ty > 59 then return false end
    local ok, t = pcall(getTile, tx, ty)
    if not ok or not t then return true end
    if t.fg == 0 and t.bg == 0 then return true end
    if t.fg == 8 or t.fg == 6 then return true end -- Bedrock / Main Door jangan dihancurkan

    local attempts = 0
    while STATE.running and attempts < 15 do
        ok, t = pcall(getTile, tx, ty)
        if not ok or not t or (t.fg == 0 and t.bg == 0) then return true end

        local px, py = getPlayerPos()
        if math.abs(px - tx) > 2 or math.abs(py - ty) > 2 then
            moveSafeTo(tx - 1, ty)
        end

        sendHitAction(tx, ty)
        safeSleep(CFG.delay_punch)
        attempts = attempts + 1
    end
    ok, t = pcall(getTile, tx, ty)
    return ok and t and (t.fg == 0 and t.bg == 0)
end

local function placeTileAt(tx, ty, itemID)
    if tx < 0 or tx > 99 or ty < 0 or ty > 59 then return false end
    local ok, t = pcall(getTile, tx, ty)
    if not ok or not t then return false end
    if t.fg == itemID then return true end

    if getInvCount(itemID) <= 0 then
        return false
    end

    local attempts = 0
    while STATE.running and attempts < 8 do
        ok, t = pcall(getTile, tx, ty)
        if not ok or not t or t.fg == itemID then return true end

        local px, py = getPlayerPos()
        local dist = math.max(math.abs(px - tx), math.abs(py - ty))
        if dist > 2 or (px == tx and py == ty) then
            -- Cari petak samping yang aman untuk berdiri
            if isTileSafe(tx - 1, ty) then
                moveSafeTo(tx - 1, ty)
            elseif isTileSafe(tx + 1, ty) then
                moveSafeTo(tx + 1, ty)
            elseif isTileSafe(tx, ty - 1) then
                moveSafeTo(tx, ty - 1)
            else
                moveSafeTo(tx, ty + 1)
            end
        end

        sendRawAction(tx, ty, itemID)
        local d = math.floor(CFG.delay_place * (0.85 + math.random() * 0.3))
        safeSleep(d)
        attempts = attempts + 1
    end

    ok, t = pcall(getTile, tx, ty)
    return ok and t and (t.fg == itemID)
end

-- ============================================================================
-- 8. LOCK ENCLOSURE ENGINE (SESUAI GAMBAR 2)
-- ============================================================================
-- Layout Relatif terhadap Main White Door di (doorX, doorY):
--   (doorX - 2, doorY - 1) : Wooden Door (ID 12)  | (doorX - 1, doorY - 1) : Small Lock (ID 202)    | (doorX, doorY - 1) : Blocker / Air Vent (ID 828)
--   (doorX - 2, doorY)     : World Lock (ID 242)   | (doorX - 1, doorY)     : Signal Jammer (ID 226) | (doorX, doorY)     : White Door (ID 6)
local function buildLockEnclosure()
    if not CFG.enable_lock_enclosure then
        addLog("`e[Enclosure] `0Pengaman lock dilewati (dinonaktifkan oleh user).")
        return true
    end

    addLog("`9[Enclosure] `0Mendeteksi White Door dan membangun pengaman (Gambar 2)...")
    local doorX, doorY = nil, nil
    for y = 0, 59 do
        for x = 0, 99 do
            local ok, t = pcall(getTile, x, y)
            if ok and t and t.fg == 6 then
                doorX, doorY = x, y
                break
            end
        end
        if doorX then break end
    end

    if not doorX or not doorY then
        addLog("`4[Enclosure Gagal] `oWhite Door tidak ditemukan di world ini!")
        return false
    end
    addLog(string.format("`2[Enclosure] `wWhite Door terdeteksi di (%d, %d)", doorX, doorY))

    -- 1. Bersihkan petak di sekitar White Door sebelum memasang
    local spotsToClear = {
        { doorX, doorY - 1 },
        { doorX - 1, doorY },
        { doorX - 1, doorY - 1 },
        { doorX - 2, doorY },
        { doorX - 2, doorY - 1 }
    }
    for _, sp in ipairs(spotsToClear) do
        local sx, sy = sp[1], sp[2]
        local ok, t = pcall(getTile, sx, sy)
        if ok and t and (t.fg ~= 0 and t.fg ~= 8 and t.fg ~= 6) then
            breakTileAt(sx, sy)
        end
    end

    -- 2. Pasang Signal Jammer di (doorX - 1, doorY)
    addLog("`9[Enclosure] `0Memasang Signal Jammer...")
    if not placeTileAt(doorX - 1, doorY, CFG.lock_id_jammer) then
        addLog("`e[Enclosure] `0Peringatan: Gagal menaruh Signal Jammer.")
    end

    -- 3. Pasang Blocker / Air Vent di (doorX, doorY - 1)
    addLog("`9[Enclosure] `0Memasang Blocker Door / Air Vent...")
    if not placeTileAt(doorX, doorY - 1, CFG.lock_id_blocker) then
        addLog("`e[Enclosure] `0Peringatan: Gagal menaruh Blocker Door.")
    end

    -- 4. Pasang Small Lock di (doorX - 1, doorY - 1)
    addLog("`9[Enclosure] `0Memasang Small Lock...")
    if placeTileAt(doorX - 1, doorY - 1, CFG.lock_id_sl) then
        -- Recalc / Reapply lock agar mengunci area pintu
        safeSleep(300)
        wrenchTile(doorX - 1, doorY - 1)
        safeSleep(300)
        if sendPacket then
            pcall(sendPacket, 2, string.format("action|dialog_return\ndialog_name|lock_edit\ntilex|%d|\ntiley|%d|\nbuttonClicked|recalcLock\n\ncheckbox_public|0\ncheckbox_ignore|1", doorX - 1, doorY - 1))
        end
        safeSleep(300)
    end

    -- 5. Pasang Wooden Door di (doorX - 2, doorY - 1) & setting Door ID
    addLog("`9[Enclosure] `0Memasang Wooden Door...")
    if placeTileAt(doorX - 2, doorY - 1, CFG.lock_id_door) then
        safeSleep(300)
        wrenchTile(doorX - 2, doorY - 1)
        safeSleep(300)
        local dID = (CFG.farm_door_id and CFG.farm_door_id ~= "") and CFG.farm_door_id or "BOREN"
        if sendPacket then
            pcall(sendPacket, 2, string.format("action|dialog_return\ndialog_name|door_edit\ntilex|%d|\ntiley|%d|\ndoor_name|\ndoor_target|\ndoor_id|%s\ncheckbox_locked|1", doorX - 2, doorY - 1, dID))
        end
        safeSleep(300)
    end

    -- 6. Pasang World Lock di (doorX - 2, doorY)
    addLog("`9[Enclosure] `0Memasang World Lock...")
    if placeTileAt(doorX - 2, doorY, CFG.lock_id_wl) then
        safeSleep(300)
        if CFG.wl_make_public then
            wrenchTile(doorX - 2, doorY)
            safeSleep(300)
            if sendPacket then
                pcall(sendPacket, 2, string.format("action|dialog_return\ndialog_name|lock_edit\ntilex|%d|\ntiley|%d|\ncheckbox_public|1\ncheckbox_disable_music|0\ntempo|100\ncheckbox_disable_music_render|0\ncheckbox_set_as_home_world|0\nminimum_entry_level|1", doorX - 2, doorY))
            end
            safeSleep(300)
        end
    end

    addLog("`2[Enclosure Selesai] `wStruktur pengaman Gambar 2 berhasil dipasang!")
    return true
end

-- ============================================================================
-- 9. WATER COLUMN ELEVATOR ENGINE (SESUAI GAMBAR 1)
-- ============================================================================
local function buildWaterColumn()
    if not CFG.enable_water_column then
        addLog("`e[Water Elevator] `0Kolom water dilewati (dinonaktifkan oleh user).")
        return true
    end

    addLog(string.format("`9[Water Elevator] `0Memasang kolom air di X=%d (Y=%d s/d %d)...", CFG.water_x, CFG.water_start_y, CFG.water_end_y))
    local wx = CFG.water_x
    for wy = CFG.water_start_y, CFG.water_end_y do
        if not STATE.running or STATE.paused then break end
        local ok, t = pcall(getTile, wx, wy)
        if ok and t and t.fg ~= CFG.water_item_id and t.fg ~= 8 and t.fg ~= 6 then
            -- Cek sisa water di tas
            if getInvCount(CFG.water_item_id) <= 0 then
                addLog("`e[Water Habis] `0Sisa item water habis di tas. Melanjutkan layout...")
                break
            end
            placeTileAt(wx, wy, CFG.water_item_id)
        end
    end
    addLog("`2[Water Elevator] `wPemasangan kolom water selesai.")
    return true
end

-- ============================================================================
-- 10. SOIL ROW PLACEMENT ENGINE (SESUAI GAMBAR 1)
-- ============================================================================
local function placeSoilRows(onNeedRestockCallback)
    addLog(string.format("`9[Place Rows] `0Memulai penempatan baris block (ID: %d - %s)...", CFG.block_id, getItemNameSafe(CFG.block_id)))
    local rowIdx = 0

    for y = CFG.row_start_y, CFG.row_end_y, CFG.row_step do
        if not STATE.running or STATE.paused then break end
        rowIdx = rowIdx + 1
        STATE.active_row = y

        -- Pola Sinuous (kiri-ke-kanan lalu kanan-ke-kiri)
        local startX, endX, stepX
        if rowIdx % 2 == 1 then
            startX, endX, stepX = CFG.row_start_x, CFG.row_end_x, 1
        else
            startX, endX, stepX = CFG.row_end_x, CFG.row_start_x, -1
        end

        local x = startX
        while (stepX > 0 and x <= endX) or (stepX < 0 and x >= endX) do
            if not STATE.running or STATE.paused then break end
            STATE.active_col = x

            local ok, t = pcall(getTile, x, y)
            if ok and t and t.fg ~= CFG.block_id and t.fg ~= 8 and t.fg ~= 6 then
                -- Cek apakah sisa block di tas sudah di bawah batas restock
                local curCount = getInvCount(CFG.block_id)
                if curCount < CFG.restock_threshold then
                    addLog(string.format("`e[Restock Diperlukan] `0Sisa block di tas (%d) < batas (%d). Menuju gudang...", curCount, CFG.restock_threshold))
                    if onNeedRestockCallback then
                        local okRestock = onNeedRestockCallback(x, y)
                        if not okRestock then
                            addLog("`4[Restock Gagal] `oGagal mengambil block dari gudang. Berhenti.")
                            return false
                        end
                    end
                end

                -- Pasang block di (x, y)
                if placeTileAt(x, y, CFG.block_id) then
                    STATE.total_placed_blocks = STATE.total_placed_blocks + 1
                end
            end

            x = x + stepX
        end
    end

    addLog(string.format("`2[Place Rows Selesai] `wTotal block terpasang: %d", STATE.total_placed_blocks))
    return true
end

-- ============================================================================
-- 11. BLAST & RANDOM WORLD SEARCH ENGINE
-- ============================================================================
local function generateRandomWorldName(letterCount, withNum, prefix)
    prefix = prefix or ""
    letterCount = math.max(4, tonumber(letterCount) or 8)
    local chars = withNum and "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" or "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    local res = prefix
    local remain = math.max(1, letterCount - #prefix)
    for i = 1, remain do
        local idx = math.random(1, #chars)
        res = res .. chars:sub(idx, idx)
    end
    return res:upper()
end

local function warpToWorld(worldName, doorID)
    worldName = (worldName or ""):upper()
    doorID = (doorID or ""):upper()
    if worldName == "" then return false end

    addLog(string.format("`9[Warp] `0Menuju world: %s %s...", worldName, (doorID ~= "" and ("|" .. doorID) or "")))
    local warpStr = (doorID ~= "") and (worldName .. "|" .. doorID) or worldName

    local attempts = 0
    while STATE.running and attempts < 10 do
        if sendPacket then
            pcall(sendPacket, 3, string.format("action|join_request\nname|%s\ninvitedWorld|0", warpStr))
        elseif getBot and getBot().warp then
            pcall(getBot().warp, getBot(), warpStr)
        end

        local waited = 0
        while waited < 4500 and STATE.running do
            safeSleep(200)
            waited = waited + 200
            local curW = ""
            if getWorld then
                local w = getWorld()
                curW = (w and w.name) or ""
            elseif getBot and getBot().getWorld then
                local w = getBot():getWorld()
                curW = (w and w.name) or ""
            end
            if curW:upper() == worldName then
                safeSleep(1000)
                return true
            end
        end
        attempts = attempts + 1
    end
    return false
end

local function isWorldCleanAndUnowned()
    local tiles = nil
    if getWorld then
        local w = getWorld()
        tiles = w and w.tiles
    elseif getBot and getBot().getWorld then
        local w = getBot():getWorld()
        tiles = w and w.getTiles and w:getTiles()
    end

    if not tiles then return false end
    for _, t in pairs(tiles) do
        for _, lk in ipairs(LOCK_IDS) do
            if t.fg == lk then
                return false -- Ada lock milik orang lain
            end
        end
    end
    return true
end

local function executeWorldBlast()
    if not CFG.auto_use_blast then return true end
    addLog(string.format("`9[Auto Blast] `0Mempersiapkan blast world dengan item ID: %d (%s)...", CFG.blast_item_id, getItemNameSafe(CFG.blast_item_id)))

    if getInvCount(CFG.blast_item_id) <= 0 then
        addLog("`4[Blast Habis] `oTidak ada blast di tas!")
        return false
    end

    local px, py = getPlayerPos()
    -- Pasang / gunakan blast di petak dekat player
    local targetX, targetY = px + 1, py
    placeTileAt(targetX, targetY, CFG.blast_item_id)
    safeSleep(500)

    -- Handle dialog konfirmasi blast jika muncul
    if sendPacket then
        pcall(sendPacket, 2, "action|dialog_return\ndialog_name|use_blast\nbuttonClicked|blast")
        pcall(sendPacket, 2, "action|dialog_return\ndialog_name|blast_confirm\nbuttonClicked|yes")
    end

    addLog("`9[Auto Blast] `0Menunggu proses blast selesai (10 detik)...")
    safeSleep(10000)
    return true
end

-- ============================================================================
-- 12. MULTI-STORAGE RESTOCK ENGINE
-- ============================================================================
local function restockFromStorage(resumeX, resumeY)
    if #CFG.storage_list == 0 then
        addLog("`4[Restock Gagal] `oDaftar gudang storage kosong! Tambahkan gudang di Tab 3.")
        return false
    end

    local currentFarm = STATE.current_world
    local currentFarmDoor = STATE.current_door

    for sIdx, stor in ipairs(CFG.storage_list) do
        if not STATE.running then break end
        addLog(string.format("`9[Gudang] `0Menuju gudang %d/%d: %s...", sIdx, #CFG.storage_list, stor.name))
        if warpToWorld(stor.name, stor.door) then
            safeSleep(1500)

            -- Scan floating objects di gudang
            local objs = (getObjects and getObjects()) or (getBot and getBot().getWorld and getBot():getWorld().getObjects and getBot():getWorld():getObjects())
            local foundItem = false
            if objs then
                for _, obj in pairs(objs) do
                    if obj.id == CFG.block_id then
                        foundItem = true
                        local ox = math.floor((obj.posX or obj.x or 0) / 32)
                        local oy = math.floor((obj.posY or obj.y or 0) / 32)
                        addLog(string.format("`2[Gudang] `wDitemukan floating block di (%d, %d). Mengambil...", ox, oy))
                        moveSafeTo(ox, oy)
                        safeSleep(500)
                        if collect then pcall(collect, 2, 200) end
                        safeSleep(800)
                        if getInvCount(CFG.block_id) >= 150 then
                            break
                        end
                    end
                end
            end

            -- Cek juga apakah butuh mengambil item pengaman / blast jika habis
            if CFG.enable_lock_enclosure then
                local secItems = { CFG.lock_id_wl, CFG.lock_id_sl, CFG.lock_id_jammer, CFG.lock_id_blocker, CFG.lock_id_door }
                for _, sId in ipairs(secItems) do
                    if getInvCount(sId) == 0 and objs then
                        for _, obj in pairs(objs) do
                            if obj.id == sId then
                                local ox = math.floor((obj.posX or obj.x or 0) / 32)
                                local oy = math.floor((obj.posY or obj.y or 0) / 32)
                                moveSafeTo(ox, oy)
                                safeSleep(500)
                                if collect then pcall(collect, 2, 10) end
                                safeSleep(500)
                                break
                            end
                        end
                    end
                end
            end

            -- Jika tas sudah terisi block > threshold, kembali ke world farm!
            if getInvCount(CFG.block_id) >= CFG.restock_threshold then
                addLog(string.format("`2[Gudang Sukses] `wBerhasil restock %d block. Kembali ke %s...", getInvCount(CFG.block_id), currentFarm))
                warpToWorld(currentFarm, currentFarmDoor)
                safeSleep(1200)
                if resumeX and resumeY then
                    moveSafeTo(resumeX, resumeY)
                end
                return true
            end
        end
    end

    addLog("`4[Gudang Gagal] `oSemua gudang sudah dicek namun block tidak cukup.")
    return false
end

-- ============================================================================
-- 13. MAIN PROCESS DISPATCHER
-- ============================================================================
local function runSingleFarmWorld(worldName, doorID)
    STATE.current_world = worldName
    STATE.current_door = doorID or ""
    STATE.status_text = "Mempersiapkan World: " .. worldName
    addLog(string.format("`2========================================`0"))
    addLog(string.format("`2[Mulai World] `wMemproses Farm World: %s", worldName))

    -- 1. Warp ke World
    if not warpToWorld(worldName, doorID) then
        addLog(string.format("`4[Gagal Warp] `oTidak dapat memasuki world %s", worldName))
        return false
    end

    -- 2. Cek apakah world unowned (jika mode blast aktif)
    if CFG.auto_use_blast then
        if not isWorldCleanAndUnowned() then
            addLog("`e[World Terkunci] `0World ini sudah ada pemiliknya. Melewati...")
            return false
        end
        executeWorldBlast()
    end

    -- 3. Bangun Pengaman Lock (Sesuai Gambar 2)
    buildLockEnclosure()

    -- 4. Bangun Kolom Water Elevator (Sesuai Gambar 1)
    buildWaterColumn()

    -- 5. Taruh Baris-Baris Block Soil (Sesuai Gambar 1)
    local okRows = placeSoilRows(function(resX, resY)
        return restockFromStorage(resX, resY)
    end)

    if okRows then
        STATE.total_worlds_completed = STATE.total_worlds_completed + 1
        addLog(string.format("`2[World Selesai] `w%s sukses dibangun 100%%!", worldName))
        sendWebhookNotification("🌱 Farm World Selesai", string.format("World: **%s**\nTotal Block: **%d**\nTotal World Selesai: **%d**", worldName, STATE.total_placed_blocks, STATE.total_worlds_completed))
        return true
    end
    return false
end

local function autoSoilMainLoop()
    STATE.running = true
    STATE.paused = false
    addLog("`2[Bot Dimulai] `wAuto Soil Builder resmi berjalan.")

    if CFG.world_mode == "RANDOM" then
        -- Mode Cari & Blast Otomatis
        addLog(string.format("`9[Mode Random] `0Mencari %d world acak...", CFG.random_target_count))
        local found = 0
        while STATE.running and found < CFG.random_target_count do
            local rndWorld = generateRandomWorldName(CFG.random_letter_count, CFG.random_with_number, CFG.random_prefix)
            addLog(string.format("`9[Scan World] `0Memeriksa world acak: %s", rndWorld))
            if runSingleFarmWorld(rndWorld, CFG.farm_door_id) then
                found = found + 1
                table.insert(CFG.farm_world_list, { name = rndWorld, door = CFG.farm_door_id, done = true })
                savePrefs(CFG)
                saveWorldsToFile()
            end
            safeSleep(1500)
        end
    else
        -- Mode Manual List
        if #CFG.farm_world_list == 0 then
            addLog("`4[Daftar Kosong] `oDaftar Farm World kosong! Tambahkan world di Tab 1 atau klik Muat dari Download.")
            STATE.running = false
            return
        end

        for idx = STATE.current_world_index, #CFG.farm_world_list do
            if not STATE.running then break end
            local wEntry = CFG.farm_world_list[idx]
            if not wEntry.done then
                STATE.current_world_index = idx
                local ok = runSingleFarmWorld(wEntry.name, wEntry.door)
                if ok then
                    wEntry.done = true
                    savePrefs(CFG)
                    saveWorldsToFile()
                    if updateWorldDisplayList then pcall(updateWorldDisplayList) end
                end
            end
            safeSleep(2000)
        end
    end

    STATE.running = false
    STATE.status_text = "SELESAI"
    addLog("`2[Semua Selesai] `wSeluruh world telah berhasil diselesaikan!")
    notifyUser("Auto Soil Builder Selesai!")
end

-- ============================================================================
-- 14. UNIFIED DIALOG MANAGERS (WORLD FARM & GUDANG)
-- ============================================================================
local function safeSendRawDialog(dText)
    if growtopia and growtopia.sendDialog then
        local ok = pcall(growtopia.sendDialog, dText)
        if ok then return true end
    end
    if sendVariant then
        local ok = pcall(sendVariant, { v1 = "OnDialogRequest", v2 = dText })
        if ok then return true end
    end
    return false
end

local function openUnifiedWorldManager()
    local dLines = {}
    table.insert(dLines, "set_default_color|`o")
    table.insert(dLines, "add_label_with_icon|big|`2Kelola Daftar Farm World``|left|1336|")
    table.insert(dLines, "add_spacer|small|")
    table.insert(dLines, string.format("add_textbox|Total World Terdaftar: `2%d World``|left|", #CFG.farm_world_list))
    table.insert(dLines, "add_spacer|small|")
    table.insert(dLines, "add_text_input|as_dlg_add_world|Nama World Baru:||24|")
    table.insert(dLines, "add_text_input|as_dlg_add_door|Door ID (Opsional):||24|")
    table.insert(dLines, "add_button|as_dlg_btn_add|➕ Tambah World ke Antrean|noflags|0|0|")
    table.insert(dLines, "add_spacer|small|")
    table.insert(dLines, "add_button|as_dlg_btn_paste|📋 Tempel Banyak World (Format Bebas)|noflags|0|0|")
    table.insert(dLines, "add_button|as_dlg_btn_copy|📄 Salin Semua ke Clipboard|noflags|0|0|")
    table.insert(dLines, "add_button|as_dlg_btn_clear|🗑️ Bersihkan Semua World|noflags|0|0|")
    table.insert(dLines, "add_spacer|small|")
    table.insert(dLines, "end_dialog|boren_soil_world_mgr|Tutup||")

    safeSendRawDialog(table.concat(dLines, "\n"))
end

local function openUnifiedStorageManager()
    local dLines = {}
    table.insert(dLines, "set_default_color|`o")
    table.insert(dLines, "add_label_with_icon|big|`2Kelola Daftar Gudang Storage``|left|242|")
    table.insert(dLines, "add_spacer|small|")
    table.insert(dLines, string.format("add_textbox|Total Gudang Terdaftar: `2%d Gudang``|left|", #CFG.storage_list))
    table.insert(dLines, "add_spacer|small|")
    table.insert(dLines, "add_text_input|as_dlg_add_stor|Nama Gudang Baru:||24|")
    table.insert(dLines, "add_text_input|as_dlg_add_stor_door|Door ID Gudang:||24|")
    table.insert(dLines, "add_button|as_dlg_btn_add_stor|➕ Tambah Gudang|noflags|0|0|")
    table.insert(dLines, "add_spacer|small|")
    table.insert(dLines, "add_button|as_dlg_btn_paste_stor|📋 Tempel Banyak Gudang|noflags|0|0|")
    table.insert(dLines, "add_button|as_dlg_btn_copy_stor|📄 Salin Semua Gudang|noflags|0|0|")
    table.insert(dLines, "add_button|as_dlg_btn_clear_stor|🗑️ Bersihkan Gudang|noflags|0|0|")
    table.insert(dLines, "add_spacer|small|")
    table.insert(dLines, "end_dialog|boren_soil_stor_mgr|Tutup||")

    safeSendRawDialog(table.concat(dLines, "\n"))
end

local function handleSoilDialog(var)
    if not var or not var.get then return false end
    local v0 = var:get(0)
    local v1 = var:get(1)
    local v2 = var:get(2)
    local dName = (v0 and v0.getString and v0:getString()) or ""
    local dText = (v1 and v1.getString and v1:getString()) or ""

    if dName == "OnDialogRequest" then return false end

    -- Dialog World Farm
    if dText:find("boren_soil_world_mgr") then
        if dText:find("buttonClicked|as_dlg_btn_add") then
            local nw = dText:match("as_dlg_add_world|([^|\n\r]+)")
            local nd = dText:match("as_dlg_add_door|([^|\n\r]+)") or ""
            if nw and nw ~= "" then
                table.insert(CFG.farm_world_list, { name = nw:upper():match("^%s*(.-)%s*$"), door = nd:upper():match("^%s*(.-)%s*$"), done = false })
                savePrefs(CFG)
                saveWorldsToFile()
                addLog("`2[Tambah World] `wWorld " .. nw:upper() .. " ditambahkan.")
            end
            openUnifiedWorldManager()
            return true
        elseif dText:find("buttonClicked|as_dlg_btn_clear") then
            CFG.farm_world_list = {}
            savePrefs(CFG)
            saveWorldsToFile()
            addLog("`4[Bersihkan World] `oDaftar world dikosongkan.")
            openUnifiedWorldManager()
            return true
        elseif dText:find("buttonClicked|as_dlg_btn_copy") then
            local out = {}
            for _, w in ipairs(CFG.farm_world_list) do
                table.insert(out, w.name .. ((w.door and w.door ~= "") and ("|" .. w.door) or ""))
            end
            if ImGui and ImGui.SetClipboardText then
                ImGui.SetClipboardText(table.concat(out, "\n"))
            end
            notifyUser("Daftar world disalin ke clipboard!")
            return true
        end
    end

    -- Dialog Storage
    if dText:find("boren_soil_stor_mgr") then
        if dText:find("buttonClicked|as_dlg_btn_add_stor") then
            local ns = dText:match("as_dlg_add_stor|([^|\n\r]+)")
            local nd = dText:match("as_dlg_add_stor_door|([^|\n\r]+)") or ""
            if ns and ns ~= "" then
                table.insert(CFG.storage_list, { name = ns:upper():match("^%s*(.-)%s*$"), door = nd:upper():match("^%s*(.-)%s*$") })
                savePrefs(CFG)
                saveStoragesToFile()
                addLog("`2[Tambah Gudang] `wGudang " .. ns:upper() .. " ditambahkan.")
            end
            openUnifiedStorageManager()
            return true
        elseif dText:find("buttonClicked|as_dlg_btn_clear_stor") then
            CFG.storage_list = {}
            savePrefs(CFG)
            saveStoragesToFile()
            addLog("`4[Bersihkan Gudang] `oDaftar gudang dikosongkan.")
            openUnifiedStorageManager()
            return true
        end
    end

    return false
end

-- ============================================================================
-- 15. NATIVE GROWLAUNCHER UI BUILDER
-- ============================================================================
local function initSoilBuilderUI()
    if not addCategory or not addIntoModule then
        addLog("`4[UI Warning] `oFungsi Native UI Growlauncher tidak terdeteksi.")
        return
    end

    addCategory("Boren Store")

    -- ------------------------------------------------------------------------
    -- TAB 1: Mulai & Farm World
    -- ------------------------------------------------------------------------
    addIntoModule("🌱 Auto Soil Builder", "🌱 Mulai & Farm World", function(ui)
        ui:addLabel("=== STATUS BOT & KONTROL UTAMA ===")
        ui:addButton("▶️ JALANKAN BOT", "as_btn_start")
        ui:addButton("⏸️ JEDA / LANJUT", "as_btn_pause")
        ui:addButton("⏹️ HENTIKAN BOT", "as_btn_stop")
        ui:addSpacer()

        ui:addLabel("=== MODE WORLD FARM ===")
        ui:addCheckbox("Cari & Blast Otomatis (Random Search)", CFG.world_mode == "RANDOM", "as_chk_mode_random")
        ui:addInputInt("Panjang Huruf Random", CFG.random_letter_count, "as_in_rnd_len")
        ui:addCheckbox("Sertakan Angka (0-9) di Nama World", CFG.random_with_number, "as_chk_rnd_num")
        ui:addInputText("Prefix Nama World (Opsional)", CFG.random_prefix, "as_in_rnd_prefix")
        ui:addInputInt("Target Jumlah World", CFG.random_target_count, "as_in_rnd_target")
        ui:addSpacer()

        ui:addLabel("=== AUTO USE BLAST ===")
        ui:addCheckbox("Gunakan Blast di World Baru (Opsional)", CFG.auto_use_blast, "as_chk_auto_blast")
        ui:addInputInt("ID Item Blast (1336 / 2810)", CFG.blast_item_id, "as_in_blast_id")
        ui:addLabel(string.format("Item Blast: %s (ID: %d)", getItemNameSafe(CFG.blast_item_id), CFG.blast_item_id))
        ui:addSpacer()

        ui:addLabel("=== MANAJEMEN ANTREAN WORLD ===")
        ui:addButton("📋 Kelola Daftar Farm World", "as_btn_manage_worlds")
        ui:addButton("💾 Simpan Antrean ke Download", "as_btn_save_worlds")
        ui:addButton("📤 Muat Antrean dari Download", "as_btn_load_worlds")
        ui:addSpacer()
        ui:addDisplayList("Daftar Farm World", "Default", "as_world_display_list")
    end)

    -- ------------------------------------------------------------------------
    -- TAB 2: Kunci & Pengaman (Sesuai Gambar 2)
    -- ------------------------------------------------------------------------
    addIntoModule("🌱 Auto Soil Builder", "🔒 Kunci & Pengaman (Gambar 2)", function(ui)
        ui:addLabel("=== STRUKTUR PENGAMAN PINTU (GAMBAR 2) ===")
        ui:addCheckbox("Aktifkan Pembuatan Pengaman Lock (Gambar 2)", CFG.enable_lock_enclosure, "as_chk_enable_lock")
        ui:addSpacer()

        ui:addLabel("Diagram Posisi (Relatif terhadap White Door):")
        ui:addLabel("[ Wooden Door ] [ Small Lock ]    [ Air Vent ]")
        ui:addLabel("[ World Lock  ] [ Signal Jammer ] [ White Door ]")
        ui:addSpacer()

        ui:addInputInt("ID World Lock (Kiri Bawah)", CFG.lock_id_wl, "as_in_id_wl")
        ui:addInputInt("ID Small Lock (Tengah Atas)", CFG.lock_id_sl, "as_in_id_sl")
        ui:addInputInt("ID Signal Jammer (Tengah Bawah)", CFG.lock_id_jammer, "as_in_id_jammer")
        ui:addInputInt("ID Blocker Door / Air Vent (Atas White Door)", CFG.lock_id_blocker, "as_in_id_blocker")
        ui:addInputInt("ID Wooden Door (Kiri Atas)", CFG.lock_id_door, "as_in_id_door")
        ui:addInputText("Label / ID Door Masuk", CFG.farm_door_id, "as_in_door_label")
        ui:addCheckbox("Jadikan World Lock Public", CFG.wl_make_public, "as_chk_wl_public")
        ui:addSpacer()
        ui:addButton("💾 Simpan Pengaturan Lock", "as_btn_save_lock_cfg")
    end)

    -- ------------------------------------------------------------------------
    -- TAB 3: Gudang & Ambil Supply
    -- ------------------------------------------------------------------------
    addIntoModule("🌱 Auto Soil Builder", "📦 Gudang & Ambil Supply", function(ui)
        ui:addLabel("=== PENGATURAN MULTI-STORAGE GUDANG ===")
        ui:addButton("📋 Kelola Daftar Gudang Storage", "as_btn_manage_storages")
        ui:addButton("💾 Simpan Daftar Gudang ke Download", "as_btn_save_storages")
        ui:addButton("📤 Muat Daftar Gudang dari Download", "as_btn_load_storages")
        ui:addSpacer()

        ui:addInputInt("Batas Restock Block (Ambil jika sisa < X)", CFG.restock_threshold, "as_in_restock_thresh")
        ui:addSpacer()
        ui:addDisplayList("Daftar Gudang Storage", "Default", "as_stor_display_list")
    end)

    -- ------------------------------------------------------------------------
    -- TAB 4: Layout & Penempatan Block
    -- ------------------------------------------------------------------------
    addIntoModule("🌱 Auto Soil Builder", "📐 Layout & Penempatan Block", function(ui)
        ui:addLabel("=== PILIHAN BLOCK SOIL / PLATFORM ===")
        ui:addInputInt("ID Block yang Ditaruh", CFG.block_id, "as_in_block_id")
        ui:addLabel(string.format("Block Terpilih: %s (ID: %d)", getItemNameSafe(CFG.block_id), CFG.block_id))
        ui:addButton("💾 Simpan ID Block", "as_btn_save_block_id")
        ui:addSpacer()

        ui:addLabel("=== PENGATURAN BARIS (GAMBAR 1) ===")
        ui:addInputInt("Jarak Baris (Row Step, Default 2)", CFG.row_step, "as_in_row_step")
        ui:addInputInt("Baris Mulai Y (Default 2)", CFG.row_start_y, "as_in_start_y")
        ui:addInputInt("Baris Akhir Y (Default 54)", CFG.row_end_y, "as_in_end_y")
        ui:addInputInt("Kolom Mulai X (Default 2)", CFG.row_start_x, "as_in_start_x")
        ui:addInputInt("Kolom Akhir X (Default 99)", CFG.row_end_x, "as_in_end_x")
        ui:addSpacer()

        ui:addLabel("=== KOLOM WATER ELEVATOR (GAMBAR 1) ===")
        ui:addCheckbox("Pasang Kolom Water di Sebelah Kiri (Gambar 1)", CFG.enable_water_column, "as_chk_enable_water")
        ui:addInputInt("ID Item Water (Default 822)", CFG.water_item_id, "as_in_water_id")
        ui:addInputInt("Kolom X Water (Default 0)", CFG.water_x, "as_in_water_x")
        ui:addSpacer()

        ui:addLabel("=== DELAY & PACING (MS) ===")
        ui:addInputInt("Delay Taruh Block (ms)", CFG.delay_place, "as_in_delay_place")
        ui:addInputInt("Delay Jalan (ms)", CFG.delay_walk, "as_in_delay_walk")
        ui:addInputInt("Delay Pukul (ms)", CFG.delay_punch, "as_in_delay_punch")
    end)

    -- ------------------------------------------------------------------------
    -- TAB 5: Console, Tas & Log
    -- ------------------------------------------------------------------------
    addIntoModule("🌱 Auto Soil Builder", "⚙️ Console, Tas & Log", function(ui)
        ui:addLabel("=== STATUS BOT REAL-TIME ===")
        ui:addLabel(string.format("Status: %s | World Aktif: %s", STATE.status_text, STATE.current_world ~= "" and STATE.current_world or "-"))
        ui:addLabel(string.format("Total Block Terpasang: %d | Total World Selesai: %d", STATE.total_placed_blocks, STATE.total_worlds_completed))
        ui:addSpacer()

        ui:addLabel("=== LOG AKTIVITAS TERBARU ===")
        ui:addDisplayList("Log Aktivitas", "Default", "as_log_display_list")
        ui:addSpacer()
        ui:addButton("🗑️ Bersihkan Log", "as_btn_clear_log")
    end)
end

-- ============================================================================
-- 16. EVENT DISPATCHERS & VALUE HANDLERS
-- ============================================================================
local function handleSoilUIValue(ctrlName, val)
    if not ctrlName or ctrlName == "" then return end

    if ctrlName == "as_btn_start" then
        if not STATE.running then
            if async then
                async(autoSoilMainLoop)
            else
                autoSoilMainLoop()
            end
        end
    elseif ctrlName == "as_btn_pause" then
        STATE.paused = not STATE.paused
        addLog(STATE.paused and "`e[Jeda] `0Bot dijeda sementara." or "`2[Lanjut] `0Bot dilanjutkan.")
    elseif ctrlName == "as_btn_stop" then
        STATE.running = false
        STATE.paused = false
        addLog("`4[Berhenti] `0Bot dihentikan oleh user.")
    elseif ctrlName == "as_chk_mode_random" then
        CFG.world_mode = (val == "1" or val == "true" or val == true) and "RANDOM" or "MANUAL"
        savePrefs(CFG)
    elseif ctrlName == "as_in_rnd_len" then
        CFG.random_letter_count = tonumber(val) or CFG.random_letter_count
        savePrefs(CFG)
    elseif ctrlName == "as_chk_rnd_num" then
        CFG.random_with_number = (val == "1" or val == "true" or val == true)
        savePrefs(CFG)
    elseif ctrlName == "as_in_rnd_prefix" then
        CFG.random_prefix = tostring(val or "")
        savePrefs(CFG)
    elseif ctrlName == "as_in_rnd_target" then
        CFG.random_target_count = tonumber(val) or CFG.random_target_count
        savePrefs(CFG)
    elseif ctrlName == "as_chk_auto_blast" then
        CFG.auto_use_blast = (val == "1" or val == "true" or val == true)
        savePrefs(CFG)
    elseif ctrlName == "as_in_blast_id" then
        CFG.blast_item_id = tonumber(val) or CFG.blast_item_id
        savePrefs(CFG)
    elseif ctrlName == "as_btn_manage_worlds" then
        openUnifiedWorldManager()
    elseif ctrlName == "as_btn_save_worlds" then
        saveWorldsToFile()
    elseif ctrlName == "as_btn_load_worlds" then
        loadWorldsFromFile()
    elseif ctrlName == "as_chk_enable_lock" then
        CFG.enable_lock_enclosure = (val == "1" or val == "true" or val == true)
        savePrefs(CFG)
    elseif ctrlName == "as_in_id_wl" then
        CFG.lock_id_wl = tonumber(val) or CFG.lock_id_wl
    elseif ctrlName == "as_in_id_sl" then
        CFG.lock_id_sl = tonumber(val) or CFG.lock_id_sl
    elseif ctrlName == "as_in_id_jammer" then
        CFG.lock_id_jammer = tonumber(val) or CFG.lock_id_jammer
    elseif ctrlName == "as_in_id_blocker" then
        CFG.lock_id_blocker = tonumber(val) or CFG.lock_id_blocker
    elseif ctrlName == "as_in_id_door" then
        CFG.lock_id_door = tonumber(val) or CFG.lock_id_door
    elseif ctrlName == "as_in_door_label" then
        CFG.farm_door_id = tostring(val or "")
    elseif ctrlName == "as_chk_wl_public" then
        CFG.wl_make_public = (val == "1" or val == "true" or val == true)
    elseif ctrlName == "as_btn_save_lock_cfg" then
        savePrefs(CFG)
        notifyUser("Pengaturan Lock berhasil disimpan!")
        addLog("`2[Simpan Lock] `wPengaturan pengaman Gambar 2 disimpan.")
    elseif ctrlName == "as_btn_manage_storages" then
        openUnifiedStorageManager()
    elseif ctrlName == "as_btn_save_storages" then
        saveStoragesToFile()
    elseif ctrlName == "as_btn_load_storages" then
        loadStoragesFromFile()
    elseif ctrlName == "as_in_restock_thresh" then
        CFG.restock_threshold = tonumber(val) or CFG.restock_threshold
        savePrefs(CFG)
    elseif ctrlName == "as_in_block_id" then
        CFG.block_id = tonumber(val) or CFG.block_id
    elseif ctrlName == "as_btn_save_block_id" then
        savePrefs(CFG)
        notifyUser(string.format("ID Block %d (%s) tersimpan!", CFG.block_id, getItemNameSafe(CFG.block_id)))
        addLog(string.format("`2[Simpan Block] `wID Block disetel ke %d (%s)", CFG.block_id, getItemNameSafe(CFG.block_id)))
    elseif ctrlName == "as_in_row_step" then
        CFG.row_step = tonumber(val) or CFG.row_step
        savePrefs(CFG)
    elseif ctrlName == "as_chk_enable_water" then
        CFG.enable_water_column = (val == "1" or val == "true" or val == true)
        savePrefs(CFG)
    elseif ctrlName == "as_in_water_id" then
        CFG.water_item_id = tonumber(val) or CFG.water_item_id
        savePrefs(CFG)
    elseif ctrlName == "as_in_water_x" then
        CFG.water_x = tonumber(val) or CFG.water_x
        savePrefs(CFG)
    elseif ctrlName == "as_in_delay_place" then
        CFG.delay_place = tonumber(val) or CFG.delay_place
        savePrefs(CFG)
    elseif ctrlName == "as_in_delay_walk" then
        CFG.delay_walk = tonumber(val) or CFG.delay_walk
        savePrefs(CFG)
    elseif ctrlName == "as_in_delay_punch" then
        CFG.delay_punch = tonumber(val) or CFG.delay_punch
        savePrefs(CFG)
    elseif ctrlName == "as_btn_clear_log" then
        STATE.log_messages = {}
        if updateLogDisplayList then pcall(updateLogDisplayList) end
    end
end

-- Export OnValue
function OnValue(ctrlName, val)
    pcall(handleSoilUIValue, ctrlName, val)
end
onValue = OnValue

-- Variant Hook untuk menangani Dialog Growtopia
if addEvent and Event and Event.variantlist then
    pcall(addEvent, Event.variantlist, function(var)
        pcall(handleSoilDialog, var)
    end)
end

-- Inisialisasi awal UI
pcall(initSoilBuilderUI)
addLog("`2[Boren Store] `wAuto Soil & Block Builder siap digunakan!")
