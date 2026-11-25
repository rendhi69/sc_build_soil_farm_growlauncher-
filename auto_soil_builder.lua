-- ============================================================================
-- AUTO SOIL & BLOCK FARM BUILDER - BOREN STORE ( V2.6.0)
-- ============================================================================
-- Framework : GrowLauncher Lua (Android & PC Windows)
-- Arsitektur : Mengadopsi 100% Core Engine & Movement auto_dirt_farm.lua
-- Pemenuhan 9 Poin Instruksi User & Kepatuhan Penuh AGENT.MD:
-- 1. Multi-World Management Antrean World Put (Daftar, Tambah, Edit, Hapus, Salin, Tempel)
-- 2. Multi-World Management Gudang Block & Water (Daftar, Tambah, Edit, Hapus, Salin, Tempel)
-- 3. Multi-World Management Gudang Alat (WL, SL, Jammer, Door, Blocker, Blast)
-- 4. Pengaturan Lock & Door Kustom (Item Door ID, ID Door, Label, dan Item Penghalang Kiri)
-- 5. Formasi Kunci Presisi (Jammer di doorX-1,doorY; SL di doorX-1,doorY-1; WL di doorX-2,doorY; Penghalang di doorX-2,doorY-1; Door di 0,0)
-- 6. Penempatan Baris Soil Farm & Kolom Water Elevator Vertikal (Toggle true/false)
-- 7. Movement Engine moveSafeTo & moveAdjacentSafe persis 100% dari auto_dirt_farm.lua
-- 8. Placement Engine placeTileAt & sendRawAction persis 100% dari auto_dirt_farm.lua
-- 9. Warp Engine warpTo dengan 5x retry, verifikasi nama world, dan jeda aman
-- ============================================================================

-- 1. IDENTITAS ITEM & GLOBAL CONSTANTS
-- STANDAR DATABASE RESMI GROWTOPIA / LUCIFER (100% PERSIS items.dat)
local ITEM = {
    WORLD_LOCK     = 242,
    SMALL_LOCK     = 202,
    BIG_LOCK       = 204,
    HUGE_LOCK      = 206,
    BUILDER_LOCK   = 4994,
    JAMMER         = 226,
    AIR_VENT       = 2810, --  ID 2810 (Air Vent)
    DOOR           = 12,
    MAIN_DOOR      = 6,    -- White Door
    WHITE_DOOR     = 6,
    BEDROCK        = 8,
    DIRT           = 2,
    ROCK           = 10,
    LAVA           = 4,
    SOIL_BLOCK     = 8772, -- Fertile Soil Block
    WATER          = 822,  --  ID 822 (Water Bucket)
    TermonuclearBlat = 1402,
    BLAST_CAVE     = 3562, --  ID 3562 (Cave Blast)
    BLAST_BEACH    = 830,  -- Beach Blast
    BLAST_HARVEST  = 1060, -- Harvest Blast
    PUNCH          = 18,
    WRENCH         = 32,
    WOOD_PLATFORM  = 102,  --  ID 102 (Wooden Platform)
    DUNGEON_DOOR   = 30,   --  ID 30 (Dungeon Door)
    PORTAL         = 544,  --  ID 544 (Orange Portal)
    PORTAL_BLUE    = 546,  --  ID 546 (Blue Portal)
    HOUSE_ENTRANCE = 224,  --  ID 224 (House Entrance)
    SCREEN_DOOR    = 858,  --  ID 858 (Screen Door)
    PORTCULLIS     = 60,   --  ID 60 (Portcullis)
}

local OTHER_LOCKS = {
    [ITEM.WORLD_LOCK]   = true,
    [ITEM.SMALL_LOCK]   = true,
    [ITEM.BIG_LOCK]     = true,
    [ITEM.HUGE_LOCK]    = true,
    [ITEM.BUILDER_LOCK] = true,
}

local KNOWN_ID_DOOR_IDS = {
    [12]   = true, -- Wooden Door
    [6]    = true, -- White Door / Main Door
    [30]   = true, -- Dungeon Door
    [60]   = true, -- Portcullis
    [224]  = true, -- House Entrance
    [544]  = true, -- Orange Portal
    [546]  = true, -- Blue Portal
    [858]  = true, -- Screen Door
    [2810] = true, -- Air Vent
}

local KNOWN_BLOCKER_IDS = {
    [2810] = true, -- Air Vent (Standar Lucifer)
    [12]   = true, -- Wooden Door
    [30]   = true, -- Dungeon Door
    [60]   = true, -- Portcullis
    [224]  = true, -- House Entrance
    [858]  = true, -- Screen Door
    [544]  = true, -- Orange Portal
    [546]  = true, -- Blue Portal
}

local function isDoorOrEntranceItem(id, name)
    id = tonumber(id) or 0
    if KNOWN_BLOCKER_IDS[id] or KNOWN_ID_DOOR_IDS[id] then
        return true
    end
    local lower = tostring(name or ""):lower()
    if lower:find("door") or lower:find("entrance") or lower:find("portal") or lower:find("portcullis") or lower:find("gate") or lower:find("vent") then
        return true
    end
    return false
end

local DOOR_ID_PRESETS = {
    { id = 12,   name = "Wooden Door (12)" },
    { id = 30,   name = "Dungeon Door (30)" },
    { id = 544,  name = "Orange Portal (544)" },
    { id = 224,  name = "House Entrance (224)" },
    { id = 2810, name = "Air Vent (2810)" },
}

local BLOCKER_DOOR_PRESETS = {
    { id = 2810, name = "Air Vent (2810)" },
    { id = 12,   name = "Wooden Door (12)" },
    { id = 30,   name = "Dungeon Door (30)" },
    { id = 60,   name = "Portcullis (60)" },
    { id = 224,  name = "House Entrance (224)" },
    { id = 858,  name = "Screen Door (858)" },
    { id = 544,  name = "Orange Portal (544)" },
}

local ITEM_NAME_CACHE = {
    [0]    = "Blank",
    [2]    = "Dirt",
    [3]    = "Dirt Seed",
    [4]    = "Lava",
    [5]    = "Lava Seed",
    [6]    = "White Door",
    [8]    = "Bedrock",
    [10]   = "Rock",
    [11]   = "Rock Seed",
    [12]   = "Wooden Door",
    [13]   = "Wooden Door Seed",
    [18]   = "Fist",
    [30]   = "Dungeon Door",
    [31]   = "Dungeon Door Seed",
    [32]   = "Wrench",
    [60]   = "Portcullis",
    [61]   = "Portcullis Seed",
    [102]  = "Wooden Platform",
    [103]  = "Wooden Platform Seed",
    [202]  = "Small Lock",
    [204]  = "Big Lock",
    [206]  = "Huge Lock",
    [224]  = "House Entrance",
    [225]  = "House Entrance Seed",
    [226]  = "Signal Jammer",
    [242]  = "World Lock",
    [544]  = "Orange Portal",
    [546]  = "Blue Portal",
    [822]  = "Water Bucket",
    [830]  = "Beach Blast",
    [858]  = "Screen Door",
    [859]  = "Screen Door Seed",
    [1060] = "Harvest Blast",
    [1796] = "Diamond Lock",
    [2810] = "Air Vent",
    [2811] = "Air Vent Seed",
    [3562] = "Cave Blast",
    [4994] = "Builder's Lock",
    [8772] = "Fertile Soil",
    [8773] = "Fertile Soil Seed",
}

-- 2. SAFE ENVIRONMENT HELPERS & PREFERENCE STORAGE
local function safeDate(fmt)
    if type(os) == "table" and type(os.date) == "function" then
        local ok, res = pcall(os.date, fmt or "%H:%M:%S")
        if ok and res then return tostring(res) end
    end
    return "--:--:--"
end

local function safeClock()
    if type(os) == "table" and type(os.clock) == "function" then
        local ok, c = pcall(os.clock)
        if ok and type(c) == "number" then return c end
    end
    return 0
end

local function safeReadFile(path)
    if readFile and type(readFile) == "function" then
        local ok, data = pcall(readFile, path)
        if ok and data and data ~= "" then return data end
    end
    if io and type(io.open) == "function" then
        local okF, f = pcall(io.open, path, "r")
        if okF and f then
            local data = f:read("*a")
            f:close()
            return data
        end
    end
    return nil
end

local function safeWriteFile(path, content)
    if writeFile and type(writeFile) == "function" then
        local ok = pcall(writeFile, path, content)
        if ok then return true end
    end
    if io and type(io.open) == "function" then
        local okF, f = pcall(io.open, path, "w")
        if okF and f then
            f:write(content)
            f:close()
            return true
        end
    end
    return false
end

local PREF_FILE = "boren_soil_builder_pref.json"

local function jsonEncode(tbl)
    if JSON and JSON.stringify then
        local ok, res = pcall(JSON.stringify, tbl)
        if ok and res then return res end
    end
    if json and json.encode then
        local ok, res = pcall(json.encode, tbl)
        if ok and res then return res end
    end
    local function serialize(val)
        local t = type(val)
        if t == "number" or t == "boolean" then
            return tostring(val)
        elseif t == "string" then
            return string.format("%q", val)
        elseif t == "table" then
            local isArray = (#val > 0)
            local elems = {}
            if isArray then
                for _, v in ipairs(val) do
                    table.insert(elems, serialize(v))
                end
                return "[" .. table.concat(elems, ",") .. "]"
            else
                for k, v in pairs(val) do
                    table.insert(elems, string.format("%q:%s", tostring(k), serialize(v)))
                end
                return "{" .. table.concat(elems, ",") .. "}"
            end
        else
            return "null"
        end
    end
    return serialize(tbl)
end

local function jsonDecode(str)
    if not str or str == "" then return nil end
    if JSON and JSON.parse then
        local ok, res = pcall(JSON.parse, str)
        if ok and res then return res end
    end
    if json and json.decode then
        local ok, res = pcall(json.decode, str)
        if ok and res then return res end
    end
    return nil
end

local function loadPrefData()
    local content = safeReadFile(PREF_FILE)
    if content and content ~= "" then
        local data = jsonDecode(content)
        if type(data) == "table" then return data end
    end
    return {}
end

local PREFS = loadPrefData()
local function getPref(key, defaultVal)
    if PREFS[key] ~= nil then return PREFS[key] end
    return defaultVal
end

local function savePrefData(tbl)
    PREFS = tbl or PREFS
    safeWriteFile(PREF_FILE, jsonEncode(PREFS))
end

-- 3. GLOBAL CONFIGURATION (CFG)
local CFG = {
    world_mode          = getPref("world_mode", "manual"), -- "manual" / "random"
    farm_world_list     = getPref("farm_world_list", {}),  -- 1. Multi World Put Antrean
    storage_tool_list   = getPref("storage_tool_list", {}),-- 3. Multi World Gudang Alat
    storage_block_list  = getPref("storage_block_list", {}),-- 2. Multi World Gudang Block & Water

    manual_world_text   = getPref("manual_world_text", ""),
    manual_door_text    = getPref("manual_door_text", ""),
    world_file_name     = getPref("world_file_name", "boren_soil_worlds.txt"),

    block_id            = tonumber(getPref("block_id", 8772)) or 8772, -- Default Soil Block: 8772

    -- 6. Fitur Water Column (Toggle true / false)
    enable_water        = (getPref("enable_water", false) == true),
    water_item_id       = tonumber(getPref("water_item_id", 822)) or 822, --  822 (Water Bucket)
    water_x             = tonumber(getPref("water_x", 0)) or 0,

    -- 4 & 5. Lock & Door Enclosure (Kustom Door & Penghalang)
    ignore_lock         = (getPref("ignore_lock", false) == true),
    use_wl              = (getPref("use_wl", true) == true),
    wl_public           = (getPref("wl_public", true) == true),
    use_sl              = (getPref("use_sl", true) == true),
    sl_ignore_air       = (getPref("sl_ignore_air", true) == true),
    sl_public           = (getPref("sl_public", false) == true),
    use_jammer          = (getPref("use_jammer", true) == true),
    use_id_door         = (getPref("use_id_door", true) == true),
    id_door_itemid      = tonumber(getPref("id_door_itemid", ITEM.WOODEN_DOOR)) or ITEM.WOODEN_DOOR,
    door_id             = getPref("door_id", "SOIL"),
    door_label          = getPref("door_label", "SOIL"),
    delay_tele_door     = tonumber(getPref("delay_tele_door", 1500)) or 1500,

    use_blocker_door    = (getPref("use_blocker_door", true) == true),
    blocker_door_itemid = tonumber(getPref("blocker_door_itemid", ITEM.AIR_VENT)) or ITEM.AIR_VENT,

    -- Auto Blast Settings
    auto_use_blast      = (getPref("auto_use_blast", false) == true),
    blast_item_id       = tonumber(getPref("blast_item_id", 3562)) or 3562, --  3562 (Cave Blast)

    -- Random World Settings
    random_target_count = tonumber(getPref("random_target_count", 5)) or 5,
    random_length       = tonumber(getPref("random_length", 6)) or 6,
    random_use_numbers  = (getPref("random_use_numbers", true) == true),

    -- Layout Grid Baris (Standar Soil Farm: 27 baris di Y ganjil 1..53)
    row_step            = tonumber(getPref("row_step", 2)) or 2,
    row_start_y         = tonumber(getPref("row_start_y", 1)) or 1, -- Space tanam baris teratas (Y=0) sejajar Door ID (0,0)
    row_end_y           = tonumber(getPref("row_end_y", 53)) or 53, -- Baris terbawah (Y=53) di atas Bedrock (Y=54) & sejajar WL/Jammer
    row_start_x         = tonumber(getPref("row_start_x", 1)) or 1,
    row_end_x           = tonumber(getPref("row_end_x", 98)) or 98, -- Kolom 99 selalu KOSONG untuk jalur lewat
    put_mode            = getPref("put_mode", "3zigzag"), -- "3zigzag" | "1by1"

    -- Delays & Movement Cheats
    delay_place         = tonumber(getPref("delay_place", 120)) or 120,
    delay_walk          = tonumber(getPref("delay_walk", 140)) or 140,
    delay_punch         = tonumber(getPref("delay_punch", 160)) or 160,
    delay_warp          = tonumber(getPref("delay_warp", 4000)) or 4000,
    use_modfly          = (getPref("use_modfly", true) == true),
    use_antilava        = (getPref("use_antilava", true) == true),
    auto_collect        = (getPref("auto_collect", true) == true),
    collect_range       = tonumber(getPref("collect_range", 3)) or 3,
}

local function persistConfig()
    savePrefData(CFG)
end

-- Auto-Migrasi ID lama yang salah ke ID resmi Growtopia / Lucifer
if CFG.blocker_door_itemid == 828 then CFG.blocker_door_itemid = 2810 end
if CFG.water_item_id == 818 then CFG.water_item_id = 822 end
if CFG.blast_item_id == 1336 or CFG.blast_item_id == 2810 then CFG.blast_item_id = 3562 end


-- Bersihkan entri rusak "0" / kosong hasil bug form lama (world:0) dari config tersimpan
do
    local function sanitizeWorldList(list)
        local out = {}
        if type(list) ~= "table" then return out end
        for _, it in ipairs(list) do
            if type(it) == "table" then
                local n = tostring(it.name or ""):upper():gsub("%s+", "")
                local d = tostring(it.door or ""):gsub("%s+", "")
                if d == "0" then d = "" end
                if n ~= "" and n ~= "0" and n ~= "EXIT" then
                    it.name = n
                    it.door = d
                    table.insert(out, it)
                end
            end
        end
        return out
    end
    CFG.farm_world_list    = sanitizeWorldList(CFG.farm_world_list)
    CFG.storage_tool_list  = sanitizeWorldList(CFG.storage_tool_list)
    CFG.storage_block_list = sanitizeWorldList(CFG.storage_block_list)
    if CFG.manual_world_text == "0" then CFG.manual_world_text = "" end
    if CFG.manual_door_text == "0" then CFG.manual_door_text = "" end
    if CFG.row_end_x >= 99 then CFG.row_end_x = 98 end
    if CFG.row_start_x == 2 then CFG.row_start_x = 1 end
    if CFG.row_start_y == 2 then CFG.row_start_y = 1 end
    if CFG.row_end_y == 54 or CFG.row_end_y >= 54 then CFG.row_end_y = 53 end
end

-- 4. RUNTIME BOT STATE
local STATE = {
    running              = false,
    paused               = false,
    active_world         = "",
    active_door          = "",
    active_row           = 2,
    active_col           = 2,
    worlds_completed     = 0,
    total_placed_blocks  = 0,
    current_status_title = "Siap",
    current_status_desc  = "Menunggu perintah START.",
    buf_world_name       = "",
    buf_world_door       = "",
    buf_tool_name        = "",
    buf_tool_door        = "",
    buf_block_name       = "",
    buf_block_door       = "",
    last_log_lines       = {},
}

-- Forward declarations
local updatePowerStatusList
local updateWorldDisplayList
local updateToolDisplayList
local updateBlockDisplayList
local updateBagDisplayList
local openUnifiedWorldManager
local openUnifiedToolManager
local openUnifiedBlockManager
local openEditWorldEntryDialog
local openEditToolEntryDialog
local openEditBlockEntryDialog
local syncInputsFromGL
local refreshNativeDisplayLists

-- 5. RESOLVER NAMA ITEM & LOGGING HELPERS
local function resolveItemName(itemID)
    itemID = tonumber(itemID) or 0
    if itemID <= 0 then return "None" end
    -- 1. Cek native GrowLauncher engine (langsung baca items.dat aktif persis Lucifer)
    if getItemInfoByID then
        local ok, info = pcall(getItemInfoByID, itemID)
        if ok and info and type(info.name) == "string" and info.name ~= "" and not info.name:find("Unknown") then
            return info.name
        end
    end
    if growtopia and growtopia.getItemName then
        local ok, n = pcall(growtopia.getItemName, itemID)
        if ok and n and n ~= "" and not tostring(n):find("Unknown") then
            return tostring(n)
        end
    end
    if getItemName then
        local ok, n = pcall(getItemName, itemID)
        if ok and n and n ~= "" and not n:find("Unknown") then
            return n
        end
    end
    -- 2. Fallback: Standar Cache Lucifer
    if ITEM_NAME_CACHE[itemID] then return ITEM_NAME_CACHE[itemID] end
    return "Item #" .. tostring(itemID)
end

local function cleanItemName(name)
    if type(name) ~= "string" then return "" end
    return (name:gsub("`.", ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function lookupItemIDByName(name)
    local clean = cleanItemName(name)
    if clean == "" then return nil end

    local embeddedId = clean:match("%((%d+)%)") or clean:match("#(%d+)")
    if embeddedId and tonumber(embeddedId) and tonumber(embeddedId) > 0 then
        return tonumber(embeddedId)
    end

    local cleanLow = clean:lower()
    for id, n in pairs(ITEM_NAME_CACHE) do
        if n and cleanItemName(n):lower() == cleanLow then
            return id
        end
    end
    for _, def in ipairs(BLOCKER_DOOR_PRESETS) do
        if def.name and cleanItemName(def.name):lower():find(cleanLow, 1, true) then
            return def.id
        end
    end
    for _, def in ipairs(DOOR_ID_PRESETS) do
        if def.name and cleanItemName(def.name):lower():find(cleanLow, 1, true) then
            return def.id
        end
    end

    if getItemInfoByName then
        local ok, info = pcall(getItemInfoByName, clean)
        if ok and info and tonumber(info.id) and tonumber(info.id) > 0 then
            return tonumber(info.id)
        end
    end

    if itemInfoManager and itemInfoManager.getItemInfoByName then
        local ok, info = pcall(itemInfoManager.getItemInfoByName, clean)
        if ok and info and tonumber(info.id) and tonumber(info.id) > 0 then
            return tonumber(info.id)
        end
    end

    if findItemID then
        local ok, id = pcall(findItemID, clean)
        if ok and tonumber(id) and tonumber(id) > 0 then
            return tonumber(id)
        end
    end

    if growtopia and growtopia.getItemID then
        local ok, id = pcall(growtopia.getItemID, clean)
        if ok and tonumber(id) and tonumber(id) > 0 then
            return tonumber(id)
        end
    end

    return nil
end

local function resolvePickedItemID(value)
    if not value or value == "" then return nil end
    local vType = type(value)
    if vType == "table" or vType == "userdata" then
        local ok, v = pcall(function()
            return value.id or value.itemID or value.itemid or value.item_id or value.value or value.item or value.name
        end)
        if ok and v ~= nil then value = v end
    end
    local num = tonumber(value)
    if num and num > 0 then
        return math.floor(num)
    end
    if type(value) == "string" and value ~= "" then
        local clean = cleanItemName(value)
        local sNum = tonumber(clean)
        if sNum and sNum > 0 then
            return math.floor(sNum)
        end
        local leadNum = clean:match("^(%d+)")
        if leadNum and tonumber(leadNum) and tonumber(leadNum) > 0 then
            return math.floor(tonumber(leadNum))
        end
        local embedNum = clean:match("%((%d+)%)") or clean:match("#(%d+)") or clean:match("(%d+)")
        if embedNum and tonumber(embedNum) and tonumber(embedNum) > 0 then
            return math.floor(tonumber(embedNum))
        end
        local lookedUp = lookupItemIDByName(clean)
        if lookedUp and lookedUp > 0 then
            return lookedUp
        end
    end
    return nil
end

local function parseWorldEntryToken(rawToken, defaultDoor)
    local clean = tostring(rawToken or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if clean == "" or clean:sub(1, 1) == "#" then return nil end

    local body = clean
    local isDone = false
    local statusTag = nil

    local b1, tag1 = clean:match("^(.-)[|:](DONE)$")
    if not b1 then b1, tag1 = clean:match("^(.-)[|:](done)$") end
    if not b1 then b1, tag1 = clean:match("^(.-)[|:](PROSES)$") end
    if not b1 then b1, tag1 = clean:match("^(.-)[|:](ANTRI)$") end
    if not b1 then b1, tag1 = clean:match("^(.-)|([01])$") end
    if b1 and tag1 then
        body = b1
        statusTag = tag1:upper()
        isDone = (statusTag == "DONE" or statusTag == "1")
    end

    local wName, dId = body:match("^([^|:]+)[|:](.*)$")
    if not wName then
        wName = body
        dId = defaultDoor or ""
    end
    wName = wName:upper():gsub("%s+", "")
    dId = (dId or ""):gsub("%s+", "")
    if wName == "" or wName == "EXIT" or wName == "0" then return nil end
    if dId == "0" then dId = "" end

    return {
        name = wName,
        door = dId,
        done = isDone,
        status = isDone and "DONE" or "ANTRI",
    }
end

local function addManualWorldsFromString(rawWorldStr, defaultDoorStr, clearExisting)
    local s = tostring(rawWorldStr or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local defDoor = tostring(defaultDoorStr or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then
        if clearExisting then CFG.farm_world_list = {} end
        return 0
    end

    if clearExisting then
        CFG.farm_world_list = {}
    end

    local addedCount = 0
    for token in s:gmatch("[^,;\r\n]+") do
        local parsed = parseWorldEntryToken(token, defDoor)
        if parsed then
            local found = false
            for _, existing in ipairs(CFG.farm_world_list) do
                if existing.name == parsed.name then
                    existing.door = parsed.door
                    existing.done = parsed.done
                    existing.status = parsed.status
                    found = true
                    break
                end
            end
            if not found then
                table.insert(CFG.farm_world_list, parsed)
            end
            addedCount = addedCount + 1
        end
    end

    if addedCount > 0 then
        CFG.world_mode = "manual"
        persistConfig()
    end
    return addedCount
end

local function addLog(msg)
    local timestamp = safeDate("%H:%M:%S")
    local line = string.format("[%s] %s", timestamp, tostring(msg or ""))
    table.insert(STATE.last_log_lines, 1, line)
    while #STATE.last_log_lines > 40 do
        table.remove(STATE.last_log_lines)
    end
    if log then pcall(log, line) end
    if print then pcall(print, line) end
end

local function setStatus(title, desc)
    STATE.current_status_title = tostring(title or "")
    STATE.current_status_desc  = tostring(desc or "")
    if updatePowerStatusList then pcall(updatePowerStatusList) end
end

local function safeSleep(ms)
    ms = tonumber(ms) or 50
    if ms < 10 then ms = 10 end
    if sleep then
        pcall(sleep, ms)
    elseif Sleep then
        pcall(Sleep, ms)
    elseif CSleep then
        pcall(CSleep, ms)
    end
end

local function waitIfPaused()
    while STATE.paused and STATE.running do
        safeSleep(300)
    end
    return STATE.running
end

-- 6. POSISI PEMAIN, WORLD & INVENTORY
local function getPlayerTilePos()
    local x, y = 0, 0
    if getLocal then
        local ok, me = pcall(getLocal)
        if ok and me and me.pos then
            x = math.floor((me.pos.x + 10) / 32)
            y = math.floor((me.pos.y + 10) / 32)
            return x, y
        end
    end
    if getPlayer then
        local ok, me = pcall(getPlayer)
        if ok and me and me.pos then
            x = math.floor((me.pos.x + 10) / 32)
            y = math.floor((me.pos.y + 10) / 32)
            return x, y
        end
    end
    return 0, 0
end

local function getWorldNameSafe()
    if getCurrentWorldName then
        local ok, n = pcall(getCurrentWorldName)
        if ok and n and n ~= "" then return n:upper() end
    end
    if getWorld then
        local ok, w = pcall(getWorld)
        if ok and w and w.name and w.name ~= "" then return w.name:upper() end
    end
    if getLocal then
        local ok, me = pcall(getLocal)
        if ok and me and me.world and me.world ~= "" then return me.world:upper() end
    end
    return ""
end

-- ===================== ROBUST INVENTORY & WORLD OBJECT ENGINE =====================
-- Sesuai dokumentasi resmi GrowLauncher (docs/namespaces/growtopia.md, docs/structs/game-objects.md):
-- 1. InventoryItem memiliki { id, amount }
-- 2. getInventory() mengembalikan InventoryItem[] (dapat berupa table maupun Sol2 userdata container)
-- 3. growtopia.checkInventory(itemid) -> boolean (Cek native C++ apakah player memiliki item)
-- 4. growtopia.checkInventoryCount(itemid) -> number (Hitung total item via C++ memory)
-- 5. getObjectList() / getObjects() -> WorldObject[] ({ id, itemid, amount, pos={x, y} })

local function readInvItemFields(it)
    local t = type(it)
    if t ~= "table" and t ~= "userdata" then return nil, nil end
    local id, amt = nil, nil
    pcall(function() id = tonumber(it.id or it.itemid or it.itemID or it.item_id) end)
    pcall(function() amt = tonumber(it.amount or it.count or it.cnt) end)
    return id, amt
end

local function getRawInventory()
    if not getInventory then return nil end
    local ok, inv = pcall(getInventory)
    if not ok or inv == nil then return nil end
    local t = type(inv)
    if t ~= "table" and t ~= "userdata" then return nil end
    local items = nil
    pcall(function() items = inv.items end)
    if items ~= nil and (type(items) == "table" or type(items) == "userdata") then return items end
    return inv
end

local function forEachInvItem(fn)
    local inv = getRawInventory()
    if not inv then return 0 end
    local seen = 0
    pcall(function()
        for _, it in pairs(inv) do
            local id, amt = readInvItemFields(it)
            if id and id > 0 then
                seen = seen + 1
                fn(id, amt or 0)
            end
        end
    end)
    if seen == 0 then
        local okLen, n = pcall(function() return #inv end)
        if not okLen or not n or n <= 0 then pcall(function() n = inv:size() end) end
        local maxI = (n and tonumber(n) and tonumber(n) > 0) and tonumber(n) or 400
        local misses = 0
        for i = 0, maxI do
            local okI, it = pcall(function() return inv[i] end)
            local id, amt = nil, nil
            if okI then id, amt = readInvItemFields(it) end
            if id and id > 0 then
                misses = 0
                seen = seen + 1
                fn(id, amt or 0)
            else
                misses = misses + 1
                if misses >= 50 and i > 5 then break end
            end
        end
    end
    return seen
end

local function getInvCount(itemID)
    local targetID = tonumber(itemID) or 0
    if targetID <= 0 then return 0 end

    -- A. C++ native GrowLauncher count (paling cepat & akurat jika sinkron)
    local nativeCnt = 0
    if growtopia and growtopia.checkInventoryCount then
        local ok, cnt = pcall(growtopia.checkInventoryCount, targetID)
        if ok and tonumber(cnt) and tonumber(cnt) > 0 then
            return tonumber(cnt)
        end
    end

    -- B. Scan memori tas (mendukung Lua table, nested .items, dan Sol2 userdata vector)
    local total = 0
    forEachInvItem(function(id, amt)
        if id == targetID and amt > 0 then total = total + amt end
    end)
    if total > 0 then return total end

    -- C. Fallback otoritatif C++ boolean dari GrowLauncher (docs/namespaces/growtopia.md)
    -- Jika checkInventoryCount mengembalikan 0 karena lag sync packet, checkInventory() tetap true jika item ada di tas!
    if growtopia and growtopia.checkInventory then
        local ok, has = pcall(growtopia.checkInventory, targetID)
        if ok and has == true then
            return 1
        end
    end

    return 0
end

local function forEachWorldObject(fn)
    local getFn = getObjectList or getObjects or getWorldObjects
    if not getFn then return 0 end
    local ok, objs = pcall(getFn)
    if not ok or not objs then return 0 end

    local container = objs
    pcall(function()
        if type(objs) == "table" and objs.objects then container = objs.objects end
    end)

    local seen = 0
    local function processObj(obj)
        if not obj then return end
        local itemid, uid, amt, px, py = nil, nil, nil, nil, nil
        pcall(function() itemid = tonumber(obj.itemid or obj.itemId or obj.item_id) end)
        pcall(function() uid = tonumber(obj.id or obj.oid or obj.netid) end)
        pcall(function() amt = tonumber(obj.amount or obj.count) or 1 end)
        pcall(function()
            if obj.pos then
                px = tonumber(obj.pos.x or obj.pos[1])
                py = tonumber(obj.pos.y or obj.pos[2])
            end
        end)
        if not px then pcall(function() px = tonumber(obj.x or obj.posX) end) end
        if not py then pcall(function() py = tonumber(obj.y or obj.posY) end) end

        if itemid and itemid > 0 and uid and px and py then
            seen = seen + 1
            fn(itemid, uid, amt, px, py, obj)
        end
    end

    pcall(function()
        for _, obj in pairs(container) do
            processObj(obj)
        end
    end)

    if seen == 0 then
        local okLen, n = pcall(function() return #container end)
        if not okLen or not n or n <= 0 then pcall(function() n = container:size() end) end
        local maxI = (n and tonumber(n) and tonumber(n) > 0) and tonumber(n) or 1000
        local misses = 0
        for i = 0, maxI do
            local okI, obj = pcall(function() return container[i] end)
            if okI and obj then
                local prev = seen
                processObj(obj)
                if seen > prev then misses = 0 else misses = misses + 1 end
                if misses >= 50 and i > 10 then break end
            else
                misses = misses + 1
                if misses >= 50 and i > 10 then break end
            end
        end
    end
    return seen
end

local function findWorldObjectsByItemID(targetID)
    targetID = tonumber(targetID) or 0
    if targetID <= 0 then return {} end
    local list = {}
    forEachWorldObject(function(itemid, uid, amt, px, py, obj)
        if itemid == targetID then
            table.insert(list, {
                itemid = itemid,
                id     = uid,
                amount = amt,
                x      = px,
                y      = py,
                tileX  = math.floor((px + 10) / 32),
                tileY  = math.floor((py + 10) / 32),
                raw    = obj,
            })
        end
    end)
    return list
end

local function logInventoryDiagnostic(idList, tag)
    local invType = "nil"
    if getInventory then
        local ok, inv = pcall(getInventory)
        invType = ok and type(inv) or ("err:" .. tostring(inv))
    end
    local slots = forEachInvItem(function() end)
    local parts = {}
    for _, id in ipairs(idList or {}) do
        id = tonumber(id) or 0
        if id > 0 then
            local nat = "-"
            if growtopia and growtopia.checkInventoryCount then
                local ok, c = pcall(growtopia.checkInventoryCount, id)
                nat = ok and tostring(c) or "err"
            end
            local hasBool = false
            if growtopia and growtopia.checkInventory then
                local ok, h = pcall(growtopia.checkInventory, id)
                hasBool = ok and h
            end
            local sc = 0
            forEachInvItem(function(i, a) if i == id then sc = sc + a end end)
            table.insert(parts, string.format("#%d[nat:%s,has:%s,scan:%d]", id, nat, tostring(hasBool), sc))
        end
    end
    addLog(string.format("`o[BP Diag%s] invType=%s slots=%d | %s",
        tag and (" " .. tag) or "", invType, slots, table.concat(parts, ", ")))
end

local function getWorldObjectsSafe()
    local list = {}
    forEachWorldObject(function(itemid, uid, amt, px, py, obj)
        table.insert(list, obj)
    end)
    return list
end

local function collectNearbyFloating(centerX, centerY, customRadius, quickMode, forceCollect)
    if ((not CFG.auto_collect) and (not forceCollect)) then return 0 end
    local objs = getWorldObjectsSafe()
    if not objs then return 0 end

    local px, py = getPlayerTilePos()
    local refX = centerX or px
    local refY = centerY or py
    if not refX or not refY then return 0 end

    local radius = customRadius or CFG.collect_range or 3
    local collected = 0

    for _, obj in pairs(objs) do
        if not STATE.running then break end
        if obj then
            local objId = obj.id or obj.oid or obj.netid
            local posX = (obj.pos and obj.pos.x) or obj.x or obj.posX
            local posY = (obj.pos and obj.pos.y) or obj.y or obj.posY
            local itemid = obj.itemid or obj.itemId or obj.item_id or 0

            if objId and posX and posY then
                local ox = math.floor((posX + 10) / 32)
                local oy = math.floor((posY + 10) / 32)
                local dist = math.max(math.abs(ox - refX), math.abs(oy - refY))

                if dist <= radius and itemid ~= ITEM.LAVA then
                    local curAmt = getInvCount(itemid)
                    if curAmt < 200 then
                        local curPx, curPy = getPlayerTilePos()
                        local pDist = (curPx and curPy) and math.max(math.abs(ox - curPx), math.abs(oy - curPy)) or 99
                        local needWalk = (not quickMode and pDist > 1) or (pDist > 2)
                        if needWalk and isTileSafeToStand(ox, oy) then
                            moveSafeTo(ox, oy)
                        end
                        pcall(sendPacketRaw, false, {
                            type  = 11,
                            value = objId,
                            x     = posX,
                            y     = posY,
                        })
                        if not quickMode then
                            safeSleep(20)
                        end
                        collected = collected + 1
                    end
                end
            end
        end
    end
    return collected
end

local function findMainDoor()
    for attempt = 1, 15 do
        if not STATE.running then break end
        for y = 0, 59 do
            for x = 0, 99 do
                local ok, t = pcall(getTile, x, y)
                if ok and t and t.fg == ITEM.MAIN_DOOR then
                    return x, y
                end
            end
        end
        safeSleep(300)
    end
    return nil, nil
end

-- ============================================================================
-- 7. MOVEMENT & PLACE ENGINE PERSIS 100% DARI AUTO_DIRT_FARM.LUA (Poin 7 & 8)
-- ============================================================================
local function isTileSafeToStand(tx, ty)
    if tx < 0 or tx > 99 or ty < 0 or ty > 53 then
        return false
    end
    local ok, t = pcall(getTile, tx, ty)
    if not ok or not t then return false end

    local fg = t.fg or 0
    if fg == ITEM.LAVA then
        return false
    end
    if fg ~= 0
       and fg ~= ITEM.MAIN_DOOR
       and fg ~= ITEM.DOOR
       and fg ~= ITEM.DUNGEON_DOOR
       and fg ~= ITEM.PORTAL
       and fg ~= ITEM.AIR_VENT
       and fg ~= ITEM.HOUSE_ENTRANCE
       and fg ~= ITEM.SCREEN_DOOR
       and fg ~= ITEM.PORTCULLIS
       and fg ~= ITEM.WOOD_PLATFORM
       and fg ~= CFG.id_door_itemid
       and fg ~= CFG.blocker_door_itemid then
        if t.collidable or fg == ITEM.DIRT or fg == ITEM.ROCK or fg == ITEM.BEDROCK or OTHER_LOCKS[fg] or fg == ITEM.JAMMER then
            return false
        end
    end

    if CFG.use_antilava and ty < 53 then
        local okB, below = pcall(getTile, tx, ty + 1)
        if okB and below and below.fg == ITEM.LAVA then
            return false
        end
    end

    return true
end

local function moveSafeTo(tx, ty)
    tx = math.max(0, math.min(99, tx))
    ty = math.max(0, math.min(53, ty))
    local px, py = getPlayerTilePos()
    if px == tx and py == ty then
        return true
    end
    local pFn = FindPath or findPath
    if not pFn then return false end

    local CHUNK_LIMIT = 5

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
        return nil, nil
    end

    local stuck = 0
    while STATE.running do
        local curX, curY = getPlayerTilePos()
        if not curX or not curY then
            stuck = stuck + 1
            if stuck >= 3 then break end
            safeSleep(100)
        else
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

            local stepDist = math.max(math.abs(curX - stepX), math.abs(curY - stepY))
            local walkDelay = math.max(50, tonumber(CFG.delay_walk) or 140)
            safeSleep(math.floor(walkDelay * (0.8 + math.random() * 0.4)))
            if not STATE.running then break end
            pcall(pFn, stepX, stepY)

            local waited = 0
            local maxWait = math.max(120, math.min(1500, stepDist * 60))
            while waited < maxWait and STATE.running do
                local nx, ny = getPlayerTilePos()
                if nx and ny and math.abs(nx - stepX) <= 1 and math.abs(ny - stepY) <= 1 then
                    break
                end
                safeSleep(25)
                waited = waited + 25
            end

            local npx, npy = getPlayerTilePos()
            if npx == tx and npy == ty then safeSleep(math.floor(walkDelay * 0.8)); return true end
            if npx == curX and npy == curY then
                stuck = stuck + 1
                if direct and stuck >= 2 then break end
            else
                stuck = 0
                if direct and npx and npy and math.abs(npx - tx) <= 1 and math.abs(npy - ty) <= 1 then
                    safeSleep(math.floor(walkDelay * 0.8))
                    break
                end
            end
            safeSleep(math.floor(walkDelay * 1.5 * (0.8 + math.random() * 0.4)))
        end
    end

    local finalX, finalY = getPlayerTilePos()
    if finalX and finalY then
        return (math.abs(finalX - tx) <= 1 and math.abs(finalY - ty) <= 1)
    end
    return false
end

local function moveAdjacentSafe(targetX, targetY, preferredDirX)
    local dir = preferredDirX or -1
    local candidates = {
        { targetX + dir, targetY },
        { targetX - dir, targetY },
        { targetX,       targetY - 1 },
        { targetX,       targetY + 1 },
        { targetX + dir, targetY - 1 },
        { targetX - dir, targetY - 1 },
        { targetX + dir, targetY + 1 },
        { targetX - dir, targetY + 1 },
        { targetX + (dir * 2), targetY },
        { targetX - (dir * 2), targetY },
    }
    for _, cand in ipairs(candidates) do
        local cx, cy = cand[1], cand[2]
        if isTileSafeToStand(cx, cy) then
            local px, py = getPlayerTilePos()
            if px == cx and py == cy then return true end
            if moveSafeTo(cx, cy) then return true end
        end
    end
    for _, cand in ipairs(candidates) do
        local cx, cy = cand[1], cand[2]
        if cx >= 0 and cx <= 99 and cy >= 0 and cy <= 53 then
            local okT, tileInfo = pcall(getTile, cx, cy)
            if okT and tileInfo and (not tileInfo.collidable) and tileInfo.fg ~= ITEM.LAVA and tileInfo.fg ~= ITEM.ROCK and tileInfo.fg ~= ITEM.DIRT and tileInfo.fg ~= ITEM.BEDROCK then
                if moveSafeTo(cx, cy) then return true end
            end
        end
    end
    return false
end

local function sendRawAction(tx, ty, value)
    local ok, p = pcall(getLocal)
    if not ok or not p then return false end
    local px = p.posX or (p.pos and p.pos.x) or (tx * 32)
    local py = p.posY or (p.pos and p.pos.y) or (ty * 32)
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
        return true
    end
    if punch then
        pcall(punch, tx, ty)
        return true
    end
    return false
end

local function placeTileAt(tx, ty, itemID, isBackground, preferredDirX)
    if tx < 0 or tx > 99 or ty < 0 or ty > 59 then return false end
    local ok, t = pcall(getTile, tx, ty)
    if not ok or not t then return false end

    if not isBackground and t.fg == itemID then return true end
    if isBackground and t.bg == itemID then return true end
    if getInvCount(itemID) <= 0 then return false end

    local maxAttempts = 10
    local attempts = 0
    while STATE.running and attempts < maxAttempts do
        if not waitIfPaused() then return false end
        ok, t = pcall(getTile, tx, ty)
        if not ok or not t then break end
        if (not isBackground and t.fg == itemID) or (isBackground and t.bg == itemID) then
            return true
        end

        local px, py = getPlayerTilePos()
        local outOfRange = (not px) or (math.abs(px - tx) > 2) or (math.abs(py - ty) > 2)
        local standingOnTarget = (px == tx and py == ty)

        if outOfRange or standingOnTarget then
            moveAdjacentSafe(tx, ty, preferredDirX)
        end

        sendRawAction(tx, ty, itemID)
        safeSleep(CFG.delay_place)
        attempts = attempts + 1
    end

    ok, t = pcall(getTile, tx, ty)
    return ok and t and ((not isBackground and t.fg == itemID) or (isBackground and t.bg == itemID))
end

local function breakTileCompletely(tx, ty, clearFg, clearBg, prefDir)
    if tx < 0 or tx > 99 or ty < 0 or ty > 59 then return end
    clearFg = (clearFg ~= false)
    prefDir = prefDir or 1

    local standX = math.max(0, math.min(99, tx + prefDir))
    local standY = ty
    moveAdjacentSafe(standX, standY)

    for attempt = 1, 40 do
        if not STATE.running then break end
        if not waitIfPaused() then break end

        local ok, t = pcall(getTile, tx, ty)
        if not ok or not t then break end
        local fgEmpty = (not clearFg) or (t.fg == 0 or t.fg == ITEM.BEDROCK or t.fg == ITEM.MAIN_DOOR)
        local bgEmpty = (not clearBg) or (t.bg == 0)

        if fgEmpty and bgEmpty then break end
        sendRawAction(tx, ty, ITEM.PUNCH)
        safeSleep(math.max(80, CFG.delay_punch))
    end
    collectNearbyFloating(tx, ty, 3, true)
end

-- ============================================================================
-- 8. WARP ENGINE PERSIS 100% DARI AUTO_DIRT_FARM.LUA (Poin 9)
-- ============================================================================
local function warpTo(worldName, doorID)
    if not worldName or worldName == "" then return false end
    worldName = tostring(worldName):upper():gsub("%s+", "")
    doorID = tostring(doorID or ""):gsub("%s+", "")
    if worldName == "" or worldName == "0" then return false end
    if doorID == "0" then doorID = "" end

    local targetStr = (doorID ~= "") and (worldName .. "|" .. doorID) or worldName
    setStatus("Warping", "Menuju world " .. targetStr)
    addLog("`9[Warp] `oMencoba masuk ke " .. targetStr)

    local tries = 0
    while STATE.running and tries < 5 do
        if not waitIfPaused() then return false end
        local cur = getWorldNameSafe()
        if cur ~= worldName then
            sendPacket(3, "action|join_request\nname|" .. targetStr .. "\ninvitedWorld|0\n")
            safeSleep(CFG.delay_warp)
        else
            if doorID ~= "" then
                sendPacket(3, "action|join_request\nname|" .. worldName .. "|" .. doorID .. "\ninvitedWorld|0\n")
                safeSleep(2500)
            end
            if getWorldNameSafe() == worldName then
                safeSleep(800)
                return true
            end
        end
        tries = tries + 1
    end

    local finalWorld = getWorldNameSafe()
    return (finalWorld == worldName)
end

-- ============================================================================
-- 9. DIALOG PACKET HOOK & RAW DIALOG ENGINE (Persis auto_dirt_farm.lua)
-- ============================================================================
local function parseDialogFields(dText)
    local map = {}
    if not dText or dText == "" then return map end
    for line in dText:gmatch("[^\r\n]+") do
        local parts = {}
        for token in line:gmatch("[^|]+") do
            table.insert(parts, token)
        end
        local cmd = parts[1] or ""
        if cmd == "embed_data" and parts[2] and parts[3] then
            map[parts[2]] = parts[3]
        elseif cmd == "add_text_input" and parts[2] and parts[4] then
            map[parts[2]] = parts[4]
        elseif cmd == "add_checkbox" and parts[2] and parts[4] then
            map[parts[2]] = parts[4]
        end
    end
    return map
end

local function buildDialogReturn(dialogName, buttonClicked, fieldMap)
    local lines = {
        "action|dialog_return",
        "dialog_name|" .. tostring(dialogName or ""),
        "buttonClicked|" .. tostring(buttonClicked or "")
    }
    if fieldMap then
        for k, v in pairs(fieldMap) do
            table.insert(lines, tostring(k) .. "|" .. tostring(v))
        end
    end
    return table.concat(lines, "\n")
end

local DIALOG_WATCH = {
    expected_name   = nil,
    captured_text   = nil,
    captured_time   = 0,
    waiting         = false,
    hook_registered = false,
}

local function onVariantDialogHook(var, pkt)
    if not var then return end
    local ok, shouldBlock = pcall(function()
        local v0 = var.v0 or var.v1 or var[0] or var[1]
        local v1 = var.v1 or var.v2 or var[1] or var[2]
        if v0 == "OnDialogRequest" or v1 == "OnDialogRequest" then
            local raw = tostring((v0 == "OnDialogRequest" and v1) or var.v2 or var[2] or "")
            local dName = raw:match("end_dialog|([^|\r\n]+)") or ""
            STATE.last_dialog_text = raw
            STATE.last_dialog_name = dName
            STATE.last_dialog_seq = (STATE.last_dialog_seq or 0) + 1
            if DIALOG_WATCH.waiting and DIALOG_WATCH.expected_name then
                if dName == DIALOG_WATCH.expected_name or raw:find(DIALOG_WATCH.expected_name, 1, true) then
                    DIALOG_WATCH.captured_text = raw
                    DIALOG_WATCH.captured_time = safeClock()
                    DIALOG_WATCH.waiting = false
                end
            end
            if STATE.suppress_dialog then
                return true
            end
        end
        return false
    end)
    if ok and shouldBlock then return true end
end

local function safeSendRawDialog(dText)
    if not dText or dText == "" then return false end
    if growtopia and type(growtopia.sendDialog) == "function" then
        local ok = pcall(growtopia.sendDialog, dText)
        if ok then return true end
    end
    if sendVariant then
        local ok0 = pcall(sendVariant, { v0 = "OnDialogRequest", v1 = dText })
        if ok0 then return true end
        local ok1 = pcall(sendVariant, { v1 = "OnDialogRequest", v2 = dText })
        if ok1 then return true end
        local okNum = pcall(sendVariant, { [0] = "OnDialogRequest", [1] = dText })
        if okNum then return true end
    end
    if sendVariantList then
        local okList = pcall(sendVariantList, { [0] = "OnDialogRequest", [1] = dText })
        if okList then return true end
    end
    if sendDialog then
        pcall(sendDialog, dText)
        return true
    end
    return false
end

local function wrenchAndAwaitDialog(tx, ty, expectedDialogName, standX, standY)
    expectedDialogName = expectedDialogName or "lock_edit"
    standX = standX or tx
    standY = standY or ty
    moveSafeTo(standX, standY)
    safeSleep(200)

    for attempt = 1, 3 do
        if not STATE.running then break end
        DIALOG_WATCH.expected_name = expectedDialogName
        DIALOG_WATCH.captured_text = nil
        DIALOG_WATCH.waiting       = true

        sendRawAction(tx, ty, ITEM.WRENCH)

        local t0 = safeClock()
        while DIALOG_WATCH.waiting and (safeClock() - t0) < 2.0 do
            safeSleep(50)
        end

        if DIALOG_WATCH.captured_text then
            local result = DIALOG_WATCH.captured_text
            DIALOG_WATCH.captured_text = nil
            DIALOG_WATCH.waiting = false
            return true, result
        end
    end

    DIALOG_WATCH.waiting = false
    return false, nil
end

local function placeAndValidateSecurityTile(tx, ty, itemID, tileLabel, standX, standY)
    if not itemID or itemID <= 0 then return false end
    standX = standX or tx
    standY = standY or ty
    moveAdjacentSafe(standX, standY)

    for attempt = 1, 4 do
        if not STATE.running then break end
        local ok, t = pcall(getTile, tx, ty)
        if ok and t and (t.fg == itemID or (OTHER_LOCKS[itemID] and OTHER_LOCKS[t.fg])) then
            return true
        end
        if ok and t and t.fg ~= 0 and t.fg ~= ITEM.BEDROCK and t.fg ~= ITEM.MAIN_DOOR then
            breakTileCompletely(tx, ty, true, false, 1)
        end
        placeTileAt(tx, ty, itemID)
        safeSleep(300)
    end
    local okFinal, tFinal = pcall(getTile, tx, ty)
    return (okFinal and tFinal and (tFinal.fg == itemID or (OTHER_LOCKS[itemID] and OTHER_LOCKS[tFinal.fg])))
end

local function validateAndEditDoorTile(tx, ty, doorID, doorLabel, standX, standY)
    local targetID = tostring(doorID or CFG.door_id or "SOIL"):gsub("%s+", "")
    local targetLabel = tostring(doorLabel or CFG.door_label or targetID)
    standX = standX or (tx + 1)
    standY = standY or ty
    moveSafeTo(standX, standY)
    safeSleep(200)

    STATE.suppress_dialog = true

    for attempt = 1, 3 do
        if not STATE.running then break end
        if not waitIfPaused() then break end

        -- Wrench door untuk memicu OnDialogRequest
        wrenchAndAwaitDialog(tx, ty, "door_edit", standX, standY)

        -- Kirim packet eksplisit dengan tilex, tiley, door_name, door_id, dan checkbox_locked = 1
        local pktStr = string.format(
            "action|dialog_return\ndialog_name|door_edit\ntilex|%d|\ntiley|%d|\ndoor_name|%s\ndoor_target|\ndoor_id|%s\ncheckbox_locked|1\n",
            tx, ty, targetLabel, targetID
        )
        if sendPacket then pcall(sendPacket, 2, pktStr) end
        safeSleep(450)
    end

    STATE.suppress_dialog = false
    addLog(string.format("`2[Door ID Setup] `wDoor di (%d, %d) diatur: ID='%s' Label='%s'", tx, ty, targetID, targetLabel))
    return true
end

local function validateAndEditWorldLock(tx, ty, isPublic, standX, standY)
    local pubBit = isPublic and "1" or "0"
    standX = standX or tx
    standY = standY or ty
    moveSafeTo(standX, standY)
    safeSleep(200)

    STATE.suppress_dialog = true

    for attempt = 1, 3 do
        if not STATE.running then break end
        if not waitIfPaused() then break end

        -- Wrench WL
        wrenchAndAwaitDialog(tx, ty, "lock_edit", standX, standY)

        -- Kirim packet resmi World Lock setting dengan tilex, tiley, dan checkbox_public
        local pktStr = string.format(
            "action|dialog_return\ndialog_name|lock_edit\ntilex|%d|\ntiley|%d|\ncheckbox_public|%s\ncheckbox_disable_music|0\ntempo|100\ncheckbox_disable_music_render|0\ncheckbox_set_as_home_world|0\nminimum_entry_level|1\n",
            tx, ty, pubBit
        )
        if sendPacket then pcall(sendPacket, 2, pktStr) end
        safeSleep(450)
    end

    STATE.suppress_dialog = false
    addLog(string.format("`2[WL Setup] `wWorld Lock di (%d, %d) diatur: Public=%s", tx, ty, tostring(isPublic)))
    return true
end

local function validateAndApplySmallLock(tx, ty, ignoreAir, isPublic, standX, standY)
    local pubBit = isPublic and "1" or "0"
    local ignBit = ignoreAir and "1" or "0"
    standX = standX or tx
    standY = standY or ty
    moveSafeTo(standX, standY)
    safeSleep(200)

    STATE.suppress_dialog = true

    for attempt = 1, 2 do
        if not STATE.running then break end
        if not waitIfPaused() then break end

        -- 1. Buka dialog Small Lock dengan wrench
        local gotDlg, dlgText = wrenchAndAwaitDialog(tx, ty, "lock_edit", standX, standY)
        local recalcBtn = "recalcLock"
        if gotDlg and dlgText and dlgText ~= "" then
            local meta = parseDialogFields(dlgText)
            if meta and meta.buttons then
                for bName, _ in pairs(meta.buttons) do
                    local lower = bName:lower()
                    if lower:find("recalc", 1, true) or lower:find("reapply", 1, true) or lower:find("apply", 1, true) then
                        recalcBtn = bName
                        break
                    end
                end
            end
        end

        -- 2. Langsung kirim RE-APPLY LOCK saat dialog sedang aktif terbuka (buttonClicked = recalcLock)
        local pktRecalc = string.format(
            "action|dialog_return\ndialog_name|lock_edit\ntilex|%d|\ntiley|%d|\nbuttonClicked|%s\ncheckbox_public|%s\ncheckbox_ignore|%s\ncheckbox_ignore_air|%s\n",
            tx, ty, recalcBtn, pubBit, ignBit, ignBit
        )
        if sendPacket then pcall(sendPacket, 2, pktRecalc) end
        safeSleep(400)

        -- 3. Buka ulang dialog dan simpan konfigurasi checkbox
        wrenchAndAwaitDialog(tx, ty, "lock_edit", standX, standY)
        local pktSave = string.format(
            "action|dialog_return\ndialog_name|lock_edit\ntilex|%d|\ntiley|%d|\ncheckbox_public|%s\ncheckbox_ignore|%s\ncheckbox_ignore_air|%s\n",
            tx, ty, pubBit, ignBit, ignBit
        )
        if sendPacket then pcall(sendPacket, 2, pktSave) end
        safeSleep(350)
        break
    end

    STATE.suppress_dialog = false
    addLog(string.format("`2[SL Re-apply] `wSmall Lock di (%d, %d) berhasil di-reapply (IgnoreAir=1, recalcLock OK)", tx, ty))
    return true
end

-- ============================================================================
-- 10. FORMASI KUNCI PINTU & PENGHALANG (Poin 4 & 5)
-- ============================================================================
-- Formasi Sesuai Format:
-- Main White Door di (doorX, doorY)
-- Signal Jammer di (doorX - 1, doorY) + punch 1x
-- Small Lock di (doorX - 1, doorY - 1) + Set Private (cover Jammer)
-- World Lock di (doorX - 2, doorY) + Set Public
-- Penghalang Kiri di (doorX - 2, doorY - 1) [kustom door / vent]
-- Door ID di (0, 0) [kustom item ID, door ID & label]
local function inspectWorldSecurityState(doorX, doorY)
    local info = {
        has_wl       = false,
        has_sl       = false,
        has_jammer   = false,
        has_id_door  = false,
        has_blocker  = false,
        all_ready    = false,
    }
    if not doorX or not doorY then return info end

    -- 1. Check WL di (doorX - 2, doorY)
    if doorX - 2 >= 0 then
        local ok, t = pcall(getTile, doorX - 2, doorY)
        if ok and t and (t.fg == ITEM.WORLD_LOCK or OTHER_LOCKS[t.fg]) then
            info.has_wl = true
        end
    end

    -- 2. Check Jammer di (doorX - 1, doorY)
    if doorX - 1 >= 0 then
        local ok, t = pcall(getTile, doorX - 1, doorY)
        if ok and t and (t.fg == ITEM.JAMMER or t.fg == 226 or t.fg == 2810) then
            info.has_jammer = true
        end
    end

    -- 3. Check SL di (doorX - 1, doorY - 1)
    if doorX - 1 >= 0 and doorY - 1 >= 0 then
        local ok, t = pcall(getTile, doorX - 1, doorY - 1)
        if ok and t and (t.fg == ITEM.SMALL_LOCK or OTHER_LOCKS[t.fg]) then
            info.has_sl = true
        end
    end

    -- 4. Check Penghalang di atas White Door (doorX, doorY - 1) [di kanan SL]
    if doorY - 1 >= 0 then
        local ok, t = pcall(getTile, doorX, doorY - 1)
        if ok and t and (t.fg == CFG.blocker_door_itemid or (KNOWN_BLOCKER_IDS and KNOWN_BLOCKER_IDS[t.fg]) or isDoorOrEntranceItem(t.fg)) then
            info.has_blocker = true
        end
    end

    -- 5. Check Door ID di (0, 0)
    do
        local ok, t = pcall(getTile, 0, 0)
        if ok and t and (t.fg == CFG.id_door_itemid) then
            info.has_id_door = true
        end
    end

    local wlOk  = (not CFG.use_wl) or info.has_wl
    local slOk  = (not CFG.use_sl) or info.has_sl
    local jamOk = (not CFG.use_jammer) or info.has_jammer
    local idOk  = (not CFG.use_id_door) or info.has_id_door
    local blkOk = (not CFG.use_blocker_door) or info.has_blocker

    info.all_ready = (wlOk and slOk and jamOk and idOk and blkOk)
    return info
end

-- Helper: Identifikasi tile area kunci & proteksi agar tidak tertabrak atau ter-break saat put
local function isSecurityAreaTile(x, y, doorX, doorY)
    if not doorX or not doorY then return false end
    if CFG.ignore_lock then
        if x == doorX and y == doorY then return true end
        local ok, t = pcall(getTile, x, y)
        if ok and t and (t.fg == ITEM.WORLD_LOCK or (OTHER_LOCKS and OTHER_LOCKS[t.fg])) then
            return true
        end
        return false
    end
    if x == doorX and y == doorY then return true end       -- White Door
    if x == doorX and y == doorY - 1 then return true end   -- Penghalang (di atas White Door, di kanan SL)
    if x == doorX - 1 and y == doorY then return true end   -- Jammer (di kiri White Door)
    if x == doorX - 1 and y == doorY - 1 then return true end -- Small Lock (di kiri Penghalang, cover Jammer)
    if x == doorX - 2 and y == doorY then return true end   -- World Lock (di kiri Jammer)
    if x == doorX - 2 and y == doorY - 1 then return true end -- Ruang kosong di atas WL
    if x == 0 and y == 0 then return true end               -- Door ID (0,0)
    return false
end

-- Helper untuk memeriksa dan menyesuaikan Door ID di (0, 0)
local function checkAndConfigureDoorID()
    local targetID = tostring(CFG.door_id or "SOIL"):gsub("%s+", "")
    local targetLabel = tostring(CFG.door_label or targetID)
    if targetID == "" then return "" end

    local teleWait = math.max(300, tonumber(CFG.delay_tele_door) or 1500)
    setStatus("Jeda Tele Door (0,0)", string.format("Jeda %d ms sebelum cek Door ID di (0,0)...", teleWait))
    safeSleep(teleWait)
    if CFG.use_modfly and editToggle then pcall(editToggle, "ModFly", true) end
    safeSleep(150)
    moveSafeTo(1, 0)

    local ok0, t0 = pcall(getTile, 0, 0)
    local needPlace = (not ok0) or (not t0) or (t0.fg == 0) or (t0.fg ~= CFG.id_door_itemid and not isDoorOrEntranceItem(t0.fg))

    if needPlace then
        setStatus("Pasang Door ID (0,0)", "Menaruh Door di (0, 0)")
        breakTileCompletely(0, 0, true, false, 1)
        placeAndValidateSecurityTile(0, 0, CFG.id_door_itemid, "Door ID (0,0)", 1, 0)
        safeSleep(300)
        validateAndEditDoorTile(0, 0, targetID, targetLabel, 1, 0)
        return targetID
    end

    -- Cek apakah Door ID & Label yang terpasang sudah sesuai
    local idAlreadyMatching = false
    if t0 and t0.extra then
        if t0.extra.target == targetID or (t0.extra.label and t0.extra.label == targetLabel) then
            idAlreadyMatching = true
        end
    end

    if idAlreadyMatching then
        addLog(string.format("`2[Door ID Validasi] `wDoor ID di (0,0) sudah terpasang & sesuai (ID='%s').", targetID))
    else
        addLog(string.format("`e[Door ID Update] `oDoor ID di (0,0) belum sesuai. Mengatur ulang ke '%s'...", targetID))
        validateAndEditDoorTile(0, 0, targetID, targetLabel, 1, 0)
    end

    return targetID
end

local function setupWorldLocks(doorX, doorY, existingSec)
    if CFG.ignore_lock then
        addLog("`2[Ignore Lock] `wMelewati setup lock/security, langsung mulai pasang soil...")
        return ""
    end
    local sec = existingSec or inspectWorldSecurityState(doorX, doorY)
    
    -- VALIDASI: Jika seluruh komponen kunci sudah terpasang, TIDAK USAH mencoba membuat/break lagi!
    local locksAlreadyPlaced = (sec.has_wl and sec.has_sl and sec.has_jammer and sec.has_blocker)
    if locksAlreadyPlaced then
        addLog("`2[Lock Validasi] `wKunci world sudah terpasang lengkap (WL, Jammer, SL, Penghalang ada). Melewati pembuatan ulang.")
        
        -- 1. Tetap pastikan Small Lock di-reapply agar meng-cover Jammer & Penghalang
        if CFG.use_sl and sec.has_sl then
            setStatus("Re-apply Small Lock", "Re-apply SL yang sudah ada...")
            validateAndApplySmallLock(doorX - 1, doorY - 1, CFG.sl_ignore_air, CFG.sl_public, doorX, doorY)
            safeSleep(200)
        end

        -- 2. Pastikan WL public
        if CFG.use_wl and sec.has_wl and CFG.wl_public then
            validateAndEditWorldLock(doorX - 2, doorY, true, doorX, doorY)
            safeSleep(200)
        end

        -- 3. Cek Door ID di (0, 0) apakah sudah sesuai jika menggunakan Door ID
        local activeDoorID = ""
        if CFG.use_id_door then
            activeDoorID = checkAndConfigureDoorID()
        end

        return activeDoorID
    end

    -- JIKA BELUM TERPASANG LENGKAP:
    setStatus("Setup Lock", string.format("Persiapan slot kunci baru di sekitar White Door (%d, %d)", doorX, doorY))

    -- Bersihkan slot yang belum terisi sesuai formasi baru:
    -- Penghalang di atas White Door: (doorX, doorY - 1)
    if CFG.use_blocker_door and not sec.has_blocker and doorY - 1 >= 0 then
        breakTileCompletely(doorX, doorY - 1, true, true, 1)
    end
    -- Jammer di kiri White Door: (doorX - 1, doorY)
    if not sec.has_jammer and doorX - 1 >= 0 then
        breakTileCompletely(doorX - 1, doorY, true, true, 1)
    end
    -- Small Lock di kiri Penghalang / di atas Jammer: (doorX - 1, doorY - 1)
    if not sec.has_sl and doorX - 1 >= 0 and doorY - 1 >= 0 then
        breakTileCompletely(doorX - 1, doorY - 1, true, true, 1)
    end
    -- World Lock di 2-kiri White Door: (doorX - 2, doorY)
    if not sec.has_wl and doorX - 2 >= 0 then
        breakTileCompletely(doorX - 2, doorY, true, true, 1)
    end
    -- Slot di atas WL: (doorX - 2, doorY - 1) dikosongkan
    if doorX - 2 >= 0 and doorY - 1 >= 0 then
        breakTileCompletely(doorX - 2, doorY - 1, true, true, 1)
    end

    -- ==================== URUTAN SESUAI PERINTAH USER ====================
    -- 1. Pasang Penghalang di atas White Door (doorX, doorY - 1) [di kanan SL]
    if CFG.use_blocker_door and doorY - 1 >= 0 then
        if not sec.has_blocker then
            setStatus("Pasang Penghalang", string.format("Menaruh %s di atas White Door (%d, %d)", resolveItemName(CFG.blocker_door_itemid), doorX, doorY - 1))
            placeAndValidateSecurityTile(doorX, doorY - 1, CFG.blocker_door_itemid, "Penghalang", doorX, doorY)
            safeSleep(200)
        end
    end

    -- 2. Pasang Signal Jammer di (doorX - 1, doorY) + punch 1x
    if CFG.use_jammer and doorX - 1 >= 0 then
        if not sec.has_jammer then
            setStatus("Pasang Jammer", string.format("Menaruh Jammer di (%d, %d)", doorX - 1, doorY))
            placeAndValidateSecurityTile(doorX - 1, doorY, ITEM.JAMMER, "Signal Jammer", doorX, doorY)
            safeSleep(300)
        end
        -- Pastikan jammer aktif (punch 1x)
        sendRawAction(doorX - 1, doorY, ITEM.PUNCH)
        safeSleep(350)
        addLog(string.format("`2[Jammer OK] `wSignal Jammer aktif di (%d, %d)", doorX - 1, doorY))
    end

    -- 3. Pasang Small Lock di (doorX - 1, doorY - 1) [di kiri Penghalang, di atas Jammer] + Set Private & Re-apply Lock (cover Jammer & Penghalang)
    if CFG.use_sl and doorX - 1 >= 0 and doorY - 1 >= 0 then
        if not sec.has_sl then
            setStatus("Pasang Small Lock", string.format("Menaruh SL di (%d, %d)", doorX - 1, doorY - 1))
            placeAndValidateSecurityTile(doorX - 1, doorY - 1, ITEM.SMALL_LOCK, "Small Lock", doorX, doorY)
            safeSleep(200)
        end
        setStatus("Apply Small Lock", "Set Private + Ignore Empty Air + Re-apply")
        validateAndApplySmallLock(doorX - 1, doorY - 1, CFG.sl_ignore_air, CFG.sl_public, doorX, doorY)
        safeSleep(200)
    end

    -- 4. Pasang World Lock di (doorX - 2, doorY) + Set Public
    if CFG.use_wl and doorX - 2 >= 0 then
        if not sec.has_wl then
            setStatus("Pasang WL", string.format("Menaruh WL di (%d, %d)", doorX - 2, doorY))
            placeAndValidateSecurityTile(doorX - 2, doorY, ITEM.WORLD_LOCK, "World Lock", doorX, doorY)
            safeSleep(200)
        end
        validateAndEditWorldLock(doorX - 2, doorY, CFG.wl_public, doorX, doorY)
        safeSleep(200)
    end

    -- 5. Pasang Door ID di (0, 0)
    local activeDoorID = ""
    if CFG.use_id_door then
        activeDoorID = checkAndConfigureDoorID()
    end

    return activeDoorID
end

-- ============================================================================
-- 11. MULTI-STORAGE RESTOCK ENGINE (Poin 2 & 3)
-- ============================================================================
local function getMissingToolsFromBag(existingSec)
    if CFG.ignore_lock then return {}, {}, {} end
    local needed = {}
    local neededOrder = {}
    local neededRoles = {}
    local function addNeed(id, count, roleLabel)
        id = tonumber(id) or 0
        if id <= 0 then return end
        if not needed[id] then
            table.insert(neededOrder, id)
            neededRoles[id] = roleLabel
        else
            neededRoles[id] = neededRoles[id] .. " & " .. roleLabel
        end
        needed[id] = (needed[id] or 0) + count
    end

    if CFG.use_wl and not (existingSec and existingSec.has_wl) then
        addNeed(ITEM.WORLD_LOCK, 1, "WL")
    end
    if CFG.use_sl and not (existingSec and existingSec.has_sl) then
        addNeed(ITEM.SMALL_LOCK, 1, "SL")
    end
    if CFG.use_jammer and not (existingSec and existingSec.has_jammer) then
        addNeed(ITEM.JAMMER, 1, "Jammer")
    end
    if CFG.use_id_door and not (existingSec and existingSec.has_id_door) then
        local did = tonumber(CFG.id_door_itemid) or 0
        if did <= 0 or getInvCount(did) <= 0 then
            for _, altID in ipairs({ ITEM.WOODEN_DOOR, 30, 544, 224, 2810 }) do
                if altID ~= did and getInvCount(altID) > 0 then
                    addLog(string.format("`2[Auto-Pilih Door ID] `wMenemukan %s (#%d) di tas, dijadikan Door ID!", resolveItemName(altID), altID))
                    CFG.id_door_itemid = altID
                    did = altID
                    persistConfig()
                    break
                end
            end
        end
        if did <= 0 then did = ITEM.WOODEN_DOOR end
        addNeed(did, 1, "Door ID")
    end
    if CFG.use_blocker_door and not (existingSec and existingSec.has_blocker) then
        local bid = tonumber(CFG.blocker_door_itemid) or 0
        if bid <= 0 or getInvCount(bid) <= 0 then
            for _, altID in ipairs({ ITEM.AIR_VENT, ITEM.WOODEN_DOOR, 30, 60, 224, 858, 544 }) do
                if altID ~= bid and getInvCount(altID) > 0 then
                    addLog(string.format("`2[Auto-Pilih Blocker] `wMenemukan %s (#%d) di tas, dijadikan Penghalang!", resolveItemName(altID), altID))
                    CFG.blocker_door_itemid = altID
                    bid = altID
                    persistConfig()
                    break
                end
            end
        end
        if bid <= 0 then bid = ITEM.WOODEN_DOOR end
        addNeed(bid, 1, "Penghalang")
    end
    if CFG.auto_use_blast and getInvCount(CFG.blast_item_id) <= 0 then
        addNeed(CFG.blast_item_id, 1, "Blast")
    end

    local missingParts = {}
    for _, needID in ipairs(neededOrder) do
        local reqAmt = needed[needID]
        local curAmt = getInvCount(needID)
        if curAmt < reqAmt then
            local diff = reqAmt - curAmt
            local role = neededRoles[needID] or ""
            table.insert(missingParts, string.format("%s (%s #%d) x%d", role, resolveItemName(needID), needID, diff))
        end
    end
    return missingParts, needed, neededOrder, neededRoles
end

-- [Rekomendasi 1] Auto Collect OFF + Anti Collect ON selama di gudang (persis auto_dirt_farm.lua)
local function setAutoCollectActive(enabled)
    if not editToggle then return end
    if enabled then
        pcall(editToggle, "Anti Collect", false)
        pcall(editToggle, "Anti-Collect", false)
        pcall(editToggle, "Auto Collect", true)
        pcall(editToggle, "AutoCollect", true)
    else
        pcall(editToggle, "Auto Collect", false)
        pcall(editToggle, "AutoCollect", false)
        pcall(editToggle, "Anti Collect", true)
        pcall(editToggle, "Anti-Collect", true)
    end
end

-- [Rekomendasi 2] Drop kelebihan item di gudang (confirmDropItem -> fallback packet drop + dialog_return)
local function dropExcessItem(itemID, keepAmt)
    local before = getInvCount(itemID)
    local excess = before - (keepAmt or 0)
    if excess <= 0 then return 0 end
    if growtopia and growtopia.confirmDropItem then
        pcall(growtopia.confirmDropItem, itemID, excess)
        safeSleep(700)
    end
    if getInvCount(itemID) >= before then
        pcall(sendPacket, 2, "action|drop\n|itemID|" .. tostring(itemID))
        safeSleep(300)
        pcall(sendPacket, 2, string.format("action|dialog_return\ndialog_name|drop_item\nitemID|%d|\ncount|%d\n", itemID, excess))
        safeSleep(600)
    end
    local dropped = math.max(0, before - getInvCount(itemID))
    if dropped > 0 then
        addLog(string.format("`9[Drop Kelebihan] `o%s x%d dikembalikan ke gudang.", resolveItemName(itemID), dropped))
    end
    return dropped
end

local function ensureToolsFromStorage(existingSec, returnWorld, returnDoor)
    if CFG.ignore_lock then return true end
    local missingBefore, needed, neededOrder = getMissingToolsFromBag(existingSec)
    if #missingBefore == 0 then return true end

    local missingStr = table.concat(missingBefore, ", ")
    addLog("`e[Alat Kurang] `oDibutuhkan: " .. missingStr)
    logInventoryDiagnostic(neededOrder, "Alat")

    if #CFG.storage_tool_list == 0 then
        addLog("`4[Storage Alat Kosong] `oDaftar Gudang Alat belum diisi! Siapkan di tas atau isi Gudang Alat.")
        if sendNotification then
            pcall(sendNotification, "Kurang alat: " .. missingStr .. " (Gudang Alat belum diisi!)")
        end
        return false
    end

    -- Loop Multi-World Gudang Alat
    local toolSatisfied = false
    setAutoCollectActive(false)
    for sIdx, stor in ipairs(CFG.storage_tool_list) do
        setStatus("Ambil Alat", string.format("Gudang Alat %d/%d: %s", sIdx, #CFG.storage_tool_list, stor.name))
        if warpTo(stor.name, stor.door) then
            -- Tunggu hingga world objects tersinkronisasi dari server (maks 2.5 detik)
            local waited = 0
            while waited < 2500 and STATE.running do
                safeSleep(300)
                waited = waited + 300
                if forEachWorldObject(function() end) > 0 then break end
            end
            safeSleep(200)

            for _, needID in ipairs(neededOrder) do
                local reqAmt = needed[needID]
                if getInvCount(needID) < reqAmt then
                    local foundObjs = findWorldObjectsByItemID(needID)
                    -- Jika Door ID / Blocker spesifik tidak ada di lantai storage, cari alternatif door di lantai!
                    if #foundObjs == 0 and (needID == CFG.blocker_door_itemid or needID == CFG.id_door_itemid) then
                        for _, altID in ipairs({ ITEM.AIR_VENT, ITEM.WOODEN_DOOR, 30, 60, 224, 858, 544 }) do
                            local altObjs = findWorldObjectsByItemID(altID)
                            if #altObjs > 0 then
                                foundObjs = altObjs
                                if needID == CFG.blocker_door_itemid then CFG.blocker_door_itemid = altID end
                                if needID == CFG.id_door_itemid then CFG.id_door_itemid = altID end
                                persistConfig()
                                break
                            end
                        end
                    end

                    for _, obj in ipairs(foundObjs) do
                        addLog(string.format("`9[Ambil Alat] `oMengambil %s di (%d, %d) [UID: %d, Butuh %dx]", resolveItemName(obj.itemid), obj.tileX, obj.tileY, obj.id, reqAmt))
                        moveSafeTo(obj.tileX, obj.tileY)
                        safeSleep(250)
                        -- Pastikan Anti Collect OFF saat mengambil objek agar packet 11 tidak diblokir!
                        if editToggle then
                            pcall(editToggle, "Anti Collect", false)
                            pcall(editToggle, "Anti-Collect", false)
                        end
                        pcall(sendPacketRaw, false, {
                            type  = 11,
                            value = obj.id,
                            x     = obj.x,
                            y     = obj.y,
                        })
                        safeSleep(350)
                        if getInvCount(needID) >= reqAmt then break end
                    end
                end
            end
            -- Kembalikan kelebihan alat ke gudang (sisakan pas sesuai kebutuhan)
            for _, needID in ipairs(neededOrder) do
                dropExcessItem(needID, needed[needID])
            end
            local missingCheck = getMissingToolsFromBag(existingSec)
            if #missingCheck == 0 then
                toolSatisfied = true
                break
            end
        else
            addLog("`4[Gagal Warp Gudang Alat] `o" .. tostring(stor.name) .. " tidak bisa dimasuki, lanjut gudang berikutnya.")
        end
    end
    setAutoCollectActive(CFG.auto_collect)

    local missingAfter = getMissingToolsFromBag(existingSec)
    if #missingAfter > 0 then
        local strAfter = table.concat(missingAfter, ", ")
        addLog("`4[Alat Kurang di Gudang] `oMasih kurang: " .. strAfter)
        if sendNotification then pcall(sendNotification, "Gudang Alat habis: " .. strAfter) end
        if returnWorld and returnWorld ~= "" then warpTo(returnWorld, returnDoor) end
        return false
    end

    addLog("`2[Alat Lengkap] `wSemua kebutuhan alat berhasil diambil dari Gudang Alat!")
    if returnWorld and returnWorld ~= "" then
        setStatus("Kembali ke Farm", returnWorld)
        if not warpTo(returnWorld, returnDoor) then return false end
        safeSleep(1200)
    end
    return true
end

local function restockSoilBlocksFromStorage(returnWorld, returnDoor)
    local needBlock = (getInvCount(CFG.block_id) < 50)
    local needWater = (CFG.enable_water and getInvCount(CFG.water_item_id) <= 0)

    if not needBlock and not needWater then return true end

    if #CFG.storage_block_list == 0 then
        addLog("`4[Gudang Block Kosong] `oDaftar Gudang Block belum diisi & bahan di tas habis!")
        if sendNotification then pcall(sendNotification, "Bahan habis & Gudang Block belum diatur!") end
        return false
    end

    -- Loop Multi-World Gudang Block & Water
    local gotMaterials = false
    setAutoCollectActive(false)
    for sIdx, stor in ipairs(CFG.storage_block_list) do
        setStatus("Restock Block/Water", string.format("Gudang %d/%d: %s", sIdx, #CFG.storage_block_list, stor.name))
        if warpTo(stor.name, stor.door) then
            local waited = 0
            while waited < 2500 and STATE.running do
                safeSleep(300)
                waited = waited + 300
                if forEachWorldObject(function() end) > 0 then break end
            end
            safeSleep(200)

            if needBlock then
                local blockObjs = findWorldObjectsByItemID(CFG.block_id)
                for _, obj in ipairs(blockObjs) do
                    if getInvCount(CFG.block_id) >= 150 then break end
                    moveSafeTo(obj.tileX, obj.tileY)
                    safeSleep(180)
                    if editToggle then
                        pcall(editToggle, "Anti Collect", false)
                        pcall(editToggle, "Anti-Collect", false)
                    end
                    pcall(sendPacketRaw, false, { type = 11, value = obj.id, x = obj.x, y = obj.y })
                    safeSleep(250)
                end
            end

            if needWater then
                local waterObjs = findWorldObjectsByItemID(CFG.water_item_id)
                for _, obj in ipairs(waterObjs) do
                    if getInvCount(CFG.water_item_id) >= 60 then break end
                    moveSafeTo(obj.tileX, obj.tileY)
                    safeSleep(180)
                    if editToggle then
                        pcall(editToggle, "Anti Collect", false)
                        pcall(editToggle, "Anti-Collect", false)
                    end
                    pcall(sendPacketRaw, false, { type = 11, value = obj.id, x = obj.x, y = obj.y })
                    safeSleep(250)
                end
            end
            if getInvCount(CFG.block_id) >= 50 and ((not CFG.enable_water) or getInvCount(CFG.water_item_id) > 0) then
                gotMaterials = true
                break
            end
        else
            addLog("`4[Gagal Warp Gudang Block] `o" .. tostring(stor.name) .. " tidak bisa dimasuki, lanjut gudang berikutnya.")
        end
    end
    setAutoCollectActive(CFG.auto_collect)

    if getInvCount(CFG.block_id) <= 0 then
        addLog("`4[Gudang Habis] `oTidak ada block ID " .. CFG.block_id .. " tersisa di Gudang Block!")
        if returnWorld and returnWorld ~= "" then warpTo(returnWorld, returnDoor) end
        return false
    end

    addLog(string.format("`2[Restock Berhasil] `wStok saat ini: %d block (%s)!", getInvCount(CFG.block_id), resolveItemName(CFG.block_id)))
    if returnWorld and returnWorld ~= "" then
        setStatus("Kembali ke Farm", returnWorld)
        if not warpTo(returnWorld, returnDoor) then return false end
        safeSleep(1200)
    end
    return true
end

-- ============================================================================
-- 12. SOIL FARM & WATER ELEVATOR PLACING (Poin 6)
-- ============================================================================
local function inspectMissingSoilBlocks(doorX, doorY)
    local missingList = {}
    local totalExpected = 0
    -- Kolom paling kanan (x = 99) selalu kosong untuk lewat naik-turun/elevator
    local effectiveEndX = math.min(tonumber(CFG.row_end_x) or 98, 98)
    local minX = math.max(0, tonumber(CFG.row_start_x) or 1)
    for y = CFG.row_start_y, CFG.row_end_y, CFG.row_step do
        for x = minX, effectiveEndX do
            local inSec = isSecurityAreaTile and isSecurityAreaTile(x, y, doorX, doorY)
            if not inSec then
                totalExpected = totalExpected + 1
                local ok, t = pcall(getTile, x, y)
                if ok and t then
                    -- Tile dianggap bolong jika masih empty air (fg == 0)
                    if t.fg == 0 then
                        table.insert(missingList, { x = x, y = y })
                    end
                else
                    table.insert(missingList, { x = x, y = y })
                end
            end
        end
    end
    return #missingList, totalExpected, missingList
end

local function tileHasWaterFlag(t)
    if not t then return false end
    if t.water == true or t.hasWater == true then return true end
    local fl = tonumber(t.flag or t.flags) or 0
    -- TILEFLAG_WATER = 0x0400 (1024), kompatibel Lua 5.1/5.4
    return (math.floor(fl / 1024) % 2) == 1
end

local function placeWaterOnceSafe(tx, ty, waterID, preferredDirX)
    if tx < 0 or tx > 99 or ty < 0 or ty > 53 then return false end
    local ok, t = pcall(getTile, tx, ty)
    if not ok or not t then return false end
    if (tonumber(t.fg) or 0) ~= 0 then return true end
    if tileHasWaterFlag(t) then return true end
    if getInvCount(waterID) <= 0 then return false end

    local function attemptSinglePut()
        local okP, tP = pcall(getTile, tx, ty)
        if not okP or not tP or (tonumber(tP.fg) or 0) ~= 0 or tileHasWaterFlag(tP) then return true end
        local flagBefore = tonumber(tP.flag or tP.flags) or 0
        local invBefore  = getInvCount(waterID)
        if invBefore <= 0 then return false end

        local px, py = getPlayerTilePos()
        local outOfRange = (not px) or (math.abs(px - tx) > 2) or (math.abs(py - ty) > 2)
        local onTarget   = (px == tx and py == ty)
        if outOfRange or onTarget then
            moveAdjacentSafe(tx, ty, preferredDirX)
        end

        local okP2, tP2 = pcall(getTile, tx, ty)
        if okP2 and tP2 and tileHasWaterFlag(tP2) then return true end

        sendRawAction(tx, ty, waterID)
        safeSleep(math.min(math.max(140, tonumber(CFG.delay_place) or 180), 160))

        local waited = 0
        while waited < 850 and STATE.running do
            local okN, tN = pcall(getTile, tx, ty)
            if okN and tN then
                if tileHasWaterFlag(tN) then return true end
                local flagNow = tonumber(tN.flag or tN.flags) or 0
                if flagNow ~= flagBefore then return true end
            end
            if invBefore > 0 and getInvCount(waterID) < invBefore then
                return true
            end
            safeSleep(50)
            waited = waited + 50
        end
        return false
    end

    if attemptSinglePut() then return true end
    if not STATE.running then return false end
    moveAdjacentSafe(tx, ty, preferredDirX)
    safeSleep(150)
    local okC, tC = pcall(getTile, tx, ty)
    if okC and tC and tileHasWaterFlag(tC) then return true end
    return attemptSinglePut()
end

local function putWaterColumn(restockCb)
    if not CFG.enable_water then return true end
    local waterCols = {
        { x = 0,  dir = 1,  label = "Pojok Kiri (X=0)" },
        { x = 99, dir = -1, label = "Pojok Kanan (X=99)" },
    }
    for _, col in ipairs(waterCols) do
        if not STATE.running then break end
        addLog(string.format("`9[Water Elevator] `wMenempatkan air %s dari atas ke bawah (Y=0..53) [1x tervalidasi/tile]...", col.label))
        setStatus("Pasang Water", col.label)

        for y = 0, 53 do
            if not STATE.running then break end
            if not waitIfPaused() then break end

            local ok, t = pcall(getTile, col.x, y)
            if ok and t and (tonumber(t.fg) or 0) == 0 and (not tileHasWaterFlag(t)) then
                if getInvCount(CFG.water_item_id) <= 0 then
                    if restockCb then
                        if not restockCb() then
                            addLog("`4[Water Habis] `oGagal restock air dari Gudang.")
                            return false
                        end
                    else
                        return false
                    end
                end
                placeWaterOnceSafe(col.x, y, CFG.water_item_id, col.dir)
            end
        end
    end
    return true
end

local function placeSoilRows(worldName, doorID, restockCb, doorX, doorY)
    local modeLabel = (CFG.put_mode == "3zigzag") and "3 Block (Zigzag Cepat)" or "1 by 1"
    addLog(string.format("`9[Place Rows] `wMemulai penempatan %s (ID %d) [Mode: %s]...", resolveItemName(CFG.block_id), CFG.block_id, modeLabel))

    if not doorX or not doorY then
        doorX, doorY = findMainDoor()
    end

    local targetBlockID = (CFG.block_id and CFG.block_id > 0) and CFG.block_id or 8772
    local goingRight = true
    local effectiveEndX = math.min(tonumber(CFG.row_end_x) or 98, 98)
    local minX = math.max(0, tonumber(CFG.row_start_x) or 1)

    for y = CFG.row_start_y, CFG.row_end_y, CFG.row_step do
        if not STATE.running then break end
        if not waitIfPaused() then break end

        STATE.active_row = y
        updatePowerStatusList()

        local standY = math.max(0, y - 1)

        if CFG.put_mode == "3zigzag" then
            -- MODE PUT 3 BLOCK ZIGZAG CEPAT (Kiri, Tengah, Kanan per titik berdiri)
            if goingRight then
                -- Arah KIRI -> KANAN (minX s/d effectiveEndX)
                local curX = minX
                while curX <= effectiveEndX do
                    if not STATE.running then break end
                    if not waitIfPaused() then break end

                    local count = math.min(3, effectiveEndX - curX + 1)
                    local sectionTiles = {}
                    local standX
                    if count == 3 then
                        sectionTiles = { curX, curX + 1, curX + 2 }
                        standX = curX + 1 -- Posisi berdiri di tengah
                        curX = curX + 3
                    elseif count == 2 then
                        sectionTiles = { curX, curX + 1 }
                        standX = curX
                        curX = curX + 2
                    else
                        sectionTiles = { curX }
                        standX = curX
                        curX = curX + 1
                    end

                    -- Filter hanya petak kosong (fg == 0) & di luar proteksi security lock
                    local neededSpots = {}
                    for _, tx in ipairs(sectionTiles) do
                        local inSec = isSecurityAreaTile and isSecurityAreaTile(tx, y, doorX, doorY)
                        if not inSec then
                            local ok, t = pcall(getTile, tx, y)
                            if ok and t and t.fg == 0 then
                                table.insert(neededSpots, tx)
                            end
                        end
                    end

                    if #neededSpots > 0 then
                        -- Cek stok sebelum mendekati posisi
                        if getInvCount(targetBlockID) <= 0 then
                            addLog(string.format("`e[Stok Habis] `oBlock habis pada baris Y=%d. Mencoba restock...", y))
                            if restockCb then
                                if not restockCb() then
                                    addLog("`4[Konstruksi Terhenti] `oGagal restock block dari Gudang Block.")
                                    return false
                                end
                                doorX, doorY = findMainDoor()
                            else
                                return false
                            end
                        end

                        STATE.active_col = standX

                        -- Pindah ke koridor udara di atas baris (y - 1)
                        local px, py = getPlayerTilePos()
                        if not px or math.abs(px - standX) > 1 or math.abs(py - standY) > 1 then
                            moveSafeTo(standX, standY)
                        end

                        for _, tx in ipairs(neededSpots) do
                            if not STATE.running then break end
                            if not waitIfPaused() then break end

                            if getInvCount(targetBlockID) <= 0 then
                                if restockCb and restockCb() then
                                    doorX, doorY = findMainDoor()
                                else
                                    return false
                                end
                            end

                            local placed = placeTileAt(tx, y, targetBlockID, false, 1)
                            if placed then
                                STATE.total_placed_blocks = STATE.total_placed_blocks + 1
                                if STATE.total_placed_blocks % 50 == 0 then
                                    updatePowerStatusList()
                                end
                            end
                        end
                    end
                end
            else
                -- Arah KANAN -> KIRI (effectiveEndX s/d minX)
                local curX = effectiveEndX
                while curX >= minX do
                    if not STATE.running then break end
                    if not waitIfPaused() then break end

                    local count = math.min(3, curX - minX + 1)
                    local sectionTiles = {}
                    local standX
                    if count == 3 then
                        sectionTiles = { curX, curX - 1, curX - 2 }
                        standX = curX - 1 -- Posisi berdiri di tengah
                        curX = curX - 3
                    elseif count == 2 then
                        sectionTiles = { curX, curX - 1 }
                        standX = curX
                        curX = curX - 2
                    else
                        sectionTiles = { curX }
                        standX = curX
                        curX = curX - 1
                    end

                    local neededSpots = {}
                    for _, tx in ipairs(sectionTiles) do
                        local inSec = isSecurityAreaTile and isSecurityAreaTile(tx, y, doorX, doorY)
                        if not inSec then
                            local ok, t = pcall(getTile, tx, y)
                            if ok and t and t.fg == 0 then
                                table.insert(neededSpots, tx)
                            end
                        end
                    end

                    if #neededSpots > 0 then
                        if getInvCount(targetBlockID) <= 0 then
                            addLog(string.format("`e[Stok Habis] `oBlock habis pada baris Y=%d. Mencoba restock...", y))
                            if restockCb then
                                if not restockCb() then
                                    addLog("`4[Konstruksi Terhenti] `oGagal restock block dari Gudang Block.")
                                    return false
                                end
                                doorX, doorY = findMainDoor()
                            else
                                return false
                            end
                        end

                        STATE.active_col = standX

                        local px, py = getPlayerTilePos()
                        if not px or math.abs(px - standX) > 1 or math.abs(py - standY) > 1 then
                            moveSafeTo(standX, standY)
                        end

                        for _, tx in ipairs(neededSpots) do
                            if not STATE.running then break end
                            if not waitIfPaused() then break end

                            if getInvCount(targetBlockID) <= 0 then
                                if restockCb and restockCb() then
                                    doorX, doorY = findMainDoor()
                                else
                                    return false
                                end
                            end

                            local placed = placeTileAt(tx, y, targetBlockID, false, -1)
                            if placed then
                                STATE.total_placed_blocks = STATE.total_placed_blocks + 1
                                if STATE.total_placed_blocks % 50 == 0 then
                                    updatePowerStatusList()
                                end
                            end
                        end
                    end
                end
            end

        else
            -- MODE 1-BY-1 (Satu per satu petak)
            local startX = goingRight and minX or effectiveEndX
            local endX   = goingRight and effectiveEndX or minX
            local stepX  = goingRight and 1 or -1

            local x = startX
            while (stepX > 0 and x <= endX) or (stepX < 0 and x >= endX) do
                if not STATE.running then break end
                if not waitIfPaused() then break end

                STATE.active_col = x

                local ok, t = pcall(getTile, x, y)
                local inSec = isSecurityAreaTile and isSecurityAreaTile(x, y, doorX, doorY)
                if (not inSec) and ok and t and t.fg == 0 then
                    if getInvCount(targetBlockID) <= 0 then
                        addLog(string.format("`e[Stok Habis] `oBlock habis pada (%d, %d). Mencoba restock...", x, y))
                        if restockCb then
                            local okRestock = restockCb()
                            if not okRestock then
                                addLog("`4[Konstruksi Terhenti] `oGagal restock block dari Gudang Block.")
                                return false
                            end
                            doorX, doorY = findMainDoor()
                        else
                            return false
                        end
                    end

                    local placed = placeTileAt(x, y, targetBlockID, false, stepX)
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

        goingRight = not goingRight
    end

    addLog(string.format("`2[Place Rows Selesai] `wTotal block terpasang: %d", STATE.total_placed_blocks))
    updatePowerStatusList()
    return true
end

local function validateAndRepairSoilLayout(worldName, doorID, doorX, doorY, restockCb)
    local targetBlockID = (CFG.block_id and CFG.block_id > 0) and CFG.block_id or 8772
    for pass = 1, 3 do
        local missingCount, totalExpected, missingList = inspectMissingSoilBlocks(doorX, doorY)
        if missingCount == 0 then return true end

        addLog(string.format("`e[Validasi Pass %d] `oDitemukan %d/%d tile belum terpasang. Memperbaiki...", pass, missingCount, totalExpected))
        for _, pos in ipairs(missingList) do
            if not STATE.running then return false end
            if not waitIfPaused() then return false end

            local ok, t = pcall(getTile, pos.x, pos.y)
            -- HANYA PUT PADA TILE KOSONG (fg == 0), TIDAK ADA BREAK
            if ok and t and t.fg == 0 then
                if getInvCount(targetBlockID) <= 0 then
                    if restockCb then
                        if not restockCb() then return false end
                    else
                        return false
                    end
                end
                placeTileAt(pos.x, pos.y, targetBlockID)
            end
        end
        safeSleep(300)
    end

    local finalMissing, totalExpected = inspectMissingSoilBlocks(doorX, doorY)
    return (totalExpected > 0 and finalMissing == 0)
end

-- ============================================================================
-- 13. AUTO BLAST ENGINE
-- ============================================================================
local function recordBlastedWorld(worldName, doorID)
    if not worldName or worldName == "" or worldName == "EXIT" then return end
    doorID = doorID or ""
    for _, e in ipairs(CFG.farm_world_list) do
        if e.name == worldName then return end
    end
    table.insert(CFG.farm_world_list, {
        name = worldName,
        door = doorID,
        status = "ANTRI",
        done = false,
        from_blast = true,
    })
    persistConfig()
    if updateWorldDisplayList then pcall(updateWorldDisplayList) end
    addLog(string.format("`2[World Blast Tersimpan] `wWorld %s otomatis masuk ke antrean World Put!", worldName))
    if sendNotification then pcall(sendNotification, "World Blast tersimpan: " .. worldName) end
end

local function executeWorldBlast(doorX, doorY)
    if not CFG.auto_use_blast then return true end
    addLog(string.format("`9[Auto Blast] `wMempersiapkan blast world dengan item ID: %d (%s)...", CFG.blast_item_id, resolveItemName(CFG.blast_item_id)))

    if getInvCount(CFG.blast_item_id) <= 0 then
        addLog("`4[Blast Habis] `oTidak ada blast di tas!")
        return false
    end

    local targetX = (doorX and doorX > 2) and (doorX - 2) or 50
    local targetY = (doorY and doorY > 2) and (doorY - 1) or 23

    moveSafeTo(targetX, targetY)
    safeSleep(300)
    placeTileAt(targetX, targetY, CFG.blast_item_id)
    safeSleep(500)

    pcall(sendPacket, 2, "action|dialog_return\ndialog_name|use_blast\nbuttonClicked|blast")
    safeSleep(350)
    pcall(sendPacket, 2, "action|dialog_return\ndialog_name|blast_confirm\nbuttonClicked|yes")

    addLog("`9[Auto Blast] `wMenunggu proses blast selesai (10 detik)...")
    for sec = 1, 10 do
        if not STATE.running then break end
        safeSleep(1000)
    end
    return true
end

-- ============================================================================
-- 14. EKSEKUSI TUNGGAL FARM WORLD
-- ============================================================================
local function runSingleFarmWorld(worldName, worldDoor, manualIdx)
    STATE.active_world = worldName
    STATE.active_door = worldDoor or ""
    setStatus("Mempersiapkan", worldName)
    addLog("`2================================================`0")
    addLog(string.format("`2[Mulai World] `wMemproses Farm World: %s", worldName))

    if manualIdx and CFG.farm_world_list[manualIdx] then
        CFG.farm_world_list[manualIdx].done = false
        CFG.farm_world_list[manualIdx].status = "PROSES"
        persistConfig()
    end
    if updateWorldDisplayList then pcall(updateWorldDisplayList) end

    -- 1. Warp ke World Target dengan Verifikasi Ketat (Poin 9)
    if not warpTo(worldName, worldDoor) then
        addLog("`4[Gagal Warp] `oTidak dapat memasuki world " .. worldName)
        setStatus("Gagal Warp", worldName)
        if manualIdx and CFG.farm_world_list[manualIdx] then
            CFG.farm_world_list[manualIdx].done = false
            CFG.farm_world_list[manualIdx].status = "GAGAL WARP"
            persistConfig()
            if updateWorldDisplayList then pcall(updateWorldDisplayList) end
        end
        return false
    end
    safeSleep(1200)

    local doorX, doorY = findMainDoor()
    if not doorX or not doorY then
        setStatus("Error Main Door", "White Door tidak ditemukan di world " .. worldName)
        addLog("`4[Error] `oWhite Door tidak terdeteksi di world " .. worldName)
        if manualIdx and CFG.farm_world_list[manualIdx] then
            CFG.farm_world_list[manualIdx].done = false
            CFG.farm_world_list[manualIdx].status = "NO WHITE DOOR"
            persistConfig()
            if updateWorldDisplayList then pcall(updateWorldDisplayList) end
        end
        return false
    end

    -- 2. Setup Proteksi Kunci & Penghalang (Poin 4 & 5)
    local activeDoorID = worldDoor or ""
    local secState = inspectWorldSecurityState(doorX, doorY)

    if CFG.ignore_lock then
        addLog("`2[Ignore Lock] `wMode Ignore Lock AKTIF (Bukan Owner). Langsung mulai pasang soil tanpa setup lock/door!")
        setStatus("Ignore Lock Soil", "Ignore Lock AKTIF di " .. worldName .. "! Langsung lanjut buat Soil...")
        activeDoorID = worldDoor or ""
    elseif secState.all_ready then
        addLog("`2[Proteksi World] `wSemua Lock, Jammer & Door sudah lengkap di " .. worldName)
        if CFG.use_id_door and activeDoorID == "" then
            activeDoorID = CFG.door_id
        end
    else
        -- Cek dulu inventori tas: jika semua kebutuhan alat sudah ada di tas, LANGSUNG pasang lock!
        local missingTools = getMissingToolsFromBag(secState)
        if #missingTools == 0 then
            addLog("`2[Alat di Tas Lengkap] `wSemua kebutuhan lock ada di tas, langsung memasang formasi lock tanpa ke Gudang Alat!")
            doorX, doorY = findMainDoor()
            if not doorX or not doorY then return false end
            activeDoorID = setupWorldLocks(doorX, doorY, secState)
            if activeDoorID == "" then activeDoorID = worldDoor or "" end
        else
            -- Alat belum lengkap di tas, baru warp ke Gudang Alat
            addLog("`e[Alat di Tas Belum Lengkap] `oMenuju Gudang Alat untuk mengambil: " .. table.concat(missingTools, ", "))
            if not ensureToolsFromStorage(secState, worldName, worldDoor) then
                if manualIdx and CFG.farm_world_list[manualIdx] then
                    CFG.farm_world_list[manualIdx].done = false
                    CFG.farm_world_list[manualIdx].status = "ALAT KURANG"
                    persistConfig()
                    if updateWorldDisplayList then pcall(updateWorldDisplayList) end
                end
                return false
            end
            doorX, doorY = findMainDoor()
            if not doorX or not doorY then return false end
            activeDoorID = setupWorldLocks(doorX, doorY, secState)
            if activeDoorID == "" then activeDoorID = worldDoor or "" end
        end
    end

    if manualIdx and CFG.farm_world_list[manualIdx] and activeDoorID ~= "" and CFG.farm_world_list[manualIdx].door ~= activeDoorID then
        CFG.farm_world_list[manualIdx].door = activeDoorID
        persistConfig()
        if updateWorldDisplayList then pcall(updateWorldDisplayList) end
    end

    -- 3. Auto Blast (bila diaktifkan)
    if CFG.auto_use_blast then
        local okBlast = executeWorldBlast(doorX, doorY)
        if okBlast then
            recordBlastedWorld(worldName, activeDoorID)
        end
    end

    -- 4. Pemasangan Kolom Water Elevator (Poin 6)
    local restockFn = function()
        return restockSoilBlocksFromStorage(worldName, activeDoorID)
    end

    if CFG.enable_water then
        putWaterColumn(restockFn)
    end

    -- 5. Pengecekan & Penempatan Baris Block Soil (Poin 6)
    local targetBlockID = (CFG.block_id and CFG.block_id > 0) and CFG.block_id or 8772
    if getInvCount(targetBlockID) <= 0 then
        if not restockFn() then
            addLog("`4[Gagal Stok Awal] `oTidak ada block di tas dan gagal restock.")
            if manualIdx and CFG.farm_world_list[manualIdx] then
                CFG.farm_world_list[manualIdx].done = false
                CFG.farm_world_list[manualIdx].status = "BLOCK KURANG"
                persistConfig()
                if updateWorldDisplayList then pcall(updateWorldDisplayList) end
            end
            return false
        end
        doorX, doorY = findMainDoor()
    end

    local okRows = placeSoilRows(worldName, activeDoorID, restockFn, doorX, doorY)
    if not okRows then
        addLog("`4[Konstruksi Gagal] `oGagal menuntaskan baris block di " .. worldName)
        if manualIdx and CFG.farm_world_list[manualIdx] then
            CFG.farm_world_list[manualIdx].done = false
            CFG.farm_world_list[manualIdx].status = "GAGAL PUT"
            persistConfig()
            if updateWorldDisplayList then pcall(updateWorldDisplayList) end
        end
        return false
    end

    local okRepair = validateAndRepairSoilLayout(worldName, activeDoorID, doorX, doorY, restockFn)
    if not okRepair then
        local missingLeft = inspectMissingSoilBlocks(doorX, doorY)
        addLog(string.format("`4[Validasi Gagal] `oWorld %s masih kurang %d block! TIDAK DITANDAI DONE.", worldName, missingLeft))
        if manualIdx and CFG.farm_world_list[manualIdx] then
            CFG.farm_world_list[manualIdx].done = false
            CFG.farm_world_list[manualIdx].status = string.format("KURANG (%d)", missingLeft)
            persistConfig()
            if updateWorldDisplayList then pcall(updateWorldDisplayList) end
        end
        return false
    end

    local missingFinal, totalExp = inspectMissingSoilBlocks(doorX, doorY)
    if missingFinal > 0 then
        addLog(string.format("`4[Validasi Akhir] `oWorld %s masih menyisakan %d/%d tile kosong! TIDAK DITANDAI DONE.", worldName, missingFinal, totalExp))
        if manualIdx and CFG.farm_world_list[manualIdx] then
            CFG.farm_world_list[manualIdx].done = false
            CFG.farm_world_list[manualIdx].status = string.format("BOLONG (%d)", missingFinal)
            persistConfig()
            if updateWorldDisplayList then pcall(updateWorldDisplayList) end
        end
        return false
    end

    -- 6. HANYA TANDAI DONE JIKA TERVERIFIKASI 100% (0 BOLONG)!
    if manualIdx and CFG.farm_world_list[manualIdx] then
        CFG.farm_world_list[manualIdx].done = true
        CFG.farm_world_list[manualIdx].status = "DONE"
        persistConfig()
        if updateWorldDisplayList then pcall(updateWorldDisplayList) end
    end

    STATE.worlds_completed = STATE.worlds_completed + 1
    STATE.active_world = ""
    STATE.active_door = ""
    if updateWorldDisplayList then pcall(updateWorldDisplayList) end
    setStatus("World Selesai!", string.format("World %s selesai 100%%! (Total: %d)", worldName, STATE.worlds_completed))
    addLog(string.format("`2[World Tuntas] `wWorld %s resmi selesai dan ditandai DONE! (Total: %d)", worldName, STATE.worlds_completed))
    if sendNotification then
        pcall(sendNotification, "Soil Builder Selesai: " .. worldName)
    end
    return true
end

-- ============================================================================
-- 15. RANDOM WORLD GENERATOR & BOT MAIN LOOP
-- ============================================================================
local function generateRandomWorldName(length, useNumbers)
    length = math.max(4, math.min(10, tonumber(length) or 6))
    local vowels = { "A", "E", "I", "U", "O" }
    local consonants = { "B", "C", "D", "F", "G", "H", "J", "K", "L", "M", "N", "P", "R", "S", "T", "V", "W" }
    local numbers = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0" }

    local res = {}
    local useVowel = (math.random(1, 2) == 1)
    for i = 1, length do
        if useNumbers and i >= length - 1 and math.random(1, 3) == 1 then
            table.insert(res, numbers[math.random(1, #numbers)])
        else
            if useVowel then
                table.insert(res, vowels[math.random(1, #vowels)])
            else
                table.insert(res, consonants[math.random(1, #consonants)])
            end
            useVowel = not useVowel
        end
    end
    return table.concat(res)
end

local function botMainLoop()
    if syncInputsFromGL then pcall(syncInputsFromGL) end
    if refreshNativeDisplayLists then pcall(refreshNativeDisplayLists) end
    STATE.running = true
    STATE.paused  = false
    addLog("`2[Start Bot] `wAuto Soil Builder V2.6.2 resmi dimulai!")
    logInventoryDiagnostic({ ITEM.WORLD_LOCK, ITEM.SMALL_LOCK, ITEM.JAMMER, CFG.id_door_itemid,
        CFG.blocker_door_itemid, CFG.block_id, CFG.enable_water and CFG.water_item_id or 0 }, "Start")
    updatePowerStatusList()

    while STATE.running do
        if not waitIfPaused() then break end

        if CFG.world_mode == "random" then
            if STATE.worlds_completed >= CFG.random_target_count then
                addLog(string.format("`2[Target Tercapai] `wTarget %d random world selesai!", CFG.random_target_count))
                break
            end
            local rndName = generateRandomWorldName(CFG.random_length, CFG.random_use_numbers)
            runSingleFarmWorld(rndName, "", nil)
        else
            -- Mode Manual World Put
            -- Jika antrean kosong tapi user sudah isi input manual, otomatis masukkan (seperti Auto Dirt Farm)
            if #CFG.farm_world_list == 0 and STATE.buf_world_name and STATE.buf_world_name ~= "" then
                addManualWorldsFromString(STATE.buf_world_name, STATE.buf_world_door or "", false)
            end

            local foundUndone = false

            for idx, wItem in ipairs(CFG.farm_world_list) do
                if not STATE.running then break end
                if not waitIfPaused() then break end

                if not wItem.done and wItem.status ~= "DONE" then
                    foundUndone = true
                    wItem.status = "PROSES"
                    STATE.active_world = wItem.name
                    STATE.active_door = wItem.door or ""
                    if updateWorldDisplayList then pcall(updateWorldDisplayList) end

                    local okCall, okResult = pcall(runSingleFarmWorld, wItem.name, wItem.door, idx)
                    local ok = okCall and okResult
                    if not okCall then
                        addLog("`4[World Error] `o" .. tostring(okResult))
                    end
                    if not ok then
                        if not STATE.running then
                            -- Dihentikan manual oleh user: kembalikan status ke ANTRI agar langsung bisa di-run lagi
                            wItem.status = "ANTRI"
                        elseif wItem.status == "PROSES" then
                            wItem.status = "GAGAL"
                        end
                        if updateWorldDisplayList then pcall(updateWorldDisplayList) end
                        safeSleep(1000)
                    end
                end
            end

            if #CFG.farm_world_list == 0 then
                addLog("`e[Antrean Kosong] `oDaftar antrean World Put belum diisi. Silakan tambahkan world terlebih dahulu.")
                setStatus("Antrean Kosong", "Isi antrean World Put lalu tekan START.")
                break
            elseif not foundUndone then
                addLog("`2[Antrean Selesai] `wSemua world dalam antrean World Put sudah berstatus DONE 100%!")
                setStatus("Antrean Selesai", "Semua antrean selesai diproses 100%.")
                break
            elseif not STATE.running then
                break
            end
        end

        safeSleep(1000)
    end

    STATE.running = false
    STATE.paused  = false
    STATE.active_world = ""
    STATE.active_door  = ""
    -- Bila masih ada world yang berstatus PROSES saat berhenti, kembalikan ke ANTRI
    for _, w in ipairs(CFG.farm_world_list) do
        if w.status == "PROSES" then
            w.status = "ANTRI"
        end
    end
    setStatus("Berhenti", "Bot selesai beroperasi.")
    if editToggle then pcall(editToggle, "sb_run_power", false) end
    if updateWorldDisplayList then pcall(updateWorldDisplayList) end
    updatePowerStatusList()
end

local function startSoilBot()
    if STATE.running then return end
    STATE.running = true
    STATE.paused  = false
    if editToggle then pcall(editToggle, "sb_run_power", true) end
    if updatePowerStatusList then pcall(updatePowerStatusList) end

    -- Reset semua world antrean yang belum selesai (ANTRI, PROSES, GAGAL, dsb) menjadi "ANTRI"
    for _, w in ipairs(CFG.farm_world_list) do
        if not w.done and w.status ~= "DONE" then
            w.status = "ANTRI"
        end
    end
    if updateWorldDisplayList then pcall(updateWorldDisplayList) end

    if syncInputsFromGL then pcall(syncInputsFromGL) end
    -- WAJIB runCoroutine (sama seperti auto_dirt_farm.lua). runThread = native thread terpisah,
    -- baca memori game (inventory / object list) dari situ tidak reliable -> item "tidak terdeteksi".
    if runCoroutine then
        local ok, err = pcall(runCoroutine, function()
            local okMain, errMain = pcall(botMainLoop)
            if not okMain then
                STATE.running = false
                addLog("`4[Runtime Error] `o" .. tostring(errMain))
                setStatus("Error Runtime", tostring(errMain))
                if editToggle then pcall(editToggle, "sb_run_power", false) end
                if updatePowerStatusList then pcall(updatePowerStatusList) end
            end
        end)
        if not ok then
            STATE.running = false
            if editToggle then pcall(editToggle, "sb_run_power", false) end
            addLog("`4[Start Err] `o" .. tostring(err))
            setStatus("Error Start", tostring(err))
            if updatePowerStatusList then pcall(updatePowerStatusList) end
        end
    elseif runThread then
        runThread(function()
            pcall(botMainLoop)
        end)
    else
        addLog("`4[Error] `orunCoroutine atau runThread tidak tersedia di Growlauncher ini.")
        STATE.running = false
        if editToggle then pcall(editToggle, "sb_run_power", false) end
    end
end

local function stopSoilBot()
    STATE.running = false
    STATE.paused  = false
    -- Bila ada world yang berstatus "PROSES", kembalikan ke "ANTRI" agar siap di-run lagi
    for _, w in ipairs(CFG.farm_world_list) do
        if w.status == "PROSES" then
            w.status = "ANTRI"
        end
    end
    if updateWorldDisplayList then pcall(updateWorldDisplayList) end
    if editToggle then pcall(editToggle, "sb_run_power", false) end
    setStatus("Dihentikan", "Bot dihentikan manual oleh user.")
    updatePowerStatusList()
end


-- ============================================================================
-- 16. REFINED MODULAR COMPACT DIALOG SYSTEM FOR SOIL BUILDER (/sb /soil /boren)
-- 100% Pure ASCII, 5-8 lines max per dialog, no vertical scrollbar
-- ============================================================================

local function parseWorldBatchFromString(rawInput)
    local list = {}
    if not rawInput or rawInput == "" then return list end
    for rawToken in rawInput:gmatch("[^\r\n,;]+") do
        local entry = parseWorldEntryToken(rawToken, "")
        if entry and entry.name ~= "" and entry.name ~= "EXIT" then
            table.insert(list, entry)
        end
    end
    return list
end

local function showClientDialog(dText)
    return safeSendRawDialog(dText)
end

local DLG = {
    wlist_page = 1,
    tool_page  = 1,
    block_page = 1,
}

-- ============================================================================
-- 0. MAIN DASHBOARD DIALOG (/sb /soil)
-- ============================================================================
DLG.showSoilMainDialog = function()
    local curW = getWorldNameSafe()
    if curW == "" then curW = "EXIT" end
    local isRun = STATE.running
    local stBadge = isRun and "`2(Running)" or "`4(Stopped)"
    local wCount = #(CFG.farm_world_list or {})
    local toolCount = #(CFG.storage_tool_list or {})
    local blockCount = #(CFG.storage_block_list or {})
    local doneCount = 0
    for _, w in ipairs(CFG.farm_world_list or {}) do
        if w.done or w.status == "DONE" then doneCount = doneCount + 1 end
    end
    local modeBadge = (CFG.world_mode == "random") and "`b(Find Random)" or "`2(Manual)"
    local putModeBadge = (CFG.put_mode == "3zigzag") and "`2(3-Zigzag)" or "`e(1by1)"

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wBoren Auto Soil Builder``|left|8772|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_textbox|`wStatus: %s `p- `wWorld: `b%s `p- `wPut: %s|left|", stBadge, curW, putModeBadge),
        string.format("add_textbox|`wQueue: `2(%d World) `p- `wDone: `2(%d) `p- `wMode: %s|left|", wCount, doneCount, modeBadge),
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
    }
    if not isRun then
        lines[#lines+1] = "add_button|sb_btn_dlg_start|`wStart Auto Soil `2(Ready)|noflags|0|0|"
    else
        lines[#lines+1] = "add_button|sb_btn_dlg_stop|`wStop Auto Soil `4(Active)|noflags|0|0|"
    end
    lines[#lines+1] = string.format("add_button|sb_btn_dlg_add_cur|`wAdd World `2(%s)|noflags|0|0|", curW)
    lines[#lines+1] = "add_spacer|small|"
    lines[#lines+1] = string.format("add_button|sb_btn_dlg_worlds|`wSetting World Put `2(%d World)|noflags|0|0|", wCount)
    lines[#lines+1] = string.format("add_button|sb_btn_dlg_storage|`wSetting Multi-Gudang `2(%d Alat, %d Block)|noflags|0|0|", toolCount, blockCount)
    lines[#lines+1] = "add_button|sb_btn_dlg_lock|`wLock & Door Config|noflags|0|0|"
    lines[#lines+1] = "add_button|sb_btn_dlg_settings|`wPengaturan Soil Farm|noflags|0|0|"
    lines[#lines+1] = "add_button|sb_btn_dlg_logs|`wLog Activity & Tas|noflags|0|0|"
    lines[#lines+1] = "add_spacer|small|"
    lines[#lines+1] = "add_button|sb_btn_dlg_close|`wClose|noflags|0|0|"
    lines[#lines+1] = "end_dialog|sb_main|Close||"
    showClientDialog(table.concat(lines, "\n"))
end

-- ============================================================================
-- 1. SETTING WORLD PUT (HUB + SUB-DIALOGS)
-- ============================================================================
DLG.showSoilWorldsDialog = function()
    local wCount = #(CFG.farm_world_list or {})
    local isRandom = (CFG.world_mode == "random")
    local modeTxt = isRandom and "`b(Find Random World)" or "`2(Manual Queue)"
    local rLen = tonumber(CFG.random_length) or 6

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wSetting World Put``|left|2|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_textbox|`wTotal Queue: `2(%d World) `p- `wMode: %s|left|", wCount, modeTxt),
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        string.format("add_button|sb_btn_toggle_mode|`wMode: %s `2(Switch)|noflags|0|0|", modeTxt),
        "add_button|sb_btn_open_add_w|`w1. Add World Put `2(Manual)|noflags|0|0|",
        string.format("add_button|sb_btn_open_find_w|`w2. Find Random World `2(%d Huruf)|noflags|0|0|", rLen),
        "add_button|sb_btn_open_batch_w|`w3. Batch Add World `2(Paste)|noflags|0|0|",
        string.format("add_button|sb_btn_open_list_w|`w4. List World Put `2(%d World)|noflags|0|0|", wCount),
        "add_button|sb_btn_open_file_w|`w5. Backup & File Manager|noflags|0|0|",
        "add_button|sb_btn_dlg_reset_queue|`wReset Status Queue `4(Reset)|noflags|0|0|",
        "add_spacer|small|",
        "add_button|sb_btn_dlg_back_main|`wBack|noflags|0|0|",
        "end_dialog|sb_worlds|Close||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 1.1 Add Single World
DLG.showSoilAddWorldDialog = function()
    local curW = getWorldNameSafe()
    if curW == "" then curW = "EXIT" end
    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wAdd World Put``|left|2|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_textbox|`wMasukkan nama world farm ke antrian: `2(Queue)|left|",
        "add_textbox|`p(Format: WORLD atau WORLD:DOOR_ID)|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        "add_text_input|sb_in_world_name|World Name||32|",
        "add_text_input|sb_in_door_id|Door ID (Opsional)||16|",
        "add_spacer|small|",
        "add_button|sb_btn_do_add_world|`wSave World `2(Add)|noflags|0|0|",
        string.format("add_button|sb_btn_add_cur_w|`wAdd Current World `2(%s)|noflags|0|0|", curW),
        "add_button|sb_btn_back_worlds|`wBack|noflags|0|0|",
        "end_dialog|sb_add_w|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 1.2 Find Random World
DLG.showSoilFindWorldDialog = function()
    local isRandom = (CFG.world_mode == "random")
    local modeBadge = isRandom and "`2(ON / Active)" or "`4(OFF / Manual)"
    local rLen = tonumber(CFG.random_length) or 6
    local rNum = CFG.random_use_numbers and 1 or 0
    local rTar = tonumber(CFG.random_target_count) or 5
    local autoBlast = CFG.auto_use_blast and 1 or 0
    local blastId = tonumber(CFG.blast_item_id) or 3562

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wFind Random World``|left|2|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_textbox|`wStatus: %s `p- `wTarget: `2(%d World Selesai)|left|", modeBadge, rTar),
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        string.format("add_button|sb_btn_find_toggle_mode|`wMode: %s `2(Switch)|noflags|0|0|", modeBadge),
        string.format("add_text_input|sb_in_find_len|Panjang Huruf (3-16)|%d|4|", rLen),
        string.format("add_text_input|sb_in_find_target|Target World Selesai|%d|4|", rTar),
        string.format("add_checkbox|sb_chk_find_num|Gunakan Kombinasi Angka (0-9)|%d|", rNum),
        string.format("add_checkbox|sb_chk_auto_blast|Gunakan Blast Otomatis|%d|", autoBlast),
        string.format("add_text_input|sb_in_blast_id|ID Item Blast (Cave=3562 / Thermo=1402)|%d|8|", blastId),
        "add_spacer|small|",
        "add_button|sb_btn_generate_1_world|`wGenerate 1 World ke Queue `2(Add)|noflags|0|0|",
        "add_button|sb_btn_save_find_cfg|`wSave Find Config `2(Save)|noflags|0|0|",
        "add_button|sb_btn_back_worlds|`wBack|noflags|0|0|",
        "end_dialog|sb_find_w|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 1.3 Batch Add World
DLG.showSoilBatchWorldDialog = function()
    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wBatch Add World Put``|left|2|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_textbox|`wMasukkan daftar world farm dipisah spasi, koma atau enter:|left|",
        "add_textbox|`p(Contoh: FARM1 FARM2:DOOR1 FARM3|DOOR2 FARM4)|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        "add_text_input|sb_in_batch_worlds|World List||80|",
        "add_checkbox|sb_chk_batch_replace|Ganti seluruh daftar (Replace)|0|",
        "add_spacer|small|",
        "add_button|sb_btn_do_batch_add|`wAdd All Worlds `2(Batch)|noflags|0|0|",
        "add_button|sb_btn_back_worlds|`wBack|noflags|0|0|",
        "end_dialog|sb_batch_w|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 1.4 List World Put (Paginated, 5 items per page)
DLG.showSoilWorldListDialog = function(page)
    local list = CFG.farm_world_list or {}
    local count = #list
    local perPage = 5
    local totalPages = math.max(1, math.ceil(count / perPage))
    page = math.max(1, math.min(totalPages, tonumber(page) or 1))
    DLG.wlist_page = page

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wList World Put``|left|2|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_textbox|`wTotal Registered: `2(%d World) `p- `wPage `2(%d/%d)|left|", count, page, totalPages),
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
    }

    if count == 0 then
        lines[#lines+1] = "add_textbox|`4(Antrian world masih kosong. Silakan tambah world)|left|"
    else
        local startIdx = (page - 1) * perPage + 1
        local endIdx = math.min(count, startIdx + perPage - 1)
        for i = startIdx, endIdx do
            local item = list[i]
            local dName = (item.door and item.door ~= "") and item.door or "-"
            local st = (item.done or item.status == "DONE") and "`2[DONE]" or ((item.status == "PROSES") and "`6[PROSES]" or "`9[ANTRI]")
            lines[#lines+1] = string.format("add_textbox|`w#%d `b%s `p[Door: `e%s`p] %s|left|", i, item.name, dName, st)
            lines[#lines+1] = string.format("add_button|sb_btn_w_edit_%d|`wEdit `2(#%d)|noflags|0|0|", i, i)
            lines[#lines+1] = string.format("add_button|sb_btn_w_del_%d|`wDelete `4(#%d)|noflags|0|0|", i, i)
            lines[#lines+1] = "add_spacer|small|"
        end
    end

    lines[#lines+1] = "add_spacer|small|"
    if page > 1 then
        lines[#lines+1] = string.format("add_button|sb_btn_w_prev_%d|`w<< Prev Page `2(%d)|noflags|0|0|", page - 1, page - 1)
    end
    if page < totalPages then
        lines[#lines+1] = string.format("add_button|sb_btn_w_next_%d|`wNext Page >> `2(%d)|noflags|0|0|", page + 1, page + 1)
    end
    lines[#lines+1] = "add_button|sb_btn_clear_all_worlds|`wClear All Worlds `4(Delete All)|noflags|0|0|"
    lines[#lines+1] = "add_button|sb_btn_back_worlds|`wBack|noflags|0|0|"
    lines[#lines+1] = "end_dialog|sb_list_w|Close||"
    showClientDialog(table.concat(lines, "\n"))
end

-- 1.5 Edit World Put Entry
DLG.showSoilWorldEditDialog = function(idx)
    idx = tonumber(idx) or 1
    local entry = (CFG.farm_world_list or {})[idx]
    if not entry then return DLG.showSoilWorldListDialog(1) end

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        string.format("add_label_with_icon|big|`wEdit World Put #%d: %s``|left|2|", idx, entry.name),
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_text_input|sb_edit_w_name|World Name|%s|32|", entry.name or ""),
        string.format("add_text_input|sb_edit_w_door|Door ID (Opsional)|%s|16|", entry.door or ""),
        string.format("add_checkbox|sb_edit_w_done|Sudah Selesai (DONE)|%d|", (entry.done or entry.status == "DONE") and 1 or 0),
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        string.format("add_button|sb_btn_save_w_edit_%d|`wSave Changes `2(Save)|noflags|0|0|", idx),
        string.format("add_button|sb_btn_del_w_edit_%d|`wDelete World `4(Del)|noflags|0|0|", idx),
        "add_button|sb_btn_back_w_list|`wBack|noflags|0|0|",
        string.format("end_dialog|sb_edit_w_%d|Cancel||", idx)
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 1.6 File & Backup Manager
DLG.showSoilFileWorldDialog = function()
    local fName = CFG.world_file_name or "boren_soil_worlds.txt"
    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wBackup & File Manager``|left|2|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_textbox|`wSimpan atau muat antrean world dari file storage lokal:|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        string.format("add_text_input|sb_in_file_name|Nama File|%s|40|", fName),
        "add_spacer|small|",
        "add_button|sb_btn_do_save_file|`wSave Queue ke File `2(Save)|noflags|0|0|",
        "add_button|sb_btn_do_load_file|`wLoad Queue dari File `2(Load)|noflags|0|0|",
        "add_button|sb_btn_back_worlds|`wBack|noflags|0|0|",
        "end_dialog|sb_file_w|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- ============================================================================
-- 2. SETTING MULTI-GUDANG (STORAGE HUB + SUB-DIALOGS)
-- ============================================================================
DLG.showSoilStorageDialog = function()
    local toolCount = #(CFG.storage_tool_list or {})
    local blockCount = #(CFG.storage_block_list or {})
    local bId = tonumber(CFG.block_id) or 8772
    local bName = resolveItemName(bId)

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wSetting Multi-Gudang``|left|3802|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_textbox|`wGudang Alat: `2(%d World) `p- `wGudang Block: `2(%d World)|left|", toolCount, blockCount),
        string.format("add_textbox|`wBlock Target: `b%s `o(#%d)|left|", bName, bId),
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        "add_button|sb_btn_open_tool_store|`w1. Gudang Alat (WL, SL, Jammer, Door, Blast)|noflags|0|0|",
        string.format("add_button|sb_btn_open_tool_list|`w2. List Gudang Alat `2(%d World)|noflags|0|0|", toolCount),
        "add_button|sb_btn_open_block_store|`w3. Gudang Block & Water Elevator|noflags|0|0|",
        string.format("add_button|sb_btn_open_block_list|`w4. List Gudang Block `2(%d World)|noflags|0|0|", blockCount),
        "add_button|sb_btn_open_block_cfg|`w5. Pengaturan Bahan Block & Water|noflags|0|0|",
        "add_spacer|small|",
        "add_button|sb_btn_dlg_back_main|`wBack|noflags|0|0|",
        "end_dialog|sb_storage|Close||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 2.1 Gudang Alat
DLG.showSoilToolStorageDialog = function()
    local curW = getWorldNameSafe()
    if curW == "" then curW = "EXIT" end
    local count = #(CFG.storage_tool_list or {})

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wGudang Alat (WL/SL/Jammer/Door)``|left|242|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_textbox|`wTambah world gudang alat restock: `2(%d World)|left|", count),
        "add_textbox|`p(Format: WORLD atau WORLD:DOOR_ID)|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        "add_text_input|sb_in_tool_name|World Name||32|",
        "add_text_input|sb_in_tool_door|Door ID (Opsional)||16|",
        "add_spacer|small|",
        "add_button|sb_btn_do_add_tool|`wSave Gudang `2(Add)|noflags|0|0|",
        string.format("add_button|sb_btn_add_cur_tool|`wAdd Current World `2(%s)|noflags|0|0|", curW),
        "add_button|sb_btn_open_tool_batch|`wBatch Add Gudang Alat `2(Paste)|noflags|0|0|",
        string.format("add_button|sb_btn_open_tool_list|`wList Gudang Alat `2(%d World)|noflags|0|0|", count),
        "add_button|sb_btn_back_storage|`wBack|noflags|0|0|",
        "end_dialog|sb_tool_storage|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 2.2 Batch Add Gudang Alat
DLG.showSoilToolBatchDialog = function()
    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wBatch Add Gudang Alat``|left|242|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_textbox|`wMasukkan daftar gudang alat dipisah spasi, koma atau enter:|left|",
        "add_textbox|`p(Format: GUDANG1 GUDANG2:DOOR1 GUDANG3|DOOR2)|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        "add_text_input|sb_in_batch_tools|Gudang List||80|",
        "add_checkbox|sb_chk_batch_tool_replace|Ganti seluruh daftar (Replace)|0|",
        "add_spacer|small|",
        "add_button|sb_btn_do_batch_tool_add|`wAdd All Gudang `2(Batch)|noflags|0|0|",
        "add_button|sb_btn_back_tool_store|`wBack|noflags|0|0|",
        "end_dialog|sb_batch_tool|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 2.3 List Gudang Alat
DLG.showSoilToolListDialog = function(page)
    local list = CFG.storage_tool_list or {}
    local count = #list
    local perPage = 5
    local totalPages = math.max(1, math.ceil(count / perPage))
    page = math.max(1, math.min(totalPages, tonumber(page) or 1))
    DLG.tool_page = page

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wList Gudang Alat``|left|242|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_textbox|`wTotal Registered: `2(%d World) `p- `wPage `2(%d/%d)|left|", count, page, totalPages),
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
    }

    if count == 0 then
        lines[#lines+1] = "add_textbox|`4(Gudang alat masih kosong. Silakan tambah gudang)|left|"
    else
        local startIdx = (page - 1) * perPage + 1
        local endIdx = math.min(count, startIdx + perPage - 1)
        for i = startIdx, endIdx do
            local item = list[i]
            local dName = (item.door and item.door ~= "") and item.door or "-"
            lines[#lines+1] = string.format("add_textbox|`w#%d `b%s `p[Door: `e%s`p]|left|", i, item.name, dName)
            lines[#lines+1] = string.format("add_button|sb_btn_tool_edit_%d|`wEdit `2(#%d)|noflags|0|0|", i, i)
            lines[#lines+1] = string.format("add_button|sb_btn_tool_del_%d|`wDelete `4(#%d)|noflags|0|0|", i, i)
            lines[#lines+1] = "add_spacer|small|"
        end
    end

    lines[#lines+1] = "add_spacer|small|"
    if page > 1 then
        lines[#lines+1] = string.format("add_button|sb_btn_tool_prev_%d|`w<< Prev Page `2(%d)|noflags|0|0|", page - 1, page - 1)
    end
    if page < totalPages then
        lines[#lines+1] = string.format("add_button|sb_btn_tool_next_%d|`wNext Page >> `2(%d)|noflags|0|0|", page + 1, page + 1)
    end
    lines[#lines+1] = "add_button|sb_btn_clear_all_tools|`wClear All Tools `4(Delete All)|noflags|0|0|"
    lines[#lines+1] = "add_button|sb_btn_back_storage|`wBack|noflags|0|0|"
    lines[#lines+1] = "end_dialog|sb_tool_list|Close||"
    showClientDialog(table.concat(lines, "\n"))
end

-- 2.4 Edit Gudang Alat Entry
DLG.showSoilToolEditDialog = function(idx)
    idx = tonumber(idx) or 1
    local entry = (CFG.storage_tool_list or {})[idx]
    if not entry then return DLG.showSoilToolListDialog(1) end

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        string.format("add_label_with_icon|big|`wEdit Gudang Alat #%d: %s``|left|242|", idx, entry.name),
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_text_input|sb_edit_tool_name|World Name|%s|32|", entry.name or ""),
        string.format("add_text_input|sb_edit_tool_door|Door ID (Opsional)|%s|16|", entry.door or ""),
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        string.format("add_button|sb_btn_save_tool_edit_%d|`wSave Changes `2(Save)|noflags|0|0|", idx),
        string.format("add_button|sb_btn_del_tool_edit_%d|`wDelete World `4(Del)|noflags|0|0|", idx),
        "add_button|sb_btn_back_tool_list|`wBack|noflags|0|0|",
        string.format("end_dialog|sb_edit_tool_%d|Cancel||", idx)
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 2.5 Gudang Block & Water
DLG.showSoilBlockStorageDialog = function()
    local curW = getWorldNameSafe()
    if curW == "" then curW = "EXIT" end
    local count = #(CFG.storage_block_list or {})

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wGudang Block & Water``|left|8772|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_textbox|`wTambah world gudang restock block: `2(%d World)|left|", count),
        "add_textbox|`p(Format: WORLD atau WORLD:DOOR_ID)|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        "add_text_input|sb_in_block_name|World Name||32|",
        "add_text_input|sb_in_block_door|Door ID (Opsional)||16|",
        "add_spacer|small|",
        "add_button|sb_btn_do_add_block|`wSave Gudang `2(Add)|noflags|0|0|",
        string.format("add_button|sb_btn_add_cur_block|`wAdd Current World `2(%s)|noflags|0|0|", curW),
        "add_button|sb_btn_open_block_batch|`wBatch Add Gudang Block `2(Paste)|noflags|0|0|",
        string.format("add_button|sb_btn_open_block_list|`wList Gudang Block `2(%d World)|noflags|0|0|", count),
        "add_button|sb_btn_back_storage|`wBack|noflags|0|0|",
        "end_dialog|sb_block_storage|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 2.6 Batch Add Gudang Block
DLG.showSoilBlockBatchDialog = function()
    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wBatch Add Gudang Block``|left|8772|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_textbox|`wMasukkan daftar gudang block dipisah spasi, koma atau enter:|left|",
        "add_textbox|`p(Format: GUDANG1 GUDANG2:DOOR1 GUDANG3|DOOR2)|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        "add_text_input|sb_in_batch_blocks|Gudang List||80|",
        "add_checkbox|sb_chk_batch_block_replace|Ganti seluruh daftar (Replace)|0|",
        "add_spacer|small|",
        "add_button|sb_btn_do_batch_block_add|`wAdd All Gudang `2(Batch)|noflags|0|0|",
        "add_button|sb_btn_back_block_store|`wBack|noflags|0|0|",
        "end_dialog|sb_batch_block|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 2.7 List Gudang Block
DLG.showSoilBlockListDialog = function(page)
    local list = CFG.storage_block_list or {}
    local count = #list
    local perPage = 5
    local totalPages = math.max(1, math.ceil(count / perPage))
    page = math.max(1, math.min(totalPages, tonumber(page) or 1))
    DLG.block_page = page

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wList Gudang Block & Water``|left|8772|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_textbox|`wTotal Registered: `2(%d World) `p- `wPage `2(%d/%d)|left|", count, page, totalPages),
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
    }

    if count == 0 then
        lines[#lines+1] = "add_textbox|`4(Gudang block masih kosong. Silakan tambah gudang)|left|"
    else
        local startIdx = (page - 1) * perPage + 1
        local endIdx = math.min(count, startIdx + perPage - 1)
        for i = startIdx, endIdx do
            local item = list[i]
            local dName = (item.door and item.door ~= "") and item.door or "-"
            lines[#lines+1] = string.format("add_textbox|`w#%d `b%s `p[Door: `e%s`p]|left|", i, item.name, dName)
            lines[#lines+1] = string.format("add_button|sb_btn_blk_edit_%d|`wEdit `2(#%d)|noflags|0|0|", i, i)
            lines[#lines+1] = string.format("add_button|sb_btn_blk_del_%d|`wDelete `4(#%d)|noflags|0|0|", i, i)
            lines[#lines+1] = "add_spacer|small|"
        end
    end

    lines[#lines+1] = "add_spacer|small|"
    if page > 1 then
        lines[#lines+1] = string.format("add_button|sb_btn_blk_prev_%d|`w<< Prev Page `2(%d)|noflags|0|0|", page - 1, page - 1)
    end
    if page < totalPages then
        lines[#lines+1] = string.format("add_button|sb_btn_blk_next_%d|`wNext Page >> `2(%d)|noflags|0|0|", page + 1, page + 1)
    end
    lines[#lines+1] = "add_button|sb_btn_clear_all_blocks|`wClear All Blocks `4(Delete All)|noflags|0|0|"
    lines[#lines+1] = "add_button|sb_btn_back_storage|`wBack|noflags|0|0|"
    lines[#lines+1] = "end_dialog|sb_block_list|Close||"
    showClientDialog(table.concat(lines, "\n"))
end

-- 2.8 Edit Gudang Block Entry
DLG.showSoilBlockEditDialog = function(idx)
    idx = tonumber(idx) or 1
    local entry = (CFG.storage_block_list or {})[idx]
    if not entry then return DLG.showSoilBlockListDialog(1) end

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        string.format("add_label_with_icon|big|`wEdit Gudang Block #%d: %s``|left|8772|", idx, entry.name),
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_text_input|sb_edit_blk_name|World Name|%s|32|", entry.name or ""),
        string.format("add_text_input|sb_edit_blk_door|Door ID (Opsional)|%s|16|", entry.door or ""),
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        string.format("add_button|sb_btn_save_blk_edit_%d|`wSave Changes `2(Save)|noflags|0|0|", idx),
        string.format("add_button|sb_btn_del_blk_edit_%d|`wDelete World `4(Del)|noflags|0|0|", idx),
        "add_button|sb_btn_back_blk_list|`wBack|noflags|0|0|",
        string.format("end_dialog|sb_edit_blk_%d|Cancel||", idx)
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 2.9 Pengaturan Bahan Block & Water Elevator
DLG.showSoilBlockConfigDialog = function()
    local bId = tonumber(CFG.block_id) or 8772
    local bName = resolveItemName(bId)
    local enableWater = CFG.enable_water and 1 or 0
    local waterId = tonumber(CFG.water_item_id) or 822
    local waterX = tonumber(CFG.water_x) or 0

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wPengaturan Bahan Block & Water``|left|8772|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_textbox|`wBlock: `b%s `p- `wWater: `2(%s)|left|", bName, CFG.enable_water and "ON" or "OFF"),
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        string.format("add_text_input|sb_in_block_id|ID Block Diletakkan (Soil=8772)|%d|8|", bId),
        string.format("add_checkbox|sb_chk_enable_water|Pasang Kolom Water Elevator|%d|", enableWater),
        string.format("add_text_input|sb_in_water_id|ID Item Water (Water Bucket=822)|%d|8|", waterId),
        string.format("add_text_input|sb_in_water_x|Kolom Water Elevator X (0-10)|%d|4|", waterX),
        "add_spacer|small|",
        "add_button|sb_btn_save_block_cfg|`wSave Config `2(Save)|noflags|0|0|",
        "add_button|sb_btn_back_storage|`wBack|noflags|0|0|",
        "end_dialog|sb_block_cfg|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- ============================================================================
-- 3. LOCK & DOOR CONFIG HUB + SUB-DIALOGS
-- ============================================================================
DLG.showSoilLockDialog = function()
    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wLock & Door Config Hub``|left|242|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_textbox|`wFormasi Kunci Pintu Entrance (WL, SL, Jammer, Door, Blocker)|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        "add_button|sb_btn_open_wl_cfg|`w1. Formasi World Lock (WL)|noflags|0|0|",
        "add_button|sb_btn_open_sl_cfg|`w2. Formasi Small Lock (SL)|noflags|0|0|",
        "add_button|sb_btn_open_door_cfg|`w3. Formasi Door Utama (ID Door)|noflags|0|0|",
        "add_button|sb_btn_open_misc_lock|`w4. Jammer & Blocker (Air Vent)|noflags|0|0|",
        "add_spacer|small|",
        "add_button|sb_btn_dlg_back_main|`wBack|noflags|0|0|",
        "end_dialog|sb_lock|Close||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 3.1 World Lock
DLG.showSoilWLConfigDialog = function()
    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wSetting World Lock (WL)``|left|242|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_textbox|`wKonfigurasi World Lock untuk penguncian world farm:|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        string.format("add_checkbox|sb_chk_use_wl|Gunakan World Lock (WL)|%d|", CFG.use_wl and 1 or 0),
        string.format("add_checkbox|sb_chk_wl_public|Pasang WL secara Public|%d|", CFG.wl_public and 1 or 0),
        string.format("add_checkbox|sb_chk_ignore_lock|Abaikan jika sudah ada Lock|%d|", CFG.ignore_lock and 1 or 0),
        "add_spacer|small|",
        "add_button|sb_btn_save_wl_cfg|`wSave WL Config `2(Save)|noflags|0|0|",
        "add_button|sb_btn_back_lock|`wBack|noflags|0|0|",
        "end_dialog|sb_wl_cfg|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 3.2 Small Lock
DLG.showSoilSLConfigDialog = function()
    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wSetting Small Lock (SL)``|left|202|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_textbox|`wKonfigurasi Small Lock untuk perlindungan pintu entrance:|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        string.format("add_checkbox|sb_chk_use_sl|Gunakan Small Lock (SL)|%d|", CFG.use_sl and 1 or 0),
        string.format("add_checkbox|sb_chk_sl_public|Pasang SL secara Public|%d|", CFG.sl_public and 1 or 0),
        string.format("add_checkbox|sb_chk_sl_ignore_air|SL Ignore Air & Apply|%d|", CFG.sl_ignore_air and 1 or 0),
        "add_spacer|small|",
        "add_button|sb_btn_save_sl_cfg|`wSave SL Config `2(Save)|noflags|0|0|",
        "add_button|sb_btn_back_lock|`wBack|noflags|0|0|",
        "end_dialog|sb_sl_cfg|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 3.3 Door Utama (ID Door)
DLG.showSoilDoorConfigDialog = function()
    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wSetting Door Utama (ID Door)``|left|12|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_textbox|`wKonfigurasi pintu entrance dengan ID & Label kustom:|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        string.format("add_checkbox|sb_chk_use_id_door|Pasang Door ID Kustom|%d|", CFG.use_id_door and 1 or 0),
        string.format("add_text_input|sb_in_id_door_itemid|ID Item Door (Default 12)|%d|8|", tonumber(CFG.id_door_itemid) or 12),
        string.format("add_text_input|sb_in_door_id|Door ID (Default SOIL)|%s|16|", CFG.door_id or "SOIL"),
        string.format("add_text_input|sb_in_door_label|Label Pintu (Default SOIL)|%s|16|", CFG.door_label or "SOIL"),
        "add_spacer|small|",
        "add_button|sb_btn_save_door_cfg|`wSave Door Config `2(Save)|noflags|0|0|",
        "add_button|sb_btn_back_lock|`wBack|noflags|0|0|",
        "end_dialog|sb_door_cfg|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- 3.4 Jammer & Blocker (Air Vent)
DLG.showSoilMiscLockDialog = function()
    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wSetting Jammer & Air Vent``|left|226|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_textbox|`wKonfigurasi Signal Jammer & Blocker (Air Vent):|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        string.format("add_checkbox|sb_chk_use_jammer|Gunakan Signal Jammer|%d|", CFG.use_jammer and 1 or 0),
        string.format("add_checkbox|sb_chk_use_blocker|Gunakan Penghalang Kiri|%d|", CFG.use_blocker_door and 1 or 0),
        string.format("add_text_input|sb_in_blocker_itemid|ID Item Penghalang (Air Vent=2810)|%d|8|", tonumber(CFG.blocker_door_itemid) or 2810),
        string.format("add_text_input|sb_in_tele_delay|Jeda Teleport Pintu (ms)|%d|6|", tonumber(CFG.delay_tele_door) or 1500),
        "add_spacer|small|",
        "add_button|sb_btn_save_misc_cfg|`wSave Config `2(Save)|noflags|0|0|",
        "add_button|sb_btn_back_lock|`wBack|noflags|0|0|",
        "end_dialog|sb_misc_lock|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- ============================================================================
-- 4. PENGATURAN SOIL FARM & BOT
-- ============================================================================
DLG.showSoilSettingsDialog = function()
    local is3Z = (CFG.put_mode == "3zigzag") and 1 or 0
    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wPengaturan Soil Farm & Bot``|left|32|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_textbox|`wKonfigurasi tata letak grid baris, delay & cheats:|left|",
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        string.format("add_checkbox|sb_chk_mode_3zigzag|Mode Put 3 Block (Zigzag Cepat)|%d|", is3Z),
        string.format("add_text_input|sb_in_row_step|Jarak Baris / Step (1-4)|%d|4|", tonumber(CFG.row_step) or 2),
        string.format("add_text_input|sb_in_start_y|Baris Awal Y (1-10)|%d|4|", tonumber(CFG.row_start_y) or 1),
        string.format("add_text_input|sb_in_end_y|Baris Akhir Y (40-55)|%d|4|", tonumber(CFG.row_end_y) or 53),
        string.format("add_text_input|sb_in_start_x|Kolom Awal X (0-10)|%d|4|", tonumber(CFG.row_start_x) or 1),
        string.format("add_text_input|sb_in_end_x|Kolom Akhir X (80-98)|%d|4|", tonumber(CFG.row_end_x) or 98),
        string.format("add_checkbox|sb_chk_modfly|Aktifkan Modfly (Terbang Tembus)|%d|", CFG.use_modfly and 1 or 0),
        string.format("add_checkbox|sb_chk_anti_lava|Anti Lava / Duri|%d|", CFG.use_antilava and 1 or 0),
        string.format("add_checkbox|sb_chk_auto_collect|Auto Collect Item/Gems|%d|", CFG.auto_collect and 1 or 0),
        string.format("add_text_input|sb_in_delay_place|Delay Place (ms)|%d|6|", tonumber(CFG.delay_place) or 120),
        string.format("add_text_input|sb_in_delay_walk|Delay Jalan (ms)|%d|6|", tonumber(CFG.delay_walk) or 140),
        string.format("add_text_input|sb_in_delay_punch|Delay Pukul (ms)|%d|6|", tonumber(CFG.delay_punch) or 160),
        string.format("add_text_input|sb_in_delay_warp|Delay Warp World (ms)|%d|6|", tonumber(CFG.delay_warp) or 4000),
        "add_spacer|small|",
        "add_button|sb_btn_save_settings_cfg|`wSave Settings `2(Save)|noflags|0|0|",
        "add_button|sb_btn_dlg_back_main|`wBack|noflags|0|0|",
        "end_dialog|sb_settings|Cancel||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- ============================================================================
-- 5. LOG AKTIVITAS & TAS (COMPACT)
-- ============================================================================
DLG.showSoilLogsDialog = function()
    local logs = STATE.last_log_lines or {}
    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wLog Activity & Mini Console``|left|32|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
    }
    if #logs == 0 then
        lines[#lines+1] = "add_textbox|`oBelum ada catatan aktivitas bot.|left|"
    else
        local startIdx = math.max(1, #logs - 6)
        for i = startIdx, #logs do
            local cleanLine = tostring(logs[i] or ""):gsub("[\r\n]+", " ")
            if #cleanLine > 60 then cleanLine = cleanLine:sub(1, 57) .. "..." end
            lines[#lines+1] = string.format("add_textbox|%s|left|", cleanLine)
        end
    end
    lines[#lines+1] = "add_textbox|`p------------------------------------------------------------|left|"
    lines[#lines+1] = "add_spacer|small|"
    lines[#lines+1] = "add_button|sb_btn_dlg_clear_logs|`wBersihkan Log|noflags|0|0|"
    lines[#lines+1] = "add_button|sb_btn_open_bag_view|`wLihat Isi Backpack `2(Bag)|noflags|0|0|"
    lines[#lines+1] = "add_button|sb_btn_dlg_back_main|`wBack|noflags|0|0|"
    lines[#lines+1] = "end_dialog|sb_logs|Close||"
    showClientDialog(table.concat(lines, "\n"))
end

DLG.showSoilBagDialog = function()
    local bId = tonumber(CFG.block_id) or 8772
    local bName = resolveItemName(bId)
    local blockCount = getInvCount(bId)
    local waterCount = getInvCount(CFG.water_item_id or 822)
    local wlCount = getInvCount(ITEM.WORLD_LOCK or 242)
    local slCount = getInvCount(ITEM.SMALL_LOCK or 202)
    local jammerCount = getInvCount(ITEM.JAMMER or 226)
    local doorCount = getInvCount(CFG.id_door_itemid or ITEM.DOOR or 12)
    local blockerCount = getInvCount(CFG.blocker_door_itemid or ITEM.AIR_VENT or 2810)
    local blastCount = getInvCount(CFG.blast_item_id or 3562)

    local lines = {
        "set_default_color|`o",
        "add_quick_exit|",
        "add_label_with_icon|big|`wIsi Backpack / Inventory``|left|18|",
        "add_spacer|small|",
        "add_textbox|`p------------------------------------------------------------|left|",
        string.format("add_textbox|`w%s (#%d): `2%d item|left|", bName, bId, blockCount),
        string.format("add_textbox|`wWater Bucket (#%d): `2%d item|left|", CFG.water_item_id or 822, waterCount),
        string.format("add_textbox|`wWorld Lock (#242): `2%d item `p- `wSmall Lock (#202): `2%d|left|", wlCount, slCount),
        string.format("add_textbox|`wSignal Jammer (#226): `2%d item `p- `wDoor: `2%d|left|", jammerCount, doorCount),
        string.format("add_textbox|`wBlocker/Vent (#%d): `2%d item `p- `wBlast: `2%d|left|", CFG.blocker_door_itemid or 2810, blockerCount, blastCount),
        "add_textbox|`p------------------------------------------------------------|left|",
        "add_spacer|small|",
        "add_button|sb_btn_refresh_bag_dlg|`wRefresh Tas `2(Update)|noflags|0|0|",
        "add_button|sb_btn_back_logs|`wBack|noflags|0|0|",
        "end_dialog|sb_bag|Close||"
    }
    showClientDialog(table.concat(lines, "\n"))
end

-- ============================================================================
-- BACKWARDS COMPATIBILITY WRAPPERS
-- ============================================================================
openUnifiedWorldManager = function(fmt) return DLG.showSoilWorldListDialog(1) end
openEditWorldEntryDialog = function(idx) return DLG.showSoilWorldEditDialog(idx) end
openUnifiedToolManager = function(fmt) return DLG.showSoilToolListDialog(1) end
openEditToolEntryDialog = function(idx) return DLG.showSoilToolEditDialog(idx) end
openUnifiedBlockManager = function(fmt) return DLG.showSoilBlockListDialog(1) end
openEditBlockEntryDialog = function(idx) return DLG.showSoilBlockEditDialog(idx) end

_G.openUnifiedWorldManager = openUnifiedWorldManager
_G.openEditWorldEntryDialog = openEditWorldEntryDialog
_G.openUnifiedToolManager = openUnifiedToolManager
_G.openEditToolEntryDialog = openEditToolEntryDialog
_G.openUnifiedBlockManager = openUnifiedBlockManager
_G.openEditBlockEntryDialog = openEditBlockEntryDialog

-- ============================================================================
-- 17. COMPACT DIALOG PACKET RETURN HANDLER & PACKET HOOK
-- ============================================================================
local function handleSoilDialogReturn(pkt)
    if not pkt or type(pkt) ~= "string" then return false end
    local fields = {}
    for line in pkt:gmatch("[^\r\n]+") do
        local k, v = line:match("^([^|]+)|(.*)$")
        if k then
            v = v:gsub("^%s+", ""):gsub("%s+$", "")
            if v:sub(-1) == "|" then v = v:sub(1, -2) end
            fields[k] = v
        end
    end
    local dName = fields.dialog_name or pkt:match("dialog_name|([^|\r\n]+)") or ""
    local btn = fields.buttonClicked or pkt:match("buttonClicked|([^|\r\n]+)") or ""

    local function getVal(key)
        local val = fields[key] or pkt:match(key .. "|([^|\r\n]+)") or ""
        val = val:gsub("^%s+", ""):gsub("%s+$", "")
        if val:sub(-1) == "|" then val = val:sub(1, -2) end
        return val
    end
    local function getNum(key, default)
        local val = getVal(key)
        local n = tonumber(val:match("(%d+)"))
        return n or default
    end

    -- --- A. MAIN DIALOG ---
    if dName == "sb_main" or pkt:find("dialog_name|sb_main", 1, true) then
        if btn == "sb_btn_dlg_start" or pkt:find("buttonClicked|sb_btn_dlg_start", 1, true) then
            if not STATE.running then startSoilBot() end
            DLG.showSoilMainDialog()
            return true
        elseif btn == "sb_btn_dlg_stop" or pkt:find("buttonClicked|sb_btn_dlg_stop", 1, true) then
            stopSoilBot()
            DLG.showSoilMainDialog()
            return true
        elseif btn == "sb_btn_dlg_add_cur" or pkt:find("buttonClicked|sb_btn_dlg_add_cur", 1, true) then
            local cw = getWorldNameSafe()
            if cw and cw ~= "" and cw ~= "EXIT" then
                local exists = false
                for _, w in ipairs(CFG.farm_world_list or {}) do
                    if w.name == cw then exists = true; break end
                end
                if not exists then
                    table.insert(CFG.farm_world_list, { name = cw, door = "", done = false, status = "ANTRI" })
                    persistConfig()
                    if updateWorldDisplayList then pcall(updateWorldDisplayList) end
                    if sendNotification then pcall(sendNotification, "World " .. cw .. " ditambahkan!") end
                else
                    if sendNotification then pcall(sendNotification, cw .. " sudah ada di antrean!") end
                end
            end
            DLG.showSoilMainDialog()
            return true
        elseif btn == "sb_btn_dlg_worlds" or pkt:find("buttonClicked|sb_btn_dlg_worlds", 1, true) then
            DLG.showSoilWorldsDialog()
            return true
        elseif btn == "sb_btn_dlg_storage" or pkt:find("buttonClicked|sb_btn_dlg_storage", 1, true) then
            DLG.showSoilStorageDialog()
            return true
        elseif btn == "sb_btn_dlg_lock" or pkt:find("buttonClicked|sb_btn_dlg_lock", 1, true) then
            DLG.showSoilLockDialog()
            return true
        elseif btn == "sb_btn_dlg_settings" or pkt:find("buttonClicked|sb_btn_dlg_settings", 1, true) then
            DLG.showSoilSettingsDialog()
            return true
        elseif btn == "sb_btn_dlg_logs" or pkt:find("buttonClicked|sb_btn_dlg_logs", 1, true) then
            DLG.showSoilLogsDialog()
            return true
        elseif btn == "sb_btn_dlg_close" or pkt:find("buttonClicked|sb_btn_dlg_close", 1, true) then
            return true
        end
        return true

    -- --- B. SETTING WORLD PUT ---
    elseif dName == "sb_worlds" or pkt:find("dialog_name|sb_worlds", 1, true) then
        if btn == "sb_btn_toggle_mode" or pkt:find("buttonClicked|sb_btn_toggle_mode", 1, true) then
            CFG.world_mode = (CFG.world_mode == "random") and "manual" or "random"
            persistConfig()
            if sendNotification then pcall(sendNotification, "Mode World diubah: " .. CFG.world_mode:upper()) end
            DLG.showSoilWorldsDialog()
            return true
        elseif btn == "sb_btn_open_add_w" or pkt:find("buttonClicked|sb_btn_open_add_w", 1, true) then
            DLG.showSoilAddWorldDialog()
            return true
        elseif btn == "sb_btn_open_find_w" or pkt:find("buttonClicked|sb_btn_open_find_w", 1, true) then
            DLG.showSoilFindWorldDialog()
            return true
        elseif btn == "sb_btn_open_batch_w" or pkt:find("buttonClicked|sb_btn_open_batch_w", 1, true) then
            DLG.showSoilBatchWorldDialog()
            return true
        elseif btn == "sb_btn_open_list_w" or pkt:find("buttonClicked|sb_btn_open_list_w", 1, true) then
            DLG.showSoilWorldListDialog(1)
            return true
        elseif btn == "sb_btn_open_file_w" or pkt:find("buttonClicked|sb_btn_open_file_w", 1, true) then
            DLG.showSoilFileWorldDialog()
            return true
        elseif btn == "sb_btn_dlg_reset_queue" or pkt:find("buttonClicked|sb_btn_dlg_reset_queue", 1, true) then
            for _, w in ipairs(CFG.farm_world_list or {}) do w.done = false; w.status = "ANTRI" end
            persistConfig()
            if updateWorldDisplayList then pcall(updateWorldDisplayList) end
            if sendNotification then pcall(sendNotification, "Status queue di-reset!") end
            DLG.showSoilWorldsDialog()
            return true
        elseif btn == "sb_btn_dlg_back_main" or pkt:find("buttonClicked|sb_btn_dlg_back_main", 1, true) then
            DLG.showSoilMainDialog()
            return true
        end
        return true

    -- Add Single World
    elseif dName == "sb_add_w" or pkt:find("dialog_name|sb_add_w", 1, true) then
        if btn == "sb_btn_do_add_world" or pkt:find("buttonClicked|sb_btn_do_add_world", 1, true) then
            local rawW = getVal("sb_in_world_name"):upper():gsub("%s+", "")
            local wDoor = getVal("sb_in_door_id"):gsub("%s+", "")
            local wName = rawW
            if rawW:find(":") then wName, wDoor = rawW:match("^([^:]+):?(.*)$")
            elseif rawW:find("|") then wName, wDoor = rawW:match("^([^|]+)|?(.*)$") end
            if wName and wName ~= "" and wName ~= "0" and wName ~= "EXIT" then
                local exists = false
                for _, w in ipairs(CFG.farm_world_list or {}) do
                    if w.name == wName then exists = true; break end
                end
                if not exists then
                    table.insert(CFG.farm_world_list, { name = wName, door = wDoor or "", done = false, status = "ANTRI" })
                    persistConfig()
                    if updateWorldDisplayList then pcall(updateWorldDisplayList) end
                    if sendNotification then pcall(sendNotification, "World " .. wName .. " ditambahkan!") end
                else
                    if sendNotification then pcall(sendNotification, wName .. " sudah ada di antrean!") end
                end
            end
            DLG.showSoilWorldsDialog()
            return true
        elseif btn == "sb_btn_add_cur_w" or pkt:find("buttonClicked|sb_btn_add_cur_w", 1, true) then
            local cw = getWorldNameSafe()
            if cw and cw ~= "" and cw ~= "EXIT" then
                local exists = false
                for _, w in ipairs(CFG.farm_world_list or {}) do
                    if w.name == cw then exists = true; break end
                end
                if not exists then
                    table.insert(CFG.farm_world_list, { name = cw, door = "", done = false, status = "ANTRI" })
                    persistConfig()
                    if updateWorldDisplayList then pcall(updateWorldDisplayList) end
                    if sendNotification then pcall(sendNotification, "World " .. cw .. " ditambahkan!") end
                else
                    if sendNotification then pcall(sendNotification, cw .. " sudah ada di antrean!") end
                end
            end
            DLG.showSoilAddWorldDialog()
            return true
        elseif btn == "sb_btn_back_worlds" or pkt:find("buttonClicked|sb_btn_back_worlds", 1, true) then
            DLG.showSoilWorldsDialog()
            return true
        end
        return true

    -- Find Random World
    elseif dName == "sb_find_w" or pkt:find("dialog_name|sb_find_w", 1, true) then
        local lenVal = getNum("sb_in_find_len", 0)
        if lenVal and lenVal >= 3 and lenVal <= 16 then CFG.random_length = lenVal end
        local numVal = getVal("sb_chk_find_num")
        if numVal ~= "" then CFG.random_use_numbers = (numVal:find("1") ~= nil) end
        local tarVal = getNum("sb_in_find_target", 0)
        if tarVal and tarVal >= 1 then CFG.random_target_count = tarVal end
        local blastChk = getVal("sb_chk_auto_blast")
        if blastChk ~= "" then CFG.auto_use_blast = (blastChk:find("1") ~= nil) end
        local bId = getNum("sb_in_blast_id", 0)
        if bId and bId > 0 then CFG.blast_item_id = bId end
        persistConfig()

        if btn == "sb_btn_find_toggle_mode" or pkt:find("buttonClicked|sb_btn_find_toggle_mode", 1, true) then
            CFG.world_mode = (CFG.world_mode == "random") and "manual" or "random"
            persistConfig()
            if sendNotification then pcall(sendNotification, "Find Random World: " .. ((CFG.world_mode == "random") and "ON" or "OFF")) end
            DLG.showSoilFindWorldDialog()
            return true
        elseif btn == "sb_btn_generate_1_world" or pkt:find("buttonClicked|sb_btn_generate_1_world", 1, true) then
            local rLen = tonumber(CFG.random_length) or 6
            local rNum = CFG.random_use_numbers
            local randName = generateRandomWorldName(rLen, rNum)
            if randName and randName ~= "" then
                table.insert(CFG.farm_world_list, { name = randName, door = "", done = false, status = "ANTRI" })
                persistConfig()
                if updateWorldDisplayList then pcall(updateWorldDisplayList) end
                if sendNotification then pcall(sendNotification, "Generated: " .. randName) end
            end
            DLG.showSoilFindWorldDialog()
            return true
        elseif btn == "sb_btn_save_find_cfg" or pkt:find("buttonClicked|sb_btn_save_find_cfg", 1, true) then
            if sendNotification then pcall(sendNotification, "Konfigurasi Find World disimpan!") end
            DLG.showSoilFindWorldDialog()
            return true
        elseif btn == "sb_btn_back_worlds" or pkt:find("buttonClicked|sb_btn_back_worlds", 1, true) then
            DLG.showSoilWorldsDialog()
            return true
        end
        return true

    -- Batch Add World
    elseif dName == "sb_batch_w" or pkt:find("dialog_name|sb_batch_w", 1, true) then
        if btn == "sb_btn_do_batch_add" or pkt:find("buttonClicked|sb_btn_do_batch_add", 1, true) then
            local raw = getVal("sb_in_batch_worlds")
            local rep = (getVal("sb_chk_batch_replace") == "1")
            if rep then CFG.farm_world_list = {} end
            local parsed = parseWorldBatchFromString(raw)
            local added = 0
            for _, item in ipairs(parsed) do
                local exists = false
                for _, w in ipairs(CFG.farm_world_list) do
                    if w.name == item.name then exists = true; break end
                end
                if not exists then
                    table.insert(CFG.farm_world_list, { name = item.name, door = item.door or "", status = "ANTRI", done = false })
                    added = added + 1
                end
            end
            persistConfig()
            if updateWorldDisplayList then pcall(updateWorldDisplayList) end
            if sendNotification then pcall(sendNotification, string.format("%d World ditambahkan!", added)) end
            DLG.showSoilWorldsDialog()
            return true
        elseif btn == "sb_btn_back_worlds" or pkt:find("buttonClicked|sb_btn_back_worlds", 1, true) then
            DLG.showSoilWorldsDialog()
            return true
        end
        return true

    -- List World Put (Pagination & Actions)
    elseif dName == "sb_list_w" or pkt:find("dialog_name|sb_list_w", 1, true) then
        local prevP = btn:match("sb_btn_w_prev_(%d+)")
        local nextP = btn:match("sb_btn_w_next_(%d+)")
        local editIdx = btn:match("sb_btn_w_edit_(%d+)")
        local delIdx = btn:match("sb_btn_w_del_(%d+)")

        if prevP then
            DLG.showSoilWorldListDialog(tonumber(prevP))
            return true
        elseif nextP then
            DLG.showSoilWorldListDialog(tonumber(nextP))
            return true
        elseif editIdx then
            DLG.showSoilWorldEditDialog(tonumber(editIdx))
            return true
        elseif delIdx then
            local idx = tonumber(delIdx)
            if idx and CFG.farm_world_list[idx] then
                table.remove(CFG.farm_world_list, idx)
                persistConfig()
                if updateWorldDisplayList then pcall(updateWorldDisplayList) end
                if sendNotification then pcall(sendNotification, "World #" .. idx .. " dihapus!") end
            end
            DLG.showSoilWorldListDialog(DLG.wlist_page or 1)
            return true
        elseif btn == "sb_btn_clear_all_worlds" or pkt:find("buttonClicked|sb_btn_clear_all_worlds", 1, true) then
            CFG.farm_world_list = {}
            persistConfig()
            if updateWorldDisplayList then pcall(updateWorldDisplayList) end
            if sendNotification then pcall(sendNotification, "Semua world di-clear!") end
            DLG.showSoilWorldListDialog(1)
            return true
        elseif btn == "sb_btn_back_worlds" or pkt:find("buttonClicked|sb_btn_back_worlds", 1, true) then
            DLG.showSoilWorldsDialog()
            return true
        end
        return true

    -- Edit World Put Dialog
    elseif dName:find("^sb_edit_w_(%d+)$") or pkt:find("dialog_name|sb_edit_w_", 1, true) then
        local idx = tonumber(dName:match("^sb_edit_w_(%d+)") or pkt:match("dialog_name|sb_edit_w_(%d+)"))
        if not idx then
            idx = tonumber(btn:match("sb_btn_save_w_edit_(%d+)") or btn:match("sb_btn_del_w_edit_(%d+)"))
        end
        if idx and CFG.farm_world_list[idx] then
            if btn:find("sb_btn_save_w_edit_") or pkt:find("buttonClicked|sb_btn_save_w_edit_", 1, true) then
                local newName = getVal("sb_edit_w_name"):upper():gsub("%s+", "")
                local newDoor = getVal("sb_edit_w_door"):gsub("%s+", "")
                local newDone = (getVal("sb_edit_w_done") == "1")
                if newName ~= "" and newName ~= "0" and newName ~= "EXIT" then
                    CFG.farm_world_list[idx].name = newName
                    CFG.farm_world_list[idx].door = newDoor
                    CFG.farm_world_list[idx].done = newDone
                    CFG.farm_world_list[idx].status = newDone and "DONE" or "ANTRI"
                    persistConfig()
                    if updateWorldDisplayList then pcall(updateWorldDisplayList) end
                    if sendNotification then pcall(sendNotification, "World #" .. idx .. " diupdate!") end
                end
                DLG.showSoilWorldListDialog(DLG.wlist_page or 1)
                return true
            elseif btn:find("sb_btn_del_w_edit_") or pkt:find("buttonClicked|sb_btn_del_w_edit_", 1, true) then
                table.remove(CFG.farm_world_list, idx)
                persistConfig()
                if updateWorldDisplayList then pcall(updateWorldDisplayList) end
                if sendNotification then pcall(sendNotification, "World #" .. idx .. " dihapus!") end
                DLG.showSoilWorldListDialog(DLG.wlist_page or 1)
                return true
            end
        end
        if btn == "sb_btn_back_w_list" or pkt:find("buttonClicked|sb_btn_back_w_list", 1, true) then
            DLG.showSoilWorldListDialog(DLG.wlist_page or 1)
            return true
        end
        return true

    -- File & Backup Manager
    elseif dName == "sb_file_w" or pkt:find("dialog_name|sb_file_w", 1, true) then
        if btn == "sb_btn_do_save_file" or pkt:find("buttonClicked|sb_btn_do_save_file", 1, true) then
            local fn = getVal("sb_in_file_name")
            if fn ~= "" then CFG.world_file_name = fn end
            local lines = {}
            for _, w in ipairs(CFG.farm_world_list or {}) do
                local d = (w.door and w.door ~= "") and w.door or ""
                table.insert(lines, (d ~= "") and (w.name .. ":" .. d) or w.name)
            end
            safeWriteFile(CFG.world_file_name, table.concat(lines, "\n"))
            persistConfig()
            if sendNotification then pcall(sendNotification, string.format("Antrean disimpan ke %s (%d world)", CFG.world_file_name, #CFG.farm_world_list)) end
            DLG.showSoilFileWorldDialog()
            return true
        elseif btn == "sb_btn_do_load_file" or pkt:find("buttonClicked|sb_btn_do_load_file", 1, true) then
            local fn = getVal("sb_in_file_name")
            if fn ~= "" then CFG.world_file_name = fn end
            local content = safeReadFile(CFG.world_file_name)
            if content and content ~= "" then
                local parsed = parseWorldBatchFromString(content)
                local count = 0
                for _, item in ipairs(parsed) do
                    table.insert(CFG.farm_world_list, { name = item.name, door = item.door, status = "ANTRI", done = false })
                    count = count + 1
                end
                persistConfig()
                if updateWorldDisplayList then pcall(updateWorldDisplayList) end
                if sendNotification then pcall(sendNotification, string.format("%d World dimuat dari %s!", count, CFG.world_file_name)) end
            else
                if sendNotification then pcall(sendNotification, "Gagal membaca: " .. CFG.world_file_name) end
            end
            DLG.showSoilFileWorldDialog()
            return true
        elseif btn == "sb_btn_back_worlds" or pkt:find("buttonClicked|sb_btn_back_worlds", 1, true) then
            DLG.showSoilWorldsDialog()
            return true
        end
        return true

    -- --- C. SETTING STORAGE HUB ---
    elseif dName == "sb_storage" or pkt:find("dialog_name|sb_storage", 1, true) then
        if btn == "sb_btn_open_tool_store" or pkt:find("buttonClicked|sb_btn_open_tool_store", 1, true) then
            DLG.showSoilToolStorageDialog()
            return true
        elseif btn == "sb_btn_open_tool_list" or pkt:find("buttonClicked|sb_btn_open_tool_list", 1, true) then
            DLG.showSoilToolListDialog(1)
            return true
        elseif btn == "sb_btn_open_block_store" or pkt:find("buttonClicked|sb_btn_open_block_store", 1, true) then
            DLG.showSoilBlockStorageDialog()
            return true
        elseif btn == "sb_btn_open_block_list" or pkt:find("buttonClicked|sb_btn_open_block_list", 1, true) then
            DLG.showSoilBlockListDialog(1)
            return true
        elseif btn == "sb_btn_open_block_cfg" or pkt:find("buttonClicked|sb_btn_open_block_cfg", 1, true) then
            DLG.showSoilBlockConfigDialog()
            return true
        elseif btn == "sb_btn_dlg_back_main" or pkt:find("buttonClicked|sb_btn_dlg_back_main", 1, true) then
            DLG.showSoilMainDialog()
            return true
        end
        return true

    -- Gudang Alat
    elseif dName == "sb_tool_storage" or pkt:find("dialog_name|sb_tool_storage", 1, true) then
        if btn == "sb_btn_do_add_tool" or pkt:find("buttonClicked|sb_btn_do_add_tool", 1, true) then
            local raw = getVal("sb_in_tool_name"):upper():gsub("%s+", "")
            local d = getVal("sb_in_tool_door"):gsub("%s+", "")
            local name = raw
            if raw:find(":") then name, d = raw:match("^([^:]+):?(.*)$")
            elseif raw:find("|") then name, d = raw:match("^([^|]+)|?(.*)$") end
            if name and name ~= "" and name ~= "0" and name ~= "EXIT" then
                table.insert(CFG.storage_tool_list, { name = name, door = d or "" })
                persistConfig()
                if updateToolDisplayList then pcall(updateToolDisplayList) end
                if sendNotification then pcall(sendNotification, "Gudang Alat " .. name .. " ditambahkan!") end
            end
            DLG.showSoilStorageDialog()
            return true
        elseif btn == "sb_btn_add_cur_tool" or pkt:find("buttonClicked|sb_btn_add_cur_tool", 1, true) then
            local curW = getWorldNameSafe()
            if curW and curW ~= "" and curW ~= "EXIT" then
                table.insert(CFG.storage_tool_list, { name = curW, door = "" })
                persistConfig()
                if updateToolDisplayList then pcall(updateToolDisplayList) end
                if sendNotification then pcall(sendNotification, "Gudang Alat " .. curW .. " ditambahkan!") end
            end
            DLG.showSoilToolStorageDialog()
            return true
        elseif btn == "sb_btn_open_tool_batch" or pkt:find("buttonClicked|sb_btn_open_tool_batch", 1, true) then
            DLG.showSoilToolBatchDialog()
            return true
        elseif btn == "sb_btn_open_tool_list" or pkt:find("buttonClicked|sb_btn_open_tool_list", 1, true) then
            DLG.showSoilToolListDialog(1)
            return true
        elseif btn == "sb_btn_back_storage" or pkt:find("buttonClicked|sb_btn_back_storage", 1, true) then
            DLG.showSoilStorageDialog()
            return true
        end
        return true

    -- Batch Gudang Alat
    elseif dName == "sb_batch_tool" or pkt:find("dialog_name|sb_batch_tool", 1, true) then
        if btn == "sb_btn_do_batch_tool_add" or pkt:find("buttonClicked|sb_btn_do_batch_tool_add", 1, true) then
            local raw = getVal("sb_in_batch_tools")
            local rep = (getVal("sb_chk_batch_tool_replace") == "1")
            if rep then CFG.storage_tool_list = {} end
            local parsed = parseWorldBatchFromString(raw)
            local added = 0
            for _, item in ipairs(parsed) do
                table.insert(CFG.storage_tool_list, { name = item.name, door = item.door or "" })
                added = added + 1
            end
            persistConfig()
            if updateToolDisplayList then pcall(updateToolDisplayList) end
            if sendNotification then pcall(sendNotification, string.format("%d Gudang Alat ditambahkan!", added)) end
            DLG.showSoilStorageDialog()
            return true
        elseif btn == "sb_btn_back_tool_store" or pkt:find("buttonClicked|sb_btn_back_tool_store", 1, true) then
            DLG.showSoilToolStorageDialog()
            return true
        end
        return true

    -- List Gudang Alat
    elseif dName == "sb_tool_list" or pkt:find("dialog_name|sb_tool_list", 1, true) then
        local prevP = btn:match("sb_btn_tool_prev_(%d+)")
        local nextP = btn:match("sb_btn_tool_next_(%d+)")
        local editIdx = btn:match("sb_btn_tool_edit_(%d+)")
        local delIdx = btn:match("sb_btn_tool_del_(%d+)")

        if prevP then
            DLG.showSoilToolListDialog(tonumber(prevP))
            return true
        elseif nextP then
            DLG.showSoilToolListDialog(tonumber(nextP))
            return true
        elseif editIdx then
            DLG.showSoilToolEditDialog(tonumber(editIdx))
            return true
        elseif delIdx then
            local idx = tonumber(delIdx)
            if idx and CFG.storage_tool_list[idx] then
                table.remove(CFG.storage_tool_list, idx)
                persistConfig()
                if updateToolDisplayList then pcall(updateToolDisplayList) end
                if sendNotification then pcall(sendNotification, "Gudang Alat #" .. idx .. " dihapus!") end
            end
            DLG.showSoilToolListDialog(DLG.tool_page or 1)
            return true
        elseif btn == "sb_btn_clear_all_tools" or pkt:find("buttonClicked|sb_btn_clear_all_tools", 1, true) then
            CFG.storage_tool_list = {}
            persistConfig()
            if updateToolDisplayList then pcall(updateToolDisplayList) end
            if sendNotification then pcall(sendNotification, "Semua gudang alat di-clear!") end
            DLG.showSoilToolListDialog(1)
            return true
        elseif btn == "sb_btn_back_storage" or pkt:find("buttonClicked|sb_btn_back_storage", 1, true) then
            DLG.showSoilStorageDialog()
            return true
        end
        return true

    -- Edit Gudang Alat Dialog
    elseif dName:find("^sb_edit_tool_(%d+)$") or pkt:find("dialog_name|sb_edit_tool_", 1, true) then
        local idx = tonumber(dName:match("^sb_edit_tool_(%d+)") or pkt:match("dialog_name|sb_edit_tool_(%d+)"))
        if not idx then
            idx = tonumber(btn:match("sb_btn_save_tool_edit_(%d+)") or btn:match("sb_btn_del_tool_edit_(%d+)"))
        end
        if idx and CFG.storage_tool_list[idx] then
            if btn:find("sb_btn_save_tool_edit_") or pkt:find("buttonClicked|sb_btn_save_tool_edit_", 1, true) then
                local newName = getVal("sb_edit_tool_name"):upper():gsub("%s+", "")
                local newDoor = getVal("sb_edit_tool_door"):gsub("%s+", "")
                if newName ~= "" and newName ~= "0" and newName ~= "EXIT" then
                    CFG.storage_tool_list[idx].name = newName
                    CFG.storage_tool_list[idx].door = newDoor
                    persistConfig()
                    if updateToolDisplayList then pcall(updateToolDisplayList) end
                    if sendNotification then pcall(sendNotification, "Gudang Alat #" .. idx .. " diupdate!") end
                end
                DLG.showSoilToolListDialog(DLG.tool_page or 1)
                return true
            elseif btn:find("sb_btn_del_tool_edit_") or pkt:find("buttonClicked|sb_btn_del_tool_edit_", 1, true) then
                table.remove(CFG.storage_tool_list, idx)
                persistConfig()
                if updateToolDisplayList then pcall(updateToolDisplayList) end
                if sendNotification then pcall(sendNotification, "Gudang Alat #" .. idx .. " dihapus!") end
                DLG.showSoilToolListDialog(DLG.tool_page or 1)
                return true
            end
        end
        if btn == "sb_btn_back_tool_list" or pkt:find("buttonClicked|sb_btn_back_tool_list", 1, true) then
            DLG.showSoilToolListDialog(DLG.tool_page or 1)
            return true
        end
        return true

    -- Gudang Block & Water
    elseif dName == "sb_block_storage" or pkt:find("dialog_name|sb_block_storage", 1, true) then
        if btn == "sb_btn_do_add_block" or pkt:find("buttonClicked|sb_btn_do_add_block", 1, true) then
            local raw = getVal("sb_in_block_name"):upper():gsub("%s+", "")
            local d = getVal("sb_in_block_door"):gsub("%s+", "")
            local name = raw
            if raw:find(":") then name, d = raw:match("^([^:]+):?(.*)$")
            elseif raw:find("|") then name, d = raw:match("^([^|]+)|?(.*)$") end
            if name and name ~= "" and name ~= "0" and name ~= "EXIT" then
                table.insert(CFG.storage_block_list, { name = name, door = d or "" })
                persistConfig()
                if updateBlockDisplayList then pcall(updateBlockDisplayList) end
                if sendNotification then pcall(sendNotification, "Gudang Block " .. name .. " ditambahkan!") end
            end
            DLG.showSoilStorageDialog()
            return true
        elseif btn == "sb_btn_add_cur_block" or pkt:find("buttonClicked|sb_btn_add_cur_block", 1, true) then
            local curW = getWorldNameSafe()
            if curW and curW ~= "" and curW ~= "EXIT" then
                table.insert(CFG.storage_block_list, { name = curW, door = "" })
                persistConfig()
                if updateBlockDisplayList then pcall(updateBlockDisplayList) end
                if sendNotification then pcall(sendNotification, "Gudang Block " .. curW .. " ditambahkan!") end
            end
            DLG.showSoilBlockStorageDialog()
            return true
        elseif btn == "sb_btn_open_block_batch" or pkt:find("buttonClicked|sb_btn_open_block_batch", 1, true) then
            DLG.showSoilBlockBatchDialog()
            return true
        elseif btn == "sb_btn_open_block_list" or pkt:find("buttonClicked|sb_btn_open_block_list", 1, true) then
            DLG.showSoilBlockListDialog(1)
            return true
        elseif btn == "sb_btn_back_storage" or pkt:find("buttonClicked|sb_btn_back_storage", 1, true) then
            DLG.showSoilStorageDialog()
            return true
        end
        return true

    -- Batch Gudang Block
    elseif dName == "sb_batch_block" or pkt:find("dialog_name|sb_batch_block", 1, true) then
        if btn == "sb_btn_do_batch_block_add" or pkt:find("buttonClicked|sb_btn_do_batch_block_add", 1, true) then
            local raw = getVal("sb_in_batch_blocks")
            local rep = (getVal("sb_chk_batch_block_replace") == "1")
            if rep then CFG.storage_block_list = {} end
            local parsed = parseWorldBatchFromString(raw)
            local added = 0
            for _, item in ipairs(parsed) do
                table.insert(CFG.storage_block_list, { name = item.name, door = item.door or "" })
                added = added + 1
            end
            persistConfig()
            if updateBlockDisplayList then pcall(updateBlockDisplayList) end
            if sendNotification then pcall(sendNotification, string.format("%d Gudang Block ditambahkan!", added)) end
            DLG.showSoilStorageDialog()
            return true
        elseif btn == "sb_btn_back_block_store" or pkt:find("buttonClicked|sb_btn_back_block_store", 1, true) then
            DLG.showSoilBlockStorageDialog()
            return true
        end
        return true

    -- List Gudang Block
    elseif dName == "sb_block_list" or pkt:find("dialog_name|sb_block_list", 1, true) then
        local prevP = btn:match("sb_btn_blk_prev_(%d+)")
        local nextP = btn:match("sb_btn_blk_next_(%d+)")
        local editIdx = btn:match("sb_btn_blk_edit_(%d+)")
        local delIdx = btn:match("sb_btn_blk_del_(%d+)")

        if prevP then
            DLG.showSoilBlockListDialog(tonumber(prevP))
            return true
        elseif nextP then
            DLG.showSoilBlockListDialog(tonumber(nextP))
            return true
        elseif editIdx then
            DLG.showSoilBlockEditDialog(tonumber(editIdx))
            return true
        elseif delIdx then
            local idx = tonumber(delIdx)
            if idx and CFG.storage_block_list[idx] then
                table.remove(CFG.storage_block_list, idx)
                persistConfig()
                if updateBlockDisplayList then pcall(updateBlockDisplayList) end
                if sendNotification then pcall(sendNotification, "Gudang Block #" .. idx .. " dihapus!") end
            end
            DLG.showSoilBlockListDialog(DLG.block_page or 1)
            return true
        elseif btn == "sb_btn_clear_all_blocks" or pkt:find("buttonClicked|sb_btn_clear_all_blocks", 1, true) then
            CFG.storage_block_list = {}
            persistConfig()
            if updateBlockDisplayList then pcall(updateBlockDisplayList) end
            if sendNotification then pcall(sendNotification, "Semua gudang block di-clear!") end
            DLG.showSoilBlockListDialog(1)
            return true
        elseif btn == "sb_btn_back_storage" or pkt:find("buttonClicked|sb_btn_back_storage", 1, true) then
            DLG.showSoilStorageDialog()
            return true
        end
        return true

    -- Edit Gudang Block Dialog
    elseif dName:find("^sb_edit_blk_(%d+)$") or pkt:find("dialog_name|sb_edit_blk_", 1, true) then
        local idx = tonumber(dName:match("^sb_edit_blk_(%d+)") or pkt:match("dialog_name|sb_edit_blk_(%d+)"))
        if not idx then
            idx = tonumber(btn:match("sb_btn_save_blk_edit_(%d+)") or btn:match("sb_btn_del_blk_edit_(%d+)"))
        end
        if idx and CFG.storage_block_list[idx] then
            if btn:find("sb_btn_save_blk_edit_") or pkt:find("buttonClicked|sb_btn_save_blk_edit_", 1, true) then
                local newName = getVal("sb_edit_blk_name"):upper():gsub("%s+", "")
                local newDoor = getVal("sb_edit_blk_door"):gsub("%s+", "")
                if newName ~= "" and newName ~= "0" and newName ~= "EXIT" then
                    CFG.storage_block_list[idx].name = newName
                    CFG.storage_block_list[idx].door = newDoor
                    persistConfig()
                    if updateBlockDisplayList then pcall(updateBlockDisplayList) end
                    if sendNotification then pcall(sendNotification, "Gudang Block #" .. idx .. " diupdate!") end
                end
                DLG.showSoilBlockListDialog(DLG.block_page or 1)
                return true
            elseif btn:find("sb_btn_del_blk_edit_") or pkt:find("buttonClicked|sb_btn_del_blk_edit_", 1, true) then
                table.remove(CFG.storage_block_list, idx)
                persistConfig()
                if updateBlockDisplayList then pcall(updateBlockDisplayList) end
                if sendNotification then pcall(sendNotification, "Gudang Block #" .. idx .. " dihapus!") end
                DLG.showSoilBlockListDialog(DLG.block_page or 1)
                return true
            end
        end
        if btn == "sb_btn_back_blk_list" or pkt:find("buttonClicked|sb_btn_back_blk_list", 1, true) then
            DLG.showSoilBlockListDialog(DLG.block_page or 1)
            return true
        end
        return true

    -- Pengaturan Bahan Block & Water
    elseif dName == "sb_block_cfg" or pkt:find("dialog_name|sb_block_cfg", 1, true) then
        if btn == "sb_btn_save_block_cfg" or pkt:find("buttonClicked|sb_btn_save_block_cfg", 1, true) then
            local bId = getNum("sb_in_block_id", 0)
            if bId and bId > 0 then CFG.block_id = bId end
            local enWater = getVal("sb_chk_enable_water")
            if enWater ~= "" then CFG.enable_water = (enWater:find("1") ~= nil) end
            local wId = getNum("sb_in_water_id", 0)
            if wId and wId > 0 then CFG.water_item_id = wId end
            local wX = getNum("sb_in_water_x", -1)
            if wX and wX >= 0 and wX <= 10 then CFG.water_x = wX end
            persistConfig()
            if sendNotification then pcall(sendNotification, "Pengaturan Block & Water disimpan!") end
            DLG.showSoilBlockConfigDialog()
            return true
        elseif btn == "sb_btn_back_storage" or pkt:find("buttonClicked|sb_btn_back_storage", 1, true) then
            DLG.showSoilStorageDialog()
            return true
        end
        return true

    -- --- D. LOCK & DOOR CONFIG HUB ---
    elseif dName == "sb_lock" or pkt:find("dialog_name|sb_lock", 1, true) then
        if btn == "sb_btn_open_wl_cfg" or pkt:find("buttonClicked|sb_btn_open_wl_cfg", 1, true) then
            DLG.showSoilWLConfigDialog()
            return true
        elseif btn == "sb_btn_open_sl_cfg" or pkt:find("buttonClicked|sb_btn_open_sl_cfg", 1, true) then
            DLG.showSoilSLConfigDialog()
            return true
        elseif btn == "sb_btn_open_door_cfg" or pkt:find("buttonClicked|sb_btn_open_door_cfg", 1, true) then
            DLG.showSoilDoorConfigDialog()
            return true
        elseif btn == "sb_btn_open_misc_lock" or pkt:find("buttonClicked|sb_btn_open_misc_lock", 1, true) then
            DLG.showSoilMiscLockDialog()
            return true
        elseif btn == "sb_btn_dlg_back_main" or pkt:find("buttonClicked|sb_btn_dlg_back_main", 1, true) then
            DLG.showSoilMainDialog()
            return true
        end
        return true

    -- WL Config
    elseif dName == "sb_wl_cfg" or pkt:find("dialog_name|sb_wl_cfg", 1, true) then
        if btn == "sb_btn_save_wl_cfg" or pkt:find("buttonClicked|sb_btn_save_wl_cfg", 1, true) then
            local uWl = getVal("sb_chk_use_wl")
            if uWl ~= "" then CFG.use_wl = (uWl:find("1") ~= nil) end
            local pubWl = getVal("sb_chk_wl_public")
            if pubWl ~= "" then CFG.wl_public = (pubWl:find("1") ~= nil) end
            local ignLock = getVal("sb_chk_ignore_lock")
            if ignLock ~= "" then CFG.ignore_lock = (ignLock:find("1") ~= nil) end
            persistConfig()
            if sendNotification then pcall(sendNotification, "Config WL Disimpan!") end
            DLG.showSoilWLConfigDialog()
            return true
        elseif btn == "sb_btn_back_lock" or pkt:find("buttonClicked|sb_btn_back_lock", 1, true) then
            DLG.showSoilLockDialog()
            return true
        end
        return true

    -- SL Config
    elseif dName == "sb_sl_cfg" or pkt:find("dialog_name|sb_sl_cfg", 1, true) then
        if btn == "sb_btn_save_sl_cfg" or pkt:find("buttonClicked|sb_btn_save_sl_cfg", 1, true) then
            local uSl = getVal("sb_chk_use_sl")
            if uSl ~= "" then CFG.use_sl = (uSl:find("1") ~= nil) end
            local pubSl = getVal("sb_chk_sl_public")
            if pubSl ~= "" then CFG.sl_public = (pubSl:find("1") ~= nil) end
            local ignAir = getVal("sb_chk_sl_ignore_air")
            if ignAir ~= "" then CFG.sl_ignore_air = (ignAir:find("1") ~= nil) end
            persistConfig()
            if sendNotification then pcall(sendNotification, "Config SL Disimpan!") end
            DLG.showSoilSLConfigDialog()
            return true
        elseif btn == "sb_btn_back_lock" or pkt:find("buttonClicked|sb_btn_back_lock", 1, true) then
            DLG.showSoilLockDialog()
            return true
        end
        return true

    -- Door Config
    elseif dName == "sb_door_cfg" or pkt:find("dialog_name|sb_door_cfg", 1, true) then
        if btn == "sb_btn_save_door_cfg" or pkt:find("buttonClicked|sb_btn_save_door_cfg", 1, true) then
            local uDoor = getVal("sb_chk_use_id_door")
            if uDoor ~= "" then CFG.use_id_door = (uDoor:find("1") ~= nil) end
            local dItem = getNum("sb_in_id_door_itemid", 0)
            if dItem and dItem > 0 then CFG.id_door_itemid = dItem end
            local dId = getVal("sb_in_door_id")
            if dId ~= "" then CFG.door_id = dId end
            local dLbl = getVal("sb_in_door_label")
            if dLbl ~= "" then CFG.door_label = dLbl end
            persistConfig()
            if sendNotification then pcall(sendNotification, "Config Door Disimpan!") end
            DLG.showSoilDoorConfigDialog()
            return true
        elseif btn == "sb_btn_back_lock" or pkt:find("buttonClicked|sb_btn_back_lock", 1, true) then
            DLG.showSoilLockDialog()
            return true
        end
        return true

    -- Jammer & Blocker
    elseif dName == "sb_misc_lock" or pkt:find("dialog_name|sb_misc_lock", 1, true) then
        if btn == "sb_btn_save_misc_cfg" or pkt:find("buttonClicked|sb_btn_save_misc_cfg", 1, true) then
            local uJam = getVal("sb_chk_use_jammer")
            if uJam ~= "" then CFG.use_jammer = (uJam:find("1") ~= nil) end
            local uBlk = getVal("sb_chk_use_blocker")
            if uBlk ~= "" then CFG.use_blocker_door = (uBlk:find("1") ~= nil) end
            local bItem = getNum("sb_in_blocker_itemid", 0)
            if bItem and bItem > 0 then CFG.blocker_door_itemid = bItem end
            local tDel = getNum("sb_in_tele_delay", 0)
            if tDel and tDel > 0 then CFG.delay_tele_door = tDel end
            persistConfig()
            if sendNotification then pcall(sendNotification, "Config Jammer & Blocker Disimpan!") end
            DLG.showSoilMiscLockDialog()
            return true
        elseif btn == "sb_btn_back_lock" or pkt:find("buttonClicked|sb_btn_back_lock", 1, true) then
            DLG.showSoilLockDialog()
            return true
        end
        return true

    -- --- E. SETTINGS BOT & SOIL FARM ---
    elseif dName == "sb_settings" or pkt:find("dialog_name|sb_settings", 1, true) then
        if btn == "sb_btn_save_settings_cfg" or pkt:find("buttonClicked|sb_btn_save_settings_cfg", 1, true) then
            local m3z = getVal("sb_chk_mode_3zigzag")
            if m3z ~= "" then CFG.put_mode = (m3z:find("1") ~= nil) and "3zigzag" or "1by1" end
            local rStep = getNum("sb_in_row_step", 0)
            if rStep and rStep >= 1 and rStep <= 4 then CFG.row_step = rStep end
            local sy = getNum("sb_in_start_y", 0)
            if sy and sy >= 1 and sy <= 10 then CFG.row_start_y = sy end
            local ey = getNum("sb_in_end_y", 0)
            if ey and ey >= 40 and ey <= 55 then CFG.row_end_y = ey end
            local sx = getNum("sb_in_start_x", -1)
            if sx and sx >= 0 and sx <= 10 then CFG.row_start_x = sx end
            local ex = getNum("sb_in_end_x", 0)
            if ex and ex >= 80 and ex <= 98 then CFG.row_end_x = ex end
            local mFly = getVal("sb_chk_modfly")
            if mFly ~= "" then CFG.use_modfly = (mFly:find("1") ~= nil) end
            local aLava = getVal("sb_chk_anti_lava")
            if aLava ~= "" then CFG.use_antilava = (aLava:find("1") ~= nil) end
            local aCol = getVal("sb_chk_auto_collect")
            if aCol ~= "" then CFG.auto_collect = (aCol:find("1") ~= nil) end
            local dPlc = getNum("sb_in_delay_place", 0)
            if dPlc and dPlc >= 50 then CFG.delay_place = dPlc end
            local dWlk = getNum("sb_in_delay_walk", 0)
            if dWlk and dWlk >= 50 then CFG.delay_walk = dWlk end
            local dPnc = getNum("sb_in_delay_punch", 0)
            if dPnc and dPnc >= 50 then CFG.delay_punch = dPnc end
            local dWrp = getNum("sb_in_delay_warp", 0)
            if dWrp and dWrp >= 1000 then CFG.delay_warp = dWrp end
            if applyCheatToggles then pcall(applyCheatToggles) end
            persistConfig()
            if sendNotification then pcall(sendNotification, "Pengaturan Bot Disimpan!") end
            DLG.showSoilSettingsDialog()
            return true
        elseif btn == "sb_btn_dlg_back_main" or pkt:find("buttonClicked|sb_btn_dlg_back_main", 1, true) then
            DLG.showSoilMainDialog()
            return true
        end
        return true

    -- --- F. LOGS & BAG ---
    elseif dName == "sb_logs" or pkt:find("dialog_name|sb_logs", 1, true) then
        if btn == "sb_btn_dlg_clear_logs" or pkt:find("buttonClicked|sb_btn_dlg_clear_logs", 1, true) then
            STATE.last_log_lines = {}
            if sendNotification then pcall(sendNotification, "Log dibersihkan!") end
            DLG.showSoilLogsDialog()
            return true
        elseif btn == "sb_btn_open_bag_view" or pkt:find("buttonClicked|sb_btn_open_bag_view", 1, true) then
            DLG.showSoilBagDialog()
            return true
        elseif btn == "sb_btn_dlg_back_main" or pkt:find("buttonClicked|sb_btn_dlg_back_main", 1, true) then
            DLG.showSoilMainDialog()
            return true
        end
        return true

    elseif dName == "sb_bag" or pkt:find("dialog_name|sb_bag", 1, true) then
        if btn == "sb_btn_refresh_bag_dlg" or pkt:find("buttonClicked|sb_btn_refresh_bag_dlg", 1, true) then
            if updateBagDisplayList then pcall(updateBagDisplayList) end
            DLG.showSoilBagDialog()
            return true
        elseif btn == "sb_btn_back_logs" or pkt:find("buttonClicked|sb_btn_back_logs", 1, true) then
            DLG.showSoilLogsDialog()
            return true
        end
        return true
    end

    return false
end

_G.handleSoilDialogReturn = handleSoilDialogReturn

local function onSendPacketDialogHook(ptype, pkt)
    local pStr = nil
    if type(pkt) == "string" then
        pStr = pkt
    elseif type(ptype) == "string" then
        pStr = ptype
    end
    if not pStr or type(pStr) ~= "string" then return end

    -- Intersepsi Chat Command (/sb, /soil, /soilbuilder, /buildsoil, /boren, /menu)
    local lowerP = pStr:lower()
    if lowerP:find("/sb", 1, true) or lowerP:find("/soil", 1, true) or lowerP:find("/soilbuilder", 1, true) or lowerP:find("/buildsoil", 1, true) or lowerP:find("/boren", 1, true) or lowerP:find("/menu", 1, true) then
        if lowerP:find("action|input", 1, true) or lowerP:find("text|/", 1, true) or lowerP:find("action|chat", 1, true) or lowerP:sub(1, 1) == "/" then
            local cmd = lowerP:match("|text|(/[a-z0-9_]+)") or lowerP:match("text|(/[a-z0-9_]+)") or lowerP:match("(/[a-z0-9_]+)")
            if cmd == "/sb" or cmd == "/soil" or cmd == "/soilbuilder" or cmd == "/buildsoil" or cmd == "/boren" or cmd == "/menu" then
                local openFn = _G.showSoilMainDialog or (DLG and DLG.showSoilMainDialog)
                if openFn then
                    pcall(openFn)
                    if LogToConsole then pcall(LogToConsole, "`2[BOREN SOIL] `wMenu Dialog dibuka via chat: `e" .. tostring(cmd)) end
                end
                return true
            end
        end
    end

    -- Intersepsi Dialog Return Compact Soil Builder
    if pStr:find("action|dialog_return", 1, true) then
        local handler = _G.handleSoilDialogReturn or handleSoilDialogReturn
        if handler and handler(pStr) then
            return true
        end
    end
end
-- ============================================================================
-- 18. NATIVE GROWLAUNCHER UI BUILDER (5 Sub-Menu Profesional)
-- ============================================================================
local function createNativeUI(subName, iconName)
    if UserInterface and UserInterface.new then
        return UserInterface.new(subName, iconName)
    end
    local ui = { sub_name = subName, icon = iconName, menu = {} }
    function ui:addLabelApp(text, icon) table.insert(self.menu, { type = "labelapp", text = text, icon = icon or "" }); return self end
    function ui:addLabel(text) table.insert(self.menu, { type = "label", text = text }); return self end
    function ui:addDivider() table.insert(self.menu, { type = "divider" }); return self end
    function ui:addToggle(text, default, alias, autosave) table.insert(self.menu, { type = "toggle", text = text, default = default == true, alias = alias, autosave = autosave == true }); return self end
    function ui:addToggleButton(text, default, alias) table.insert(self.menu, { type = "toggle_button", text = text, default = default == true, alias = alias }); return self end
    function ui:addButton(text, alias) table.insert(self.menu, { type = "button", text = text, alias = alias }); return self end
    function ui:addInputString(text, default, label, placeholder, icon, alias) table.insert(self.menu, { type = "input_string", text = text, default = default or "", label = label or "Text", placeholder = placeholder or "", icon = icon or "", alias = alias }); return self end
    function ui:addInputInt(text, default, label, placeholder, icon, alias) table.insert(self.menu, { type = "input_int", text = text, default = tostring(default or "0"), label = label or "Value", placeholder = placeholder or "0", icon = icon or "", alias = alias }); return self end
    function ui:addSlider(text, minVal, maxVal, defaultVal, stepVal, useDot, alias) table.insert(self.menu, { type = "slider", text = text, min = minVal, max = maxVal, default = defaultVal, step = stepVal, use_dot = useDot == true, alias = alias }); return self end
    function ui:addTooltip(text, supportText, icon, background) table.insert(self.menu, { type = "tooltip", text = text, support_text = supportText or "", icon = icon or "Info", background = background == true }); return self end
    function ui:addItemPicker(text, item, default, alias) table.insert(self.menu, { type = "item_picker", text = text, item = item or "Blank", default = tostring(default or "0"), alias = alias }); return self end
    function ui:addDisplayList(text, default, alias) table.insert(self.menu, { type = "display_list", text = text, default = default or "Default", alias = alias }); return self end
    function ui:generateJSON() return jsonEncode({ sub_name = self.sub_name, icon = self.icon, menu = self.menu }) end
    return ui
end

local function registerNativeSoilUI()
    if not addCategory or not addIntoModule then return end

    -- Tab 1: Start & World (Antrean World Put)
    local uiWorld = createNativeUI("1. Start & World", "PlayArrow")
    uiWorld:addLabelApp("Boren Store - Soil Builder", "Storefront")
    uiWorld:addButton("    START SOIL BOT", "sb_btn_start")
    uiWorld:addButton("    STOP SOIL BOT", "sb_btn_stop")
    uiWorld:addToggleButton("    START /     STOP TOGGLE", false, "sb_run_power")
    uiWorld:addToggle("Pause Bot", false, "sb_pause_toggle", false)
    uiWorld:addDisplayList("Status Bot", "Default", "sb_power_status_list")
    uiWorld:addDivider()
    uiWorld:addLabel("Antrean World Put:")
    uiWorld:addInputString("Nama World Put", CFG.manual_world_text, "World", "WORLD1", "Public", "sb_manual_world_input")
    uiWorld:addInputString("Door ID (Opsional)", CFG.manual_door_text, "Door ID", "Kosong = White Door", "DoorFront", "sb_manual_door_input")
    uiWorld:addButton("+ Tambah World ke Antrean", "sb_btn_add_world")
    uiWorld:addButton("+ Pakai World Sekarang", "sb_btn_add_cur_world")
    uiWorld:addButton("     Kelola Antrean World Put", "sb_btn_view_worlds")
    uiWorld:addButton("        Kosongkan Antrean World", "sb_btn_clear_worlds")
    uiWorld:addDivider()
    uiWorld:addLabel("Cadangan File Antrean:")
    uiWorld:addInputString("Nama File Antrean", CFG.world_file_name, "File", "boren_soil_worlds.txt", "Description", "sb_world_file")
    uiWorld:addButton("     Simpan Antrean ke File", "sb_btn_save_worlds")
    uiWorld:addButton("     Muat Antrean dari File", "sb_btn_load_worlds")
    uiWorld:addDisplayList("List World Put", "Default", "sb_world_display_list")
    uiWorld:addDivider()
    uiWorld:addLabel("Fitur Auto Blast & Random:")
    uiWorld:addToggle("Gunakan Blast Otomatis", CFG.auto_use_blast, "sb_chk_auto_blast", true)
    uiWorld:addInputInt("ID Item Blast", tostring(CFG.blast_item_id), "Blast ID", "3562 (Cave Blast)", "Fire", "sb_in_blast_id")
    uiWorld:addToggle("Mode Random World", CFG.world_mode == "random", "sb_world_random", true)
    uiWorld:addInputInt("Jumlah World Random", tostring(CFG.random_target_count), "Target", "5", "FormatListNumbered", "sb_random_target")
    uiWorld:addSlider("Panjang Nama", 4, 10, CFG.random_length, 1, false, "sb_random_len")
    uiWorld:addToggle("Campur Angka", CFG.random_use_numbers, "sb_random_num", true)

    -- Tab 2: Lock & Door (Kustomisasi Pintu & Penghalang)
    local uiLock = createNativeUI("2. Lock & Door", "Lock")
    uiLock:addLabelApp("Proteksi Lock & Door", "Lock")
    uiLock:addTooltip("Posisi Lock", "Jammer kiri door, SL atas jammer, WL kiri jammer, Penghalang atas WL, Door ID di (0,0).", "Verified", false)
    uiLock:addToggle("Ignore Lock (Bukan Owner)", CFG.ignore_lock, "sb_ignore_lock", true)
    uiLock:addToggle("World Lock (WL)", CFG.use_wl, "sb_use_wl", true)
    uiLock:addToggle("WL Public", CFG.wl_public, "sb_wl_public", true)
    uiLock:addDivider()
    uiLock:addToggle("Small Lock (SL)", CFG.use_sl, "sb_use_sl", true)
    uiLock:addToggle("SL Ignore Empty Air", CFG.sl_ignore_air, "sb_sl_ignore", true)
    uiLock:addToggle("SL Public (OFF = Private)", CFG.sl_public, "sb_sl_public", true)
    uiLock:addDivider()
    uiLock:addToggle("Signal Jammer", CFG.use_jammer, "sb_use_jammer", true)
    uiLock:addDivider()
    uiLock:addToggle("Pasang Door ID di (0,0)", CFG.use_id_door, "sb_use_id_door", true)
    uiLock:addItemPicker("Pilih Item Door ID", ITEM_NAME_CACHE[CFG.id_door_itemid] or resolveItemName(CFG.id_door_itemid), tostring(CFG.id_door_itemid), "sb_pick_id_door")
    uiLock:addInputInt("ID Item Door (Manual)", tostring(CFG.id_door_itemid), "Item ID", "12 (Wooden Door) / 102 (Door)", "DoorFront", "sb_input_id_door")
    uiLock:addInputString("Target Door ID", CFG.door_id, "ID", "SOIL", "Key", "sb_door_id")
    uiLock:addInputString("Label Door ID", CFG.door_label, "Label", "SOIL", "Label", "sb_door_label")
    uiLock:addSlider("Delay Tele Door (ms)", 500, 4000, CFG.delay_tele_door, 100, false, "sb_delay_tele_door")
    uiLock:addDivider()
    uiLock:addToggle("Pasang Penghalang Kiri", CFG.use_blocker_door, "sb_use_blocker", true)
    uiLock:addItemPicker("Pilih Item Penghalang", ITEM_NAME_CACHE[CFG.blocker_door_itemid] or resolveItemName(CFG.blocker_door_itemid), tostring(CFG.blocker_door_itemid), "sb_pick_blocker")
    uiLock:addInputInt("ID Item Penghalang (Manual)", tostring(CFG.blocker_door_itemid), "Item ID", "2810 (Air Vent) / 12 (Wooden Door)", "DoorFront", "sb_input_blocker")

    -- Tab 3: Storage (Gudang Alat & Gudang Block & Water)
    local uiStorage = createNativeUI("3. Storage", "Inventory")
    uiStorage:addLabelApp("Manajemen Storage Gudang", "Inventory")
    uiStorage:addLabel("Multi-Storage Gudang Alat (WL, SL, Jammer, Door, Blast):")
    uiStorage:addInputString("World Gudang Alat", STATE.buf_tool_name, "World", "GUDANGALAT", "Public", "sb_input_add_tool")
    uiStorage:addInputString("Door ID Gudang Alat", STATE.buf_tool_door, "Door", "KOSONG / ID", "DoorFront", "sb_input_add_tool_door")
    uiStorage:addButton("    Tambah Gudang Alat", "sb_btn_add_tool_direct")
    uiStorage:addButton("     Tambah World Sekarang (Alat)", "sb_btn_add_cur_tool")
    uiStorage:addButton("     Kelola Gudang Alat", "sb_btn_manage_tools")
    uiStorage:addButton("        Kosongkan Gudang Alat", "sb_btn_clear_tool_direct")
    uiStorage:addDisplayList("Daftar Gudang Alat", "Default", "sb_tool_display_list")
    uiStorage:addDivider()
    uiStorage:addLabel("Multi-Storage Gudang Block & Water:")
    uiStorage:addInputString("World Gudang Block", STATE.buf_block_name, "World", "GUDANGBLOCK", "Public", "sb_input_add_block")
    uiStorage:addInputString("Door ID Gudang Block", STATE.buf_block_door, "Door", "KOSONG / ID", "DoorFront", "sb_input_add_block_door")
    uiStorage:addButton("    Tambah Gudang Block/Water", "sb_btn_add_block_direct")
    uiStorage:addButton("     Tambah World Sekarang (Block)", "sb_btn_add_cur_block")
    uiStorage:addButton("     Kelola Gudang Block & Water", "sb_btn_manage_blocks")
    uiStorage:addButton("        Kosongkan Gudang Block", "sb_btn_clear_block_direct")
    uiStorage:addDisplayList("Daftar Gudang Block", "Default", "sb_block_display_list")
    uiStorage:addDivider()
    uiStorage:addLabel("Pengaturan Bahan Block & Water:")
    uiStorage:addInputInt("ID Block Diletakkan", tostring(CFG.block_id), "ID Block", "8772", "Category", "sb_block_id")
    uiStorage:addToggle("Pasang Kolom Water Elevator", CFG.enable_water, "sb_chk_enable_water", true)
    uiStorage:addInputInt("ID Item Water", tostring(CFG.water_item_id), "Water ID", "822", "Water", "sb_in_water_id")
    uiStorage:addSlider("Kolom Water (X)", 0, 10, CFG.water_x, 1, false, "sb_in_water_x")

    -- Tab 4: Pengaturan (Tata Letak & Cheats)
    local uiSetting = createNativeUI("4. Pengaturan", "Build")
    uiSetting:addLabelApp("Pengaturan Tata Letak & Gerak", "Build")
    uiSetting:addLabel("Grid Baris Block:")
    uiSetting:addToggle("Mode Put 3 Block (Zigzag Cepat)", CFG.put_mode == "3zigzag", "sb_toggle_mode_3zigzag", true)
    uiSetting:addSlider("Jarak Baris (Step)", 1, 4, CFG.row_step, 1, false, "sb_in_row_step")
    uiSetting:addSlider("Baris Awal (Y)", 1, 10, CFG.row_start_y, 1, false, "sb_in_start_y")
    uiSetting:addSlider("Baris Akhir (Y)", 40, 55, CFG.row_end_y, 1, false, "sb_in_end_y")
    uiSetting:addSlider("Kolom Awal (X)", 0, 10, CFG.row_start_x, 1, false, "sb_in_start_x")
    uiSetting:addSlider("Kolom Akhir (X)", 80, 98, CFG.row_end_x, 1, false, "sb_in_end_x")
    uiSetting:addDivider()
    uiSetting:addLabel("Bantuan Gerakan & Cheat:")
    uiSetting:addToggle("ModFly (Terbang Tembus)", CFG.use_modfly, "sb_modfly", true)
    uiSetting:addToggle("Anti Lava / Duri", CFG.use_antilava, "sb_anti_lava", true)
    uiSetting:addSlider("Delay Pasang Block (ms)", 50, 400, CFG.delay_place, 10, false, "sb_delay_place")
    uiSetting:addSlider("Delay Gerak (ms)", 50, 400, CFG.delay_walk, 10, false, "sb_delay_walk")
    uiSetting:addSlider("Delay Pukul (ms)", 50, 400, CFG.delay_punch, 10, false, "sb_delay_punch")
    uiSetting:addSlider("Delay Warp World (ms)", 2000, 8000, CFG.delay_warp, 500, false, "sb_delay_warp")

    -- Tab 5: Console & Tas
    local uiBackpack = createNativeUI("5. Console & Tas", "Terminal")
    uiBackpack:addLabelApp("Log Console & Backpack", "Terminal")
    uiBackpack:addButton("Bersihkan Log Console", "sb_btn_clear_console")
    uiBackpack:addDisplayList("Log Bot", "Default", "sb_console_list")
    uiBackpack:addDivider()
    uiBackpack:addButton("Refresh Tas", "sb_btn_refresh_bag")
    uiBackpack:addDisplayList("Isi Backpack", "Default", "sb_bag_display_list")

    -- Registrasi Kategori Tunggal & 5 Sub-Menu Resmi ke GrowLauncher
    local ok1, jsonWorld = pcall(function() return uiWorld:generateJSON() end)
    local ok2, jsonLock = pcall(function() return uiLock:generateJSON() end)
    local ok3, jsonStorage = pcall(function() return uiStorage:generateJSON() end)
    local ok4, jsonSetting = pcall(function() return uiSetting:generateJSON() end)
    local ok5, jsonBackpack = pcall(function() return uiBackpack:generateJSON() end)

    pcall(addCategory, "Boren Soil", "Storefront")
    if ok1 and jsonWorld then pcall(addIntoModule, jsonWorld, "Boren Soil") end
    if ok2 and jsonLock then pcall(addIntoModule, jsonLock, "Boren Soil") end
    if ok3 and jsonStorage then pcall(addIntoModule, jsonStorage, "Boren Soil") end
    if ok4 and jsonSetting then pcall(addIntoModule, jsonSetting, "Boren Soil") end
    if ok5 and jsonBackpack then pcall(addIntoModule, jsonBackpack, "Boren Soil") end
end

-- ============================================================================
-- 19. DISPLAY LIST UPDATERS (Compatible with GrowLauncher editValue / editDisplayList)
-- ============================================================================
local function safeEditDisplayList(alias, rows)
    if not rows then return end
    local jsonStr = jsonEncode(rows)
    if editValue then
        pcall(editValue, alias, jsonStr)
    elseif editDisplayList then
        pcall(editDisplayList, alias, jsonStr)
    end
end

local function buildPowerStatusRows()
    local row1Title = "STATUS: BERHENTI (OFF)"
    local row1Sub = "Tekan 'START SOIL BOT' untuk mulai"
    if STATE.running and STATE.paused then
        row1Title = "STATUS: DIJEDA (PAUSE)"
        row1Sub = "World: " .. tostring(STATE.active_world ~= "" and STATE.active_world or "-")
    elseif STATE.running then
        row1Title = "STATUS: SEDANG JALAN (ON)"
        row1Sub = tostring(STATE.current_status_title ~= "" and STATE.current_status_title or "Proses Soil Farm")
    end
    return {
        { row1Title, row1Sub },
        { "World Aktif: " .. tostring(STATE.active_world ~= "" and STATE.active_world or "-"), "Door: " .. tostring(STATE.active_door ~= "" and STATE.active_door or "-") },
        { "Progress Grid", string.format("Baris Y=%d | Col=%d", STATE.active_row or 0, STATE.active_col or 0) },
        { "Statistik", string.format("Selesai: %d | Terpasang: %d block", STATE.worlds_completed or 0, STATE.total_placed_blocks or 0) }
    }
end

local function buildConsoleRows()
    local rows = {
        { "Status: " .. tostring(STATE.current_status_title ~= "" and STATE.current_status_title or "IDLE"), tostring(STATE.current_status_desc ~= "" and STATE.current_status_desc or "-") }
    }
    for i = 1, math.min(10, #STATE.last_log_lines) do
        table.insert(rows, { "Log #" .. tostring(i), tostring(STATE.last_log_lines[i]) })
    end
    if #rows == 1 then
        table.insert(rows, { "Log Console", "Belum ada log tercatat" })
    end
    return rows
end

local function buildWorldDisplayRows()
    local rows = {}
    for i, w in ipairs(CFG.farm_world_list) do
        local d = (w.door and w.door ~= "") and ("Door: " .. w.door) or "White Door"
        local st = (w.done or w.status == "DONE") and "DONE" or ((STATE.running and STATE.active_world == w.name) and "PROSES" or (w.status or "ANTRI"))
        table.insert(rows, { string.format("%d. %s [%s]", i, w.name, st), d })
    end
    if #rows == 0 then
        table.insert(rows, { "Antrean World Put masih kosong", "Ketik Nama World lalu klik + Tambah" })
    end
    return rows
end

local function buildToolDisplayRows()
    local rows = {}
    for i, s in ipairs(CFG.storage_tool_list) do
        local d = (s.door and s.door ~= "") and ("Door: " .. s.door) or "White Door"
        table.insert(rows, { string.format("%d. %s", i, s.name), d })
    end
    if #rows == 0 then
        table.insert(rows, { "Gudang Alat masih kosong", "Ketik Nama World lalu klik + Tambah Gudang Alat" })
    end
    return rows
end

local function buildBlockDisplayRows()
    local rows = {}
    for i, s in ipairs(CFG.storage_block_list) do
        local d = (s.door and s.door ~= "") and ("Door: " .. s.door) or "White Door"
        table.insert(rows, { string.format("%d. %s", i, s.name), d })
    end
    if #rows == 0 then
        table.insert(rows, { "Gudang Block masih kosong", "Ketik Nama World lalu klik + Tambah Gudang Block" })
    end
    return rows
end

local function buildBagDisplayRows()
    local rows = {}
    local agg, order = {}, {}
    forEachInvItem(function(id, cnt)
        if cnt > 0 then
            if not agg[id] then table.insert(order, id) end
            agg[id] = (agg[id] or 0) + cnt
        end
    end)
    for _, id in ipairs(order) do
        table.insert(rows, { string.format("%s (ID: %d)", resolveItemName(id), id), string.format("Jumlah: %d", agg[id]) })
    end
    if #rows == 0 then
        -- Fallback: tabel inventory kosong -> cek langsung ID kebutuhan via checkInventoryCount
        local seen = {}
        local ids = { ITEM.WORLD_LOCK, ITEM.SMALL_LOCK, ITEM.JAMMER, CFG.id_door_itemid,
            CFG.blocker_door_itemid, CFG.block_id, CFG.water_item_id, CFG.blast_item_id }
        for _, id in ipairs(ids) do
            id = tonumber(id) or 0
            if id > 0 and not seen[id] then
                seen[id] = true
                local cnt = getInvCount(id)
                table.insert(rows, { string.format("%s (ID: %d)", resolveItemName(id), id), string.format("Jumlah: %d", cnt) })
            end
        end
    end
    if #rows == 0 then
        table.insert(rows, { "Tas kosong atau belum terbaca", "Klik 'Refresh Tas' saat berada di world" })
    end
    return rows
end

updatePowerStatusList = function()
    safeEditDisplayList("sb_power_status_list", buildPowerStatusRows())
    safeEditDisplayList("sb_console_list", buildConsoleRows())
end

updateWorldDisplayList = function()
    safeEditDisplayList("sb_world_display_list", buildWorldDisplayRows())
end

updateToolDisplayList = function()
    safeEditDisplayList("sb_tool_display_list", buildToolDisplayRows())
end

updateBlockDisplayList = function()
    safeEditDisplayList("sb_block_display_list", buildBlockDisplayRows())
end

updateBagDisplayList = function()
    safeEditDisplayList("sb_bag_display_list", buildBagDisplayRows())
end

refreshNativeDisplayLists = function()
    if updatePowerStatusList then pcall(updatePowerStatusList) end
    if updateWorldDisplayList then pcall(updateWorldDisplayList) end
    if updateToolDisplayList then pcall(updateToolDisplayList) end
    if updateBlockDisplayList then pcall(updateBlockDisplayList) end
    if updateBagDisplayList then pcall(updateBagDisplayList) end
end

-- ============================================================================
-- 20. INPUT STRING & STATE SYNC HELPER
-- ============================================================================
local function readGLString(alias, defaultVal)
    -- Disamakan dengan auto_dirt_farm.lua: HANYA terima string non-kosong & bukan "0".
    -- getValue(1, alias) pada input string mengembalikan angka 0 -> dulu jadi "0" (bug world:0).
    defaultVal = defaultVal or ""
    if getValue then
        for _, vtype in ipairs({ 2, 5 }) do
            local ok, val = pcall(getValue, vtype, alias)
            if ok and type(val) == "string" and val ~= "" and val ~= "0" then
                return val
            end
        end
    end
    if defaultVal == "0" then return "" end
    return defaultVal
end

local function readGLItemOrInt(alias, fallback)
    if getValue then
        for _, t in ipairs({ 1, 5, 0, 2 }) do
            local ok, val = pcall(getValue, t, alias)
            if ok and val ~= nil and tostring(val) ~= "" then
                local res = resolvePickedItemID(val)
                if res and res > 0 then return res end
            end
        end
        local ok0, val0 = pcall(getValue, alias)
        if ok0 and val0 ~= nil and tostring(val0) ~= "" then
            local res = resolvePickedItemID(val0)
            if res and res > 0 then return res end
        end
    end
    return fallback
end

syncInputsFromGL = function()
    local wIn = readGLString("sb_manual_world_input", "")
    if wIn ~= "" then
        STATE.buf_world_name = wIn:upper()
        CFG.manual_world_text = STATE.buf_world_name
    end
    local dIn = readGLString("sb_manual_door_input", "")
    if dIn ~= "" then
        STATE.buf_world_door = dIn
        CFG.manual_door_text = dIn
    end
    local dId = readGLString("sb_door_id", "")
    if dId ~= "" then CFG.door_id = dId:gsub("%s+", "") end
    local dLbl = readGLString("sb_door_label", "")
    if dLbl ~= "" then CFG.door_label = dLbl end

    -- Sinkronisasi Item IDs Secara Presisi & Lengkap
    local dItemId = readGLItemOrInt("sb_input_id_door", nil) or readGLItemOrInt("sb_pick_id_door", nil)
    if dItemId and dItemId > 0 then CFG.id_door_itemid = dItemId end

    local bItemId = readGLItemOrInt("sb_input_blocker", nil) or readGLItemOrInt("sb_pick_blocker", nil)
    if bItemId and bItemId > 0 then CFG.blocker_door_itemid = bItemId end

    local blkIdIn = readGLItemOrInt("sb_block_id", nil)
    if blkIdIn and blkIdIn > 0 then CFG.block_id = blkIdIn end
    if (not CFG.block_id) or CFG.block_id <= 0 then CFG.block_id = 8772 end

    local wtrIdIn = readGLItemOrInt("sb_in_water_id", nil)
    if wtrIdIn and wtrIdIn > 0 then CFG.water_item_id = wtrIdIn end

    local blastIdIn = readGLItemOrInt("sb_in_blast_id", nil)
    if blastIdIn and blastIdIn > 0 then CFG.blast_item_id = blastIdIn end

    persistConfig()
end

-- ============================================================================
-- 21. EVENT DISPATCHER (ONVALUE)
-- ============================================================================
local lastAliasEventTime = {}

local function toBoolVal(v)
    return (v == true or v == 1 or v == "true" or v == "1")
end

-- Nilai input string dari event: tolak nil / angka / "0" (GL kadang kirim 0 untuk input string)
local function cleanStrVal(v)
    if type(v) ~= "string" then return "" end
    v = v:gsub("^%s+", ""):gsub("%s+$", "")
    if v == "0" then return "" end
    return v
end

local function handleUIValue(vtype, name, value)
    if type(vtype) == "string" and (name == nil or type(name) ~= "string" or (type(name) == "string" and vtype:sub(1, 3) == "sb_")) then
        value = name
        name = vtype
        vtype = 0
    end
    name = tostring(name or "")
    if name == "" then return end

    local now = safeClock()
    local isButton = (name:sub(1, 7) == "sb_btn_")
    if isButton then
        if lastAliasEventTime[name] and (now - lastAliasEventTime[name]) < 0.25 then
            return
        end
        lastAliasEventTime[name] = now
    end

    -- Tab 1: Start & World
    if name == "sb_run_power" then
        local wantRun = toBoolVal(value)
        if wantRun then
            if not STATE.running then
                startSoilBot()
            end
        else
            if STATE.running then
                stopSoilBot()
            end
        end
        return
    elseif name == "sb_btn_start" then
        if not STATE.running then
            startSoilBot()
        end
        return
    elseif name == "sb_btn_stop" then
        stopSoilBot()
        if sendNotification then pcall(sendNotification, "Soil Builder dihentikan!") end
        return
    elseif name == "sb_pause_toggle" then
        STATE.paused = toBoolVal(value)
        setStatus(STATE.paused and "Paused" or (STATE.running and "Running" or "Siap"), STATE.paused and "Bot dijeda." or "Bot dilanjutkan.")
    elseif name == "sb_manual_world_input" then
        local v = cleanStrVal(value)
        if v ~= "" then
            CFG.manual_world_text = v:upper()
            STATE.buf_world_name = CFG.manual_world_text
        end
    elseif name == "sb_manual_door_input" then
        local v = cleanStrVal(value)
        CFG.manual_door_text = v
        STATE.buf_world_door = v
    elseif name == "sb_btn_add_world" then
        local wIn = readGLString("sb_manual_world_input", "")
        if wIn ~= "" then
            STATE.buf_world_name = wIn:upper()
            CFG.manual_world_text = STATE.buf_world_name
        end
        local dIn = readGLString("sb_manual_door_input", "")
        if dIn ~= "" then
            STATE.buf_world_door = dIn
            CFG.manual_door_text = dIn
        end
        local targetW = (STATE.buf_world_name ~= "" and STATE.buf_world_name) or CFG.manual_world_text
        local targetD = (STATE.buf_world_door ~= "" and STATE.buf_world_door) or CFG.manual_door_text
        local count = addManualWorldsFromString(targetW, targetD, false)
        persistConfig()
        updateWorldDisplayList()
        if count > 0 then
            STATE.buf_world_name = ""
            CFG.manual_world_text = ""
            if editValue then pcall(editValue, "sb_manual_world_input", "") end
            if sendNotification then pcall(sendNotification, string.format("%d World ditambahkan! (Total: %d)", count, #CFG.farm_world_list)) end
        else
            if sendNotification then pcall(sendNotification, "Isi Nama World dulu di atas!") end
        end
    elseif name == "sb_btn_add_cur_world" then
        local curW = getWorldNameSafe()
        if curW ~= "" and curW ~= "EXIT" then
            local dIn = readGLString("sb_manual_door_input", STATE.buf_world_door)
            local count = addManualWorldsFromString(curW, dIn, false)
            persistConfig()
            updateWorldDisplayList()
            if sendNotification then pcall(sendNotification, string.format("World aktif ditambahkan: %s (Total: %d)", curW, #CFG.farm_world_list)) end
        else
            if sendNotification then pcall(sendNotification, "Anda belum masuk ke dalam world!") end
        end
    elseif name == "sb_btn_view_worlds" then
        updateWorldDisplayList()
        openUnifiedWorldManager()
    elseif name == "sb_btn_clear_worlds" then
        CFG.farm_world_list = {}
        CFG.manual_world_text = ""
        STATE.buf_world_name = ""
        persistConfig()
        updateWorldDisplayList()
        if sendNotification then pcall(sendNotification, "Antrean world dikosongkan!") end
    elseif name == "sb_world_file" then
        CFG.world_file_name = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
        persistConfig()
    elseif name == "sb_btn_save_worlds" then
        local fIn = readGLString("sb_world_file", CFG.world_file_name)
        if fIn ~= "" then CFG.world_file_name = fIn end
        local lines = {}
        for _, w in ipairs(CFG.farm_world_list) do
            local d = (w.door and w.door ~= "") and w.door or ""
            table.insert(lines, (d ~= "") and (w.name .. ":" .. d) or w.name)
        end
        safeWriteFile(CFG.world_file_name, table.concat(lines, "\n"))
        persistConfig()
        if sendNotification then pcall(sendNotification, string.format("Antrean disimpan ke %s (%d world)", CFG.world_file_name, #CFG.farm_world_list)) end
    elseif name == "sb_btn_load_worlds" then
        local fIn = readGLString("sb_world_file", CFG.world_file_name)
        if fIn ~= "" then CFG.world_file_name = fIn end
        local content = safeReadFile(CFG.world_file_name)
        if content and content ~= "" then
            local parsed = parseWorldBatchFromString(content)
            for _, item in ipairs(parsed) do
                table.insert(CFG.farm_world_list, { name = item.name, door = item.door, status = "ANTRI", done = false })
            end
            persistConfig()
            updateWorldDisplayList()
            if sendNotification then pcall(sendNotification, string.format("%d World dimuat dari %s!", #parsed, CFG.world_file_name)) end
        else
            if sendNotification then pcall(sendNotification, "Gagal membaca file: " .. CFG.world_file_name) end
        end
    elseif name == "sb_chk_auto_blast" then
        CFG.auto_use_blast = toBoolVal(value)
        persistConfig()
    elseif name == "sb_in_blast_id" then
        local num = resolvePickedItemID(value)
        if num and num > 0 then
            CFG.blast_item_id = num
            persistConfig()
        end
    elseif name == "sb_world_random" then
        CFG.world_mode = toBoolVal(value) and "random" or "manual"
        persistConfig()
    elseif name == "sb_random_target" then
        CFG.random_target_count = tonumber(value) or CFG.random_target_count
        persistConfig()
    elseif name == "sb_random_len" then
        CFG.random_length = tonumber(value) or CFG.random_length
        persistConfig()
    elseif name == "sb_random_num" then
        CFG.random_use_numbers = toBoolVal(value)
        persistConfig()

    -- Tab 2: Lock & Door
    elseif name == "sb_ignore_lock" then
        CFG.ignore_lock = toBoolVal(value)
        persistConfig()
    elseif name == "sb_use_wl" then
        CFG.use_wl = toBoolVal(value)
        persistConfig()
    elseif name == "sb_wl_public" then
        CFG.wl_public = toBoolVal(value)
        persistConfig()
    elseif name == "sb_use_sl" then
        CFG.use_sl = toBoolVal(value)
        persistConfig()
    elseif name == "sb_sl_ignore" then
        CFG.sl_ignore_air = toBoolVal(value)
        persistConfig()
    elseif name == "sb_sl_public" then
        CFG.sl_public = toBoolVal(value)
        persistConfig()
    elseif name == "sb_use_jammer" then
        CFG.use_jammer = toBoolVal(value)
        persistConfig()
    elseif name == "sb_use_id_door" then
        CFG.use_id_door = toBoolVal(value)
        persistConfig()
    elseif name == "sb_pick_id_door" or name == "sb_input_id_door" then
        if not value or value == "" or value == 0 or value == "0" then return end
        local num = resolvePickedItemID(value)
        if num and num > 0 then
            CFG.id_door_itemid = num
            persistConfig()
            if name == "sb_pick_id_door" and editValue then
                pcall(editValue, "sb_input_id_door", tostring(num))
            end
            if sendNotification then pcall(sendNotification, "Door ID: " .. resolveItemName(num) .. " (ID: " .. num .. ")") end
        end
    elseif name == "sb_door_id" then
        CFG.door_id = tostring(value or ""):gsub("%s+", "")
        persistConfig()
    elseif name == "sb_door_label" then
        CFG.door_label = tostring(value or "")
        persistConfig()
    elseif name == "sb_delay_tele_door" then
        CFG.delay_tele_door = tonumber(value) or CFG.delay_tele_door
        persistConfig()
    elseif name == "sb_use_blocker" then
        CFG.use_blocker_door = toBoolVal(value)
        persistConfig()
    elseif name == "sb_pick_blocker" or name == "sb_input_blocker" then
        if not value or value == "" or value == 0 or value == "0" then return end
        local num = resolvePickedItemID(value)
        if num and num > 0 then
            CFG.blocker_door_itemid = num
            persistConfig()
            if name == "sb_pick_blocker" and editValue then
                pcall(editValue, "sb_input_blocker", tostring(num))
            end
            if sendNotification then pcall(sendNotification, "Penghalang: " .. resolveItemName(num) .. " (ID: " .. num .. ")") end
        end

    -- Tab 3: Storage (Gudang Alat, Block & Water)
    elseif name == "sb_input_add_tool" then
        local v = cleanStrVal(value)
        if v ~= "" then STATE.buf_tool_name = v:upper() end
    elseif name == "sb_input_add_tool_door" then
        local v = cleanStrVal(value)
        if v ~= "" then STATE.buf_tool_door = v end
    elseif name == "sb_btn_add_tool_direct" then
        local tName = readGLString("sb_input_add_tool", STATE.buf_tool_name):upper()
        local tDoor = readGLString("sb_input_add_tool_door", STATE.buf_tool_door)
        local parsed = parseWorldBatchFromString(tName)
        if #parsed == 0 and tName ~= "" and tName ~= "EXIT" and tName ~= "0" then
            table.insert(parsed, { name = tName, door = tDoor })
        end
        local added = 0
        for _, it in ipairs(parsed) do
            local d = (it.door and it.door ~= "") and it.door or tDoor
            local exists = false
            for _, ex in ipairs(CFG.storage_tool_list) do
                if ex.name == it.name then exists = true; break end
            end
            if not exists then
                table.insert(CFG.storage_tool_list, { name = it.name, door = d })
                added = added + 1
            end
        end
        if added > 0 then
            STATE.buf_tool_name = ""
            if editValue then pcall(editValue, "sb_input_add_tool", "") end
            persistConfig()
            updateToolDisplayList()
            if sendNotification then pcall(sendNotification, string.format("%d Gudang Alat ditambahkan! (Total: %d)", added, #CFG.storage_tool_list)) end
        else
            if sendNotification then pcall(sendNotification, "Isi Nama World Gudang Alat dulu!") end
        end
    elseif name == "sb_btn_add_cur_tool" then
        local curW = getWorldNameSafe()
        if curW ~= "" and curW ~= "EXIT" then
            local tDoor = readGLString("sb_input_add_tool_door", STATE.buf_tool_door)
            local exists = false
            for _, ex in ipairs(CFG.storage_tool_list) do
                if ex.name == curW then exists = true; break end
            end
            if not exists then
                table.insert(CFG.storage_tool_list, { name = curW, door = tDoor })
                persistConfig()
                updateToolDisplayList()
                if sendNotification then pcall(sendNotification, "World aktif masuk ke Gudang Alat: " .. curW) end
            else
                if sendNotification then pcall(sendNotification, "World sudah ada di daftar Gudang Alat!") end
            end
        else
            if sendNotification then pcall(sendNotification, "Anda belum masuk ke dalam world!") end
        end
    elseif name == "sb_btn_manage_tools" then
        updateToolDisplayList()
        openUnifiedToolManager()
    elseif name == "sb_btn_clear_tool_direct" then
        CFG.storage_tool_list = {}
        persistConfig()
        updateToolDisplayList()
        if sendNotification then pcall(sendNotification, "Gudang Alat dikosongkan!") end

    elseif name == "sb_input_add_block" then
        local v = cleanStrVal(value)
        if v ~= "" then STATE.buf_block_name = v:upper() end
    elseif name == "sb_input_add_block_door" then
        local v = cleanStrVal(value)
        if v ~= "" then STATE.buf_block_door = v end
    elseif name == "sb_btn_add_block_direct" then
        local bName = readGLString("sb_input_add_block", STATE.buf_block_name):upper()
        local bDoor = readGLString("sb_input_add_block_door", STATE.buf_block_door)
        local parsed = parseWorldBatchFromString(bName)
        if #parsed == 0 and bName ~= "" and bName ~= "EXIT" and bName ~= "0" then
            table.insert(parsed, { name = bName, door = bDoor })
        end
        local added = 0
        for _, it in ipairs(parsed) do
            local d = (it.door and it.door ~= "") and it.door or bDoor
            local exists = false
            for _, ex in ipairs(CFG.storage_block_list) do
                if ex.name == it.name then exists = true; break end
            end
            if not exists then
                table.insert(CFG.storage_block_list, { name = it.name, door = d })
                added = added + 1
            end
        end
        if added > 0 then
            STATE.buf_block_name = ""
            if editValue then pcall(editValue, "sb_input_add_block", "") end
            persistConfig()
            updateBlockDisplayList()
            if sendNotification then pcall(sendNotification, string.format("%d Gudang Block ditambahkan! (Total: %d)", added, #CFG.storage_block_list)) end
        else
            if sendNotification then pcall(sendNotification, "Isi Nama World Gudang Block dulu!") end
        end
    elseif name == "sb_btn_add_cur_block" then
        local curW = getWorldNameSafe()
        if curW ~= "" and curW ~= "EXIT" then
            local bDoor = readGLString("sb_input_add_block_door", STATE.buf_block_door)
            local exists = false
            for _, ex in ipairs(CFG.storage_block_list) do
                if ex.name == curW then exists = true; break end
            end
            if not exists then
                table.insert(CFG.storage_block_list, { name = curW, door = bDoor })
                persistConfig()
                updateBlockDisplayList()
                if sendNotification then pcall(sendNotification, "World aktif masuk ke Gudang Block: " .. curW) end
            else
                if sendNotification then pcall(sendNotification, "World sudah ada di daftar Gudang Block!") end
            end
        else
            if sendNotification then pcall(sendNotification, "Anda belum masuk ke dalam world!") end
        end
    elseif name == "sb_btn_manage_blocks" then
        updateBlockDisplayList()
        openUnifiedBlockManager()
    elseif name == "sb_btn_clear_block_direct" then
        CFG.storage_block_list = {}
        persistConfig()
        updateBlockDisplayList()
        if sendNotification then pcall(sendNotification, "Gudang Block dikosongkan!") end

    elseif name == "sb_block_id" then
        local num = resolvePickedItemID(value)
        if num and num > 0 then
            CFG.block_id = num
            persistConfig()
            if sendNotification then pcall(sendNotification, "Block Farm: " .. resolveItemName(num) .. " (ID: " .. num .. ")") end
        end
    elseif name == "sb_chk_enable_water" then
        CFG.enable_water = toBoolVal(value)
        persistConfig()
    elseif name == "sb_in_water_id" then
        local num = resolvePickedItemID(value)
        if num and num > 0 then
            CFG.water_item_id = num
            persistConfig()
        end
    elseif name == "sb_in_water_x" then
        CFG.water_x = tonumber(value) or CFG.water_x
        persistConfig()

    -- Tab 4: Pengaturan
    elseif name == "sb_in_row_step" then
        CFG.row_step = tonumber(value) or CFG.row_step
        persistConfig()
    elseif name == "sb_in_start_y" then
        CFG.row_start_y = tonumber(value) or CFG.row_start_y
        persistConfig()
    elseif name == "sb_in_end_y" then
        CFG.row_end_y = tonumber(value) or CFG.row_end_y
        persistConfig()
    elseif name == "sb_toggle_mode_3zigzag" then
        CFG.put_mode = (value == true or value == 1 or value == "1") and "3zigzag" or "1by1"
        persistConfig()
        addLog(string.format("`9[Pengaturan] `wMode Put: `2%s", (CFG.put_mode == "3zigzag" and "3 Block (Zigzag Cepat)" or "1 by 1")))
    elseif name == "sb_in_start_x" then
        CFG.row_start_x = tonumber(value) or CFG.row_start_x
        persistConfig()
    elseif name == "sb_in_end_x" then
        CFG.row_end_x = tonumber(value) or CFG.row_end_x
        persistConfig()
    elseif name == "sb_modfly" then
        CFG.use_modfly = toBoolVal(value)
        if editToggle then pcall(editToggle, "ModFly", CFG.use_modfly) end
        persistConfig()
    elseif name == "sb_anti_lava" then
        CFG.use_antilava = toBoolVal(value)
        persistConfig()
    elseif name == "sb_delay_place" then
        CFG.delay_place = tonumber(value) or CFG.delay_place
        persistConfig()
    elseif name == "sb_delay_walk" then
        CFG.delay_walk = tonumber(value) or CFG.delay_walk
        persistConfig()
    elseif name == "sb_delay_punch" then
        CFG.delay_punch = tonumber(value) or CFG.delay_punch
        persistConfig()
    elseif name == "sb_delay_warp" then
        CFG.delay_warp = tonumber(value) or CFG.delay_warp
        persistConfig()

    -- Tab 5: Console & Tas
    elseif name == "sb_btn_clear_console" then
        STATE.last_log_lines = {}
        updatePowerStatusList()
    elseif name == "sb_btn_refresh_bag" then
        updateBagDisplayList()
    end
end

-- ============================================================================
-- 22. HOOK REGISTRATIONS (onValue, onSendPacket, onVariant)
-- ============================================================================
function OnValue(a1, a2, a3)
    pcall(handleUIValue, a1, a2, a3)
end
onValue = OnValue
onSendPacket = onSendPacketDialogHook
OnSendPacket = onSendPacketDialogHook
onVariant = onVariantDialogHook
OnVariant = onVariantDialogHook

if addHook then
    pcall(addHook, onSendPacketDialogHook, "onsendpacket")
    pcall(addHook, onVariantDialogHook, "onvariant")
    pcall(addHook, onValue, "onvalue")
    if applyHook then pcall(applyHook) end
end

-- 23. INISIALISASI UI
registerNativeSoilUI()
refreshNativeDisplayLists()

local ALL_UI_ALIASES = {
    "sb_run_power", "sb_btn_start", "sb_btn_stop", "sb_pause_toggle",
    "sb_manual_world_input", "sb_manual_door_input",
    "sb_btn_add_world", "sb_btn_add_cur_world", "sb_btn_view_worlds", "sb_btn_clear_worlds",
    "sb_world_file", "sb_btn_save_worlds", "sb_btn_load_worlds",
    "sb_chk_auto_blast", "sb_in_blast_id", "sb_world_random", "sb_random_target", "sb_random_len", "sb_random_num",
    "sb_ignore_lock", "sb_use_wl", "sb_wl_public", "sb_use_sl", "sb_sl_ignore", "sb_sl_public",
    "sb_use_jammer", "sb_use_id_door", "sb_pick_id_door", "sb_input_id_door", "sb_door_id", "sb_door_label", "sb_delay_tele_door",
    "sb_use_blocker", "sb_pick_blocker", "sb_input_blocker",
    "sb_input_add_tool", "sb_input_add_tool_door", "sb_btn_add_tool_direct", "sb_btn_add_cur_tool", "sb_btn_manage_tools", "sb_btn_clear_tool_direct",
    "sb_input_add_block", "sb_input_add_block_door", "sb_btn_add_block_direct", "sb_btn_add_cur_block", "sb_btn_manage_blocks", "sb_btn_clear_block_direct",
    "sb_block_id", "sb_chk_enable_water", "sb_in_water_id", "sb_in_water_x",
    "sb_toggle_mode_3zigzag", "sb_in_row_step", "sb_in_start_y", "sb_in_end_y", "sb_in_start_x", "sb_in_end_x",
    "sb_modfly", "sb_anti_lava", "sb_delay_place", "sb_delay_walk", "sb_delay_punch", "sb_delay_warp",
    "sb_btn_clear_console", "sb_btn_refresh_bag",
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

if applyHook then
    pcall(applyHook)
end

if sendNotification then
    pcall(sendNotification, "Boren Soil Builder siap!")
end

_G.SOIL_CFG = CFG
_G.SOIL_STATE = STATE
_G.inspectWorldSecurityState = inspectWorldSecurityState
_G.inspectMissingSoilBlocks = inspectMissingSoilBlocks
_G.placeSoilRows = placeSoilRows
_G.handleUIValue = handleUIValue
_G.setupWorldLocks = setupWorldLocks
_G.resolvePickedItemID = resolvePickedItemID
_G.getMissingToolsFromBag = getMissingToolsFromBag
_G.getInvCount = getInvCount
_G.addManualWorldsFromString = addManualWorldsFromString
_G.refreshNativeDisplayLists = refreshNativeDisplayLists

_G.findWorldObjectsByItemID = findWorldObjectsByItemID
_G.getInvCount = getInvCount
_G.ITEM = ITEM
_G.resolveItemName = resolveItemName
_G.lookupItemIDByName = lookupItemIDByName

_G.CFG = CFG


-- ============================================================================
-- 24. INISIALISASI AWAL COMPACT DIALOG SOIL BUILDER
-- ============================================================================
_G.showSoilMainDialog = DLG.showSoilMainDialog
_G.DLG = DLG

local function applyCheatToggles()
    if editToggle then
        pcall(editToggle, "ModFly", CFG.use_modfly == true)
    end
end
_G.applyCheatToggles = applyCheatToggles

-- Inisialisasi awal saat script di-Run (Standar In-Game Dialog)
addLog("[Boren Soil Dialog] Script Auto Soil Builder (In-Game Dialog) Berhasil Dimuat!")
if LogToConsole then
    pcall(LogToConsole, "`5[BOREN SOIL] `2Script Aktif! `wKetik `c/sb `watau `c/soil `wdi chat game untuk membuka Menu Form Dialog.")
end
if sendNotification then
    pcall(sendNotification, "Boren Auto Soil Builder Siap! Ketik /sb di chat game.")
end

-- Otomatis terapkan cheat dan buka dialog saat pertama kali di-run via coroutine
local function openInitialSoilDialog()
    safeSleep(200)
    pcall(applyCheatToggles)
    local openFn = _G.showSoilMainDialog or (DLG and DLG.showSoilMainDialog)
    if openFn then pcall(openFn) end
end

if runCoroutine then
    pcall(runCoroutine, openInitialSoilDialog)
elseif runThread then
    pcall(runThread, openInitialSoilDialog)
else
    pcall(applyCheatToggles)
    local openFn = _G.showSoilMainDialog or (DLG and DLG.showSoilMainDialog)
    if openFn then pcall(openFn) end
end
