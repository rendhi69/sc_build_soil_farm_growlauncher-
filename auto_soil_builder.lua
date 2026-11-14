-- ============================================================================
-- AUTO SOIL & BLOCK BUILDER - BOREN STORE OFFICIAL
-- ============================================================================
-- Framework : GrowLauncher Lua (Android & PC Windows)
-- Developer : Boren Store
-- Modul     : Auto Placement Soil / Block Farm + Lock Enclosure + Multi-Storage
-- Lisensi   : Hak Cipta Dilindungi Undang-Undang
-- ============================================================================

-- ============================================================================
-- 1. IDENTITAS SISTEM & METADATA
-- ============================================================================
local SCRIPT_NAME    = "Auto Soil Builder"
local SCRIPT_VERSION = "2.3.1"
local SCRIPT_BUILD   = "2026.11.15-PRO"
local SCRIPT_AUTHOR  = "Boren Store"

-- ============================================================================
-- 2. KONFIGURASI LENGKAP & DEFAULT PREFERENCES
-- ============================================================================
local function loadPref(key, defaultVal)
    if not saved or not saved.get then return defaultVal end
    local ok, res = pcall(saved.get, saved, key, defaultVal)
    if ok and res ~= nil then
        return res
    end
    return defaultVal
end

local CFG = {
    -- Mode Operasi World
    world_mode              = tostring(loadPref("world_mode", "LIST")),           -- "LIST" atau "RANDOM"
    random_letter_count     = tonumber(loadPref("random_letter_count", 8)) or 8,
    random_with_number      = (loadPref("random_with_number", false) == true),
    random_prefix           = tostring(loadPref("random_prefix", "")),
    random_target_count     = tonumber(loadPref("random_target_count", 20)) or 20,
    
    -- Auto Blast Settings
    auto_use_blast          = (loadPref("auto_use_blast", false) == true),
    blast_item_id           = tonumber(loadPref("blast_item_id", 1336)) or 1336, -- 1336 = World Blast, 2810 = Cave Blast
    
    -- Pengaturan Proteksi Kunci Pintu (DEFAULT ON)
    enable_lock_enclosure   = (loadPref("enable_lock_enclosure", true) == true),
    lock_id_wl              = tonumber(loadPref("lock_id_wl", 242)) or 242,       -- World Lock
    lock_id_sl              = tonumber(loadPref("lock_id_sl", 202)) or 202,       -- Small Lock
    lock_id_jammer          = tonumber(loadPref("lock_id_jammer", 226)) or 226,   -- Signal Jammer
    lock_id_door            = tonumber(loadPref("lock_id_door", 12)) or 12,       -- Wooden Door di (0, 0)
    farm_door_id            = tostring(loadPref("farm_door_id", "BOREN")),        -- Label / ID Door
    wl_make_public          = (loadPref("wl_make_public", true) == true),
    
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
    tool_file_name          = loadPref("tool_file_name", "boren_soil_tools.txt"),
    block_file_name         = loadPref("block_file_name", "boren_soil_blocks.txt"),
    
    -- Discord Webhook
    webhook_url             = tostring(loadPref("webhook_url", "")),
    
    -- 3 Kategori World Terpisah
    farm_world_list         = {}, -- World Put / Antrean Farm
    storage_tool_list       = {}, -- World untuk Alat (WL, SL, Jammer, Wooden Door)
    storage_block_list      = {}, -- World untuk Block (Soil Block 8772)
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
    buf_new_tool            = "",
    buf_new_tool_door       = "",
    buf_new_block           = "",
    buf_new_block_door      = "",
    
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
        -- Simpan daftar world put
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

        -- Simpan daftar world gudang alat
        local tParts = {}
        if type(cfg.storage_tool_list) == "table" then
            for _, entry in ipairs(cfg.storage_tool_list) do
                if type(entry) == "table" and entry.name and entry.name ~= "" then
                    table.insert(tParts, tostring(entry.name) .. "|" .. tostring(entry.door or ""))
                end
            end
        end
        saved:set("storage_tool_list_str", table.concat(tParts, ";"))

        -- Simpan daftar world gudang block
        local bParts = {}
        if type(cfg.storage_block_list) == "table" then
            for _, entry in ipairs(cfg.storage_block_list) do
                if type(entry) == "table" and entry.name and entry.name ~= "" then
                    table.insert(bParts, tostring(entry.name) .. "|" .. tostring(entry.door or ""))
                end
            end
        end
        saved:set("storage_block_list_str", table.concat(bParts, ";"))

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

    local tStr = loadPref("storage_tool_list_str", "")
    if tStr and tStr ~= "" then
        CFG.storage_tool_list = {}
        for token in string.gmatch(tStr, "[^;]+") do
            local sName, sDoor = string.match(token, "^([^|]*)|?([^|]*)$")
            if sName and sName ~= "" then
                table.insert(CFG.storage_tool_list, {
                    name = sName:upper(),
                    door = (sDoor or ""):upper()
                })
            end
        end
    end

    local bStr = loadPref("storage_block_list_str", "")
    if bStr and bStr ~= "" then
        CFG.storage_block_list = {}
        for token in string.gmatch(bStr, "[^;]+") do
            local sName, sDoor = string.match(token, "^([^|]*)|?([^|]*)$")
            if sName and sName ~= "" then
                table.insert(CFG.storage_block_list, {
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
local updateToolDisplayList = nil
local updateBlockDisplayList = nil
local updateLogDisplayList = nil

-- ============================================================================
-- 3. ITEM CONSTANTS & SAFE NAME RESOLVER
-- ============================================================================
local ITEM = {
    DIRT        = 2,
    MAIN_DOOR   = 6,
    BEDROCK     = 8,
    WOODEN_DOOR = 12,
    LAVA        = 10,
    ROCK        = 102,
    SMALL_LOCK  = 202,
    JAMMER      = 226,
    WORLD_LOCK  = 242,
    WATER       = 822,
    AIR_VENT    = 828,
    BLAST_WORLD = 1336,
    BLAST_CAVE  = 2810,
    SOIL_BLOCK  = 8772,
}

local LOCK_IDS = { 202, 204, 206, 242, 1796, 7188, 4994, 226, 828, 12 }

local function getItemNameSafe(itemID)
    itemID = tonumber(itemID) or 0
    if itemID == ITEM.SOIL_BLOCK  then return "Soil Block" end
    if itemID == ITEM.DIRT        then return "Dirt" end
    if itemID == ITEM.ROCK        then return "Rock" end
    if itemID == ITEM.LAVA        then return "Lava" end
    if itemID == ITEM.MAIN_DOOR   then return "White Door (Exit)" end
    if itemID == ITEM.WOODEN_DOOR then return "Wooden Door" end
    if itemID == ITEM.BEDROCK     then return "Bedrock" end
    if itemID == ITEM.SMALL_LOCK  then return "Small Lock" end
    if itemID == ITEM.WORLD_LOCK  then return "World Lock" end
    if itemID == ITEM.JAMMER      then return "Signal Jammer" end
    if itemID == ITEM.AIR_VENT    then return "Blocker Door (Air Vent)" end
    if itemID == ITEM.WATER       then return "Water" end
    if itemID == ITEM.BLAST_WORLD then return "World Blast" end
    if itemID == ITEM.BLAST_CAVE  then return "Cave Blast" end

    if getItemInfo then
        local ok, info = pcall(getItemInfo, itemID)
        if ok and info and info.name and info.name ~= "" then
            return info.name
        end
    end
    if getBot and getBot().getItemInfo then
        local ok, info = pcall(getBot().getItemInfo, getBot(), itemID)
        if ok and info and info.name and info.name ~= "" then
            return info.name
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
        end
    end
    return "EXIT"
end

-- ============================================================================
-- 4. JSON SERIALIZER & DISPLAY LIST FORMATTERS
-- ============================================================================
local function jsonEncode(val)
    local t = type(val)
    if t == "table" then
        local isArray = true
        local n = 0
        for k, _ in pairs(val) do
            n = n + 1
            if type(k) ~= "number" or k ~= n then
                isArray = false
                break
            end
        end
        if isArray then
            local parts = {}
            for _, v in ipairs(val) do
                table.insert(parts, jsonEncode(v))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, string.format("%s:%s", jsonEncode(tostring(k)), jsonEncode(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    elseif t == "string" then
        local escaped = val:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
        return '"' .. escaped .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    else
        return "null"
    end
end

local function addLog(msg)
    local timestamp = os.date("%H:%M:%S")
    local line = string.format("[%s] %s", timestamp, msg)
    table.insert(STATE.log_messages, 1, line)
    if #STATE.log_messages > 150 then
        table.remove(STATE.log_messages)
    end
    if LogToConsole then
        pcall(LogToConsole, line)
    elseif print then
        pcall(print, line)
    end
    if updateLogDisplayList then
        pcall(updateLogDisplayList)
    end
end

local function notifyUser(msg)
    if sendNotification then
        pcall(sendNotification, msg)
    elseif growtopia and growtopia.notify then
        pcall(growtopia.notify, msg)
    end
end

local function sendWebhookNotification(title, description, fields)
    if not CFG.webhook_url or CFG.webhook_url == "" then return end
    local payload = {
        embeds = {
            {
                title = title or "Boren Farm Builder Report",
                description = description or "",
                color = 3066993,
                fields = fields or {},
                footer = { text = "Boren Store Official • Auto Soil Builder" },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }
    local jsonStr = jsonEncode(payload)
    if httpPost then
        pcall(httpPost, CFG.webhook_url, jsonStr, "application/json")
    elseif httpRequest then
        pcall(httpRequest, "POST", CFG.webhook_url, jsonStr, { ["Content-Type"] = "application/json" })
    end
end

local function getInvCount(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then return 0 end
    if getInventory then
        local ok, inv = pcall(getInventory)
        if ok and inv then
            local items = inv.items or inv
            for _, it in pairs(items) do
                local id = it.id or it.item or 0
                if id == itemID then
                    return it.count or it.amount or 0
                end
            end
        end
    end
    if getBot and getBot().getInventory then
        local ok, inv = pcall(getBot().getInventory, getBot())
        if ok and inv then
            local items = inv.items or inv
            for _, it in pairs(items) do
                local id = it.id or it.item or 0
                if id == itemID then
                    return it.count or it.amount or 0
                end
            end
        end
    end
    return 0
end

updatePowerStatusList = function()
    if not editValue then return end
    local blockName = getItemNameSafe(CFG.block_id)
    local curW = getWorldNameSafe()
    local runningStr = STATE.running and (STATE.paused and "`ePAUSED" or "`2RUNNING") or "`4STOPPED"
    local list = {
        { "Status Mesin", runningStr },
        { "World Terkini", (curW ~= "EXIT" and curW or "-") },
        { "Antrean World Put", string.format("%d World", #CFG.farm_world_list) },
        { "Gudang Alat", string.format("%d World", #CFG.storage_tool_list) },
        { "Gudang Block", string.format("%d World", #CFG.storage_block_list) },
        { "Block Terpilih", string.format("%s (ID %d)", blockName, CFG.block_id) },
        { "Stok Block di Tas", string.format("%d Pcs", getInvCount(CFG.block_id)) },
        { "Total Terpasang", string.format("%d Block", STATE.total_placed_blocks) },
        { "Target Selesai", string.format("%d World", STATE.total_worlds_completed) },
    }
    pcall(editValue, "as_power_status_list", jsonEncode(list))
end

updateWorldDisplayList = function()
    if not editValue then return end
    local list = {}
    for idx, w in ipairs(CFG.farm_world_list) do
        local dInfo = (w.door and w.door ~= "") and (" [Door: " .. w.door .. "]") or ""
        local sInfo = w.done and "`2[DONE]`0" or "`e[PENDING]`0"
        table.insert(list, {
            string.format("%d. %s%s", idx, w.name, dInfo),
            sInfo
        })
    end
    if #list == 0 then table.insert(list, { "Belum ada antrean world put", "Tambahkan world di form di atas" }) end
    pcall(editValue, "as_world_display_list", jsonEncode(list))
end

updateToolDisplayList = function()
    if not editValue then return end
    local list = {}
    for idx, s in ipairs(CFG.storage_tool_list) do
        local dInfo = (s.door and s.door ~= "") and (" [Door: " .. s.door .. "]") or ""
        table.insert(list, {
            string.format("%d. %s%s", idx, s.name, dInfo),
            "Gudang Alat (WL, SL, Jammer, Door)"
        })
    end
    if #list == 0 then table.insert(list, { "Belum ada gudang alat", "Tambahkan world alat di form di atas" }) end
    pcall(editValue, "as_tool_display_list", jsonEncode(list))
end

updateBlockDisplayList = function()
    if not editValue then return end
    local list = {}
    for idx, s in ipairs(CFG.storage_block_list) do
        local dInfo = (s.door and s.door ~= "") and (" [Door: " .. s.door .. "]") or ""
        table.insert(list, {
            string.format("%d. %s%s", idx, s.name, dInfo),
            string.format("Gudang Block (%s)", getItemNameSafe(CFG.block_id))
        })
    end
    if #list == 0 then table.insert(list, { "Belum ada gudang block", "Tambahkan world block di form di atas" }) end
    pcall(editValue, "as_block_display_list", jsonEncode(list))
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
    if not fh then fh = io.open("/sdcard/Download/" .. fn, "w") end
    if not fh then
        addLog("`4[Gagal Simpan] `oTidak dapat membuka file world put.")
        return false
    end

    for _, w in ipairs(CFG.farm_world_list) do
        local d = (w.door and w.door ~= "") and ("|" .. w.door) or ""
        local s = w.done and "|DONE" or ""
        fh:write(w.name .. d .. s .. "\n")
    end
    fh:close()
    addLog(string.format("`2[Berhasil Simpan] `w%d world put ke %s", #CFG.farm_world_list, path))
    notifyUser(string.format("Berhasil simpan %d world put", #CFG.farm_world_list))
    return true
end

local function loadWorldsFromFile()
    local path, dir, fn = resolveFilePath(CFG.world_file_name, "boren_soil_worlds.txt")
    local fh = io.open(path, "r")
    if not fh then fh = io.open("/sdcard/Download/" .. fn, "r") end
    if not fh then
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
    addLog(string.format("`2[Berhasil Muat] `w%d world put dari %s", count, path))
    updateWorldDisplayList()
    return true
end

local function saveToolsToFile()
    local path, dir, fn = resolveFilePath(CFG.tool_file_name, "boren_soil_tools.txt")
    local fh = io.open(path, "w")
    if not fh then fh = io.open("/sdcard/Download/" .. fn, "w") end
    if not fh then
        addLog("`4[Gagal Simpan] `oTidak dapat membuka file gudang alat.")
        return false
    end

    for _, s in ipairs(CFG.storage_tool_list) do
        local d = (s.door and s.door ~= "") and ("|" .. s.door) or ""
        fh:write(s.name .. d .. "\n")
    end
    fh:close()
    addLog(string.format("`2[Berhasil Simpan] `w%d gudang alat ke %s", #CFG.storage_tool_list, path))
    notifyUser(string.format("Berhasil simpan %d gudang alat", #CFG.storage_tool_list))
    return true
end

local function loadToolsFromFile()
    local path, dir, fn = resolveFilePath(CFG.tool_file_name, "boren_soil_tools.txt")
    local fh = io.open(path, "r")
    if not fh then fh = io.open("/sdcard/Download/" .. fn, "r") end
    if not fh then
        return false
    end

    local count = 0
    CFG.storage_tool_list = {}
    for line in fh:lines() do
        local cleanLine = line:gsub("[\r\n]", ""):match("^%s*(.-)%s*$")
        if cleanLine ~= "" and not cleanLine:match("^#") then
            local sName, sDoor = cleanLine:match("^([^|]+)|?([^|]*)$")
            if sName and sName ~= "" then
                table.insert(CFG.storage_tool_list, {
                    name = sName:upper(),
                    door = (sDoor or ""):upper()
                })
                count = count + 1
            end
        end
    end
    fh:close()
    savePrefs(CFG)
    addLog(string.format("`2[Berhasil Muat] `w%d gudang alat dari %s", count, path))
    updateToolDisplayList()
    return true
end

local function saveBlocksToFile()
    local path, dir, fn = resolveFilePath(CFG.block_file_name, "boren_soil_blocks.txt")
    local fh = io.open(path, "w")
    if not fh then fh = io.open("/sdcard/Download/" .. fn, "w") end
    if not fh then
        addLog("`4[Gagal Simpan] `oTidak dapat membuka file gudang block.")
        return false
    end

    for _, s in ipairs(CFG.storage_block_list) do
        local d = (s.door and s.door ~= "") and ("|" .. s.door) or ""
        fh:write(s.name .. d .. "\n")
    end
    fh:close()
    addLog(string.format("`2[Berhasil Simpan] `w%d gudang block ke %s", #CFG.storage_block_list, path))
    notifyUser(string.format("Berhasil simpan %d gudang block", #CFG.storage_block_list))
    return true
end

local function loadBlocksFromFile()
    local path, dir, fn = resolveFilePath(CFG.block_file_name, "boren_soil_blocks.txt")
    local fh = io.open(path, "r")
    if not fh then fh = io.open("/sdcard/Download/" .. fn, "r") end
    if not fh then
        return false
    end

    local count = 0
    CFG.storage_block_list = {}
    for line in fh:lines() do
        local cleanLine = line:gsub("[\r\n]", ""):match("^%s*(.-)%s*$")
        if cleanLine ~= "" and not cleanLine:match("^#") then
            local sName, sDoor = cleanLine:match("^([^|]+)|?([^|]*)$")
            if sName and sName ~= "" then
                table.insert(CFG.storage_block_list, {
                    name = sName:upper(),
                    door = (sDoor or ""):upper()
                })
                count = count + 1
            end
        end
    end
    fh:close()
    savePrefs(CFG)
    addLog(string.format("`2[Berhasil Muat] `w%d gudang block dari %s", count, path))
    updateBlockDisplayList()
    return true
end

-- ============================================================================
-- 6. GROWLAUNCHER CHEATS & ACTION HELPERS
-- ============================================================================
local function applyCheatToggles()
    if not editToggle then return end
    pcall(editToggle, "ModFly", CFG.use_modfly == true)
    pcall(editToggle, "Mod Fly", CFG.use_modfly == true)
    pcall(editToggle, "Anti Lava", CFG.use_anti_lava == true)
    pcall(editToggle, "Anti-Lava", CFG.use_anti_lava == true)
    pcall(editToggle, "Anti Spike", true)
    pcall(editToggle, "Anti-Spike", true)
end

local function safeSleep(ms)
    ms = tonumber(ms) or 100
    if Sleep then
        Sleep(ms)
    elseif sleep then
        sleep(ms)
    else
        local start = os.clock()
        while (os.clock() - start) * 1000 < ms do end
    end
end

local function waitIfPaused()
    while STATE.paused and STATE.running do
        safeSleep(300)
    end
    return STATE.running
end

local function getPlayerPos()
    local p = (getLocal and getLocal()) or (getBot and getBot())
    if not p then return 50, 23 end
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
-- 7. MOVEMENT & SAFE PATHFINDING
-- ============================================================================
local function isTileSafeToStand(tx, ty)
    if tx < 0 or tx > 99 or ty < 0 or ty > 59 then return false end
    local ok, t = pcall(getTile, tx, ty)
    if not ok or not t then return true end
    if t.fg == 8 or t.fg == 6 or t.fg == 10 then return false end
    return true
end

local function nearestFree(cx, cy)
    if isTileSafeToStand(cx, cy) then return cx, cy end
    local ring = { {0,-1}, {0,1}, {-1,0}, {1,0}, {-1,-1}, {1,-1}, {-1,1}, {1,1} }
    for _, d in ipairs(ring) do
        local nx, ny = cx + d[1], cy + d[2]
        if isTileSafeToStand(nx, ny) then return nx, ny end
    end
    return cx, cy
end

local function moveSafeTo(tx, ty)
    tx = math.max(0, math.min(99, tx))
    ty = math.max(0, math.min(59, ty))

    local sx, sy = getPlayerPos()
    if sx == tx and sy == ty then return true end

    local walkDelay = math.max(50, tonumber(CFG.delay_walk) or 150)

    if CFG.use_modfly then
        local steps = math.max(math.abs(tx - sx), math.abs(ty - sy))
        if steps == 0 then return true end
        for s = 1, steps do
            if not waitIfPaused() then return false end
            local cx = math.floor(sx + (tx - sx) * (s / steps))
            local cy = math.floor(sy + (ty - sy) * (s / steps))
            local okP, p = pcall(getLocal)
            if okP and p and sendPacketRaw then
                pcall(sendPacketRaw, false, {
                    type  = 0,
                    x     = cx * 32,
                    y     = cy * 32,
                    state = (tx >= sx) and 32 or 48,
                })
            elseif getBot and getBot().findPath then
                pcall(getBot().findPath, getBot(), cx, cy)
            end
            safeSleep(math.floor(walkDelay * 0.7))
        end
        return true
    end

    if FindPath or (getBot and getBot().findPath) then
        local wtx, wty = nearestFree(tx, ty)
        local okF = false
        if FindPath then
            okF = pcall(FindPath, wtx, wty)
        elseif getBot and getBot().findPath then
            okF = pcall(getBot().findPath, getBot(), wtx, wty)
        end
        if okF then
            local waitWalk = 0
            while waitWalk < 4000 and STATE.running do
                safeSleep(150)
                waitWalk = waitWalk + 150
                local nx, ny = getPlayerPos()
                if nx == wtx and ny == wty then return true end
            end
        end
    end

    local steps = math.max(math.abs(tx - sx), math.abs(ty - sy))
    for s = 1, steps do
        if not waitIfPaused() then return false end
        local cx = math.floor(sx + (tx - sx) * (s / steps))
        local cy = math.floor(sy + (ty - sy) * (s / steps))
        local okP, p = pcall(getLocal)
        if okP and p and sendPacketRaw then
            pcall(sendPacketRaw, false, {
                type  = 0,
                x     = cx * 32,
                y     = cy * 32,
                state = (tx >= sx) and 32 or 48,
            })
        end
        safeSleep(walkDelay)
    end
    return true
end

-- ============================================================================
-- 8. TILE BREAKING & PLACING ENGINE
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
    return false
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
        if math.abs(px - tx) > 2 or math.abs(py - ty) > 2 then
            moveSafeTo(tx, ty - 1)
        end

        sendRawAction(tx, ty, itemID)
        safeSleep(CFG.delay_place)
        attempts = attempts + 1
    end
    return false
end

-- ============================================================================
-- 9. WHITE DOOR & LOCK ENCLOSURE ENGINE
-- ============================================================================
local function findWhiteDoor()
    local attempts = 0
    while STATE.running and attempts < 15 do
        if getTiles then
            local ok, tiles = pcall(getTiles)
            if ok and tiles then
                for _, t in pairs(tiles) do
                    if t and t.fg == ITEM.MAIN_DOOR then
                        return t.x, t.y
                    end
                end
            end
        end
        for y = 0, 59 do
            for x = 0, 99 do
                local ok, t = pcall(getTile, x, y)
                if ok and t and t.fg == ITEM.MAIN_DOOR then
                    return x, y
                end
            end
        end
        safeSleep(250)
        attempts = attempts + 1
    end
    -- Fallback ke posisi player jika tile belum terload sempurna
    local px, py = getPlayerPos()
    if px and py then return px, py end
    return 50, 23
end

local function isOnMainDoor()
    local px, py = getPlayerPos()
    local dx, dy = findWhiteDoor()
    if px and dx and px == dx and py == dy then
        return true
    end
    return false
end

local function getMissingLockMaterials()
    local missing = {}
    local needed = {
        { id = CFG.lock_id_wl,     name = "World Lock",    count = 1 },
        { id = CFG.lock_id_sl,     name = "Small Lock",    count = 1 },
        { id = CFG.lock_id_jammer, name = "Signal Jammer", count = 1 },
        { id = CFG.lock_id_door,   name = "Wooden Door",   count = 1 },
    }
    for _, item in ipairs(needed) do
        local inInv = getInvCount(item.id)
        if inInv < item.count then
            table.insert(missing, { id = item.id, name = item.name, need = item.count - inInv })
        end
    end
    return missing
end

-- Forward declaration of warpToWorld
local warpToWorld

local function restockLockMaterialsFromStorage(missing)
    if #CFG.storage_tool_list == 0 then
        local names = {}
        for _, m in ipairs(missing) do
            table.insert(names, string.format("%s (ID %d)", m.name, m.id))
        end
        local warnStr = "Bahan proteksi tidak ada di tas & Gudang Alat kosong: " .. table.concat(names, ", ")
        addLog("`4[Peringatan Alat] `o" .. warnStr)
        notifyUser(warnStr)
        return false
    end

    local currentFarm = STATE.current_world
    local currentFarmDoor = STATE.current_door
    addLog("`9[Gudang Alat] `0Bahan proteksi kurang di tas. Mengambil ke Gudang Alat...")

    for _, stor in ipairs(CFG.storage_tool_list) do
        if not STATE.running or STATE.paused then break end
        if stor.name and stor.name ~= "" then
            addLog(string.format("`9[Cek Alat] `0Mengecek bahan proteksi di %s...", stor.name))
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

    -- Kembali ke farm world jika sebelumnya berada di farm
    if currentFarm ~= "" and currentFarm ~= "EXIT" then
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
        local warnStr = "Bahan proteksi belum lengkap di tas/gudang alat: " .. table.concat(names, ", ")
        addLog("`4[Peringatan Alat] `o" .. warnStr)
        notifyUser(warnStr)
        return false
    end

    addLog("`2[Gudang Alat] `wSeluruh bahan proteksi berhasil diambil dari gudang alat!")
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
    local doorX, doorY = findWhiteDoor()
    if not doorX or not doorY then
        addLog("`4[Proteksi Gagal] `oWhite Door tidak ditemukan di world ini!")
        notifyUser("Peringatan: White Door tidak ditemukan!")
        return false
    end
    addLog(string.format("`2[Proteksi] `wWhite Door terdeteksi di koordinat (%d, %d)", doorX, doorY))

    -- Tentukan orientasi horizontal (kiri pintu jika doorX >= 2, kanan jika < 2)
    local dirX = (doorX >= 2) and -1 or 1
    local pJammer = { x = doorX + (1 * dirX), y = doorY }
    local pSL     = { x = doorX + (1 * dirX), y = doorY - 1 }
    local pWL     = { x = doorX + (2 * dirX), y = doorY }
    local pSky    = { x = doorX + (2 * dirX), y = doorY - 1 } -- Langit kosong di atas WL

    -- 3. Cek apakah formasi kunci & Door ID di (0, 0) sudah pernah terpasang lengkap
    local okWl, tWl = pcall(getTile, pWL.x, pWL.y)
    local okSl, tSl = pcall(getTile, pSL.x, pSL.y)
    local okJm, tJm = pcall(getTile, pJammer.x, pJammer.y)
    local okD0, tD0 = pcall(getTile, 0, 0)

    if okWl and tWl and tWl.fg == CFG.lock_id_wl and
       okSl and tSl and tSl.fg == CFG.lock_id_sl and
       okJm and tJm and tJm.fg == CFG.lock_id_jammer and
       okD0 and tD0 and tD0.fg == CFG.lock_id_door then
        addLog("`2[Proteksi Kunci] `wStruktur proteksi kunci dan Door ID di (0,0) sudah terpasang rapi!")
        return true
    end

    -- 4. Validasi ketersediaan bahan yang diperlukan
    local missingMat = getMissingLockMaterials()
    if #missingMat > 0 then
        addLog("`e[Alat Kurang] `0Bahan proteksi belum lengkap di tas. Mencoba mengambil ke Gudang Alat...")
        local okRestock = restockLockMaterialsFromStorage(missingMat)
        if not okRestock then
            addLog("`4[Peringatan Proteksi] `oPemasangan kunci dilewati karena bahan tidak tersedia.")
            notifyUser("Pemasangan kunci dilewati: bahan tidak lengkap.")
            return false
        end
    end

    -- 5. Bersihkan area petak formasi proteksi
    local spotsToClear = { pJammer, pSL, pWL, pSky }
    for _, sp in ipairs(spotsToClear) do
        local ok, t = pcall(getTile, sp.x, sp.y)
        if ok and t and (t.fg ~= 0 and t.fg ~= 8 and t.fg ~= 6) then
            breakTileAt(sp.x, sp.y)
        end
    end

    -- 6. Pasang Signal Jammer di (doorX - 1, doorY) + Punch 1x agar aktif
    addLog("`9[Proteksi] `0Memasang Signal Jammer...")
    if placeTileAt(pJammer.x, pJammer.y, CFG.lock_id_jammer) then
        safeSleep(300)
        sendHitAction(pJammer.x, pJammer.y)
        safeSleep(350)
        addLog(string.format("`2[Proteksi] `wSignal Jammer aktif di (%d, %d)", pJammer.x, pJammer.y))
    end

    -- 7. Pasang Small Lock di (doorX - 1, doorY - 1) & Recalc Lock
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

    -- 8. Pasang World Lock di (doorX - 2, doorY) & Set Public
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

    -- 9. Pasang Wooden Door di koordinat (0, 0) & Setting Door ID (seperti DF)
    addLog("`9[Proteksi] `0Fly ke (0, 0) untuk memasang Door ID...")
    if editToggle then pcall(editToggle, "ModFly", true) end
    safeSleep(200)
    moveSafeTo(1, 0)
    safeSleep(350)

    local ok0, t0 = pcall(getTile, 0, 0)
    if ok0 and t0 and t0.fg ~= CFG.lock_id_door and t0.fg ~= 8 then
        breakTileAt(0, 0)
    end

    if placeTileAt(0, 0, CFG.lock_id_door) then
        safeSleep(300)
        wrenchTile(0, 0)
        safeSleep(300)
        local dID = (CFG.farm_door_id and CFG.farm_door_id ~= "") and CFG.farm_door_id or "BOREN"
        if sendPacket then
            pcall(sendPacket, 2, string.format("action|dialog_return\ndialog_name|door_edit\ntilex|0|\ntiley|0|\ndoor_name|\ndoor_target|\ndoor_id|%s\ncheckbox_locked|1", dID))
        end
        safeSleep(300)
        addLog(string.format("`2[Proteksi] `wDoor ID (%s) berhasil dipasang di (0, 0)", dID))
    end

    -- Kembali ke White Door
    moveSafeTo(doorX, doorY)
    safeSleep(300)
    applyCheatToggles()

    addLog("`2[Proteksi Selesai] `wStruktur proteksi kunci dan Door ID di (0, 0) berhasil dipasang optimal!")
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
    addLog("`2[Elevator Air] `wKolom elevator air berhasil dipasang!")
    return true
end

-- ============================================================================
-- 11. HORIZONTAL ROW SOIL PLACING ENGINE
-- ============================================================================
local function placeSoilRows(restockCallback)
    addLog(string.format("`9[Place Rows] `0Memulai penempatan %s (ID %d)...", getItemNameSafe(CFG.block_id), CFG.block_id))

    local goingRight = true
    for y = CFG.row_start_y, CFG.row_end_y, CFG.row_step do
        if not STATE.running then break end
        if not waitIfPaused() then break end

        STATE.active_row = y
        updatePowerStatusList()

        local startX = goingRight and CFG.row_start_x or CFG.row_end_x
        local endX   = goingRight and CFG.row_end_x or CFG.row_start_x
        local stepX  = goingRight and 1 or -1
        goingRight = not goingRight

        local x = startX
        while (stepX > 0 and x <= endX) or (stepX < 0 and x >= endX) do
            if not STATE.running then break end
            if not waitIfPaused() then break end

            STATE.active_col = x

            local ok, t = pcall(getTile, x, y)
            if ok and t and t.fg ~= CFG.block_id and t.fg ~= 8 and t.fg ~= 6 then
                if getInvCount(CFG.block_id) <= 0 then
                    addLog(string.format("`e[Stok Habis] `0Block di tas habis pada (%d, %d). Memanggil restock...", x, y))
                    if restockCallback then
                        local okRestock = restockCallback(x, y)
                        if not okRestock then
                            addLog("`4[Konstruksi Terhenti] `oGagal restock block dari gudang.")
                            return false
                        end
                    else
                        addLog("`4[Konstruksi Terhenti] `oTidak ada fungsi restock.")
                        return false
                    end
                end

                local placed = placeTileAt(x, y, CFG.block_id)
                if placed then
                    STATE.total_placed_blocks = STATE.total_placed_blocks + 1
                    if STATE.total_placed_blocks % 50 == 0 then
                        updatePowerStatusList()
                    end
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

warpToWorld = function(worldName, doorID)
    if not worldName or worldName == "" then return false end
    worldName = worldName:upper():gsub("%s+", "")
    doorID = (doorID or ""):gsub("%s+", "")

    local targetStr = (doorID ~= "") and (worldName .. "|" .. doorID) or worldName
    addLog(string.format("`9[Warp] `0Menuju world: %s...", targetStr))

    local tries = 0
    while STATE.running and tries < 8 do
        local cur = getWorldNameSafe()
        if cur ~= worldName then
            if sendPacket then
                pcall(sendPacket, 3, "action|join_request\nname|" .. targetStr .. "\ninvitedWorld|0\n")
            elseif getBot and getBot().warp then
                pcall(getBot().warp, getBot(), targetStr)
            end
            safeSleep(3200)
        else
            -- Sudah berada di world target
            if doorID ~= "" and isOnMainDoor() then
                if sendPacket then
                    pcall(sendPacket, 3, "action|join_request\nname|" .. worldName .. "|" .. doorID .. "\ninvitedWorld|0\n")
                elseif getBot and getBot().warp then
                    pcall(getBot().warp, getBot(), worldName .. "|" .. doorID)
                end
                safeSleep(1500)
            end
            if getWorldNameSafe() == worldName then
                STATE.current_world = worldName
                applyCheatToggles()
                return true
            end
        end
        tries = tries + 1
    end

    local finalW = getWorldNameSafe()
    STATE.current_world = finalW
    applyCheatToggles()
    return finalW == worldName
end

local function isWorldCleanAndUnowned()
    local tiles = nil
    if getWorld then
        local w = getWorld()
        tiles = (type(w) == "table") and w.tiles or nil
    elseif getBot and getBot().getWorld then
        local w = getBot():getWorld()
        tiles = w and w.getTiles and w:getTiles()
    end

    if not tiles and getTiles then
        local ok, res = pcall(getTiles)
        if ok and res then tiles = res end
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
-- 13. MULTI-STORAGE BLOCK RESTOCK ENGINE
-- ============================================================================
local function restockBlocksFromStorage(resumeX, resumeY)
    if #CFG.storage_block_list == 0 then
        addLog("`4[Restock Gagal] `oDaftar Gudang Block kosong! Tambahkan gudang di Tab 4.")
        return false
    end

    local currentFarm = STATE.current_world
    local currentFarmDoor = STATE.current_door

    for sIdx, stor in ipairs(CFG.storage_block_list) do
        if not STATE.running then break end
        addLog(string.format("`9[Gudang Block] `0Menuju gudang %d/%d: %s...", sIdx, #CFG.storage_block_list, stor.name))
        if warpToWorld(stor.name, stor.door) then
            safeSleep(1500)

            local objs = (getObjects and getObjects()) or (getBot and getBot().getWorld and getBot():getWorld().getObjects and getBot():getWorld():getObjects())
            if objs then
                for _, obj in pairs(objs) do
                    local oId = obj.id or obj.item or 0
                    if oId == CFG.block_id then
                        local ox = math.floor((obj.posX or obj.x or 0) / 32)
                        local oy = math.floor((obj.posY or obj.y or 0) / 32)
                        addLog(string.format("`2[Gudang Block] `wDitemukan floating block di (%d, %d). Mengambil...", ox, oy))
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

            if getInvCount(CFG.block_id) >= CFG.restock_threshold then
                addLog(string.format("`2[Restock Sukses] `wBerhasil restock %d block. Kembali ke %s...", getInvCount(CFG.block_id), currentFarm))
                if currentFarm ~= "" and currentFarm ~= "EXIT" then
                    warpToWorld(currentFarm, currentFarmDoor)
                    safeSleep(1200)
                    if resumeX and resumeY then
                        moveSafeTo(resumeX, resumeY)
                    end
                end
                return true
            end
        end
    end

    addLog("`4[Gudang Block Gagal] `oSemua gudang block sudah dicek namun block tidak cukup.")
    return false
end

-- ============================================================================
-- 14. PRE-FLIGHT PREPARATION & MAIN PROCESS DISPATCHER
-- ============================================================================
local function ensurePreparedForFarm()
    -- 1. Cek Kebutuhan Alat & Kunci
    if CFG.enable_lock_enclosure then
        local missingTools = getMissingLockMaterials()
        if #missingTools > 0 then
            addLog("`9[Persiapan Alat] `0Bahan proteksi belum lengkap di tas. Mengambil ke Gudang Alat...")
            local okT = restockLockMaterialsFromStorage(missingTools)
            if not okT then
                addLog("`e[Peringatan Alat] `0Gagal mengambil alat proteksi dari gudang alat.")
            end
        end
    end

    -- 2. Cek Kebutuhan Block
    if getInvCount(CFG.block_id) < CFG.restock_threshold then
        addLog(string.format("`9[Persiapan Block] `0Block di tas kurang (%d < %d). Mengambil ke Gudang Block...", getInvCount(CFG.block_id), CFG.restock_threshold))
        local okB = restockBlocksFromStorage()
        if not okB then
            addLog("`e[Peringatan Block] `0Gagal mengambil block dari gudang block.")
        end
    end
end

local function runSingleFarmWorld(worldName, doorID)
    STATE.current_world = worldName
    STATE.current_door = doorID or ""
    STATE.status_text = "Mempersiapkan: " .. worldName
    updatePowerStatusList()
    addLog(string.format("`2========================================`0"))
    addLog(string.format("`2[Mulai World] `wMemproses Farm World: %s", worldName))

    -- Persiapan tas sebelum masuk ke world
    ensurePreparedForFarm()

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
        return restockBlocksFromStorage(resX, resY)
    end)

    if okRows then
        STATE.total_worlds_completed = STATE.total_worlds_completed + 1
        addLog(string.format("`2[World Selesai] `w%s sukses dibangun 100%%!", worldName))
        sendWebhookNotification("Farm World Selesai", string.format("World: **%s**\nTotal Block: **%d**\nTotal World Selesai: **%d**", worldName, STATE.total_placed_blocks, STATE.total_worlds_completed))
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
                    if w.name == rndWorld then foundEntry = true; break end
                end
                if not foundEntry then
                    table.insert(CFG.farm_world_list, { name = rndWorld, door = CFG.farm_door_id, done = true })
                    savePrefs(CFG)
                    saveWorldsToFile()
                    updateWorldDisplayList()
                end
            end
            safeSleep(1500)
        end
    else
        addLog(string.format("`9[Mode Antrean] `0Memproses %d world dalam antrean...", #CFG.farm_world_list))
        if #CFG.farm_world_list == 0 then
            addLog("`4[Antrean Kosong] `oDaftar world kosong! Tambahkan world di Tab 1.")
            STATE.running = false
            updatePowerStatusList()
            return
        end

        for idx, wItem in ipairs(CFG.farm_world_list) do
            if not STATE.running then break end
            if not wItem.done then
                STATE.current_world_index = idx
                local ok = runSingleFarmWorld(wItem.name, wItem.door)
                if ok then
                    wItem.done = true
                    savePrefs(CFG)
                    saveWorldsToFile()
                    updateWorldDisplayList()
                end
                safeSleep(2000)
            end
        end
    end

    STATE.running = false
    STATE.status_text = "SELESAI"
    addLog("`2[Operasi Selesai] `wSeluruh rangkaian pembangunan farm selesai!")
    updatePowerStatusList()
    notifyUser("Auto Soil Builder Selesai!")
end

local function startSoilBot()
    if STATE.running then
        addLog("`e[Peringatan] `0Bot sudah dalam kondisi berjalan.")
        return
    end
    STATE.running = true
    STATE.paused = false
    STATE.status_text = "RUNNING"
    updatePowerStatusList()

    local okCoro = pcall(runCoroutine, function()
        autoSoilMainLoop()
    end)
    if not okCoro then
        local okTask = pcall(function()
            if asyncTask then
                asyncTask(autoSoilMainLoop)
            else
                local co = coroutine.create(autoSoilMainLoop)
                coroutine.resume(co)
            end
        end)
        if not okTask then
            addLog("`4[Coroutine Error] `oGagal meluncurkan coroutine bot.")
            STATE.running = false
            updatePowerStatusList()
        end
    end
end

local function stopSoilBot()
    STATE.running = false
    STATE.paused = false
    STATE.status_text = "STOPPED"
    addLog("`4[Bot Berhenti] `oInstruksi penghentian bot diterima.")
    updatePowerStatusList()
    notifyUser("Auto Soil Builder Dihentikan!")
end

local function togglePauseSoilBot()
    if not STATE.running then return end
    STATE.paused = not STATE.paused
    STATE.status_text = STATE.paused and "PAUSED" or "RUNNING"
    addLog(STATE.paused and "`e[Bot Dijeda] `0Operasi dihentikan sementara." or "`2[Bot Dilanjutkan] `wOperasi dilanjutkan kembali.")
    updatePowerStatusList()
end

-- ============================================================================
-- 15. UNIFIED DIALOG MANAGERS & QUICK PASTE
-- ============================================================================
local openUnifiedWorldManager
local openUnifiedToolManager
local openUnifiedBlockManager
local openEditWorldEntryDialog
local openEditToolEntryDialog
local openEditBlockEntryDialog

local function safeSendRawDialog(dText)
    if not dText or dText == "" then return false end
    if sendRawDialog then
        pcall(sendRawDialog, dText)
        return true
    elseif variant then
        pcall(variant, { [0] = "OnDialogRequest", [1] = dText })
        return true
    elseif sendVariant then
        pcall(sendVariant, { [0] = "OnDialogRequest", [1] = dText })
        return true
    end
    return false
end

local function parseAndValidateWorldBatch(rawText, isReplace)
    if not rawText or rawText == "" then return 0, 0, 0, "Teks kosong!" end
    local added, duplicates, ignored = 0, 0, 0
    local existing = {}
    if not isReplace then
        for _, w in ipairs(CFG.farm_world_list) do
            existing[(w.name or ""):upper()] = true
        end
    else
        CFG.farm_world_list = {}
    end

    for line in string.gmatch(rawText, "[^\r\n]+") do
        local clean = line:gsub("^%s+", ""):gsub("%s+$", "")
        clean = clean:gsub("^%d+[%.:%)%s]+", ""):gsub("%s*#.*$", "")
        if clean ~= "" then
            local pName, pDoor = clean:match("^([A-Za-z0-9_]+)[%s:|;,]+([A-Za-z0-9_]*)$")
            if not pName then pName = clean:match("^([A-Za-z0-9_]+)$") end
            if pName and pName ~= "" then
                pName = pName:upper()
                pDoor = pDoor or ""
                if not existing[pName] then
                    existing[pName] = true
                    table.insert(CFG.farm_world_list, { name = pName, door = pDoor, done = false })
                    added = added + 1
                else
                    duplicates = duplicates + 1
                end
            else
                ignored = ignored + 1
            end
        end
    end

    savePrefs(CFG)
    saveWorldsToFile()
    updateWorldDisplayList()
    local summary = string.format("Sukses: %d ditambah | %d duplikat | %d diabaikan", added, duplicates, ignored)
    return added, duplicates, ignored, summary
end

local function parseAndValidateToolBatch(rawText, isReplace)
    if not rawText or rawText == "" then return 0, 0, 0, "Teks kosong!" end
    local added, duplicates, ignored = 0, 0, 0
    local existing = {}
    if not isReplace then
        for _, s in ipairs(CFG.storage_tool_list) do
            existing[(s.name or ""):upper()] = true
        end
    else
        CFG.storage_tool_list = {}
    end

    for line in string.gmatch(rawText, "[^\r\n]+") do
        local clean = line:gsub("^%s+", ""):gsub("%s+$", "")
        clean = clean:gsub("^%d+[%.:%)%s]+", ""):gsub("%s*#.*$", "")
        if clean ~= "" then
            local pName, pDoor = clean:match("^([A-Za-z0-9_]+)[%s:|;,]+([A-Za-z0-9_]*)$")
            if not pName then pName = clean:match("^([A-Za-z0-9_]+)$") end
            if pName and pName ~= "" then
                pName = pName:upper()
                pDoor = pDoor or ""
                if not existing[pName] then
                    existing[pName] = true
                    table.insert(CFG.storage_tool_list, { name = pName, door = pDoor })
                    added = added + 1
                else
                    duplicates = duplicates + 1
                end
            else
                ignored = ignored + 1
            end
        end
    end

    savePrefs(CFG)
    saveToolsToFile()
    updateToolDisplayList()
    local summary = string.format("Sukses: %d ditambah | %d duplikat | %d diabaikan", added, duplicates, ignored)
    return added, duplicates, ignored, summary
end

local function parseAndValidateBlockBatch(rawText, isReplace)
    if not rawText or rawText == "" then return 0, 0, 0, "Teks kosong!" end
    local added, duplicates, ignored = 0, 0, 0
    local existing = {}
    if not isReplace then
        for _, s in ipairs(CFG.storage_block_list) do
            existing[(s.name or ""):upper()] = true
        end
    else
        CFG.storage_block_list = {}
    end

    for line in string.gmatch(rawText, "[^\r\n]+") do
        local clean = line:gsub("^%s+", ""):gsub("%s+$", "")
        clean = clean:gsub("^%d+[%.:%)%s]+", ""):gsub("%s*#.*$", "")
        if clean ~= "" then
            local pName, pDoor = clean:match("^([A-Za-z0-9_]+)[%s:|;,]+([A-Za-z0-9_]*)$")
            if not pName then pName = clean:match("^([A-Za-z0-9_]+)$") end
            if pName and pName ~= "" then
                pName = pName:upper()
                pDoor = pDoor or ""
                if not existing[pName] then
                    existing[pName] = true
                    table.insert(CFG.storage_block_list, { name = pName, door = pDoor })
                    added = added + 1
                else
                    duplicates = duplicates + 1
                end
            else
                ignored = ignored + 1
            end
        end
    end

    savePrefs(CFG)
    saveBlocksToFile()
    updateBlockDisplayList()
    local summary = string.format("Sukses: %d ditambah | %d duplikat | %d diabaikan", added, duplicates, ignored)
    return added, duplicates, ignored, summary
end

openUnifiedWorldManager = function(fmt)
    fmt = fmt or "colon"
    local copyLines = {}
    for _, w in ipairs(CFG.farm_world_list) do
        local d = (w.door and w.door ~= "") and w.door or ""
        if fmt == "colon" then
            table.insert(copyLines, d ~= "" and (w.name .. ":" .. d) or w.name)
        elseif fmt == "pipe" then
            table.insert(copyLines, d ~= "" and (w.name .. "|" .. d) or w.name)
        else
            table.insert(copyLines, w.name)
        end
    end
    local copyText = table.concat(copyLines, "\n")

    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`2Kelola Antrean World Put|left|1436|")
    table.insert(d, string.format("add_smalltext|Total antrean terdaftar: `w%d World`o|", #CFG.farm_world_list))
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_label|small|`9Format Ekspor / Salin Cepat:`o|")
    table.insert(d, "add_button|boren_btn_wfmt_colon|`wFormat WORLD:DOOR`o|noflags|0|0|")
    table.insert(d, "add_button|boren_btn_wfmt_pipe|`wFormat WORLD|DOOR`o|noflags|0|0|")
    table.insert(d, "add_button|boren_btn_wfmt_name|`wHanya Nama World`o|noflags|0|0|")
    table.insert(d, "add_text_input|boren_wpaste_raw|Teks Antrean World (Salin / Tempel Cepat):|" .. copyText .. "|250|")
    table.insert(d, "add_checkbox|boren_wpaste_replace|Ganti seluruh daftar (Replace All)|0|")
    table.insert(d, "add_button|boren_submit_wpaste|`2Terapkan Perubahan Teks Antrean`o|noflags|0|0|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_label|small|`9Daftar Antrean World Put Individual:`o|")

    if #CFG.farm_world_list == 0 then
        table.insert(d, "add_smalltext|`4Belum ada world dalam antrean.`o|")
    else
        for idx, w in ipairs(CFG.farm_world_list) do
            local dLabel = (w.door and w.door ~= "") and (" [Door: " .. w.door .. "]") or ""
            local statusTag = w.done and "`2[DONE]`o " or "`e[PENDING]`o "
            table.insert(d, string.format("add_smalltext|`w%d.`o %s%s%s|", idx, statusTag, w.name, dLabel))
            table.insert(d, string.format("add_button|boren_wedit_%d|`eEdit #%d`o|noflags|0|0|", idx, idx))
            table.insert(d, string.format("add_button|boren_whapus_%d|`4Hapus #%d`o|noflags|0|0|", idx, idx))
            table.insert(d, "add_spacer|small|")
        end
    end

    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_label|small|`9Tambah Satu World Put Manual:`o|")
    table.insert(d, "add_text_input|as_dlg_add_world|Nama World:||30|")
    table.insert(d, "add_text_input|as_dlg_add_door|Door ID (Opsional):||30|")
    table.insert(d, "add_button|as_dlg_btn_add|`2➕ Tambah World ke Antrean`o|noflags|0|0|")
    table.insert(d, "add_button|as_dlg_btn_clear|`4🗑️ Kosongkan Seluruh Antrean`o|noflags|0|0|")
    table.insert(d, "add_quick_exit|")
    table.insert(d, "end_dialog|boren_soil_world_mgr|Tutup|Simpan|")
    safeSendRawDialog(table.concat(d, "\n"))
end

openUnifiedToolManager = function(fmt)
    fmt = fmt or "colon"
    local copyLines = {}
    for _, s in ipairs(CFG.storage_tool_list) do
        local d = (s.door and s.door ~= "") and s.door or ""
        if fmt == "colon" then
            table.insert(copyLines, d ~= "" and (s.name .. ":" .. d) or s.name)
        elseif fmt == "pipe" then
            table.insert(copyLines, d ~= "" and (s.name .. "|" .. d) or s.name)
        else
            table.insert(copyLines, s.name)
        end
    end
    local copyText = table.concat(copyLines, "\n")

    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`2Kelola Daftar Gudang Alat|left|242|")
    table.insert(d, string.format("add_smalltext|Total Gudang Alat (WL, SL, Jammer, Door): `w%d World`o|", #CFG.storage_tool_list))
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_label|small|`9Format Ekspor / Salin Cepat:`o|")
    table.insert(d, "add_button|boren_btn_tlfmt_colon|`wFormat WORLD:DOOR`o|noflags|0|0|")
    table.insert(d, "add_button|boren_btn_tlfmt_pipe|`wFormat WORLD|DOOR`o|noflags|0|0|")
    table.insert(d, "add_button|boren_btn_tlfmt_name|`wHanya Nama World`o|noflags|0|0|")
    table.insert(d, "add_text_input|boren_tlpaste_raw|Teks Gudang Alat (Salin / Tempel Cepat):|" .. copyText .. "|250|")
    table.insert(d, "add_checkbox|boren_tlpaste_replace|Ganti seluruh daftar (Replace All)|0|")
    table.insert(d, "add_button|boren_submit_tlpaste|`2Terapkan Perubahan Teks Gudang Alat`o|noflags|0|0|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_label|small|`9Daftar Gudang Alat Individual:`o|")

    if #CFG.storage_tool_list == 0 then
        table.insert(d, "add_smalltext|`4Belum ada world gudang alat terdaftar.`o|")
    else
        for idx, s in ipairs(CFG.storage_tool_list) do
            local dLabel = (s.door and s.door ~= "") and (" [Door: " .. s.door .. "]") or ""
            table.insert(d, string.format("add_smalltext|`w%d.`o %s%s|", idx, s.name, dLabel))
            table.insert(d, string.format("add_button|boren_tledit_%d|`eEdit #%d`o|noflags|0|0|", idx, idx))
            table.insert(d, string.format("add_button|boren_tlhapus_%d|`4Hapus #%d`o|noflags|0|0|", idx, idx))
            table.insert(d, "add_spacer|small|")
        end
    end

    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_label|small|`9Tambah Satu Gudang Alat Manual:`o|")
    table.insert(d, "add_text_input|as_dlg_add_tool|Nama World Gudang Alat:||30|")
    table.insert(d, "add_text_input|as_dlg_add_tool_door|Door ID (Opsional):||30|")
    table.insert(d, "add_button|as_dlg_btn_add_tool|`2➕ Tambah Gudang Alat`o|noflags|0|0|")
    table.insert(d, "add_button|as_dlg_btn_clear_tool|`4🗑️ Kosongkan Seluruh Gudang Alat`o|noflags|0|0|")
    table.insert(d, "add_quick_exit|")
    table.insert(d, "end_dialog|boren_soil_tool_mgr|Tutup|Simpan|")
    safeSendRawDialog(table.concat(d, "\n"))
end

openUnifiedBlockManager = function(fmt)
    fmt = fmt or "colon"
    local copyLines = {}
    for _, s in ipairs(CFG.storage_block_list) do
        local d = (s.door and s.door ~= "") and s.door or ""
        if fmt == "colon" then
            table.insert(copyLines, d ~= "" and (s.name .. ":" .. d) or s.name)
        elseif fmt == "pipe" then
            table.insert(copyLines, d ~= "" and (s.name .. "|" .. d) or s.name)
        else
            table.insert(copyLines, s.name)
        end
    end
    local copyText = table.concat(copyLines, "\n")

    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, "add_label_with_icon|big|`2Kelola Daftar Gudang Block|left|8772|")
    table.insert(d, string.format("add_smalltext|Total Gudang Block (%s): `w%d World`o|", getItemNameSafe(CFG.block_id), #CFG.storage_block_list))
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_label|small|`9Format Ekspor / Salin Cepat:`o|")
    table.insert(d, "add_button|boren_btn_bkfmt_colon|`wFormat WORLD:DOOR`o|noflags|0|0|")
    table.insert(d, "add_button|boren_btn_bkfmt_pipe|`wFormat WORLD|DOOR`o|noflags|0|0|")
    table.insert(d, "add_button|boren_btn_bkfmt_name|`wHanya Nama World`o|noflags|0|0|")
    table.insert(d, "add_text_input|boren_bkpaste_raw|Teks Gudang Block (Salin / Tempel Cepat):|" .. copyText .. "|250|")
    table.insert(d, "add_checkbox|boren_bkpaste_replace|Ganti seluruh daftar (Replace All)|0|")
    table.insert(d, "add_button|boren_submit_bkpaste|`2Terapkan Perubahan Teks Gudang Block`o|noflags|0|0|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_label|small|`9Daftar Gudang Block Individual:`o|")

    if #CFG.storage_block_list == 0 then
        table.insert(d, "add_smalltext|`4Belum ada world gudang block terdaftar.`o|")
    else
        for idx, s in ipairs(CFG.storage_block_list) do
            local dLabel = (s.door and s.door ~= "") and (" [Door: " .. s.door .. "]") or ""
            table.insert(d, string.format("add_smalltext|`w%d.`o %s%s|", idx, s.name, dLabel))
            table.insert(d, string.format("add_button|boren_bkedit_%d|`eEdit #%d`o|noflags|0|0|", idx, idx))
            table.insert(d, string.format("add_button|boren_bkhapus_%d|`4Hapus #%d`o|noflags|0|0|", idx, idx))
            table.insert(d, "add_spacer|small|")
        end
    end

    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_label|small|`9Tambah Satu Gudang Block Manual:`o|")
    table.insert(d, "add_text_input|as_dlg_add_block|Nama World Gudang Block:||30|")
    table.insert(d, "add_text_input|as_dlg_add_block_door|Door ID (Opsional):||30|")
    table.insert(d, "add_button|as_dlg_btn_add_block|`2➕ Tambah Gudang Block`o|noflags|0|0|")
    table.insert(d, "add_button|as_dlg_btn_clear_block|`4🗑️ Kosongkan Seluruh Gudang Block`o|noflags|0|0|")
    table.insert(d, "add_quick_exit|")
    table.insert(d, "end_dialog|boren_soil_block_mgr|Tutup|Simpan|")
    safeSendRawDialog(table.concat(d, "\n"))
end

openEditWorldEntryDialog = function(idx)
    idx = tonumber(idx)
    if not idx or not CFG.farm_world_list[idx] then return end
    local entry = CFG.farm_world_list[idx]
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, string.format("add_label_with_icon|big|`2Edit World Put #%d|left|1436|", idx))
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_text_input|boren_ed_wname|Nama World:|" .. tostring(entry.name or "") .. "|30|")
    table.insert(d, "add_text_input|boren_ed_wdoor|Door ID:|" .. tostring(entry.door or "") .. "|30|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, string.format("add_button|boren_save_wedit_%d|`2Simpan Perubahan`o|noflags|0|0|", idx))
    table.insert(d, "add_quick_exit|")
    table.insert(d, "end_dialog|boren_soil_edit_w_dlg|Batal||")
    safeSendRawDialog(table.concat(d, "\n"))
end

openEditToolEntryDialog = function(idx)
    idx = tonumber(idx)
    if not idx or not CFG.storage_tool_list[idx] then return end
    local entry = CFG.storage_tool_list[idx]
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, string.format("add_label_with_icon|big|`2Edit Gudang Alat #%d|left|242|", idx))
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_text_input|boren_ed_tlname|Nama World Gudang Alat:|" .. tostring(entry.name or "") .. "|30|")
    table.insert(d, "add_text_input|boren_ed_tldoor|Door ID:|" .. tostring(entry.door or "") .. "|30|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, string.format("add_button|boren_save_tledit_%d|`2Simpan Perubahan`o|noflags|0|0|", idx))
    table.insert(d, "add_quick_exit|")
    table.insert(d, "end_dialog|boren_soil_edit_t_dlg|Batal||")
    safeSendRawDialog(table.concat(d, "\n"))
end

openEditBlockEntryDialog = function(idx)
    idx = tonumber(idx)
    if not idx or not CFG.storage_block_list[idx] then return end
    local entry = CFG.storage_block_list[idx]
    local d = {}
    table.insert(d, "set_default_color|`o")
    table.insert(d, string.format("add_label_with_icon|big|`2Edit Gudang Block #%d|left|8772|", idx))
    table.insert(d, "add_spacer|small|")
    table.insert(d, "add_text_input|boren_ed_bkname|Nama World Gudang Block:|" .. tostring(entry.name or "") .. "|30|")
    table.insert(d, "add_text_input|boren_ed_bkdoor|Door ID:|" .. tostring(entry.door or "") .. "|30|")
    table.insert(d, "add_spacer|small|")
    table.insert(d, string.format("add_button|boren_save_bkedit_%d|`2Simpan Perubahan`o|noflags|0|0|", idx))
    table.insert(d, "add_quick_exit|")
    table.insert(d, "end_dialog|boren_soil_edit_b_dlg|Batal||")
    safeSendRawDialog(table.concat(d, "\n"))
end

-- ============================================================================
-- DIALOG HOOK DISPATCHER
-- ============================================================================
local function onDialogReturnPacket(pkt)
    if not pkt or pkt == "" then return false end
    local dName = pkt:match("dialog_name|([^\r\n]+)")
    local btn   = pkt:match("buttonClicked|([^\r\n]+)")
    if not dName then return false end

    local fields = {}
    for line in string.gmatch(pkt, "[^\r\n]+") do
        local k, v = line:match("^([^|]+)|(.*)$")
        if k then fields[k] = v or "" end
    end

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
            addLog("[Quick Paste World] " .. summary)
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
            addLog("`4[Bersihkan World] `oDaftar world put dikosongkan.")
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

    elseif dName == "boren_soil_tool_mgr" then
        if btn == "boren_btn_tlfmt_colon" then
            openUnifiedToolManager("colon")
            return true
        elseif btn == "boren_btn_tlfmt_pipe" then
            openUnifiedToolManager("pipe")
            return true
        elseif btn == "boren_btn_tlfmt_name" then
            openUnifiedToolManager("name_only")
            return true
        elseif btn == "boren_submit_tlpaste" then
            local raw = pkt:match("boren_tlpaste_raw|(.-)\nboren_tlpaste_replace|")
                or pkt:match("boren_tlpaste_raw|(.-)\nbuttonClicked|")
                or fields.boren_tlpaste_raw or ""
            local isReplace = (fields.boren_tlpaste_replace == "1")
            local added, dups, ign, summary = parseAndValidateToolBatch(raw, isReplace)
            addLog("[Quick Paste Alat] " .. summary)
            notifyUser(summary)
            openUnifiedToolManager()
            return true
        elseif btn == "as_dlg_btn_add_tool" then
            local ns = tostring(fields.as_dlg_add_tool or ""):gsub("%s+", ""):upper()
            local nd = tostring(fields.as_dlg_add_tool_door or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if ns ~= "" then
                table.insert(CFG.storage_tool_list, { name = ns, door = nd })
                savePrefs(CFG)
                saveToolsToFile()
                updateToolDisplayList()
                addLog(string.format("`2[Tambah Gudang Alat] `w%s [Door: %s] ditambahkan.", ns, (nd ~= "" and nd or "-")))
                notifyUser("Gudang Alat " .. ns .. " ditambahkan!")
            else
                notifyUser("Isi nama gudang alat terlebih dahulu!")
            end
            openUnifiedToolManager()
            return true
        elseif btn == "as_dlg_btn_clear_tool" then
            CFG.storage_tool_list = {}
            savePrefs(CFG)
            saveToolsToFile()
            updateToolDisplayList()
            addLog("`4[Bersihkan Gudang Alat] `oDaftar gudang alat dikosongkan.")
            notifyUser("Daftar gudang alat dikosongkan!")
            openUnifiedToolManager()
            return true
        end

        local editIdx = btn:match("^boren_tledit_(%d+)$")
        if editIdx then
            openEditToolEntryDialog(tonumber(editIdx))
            return true
        end

        local hapusIdx = btn:match("^boren_tlhapus_(%d+)$")
        if hapusIdx then
            local idx = tonumber(hapusIdx)
            if idx and CFG.storage_tool_list[idx] then
                local removed = table.remove(CFG.storage_tool_list, idx)
                savePrefs(CFG)
                saveToolsToFile()
                updateToolDisplayList()
                addLog(string.format("`4[Hapus Gudang Alat] `o%s dihapus.", removed.name))
                notifyUser("Dihapus: " .. removed.name)
            end
            openUnifiedToolManager()
            return true
        end
        return true

    elseif dName == "boren_soil_block_mgr" then
        if btn == "boren_btn_bkfmt_colon" then
            openUnifiedBlockManager("colon")
            return true
        elseif btn == "boren_btn_bkfmt_pipe" then
            openUnifiedBlockManager("pipe")
            return true
        elseif btn == "boren_btn_bkfmt_name" then
            openUnifiedBlockManager("name_only")
            return true
        elseif btn == "boren_submit_bkpaste" then
            local raw = pkt:match("boren_bkpaste_raw|(.-)\nboren_bkpaste_replace|")
                or pkt:match("boren_bkpaste_raw|(.-)\nbuttonClicked|")
                or fields.boren_bkpaste_raw or ""
            local isReplace = (fields.boren_bkpaste_replace == "1")
            local added, dups, ign, summary = parseAndValidateBlockBatch(raw, isReplace)
            addLog("[Quick Paste Block] " .. summary)
            notifyUser(summary)
            openUnifiedBlockManager()
            return true
        elseif btn == "as_dlg_btn_add_block" then
            local ns = tostring(fields.as_dlg_add_block or ""):gsub("%s+", ""):upper()
            local nd = tostring(fields.as_dlg_add_block_door or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if ns ~= "" then
                table.insert(CFG.storage_block_list, { name = ns, door = nd })
                savePrefs(CFG)
                saveBlocksToFile()
                updateBlockDisplayList()
                addLog(string.format("`2[Tambah Gudang Block] `w%s [Door: %s] ditambahkan.", ns, (nd ~= "" and nd or "-")))
                notifyUser("Gudang Block " .. ns .. " ditambahkan!")
            else
                notifyUser("Isi nama gudang block terlebih dahulu!")
            end
            openUnifiedBlockManager()
            return true
        elseif btn == "as_dlg_btn_clear_block" then
            CFG.storage_block_list = {}
            savePrefs(CFG)
            saveBlocksToFile()
            updateBlockDisplayList()
            addLog("`4[Bersihkan Gudang Block] `oDaftar gudang block dikosongkan.")
            notifyUser("Daftar gudang block dikosongkan!")
            openUnifiedBlockManager()
            return true
        end

        local editIdx = btn:match("^boren_bkedit_(%d+)$")
        if editIdx then
            openEditBlockEntryDialog(tonumber(editIdx))
            return true
        end

        local hapusIdx = btn:match("^boren_bkhapus_(%d+)$")
        if hapusIdx then
            local idx = tonumber(hapusIdx)
            if idx and CFG.storage_block_list[idx] then
                local removed = table.remove(CFG.storage_block_list, idx)
                savePrefs(CFG)
                saveBlocksToFile()
                updateBlockDisplayList()
                addLog(string.format("`4[Hapus Gudang Block] `o%s dihapus.", removed.name))
                notifyUser("Dihapus: " .. removed.name)
            end
            openUnifiedBlockManager()
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

    elseif dName == "boren_soil_edit_t_dlg" then
        local saveIdx = btn:match("^boren_save_tledit_(%d+)$")
        if saveIdx then
            local idx = tonumber(saveIdx)
            if idx and CFG.storage_tool_list[idx] then
                local newName = tostring(fields.boren_ed_tlname or ""):gsub("%s+", ""):upper()
                local newDoor = tostring(fields.boren_ed_tldoor or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if newName ~= "" then
                    CFG.storage_tool_list[idx].name = newName
                    CFG.storage_tool_list[idx].door = newDoor
                    savePrefs(CFG)
                    saveToolsToFile()
                    updateToolDisplayList()
                    addLog(string.format("`2[Edit Gudang Alat #%d] `w%s [Door: %s]", idx, newName, (newDoor ~= "" and newDoor or "-")))
                    notifyUser("Gudang Alat diperbarui: " .. newName)
                end
            end
            openUnifiedToolManager()
            return true
        end
        return true

    elseif dName == "boren_soil_edit_b_dlg" then
        local saveIdx = btn:match("^boren_save_bkedit_(%d+)$")
        if saveIdx then
            local idx = tonumber(saveIdx)
            if idx and CFG.storage_block_list[idx] then
                local newName = tostring(fields.boren_ed_bkname or ""):gsub("%s+", ""):upper()
                local newDoor = tostring(fields.boren_ed_bkdoor or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if newName ~= "" then
                    CFG.storage_block_list[idx].name = newName
                    CFG.storage_block_list[idx].door = newDoor
                    savePrefs(CFG)
                    saveBlocksToFile()
                    updateBlockDisplayList()
                    addLog(string.format("`2[Edit Gudang Block #%d] `w%s [Door: %s]", idx, newName, (newDoor ~= "" and newDoor or "-")))
                    notifyUser("Gudang Block diperbarui: " .. newName)
                end
            end
            openUnifiedBlockManager()
            return true
        end
        return true
    end

    return false
end

if addHook then
    pcall(addHook, "onvariant", "boren_soil_dlg_var", function(v)
        if v and v[0] == "OnDialogRequest" and v[1] then
            -- Passthrough
        end
    end)
    pcall(addHook, "onsendpacket", "boren_soil_pkt_hook", function(t, str)
        if t == 2 and str and str:find("dialog_name|boren_soil_") then
            onDialogReturnPacket(str)
        end
    end)
end

-- ============================================================================
-- 16. NATIVE GROWLAUNCHER UI BUILDER (6 PROFESSIONAL TABS)
-- ============================================================================
-- Helper UI Builder: memakai UserInterface.new() bawaan GrowLauncher atau fallback JSON resmi
local function createNativeUI(subName, iconName)
    if UserInterface and UserInterface.new then
        local ok, res = pcall(UserInterface.new, subName, iconName)
        if ok and res then return res end
    end

    local ui = { sub_name = subName, icon = iconName, menu = {} }

    function ui:addLabelApp(text, icon)
        table.insert(self.menu, { type = "labelapp", text = text, icon = icon or "" })
        return self
    end

    function ui:addLabel(text)
        table.insert(self.menu, { type = "label", text = text })
        return self
    end

    function ui:addDivider()
        table.insert(self.menu, { type = "divider" })
        return self
    end

    function ui:addToggle(text, default, alias, autosave)
        table.insert(self.menu, { type = "toggle", text = text, default = (default == true or default == 1 or default == "1"), alias = alias, autosave = (autosave == true) })
        return self
    end

    function ui:addToggleButton(text, default, alias)
        table.insert(self.menu, { type = "toggle_button", text = text, default = (default == true or default == 1 or default == "1"), alias = alias })
        return self
    end

    function ui:addButton(text, alias)
        table.insert(self.menu, { type = "button", text = text, alias = alias })
        return self
    end

    function ui:addInputString(text, default, label, placeholder, icon, alias)
        table.insert(self.menu, { type = "input_string", text = text, default = tostring(default or ""), label = label or "Text", placeholder = placeholder or "", icon = icon or "", alias = alias })
        return self
    end

    function ui:addInputInt(text, default, label, placeholder, icon, alias)
        table.insert(self.menu, { type = "input_int", text = text, default = tostring(default or "0"), label = label or "Value", placeholder = placeholder or "0", icon = icon or "", alias = alias })
        return self
    end

    function ui:addSlider(text, minVal, maxVal, defaultVal, stepVal, useDot, alias)
        table.insert(self.menu, { type = "slider", text = text, min = tonumber(minVal) or 0, max = tonumber(maxVal) or 100, default = tonumber(defaultVal) or 0, step = tonumber(stepVal) or 1, use_dot = (useDot == true), alias = alias })
        return self
    end

    function ui:addTooltip(text, supportText, icon, background)
        table.insert(self.menu, { type = "tooltip", text = text, support_text = supportText or "", icon = icon or "Info", background = (background == true) })
        return self
    end

    function ui:addItemPicker(text, item, default, alias)
        table.insert(self.menu, { type = "item_picker", text = text, item = item or "Blank", default = tostring(default or "0"), alias = alias })
        return self
    end

    function ui:addDisplayList(text, default, alias)
        table.insert(self.menu, { type = "display_list", text = text, default = default or "Default", alias = alias })
        return self
    end

    function ui:generateJSON()
        return jsonEncode({ sub_name = self.sub_name, icon = self.icon, menu = self.menu })
    end

    return ui
end

local function addSubModule(uiObj, catName)
    catName = catName or "Boren Farm"
    if not addIntoModule then return end
    local jsonStr = ""
    if type(uiObj) == "string" then
        jsonStr = uiObj
    elseif type(uiObj) == "table" or type(uiObj) == "userdata" then
        if uiObj.generateJSON then
            local okG, resG = pcall(uiObj.generateJSON, uiObj)
            if okG and resG then jsonStr = resG end
        end
    end

    if jsonStr and jsonStr ~= "" then
        local okM, errM = pcall(addIntoModule, jsonStr, catName)
        if not okM and LogToConsole then
            pcall(LogToConsole, "`4[UI Error] addIntoModule gagal: " .. tostring(errM))
        end
    elseif uiObj then
        pcall(addIntoModule, uiObj, catName)
    end
end

local function registerNativeSoilUI()
    if not addCategory or not addIntoModule then
        local warn = "Fungsi addCategory / addIntoModule tidak terdeteksi di runtime ini."
        addLog("`4[UI Warning] `o" .. warn)
        if LogToConsole then pcall(LogToConsole, "`4[UI Warning] `0" .. warn) end
        return
    end

    -- Daftarkan kategori utama "Boren Farm"
    pcall(addCategory, "Boren Farm", "Spa")

    -- Tab 1: Dashboard & World Put
    local uiWorld = createNativeUI("1. Dashboard & World Put", "PlayArrow")
    uiWorld:addLabelApp("Boren Farm Builder", "Spa")
    uiWorld:addToggleButton("▶ Mulai Bot", false, "as_run_power")
    uiWorld:addButton("■ Hentikan Bot", "as_btn_stop")
    uiWorld:addToggle("Jeda Bot", false, "as_pause_toggle", false)
    uiWorld:addDisplayList("Status Operasi", "Default", "as_power_status_list")
    uiWorld:addDivider()
    uiWorld:addLabel("Daftar Antrean World Put (Farm):")
    uiWorld:addInputString("Nama World Put", "", "World", "WORLD1", "Public", "as_input_add_world")
    uiWorld:addInputString("Door ID (Opsional)", "", "Door ID", "Kosong = White Door", "DoorFront", "as_input_add_door")
    uiWorld:addButton("➕ Tambah World Put", "as_btn_add_world")
    uiWorld:addButton("📍 Tambah World Sekarang", "as_btn_add_cur_world")
    uiWorld:addButton("📋 Kelola World Put", "as_btn_manage_worlds")
    uiWorld:addButton("🗑️ Kosongkan World Put", "as_btn_clear_worlds")
    uiWorld:addDivider()
    uiWorld:addLabel("Penyimpanan File Cadangan (Download):")
    uiWorld:addButton("📥 Simpan Antrean ke File", "as_btn_save_worlds")
    uiWorld:addButton("📤 Muat Antrean dari File", "as_btn_load_worlds")
    uiWorld:addDisplayList("Daftar Antrean World Put", "Default", "as_world_display_list")
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
    uiLock:addTooltip("Formasi Proteksi", "Formasi Layout: White Door di (X, Y), Jammer di (X-1, Y), Small Lock di (X-1, Y-1), World Lock di (X-2, Y), dan Wooden Door di koordinat (0, 0) seperti Dirt Farm (DF).", "Verified", false)
    uiLock:addToggle("Aktifkan Proteksi Kunci", CFG.enable_lock_enclosure, "as_chk_enable_lock", true)
    uiLock:addDivider()
    uiLock:addInputInt("ID World Lock", tostring(CFG.lock_id_wl), "ID WL", "242", "Lock", "as_in_id_wl")
    uiLock:addToggle("World Lock Publik", CFG.wl_make_public, "as_chk_wl_public", true)
    uiLock:addDivider()
    uiLock:addInputInt("ID Small Lock", tostring(CFG.lock_id_sl), "ID SL", "202", "Lock", "as_in_id_sl")
    uiLock:addDivider()
    uiLock:addInputInt("ID Signal Jammer", tostring(CFG.lock_id_jammer), "ID Jammer", "226", "WifiTethering", "as_in_id_jammer")
    uiLock:addDivider()
    uiLock:addInputInt("ID Wooden Door (0, 0)", tostring(CFG.lock_id_door), "ID Door", "12 (Wooden Door)", "DoorFront", "as_in_id_door")
    uiLock:addInputString("Label Door ID (0, 0)", CFG.farm_door_id, "Door ID", "BOREN", "Label", "as_in_door_label")
    uiLock:addButton("💾 Simpan Konfigurasi Proteksi", "as_btn_save_lock_cfg")

    -- Tab 3: Gudang Alat
    local uiTool = createNativeUI("3. Gudang Alat", "Build")
    uiTool:addLabelApp("Gudang Alat & Kunci Proteksi", "Build")
    uiTool:addTooltip("Fungsi Gudang Alat", "World khusus penyimpanan stok World Lock, Small Lock, Signal Jammer, dan Wooden Door.", "Info", false)
    uiTool:addInputString("Nama World Alat", "", "World", "GUDANGALAT1", "Build", "as_input_add_tool")
    uiTool:addInputString("Door ID Gudang Alat", "", "Door ID", "DOOR123", "DoorFront", "as_input_add_tool_door")
    uiTool:addButton("➕ Tambah World Alat", "as_btn_add_tool_direct")
    uiTool:addButton("📍 Tambah World Sekarang", "as_btn_add_cur_tool")
    uiTool:addButton("📋 Kelola World Alat", "as_btn_manage_tools")
    uiTool:addButton("🗑️ Kosongkan World Alat", "as_btn_clear_tool_direct")
    uiTool:addDivider()
    uiTool:addLabel("Penyimpanan File Gudang Alat (Download):")
    uiTool:addButton("📥 Simpan Alat ke File", "as_btn_save_tools")
    uiTool:addButton("📤 Muat Alat dari File", "as_btn_load_tools")
    uiTool:addDisplayList("Daftar Gudang Alat", "Default", "as_tool_display_list")

    -- Tab 4: Gudang Block
    local uiBlock = createNativeUI("4. Gudang Block", "Inventory")
    uiBlock:addLabelApp("Gudang Material Block Farm", "Inventory")
    uiBlock:addTooltip("Fungsi Gudang Block", "World khusus penyimpanan floating item Soil Block (ID 8772) atau block lainnya.", "Info", false)
    uiBlock:addInputString("Nama World Block", "", "World", "GUDANGSOIL1", "Inventory", "as_input_add_block")
    uiBlock:addInputString("Door ID Gudang Block", "", "Door ID", "DOOR123", "DoorFront", "as_input_add_block_door")
    uiBlock:addButton("➕ Tambah World Block", "as_btn_add_block_direct")
    uiBlock:addButton("📍 Tambah World Sekarang", "as_btn_add_cur_block")
    uiBlock:addButton("📋 Kelola World Block", "as_btn_manage_blocks")
    uiBlock:addButton("🗑️ Kosongkan World Block", "as_btn_clear_block_direct")
    uiBlock:addDivider()
    uiBlock:addLabel("Penyimpanan File Gudang Block (Download):")
    uiBlock:addButton("📥 Simpan Block ke File", "as_btn_save_blocks")
    uiBlock:addButton("📤 Muat Block dari File", "as_btn_load_blocks")
    uiBlock:addDisplayList("Daftar Gudang Block", "Default", "as_block_display_list")
    uiBlock:addDivider()
    uiBlock:addSlider("Batas Minimum Restock", 10, 100, CFG.restock_threshold, 5, false, "as_in_restock_thresh")

    -- Tab 5: Desain & Layout
    local uiLayout = createNativeUI("5. Desain & Layout", "Build")
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

    -- Tab 6: Konsol & Log
    local uiConsole = createNativeUI("6. Konsol & Log", "Terminal")
    uiConsole:addLabelApp("Konsol Aktivitas Sistem", "Terminal")
    uiConsole:addDisplayList("Status Operasi Sistem", "Default", "as_power_status_list")
    uiConsole:addDivider()
    uiConsole:addButton("🗑️ Bersihkan Riwayat Log", "as_btn_clear_log")
    uiConsole:addDisplayList("Riwayat Log Operasi", "Default", "as_log_display_list")

    -- Registrasi Kategori Tunggal & 6 Sub-Menu Resmi ke GrowLauncher
    addSubModule(uiWorld, "Boren Farm")
    addSubModule(uiLock, "Boren Farm")
    addSubModule(uiTool, "Boren Farm")
    addSubModule(uiBlock, "Boren Farm")
    addSubModule(uiLayout, "Boren Farm")
    addSubModule(uiConsole, "Boren Farm")
end

-- ============================================================================
-- 17. EVENT DISPATCHERS & VALUE HANDLERS
-- ============================================================================
local function readGLString(alias, defaultVal)
    if not getValue then return defaultVal end
    local ok, res = pcall(getValue, alias)
    if ok and res ~= nil and tostring(res) ~= "" then
        return tostring(res)
    end
    return defaultVal
end

local function OnValue(index, name, value)
    if name == "as_run_power" then
        if value == true or value == 1 or value == "1" then
            startSoilBot()
        else
            stopSoilBot()
        end
    elseif name == "as_btn_stop" then
        stopSoilBot()
        if editValue then pcall(editValue, "as_run_power", false) end
    elseif name == "as_pause_toggle" then
        togglePauseSoilBot()
    elseif name == "as_input_add_world" then
        STATE.buf_new_world = tostring(value or "")
    elseif name == "as_input_add_door" then
        STATE.buf_new_door = tostring(value or "")
    elseif name == "as_btn_add_world" then
        local nw = readGLString("as_input_add_world", STATE.buf_new_world)
        local nd = readGLString("as_input_add_door", STATE.buf_new_door)
        nw = nw:gsub("%s+", ""):upper()
        nd = nd:gsub("^%s+", ""):gsub("%s+$", "")
        if nw ~= "" then
            table.insert(CFG.farm_world_list, { name = nw, door = nd, done = false })
            savePrefs(CFG)
            saveWorldsToFile()
            updateWorldDisplayList()
            notifyUser(string.format("World Put %s berhasil ditambahkan!", nw))
            addLog(string.format("`2[Tambah World] `w%s [Door: %s] masuk ke antrean world put.", nw, (nd ~= "" and nd or "-")))
        else
            notifyUser("Nama world put tidak boleh kosong!")
        end
    elseif name == "as_btn_add_cur_world" then
        local curW = getWorldNameSafe()
        if curW ~= "" and curW ~= "EXIT" then
            local nd = readGLString("as_input_add_door", STATE.buf_new_door)
            nd = nd:gsub("^%s+", ""):gsub("%s+$", "")
            table.insert(CFG.farm_world_list, { name = curW, door = nd, done = false })
            savePrefs(CFG)
            saveWorldsToFile()
            updateWorldDisplayList()
            notifyUser(string.format("World aktif %s berhasil ditambahkan ke World Put!", curW))
            addLog(string.format("`2[World Aktif] `w%s otomatis masuk ke antrean world put.", curW))
        else
            notifyUser("Anda sedang berada di luar world (EXIT / Loading)!")
        end
    elseif name == "as_btn_clear_worlds" then
        CFG.farm_world_list = {}
        savePrefs(CFG)
        saveWorldsToFile()
        updateWorldDisplayList()
        notifyUser("Daftar antrean world put dikosongkan!")
        addLog("`4[Kosongkan World] `oDaftar world put berhasil dikosongkan.")
    elseif name == "as_btn_manage_worlds" then
        openUnifiedWorldManager()
    elseif name == "as_btn_save_worlds" then
        saveWorldsToFile()
    elseif name == "as_btn_load_worlds" then
        loadWorldsFromFile()

    -- TAB 2: Proteksi & Kunci
    elseif name == "as_chk_enable_lock" then
        CFG.enable_lock_enclosure = (value == true or value == 1 or value == "1")
        savePrefs(CFG)
        addLog(CFG.enable_lock_enclosure and "`2[Proteksi Kunci] `wFitur diaktifkan." or "`e[Proteksi Kunci] `0Fitur dinonaktifkan.")
    elseif name == "as_in_id_wl" then
        CFG.lock_id_wl = tonumber(value) or CFG.lock_id_wl
    elseif name == "as_chk_wl_public" then
        CFG.wl_make_public = (value == true or value == 1 or value == "1")
    elseif name == "as_in_id_sl" then
        CFG.lock_id_sl = tonumber(value) or CFG.lock_id_sl
    elseif name == "as_in_id_jammer" then
        CFG.lock_id_jammer = tonumber(value) or CFG.lock_id_jammer
    elseif name == "as_in_id_door" then
        CFG.lock_id_door = tonumber(value) or CFG.lock_id_door
    elseif name == "as_in_door_label" then
        CFG.farm_door_id = tostring(value or "")
    elseif name == "as_btn_save_lock_cfg" then
        CFG.lock_id_wl     = tonumber(readGLString("as_in_id_wl", tostring(CFG.lock_id_wl))) or CFG.lock_id_wl
        CFG.lock_id_sl     = tonumber(readGLString("as_in_id_sl", tostring(CFG.lock_id_sl))) or CFG.lock_id_sl
        CFG.lock_id_jammer = tonumber(readGLString("as_in_id_jammer", tostring(CFG.lock_id_jammer))) or CFG.lock_id_jammer
        CFG.lock_id_door   = tonumber(readGLString("as_in_id_door", tostring(CFG.lock_id_door))) or CFG.lock_id_door
        CFG.farm_door_id   = readGLString("as_in_door_label", CFG.farm_door_id)
        savePrefs(CFG)
        notifyUser("Konfigurasi Proteksi Tersimpan!")
        addLog("`2[Simpan Proteksi] `wKonfigurasi kunci pintu (WL, SL, Jammer, Door di 0,0) berhasil disimpan.")

    -- TAB 3: Gudang Alat
    elseif name == "as_input_add_tool" then
        STATE.buf_new_tool = tostring(value or "")
    elseif name == "as_input_add_tool_door" then
        STATE.buf_new_tool_door = tostring(value or "")
    elseif name == "as_btn_add_tool_direct" then
        local ns = readGLString("as_input_add_tool", STATE.buf_new_tool)
        local nd = readGLString("as_input_add_tool_door", STATE.buf_new_tool_door)
        ns = ns:gsub("%s+", ""):upper()
        nd = nd:gsub("^%s+", ""):gsub("%s+$", "")
        if ns ~= "" then
            table.insert(CFG.storage_tool_list, { name = ns, door = nd })
            savePrefs(CFG)
            saveToolsToFile()
            updateToolDisplayList()
            notifyUser(string.format("Gudang Alat %s ditambahkan!", ns))
            addLog(string.format("`2[Gudang Alat] `w%s [Door: %s] berhasil didaftarkan.", ns, (nd ~= "" and nd or "-")))
        else
            notifyUser("Nama world gudang alat tidak boleh kosong!")
        end
    elseif name == "as_btn_add_cur_tool" then
        local curW = getWorldNameSafe()
        if curW ~= "" and curW ~= "EXIT" then
            local nd = readGLString("as_input_add_tool_door", STATE.buf_new_tool_door)
            nd = nd:gsub("^%s+", ""):gsub("%s+$", "")
            table.insert(CFG.storage_tool_list, { name = curW, door = nd })
            savePrefs(CFG)
            saveToolsToFile()
            updateToolDisplayList()
            notifyUser(string.format("World aktif %s masuk ke Gudang Alat!", curW))
            addLog(string.format("`2[Gudang Alat] `w%s otomatis masuk ke Gudang Alat.", curW))
        else
            notifyUser("Anda sedang berada di luar world (EXIT / Loading)!")
        end
    elseif name == "as_btn_clear_tool_direct" then
        CFG.storage_tool_list = {}
        savePrefs(CFG)
        saveToolsToFile()
        updateToolDisplayList()
        notifyUser("Daftar gudang alat dikosongkan!")
        addLog("`4[Kosongkan Alat] `oDaftar gudang alat dikosongkan.")
    elseif name == "as_btn_manage_tools" then
        openUnifiedToolManager()
    elseif name == "as_btn_save_tools" then
        saveToolsToFile()
    elseif name == "as_btn_load_tools" then
        loadToolsFromFile()

    -- TAB 4: Gudang Block
    elseif name == "as_input_add_block" then
        STATE.buf_new_block = tostring(value or "")
    elseif name == "as_input_add_block_door" then
        STATE.buf_new_block_door = tostring(value or "")
    elseif name == "as_btn_add_block_direct" then
        local ns = readGLString("as_input_add_block", STATE.buf_new_block)
        local nd = readGLString("as_input_add_block_door", STATE.buf_new_block_door)
        ns = ns:gsub("%s+", ""):upper()
        nd = nd:gsub("^%s+", ""):gsub("%s+$", "")
        if ns ~= "" then
            table.insert(CFG.storage_block_list, { name = ns, door = nd })
            savePrefs(CFG)
            saveBlocksToFile()
            updateBlockDisplayList()
            notifyUser(string.format("Gudang Block %s ditambahkan!", ns))
            addLog(string.format("`2[Gudang Block] `w%s [Door: %s] berhasil didaftarkan.", ns, (nd ~= "" and nd or "-")))
        else
            notifyUser("Nama world gudang block tidak boleh kosong!")
        end
    elseif name == "as_btn_add_cur_block" then
        local curW = getWorldNameSafe()
        if curW ~= "" and curW ~= "EXIT" then
            local nd = readGLString("as_input_add_block_door", STATE.buf_new_block_door)
            nd = nd:gsub("^%s+", ""):gsub("%s+$", "")
            table.insert(CFG.storage_block_list, { name = curW, door = nd })
            savePrefs(CFG)
            saveBlocksToFile()
            updateBlockDisplayList()
            notifyUser(string.format("World aktif %s masuk ke Gudang Block!", curW))
            addLog(string.format("`2[Gudang Block] `w%s otomatis masuk ke Gudang Block.", curW))
        else
            notifyUser("Anda sedang berada di luar world (EXIT / Loading)!")
        end
    elseif name == "as_btn_clear_block_direct" then
        CFG.storage_block_list = {}
        savePrefs(CFG)
        saveBlocksToFile()
        updateBlockDisplayList()
        notifyUser("Daftar gudang block dikosongkan!")
        addLog("`4[Kosongkan Block] `oDaftar gudang block dikosongkan.")
    elseif name == "as_btn_manage_blocks" then
        openUnifiedBlockManager()
    elseif name == "as_btn_save_blocks" then
        saveBlocksToFile()
    elseif name == "as_btn_load_blocks" then
        loadBlocksFromFile()
    elseif name == "as_in_restock_thresh" then
        CFG.restock_threshold = tonumber(value) or CFG.restock_threshold
        savePrefs(CFG)

    -- TAB 5: Desain & Layout
    elseif name == "as_in_block_id" then
        CFG.block_id = tonumber(value) or CFG.block_id
    elseif name == "as_btn_save_block_id" then
        local bIn = tonumber(readGLString("as_in_block_id", tostring(CFG.block_id)))
        if bIn and bIn > 0 then CFG.block_id = bIn end
        savePrefs(CFG)
        notifyUser(string.format("ID Block %d (%s) tersimpan!", CFG.block_id, getItemNameSafe(CFG.block_id)))
        addLog(string.format("`2[Simpan Block] `wID Block disetel ke %d (%s)", CFG.block_id, getItemNameSafe(CFG.block_id)))
        updatePowerStatusList()
        updateBlockDisplayList()
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
    elseif name == "as_chk_modfly" then
        CFG.use_modfly = (value == true or value == 1 or value == "1")
        applyCheatToggles()
    elseif name == "as_chk_anti_lava" then
        CFG.use_anti_lava = (value == true or value == 1 or value == "1")
        applyCheatToggles()
    elseif name == "as_chk_enable_water" then
        CFG.enable_water_column = (value == true or value == 1 or value == "1")
        savePrefs(CFG)
    elseif name == "as_in_water_id" then
        CFG.water_item_id = tonumber(value) or CFG.water_item_id
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

    -- TAB 6: Konsol & Log
    elseif name == "as_btn_clear_log" then
        STATE.log_messages = {}
        updateLogDisplayList()
        notifyUser("Riwayat log dibersihkan!")
    end
end

-- ============================================================================
-- GLOBAL LISTENER BINDINGS
-- ============================================================================
local ALL_UI_ALIASES = {
    "as_run_power", "as_btn_stop", "as_pause_toggle",
    "as_input_add_world", "as_input_add_door", "as_btn_add_world", "as_btn_add_cur_world", "as_btn_manage_worlds", "as_btn_clear_worlds",
    "as_btn_save_worlds", "as_btn_load_worlds", "as_chk_mode_random", "as_in_rnd_len", "as_chk_rnd_num", "as_in_rnd_prefix", "as_in_rnd_target", "as_chk_auto_blast", "as_in_blast_id",
    "as_chk_enable_lock", "as_in_id_wl", "as_chk_wl_public", "as_in_id_sl", "as_in_id_jammer", "as_in_id_door", "as_in_door_label", "as_btn_save_lock_cfg",
    "as_input_add_tool", "as_input_add_tool_door", "as_btn_add_tool_direct", "as_btn_add_cur_tool", "as_btn_manage_tools", "as_btn_clear_tool_direct", "as_btn_save_tools", "as_btn_load_tools",
    "as_input_add_block", "as_input_add_block_door", "as_btn_add_block_direct", "as_btn_add_cur_block", "as_btn_manage_blocks", "as_btn_clear_block_direct", "as_btn_save_blocks", "as_btn_load_blocks", "as_in_restock_thresh",
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
    pcall(addHook, OnValue, "onvalue")
end
if applyHook then
    pcall(applyHook)
end

-- ============================================================================
-- 18. SYSTEM INITIALIZATION & REGISTRATION
-- ============================================================================
-- 1. Registrasi Menu UI terlebih dahulu agar instan muncul di layar GrowLauncher
registerNativeSoilUI()

-- 2. Muat data cadangan file secara mandiri
pcall(loadWorldsFromFile)
pcall(loadToolsFromFile)
pcall(loadBlocksFromFile)

-- 3. Terapkan cheat & perbarui status tampilan
pcall(applyCheatToggles)
pcall(updatePowerStatusList)
pcall(updateWorldDisplayList)
pcall(updateToolDisplayList)
pcall(updateBlockDisplayList)
pcall(updateLogDisplayList)

addLog("`2[Sistem Siap] `wAuto Soil Builder V2.3.1 Resmi Dimuat.")
notifyUser("Auto Soil Builder Siap!")
