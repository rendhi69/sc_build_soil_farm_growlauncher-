---@diagnostic disable: undefined-global, lowercase-global
-- ============================================================================
-- AUTO SOIL & BLOCK BUILDER BY BOREN STORE - GROWLAUNCHER
-- Sistem Pembuatan Farm Terpadu (Baris Block & Elevator Air) serta Proteksi Kunci Lengkap
-- Fitur: Auto Blast World, Multi-Storage Restock, Multi-World Farm Management,
--        Water Column, Persistent File Backup di Folder Download HP / PC
-- ============================================================================

-- ============================================================================
-- 1. PURE LUA JSON ENCODER (STANDAR GROWLAUNCHER NATIVE UI)
-- ============================================================================
local function escapeJsonStr(s)
    s = tostring(s or "")
    s = s:gsub("\\", "\\\\")
    s = s:gsub('"', '\\"')
    s = s:gsub("\n", "\\n")
    s = s:gsub("\r", "\\r")
    s = s:gsub("\t", "\\t")
    return '"' .. s .. '"'
end

local function encodeJsonValue(v)
    local t = type(v)
    if t == "string" then
        return escapeJsonStr(v)
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "table" then
        local isArr = (#v > 0) or (next(v) == nil)
        if isArr then
            local parts = {}
            for i = 1, #v do
                parts[i] = encodeJsonValue(v[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, val in pairs(v) do
                table.insert(parts, escapeJsonStr(k) .. ":" .. encodeJsonValue(val))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

local function jsonEncode(val)
    return encodeJsonValue(val)
end

-- ============================================================================
-- 2. SAFE PREFERENCES & CONFIGURATION
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
    
    -- Pengaturan Proteksi Kunci Pintu
    enable_lock_enclosure   = (loadPref("enable_lock_enclosure", true) == true),
    lock_id_wl              = tonumber(loadPref("lock_id_wl", 242)) or 242,       -- World Lock
    lock_id_sl              = tonumber(loadPref("lock_id_sl", 202)) or 202,       -- Small Lock
    lock_id_jammer          = tonumber(loadPref("lock_id_jammer", 226)) or 226,   -- Signal Jammer
    lock_id_blocker         = tonumber(loadPref("lock_id_blocker", 828)) or 828,  -- Blocker Door (Air Vent)
    lock_id_door            = tonumber(loadPref("lock_id_door", 12)) or 12,       -- Wooden Door
    farm_door_id            = tostring(loadPref("farm_door_id", "BOREN")),        -- Label / ID Door
    wl_make_public          = (loadPref("wl_make_public", false) == true),
    
    -- Pengaturan Elevator Air Vertikal
    enable_water_column     = (loadPref("enable_water_column", true) == true),
    water_item_id           = tonumber(loadPref("water_item_id", 822)) or 822,    -- 822 = Water
    water_x                 = tonumber(loadPref("water_x", 0)) or 0,              -- Kolom elevator X = 0
    water_start_y           = tonumber(loadPref("water_start_y", 1)) or 1,
    water_end_y             = tonumber(loadPref("water_end_y", 54)) or 54,
    
    -- Pengaturan Tata Letak Baris Block
    block_id                = tonumber(loadPref("block_id", 8772)) or 8772,       -- Default 8772 = Soil Block
    row_step                = tonumber(loadPref("row_step", 2)) or 2,             -- Tiap 2 baris (Y genap: 2, 4, 6... 54)
    row_start_y             = tonumber(loadPref("row_start_y", 2)) or 2,
    row_end_y               = tonumber(loadPref("row_end_y", 54)) or 54,
    row_start_x             = tonumber(loadPref("row_start_x", 2)) or 2,          -- X mulai (setelah kolom water)
    row_end_x               = tonumber(loadPref("row_end_x", 99)) or 99,
    
    -- Cheats & Movement Aids
    use_modfly              = (loadPref("use_modfly", true) == true),
    use_anti_lava           = (loadPref("use_anti_lava", true) == true),
    
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
    
    -- Buffer input
    buf_new_world           = "",
    buf_new_door            = "",
    buf_new_stor            = "",
    buf_new_stor_door       = "",
    
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

-- Forward declarations of update functions
local updatePowerStatusList = nil
local updateWorldDisplayList = nil
local updateStorageDisplayList = nil
local updateLogDisplayList = nil

-- ============================================================================
-- 3. ITEM CONSTANTS & SAFE NAME RESOLVER
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
    [8772] = "Soil Block",
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

local function getWorldNameSafe()
    local fn = getCurrentWorldName or GetCurrentWorldName
    if fn then
        local ok, n = pcall(fn)
        if ok and type(n) == "string" and n ~= "" and n:upper() ~= "EXIT" then
            return n:upper()
        end
    end
    local wFn = getWorld or GetWorld
    if wFn then
        local ok, w = pcall(wFn)
        if ok and w then
            if type(w) == "string" and w ~= "" and w:upper() ~= "EXIT" then
                return w:upper()
            elseif type(w) == "table" and w.name and type(w.name) == "string" and w.name ~= "" and w.name:upper() ~= "EXIT" then
                return w.name:upper()
            end
        end
    end
    if getBot then
        local ok, b = pcall(getBot)
        if ok and b then
            if b.getWorld then
                local ok2, w = pcall(b.getWorld, b)
                if ok2 and w and type(w.name) == "string" and w.name ~= "" and w.name:upper() ~= "EXIT" then
                    return w.name:upper()
                end
            end
            if b.world and type(b.world) == "string" and b.world ~= "" and b.world:upper() ~= "EXIT" then
                return b.world:upper()
            end
        end
    end
    if getLocal then
        local ok, p = pcall(getLocal)
        if ok and p and p.world and type(p.world) == "string" and p.world ~= "" and p.world:upper() ~= "EXIT" then
            return p.world:upper()
        end
    end
    return ""
end

-- ============================================================================
-- 4. LOGGING, WEBHOOK & DISPLAY UPDATERS
-- ============================================================================
local function addLog(msg)
    local tStr = os.date("%H:%M:%S")
    local line = string.format("[%s] %s", tStr, msg)
    table.insert(STATE.log_messages, 1, line)
    while #STATE.log_messages > 50 do
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

-- UI Real-time Updaters via editValue
updatePowerStatusList = function()
    if not editValue then return end
    local statusTitle = STATE.running and (STATE.paused and "STATUS: DIJEDA (PAUSE)" or "STATUS: SEDANG BERJALAN") or "STATUS: BERHENTI (OFF)"
    local curW = (STATE.current_world ~= "") and STATE.current_world or "(Belum masuk world)"
    local blockInfo = string.format("%s (ID: %d)", getItemNameSafe(CFG.block_id), CFG.block_id)
    local pList = {
        { statusTitle, STATE.status_text or "Siap digunakan" },
        { "World Farm Aktif", curW },
        { "Block yang Ditaruh", blockInfo },
        { "Total Block Terpasang", string.format("%d Block", STATE.total_placed_blocks) },
        { "Total World Selesai", string.format("%d World", STATE.total_worlds_completed) },
    }
    pcall(editValue, "as_power_status_list", jsonEncode(pList))
end

updateWorldDisplayList = function()
    if not editValue then return end
    local list = {}
    for idx, w in ipairs(CFG.farm_world_list) do
        local status = w.done and "`2[SELESAI]" or "`e[ANTREAN]"
        local dInfo = (w.door and w.door ~= "") and (" [Door: " .. w.door .. "]") or ""
        table.insert(list, {
            string.format("%d. %s%s", idx, w.name, dInfo),
            status
        })
    end
    if #list == 0 then table.insert(list, { "Antrean world kosong", "Gunakan form di atas untuk menambah" }) end
    pcall(editValue, "as_world_display_list", jsonEncode(list))
end

updateStorageDisplayList = function()
    if not editValue then return end
    local list = {}
    for idx, s in ipairs(CFG.storage_list) do
        local dInfo = (s.door and s.door ~= "") and (" [Door: " .. s.door .. "]") or ""
        table.insert(list, {
            string.format("%d. %s%s", idx, s.name, dInfo),
            "Gudang Block"
        })
    end
    if #list == 0 then table.insert(list, { "Belum ada gudang", "Tambahkan gudang di form di atas" }) end
    pcall(editValue, "as_stor_display_list", jsonEncode(list))
end

updateLogDisplayList = function()
    if not editValue then return end
    local lList = {}
    for _, l in ipairs(STATE.log_messages) do
        table.insert(lList, { l, "" })
    end
    if #lList == 0 then table.insert(lList, { "Belum ada aktivitas.", "" }) end
    pcall(editValue, "as_log_display_list", jsonEncode(lList))
end

-- ============================================================================
-- 5. SAFE FILE PERSISTENCE ENGINE (FOLDER DOWNLOAD HP / PC)
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
    updateWorldDisplayList()
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
    updateStorageDisplayList()
    return true
end

-- ============================================================================
-- 6. INVENTORY & BOT HELPERS
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
-- 7. MOVEMENT & PATHFINDING
-- ============================================================================
local function applyCheatToggles()
    if not editToggle then return end
    if CFG.use_modfly then
        pcall(editToggle, "ModFly", true)
    end
    if CFG.use_anti_lava then
        pcall(editToggle, "Anti Lava", true)
        pcall(editToggle, "No Lava", true)
    end
end

local function isTileSafe(tx, ty)
    if tx < 0 or tx > 99 or ty < 0 or ty > 59 then return false end
    local ok, t = pcall(getTile, tx, ty)
    if not ok or not t then return false end
    if t.fg == 4 or t.fg == 8 then return false end -- Lava / Bedrock
    return true
end

local function isTileSafeToStand(tx, ty)
    if tx < 0 or tx > 99 or ty < 0 or ty > 53 then return false end
    local ok, t = pcall(getTile, tx, ty)
    if not ok or not t then return true end
    local fg = t.fg or 0
    if fg == 4 or fg == 8 or fg == 2 or fg == 10 or fg == 100 or fg == 8772 then
        return false
    end
    if t.collidable then
        return false
    end
    if CFG.use_anti_lava and ty < 53 then
        local okB, below = pcall(getTile, tx, ty + 1)
        if okB and below and below.fg == 4 then
            return false
        end
    end
    return true
end

local function moveSafeTo(tx, ty)
    tx = math.max(0, math.min(99, tx))
    ty = math.max(0, math.min(53, ty))
    local curX, curY = getPlayerPos()
    if curX == tx and curY == ty then return true end

    local pFn = FindPath or findPath or (getBot and getBot().findPath)
    if not pFn then return false end

    applyCheatToggles()

    local function nearestFree(cx, cy)
        for r = 0, 3 do
            for oy = -r, r do
                for ox = -r, r do
                    if math.max(math.abs(ox), math.abs(oy)) == r and isTileSafeToStand(cx + ox, cy + oy) then
                        return cx + ox, cy + oy
                    end
                end
            end
        end
        return cx, cy
    end

    local CHUNK_LIMIT = 5
    local stuck = 0
    while STATE.running and not STATE.paused do
        curX, curY = getPlayerPos()
        if not curX or not curY then
            safeSleep(100)
            break
        end
        if curX == tx and curY == ty then return true end

        local dx = tx - curX
        local dy = ty - curY
        local dist = math.max(math.abs(dx), math.abs(dy))
        if dist == 0 then return true end

        local stepX, stepY = tx, ty
        local direct = (dist <= CHUNK_LIMIT) or stuck >= 1
        if not direct then
            local ratio = CHUNK_LIMIT / dist
            local ix = math.max(0, math.min(99, math.floor(curX + (dx * ratio) + 0.5)))
            local iy = math.max(0, math.min(53, math.floor(curY + (dy * ratio) + 0.5)))
            stepX, stepY = nearestFree(ix, iy)
            if not stepX then stepX, stepY, direct = tx, ty, true end
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
        local stepDist = math.max(math.abs(curX - stepX), math.abs(curY - stepY))
        local maxWait = math.max(120, math.min(1500, stepDist * 60))
        while waited < maxWait and STATE.running do
            local nx, ny = getPlayerPos()
            if nx and ny and math.abs(nx - stepX) <= 1 and math.abs(ny - stepY) <= 1 then break end
            safeSleep(25)
            waited = waited + 25
        end

        local npx, npy = getPlayerPos()
        if npx == tx and npy == ty then return true end
        if npx == curX and npy == curY then
            stuck = stuck + 1
            if stuck >= 2 then
                local okP, p = pcall(getLocal)
                if okP and p and sendPacketRaw then
                    pcall(sendPacketRaw, false, { type = 0, x = tx * 32, y = ty * 32 })
                end
                if stuck >= 3 then break end
            end
        else
            stuck = 0
            if direct and npx and npy and math.abs(npx - tx) <= 1 and math.abs(npy - ty) <= 1 then
                break
            end
        end
        safeSleep(math.floor(walkDelay * (0.85 + math.random() * 0.3)))
    end
    local fx, fy = getPlayerPos()
    return (fx and fy and math.abs(fx - tx) <= 1 and math.abs(fy - ty) <= 1)
end

-- ============================================================================
-- 8. TILE ACTIONS & VALIDATION
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
-- 9. LOCK & ACCESS PROTECTION ENGINE
-- ============================================================================
local function getMissingLockMaterials()
    local missing = {}
    local needed = {
        { id = CFG.lock_id_wl, name = "World Lock", count = 1 },
        { id = CFG.lock_id_sl, name = "Small Lock", count = 1 },
        { id = CFG.lock_id_jammer, name = "Signal Jammer", count = 1 },
        { id = CFG.lock_id_blocker, name = "Blocker Door", count = 1 },
        { id = CFG.lock_id_door, name = "Wooden Door", count = 1 },
    }
    for _, item in ipairs(needed) do
        local inInv = getInvCount(item.id)
        if inInv < item.count then
            table.insert(missing, { id = item.id, name = item.name, need = item.count - inInv })
        end
    end
    return missing
end

local function restockLockMaterialsFromStorage(missing)
    if #CFG.storage_list == 0 then
        local names = {}
        for _, m in ipairs(missing) do
            table.insert(names, string.format("%s (ID %d)", m.name, m.id))
        end
        local warnStr = "Bahan proteksi tidak ada di tas & daftar gudang kosong: " .. table.concat(names, ", ")
        addLog("`4[Peringatan Bahan] `o" .. warnStr)
        notifyUser(warnStr)
        return false
    end

    local currentFarm = STATE.current_world
    local currentFarmDoor = STATE.current_door
    addLog("`9[Proteksi Gudang] `0Bahan proteksi kurang di tas. Mencari ke gudang...")

    for _, stor in ipairs(CFG.storage_list) do
        if not STATE.running or STATE.paused then break end
        if stor.name and stor.name ~= "" then
            addLog(string.format("`9[Cek Gudang] `0Mengecek bahan proteksi di %s...", stor.name))
            if warpToWorld(stor.name, stor.door) then
                safeSleep(1500)
                local objs = nil
                if getObjects then
                    local okO, resO = pcall(getObjects)
                    if okO and resO then objs = resO end
                elseif getBot and getBot().getWorld then
                    local w = getBot():getWorld()
                    if w and w.getObjects then objs = w:getObjects() end
                end

                if objs then
                    for _, m in ipairs(missing) do
                        if getInvCount(m.id) < m.need then
                            for _, obj in pairs(objs) do
                                local oId = obj.id or obj.item or 0
                                if oId == m.id then
                                    local ox = math.floor((obj.posX or obj.x or 0) / 32)
                                    local oy = math.floor((obj.posY or obj.y or 0) / 32)
                                    moveSafeTo(ox, oy)
                                    safeSleep(400)
                                    if collect then pcall(collect, 2, 5) end
                                    safeSleep(500)
                                    if getInvCount(m.id) >= m.need then
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Kembali ke farm world
    if currentFarm ~= "" then
        warpToWorld(currentFarm, currentFarmDoor)
        safeSleep(1200)
    end

    -- Evaluasi apakah semua bahan sudah lengkap
    local stillMissing = getMissingLockMaterials()
    if #stillMissing > 0 then
        local names = {}
        for _, m in ipairs(stillMissing) do
            table.insert(names, string.format("%s (ID %d)", m.name, m.id))
        end
        local warnStr = "Bahan proteksi tidak lengkap di tas/gudang: " .. table.concat(names, ", ")
        addLog("`4[Peringatan Bahan] `o" .. warnStr)
        notifyUser(warnStr)
        return false
    end

    addLog("`2[Proteksi Gudang] `wSeluruh bahan proteksi berhasil diambil dari gudang!")
    return true
end

local function buildLockEnclosure()
    -- 1. Validasi opsi apakah user mengaktifkan proteksi lock
    if not CFG.enable_lock_enclosure then
        addLog("`e[Proteksi Kunci] `0Fitur proteksi kunci dinonaktifkan oleh user.")
        return true
    end

    addLog("`9[Proteksi Kunci] `0Memeriksa posisi White Door dan ketersediaan bahan...")

    -- 2. Cek posisi White Door
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
        addLog("`4[Proteksi Gagal] `oWhite Door tidak ditemukan di world ini!")
        notifyUser("Peringatan: White Door tidak ditemukan!")
        return false
    end
    addLog(string.format("`2[Proteksi] `wWhite Door terdeteksi di koordinat (%d, %d)", doorX, doorY))

    -- Tentukan orientasi horizontal (kiri pintu jika doorX >= 2, kanan jika < 2)
    local dirX = (doorX >= 2) and -1 or 1
    local pJammer  = { x = doorX + (1 * dirX), y = doorY }
    local pBlocker = { x = doorX,              y = doorY - 1 }
    local pSL      = { x = doorX + (1 * dirX), y = doorY - 1 }
    local pDoor    = { x = doorX + (2 * dirX), y = doorY - 1 }
    local pWL      = { x = doorX + (2 * dirX), y = doorY }

    -- 3. Cek apakah formasi kunci sudah pernah terpasang lengkap
    local okWl, tWl = pcall(getTile, pWL.x, pWL.y)
    local okSl, tSl = pcall(getTile, pSL.x, pSL.y)
    if okWl and tWl and tWl.fg == CFG.lock_id_wl and okSl and tSl and tSl.fg == CFG.lock_id_sl then
        addLog("`2[Proteksi Kunci] `wStruktur proteksi kunci sudah terpasang rapi!")
        return true
    end

    -- 4. Validasi ketersediaan bahan yang diperlukan
    local missingMat = getMissingLockMaterials()
    if #missingMat > 0 then
        addLog("`e[Bahan Kurang] `0Bahan proteksi belum lengkap di tas. Mencoba mengambil ke gudang...")
        local okRestock = restockLockMaterialsFromStorage(missingMat)
        if not okRestock then
            addLog("`4[Peringatan Proteksi] `oPemasangan kunci dilewati karena bahan tidak tersedia.")
            notifyUser("Pemasangan kunci dilewati: bahan tidak lengkap.")
            return false
        end
    end

    -- 5. Bersihkan area petak formasi proteksi
    local spotsToClear = { pBlocker, pJammer, pSL, pDoor, pWL }
    for _, sp in ipairs(spotsToClear) do
        local ok, t = pcall(getTile, sp.x, sp.y)
        if ok and t and (t.fg ~= 0 and t.fg ~= 8 and t.fg ~= 6) then
            breakTileAt(sp.x, sp.y)
        end
    end

    -- 6. Pasang Signal Jammer
    addLog("`9[Proteksi] `0Memasang Signal Jammer...")
    if not placeTileAt(pJammer.x, pJammer.y, CFG.lock_id_jammer) then
        addLog("`e[Proteksi] `0Peringatan: Gagal menaruh Signal Jammer.")
    end

    -- 7. Pasang Blocker Door / Air Vent
    addLog("`9[Proteksi] `0Memasang Blocker Door...")
    if not placeTileAt(pBlocker.x, pBlocker.y, CFG.lock_id_blocker) then
        addLog("`e[Proteksi] `0Peringatan: Gagal menaruh Blocker Door.")
    end

    -- 8. Pasang Small Lock & Recalc Lock
    addLog("`9[Proteksi] `0Memasang Small Lock...")
    if placeTileAt(pSL.x, pSL.y, CFG.lock_id_sl) then
        safeSleep(300)
        wrenchTile(pSL.x, pSL.y)
        safeSleep(300)
        if sendPacket then
            pcall(sendPacket, 2, string.format("action|dialog_return\ndialog_name|lock_edit\ntilex|%d|\ntiley|%d|\nbuttonClicked|recalcLock\n\ncheckbox_public|0\ncheckbox_ignore|1", pSL.x, pSL.y))
        end
        safeSleep(300)
    end

    -- 9. Pasang Wooden Door & Setting Door ID
    addLog("`9[Proteksi] `0Memasang Wooden Door...")
    if placeTileAt(pDoor.x, pDoor.y, CFG.lock_id_door) then
        safeSleep(300)
        wrenchTile(pDoor.x, pDoor.y)
        safeSleep(300)
        local dID = (CFG.farm_door_id and CFG.farm_door_id ~= "") and CFG.farm_door_id or "BOREN"
        if sendPacket then
            pcall(sendPacket, 2, string.format("action|dialog_return\ndialog_name|door_edit\ntilex|%d|\ntiley|%d|\ndoor_name|\ndoor_target|\ndoor_id|%s\ncheckbox_locked|1", pDoor.x, pDoor.y, dID))
        end
        safeSleep(300)
    end

    -- 10. Pasang World Lock
    addLog("`9[Proteksi] `0Memasang World Lock...")
    if placeTileAt(pWL.x, pWL.y, CFG.lock_id_wl) then
        safeSleep(300)
        if CFG.wl_make_public then
            wrenchTile(pWL.x, pWL.y)
            safeSleep(300)
            if sendPacket then
                pcall(sendPacket, 2, string.format("action|dialog_return\ndialog_name|lock_edit\ntilex|%d|\ntiley|%d|\ncheckbox_public|1\ncheckbox_disable_music|0\ntempo|100\ncheckbox_disable_music_render|0\ncheckbox_set_as_home_world|0\nminimum_entry_level|1", pWL.x, pWL.y))
            end
            safeSleep(300)
        end
    end

    addLog("`2[Proteksi Selesai] `wStruktur proteksi kunci berhasil dipasang secara optimal!")
    return true
end

-- ============================================================================
-- 10. VERTICAL WATER ELEVATOR ENGINE
-- ============================================================================
local function buildWaterColumn()
    if not CFG.enable_water_column then
        addLog("`e[Elevator Air] `0Pemasangan kolom air dilewati (dinonaktifkan oleh user).")
        return true
    end

    addLog(string.format("`9[Elevator Air] `0Memasang kolom air di X=%d (Y=%d s/d %d)...", CFG.water_x, CFG.water_start_y, CFG.water_end_y))
    local wx = CFG.water_x
    for wy = CFG.water_start_y, CFG.water_end_y do
        if not STATE.running or STATE.paused then break end
        local ok, t = pcall(getTile, wx, wy)
        if ok and t and t.fg ~= CFG.water_item_id and t.fg ~= 8 and t.fg ~= 6 then
            if getInvCount(CFG.water_item_id) <= 0 then
                addLog("`e[Item Air Habis] `0Item air habis di tas. Melanjutkan konstruksi baris...")
                break
            end
            placeTileAt(wx, wy, CFG.water_item_id)
        end
    end
    addLog("`2[Elevator Air] `wPemasangan elevator air vertikal selesai.")
    return true
end

-- ============================================================================
-- 11. HORIZONTAL ROW PLACEMENT ENGINE
-- ============================================================================
local function placeSoilRows(onNeedRestockCallback)
    addLog(string.format("`9[Konstruksi] `0Memulai penempatan baris block (ID: %d - %s)...", CFG.block_id, getItemNameSafe(CFG.block_id)))
    local rowIdx = 0

    applyCheatToggles()

    for y = CFG.row_start_y, CFG.row_end_y, CFG.row_step do
        if not STATE.running or STATE.paused then break end
        rowIdx = rowIdx + 1
        STATE.active_row = y

        -- Bot terbang di koridor udara kosong persis di atas baris (y - 1)
        local standY = (y - 1 >= 1) and (y - 1) or (y + 1)
        applyCheatToggles()

        local startX, endX, stepX
        if rowIdx % 2 == 1 then
            startX, endX, stepX = CFG.row_start_x, CFG.row_end_x, 1
        else
            startX, endX, stepX = CFG.row_end_x, CFG.row_start_x, -1
        end

        -- Pindah ke awal koridor baris
        moveSafeTo(startX, standY)

        local x = startX
        while (stepX > 0 and x <= endX) or (stepX < 0 and x >= endX) do
            if not STATE.running or STATE.paused then break end
            STATE.active_col = x

            local ok, t = pcall(getTile, x, y)
            if ok and t and t.fg ~= CFG.block_id and t.fg ~= 8 and t.fg ~= 6 then
                local curCount = getInvCount(CFG.block_id)
                if curCount < CFG.restock_threshold then
                    addLog(string.format("`e[Restock Diperlukan] `0Sisa block di tas (%d) < batas (%d). Menuju gudang...", curCount, CFG.restock_threshold))
                    if onNeedRestockCallback then
                        local okRestock = onNeedRestockCallback(x, standY)
                        if not okRestock then
                            addLog("`4[Restock Gagal] `oGagal mengambil block dari gudang. Berhenti.")
                            return false
                        end
                        applyCheatToggles()
                        moveSafeTo(x, standY)
                    end
                end

                local px, py = getPlayerPos()
                if math.abs(px - x) > 1 or py ~= standY then
                    moveSafeTo(x, standY)
                end

                sendRawAction(x, y, CFG.block_id)
                local d = math.floor(CFG.delay_place * (0.85 + math.random() * 0.3))
                safeSleep(d)

                STATE.total_placed_blocks = STATE.total_placed_blocks + 1
                if STATE.total_placed_blocks % 50 == 0 then
                    updatePowerStatusList()
                end
            end

            x = x + stepX
        end
    end

    addLog(string.format("`2[Place Rows Selesai] `wTotal block terpasang: %d", STATE.total_placed_blocks))
    updatePowerStatusList()
    return true
end

-- ============================================================================
-- 12. BLAST & RANDOM WORLD SEARCH ENGINE
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
                applyCheatToggles()
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
                return false
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
    local targetX, targetY = px + 1, py
    placeTileAt(targetX, targetY, CFG.blast_item_id)
    safeSleep(500)

    if sendPacket then
        pcall(sendPacket, 2, "action|dialog_return\ndialog_name|use_blast\nbuttonClicked|blast")
        pcall(sendPacket, 2, "action|dialog_return\ndialog_name|blast_confirm\nbuttonClicked|yes")
    end

    addLog("`9[Auto Blast] `0Menunggu proses blast selesai (10 detik)...")
    safeSleep(10000)
    return true
end

local function recordBlastedWorld(worldName, doorID)
    worldName = (worldName or ""):upper()
    doorID = (doorID or "")
    if worldName == "" or worldName == "EXIT" then return end
    local exists = false
    for _, w in ipairs(CFG.farm_world_list) do
        if (w.name or ""):upper() == worldName then
            exists = true
            break
        end
    end
    if not exists then
        table.insert(CFG.farm_world_list, { name = worldName, door = doorID, done = false })
        savePrefs(CFG)
        saveWorldsToFile()
        updateWorldDisplayList()
        addLog(string.format("`2[World Blast Tersimpan] `wWorld %s otomatis masuk ke daftar antrean!", worldName))
        notifyUser("World Blast tersimpan: " .. worldName)
    end
end

-- ============================================================================
-- 13. MULTI-STORAGE RESTOCK ENGINE
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

            local objs = (getObjects and getObjects()) or (getBot and getBot().getWorld and getBot():getWorld().getObjects and getBot():getWorld():getObjects())
            if objs then
                for _, obj in pairs(objs) do
                    if obj.id == CFG.block_id then
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
-- 14. MAIN PROCESS DISPATCHER
-- ============================================================================
local function runSingleFarmWorld(worldName, doorID)
    STATE.current_world = worldName
    STATE.current_door = doorID or ""
    STATE.status_text = "Mempersiapkan: " .. worldName
    updatePowerStatusList()
    addLog(string.format("`2========================================`0"))
    addLog(string.format("`2[Mulai World] `wMemproses Farm World: %s", worldName))

    if not warpToWorld(worldName, doorID) then
        addLog(string.format("`4[Gagal Warp] `oTidak dapat memasuki world %s", worldName))
        return false
    end

    if CFG.auto_use_blast then
        if not isWorldCleanAndUnowned() then
            addLog("`e[World Terkunci] `0World ini sudah ada pemiliknya. Melewati...")
            return false
        end
        local okBlast = executeWorldBlast()
        if okBlast then
            recordBlastedWorld(worldName, doorID)
        end
    end

    buildLockEnclosure()
    buildWaterColumn()

    local okRows = placeSoilRows(function(resX, resY)
        return restockFromStorage(resX, resY)
    end)

    if okRows then
        STATE.total_worlds_completed = STATE.total_worlds_completed + 1
        addLog(string.format("`2[World Selesai] `w%s sukses dibangun 100%%!", worldName))
        sendWebhookNotification("🌱 Farm World Selesai", string.format("World: **%s**\nTotal Block: **%d**\nTotal World Selesai: **%d**", worldName, STATE.total_placed_blocks, STATE.total_worlds_completed))
        updatePowerStatusList()
        return true
    end
    return false
end

local function autoSoilMainLoop()
    STATE.running = true
    STATE.paused = false
    addLog("`2[Bot Dimulai] `wAuto Soil Builder resmi berjalan.")
    updatePowerStatusList()

    if CFG.world_mode == "RANDOM" then
        addLog(string.format("`9[Mode Random] `0Mencari %d world acak...", CFG.random_target_count))
        local found = 0
        while STATE.running and found < CFG.random_target_count do
            local rndWorld = generateRandomWorldName(CFG.random_letter_count, CFG.random_with_number, CFG.random_prefix)
            addLog(string.format("`9[Scan World] `0Memeriksa world acak: %s", rndWorld))
            if runSingleFarmWorld(rndWorld, CFG.farm_door_id) then
                found = found + 1
                local foundEntry = false
                for _, w in ipairs(CFG.farm_world_list) do
                    if (w.name or ""):upper() == rndWorld:upper() then
                        w.done = true
                        foundEntry = true
                        break
                    end
                end
                if not foundEntry then
                    table.insert(CFG.farm_world_list, { name = rndWorld, door = CFG.farm_door_id, done = true })
                end
                savePrefs(CFG)
                saveWorldsToFile()
                updateWorldDisplayList()
            end
            safeSleep(1500)
        end
    else
        if #CFG.farm_world_list == 0 then
            addLog("`4[Daftar Kosong] `oDaftar Farm World kosong! Tambahkan world di Tab 1 atau klik Muat dari Download.")
            STATE.running = false
            updatePowerStatusList()
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
                    updateWorldDisplayList()
                end
            end
            safeSleep(2000)
        end
    end

    STATE.running = false
    STATE.status_text = "SELESAI"
    addLog("`2[Semua Selesai] `wSeluruh world telah berhasil diselesaikan!")
    updatePowerStatusList()
    notifyUser("Auto Soil Builder Selesai!")
end

local function startSoilBot()
    if STATE.running then return end
    applyCheatToggles()
    STATE.running = true
    STATE.paused  = false
    if editToggle then pcall(editToggle, "as_run_power", true) end
    updatePowerStatusList()

    local okCoro, errCoro = pcall(runCoroutine, function()
        autoSoilMainLoop()
    end)
    if not okCoro then
        STATE.running = false
        STATE.paused = false
        if editToggle then pcall(editToggle, "as_run_power", false) end
        addLog("`4[Error Coroutine] `o" .. tostring(errCoro))
        updatePowerStatusList()
        if sendNotification then pcall(sendNotification, "Gagal mulai bot: " .. tostring(errCoro)) end
    end
end

local function stopSoilBot()
    STATE.running = false
    STATE.paused = false
    if editToggle then pcall(editToggle, "as_run_power", false) end
    addLog("`4[Berhenti] `0Bot dihentikan oleh user.")
    updatePowerStatusList()
end

-- ============================================================================
-- 15. UNIFIED DIALOG MANAGERS (WORLD FARM & GUDANG)
-- ============================================================================
local openUnifiedWorldManager
local openUnifiedStorageManager
local openEditWorldEntryDialog
local openEditStorageEntryDialog

local function safeSendRawDialog(dText)
    if not dText or dText == "" then return false end
    if growtopia and type(growtopia.sendDialog) == "function" then
        local ok = pcall(growtopia.sendDialog, dText)
        if ok then return true end
    end
    if sendVariant then
        local ok1 = pcall(sendVariant, { v1 = "OnDialogRequest", v2 = dText })
        if ok1 then return true end
        local ok2 = pcall(sendVariant, { v0 = "OnDialogRequest", v1 = dText })
        if ok2 then return true end
    end
    if sendDialog then
        local ok = pcall(sendDialog, dText)
        if ok then return true end
    end
    return false
end

local function parseWorldEntryToken(token)
    if not token or token == "" then return nil end
    local w, d = token:match("^([^:]+):?(.*)$")
    if not w or w == "" then
        w, d = token:match("^([^|]+)|?(.*)$")
    end
    if not w or w == "" then w = token d = "" end
    w = w:gsub("%s+", ""):upper()
    d = (d or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if w == "" then return nil end
    return { name = w, door = d, done = false }
end

local function parseAndValidateWorldBatch(rawText, replaceMode)
    if type(rawText) ~= "string" or rawText == "" then
        return 0, 0, 0, "Teks kosong! Silakan tempel daftar world terlebih dahulu."
    end
    local cleaned = rawText:gsub("[\"\'%[%]%(%)]", " "):gsub("\t", " ")
    local tokens = {}
    for part in cleaned:gmatch("[^\r\n;,]+") do
        local trimmed = part:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" then table.insert(tokens, trimmed) end
    end
    if #tokens == 0 then
        return 0, 0, 0, "Tidak ada data world yang valid ditemukan."
    end

    local candidateList = {}
    local seen = {}
    local dups = 0
    local ignored = 0

    for _, token in ipairs(tokens) do
        local parsed = parseWorldEntryToken(token)
        if parsed and parsed.name ~= "" then
            local validName = parsed.name:match("^([%w_]+)$")
            if validName and #validName >= 1 and #validName <= 24 then
                parsed.name = validName:upper()
                if seen[parsed.name] then
                    dups = dups + 1
                else
                    seen[parsed.name] = true
                    table.insert(candidateList, parsed)
                end
            else
                ignored = ignored + 1
            end
        else
            ignored = ignored + 1
        end
    end

    if #candidateList == 0 then
        return 0, dups, ignored, "Tidak ada world valid yang dapat ditambahkan."
    end

    local added = 0
    if replaceMode then
        CFG.farm_world_list = {}
        for _, e in ipairs(candidateList) do
            table.insert(CFG.farm_world_list, e)
            added = added + 1
        end
    else
        local existingMap = {}
        for _, e in ipairs(CFG.farm_world_list) do
            existingMap[e.name] = true
        end
        for _, e in ipairs(candidateList) do
            if not existingMap[e.name] then
                existingMap[e.name] = true
                table.insert(CFG.farm_world_list, e)
                added = added + 1
            else
                dups = dups + 1
            end
        end
    end

    savePrefs(CFG)
    saveWorldsToFile()
    updateWorldDisplayList()
    local summary = string.format("Berhasil input %d Farm World! (Duplikat: %d | Dilewati: %d | Total: %d)",
        added, dups, ignored, #CFG.farm_world_list)
    return added, dups, ignored, summary
end

local function parseAndValidateStorageBatch(rawText, replaceMode)
    if type(rawText) ~= "string" or rawText == "" then
        return 0, 0, 0, "Teks kosong! Silakan tempel daftar gudang terlebih dahulu."
    end
    local cleaned = rawText:gsub("[\"\'%[%]%(%)]", " "):gsub("\t", " ")
    local tokens = {}
    for part in cleaned:gmatch("[^\r\n;,]+") do
        local trimmed = part:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" then table.insert(tokens, trimmed) end
    end
    if #tokens == 0 then
        return 0, 0, 0, "Tidak ada data gudang yang valid ditemukan."
    end

    local candidateList = {}
    local seen = {}
    local dups = 0
    local ignored = 0

    for _, token in ipairs(tokens) do
        local parsed = parseWorldEntryToken(token)
        if parsed and parsed.name ~= "" then
            local validName = parsed.name:match("^([%w_]+)$")
            if validName and #validName >= 1 and #validName <= 24 then
                parsed.name = validName:upper()
                if seen[parsed.name] then
                    dups = dups + 1
                else
                    seen[parsed.name] = true
                    table.insert(candidateList, { name = parsed.name, door = parsed.door })
                end
            else
                ignored = ignored + 1
            end
        else
            ignored = ignored + 1
        end
    end

    if #candidateList == 0 then
        return 0, dups, ignored, "Tidak ada gudang valid yang dapat ditambahkan."
    end

    local added = 0
    if replaceMode then
        CFG.storage_list = {}
        for _, e in ipairs(candidateList) do
            table.insert(CFG.storage_list, e)
            added = added + 1
        end
    else
        local existingMap = {}
        for _, e in ipairs(CFG.storage_list) do
            existingMap[e.name] = true
        end
        for _, e in ipairs(candidateList) do
            if not existingMap[e.name] then
                existingMap[e.name] = true
                table.insert(CFG.storage_list, e)
                added = added + 1
            else
                dups = dups + 1
            end
        end
    end

    savePrefs(CFG)
    saveStoragesToFile()
    updateStorageDisplayList()
    local summary = string.format("Berhasil input %d Gudang! (Duplikat: %d | Dilewati: %d | Total: %d)",
        added, dups, ignored, #CFG.storage_list)
    return added, dups, ignored, summary
end

openUnifiedWorldManager = function(fmt)
    fmt = fmt or "colon"
    local copyLines = {}
    for _, w in ipairs(CFG.farm_world_list) do
        local d = (w.door and w.door ~= "") and w.door or ""
        if fmt == "colon" then
            table.insert(copyLines, (d ~= "") and (w.name .. ":" .. d) or w.name)
        elseif fmt == "pipe" then
            table.insert(copyLines, (d ~= "") and (w.name .. "|" .. d) or w.name)
        else
            table.insert(copyLines, w.name)
        end
    end
    local rawCopy = table.concat(copyLines, "\n")
    local rawBoxText = table.concat(copyLines, ", ")
    if ImGui and ImGui.SetClipboardText and rawCopy ~= "" then
        pcall(ImGui.SetClipboardText, rawCopy)
    end

    local dLines = {
        "set_default_color|`o",
        "add_quick_exit|",
        string.format("add_label_with_icon|big|`wKelola Farm World (%d World)``|left|1336|", #CFG.farm_world_list),
        "add_textbox|`oSalin antrean, tempel banyak world sekaligus, atau edit/hapus di bawah.|left|",
        "add_spacer|small|",

        -- Bagian 1: Salin Semua World
        "add_textbox|`2[1. Salin Antrean World ke Clipboard]|left|",
        string.format("add_text_input|as_wcopy_box|Salin Antrean|%s|9999|", rawBoxText),
        "add_button|boren_btn_wfmt_colon|Format Titik Dua (:)|noflags|0|0|",
        "add_button|boren_btn_wfmt_pipe|Format Garis (|)|noflags|0|0|",
        "add_button|boren_btn_wfmt_name|Hanya Nama World|noflags|0|0|",
        "add_spacer|small|",

        -- Bagian 2: Tempel Banyak / Tambah World
        "add_textbox|`2[2. Tempel / Tambah World ke Antrean]|left|",
        "add_textbox|`eTempel 1 atau banyak world (Format: WORLD:ID / WORLD|ID / WORLD). Bebas koma/enter.|left|",
        "add_text_input|boren_wpaste_raw|Tempel World di sini:||9999|",
        "add_checkbox|boren_wpaste_replace|Ganti semua antrean (Replace)|0|",
        "add_button|boren_submit_wpaste|`2+ Tempel / Tambah ke Antrean|noflags|0|0|",
        "add_spacer|small|",

        -- Bagian 3: Tambah 1 World Manual
        "add_textbox|`2[3. Tambah 1 World Manual]|left|",
        "add_text_input|as_dlg_add_world|Nama World:||24|",
        "add_text_input|as_dlg_add_door|Door ID (Opsional):||24|",
        "add_button|as_dlg_btn_add|➕ Tambah 1 World|noflags|0|0|",
        "add_spacer|small|",

        -- Bagian 4: Daftar World & Edit / Hapus
        string.format("add_textbox|`2[4. Daftar World Saat Ini (%d World)]|left|", #CFG.farm_world_list)
    }

    if #CFG.farm_world_list == 0 then
        table.insert(dLines, "add_textbox|`4(Antrean Farm World masih kosong. Silakan tempel di atas!)|left|")
    else
        for i, w in ipairs(CFG.farm_world_list) do
            local st = w.done and "`2[DONE]" or "`9[ANTRI]"
            local d = (w.door and w.door ~= "") and w.door or "-"
            table.insert(dLines, string.format("add_textbox|`w%d. `9%s `o[Door: %s] %s|left|", i, w.name, d, st))
            table.insert(dLines, string.format("add_button|boren_wedit_%d|Edit|noflags|0|0|", i))
            table.insert(dLines, string.format("add_button|boren_whapus_%d|Hapus|noflags|0|0|", i))
            table.insert(dLines, "add_spacer|small|")
        end
    end

    table.insert(dLines, "add_button|as_dlg_btn_clear|`4🗑️ Kosongkan Semua World|noflags|0|0|")
    table.insert(dLines, "add_spacer|small|")
    table.insert(dLines, "end_dialog|boren_soil_world_mgr|Tutup||")

    return safeSendRawDialog(table.concat(dLines, "\n"))
end

openUnifiedStorageManager = function(fmt)
    fmt = fmt or "colon"
    local copyLines = {}
    for _, s in ipairs(CFG.storage_list) do
        local d = (s.door and s.door ~= "") and s.door or ""
        if fmt == "colon" then
            table.insert(copyLines, (d ~= "") and (s.name .. ":" .. d) or s.name)
        elseif fmt == "pipe" then
            table.insert(copyLines, (d ~= "") and (s.name .. "|" .. d) or s.name)
        else
            table.insert(copyLines, s.name)
        end
    end
    local rawCopy = table.concat(copyLines, "\n")
    local rawBoxText = table.concat(copyLines, ", ")
    if ImGui and ImGui.SetClipboardText and rawCopy ~= "" then
        pcall(ImGui.SetClipboardText, rawCopy)
    end

    local dLines = {
        "set_default_color|`o",
        "add_quick_exit|",
        string.format("add_label_with_icon|big|`wKelola Gudang Block (%d Gudang)``|left|242|", #CFG.storage_list),
        "add_textbox|`oSalin daftar gudang, tempel banyak gudang, atau edit/hapus di bawah.|left|",
        "add_spacer|small|",

        -- Bagian 1: Salin Semua Gudang
        "add_textbox|`2[1. Salin Daftar Gudang ke Clipboard]|left|",
        string.format("add_text_input|as_stcopy_box|Salin Gudang|%s|9999|", rawBoxText),
        "add_button|boren_btn_stfmt_colon|Format Titik Dua (:)|noflags|0|0|",
        "add_button|boren_btn_stfmt_pipe|Format Garis (|)|noflags|0|0|",
        "add_button|boren_btn_stfmt_name|Hanya Nama Gudang|noflags|0|0|",
        "add_spacer|small|",

        -- Bagian 2: Tempel Banyak Gudang
        "add_textbox|`2[2. Tempel / Tambah Gudang ke Daftar]|left|",
        "add_textbox|`eTempel 1 atau banyak gudang (Format: GUDANG:ID / GUDANG|ID / GUDANG).|left|",
        "add_text_input|boren_stpaste_raw|Tempel Gudang di sini:||9999|",
        "add_checkbox|boren_stpaste_replace|Ganti semua gudang (Replace)|0|",
        "add_button|boren_submit_stpaste|`2+ Tempel / Tambah Gudang|noflags|0|0|",
        "add_spacer|small|",

        -- Bagian 3: Tambah 1 Gudang Manual
        "add_textbox|`2[3. Tambah 1 Gudang Manual]|left|",
        "add_text_input|as_dlg_add_stor|Nama Gudang:||24|",
        "add_text_input|as_dlg_add_stor_door|Door ID Gudang:||24|",
        "add_button|as_dlg_btn_add_stor|➕ Tambah 1 Gudang|noflags|0|0|",
        "add_spacer|small|",

        -- Bagian 4: Daftar Gudang Saat Ini
        string.format("add_textbox|`2[4. Daftar Gudang Saat Ini (%d Gudang)]|left|", #CFG.storage_list)
    }

    if #CFG.storage_list == 0 then
        table.insert(dLines, "add_textbox|`4(Daftar Gudang masih kosong. Silakan tempel di atas!)|left|")
    else
        for i, s in ipairs(CFG.storage_list) do
            local d = (s.door and s.door ~= "") and s.door or "-"
            table.insert(dLines, string.format("add_textbox|`w%d. `9%s `o[Door: %s]|left|", i, s.name, d))
            table.insert(dLines, string.format("add_button|boren_stedit_%d|Edit|noflags|0|0|", i))
            table.insert(dLines, string.format("add_button|boren_sthapus_%d|Hapus|noflags|0|0|", i))
            table.insert(dLines, "add_spacer|small|")
        end
    end

    table.insert(dLines, "add_button|as_dlg_btn_clear_stor|`4🗑️ Kosongkan Semua Gudang|noflags|0|0|")
    table.insert(dLines, "add_spacer|small|")
    table.insert(dLines, "end_dialog|boren_soil_stor_mgr|Tutup||")

    return safeSendRawDialog(table.concat(dLines, "\n"))
end

openEditWorldEntryDialog = function(idx)
    idx = tonumber(idx) or 0
    local w = CFG.farm_world_list[idx]
    if not w then return false end
    local dLines = {
        "set_default_color|`o",
        "add_quick_exit|",
        string.format("add_label_with_icon|big|`wEdit Farm World #%d``|left|1336|", idx),
        "add_textbox|`oUbah nama world atau Door ID di bawah ini:|left|",
        "add_spacer|small|",
        string.format("add_text_input|boren_ed_wname|Nama World|%s|32|", w.name or ""),
        string.format("add_text_input|boren_ed_wdoor|Door ID (Kosong = White Door)|%s|32|", w.door or ""),
        "add_spacer|small|",
        string.format("add_button|boren_save_wedit_%d|`2Simpan Perubahan|noflags|0|0|", idx),
        "end_dialog|boren_soil_edit_w_dlg|Batal||"
    }
    return safeSendRawDialog(table.concat(dLines, "\n"))
end

openEditStorageEntryDialog = function(idx)
    idx = tonumber(idx) or 0
    local s = CFG.storage_list[idx]
    if not s then return false end
    local dLines = {
        "set_default_color|`o",
        "add_quick_exit|",
        string.format("add_label_with_icon|big|`wEdit Gudang Block #%d``|left|242|", idx),
        "add_textbox|`oUbah nama gudang atau Door ID di bawah ini:|left|",
        "add_spacer|small|",
        string.format("add_text_input|boren_ed_sname|Nama Gudang|%s|32|", s.name or ""),
        string.format("add_text_input|boren_ed_sdoor|Door ID (Kosong = White Door)|%s|32|", s.door or ""),
        "add_spacer|small|",
        string.format("add_button|boren_save_stedit_%d|`2Simpan Perubahan|noflags|0|0|", idx),
        "end_dialog|boren_soil_edit_s_dlg|Batal||"
    }
    return safeSendRawDialog(table.concat(dLines, "\n"))
end

local function parseDialogReturnFields(pkt)
    local fields = {}
    for line in pkt:gmatch("[^\r\n]+") do
        local k, v = line:match("^([^|]+)|(.*)$")
        if k then fields[k] = v end
    end
    return fields
end

local function onSendPacketDialogHook(ptype, pkt)
    if type(pkt) ~= "string" or not pkt:find("action|dialog_return", 1, true) then return false end
    local fields = parseDialogReturnFields(pkt)
    local dName = fields.dialog_name or ""
    local btn = fields.buttonClicked or ""

    if dName == "boren_soil_world_mgr" then
        if btn == "boren_btn_wfmt_colon" then
            openUnifiedWorldManager("colon")
            return true
        elseif btn == "boren_btn_wfmt_pipe" then
            openUnifiedWorldManager("pipe")
            return true
        elseif btn == "boren_btn_wfmt_name" then
            openUnifiedWorldManager("name_only")
            return true
        elseif btn == "boren_submit_wpaste" then
            local raw = pkt:match("boren_wpaste_raw|(.-)\nboren_wpaste_replace|")
                or pkt:match("boren_wpaste_raw|(.-)\nbuttonClicked|")
                or fields.boren_wpaste_raw or ""
            local isReplace = (fields.boren_wpaste_replace == "1")
            local added, dups, ign, summary = parseAndValidateWorldBatch(raw, isReplace)
            addLog("[Quick Paste Farm] " .. summary)
            notifyUser(summary)
            openUnifiedWorldManager()
            return true
        elseif btn == "as_dlg_btn_add" then
            local nw = tostring(fields.as_dlg_add_world or ""):gsub("%s+", ""):upper()
            local nd = tostring(fields.as_dlg_add_door or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if nw ~= "" then
                table.insert(CFG.farm_world_list, { name = nw, door = nd, done = false })
                savePrefs(CFG)
                saveWorldsToFile()
                updateWorldDisplayList()
                addLog(string.format("`2[Tambah World] `w%s [Door: %s] ditambahkan.", nw, (nd ~= "" and nd or "-")))
                notifyUser("World " .. nw .. " ditambahkan!")
            else
                notifyUser("Isi nama world terlebih dahulu!")
            end
            openUnifiedWorldManager()
            return true
        elseif btn == "as_dlg_btn_clear" then
            CFG.farm_world_list = {}
            savePrefs(CFG)
            saveWorldsToFile()
            updateWorldDisplayList()
            addLog("`4[Bersihkan World] `oDaftar world dikosongkan.")
            notifyUser("Daftar world dikosongkan!")
            openUnifiedWorldManager()
            return true
        end

        local editIdx = btn:match("^boren_wedit_(%d+)$")
        if editIdx then
            openEditWorldEntryDialog(tonumber(editIdx))
            return true
        end

        local hapusIdx = btn:match("^boren_whapus_(%d+)$")
        if hapusIdx then
            local idx = tonumber(hapusIdx)
            if idx and CFG.farm_world_list[idx] then
                local removed = table.remove(CFG.farm_world_list, idx)
                savePrefs(CFG)
                saveWorldsToFile()
                updateWorldDisplayList()
                addLog(string.format("`4[Hapus World] `o%s dihapus dari antrean.", removed.name))
                notifyUser("Dihapus: " .. removed.name)
            end
            openUnifiedWorldManager()
            return true
        end
        return true

    elseif dName == "boren_soil_stor_mgr" then
        if btn == "boren_btn_stfmt_colon" then
            openUnifiedStorageManager("colon")
            return true
        elseif btn == "boren_btn_stfmt_pipe" then
            openUnifiedStorageManager("pipe")
            return true
        elseif btn == "boren_btn_stfmt_name" then
            openUnifiedStorageManager("name_only")
            return true
        elseif btn == "boren_submit_stpaste" then
            local raw = pkt:match("boren_stpaste_raw|(.-)\nboren_stpaste_replace|")
                or pkt:match("boren_stpaste_raw|(.-)\nbuttonClicked|")
                or fields.boren_stpaste_raw or ""
            local isReplace = (fields.boren_stpaste_replace == "1")
            local added, dups, ign, summary = parseAndValidateStorageBatch(raw, isReplace)
            addLog("[Quick Paste Gudang] " .. summary)
            notifyUser(summary)
            openUnifiedStorageManager()
            return true
        elseif btn == "as_dlg_btn_add_stor" then
            local ns = tostring(fields.as_dlg_add_stor or ""):gsub("%s+", ""):upper()
            local nd = tostring(fields.as_dlg_add_stor_door or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if ns ~= "" then
                table.insert(CFG.storage_list, { name = ns, door = nd })
                savePrefs(CFG)
                saveStoragesToFile()
                updateStorageDisplayList()
                addLog(string.format("`2[Tambah Gudang] `w%s [Door: %s] ditambahkan.", ns, (nd ~= "" and nd or "-")))
                notifyUser("Gudang " .. ns .. " ditambahkan!")
            else
                notifyUser("Isi nama gudang terlebih dahulu!")
            end
            openUnifiedStorageManager()
            return true
        elseif btn == "as_dlg_btn_clear_stor" then
            CFG.storage_list = {}
            savePrefs(CFG)
            saveStoragesToFile()
            updateStorageDisplayList()
            addLog("`4[Bersihkan Gudang] `oDaftar gudang dikosongkan.")
            notifyUser("Daftar gudang dikosongkan!")
            openUnifiedStorageManager()
            return true
        end

        local editIdx = btn:match("^boren_stedit_(%d+)$")
        if editIdx then
            openEditStorageEntryDialog(tonumber(editIdx))
            return true
        end

        local hapusIdx = btn:match("^boren_sthapus_(%d+)$")
        if hapusIdx then
            local idx = tonumber(hapusIdx)
            if idx and CFG.storage_list[idx] then
                local removed = table.remove(CFG.storage_list, idx)
                savePrefs(CFG)
                saveStoragesToFile()
                updateStorageDisplayList()
                addLog(string.format("`4[Hapus Gudang] `o%s dihapus dari gudang.", removed.name))
                notifyUser("Dihapus: " .. removed.name)
            end
            openUnifiedStorageManager()
            return true
        end
        return true

    elseif dName == "boren_soil_edit_w_dlg" then
        local saveIdx = btn:match("^boren_save_wedit_(%d+)$")
        if saveIdx then
            local idx = tonumber(saveIdx)
            if idx and CFG.farm_world_list[idx] then
                local newName = tostring(fields.boren_ed_wname or ""):gsub("%s+", ""):upper()
                local newDoor = tostring(fields.boren_ed_wdoor or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if newName ~= "" then
                    CFG.farm_world_list[idx].name = newName
                    CFG.farm_world_list[idx].door = newDoor
                    savePrefs(CFG)
                    saveWorldsToFile()
                    updateWorldDisplayList()
                    addLog(string.format("`2[Edit World #%d] `w%s [Door: %s]", idx, newName, (newDoor ~= "" and newDoor or "-")))
                    notifyUser("World diperbarui: " .. newName)
                end
            end
            openUnifiedWorldManager()
            return true
        end
        return true

    elseif dName == "boren_soil_edit_s_dlg" then
        local saveIdx = btn:match("^boren_save_stedit_(%d+)$")
        if saveIdx then
            local idx = tonumber(saveIdx)
            if idx and CFG.storage_list[idx] then
                local newName = tostring(fields.boren_ed_sname or ""):gsub("%s+", ""):upper()
                local newDoor = tostring(fields.boren_ed_sdoor or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if newName ~= "" then
                    CFG.storage_list[idx].name = newName
                    CFG.storage_list[idx].door = newDoor
                    savePrefs(CFG)
                    saveStoragesToFile()
                    updateStorageDisplayList()
                    addLog(string.format("`2[Edit Gudang #%d] `w%s [Door: %s]", idx, newName, (newDoor ~= "" and newDoor or "-")))
                    notifyUser("Gudang diperbarui: " .. newName)
                end
            end
            openUnifiedStorageManager()
            return true
        end
        return true
    end

    return false
end

-- ============================================================================
-- 16. NATIVE GROWLAUNCHER UI BUILDER (STANDAR RESMI GROWLAUNCHER APK)
-- ============================================================================
local function createNativeUI(subName, iconName)
    if UserInterface and UserInterface.new then
        return UserInterface.new(subName, iconName)
    end
    local ui = { sub_name = subName, icon = iconName, menu = {} }
    function ui:addLabelApp(text, icon) table.insert(self.menu, { type = "labelapp", text = text, icon = icon or "" }) return self end
    function ui:addLabel(text) table.insert(self.menu, { type = "label", text = text }) return self end
    function ui:addDivider() table.insert(self.menu, { type = "divider" }) return self end
    function ui:addToggle(text, default, alias, autosave) table.insert(self.menu, { type = "toggle", text = text, default = default == true, alias = alias, autosave = autosave == true }) return self end
    function ui:addToggleButton(text, default, alias) table.insert(self.menu, { type = "toggle_button", text = text, default = default == true, alias = alias }) return self end
    function ui:addButton(text, alias) table.insert(self.menu, { type = "button", text = text, alias = alias }) return self end
    function ui:addInputString(text, default, label, placeholder, icon, alias) table.insert(self.menu, { type = "input_string", text = text, default = default or "", label = label or "Text", placeholder = placeholder or "", icon = icon or "", alias = alias }) return self end
    function ui:addInputInt(text, default, label, placeholder, icon, alias) table.insert(self.menu, { type = "input_int", text = text, default = tostring(default or "0"), label = label or "Value", placeholder = placeholder or "0", icon = icon or "", alias = alias }) return self end
    function ui:addSlider(text, minVal, maxVal, defaultVal, stepVal, useDot, alias) table.insert(self.menu, { type = "slider", text = text, min = minVal, max = maxVal, default = defaultVal, step = stepVal, use_dot = useDot == true, alias = alias }) return self end
    function ui:addTooltip(text, supportText, icon, background) table.insert(self.menu, { type = "tooltip", text = text, support_text = supportText or "", icon = icon or "Info", background = background == true }) return self end
    function ui:addItemPicker(text, item, default, alias) table.insert(self.menu, { type = "item_picker", text = text, item = item or "Blank", default = tostring(default or "0"), alias = alias }) return self end
    function ui:addDisplayList(text, displayType, alias) table.insert(self.menu, { type = "display_list", text = text, default = displayType or "Default", alias = alias }) return self end
    function ui:generateJSON()
        return jsonEncode({ sub_name = self.sub_name, icon = self.icon, menu = self.menu })
    end
    return ui
end

local function registerNativeSoilUI()
    if not addCategory or not addIntoModule then
        addLog("`4[UI Warning] `oFungsi addCategory / addIntoModule tidak terdeteksi.")
        return
    end

    -- Tab 1: Dashboard & World Farm
    local uiWorld = createNativeUI("1. Dashboard & World", "PlayArrow")
    uiWorld:addLabelApp("Boren Farm Builder", "Grass")
    uiWorld:addToggleButton("▶ Mulai Bot", false, "as_run_power")
    uiWorld:addButton("■ Hentikan Bot", "as_btn_stop")
    uiWorld:addToggle("Jeda Bot", false, "as_pause_toggle", false)
    uiWorld:addDisplayList("Status Operasi", "Default", "as_power_status_list")
    uiWorld:addDivider()
    uiWorld:addLabel("Daftar Antrean World:")
    uiWorld:addInputString("Nama World", "", "World", "WORLD1", "Public", "as_input_add_world")
    uiWorld:addInputString("Door ID (Opsional)", "", "Door ID", "Kosong = White Door", "DoorFront", "as_input_add_door")
    uiWorld:addButton("➕ Tambah World ke Antrean", "as_btn_add_world")
    uiWorld:addButton("📍 Tambah World Aktif", "as_btn_add_cur_world")
    uiWorld:addButton("📋 Kelola Antrean World", "as_btn_manage_worlds")
    uiWorld:addButton("🗑️ Kosongkan Antrean", "as_btn_clear_worlds")
    uiWorld:addDivider()
    uiWorld:addLabel("Penyimpanan File Cadangan (Download):")
    uiWorld:addButton("📥 Simpan Antrean ke File", "as_btn_save_worlds")
    uiWorld:addButton("📤 Muat Antrean dari File", "as_btn_load_worlds")
    uiWorld:addDisplayList("Daftar Antrean World", "Default", "as_world_display_list")
    uiWorld:addDivider()
    uiWorld:addLabel("Pencarian World Otomatis:")
    uiWorld:addToggle("Mode Acak World", CFG.world_mode == "RANDOM", "as_chk_mode_random", true)
    uiWorld:addSlider("Panjang Karakter", 4, 12, CFG.random_letter_count, 1, false, "as_in_rnd_len")
    uiWorld:addToggle("Sertakan Angka", CFG.random_with_number, "as_chk_rnd_num", true)
    uiWorld:addInputString("Awalan (Prefix)", CFG.random_prefix, "Prefix", "Kosongkan jika acak", "Label", "as_in_rnd_prefix")
    uiWorld:addInputInt("Target Jumlah World", tostring(CFG.random_target_count), "Target", "20", "FormatListNumbered", "as_in_rnd_target")
    uiWorld:addDivider()
    uiWorld:addLabel("Fitur World Blast:")
    uiWorld:addToggle("Gunakan Blast Otomatis", CFG.auto_use_blast, "as_chk_auto_blast", true)
    uiWorld:addInputInt("ID Item Blast", tostring(CFG.blast_item_id), "Blast ID", "1336 (World) / 2810 (Cave)", "Tag", "as_in_blast_id")

    -- Tab 2: Proteksi & Kunci
    local uiLock = createNativeUI("2. Proteksi & Kunci", "Lock")
    uiLock:addLabelApp("Proteksi Akses Pintu", "Lock")
    uiLock:addTooltip("Formasi Proteksi", "Formasi: White Door (kanan-bawah), Blocker Door (kanan-atas), Small Lock (tengah-atas), Signal Jammer (tengah-bawah), Wooden Door (kiri-atas), World Lock (kiri-bawah).", "Verified", false)
    uiLock:addToggle("Aktifkan Proteksi Kunci", CFG.enable_lock_enclosure, "as_chk_enable_lock", true)
    uiLock:addDivider()
    uiLock:addInputInt("ID World Lock", tostring(CFG.lock_id_wl), "ID WL", "242", "Lock", "as_in_id_wl")
    uiLock:addToggle("World Lock Publik", CFG.wl_make_public, "as_chk_wl_public", true)
    uiLock:addDivider()
    uiLock:addInputInt("ID Small Lock", tostring(CFG.lock_id_sl), "ID SL", "202", "Lock", "as_in_id_sl")
    uiLock:addDivider()
    uiLock:addInputInt("ID Signal Jammer", tostring(CFG.lock_id_jammer), "ID Jammer", "226", "WifiTethering", "as_in_id_jammer")
    uiLock:addDivider()
    uiLock:addInputInt("ID Blocker Door", tostring(CFG.lock_id_blocker), "ID Blocker", "828 (Air Vent)", "DoorFront", "as_in_id_blocker")
    uiLock:addDivider()
    uiLock:addInputInt("ID Wooden Door", tostring(CFG.lock_id_door), "ID Door", "12 (Wooden Door)", "DoorFront", "as_in_id_door")
    uiLock:addInputString("Label Door ID", CFG.farm_door_id, "Door ID", "BOREN", "Label", "as_in_door_label")
    uiLock:addButton("💾 Simpan Konfigurasi Proteksi", "as_btn_save_lock_cfg")

    -- Tab 3: Gudang & Restock
    local uiStorage = createNativeUI("3. Gudang & Restock", "Inventory")
    uiStorage:addLabelApp("Manajemen Gudang Multi-Storage", "Inventory")
    uiStorage:addInputString("Nama Gudang", "", "World", "GUDANG1", "Inventory", "as_input_add_stor")
    uiStorage:addInputString("Door ID Gudang", "", "Door ID", "DOOR123", "DoorFront", "as_input_add_stor_door")
    uiStorage:addButton("➕ Tambah Gudang", "as_btn_add_stor_direct")
    uiStorage:addButton("📍 Tambah Gudang Aktif", "as_btn_add_cur_stor")
    uiStorage:addButton("📋 Kelola Daftar Gudang", "as_btn_manage_storages")
    uiStorage:addButton("🗑️ Kosongkan Gudang", "as_btn_clear_stor_direct")
    uiStorage:addDivider()
    uiStorage:addLabel("Penyimpanan File Gudang (Download):")
    uiStorage:addButton("📥 Simpan Gudang ke File", "as_btn_save_storages")
    uiStorage:addButton("📤 Muat Gudang dari File", "as_btn_load_storages")
    uiStorage:addDisplayList("Daftar Gudang Tersimpan", "Default", "as_stor_display_list")
    uiStorage:addDivider()
    uiStorage:addSlider("Batas Minimum Restock", 10, 100, CFG.restock_threshold, 5, false, "as_in_restock_thresh")

    -- Tab 4: Desain & Layout
    local uiLayout = createNativeUI("4. Desain & Layout", "Build")
    uiLayout:addLabelApp("Pengaturan Tata Letak Farm", "Build")
    uiLayout:addLabel("Spesifikasi Block Material:")
    uiLayout:addInputInt("ID Block Material", tostring(CFG.block_id), "ID Item", "8772 (Soil) / 2 (Dirt) / 102 (Plat)", "Tag", "as_in_block_id")
    uiLayout:addButton("💾 Simpan ID Block", "as_btn_save_block_id")
    uiLayout:addDivider()
    uiLayout:addToggle("Aktifkan ModFly (Melayang)", CFG.use_modfly, "as_chk_modfly", true)
    uiLayout:addToggle("Aktifkan Anti Lava", CFG.use_anti_lava, "as_chk_anti_lava", true)
    uiLayout:addDivider()
    uiLayout:addLabel("Parameter Baris Horizontal:")
    uiLayout:addSlider("Jarak Baris (Step)", 1, 4, CFG.row_step, 1, false, "as_in_row_step")
    uiLayout:addSlider("Baris Awal (Y)", 1, 10, CFG.row_start_y, 1, false, "as_in_start_y")
    uiLayout:addSlider("Baris Akhir (Y)", 40, 56, CFG.row_end_y, 1, false, "as_in_end_y")
    uiLayout:addSlider("Kolom Awal (X)", 0, 10, CFG.row_start_x, 1, false, "as_in_start_x")
    uiLayout:addSlider("Kolom Akhir (X)", 80, 99, CFG.row_end_x, 1, false, "as_in_end_x")
    uiLayout:addDivider()
    uiLayout:addLabel("Elevator Air Vertikal:")
    uiLayout:addToggle("Aktifkan Kolom Air Vertikal", CFG.enable_water_column, "as_chk_enable_water", true)
    uiLayout:addInputInt("ID Item Air", tostring(CFG.water_item_id), "Water ID", "822", "Water", "as_in_water_id")
    uiLayout:addSlider("Posisi Kolom Air (X)", 0, 5, CFG.water_x, 1, false, "as_in_water_x")
    uiLayout:addDivider()
    uiLayout:addLabel("Pengaturan Waktu Tunggu (Delay):")
    uiLayout:addSlider("Delay Penempatan Block (ms)", 60, 400, CFG.delay_place, 10, false, "as_in_delay_place")
    uiLayout:addSlider("Delay Pergerakan (ms)", 80, 500, CFG.delay_walk, 10, false, "as_in_delay_walk")
    uiLayout:addSlider("Delay Pukulan (ms)", 80, 400, CFG.delay_punch, 10, false, "as_in_delay_punch")

    -- Tab 5: Konsol & Log
    local uiConsole = createNativeUI("5. Konsol & Log", "Terminal")
    uiConsole:addLabelApp("Konsol Aktivitas Sistem", "Terminal")
    uiConsole:addDisplayList("Status Operasi Sistem", "Default", "as_power_status_list")
    uiConsole:addDivider()
    uiConsole:addButton("🗑️ Bersihkan Riwayat Log", "as_btn_clear_log")
    uiConsole:addDisplayList("Riwayat Log Operasi", "Default", "as_log_display_list")

    -- Registrasi Kategori & Sub-Menu ke GrowLauncher
    pcall(addCategory, "Boren Soil", "Grass")
    pcall(addCategory, "Boren Farm", "Grass")
    pcall(addIntoModule, uiWorld:generateJSON(), "Boren Soil")
    pcall(addIntoModule, uiLock:generateJSON(), "Boren Soil")
    pcall(addIntoModule, uiStorage:generateJSON(), "Boren Soil")
    pcall(addIntoModule, uiLayout:generateJSON(), "Boren Soil")
    pcall(addIntoModule, uiConsole:generateJSON(), "Boren Soil")
    pcall(addIntoModule, uiWorld:generateJSON(), "Boren Farm")
    pcall(addIntoModule, uiLock:generateJSON(), "Boren Farm")
    pcall(addIntoModule, uiStorage:generateJSON(), "Boren Farm")
    pcall(addIntoModule, uiLayout:generateJSON(), "Boren Farm")
    pcall(addIntoModule, uiConsole:generateJSON(), "Boren Farm")
end

-- ============================================================================
-- 17. EVENT DISPATCHERS & VALUE HANDLERS
-- ============================================================================
local function toBoolVal(v)
    return (v == true or v == 1 or v == "true" or v == "1")
end

local function readGLString(alias, fallback)
    if getValue then
        for _, vtype in ipairs({ 2, 5, 0, 1 }) do
            local ok, val = pcall(getValue, vtype, alias)
            if ok and type(val) == "string" and val ~= "" then
                return val
            end
        end
    end
    return fallback
end

local function handleSoilUIValue(vtype, name, value)
    -- Shift argumen jika GrowLauncher memanggil onValue(alias, value) atau alias ada di vtype
    if type(vtype) == "string" and (name == nil or type(name) ~= "string" or (type(name) == "string" and vtype:sub(1, 3) == "as_")) then
        value = name
        name = vtype
        vtype = 0
    end
    name = tostring(name or "")
    if name == "" then return end

    local now = os.clock()
    local isButton = (name:sub(1, 7) == "as_btn_")
    if isButton then
        if STATE.last_btn_time and STATE.last_btn_time[name] and (now - STATE.last_btn_time[name]) < 0.25 then
            return
        end
        if not STATE.last_btn_time then STATE.last_btn_time = {} end
        STATE.last_btn_time[name] = now
    end

    if name == "as_run_power" then
        local state = toBoolVal(value)
        if state and not STATE.running then
            startSoilBot()
        elseif not state and STATE.running then
            stopSoilBot()
        end
    elseif name == "as_pause_toggle" then
        STATE.paused = toBoolVal(value)
        addLog(STATE.paused and "`e[Jeda] `0Bot dijeda sementara." or "`2[Lanjut] `0Bot dilanjutkan.")
        updatePowerStatusList()
    elseif name == "as_btn_stop" then
        stopSoilBot()
    elseif name == "as_chk_mode_random" then
        CFG.world_mode = toBoolVal(value) and "RANDOM" or "MANUAL"
        savePrefs(CFG)
    elseif name == "as_in_rnd_len" then
        CFG.random_letter_count = tonumber(value) or CFG.random_letter_count
        savePrefs(CFG)
    elseif name == "as_chk_rnd_num" then
        CFG.random_with_number = toBoolVal(value)
        savePrefs(CFG)
    elseif name == "as_in_rnd_prefix" then
        CFG.random_prefix = tostring(value or "")
        savePrefs(CFG)
    elseif name == "as_in_rnd_target" then
        CFG.random_target_count = tonumber(value) or CFG.random_target_count
        savePrefs(CFG)
    elseif name == "as_chk_auto_blast" then
        CFG.auto_use_blast = toBoolVal(value)
        savePrefs(CFG)
    elseif name == "as_in_blast_id" then
        CFG.blast_item_id = tonumber(value) or CFG.blast_item_id
        savePrefs(CFG)
    elseif name == "as_input_add_world" then
        STATE.buf_new_world = tostring(value or ""):upper():match("^%s*(.-)%s*$")
    elseif name == "as_input_add_door" then
        STATE.buf_new_door = tostring(value or ""):upper():match("^%s*(.-)%s*$")
    elseif name == "as_btn_add_world" then
        local wIn = readGLString("as_input_add_world", STATE.buf_new_world or "")
        local dIn = readGLString("as_input_add_door", STATE.buf_new_door or "")
        wIn = tostring(wIn or ""):gsub("%s+", ""):upper()
        dIn = tostring(dIn or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if wIn ~= "" then
            table.insert(CFG.farm_world_list, { name = wIn, door = dIn, done = false })
            savePrefs(CFG)
            saveWorldsToFile()
            updateWorldDisplayList()
            addLog("`2[Tambah World] `w" .. wIn .. ((dIn ~= "") and (" (Door: " .. dIn .. ")") or "") .. " ditambahkan.")
            notifyUser("World " .. wIn .. " ditambahkan!")
            STATE.buf_new_world = ""
            STATE.buf_new_door = ""
            if editValue then
                pcall(editValue, "as_input_add_world", "")
                pcall(editValue, "as_input_add_door", "")
            end
        else
            notifyUser("Isi nama world terlebih dahulu!")
            addLog("`4[Peringatan] `oNama world tidak boleh kosong!")
        end
    elseif name == "as_btn_add_cur_world" then
        local curW = getWorldNameSafe()
        if curW == "" or curW == "EXIT" then
            addLog("`4[Gagal] `oKarakter belum masuk ke dalam world.")
            notifyUser("Karakter belum masuk ke dalam world.")
            return
        end
        local exists = false
        for _, w in ipairs(CFG.farm_world_list) do
            if (w.name or ""):upper() == curW:upper() then
                exists = true
                break
            end
        end
        if exists then
            addLog("`e[Info] `0World " .. curW .. " sudah ada di antrean.")
            notifyUser("World " .. curW .. " sudah ada di antrean.")
        else
            local doorVal = (STATE.buf_new_door and STATE.buf_new_door ~= "") and STATE.buf_new_door or CFG.farm_door_id
            table.insert(CFG.farm_world_list, { name = curW, door = doorVal, done = false })
            savePrefs(CFG)
            saveWorldsToFile()
            updateWorldDisplayList()
            addLog("`2[Sukses] `wWorld sekarang: " .. curW .. " ditambahkan ke antrean!")
            notifyUser("World " .. curW .. " ditambahkan!")
        end
    elseif name == "as_btn_clear_worlds" then
        CFG.farm_world_list = {}
        savePrefs(CFG)
        saveWorldsToFile()
        updateWorldDisplayList()
        addLog("`4[Bersihkan World] `oAntrean world dikosongkan.")
        notifyUser("Antrean world dikosongkan!")
    elseif name == "as_btn_manage_worlds" then
        openUnifiedWorldManager()
    elseif name == "as_btn_save_worlds" then
        saveWorldsToFile()
    elseif name == "as_btn_load_worlds" then
        loadWorldsFromFile()
    elseif name == "as_chk_enable_lock" then
        CFG.enable_lock_enclosure = toBoolVal(value)
        savePrefs(CFG)
    elseif name == "as_in_id_wl" then
        CFG.lock_id_wl = tonumber(value) or CFG.lock_id_wl
    elseif name == "as_in_id_sl" then
        CFG.lock_id_sl = tonumber(value) or CFG.lock_id_sl
    elseif name == "as_in_id_jammer" then
        CFG.lock_id_jammer = tonumber(value) or CFG.lock_id_jammer
    elseif name == "as_in_id_blocker" then
        CFG.lock_id_blocker = tonumber(value) or CFG.lock_id_blocker
    elseif name == "as_in_id_door" then
        CFG.lock_id_door = tonumber(value) or CFG.lock_id_door
    elseif name == "as_in_door_label" then
        CFG.farm_door_id = tostring(value or "")
    elseif name == "as_chk_wl_public" then
        CFG.wl_make_public = toBoolVal(value)
    elseif name == "as_btn_save_lock_cfg" then
        local wlIn = tonumber(readGLString("as_in_id_wl", tostring(CFG.lock_id_wl)))
        if wlIn and wlIn > 0 then CFG.lock_id_wl = wlIn end
        local slIn = tonumber(readGLString("as_in_id_sl", tostring(CFG.lock_id_sl)))
        if slIn and slIn > 0 then CFG.lock_id_sl = slIn end
        local jamIn = tonumber(readGLString("as_in_id_jammer", tostring(CFG.lock_id_jammer)))
        if jamIn and jamIn > 0 then CFG.lock_id_jammer = jamIn end
        local blkIn = tonumber(readGLString("as_in_id_blocker", tostring(CFG.lock_id_blocker)))
        if blkIn and blkIn > 0 then CFG.lock_id_blocker = blkIn end
        local drIn = tonumber(readGLString("as_in_id_door", tostring(CFG.lock_id_door)))
        if drIn and drIn > 0 then CFG.lock_id_door = drIn end
        local lblIn = readGLString("as_in_door_label", CFG.farm_door_id)
        if lblIn then CFG.farm_door_id = lblIn end
        savePrefs(CFG)
        notifyUser("Pengaturan proteksi berhasil disimpan!")
        addLog("`2[Simpan Proteksi] `wKonfigurasi proteksi kunci berhasil disimpan.")
    elseif name == "as_input_add_stor" then
        STATE.buf_new_stor = tostring(value or ""):upper():match("^%s*(.-)%s*$")
    elseif name == "as_input_add_stor_door" then
        STATE.buf_new_stor_door = tostring(value or ""):upper():match("^%s*(.-)%s*$")
    elseif name == "as_btn_add_stor_direct" then
        local sIn = readGLString("as_input_add_stor", STATE.buf_new_stor or "")
        local dIn = readGLString("as_input_add_stor_door", STATE.buf_new_stor_door or "")
        sIn = tostring(sIn or ""):gsub("%s+", ""):upper()
        dIn = tostring(dIn or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if sIn ~= "" then
            table.insert(CFG.storage_list, { name = sIn, door = dIn })
            savePrefs(CFG)
            saveStoragesToFile()
            updateStorageDisplayList()
            addLog("`2[Tambah Gudang] `w" .. sIn .. ((dIn ~= "") and (" (Door: " .. dIn .. ")") or "") .. " ditambahkan.")
            notifyUser("Gudang " .. sIn .. " ditambahkan!")
            STATE.buf_new_stor = ""
            STATE.buf_new_door = ""
            if editValue then
                pcall(editValue, "as_input_add_stor", "")
                pcall(editValue, "as_input_add_stor_door", "")
            end
        else
            notifyUser("Isi nama gudang terlebih dahulu!")
            addLog("`4[Peringatan] `oNama gudang tidak boleh kosong!")
        end
    elseif name == "as_btn_add_cur_stor" then
        local curW = getWorldNameSafe()
        if curW == "" or curW == "EXIT" then
            addLog("`4[Gagal] `oKarakter belum masuk ke dalam world.")
            notifyUser("Karakter belum masuk ke dalam world.")
            return
        end
        local exists = false
        for _, s in ipairs(CFG.storage_list) do
            if (s.name or ""):upper() == curW:upper() then
                exists = true
                break
            end
        end
        if exists then
            addLog("`e[Info] `0Gudang " .. curW .. " sudah ada di daftar.")
            notifyUser("Gudang " .. curW .. " sudah ada di daftar.")
        else
            local dVal = (STATE.buf_new_stor_door and STATE.buf_new_stor_door ~= "") and STATE.buf_new_stor_door or CFG.storage_door_default
            table.insert(CFG.storage_list, { name = curW, door = dVal })
            savePrefs(CFG)
            saveStoragesToFile()
            updateStorageDisplayList()
            addLog("`2[Sukses] `wGudang sekarang: " .. curW .. " ditambahkan ke daftar!")
            notifyUser("Gudang " .. curW .. " ditambahkan!")
        end
    elseif name == "as_btn_clear_stor_direct" then
        CFG.storage_list = {}
        savePrefs(CFG)
        saveStoragesToFile()
        updateStorageDisplayList()
        addLog("`4[Bersihkan Gudang] `oDaftar gudang dikosongkan.")
        notifyUser("Daftar gudang dikosongkan!")
    elseif name == "as_btn_manage_storages" then
        openUnifiedStorageManager()
    elseif name == "as_btn_save_storages" then
        saveStoragesToFile()
    elseif name == "as_btn_load_storages" then
        loadStoragesFromFile()
    elseif name == "as_in_restock_thresh" then
        CFG.restock_threshold = tonumber(value) or CFG.restock_threshold
        savePrefs(CFG)
    elseif name == "as_in_block_id" then
        CFG.block_id = tonumber(value) or CFG.block_id
    elseif name == "as_btn_save_block_id" then
        local bIn = tonumber(readGLString("as_in_block_id", tostring(CFG.block_id)))
        if bIn and bIn > 0 then CFG.block_id = bIn end
        savePrefs(CFG)
        notifyUser(string.format("ID Block %d (%s) tersimpan!", CFG.block_id, getItemNameSafe(CFG.block_id)))
        addLog(string.format("`2[Simpan Block] `wID Block disetel ke %d (%s)", CFG.block_id, getItemNameSafe(CFG.block_id)))
        updatePowerStatusList()
    elseif name == "as_in_row_step" then
        CFG.row_step = tonumber(value) or CFG.row_step
        savePrefs(CFG)
    elseif name == "as_in_start_y" then
        CFG.row_start_y = tonumber(value) or CFG.row_start_y
        savePrefs(CFG)
    elseif name == "as_in_end_y" then
        CFG.row_end_y = tonumber(value) or CFG.row_end_y
        savePrefs(CFG)
    elseif name == "as_in_start_x" then
        CFG.row_start_x = tonumber(value) or CFG.row_start_x
        savePrefs(CFG)
    elseif name == "as_in_end_x" then
        CFG.row_end_x = tonumber(value) or CFG.row_end_x
        savePrefs(CFG)
    elseif name == "as_chk_enable_water" then
        CFG.enable_water_column = toBoolVal(value)
        savePrefs(CFG)
    elseif name == "as_in_water_id" then
        local wIdIn = tonumber(readGLString("as_in_water_id", tostring(CFG.water_item_id)))
        if wIdIn and wIdIn > 0 then CFG.water_item_id = wIdIn end
        savePrefs(CFG)
    elseif name == "as_in_water_x" then
        CFG.water_x = tonumber(value) or CFG.water_x
        savePrefs(CFG)
    elseif name == "as_in_delay_place" then
        CFG.delay_place = tonumber(value) or CFG.delay_place
        savePrefs(CFG)
    elseif name == "as_in_delay_walk" then
        CFG.delay_walk = tonumber(value) or CFG.delay_walk
        savePrefs(CFG)
    elseif name == "as_in_delay_punch" then
        CFG.delay_punch = tonumber(value) or CFG.delay_punch
        savePrefs(CFG)
    elseif name == "as_btn_clear_log" then
        STATE.log_messages = {}
        updateLogDisplayList()
    elseif name == "as_chk_modfly" then
        CFG.use_modfly = toBoolVal(value)
        savePrefs(CFG)
        applyCheatToggles()
    elseif name == "as_chk_anti_lava" then
        CFG.use_anti_lava = toBoolVal(value)
        savePrefs(CFG)
        applyCheatToggles()
    end
end

-- Export OnValue & onSendPacket ke namespace global
function OnValue(typeVal, name, val)
    pcall(handleSoilUIValue, typeVal, name, val)
end
onValue = OnValue

onSendPacket = onSendPacketDialogHook
OnSendPacket = onSendPacketDialogHook

-- Daftarkan setOnValue per-alias jika didukung GrowLauncher
local ALL_UI_ALIASES = {
    "as_run_power", "as_pause_toggle", "as_btn_stop",
    "as_chk_mode_random", "as_in_rnd_len", "as_chk_rnd_num", "as_in_rnd_prefix", "as_in_rnd_target",
    "as_chk_auto_blast", "as_in_blast_id",
    "as_input_add_world", "as_input_add_door", "as_btn_add_world", "as_btn_add_cur_world", "as_btn_manage_worlds", "as_btn_clear_worlds",
    "as_btn_save_worlds", "as_btn_load_worlds",
    "as_chk_enable_lock", "as_in_id_wl", "as_chk_wl_public", "as_in_id_sl", "as_in_id_jammer", "as_in_id_blocker", "as_in_id_door", "as_in_door_label", "as_btn_save_lock_cfg",
    "as_input_add_stor", "as_input_add_stor_door", "as_btn_add_stor_direct", "as_btn_add_cur_stor", "as_btn_manage_storages", "as_btn_clear_stor_direct",
    "as_btn_save_storages", "as_btn_load_storages", "as_in_restock_thresh",
    "as_in_block_id", "as_btn_save_block_id", "as_chk_modfly", "as_chk_anti_lava", "as_in_row_step", "as_in_start_y", "as_in_end_y", "as_in_start_x", "as_in_end_x",
    "as_chk_enable_water", "as_in_water_id", "as_in_water_x",
    "as_in_delay_place", "as_in_delay_walk", "as_in_delay_punch", "as_btn_clear_log"
}

if setOnValue then
    for _, aliasName in ipairs(ALL_UI_ALIASES) do
        pcall(setOnValue, aliasName, function(a1, a2, a3)
            if a2 == aliasName then
                OnValue(a1, a2, a3)
            elseif a1 == aliasName then
                OnValue(0, a1, a2)
            else
                OnValue(0, aliasName, a1)
            end
        end)
    end
end

if addHook then
    pcall(addHook, onValue, "onvalue")
    pcall(addHook, onSendPacketDialogHook, "onsendpacket")
end
if applyHook then
    pcall(applyHook)
end

-- Variant Hook jika versi GL memakai addEvent
if addEvent and Event and Event.variantlist then
    pcall(addEvent, Event.variantlist, function(var)
        -- Fallback variant
    end)
end

-- Inisialisasi awal UI Native GrowLauncher
pcall(registerNativeSoilUI)
safeSleep(200)
pcall(updatePowerStatusList)
pcall(updateWorldDisplayList)
pcall(updateStorageDisplayList)
pcall(updateLogDisplayList)
addLog("`2[Boren Store] `wAuto Soil & Block Builder siap digunakan!")
