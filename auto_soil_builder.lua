-- ============================================================================
-- AUTO SOIL & BLOCK FARM BUILDER - BOREN STORE (EDISI SENIOR DEVELOPER V2.5.0)
-- ============================================================================
-- Framework : GrowLauncher Lua (Android & PC Windows)
-- Arsitektur : Adopsi 100% pondasi teruji dari auto_dirt_farm.lua (Senior Dev Refactor)
-- Fitur Utama:
-- 1. Formasi Proteksi Kunci (WL, SL, Jammer, Door di 0,0) sesuai layout:
--    - White Door di (doorX, doorY)
--    - Signal Jammer di (doorX - 1, doorY) + punch 1x
--    - Small Lock di (doorX - 1, doorY - 1) + Set Private (cover Jammer)
--    - World Lock di (doorX - 2, doorY) + Set Public
--    - Door ID di (0, 0)
-- 2. Validasi World Ketat (0 Bolong / 0 Defect):
--    - Pengecekan menyeluruh inspectMissingSoilBlocks()
--    - World HANYA ditandai DONE jika terverifikasi 100% (0 tile bolong tersisa)!
-- 3. Pemisahan 3 Kategori World (World Put, Storage Alat, Storage Block):
--    - Tombol "+ Pakai World Sekarang" untuk masing-masing kategori
-- 4. Auto Blast terintegrasi otomatis menyimpan world ke antrean World Put
-- 5. Manajemen Antrean & Dialog Manager runtime packet hooks resmi
-- ============================================================================

-- 1. IDENTITAS ITEM & GLOBAL CONSTANTS
local ITEM = {
    WORLD_LOCK   = 242,
    SMALL_LOCK   = 202,
    BIG_LOCK     = 204,
    HUGE_LOCK    = 206,
    BUILDER_LOCK = 4994,
    JAMMER       = 226,
    AIR_VENT     = 828,
    WOODEN_DOOR  = 12,
    MAIN_DOOR    = 6,
    BEDROCK      = 8,
    DIRT         = 2,
    SOIL_BLOCK   = 8772,
    BLAST_WORLD  = 1336,
    BLAST_CAVE   = 2810,
    PUNCH        = 18,
    WRENCH       = 32,
}

local OTHER_LOCKS = {
    [ITEM.WORLD_LOCK]   = true,
    [ITEM.SMALL_LOCK]   = true,
    [ITEM.BIG_LOCK]     = true,
    [ITEM.HUGE_LOCK]    = true,
    [ITEM.BUILDER_LOCK] = true,
}

local KNOWN_ID_DOOR_IDS = {
    [ITEM.WOODEN_DOOR] = true,
    [ITEM.MAIN_DOOR]   = true,
}

local ITEM_NAME_CACHE = {
    [242]  = "World Lock",
    [202]  = "Small Lock",
    [204]  = "Big Lock",
    [206]  = "Huge Lock",
    [4994] = "Builder's Lock",
    [226]  = "Signal Jammer",
    [828]  = "Air Vent",
    [12]   = "Wooden Door",
    [6]    = "White Door",
    [8]    = "Bedrock",
    [2]    = "Dirt",
    [8772] = "Soil Block",
    [1336] = "World Blast",
    [2810] = "Cave Blast",
}

-- 2. FILE PERSISTENCE & PREFERENCE LOADER
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
    -- Fallback serializer
    local parts = {}
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
    local ok, content = pcall(readFile, PREF_FILE)
    if ok and content and content ~= "" then
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
    pcall(writeFile, PREF_FILE, jsonEncode(PREFS))
end

-- 3. GLOBAL CONFIGURATION (CFG)
local CFG = {
    world_mode          = getPref("world_mode", "manual"), -- "manual" / "random"
    world_list          = getPref("world_list", {}),
    manual_world_text   = getPref("manual_world_text", ""),
    manual_door_text    = getPref("manual_door_text", ""),
    world_file_name     = getPref("world_file_name", "boren_soil_worlds.txt"),

    -- Storage Alat & Block
    storage_tool_world  = getPref("storage_tool_world", ""),
    storage_tool_door   = getPref("storage_tool_door", ""),
    storage_block_world = getPref("storage_block_world", ""),
    storage_block_door  = getPref("storage_block_door", ""),
    block_id            = tonumber(getPref("block_id", 8772)) or 8772, -- Default Soil Block: 8772

    -- Lock & Door Protection (Default ON)
    use_wl              = (getPref("use_wl", true) == true),
    wl_public           = (getPref("wl_public", true) == true),
    use_sl              = (getPref("use_sl", true) == true),
    sl_ignore_air       = (getPref("sl_ignore_air", true) == true),
    sl_public           = (getPref("sl_public", false) == true),
    use_jammer          = (getPref("use_jammer", true) == true),
    use_id_door         = (getPref("use_id_door", true) == true),
    door_id             = getPref("door_id", "SOIL"),
    door_label          = getPref("door_label", "SOIL"),
    id_door_itemid      = tonumber(getPref("id_door_itemid", ITEM.WOODEN_DOOR)) or ITEM.WOODEN_DOOR,
    delay_tele_door     = tonumber(getPref("delay_tele_door", 1500)) or 1500,

    -- Auto Blast Settings
    auto_use_blast      = (getPref("auto_use_blast", false) == true),
    blast_item_id       = tonumber(getPref("blast_item_id", 1336)) or 1336,

    -- Random World Settings
    random_target_count = tonumber(getPref("random_target_count", 5)) or 5,
    random_length       = tonumber(getPref("random_length", 6)) or 6,
    random_use_numbers  = (getPref("random_use_numbers", true) == true),

    -- Layout Grid Baris
    row_step            = tonumber(getPref("row_step", 2)) or 2,
    row_start_y         = tonumber(getPref("row_start_y", 2)) or 2,
    row_end_y           = tonumber(getPref("row_end_y", 54)) or 54,
    row_start_x         = tonumber(getPref("row_start_x", 2)) or 2,
    row_end_x           = tonumber(getPref("row_end_x", 99)) or 99,

    -- Delays & Movement Cheats
    delay_place         = tonumber(getPref("delay_place", 120)) or 120,
    delay_walk          = tonumber(getPref("delay_walk", 140)) or 140,
    delay_punch         = tonumber(getPref("delay_punch", 160)) or 160,
    delay_warp          = tonumber(getPref("delay_warp", 4000)) or 4000,
    use_modfly          = (getPref("use_modfly", true) == true),
    use_antilava        = (getPref("use_antilava", true) == true),
}

local function persistConfig()
    savePrefData(CFG)
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
    buf_tool_world       = "",
    buf_tool_door        = "",
    buf_block_world      = "",
    buf_block_door       = "",
    last_log_lines       = {},
}

-- Forward declarations
local updatePowerStatusList
local updateWorldDisplayList
local updateBagDisplayList
local openWorldListManagerDialog
local openWorldEditDialog

-- 5. RESOLVER NAMA ITEM & LOGGING HELPERS
local function resolveItemName(itemID)
    if not itemID or itemID <= 0 then return "None" end
    if ITEM_NAME_CACHE[itemID] then return ITEM_NAME_CACHE[itemID] end
    if getItemName then
        local ok, n = pcall(getItemName, itemID)
        if ok and n and n ~= "" and not n:find("Unknown") then
            ITEM_NAME_CACHE[itemID] = n
            return n
        end
    end
    if getInfo then
        local ok, info = pcall(getInfo, itemID)
        if ok and info and info.name and info.name ~= "" then
            ITEM_NAME_CACHE[itemID] = info.name
            return info.name
        end
    end
    return "Item #" .. tostring(itemID)
end

local function addLog(msg)
    local timestamp = os.date("%H:%M:%S")
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
    ms = tonumber(ms) or 100
    if ms <= 0 then return end
    if sleep then
        pcall(sleep, ms)
    else
        local t0 = os.clock()
        while (os.clock() - t0) * 1000 < ms do end
    end
end

local function waitIfPaused()
    while STATE.paused and STATE.running do
        safeSleep(300)
    end
    return STATE.running
end

-- 6. POSISI PEMAIN, WORLD, INVENTORY & TILE HELPERS
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

local function getInvCount(itemID)
    if not itemID or itemID <= 0 then return 0 end
    if getInventory then
        local ok, inv = pcall(getInventory)
        if ok and inv and inv.items then
            for _, it in pairs(inv.items) do
                if it and (it.id == itemID or it.itemid == itemID) then
                    return it.count or it.amount or 0
                end
            end
        end
    end
    if getAmount then
        local ok, cnt = pcall(getAmount, itemID)
        if ok and cnt then return tonumber(cnt) or 0 end
    end
    return 0
end

local function getWorldObjectsSafe()
    if getWorldObjects then
        local ok, objs = pcall(getWorldObjects)
        if ok and objs then return objs end
    end
    if getObjects then
        local ok, objs = pcall(getObjects)
        if ok and objs then return objs end
    end
    return nil
end

local function sendRawAction(tx, ty, itemID)
    if not tx or not ty then return end
    if sendPacketRaw then
        local ok = pcall(sendPacketRaw, false, {
            type  = 7,
            value = itemID or ITEM.PUNCH,
            px    = tx,
            py    = ty,
            x     = tx * 32,
            y     = ty * 32,
        })
        if ok then return end
    end
    if punch then
        pcall(punch, tx, ty)
    end
end

local function moveSafeTo(tx, ty)
    if not tx or not ty then return end
    if CFG.use_modfly and editToggle then
        pcall(editToggle, "ModFly", true)
    end
    if findPath then
        pcall(findPath, tx, ty)
        safeSleep(math.max(80, CFG.delay_walk))
        return
    end
    if teleport then
        pcall(teleport, tx, ty)
        safeSleep(math.max(80, CFG.delay_walk))
        return
    end
    if sendPacketRaw then
        pcall(sendPacketRaw, false, {
            type  = 0,
            x     = tx * 32,
            y     = ty * 32,
            state = 32,
        })
        safeSleep(math.max(80, CFG.delay_walk))
    end
end

local function breakTileCompletely(tx, ty, clearFg, clearBg, prefDir)
    if tx < 0 or tx > 99 or ty < 0 or ty > 59 then return end
    clearFg = (clearFg ~= false)
    prefDir = prefDir or 1

    local standX = math.max(0, math.min(99, tx + prefDir))
    local standY = ty
    moveSafeTo(standX, standY)

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
end

local function placeTileAt(tx, ty, itemID)
    if tx < 0 or tx > 99 or ty < 0 or ty > 59 then return false end
    if not itemID or itemID <= 0 then return false end

    local px, py = getPlayerTilePos()
    if math.abs(px - tx) > 3 or math.abs(py - ty) > 3 then
        local standX = (tx <= px) and math.min(99, tx + 1) or math.max(0, tx - 1)
        moveSafeTo(standX, ty)
    end

    sendRawAction(tx, ty, itemID)
    safeSleep(math.max(70, CFG.delay_place))

    local ok, t = pcall(getTile, tx, ty)
    if ok and t and (t.fg == itemID or t.bg == itemID) then
        return true
    end
    return false
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

local function warpTo(targetWorld, targetDoor)
    if not targetWorld or targetWorld == "" or targetWorld == "EXIT" then return false end
    targetWorld = targetWorld:upper():gsub("%s+", "")
    targetDoor  = tostring(targetDoor or ""):gsub("%s+", "")

    local curW = getWorldNameSafe()
    if curW == targetWorld and curW ~= "" then
        return true
    end

    local warpPkt = (targetDoor ~= "") and string.format("action|join_request\nname|%s|%s\ninvitedWorld|0", targetWorld, targetDoor)
                                        or string.format("action|join_request\nname|%s\ninvitedWorld|0", targetWorld)

    for attempt = 1, 5 do
        if not STATE.running then return false end
        setStatus("Warping", string.format("Menuju %s (Percobaan %d/5)", targetWorld, attempt))
        addLog(string.format("`9[Warp] `oMasuk ke world %s...", targetWorld))

        if sendPacket then
            pcall(sendPacket, 3, warpPkt)
        elseif warp then
            pcall(warp, targetWorld, targetDoor)
        end

        local waitLimit = math.max(2500, CFG.delay_warp)
        local t0 = os.clock()
        while (os.clock() - t0) * 1000 < waitLimit do
            safeSleep(250)
            curW = getWorldNameSafe()
            if curW == targetWorld then
                safeSleep(1000)
                return true
            end
        end
    end
    return false
end

-- 7. DIALOG PACKET HOOK & RAW DIALOG ENGINE (Persis auto_dirt_farm.lua)
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

local function onVariantDialogHook(varlist)
    if not varlist then return end
    local v0 = varlist[0] or varlist[1]
    if v0 == "OnDialogRequest" then
        local dText = tostring(varlist[1] or varlist[2] or "")
        if DIALOG_WATCH.waiting and DIALOG_WATCH.expected_name then
            if dText:find(DIALOG_WATCH.expected_name, 1, true) then
                DIALOG_WATCH.captured_text = dText
                DIALOG_WATCH.captured_time = os.clock()
                DIALOG_WATCH.waiting = false
            end
        end
    end
end

local function ensureRuntimeHooks()
    if DIALOG_WATCH.hook_registered then return end
    if addHook then
        pcall(addHook, onVariantDialogHook, "onvariant")
        if onSendPacketDialogHook then
            pcall(addHook, onSendPacketDialogHook, "onsendpacket")
        end
        if applyHook then pcall(applyHook) end
        DIALOG_WATCH.hook_registered = true
    end
end

local function wrenchAndAwaitDialog(tx, ty, expectedDialogName, standX, standY)
    ensureRuntimeHooks()
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

        local t0 = os.clock()
        while DIALOG_WATCH.waiting and (os.clock() - t0) < 2.0 do
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

local function safeSendRawDialog(dText)
    if not dText or dText == "" then return false end
    if runThread then
        runThread(function()
            safeSleep(120)
            if sendVariantList then
                pcall(sendVariantList, { [0] = "OnDialogRequest", [1] = dText })
            elseif sendVariant then
                pcall(sendVariant, { [0] = "OnDialogRequest", [1] = dText })
            end
        end)
        return true
    end
    if sendVariantList then
        return pcall(sendVariantList, { [0] = "OnDialogRequest", [1] = dText })
    end
    return false
end

-- 8. PENGATURAN KUNCI & DOOR TILE SETTINGS (Persis auto_dirt_farm.lua)
local function placeAndValidateSecurityTile(tx, ty, itemID, tileLabel, standX, standY)
    if not itemID or itemID <= 0 then return false end
    standX = standX or tx
    standY = standY or ty
    moveSafeTo(standX, standY)

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
    if not doorID or doorID == "" then return true end
    doorLabel = doorLabel or doorID
    standX = standX or (tx + 1)
    standY = standY or ty

    for attempt = 1, 3 do
        if not STATE.running then break end
        local gotDlg, dlgText = wrenchAndAwaitDialog(tx, ty, "door_edit", standX, standY)
        local fMap = {}
        if gotDlg and dlgText then
            fMap = parseDialogFields(dlgText)
        end
        fMap["door_name"] = tostring(doorLabel)
        fMap["door_target"] = tostring(doorID)
        fMap["door_id"] = tostring(doorID)

        local pkt = buildDialogReturn("door_edit", "", fMap)
        if sendPacket then pcall(sendPacket, 2, pkt) end
        safeSleep(350)
        return true
    end
    return false
end

local function validateAndEditWorldLock(tx, ty, isPublic, standX, standY)
    standX = standX or tx
    standY = standY or ty

    for attempt = 1, 3 do
        if not STATE.running then break end
        local gotDlg, dlgText = wrenchAndAwaitDialog(tx, ty, "lock_edit", standX, standY)
        local fMap = {}
        if gotDlg and dlgText then
            fMap = parseDialogFields(dlgText)
        end
        fMap["checkbox_public"] = isPublic and "1" or "0"
        fMap["checkbox_disable_music"] = "0"

        local pkt = buildDialogReturn("lock_edit", "", fMap)
        if sendPacket then pcall(sendPacket, 2, pkt) end
        safeSleep(350)
        return true
    end
    return false
end

local function validateAndApplySmallLock(tx, ty, ignoreAir, isPublic, standX, standY)
    standX = standX or tx
    standY = standY or ty

    for attempt = 1, 3 do
        if not STATE.running then break end
        local gotDlg, dlgText = wrenchAndAwaitDialog(tx, ty, "lock_edit", standX, standY)
        local fMap = {}
        if gotDlg and dlgText then
            fMap = parseDialogFields(dlgText)
        end

        fMap["checkbox_public"] = isPublic and "1" or "0"
        fMap["checkbox_ignore_air"] = ignoreAir and "1" or "0"

        local pktApply = buildDialogReturn("lock_edit", "apply_lock", fMap)
        if sendPacket then pcall(sendPacket, 2, pktApply) end
        safeSleep(400)

        local pktSave = buildDialogReturn("lock_edit", "", fMap)
        if sendPacket then pcall(sendPacket, 2, pktSave) end
        safeSleep(350)
        return true
    end
    return false
end

-- 9. INSPEKSI KEAMANAN & SETUP FORMASI KUNCI PINTU
-- Formasi Sesuai Gambar Layout:
-- White Door di (doorX, doorY)
-- Signal Jammer di (doorX - 1, doorY) + punch 1x
-- Small Lock di (doorX - 1, doorY - 1) + set private & apply (cover Jammer)
-- World Lock di (doorX - 2, doorY) + set public
-- Door ID di (0, 0)
local function inspectWorldSecurityState(doorX, doorY)
    local info = {
        has_wl      = false,
        has_sl      = false,
        has_jammer  = false,
        has_id_door = false,
        all_ready   = false,
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
        if ok and t and (t.fg == ITEM.JAMMER or t.fg == 226 or t.fg == 828) then
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

    -- 4. Check Door ID di (0, 0)
    do
        local ok, t = pcall(getTile, 0, 0)
        if ok and t and (t.fg == CFG.id_door_itemid or KNOWN_ID_DOOR_IDS[t.fg] or t.fg == ITEM.WOODEN_DOOR or t.fg == ITEM.MAIN_DOOR) then
            info.has_id_door = true
        end
    end

    local wlOk  = (not CFG.use_wl) or info.has_wl
    local slOk  = (not CFG.use_sl) or info.has_sl
    local jamOk = (not CFG.use_jammer) or info.has_jammer
    local idOk  = (not CFG.use_id_door) or info.has_id_door

    info.all_ready = (wlOk and slOk and jamOk and idOk)
    return info
end

local function setupWorldLocks(doorX, doorY, existingSec)
    local sec = existingSec or inspectWorldSecurityState(doorX, doorY)
    if sec.all_ready then
        addLog("`2[Lock Enclosure] `wSemua Lock, Jammer & Door sudah lengkap! Langsung lanjut proses...")
        return (CFG.use_id_door and CFG.door_id ~= "") and CFG.door_id or ""
    end

    setStatus("Setup Lock", string.format("Persiapan slot kunci di sekitar White Door (%d, %d)", doorX, doorY))

    -- Bersihkan slot yang belum terpasang item yang sesuai
    if not sec.has_jammer and doorX - 1 >= 0 then
        breakTileCompletely(doorX - 1, doorY, true, true, 1)
    end
    if not sec.has_sl and doorX - 1 >= 0 and doorY - 1 >= 0 then
        breakTileCompletely(doorX - 1, doorY - 1, true, true, 1)
    end
    if not sec.has_wl and doorX - 2 >= 0 then
        breakTileCompletely(doorX - 2, doorY, true, true, 1)
    end
    if doorX - 2 >= 0 and doorY - 1 >= 0 then
        breakTileCompletely(doorX - 2, doorY - 1, true, true, 1)
    end

    -- 1. Pasang Signal Jammer di (doorX - 1, doorY) + punch 1x
    if CFG.use_jammer and doorX - 1 >= 0 then
        if not sec.has_jammer then
            setStatus("Pasang Jammer", string.format("Menaruh Jammer di (%d, %d)", doorX - 1, doorY))
            local jamPlaced = placeAndValidateSecurityTile(doorX - 1, doorY, ITEM.JAMMER, "Signal Jammer", doorX, doorY)
            if jamPlaced then
                safeSleep(300)
                sendRawAction(doorX - 1, doorY, ITEM.PUNCH)
                safeSleep(350)
                addLog(string.format("Validasi Jammer OK di (%d, %d)", doorX - 1, doorY))
            end
        end
    end

    -- 2. Pasang Small Lock di (doorX - 1, doorY - 1) + Set Private (cover Jammer)
    if CFG.use_sl and doorX - 1 >= 0 and doorY - 1 >= 0 then
        if not sec.has_sl then
            setStatus("Pasang Small Lock", string.format("Menaruh SL di (%d, %d)", doorX - 1, doorY - 1))
            placeAndValidateSecurityTile(doorX - 1, doorY - 1, ITEM.SMALL_LOCK, "Small Lock", doorX, doorY)
        end
        setStatus("Apply Small Lock", "Set Private + Ignore Empty Air + Re-apply")
        validateAndApplySmallLock(doorX - 1, doorY - 1, CFG.sl_ignore_air, CFG.sl_public, doorX, doorY)
    end

    -- 3. Pasang World Lock di (doorX - 2, doorY) + Set Public
    if CFG.use_wl and doorX - 2 >= 0 then
        if not sec.has_wl then
            setStatus("Pasang WL", string.format("Menaruh WL di (%d, %d)", doorX - 2, doorY))
            placeAndValidateSecurityTile(doorX - 2, doorY, ITEM.WORLD_LOCK, "World Lock", doorX, doorY)
        end
        validateAndEditWorldLock(doorX - 2, doorY, CFG.wl_public, doorX, doorY)
    end

    -- 4. Pasang Door ID di (0, 0)
    local activeDoorID = ""
    if CFG.use_id_door then
        local teleWait = math.max(300, tonumber(CFG.delay_tele_door) or 1500)
        setStatus("Jeda Tele Door (0,0)", string.format("Jeda %d ms sebelum ke (0,0)...", teleWait))
        safeSleep(teleWait)
        if CFG.use_modfly and editToggle then pcall(editToggle, "ModFly", true) end
        safeSleep(150)

        if not sec.has_id_door then
            setStatus("Pasang Door ID (0,0)", "Menaruh Door di (0, 0)")
            breakTileCompletely(0, 0, true, false, 1)
            placeAndValidateSecurityTile(0, 0, CFG.id_door_itemid, "Door ID (0,0)", 1, 0)
            safeSleep(300)
        end
        validateAndEditDoorTile(0, 0, CFG.door_id, CFG.door_label, 1, 0)
        activeDoorID = CFG.door_id
    end

    return activeDoorID
end

-- 10. GUDANG ALAT & BLOCK RESTOCK ENGINE (Persis auto_dirt_farm.lua)
local function ensureToolsFromStorage(existingSec, returnWorld, returnDoor)
    local needed = {}
    local neededOrder = {}
    local neededRoles = {}
    local function addNeed(id, count, roleLabel)
        if not id or id <= 0 then return end
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
        addNeed(CFG.id_door_itemid or ITEM.WOODEN_DOOR, 1, "Door ID")
    end
    if CFG.auto_use_blast and getInvCount(CFG.blast_item_id) <= 0 then
        addNeed(CFG.blast_item_id, 1, "Blast")
    end

    local function collectMissingText()
        local missingParts = {}
        for _, needID in ipairs(neededOrder) do
            local reqAmt = needed[needID]
            local curAmt = getInvCount(needID)
            if curAmt < reqAmt then
                local diff = reqAmt - curAmt
                local role = neededRoles[needID] or ""
                table.insert(missingParts, string.format("%s (%s) x%d", role, resolveItemName(needID), diff))
            end
        end
        return missingParts
    end

    local missingBefore = collectMissingText()
    if #missingBefore == 0 then
        return true
    end

    local missingStr = table.concat(missingBefore, ", ")
    addLog("`e[Alat Kurang] `oDibutuhkan: " .. missingStr)

    if CFG.storage_tool_world == "" then
        addLog("`4[Storage Belum Diatur] `oWorld Storage Alat kosong! Siapkan di tas atau isi Storage Alat.")
        if sendNotification then
            pcall(sendNotification, "Kurang alat: " .. missingStr .. " (Storage Alat belum diatur!)")
        end
        return false
    end

    setStatus("Ambil Alat", "Warp ke Storage Alat: " .. CFG.storage_tool_world)
    if not warpTo(CFG.storage_tool_world, CFG.storage_tool_door) then
        addLog("`4[Gagal Warp] `oTidak bisa masuk ke Storage Alat: " .. CFG.storage_tool_world)
        if sendNotification then
            pcall(sendNotification, "Gagal masuk ke Storage Alat: " .. CFG.storage_tool_world)
        end
        return false
    end
    safeSleep(1200)

    -- Ambil alat yang kurang dengan sendPacketRaw type 11
    local objs = getWorldObjectsSafe()
    if objs then
        for _, needID in ipairs(neededOrder) do
            local reqAmt = needed[needID]
            if getInvCount(needID) < reqAmt then
                for _, obj in pairs(objs) do
                    if obj and obj.itemid == needID and obj.pos and obj.id then
                        local ox = math.floor((obj.pos.x + 10) / 32)
                        local oy = math.floor((obj.pos.y + 10) / 32)
                        addLog(string.format("Mengambil %s di (%d, %d)", resolveItemName(needID), ox, oy))
                        moveSafeTo(ox, oy)
                        safeSleep(250)
                        pcall(sendPacketRaw, false, {
                            type  = 11,
                            value = obj.id,
                            x     = obj.pos.x,
                            y     = obj.pos.y,
                        })
                        safeSleep(350)
                        if getInvCount(needID) >= reqAmt then
                            break
                        end
                    end
                end
            end
        end
    end

    local missingAfter = collectMissingText()
    if #missingAfter > 0 then
        local strAfter = table.concat(missingAfter, ", ")
        addLog("`4[Alat Kurang di Storage] `oMasih kurang: " .. strAfter)
        if sendNotification then
            pcall(sendNotification, "Alat di Storage habis: " .. strAfter)
        end
        if returnWorld and returnWorld ~= "" then
            warpTo(returnWorld, returnDoor)
        end
        return false
    end

    addLog("`2[Alat Lengkap] `wSemua kebutuhan alat berhasil diambil dari Storage!")
    if returnWorld and returnWorld ~= "" then
        setStatus("Kembali ke Farm", returnWorld)
        if not warpTo(returnWorld, returnDoor) then
            return false
        end
        safeSleep(1200)
    end
    return true
end

local function restockSoilBlocksFromStorage(returnWorld, returnDoor)
    if getInvCount(CFG.block_id) >= 50 then
        return true
    end

    if CFG.storage_block_world == "" then
        addLog("`4[Storage Block Kosong] `oWorld Storage Block belum diatur & Block di tas habis!")
        if sendNotification then
            pcall(sendNotification, "Block di tas habis & Storage Block belum diatur!")
        end
        return false
    end

    setStatus("Restock Block", "Warp ke Storage Block: " .. CFG.storage_block_world)
    if not warpTo(CFG.storage_block_world, CFG.storage_block_door) then
        addLog("`4[Gagal Warp] `oTidak bisa masuk ke Storage Block: " .. CFG.storage_block_world)
        return false
    end
    safeSleep(1200)

    local objs = getWorldObjectsSafe()
    if objs then
        for _, obj in pairs(objs) do
            if obj and obj.itemid == CFG.block_id and obj.pos and obj.id then
                local ox = math.floor((obj.pos.x + 10) / 32)
                local oy = math.floor((obj.pos.y + 10) / 32)
                moveSafeTo(ox, oy)
                safeSleep(200)
                pcall(sendPacketRaw, false, {
                    type  = 11,
                    value = obj.id,
                    x     = obj.pos.x,
                    y     = obj.pos.y,
                })
                safeSleep(300)
                if getInvCount(CFG.block_id) >= 150 then
                    break
                end
            end
        end
    end

    local curCount = getInvCount(CFG.block_id)
    if curCount <= 0 then
        addLog("`4[Gudang Habis] `oTidak ada block ID " .. CFG.block_id .. " tersisa di Storage Block!")
        if sendNotification then
            pcall(sendNotification, "Gudang Block habis: ID " .. CFG.block_id)
        end
        if returnWorld and returnWorld ~= "" then
            warpTo(returnWorld, returnDoor)
        end
        return false
    end

    addLog(string.format("`2[Restock Berhasil] `wMendapatkan %d block dari Storage!", curCount))
    if returnWorld and returnWorld ~= "" then
        setStatus("Kembali ke Farm", returnWorld)
        if not warpTo(returnWorld, returnDoor) then
            return false
        end
        safeSleep(1200)
    end
    return true
end

-- 11. INSPEKSI BOLONG & PENEMPATAN BARIS BLOCK SOIL
local function inspectMissingSoilBlocks(doorX, doorY)
    local missingList = {}
    local totalExpected = 0
    for y = CFG.row_start_y, CFG.row_end_y, CFG.row_step do
        for x = CFG.row_start_x, CFG.row_end_x do
            local isDoorTile = (doorX and doorY and x == doorX and y == doorY)
            if not isDoorTile then
                totalExpected = totalExpected + 1
                local ok, t = pcall(getTile, x, y)
                if ok and t then
                    if t.fg ~= CFG.block_id and t.fg ~= ITEM.BEDROCK and t.fg ~= ITEM.MAIN_DOOR then
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

local function placeSoilRows(worldName, doorID, restockCb)
    addLog(string.format("`9[Place Rows] `wMemulai penempatan %s (ID %d)...", resolveItemName(CFG.block_id), CFG.block_id))

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
            if ok and t and t.fg ~= CFG.block_id and t.fg ~= ITEM.BEDROCK and t.fg ~= ITEM.MAIN_DOOR then
                if getInvCount(CFG.block_id) <= 0 then
                    addLog(string.format("`e[Stok Habis] `oBlock habis pada (%d, %d). Mencoba restock...", x, y))
                    if restockCb then
                        local okRestock = restockCb()
                        if not okRestock then
                            addLog("`4[Konstruksi Terhenti] `oGagal restock block dari Storage Block.")
                            return false
                        end
                    else
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

local function validateAndRepairSoilLayout(worldName, doorID, doorX, doorY, restockCb)
    for pass = 1, 3 do
        local missingCount, totalExpected, missingList = inspectMissingSoilBlocks(doorX, doorY)
        if missingCount == 0 then
            return true
        end

        addLog(string.format("`e[Validasi Pass %d] `oDitemukan %d/%d tile belum terpasang. Memperbaiki...", pass, missingCount, totalExpected))
        for _, pos in ipairs(missingList) do
            if not STATE.running then return false end
            if not waitIfPaused() then return false end

            if getInvCount(CFG.block_id) <= 0 then
                if restockCb then
                    if not restockCb() then return false end
                else
                    return false
                end
            end
            placeTileAt(pos.x, pos.y, CFG.block_id)
        end
        safeSleep(300)
    end

    local finalMissing = inspectMissingSoilBlocks(doorX, doorY)
    return (finalMissing == 0)
end

-- 12. FITUR AUTO BLAST WORLD
local function recordBlastedWorld(worldName, doorID)
    if not worldName or worldName == "" or worldName == "EXIT" then return end
    doorID = doorID or ""
    for _, e in ipairs(CFG.world_list) do
        if e.name == worldName then
            return
        end
    end
    table.insert(CFG.world_list, {
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

-- 13. EKSEKUSI TUNGGAL FARM WORLD (Strict Zero-Hole Validation)
local function runSingleFarmWorld(worldName, worldDoor, manualIdx)
    STATE.active_world = worldName
    STATE.active_door = worldDoor or ""
    setStatus("Mempersiapkan", worldName)
    addLog("`2================================================`0")
    addLog(string.format("`2[Mulai World] `wMemproses Farm World: %s", worldName))
    if updateWorldDisplayList then pcall(updateWorldDisplayList) end

    -- 1. Warp ke World Target
    if not warpTo(worldName, worldDoor) then
        addLog("`4[Gagal Warp] `oTidak dapat memasuki world " .. worldName)
        setStatus("Gagal Warp", worldName)
        return false
    end
    safeSleep(1200)

    local doorX, doorY = findMainDoor()
    if not doorX or not doorY then
        setStatus("Error Main Door", "White Door tidak ditemukan di world " .. worldName)
        addLog("`4[Error] `oWhite Door tidak terdeteksi di world " .. worldName)
        return false
    end

    -- 2. Setup Proteksi Kunci (WL, SL, Jammer, Door di 0,0)
    local activeDoorID = worldDoor or ""
    local secState = inspectWorldSecurityState(doorX, doorY)

    if secState.all_ready then
        addLog("`2[Proteksi World] `wSemua Lock, Jammer & Door sudah lengkap di " .. worldName)
        if CFG.use_id_door and activeDoorID == "" then
            activeDoorID = CFG.door_id
        end
    else
        -- Ambil alat yang kurang ke World Storage Alat
        if not ensureToolsFromStorage(secState, worldName, worldDoor) then
            return false
        end
        doorX, doorY = findMainDoor()
        if not doorX or not doorY then return false end
        activeDoorID = setupWorldLocks(doorX, doorY, secState)
        if activeDoorID == "" then activeDoorID = worldDoor or "" end
    end

    if manualIdx and CFG.world_list[manualIdx] and activeDoorID ~= "" and CFG.world_list[manualIdx].door ~= activeDoorID then
        CFG.world_list[manualIdx].door = activeDoorID
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

    -- 4. Pengecekan & Penempatan Baris Block Soil
    local restockFn = function()
        return restockSoilBlocksFromStorage(worldName, activeDoorID)
    end

    local initMissing, totalExp = inspectMissingSoilBlocks(doorX, doorY)
    if secState.all_ready and initMissing == 0 and totalExp > 0 then
        addLog(string.format("`2[Cek Status World] `wWorld %s sudah selesai penuh (0 bolong) -> Status DONE!", worldName))
    else
        if getInvCount(CFG.block_id) <= 0 then
            if not restockFn() then
                addLog("`4[Gagal Stok Awal] `oTidak ada block di tas dan gagal restock.")
                return false
            end
            doorX, doorY = findMainDoor()
        end

        local okRows = placeSoilRows(worldName, activeDoorID, restockFn)
        if not okRows then
            addLog("`4[Konstruksi Gagal] `oGagal menuntaskan baris block di " .. worldName)
            return false
        end

        local okRepair = validateAndRepairSoilLayout(worldName, activeDoorID, doorX, doorY, restockFn)
        if not okRepair then
            local missingLeft = inspectMissingSoilBlocks(doorX, doorY)
            addLog(string.format("`4[Validasi Gagal] `oWorld %s masih kurang %d block! TIDAK DITANDAI DONE.", worldName, missingLeft))
            if manualIdx and CFG.world_list[manualIdx] then
                CFG.world_list[manualIdx].done = false
                CFG.world_list[manualIdx].status = string.format("KURANG (%d)", missingLeft)
                persistConfig()
                if updateWorldDisplayList then pcall(updateWorldDisplayList) end
            end
            return false
        end
    end

    -- 5. HANYA TANDAI DONE JIKA TERVERIFIKASI 100% (0 BOLONG)!
    if manualIdx and CFG.world_list[manualIdx] then
        CFG.world_list[manualIdx].done = true
        CFG.world_list[manualIdx].status = "DONE"
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

-- 14. GENERATOR RANDOM WORLD & BOT MAIN LOOP
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
    STATE.running = true
    STATE.paused  = false
    addLog("`2[Start Bot] `wAuto Soil Builder V2.5.0 resmi dimulai!")
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
            local foundUndone = false
            for idx, wItem in ipairs(CFG.world_list) do
                if not STATE.running then break end
                if not waitIfPaused() then break end

                if not wItem.done and wItem.status ~= "DONE" then
                    foundUndone = true
                    wItem.status = "PROSES"
                    if updateWorldDisplayList then pcall(updateWorldDisplayList) end

                    local ok = runSingleFarmWorld(wItem.name, wItem.door, idx)
                    if not ok then
                        if wItem.status == "PROSES" then
                            wItem.status = "GAGAL"
                        end
                        if updateWorldDisplayList then pcall(updateWorldDisplayList) end
                        safeSleep(2000)
                    end
                end
            end

            if not foundUndone then
                addLog("`2[Antrean Selesai] `wSemua world dalam antrean World Put sudah berstatus DONE!")
                setStatus("Antrean Selesai", "Semua antrean selesai diproses.")
                break
            end
        end

        safeSleep(1000)
    end

    STATE.running = false
    STATE.paused  = false
    setStatus("Berhenti", "Bot selesai beroperasi.")
    if editToggle then pcall(editToggle, "sb_run_power", false) end
    updatePowerStatusList()
end

local function startSoilBot()
    if STATE.running then return end
    ensureRuntimeHooks()
    if runThread then
        runThread(botMainLoop)
    else
        botMainLoop()
    end
end

local function stopSoilBot()
    STATE.running = false
    STATE.paused  = false
    setStatus("Dihentikan", "Bot dihentikan manual oleh user.")
    updatePowerStatusList()
end

-- 15. MANAJEMEN ANTREAN WORLD, SALIN, TEMPEL & FILE IO
local function addManualWorldsFromString(rawInput, defaultDoor)
    if not rawInput or rawInput == "" then return 0 end
    defaultDoor = defaultDoor or ""
    local addedCount = 0

    for rawToken in rawInput:gmatch("[^\r\n,;]+") do
        local token = rawToken:gsub("^%s+", ""):gsub("%s+$", "")
        if token ~= "" then
            local wName, wDoor = "", ""
            if token:find(":") then
                wName, wDoor = token:match("([^:]+):?(.*)")
            elseif token:find("|") then
                wName, wDoor = token:match("([^|]+)|?(.*)")
            else
                wName = token
            end

            wName = tostring(wName or ""):upper():gsub("%s+", "")
            wDoor = tostring(wDoor or ""):gsub("%s+", "")
            if wDoor == "" then wDoor = defaultDoor end

            if wName ~= "" and wName ~= "EXIT" then
                local exists = false
                for _, ex in ipairs(CFG.world_list) do
                    if ex.name == wName then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(CFG.world_list, {
                        name   = wName,
                        door   = wDoor,
                        status = "ANTRI",
                        done   = false,
                    })
                    addedCount = addedCount + 1
                end
            end
        end
    end
    return addedCount
end

openWorldEditDialog = function(idx)
    local entry = CFG.world_list[idx]
    if not entry then return end

    local dLines = {
        "set_default_color|`o",
        "add_quick_exit|",
        string.format("add_label_with_icon|big|`wEdit World #%d: %s``|left|2|", idx, entry.name),
        "add_spacer|small|",
        string.format("add_text_input|edit_w_name|Nama World:|%s|32|", entry.name),
        string.format("add_text_input|edit_w_door|Door ID:|%s|32|", entry.door or ""),
        string.format("add_checkbox|edit_w_done|Sudah Selesai (DONE)|%s|", entry.done and "1" or "0"),
        "add_spacer|small|",
        "add_button|save_w_edit|`2Simpan Perubahan|noflags|0|0|",
        "add_button|del_w_edit|`4Hapus World Ini|noflags|0|0|",
        string.format("end_dialog|boren_world_edit_%d|Batal||", idx),
    }
    safeSendRawDialog(table.concat(dLines, "\n"))
end

openWorldListManagerDialog = function(fmt)
    fmt = fmt or "colon"

    local copyLines = {}
    for _, e in ipairs(CFG.world_list) do
        local door = e.door or ""
        if fmt == "colon" then
            table.insert(copyLines, (door ~= "") and (e.name .. ":" .. door) or e.name)
        elseif fmt == "pipe" then
            table.insert(copyLines, (door ~= "") and (e.name .. "|" .. door) or e.name)
        else
            table.insert(copyLines, e.name)
        end
    end
    local rawBoxText = table.concat(copyLines, ", ")

    local dLines = {
        "set_default_color|`o",
        "add_quick_exit|",
        string.format("add_label_with_icon|big|`wKelola Antrean World Put (%d)``|left|2|", #CFG.world_list),
        "add_textbox|`oDi sini Anda bisa menyalin, menempel banyak world, atau edit/hapus antrean.|left|",
        "add_spacer|small|",

        -- Bagian 1: Salin Semua World
        "add_textbox|`2[1. Salin Antrean World Put]|left|",
        string.format("add_text_input|boren_wcopy_box|Salin Antrean|%s|9999|", rawBoxText),
        "add_button|boren_btn_wfmt_colon|Format Titik Dua (:)|noflags|0|0|",
        "add_button|boren_btn_wfmt_pipe|Format Garis (|)|noflags|0|0|",
        "add_button|boren_btn_wfmt_name|Hanya Nama World|noflags|0|0|",
        "add_spacer|small|",

        -- Bagian 2: Tempel Banyak / Tambah World
        "add_textbox|`2[2. Tempel / Tambah World ke Antrean]|left|",
        "add_textbox|`eTempel format: WORLD:ID atau WORLD|ID atau WORLD. Bebas koma/enter.|left|",
        "add_text_input|boren_wpaste_raw|Tempel World di sini:||9999|",
        "add_checkbox|boren_wpaste_replace|Ganti semua antrean (Replace)|0|",
        "add_button|boren_submit_wpaste|`2+ Tempel / Tambah ke Antrean|noflags|0|0|",
        "add_spacer|small|",

        -- Bagian 3: Daftar World Saat Ini
        string.format("add_textbox|`2[3. Daftar Antrean Saat Ini (%d World)]|left|", #CFG.world_list)
    }

    if #CFG.world_list == 0 then
        table.insert(dLines, "add_textbox|`4(Antrean World Put masih kosong. Silakan tempel di atas!)|left|")
    else
        for i, e in ipairs(CFG.world_list) do
            local st = (e.done or e.status == "DONE") and "`2[DONE]" or ((e.status == "PROSES") and "`6[PROSES]" or "`9[ANTRI]")
            local d = (e.door and e.door ~= "") and e.door or "-"
            table.insert(dLines, string.format("add_textbox|`w%d. `9%s `o[Door: %s] %s|left|", i, e.name, d, st))
            table.insert(dLines, string.format("add_button|boren_wedit_%d|Edit|noflags|0|0|", i))
            table.insert(dLines, string.format("add_button|boren_whapus_%d|Hapus|noflags|0|0|", i))
            table.insert(dLines, "add_spacer|small|")
        end
    end

    table.insert(dLines, "end_dialog|boren_world_mgr|Tutup||")
    return safeSendRawDialog(table.concat(dLines, "\n"))
end

local function onSendPacketDialogHook(ptype, pkt)
    if ptype ~= 2 or not pkt then return end
    if not pkt:find("action|dialog_return", 1, true) then return end

    local dMap = {}
    for line in pkt:gmatch("[^\r\n]+") do
        local k, v = line:match("([^|]+)|(.*)")
        if k then dMap[k] = v end
    end
    local dName = dMap["dialog_name"] or ""
    local btn   = dMap["buttonClicked"] or ""

    if dName == "boren_world_mgr" then
        if btn == "boren_btn_wfmt_colon" then
            openWorldListManagerDialog("colon")
            return
        elseif btn == "boren_btn_wfmt_pipe" then
            openWorldListManagerDialog("pipe")
            return
        elseif btn == "boren_btn_wfmt_name" then
            openWorldListManagerDialog("name_only")
            return
        elseif btn == "boren_submit_wpaste" then
            local raw = pkt:match("boren_wpaste_raw|(.-)\nboren_wpaste_replace|")
                or pkt:match("boren_wpaste_raw|(.-)\nbuttonClicked|")
                or tostring(dMap["boren_wpaste_raw"] or "")
            local replace = (dMap["boren_wpaste_replace"] == "1")
            if replace then
                CFG.world_list = {}
            end
            local cnt = addManualWorldsFromString(raw, "")
            persistConfig()
            updateWorldDisplayList()
            if sendNotification then
                pcall(sendNotification, string.format("%d World berhasil dimasukkan ke antrean!", cnt))
            end
            openWorldListManagerDialog()
            return
        end

        local editIdx = tonumber(btn:match("^boren_wedit_(%d+)$"))
        if editIdx then
            openWorldEditDialog(editIdx)
            return
        end

        local delIdx = tonumber(btn:match("^boren_whapus_(%d+)$"))
        if delIdx and CFG.world_list[delIdx] then
            table.remove(CFG.world_list, delIdx)
            persistConfig()
            updateWorldDisplayList()
            openWorldListManagerDialog()
            return
        end
    elseif dName:find("^boren_world_edit_(%d+)$") then
        local idx = tonumber(dName:match("^boren_world_edit_(%d+)$"))
        if idx and CFG.world_list[idx] then
            if btn == "save_w_edit" then
                local newName = tostring(dMap["edit_w_name"] or ""):upper():gsub("%s+", "")
                local newDoor = tostring(dMap["edit_w_door"] or ""):gsub("%s+", "")
                local newDone = (dMap["edit_w_done"] == "1")
                if newName ~= "" then
                    CFG.world_list[idx].name = newName
                    CFG.world_list[idx].door = newDoor
                    CFG.world_list[idx].done = newDone
                    CFG.world_list[idx].status = newDone and "DONE" or "ANTRI"
                    persistConfig()
                    updateWorldDisplayList()
                end
                openWorldListManagerDialog()
                return
            elseif btn == "del_w_edit" then
                table.remove(CFG.world_list, idx)
                persistConfig()
                updateWorldDisplayList()
                openWorldListManagerDialog()
                return
            end
        end
    end
end

-- 16. NATIVE GROWLAUNCHER UI BUILDER (5 Tab Profesional)
local function createNativeUI(subName, iconName)
    if UserInterface and UserInterface.new then
        return UserInterface.new(subName, iconName)
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
        table.insert(self.menu, { type = "toggle", text = text, default = default == true, alias = alias, autosave = autosave == true })
        return self
    end
    function ui:addToggleButton(text, default, alias)
        table.insert(self.menu, { type = "toggle_button", text = text, default = default == true, alias = alias })
        return self
    end
    function ui:addButton(text, alias)
        table.insert(self.menu, { type = "button", text = text, alias = alias })
        return self
    end
    function ui:addInputString(text, default, label, placeholder, icon, alias)
        table.insert(self.menu, { type = "input_string", text = text, default = default or "", label = label or "Text", placeholder = placeholder or "", icon = icon or "", alias = alias })
        return self
    end
    function ui:addInputInt(text, default, label, placeholder, icon, alias)
        table.insert(self.menu, { type = "input_int", text = text, default = tostring(default or "0"), label = label or "Value", placeholder = placeholder or "0", icon = icon or "", alias = alias })
        return self
    end
    function ui:addSlider(text, minVal, maxVal, defaultVal, stepVal, useDot, alias)
        table.insert(self.menu, { type = "slider", text = text, min = minVal, max = maxVal, default = defaultVal, step = stepVal, use_dot = useDot == true, alias = alias })
        return self
    end
    function ui:addTooltip(text, supportText, icon, background)
        table.insert(self.menu, { type = "tooltip", text = text, support_text = supportText or "", icon = icon or "Info", background = background == true })
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

local function registerNativeSoilUI()
    if not addCategory or not addIntoModule then return end

    -- Tab 1: Start & World (World Put)
    local uiWorld = createNativeUI("1. Start & World", "PlayArrow")
    uiWorld:addLabelApp("Boren Store - Soil Builder", "Storefront")
    uiWorld:addToggleButton("▶ START / ■ STOP SOIL BOT", false, "sb_run_power")
    uiWorld:addButton("■ STOP SOIL BOT", "sb_btn_stop")
    uiWorld:addToggle("Pause Bot", false, "sb_pause_toggle", false)
    uiWorld:addDisplayList("Status Bot", "Default", "sb_power_status_list")
    uiWorld:addDivider()
    uiWorld:addLabel("Antrean World Put:")
    uiWorld:addInputString("Nama World Put", CFG.manual_world_text, "World", "WORLD1", "Public", "sb_manual_world_input")
    uiWorld:addInputString("Door ID (Opsional)", CFG.manual_door_text, "Door ID", "Kosong = White Door", "DoorFront", "sb_manual_door_input")
    uiWorld:addButton("+ Tambah World ke Antrean", "sb_btn_add_world")
    uiWorld:addButton("+ Pakai World Sekarang", "sb_btn_add_cur_world")
    uiWorld:addButton("📋 Kelola / Edit, Salin & Tempel World", "sb_btn_view_worlds")
    uiWorld:addButton("🗑️ Kosongkan Semua World", "sb_btn_clear_worlds")
    uiWorld:addDivider()
    uiWorld:addLabel("Cadangan File Antrean:")
    uiWorld:addInputString("Nama File Antrean", CFG.world_file_name, "File", "boren_soil_worlds.txt", "Description", "sb_world_file")
    uiWorld:addButton("📥 Simpan Antrean ke File", "sb_btn_save_worlds")
    uiWorld:addButton("📤 Muat Antrean dari File", "sb_btn_load_worlds")
    uiWorld:addDisplayList("List World Put", "Default", "sb_world_display_list")
    uiWorld:addDivider()
    uiWorld:addLabel("Fitur Auto Blast & Random:")
    uiWorld:addToggle("Gunakan Blast Otomatis", CFG.auto_use_blast, "sb_chk_auto_blast", true)
    uiWorld:addInputInt("ID Item Blast", tostring(CFG.blast_item_id), "Blast ID", "1336 / 2810", "Fire", "sb_in_blast_id")
    uiWorld:addToggle("Mode Random World", CFG.world_mode == "random", "sb_world_random", true)
    uiWorld:addInputInt("Jumlah World Random", tostring(CFG.random_target_count), "Target", "5", "FormatListNumbered", "sb_random_target")
    uiWorld:addSlider("Panjang Nama", 4, 10, CFG.random_length, 1, false, "sb_random_len")
    uiWorld:addToggle("Campur Angka", CFG.random_use_numbers, "sb_random_num", true)

    -- Tab 2: Lock & Door
    local uiLock = createNativeUI("2. Lock & Door", "Lock")
    uiLock:addLabelApp("Proteksi Lock & Door", "Lock")
    uiLock:addTooltip("Posisi Lock", "Jammer kiri door, SL atas jammer, WL kiri jammer, Door ID di (0,0).", "Verified", false)
    uiLock:addToggle("World Lock (WL)", CFG.use_wl, "sb_use_wl", true)
    uiLock:addToggle("WL Public", CFG.wl_public, "sb_wl_public", true)
    uiLock:addToggle("Small Lock (SL)", CFG.use_sl, "sb_use_sl", true)
    uiLock:addToggle("SL Ignore Empty Air", CFG.sl_ignore_air, "sb_sl_ignore", true)
    uiLock:addToggle("SL Public", CFG.sl_public, "sb_sl_public", true)
    uiLock:addToggle("Signal Jammer", CFG.use_jammer, "sb_use_jammer", true)
    uiLock:addToggle("Pasang Door ID di (0,0)", CFG.use_id_door, "sb_use_id_door", true)
    uiLock:addInputString("Target Door ID", CFG.door_id, "ID", "SOIL", "Key", "sb_door_id")
    uiLock:addInputString("Label Door ID", CFG.door_label, "Label", "SOIL", "Label", "sb_door_label")
    uiLock:addSlider("Delay Tele Door (ms)", 500, 4000, CFG.delay_tele_door, 100, false, "sb_delay_tele_door")

    -- Tab 3: Storage (Alat & Block)
    local uiStorage = createNativeUI("3. Storage", "Inventory")
    uiStorage:addLabelApp("Manajemen Storage Gudang", "Inventory")
    uiStorage:addLabel("Storage Gudang Alat (WL, SL, Jammer, Door, Blast):")
    uiStorage:addInputString("World Storage Alat", CFG.storage_tool_world, "World", "GUDANGALAT", "Public", "sb_tool_w")
    uiStorage:addInputString("Door ID Storage Alat", CFG.storage_tool_door, "Door", "KOSONG / ID", "DoorFront", "sb_tool_d")
    uiStorage:addButton("+ Pakai World Sekarang (Alat)", "sb_btn_add_cur_tool")
    uiStorage:addDivider()
    uiStorage:addLabel("Storage Gudang Block (Block Put / Soil):")
    uiStorage:addInputString("World Storage Block", CFG.storage_block_world, "World", "GUDANGBLOCK", "Public", "sb_block_w")
    uiStorage:addInputString("Door ID Storage Block", CFG.storage_block_door, "Door", "KOSONG / ID", "DoorFront", "sb_block_d")
    uiStorage:addButton("+ Pakai World Sekarang (Block)", "sb_btn_add_cur_block")
    uiStorage:addInputInt("ID Block Diletakkan", tostring(CFG.block_id), "ID Block", "8772", "Category", "sb_block_id")

    -- Tab 4: Pengaturan (Tata Letak & Cheats)
    local uiSetting = createNativeUI("4. Pengaturan", "Build")
    uiSetting:addLabelApp("Pengaturan Tata Letak & Gerak", "Build")
    uiSetting:addLabel("Grid Baris Block:")
    uiSetting:addSlider("Jarak Baris (Step)", 1, 4, CFG.row_step, 1, false, "sb_in_row_step")
    uiSetting:addSlider("Baris Awal (Y)", 1, 10, CFG.row_start_y, 1, false, "sb_in_start_y")
    uiSetting:addSlider("Baris Akhir (Y)", 40, 56, CFG.row_end_y, 1, false, "sb_in_end_y")
    uiSetting:addSlider("Kolom Awal (X)", 0, 10, CFG.row_start_x, 1, false, "sb_in_start_x")
    uiSetting:addSlider("Kolom Akhir (X)", 80, 99, CFG.row_end_x, 1, false, "sb_in_end_x")
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
    pcall(addCategory, "Boren Soil", "Storefront")
    pcall(addIntoModule, uiWorld:generateJSON(), "Boren Soil")
    pcall(addIntoModule, uiLock:generateJSON(), "Boren Soil")
    pcall(addIntoModule, uiStorage:generateJSON(), "Boren Soil")
    pcall(addIntoModule, uiSetting:generateJSON(), "Boren Soil")
    pcall(addIntoModule, uiBackpack:generateJSON(), "Boren Soil")
end

-- 17. DISPLAY LIST UPDATERS
updatePowerStatusList = function()
    if not editDisplayList then return end
    local items = {
        string.format("Status: %s", STATE.current_status_title),
        string.format("Keterangan: %s", STATE.current_status_desc),
        string.format("World Aktif: %s (Door: %s)", STATE.active_world ~= "" and STATE.active_world or "-", STATE.active_door ~= "" and STATE.active_door or "-"),
        string.format("Baris Aktif: Y=%d, Col=%d", STATE.active_row, STATE.active_col),
        string.format("Total World Selesai: %d", STATE.worlds_completed),
        string.format("Total Block Terpasang: %d", STATE.total_placed_blocks),
    }
    pcall(editDisplayList, "sb_power_status_list", jsonEncode(items))

    local logItems = {}
    for i = 1, math.min(15, #STATE.last_log_lines) do
        table.insert(logItems, STATE.last_log_lines[i])
    end
    pcall(editDisplayList, "sb_console_list", jsonEncode(logItems))
end

updateWorldDisplayList = function()
    if not editDisplayList then return end
    local items = {}
    if #CFG.world_list == 0 then
        table.insert(items, "(Antrean World Put masih kosong)")
    else
        for i, w in ipairs(CFG.world_list) do
            local d = (w.door and w.door ~= "") and w.door or "-"
            local st = (w.done or w.status == "DONE") and "[DONE]" or (w.status or "[ANTRI]")
            table.insert(items, string.format("%d. %s [Door: %s] - %s", i, w.name, d, st))
        end
    end
    pcall(editDisplayList, "sb_world_display_list", jsonEncode(items))
end

updateBagDisplayList = function()
    if not editDisplayList then return end
    local items = {}
    if getInventory then
        local ok, inv = pcall(getInventory)
        if ok and inv and inv.items then
            for _, it in pairs(inv.items) do
                local id = it.id or it.itemid or 0
                local cnt = it.count or it.amount or 0
                if id > 0 and cnt > 0 then
                    table.insert(items, string.format("%s (ID %d) x%d", resolveItemName(id), id, cnt))
                end
            end
        end
    end
    if #items == 0 then
        table.insert(items, "(Tas kosong atau gagal dibaca)")
    end
    pcall(editDisplayList, "sb_bag_display_list", jsonEncode(items))
end

-- 18. INPUT EXTRACTION HELPER
local function readGLString(alias, defaultVal)
    defaultVal = defaultVal or ""
    if getValue then
        local ok5, v5 = pcall(getValue, 5, alias)
        if ok5 and v5 ~= nil and tostring(v5) ~= "" then
            return tostring(v5)
        end
        local ok2, v2 = pcall(getValue, 2, alias)
        if ok2 and v2 ~= nil and tostring(v2) ~= "" then
            return tostring(v2)
        end
        local ok0, v0 = pcall(getValue, alias)
        if ok0 and v0 ~= nil and tostring(v0) ~= "" then
            return tostring(v0)
        end
    end
    return defaultVal
end

-- 19. GROWLAUNCHER ONVALUE EVENT DISPATCHER
local lastAliasEventTime = {}

local function toBoolVal(v)
    return (v == true or v == 1 or v == "true" or v == "1")
end

local function handleUIValue(vtype, name, value)
    if type(vtype) == "string" and (name == nil or type(name) ~= "string" or (type(name) == "string" and vtype:sub(1, 3) == "sb_")) then
        value = name
        name = vtype
        vtype = 0
    end
    name = tostring(name or "")
    if name == "" then return end

    local now = os.clock()
    local isButton = (name:sub(1, 7) == "sb_btn_")
    if isButton then
        if lastAliasEventTime[name] and (now - lastAliasEventTime[name]) < 0.25 then
            return
        end
        lastAliasEventTime[name] = now
    end

    if name == "sb_run_power" then
        local running = toBoolVal(value)
        if running then
            startSoilBot()
        else
            stopSoilBot()
        end
    elseif name == "sb_btn_stop" then
        stopSoilBot()
        if editToggle then pcall(editToggle, "sb_run_power", false) end
        if sendNotification then pcall(sendNotification, "Soil Builder dihentikan!") end
    elseif name == "sb_pause_toggle" then
        STATE.paused = toBoolVal(value)
        setStatus(STATE.paused and "Paused" or (STATE.running and "Running" or "Siap"), STATE.paused and "Bot dijeda." or "Bot dilanjutkan.")
    elseif name == "sb_manual_world_input" then
        CFG.manual_world_text = tostring(value or ""):upper()
        STATE.buf_world_name = CFG.manual_world_text
    elseif name == "sb_manual_door_input" then
        CFG.manual_door_text = tostring(value or "")
        STATE.buf_world_door = CFG.manual_door_text
    elseif name == "sb_btn_add_world" then
        local wIn = readGLString("sb_manual_world_input", STATE.buf_world_name)
        if wIn ~= "" then
            STATE.buf_world_name = wIn:upper()
            CFG.manual_world_text = STATE.buf_world_name
        end
        local dIn = readGLString("sb_manual_door_input", STATE.buf_world_door)
        if dIn ~= "" then
            STATE.buf_world_door = dIn
            CFG.manual_door_text = dIn
        end
        local targetW = (STATE.buf_world_name ~= "" and STATE.buf_world_name) or CFG.manual_world_text
        local targetD = (STATE.buf_world_door ~= "" and STATE.buf_world_door) or CFG.manual_door_text
        local cnt = addManualWorldsFromString(targetW, targetD)
        persistConfig()
        updateWorldDisplayList()
        if cnt > 0 then
            if sendNotification then pcall(sendNotification, string.format("%d World ditambahkan! (Total: %d)", cnt, #CFG.world_list)) end
        else
            if sendNotification then pcall(sendNotification, "Isi Nama World dulu di atas!") end
        end
    elseif name == "sb_btn_add_cur_world" then
        local curW = getWorldNameSafe()
        if curW ~= "" and curW ~= "EXIT" then
            STATE.buf_world_name = curW
            CFG.manual_world_text = curW
            addManualWorldsFromString(curW, STATE.buf_world_door)
            persistConfig()
            updateWorldDisplayList()
            if sendNotification then pcall(sendNotification, string.format("World ditambahkan: %s (Total: %d)", curW, #CFG.world_list)) end
        else
            if sendNotification then pcall(sendNotification, "Anda belum masuk ke dalam world!") end
        end
    elseif name == "sb_btn_view_worlds" then
        ensureRuntimeHooks()
        updateWorldDisplayList()
        openWorldListManagerDialog()
    elseif name == "sb_btn_clear_worlds" then
        CFG.world_list = {}
        CFG.manual_world_text = ""
        STATE.buf_world_name = ""
        persistConfig()
        updateWorldDisplayList()
        if sendNotification then pcall(sendNotification, "List world dikosongkan!") end
    elseif name == "sb_world_file" then
        CFG.world_file_name = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
        persistConfig()
    elseif name == "sb_btn_save_worlds" then
        local fIn = readGLString("sb_world_file", CFG.world_file_name)
        if fIn ~= "" then CFG.world_file_name = fIn end
        local lines = {}
        for _, w in ipairs(CFG.world_list) do
            local d = (w.door and w.door ~= "") and w.door or ""
            table.insert(lines, (d ~= "") and (w.name .. ":" .. d) or w.name)
        end
        pcall(writeFile, CFG.world_file_name, table.concat(lines, "\n"))
        persistConfig()
        if sendNotification then pcall(sendNotification, string.format("Antrean disimpan ke %s (%d world)", CFG.world_file_name, #CFG.world_list)) end
    elseif name == "sb_btn_load_worlds" then
        local fIn = readGLString("sb_world_file", CFG.world_file_name)
        if fIn ~= "" then CFG.world_file_name = fIn end
        local ok, content = pcall(readFile, CFG.world_file_name)
        if ok and content and content ~= "" then
            local cnt = addManualWorldsFromString(content, "")
            persistConfig()
            updateWorldDisplayList()
            if sendNotification then pcall(sendNotification, string.format("%d World dimuat dari %s!", cnt, CFG.world_file_name)) end
        else
            if sendNotification then pcall(sendNotification, "Gagal membaca file: " .. CFG.world_file_name) end
        end
    elseif name == "sb_chk_auto_blast" then
        CFG.auto_use_blast = toBoolVal(value)
        persistConfig()
    elseif name == "sb_in_blast_id" then
        CFG.blast_item_id = tonumber(value) or CFG.blast_item_id
        persistConfig()
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
    elseif name == "sb_door_id" then
        CFG.door_id = tostring(value or ""):gsub("%s+", "")
        persistConfig()
    elseif name == "sb_door_label" then
        CFG.door_label = tostring(value or "")
        persistConfig()
    elseif name == "sb_delay_tele_door" then
        CFG.delay_tele_door = tonumber(value) or CFG.delay_tele_door
        persistConfig()
    -- Tab 3: Storage
    elseif name == "sb_tool_w" then
        CFG.storage_tool_world = tostring(value or ""):upper():gsub("%s+", "")
        persistConfig()
    elseif name == "sb_tool_d" then
        CFG.storage_tool_door = tostring(value or ""):gsub("%s+", "")
        persistConfig()
    elseif name == "sb_btn_add_cur_tool" then
        local curW = getWorldNameSafe()
        if curW ~= "" and curW ~= "EXIT" then
            CFG.storage_tool_world = curW
            persistConfig()
            if sendNotification then pcall(sendNotification, "Storage Alat diatur ke: " .. curW) end
        end
    elseif name == "sb_block_w" then
        CFG.storage_block_world = tostring(value or ""):upper():gsub("%s+", "")
        persistConfig()
    elseif name == "sb_block_d" then
        CFG.storage_block_door = tostring(value or ""):gsub("%s+", "")
        persistConfig()
    elseif name == "sb_btn_add_cur_block" then
        local curW = getWorldNameSafe()
        if curW ~= "" and curW ~= "EXIT" then
            CFG.storage_block_world = curW
            persistConfig()
            if sendNotification then pcall(sendNotification, "Storage Block diatur ke: " .. curW) end
        end
    elseif name == "sb_block_id" then
        CFG.block_id = tonumber(value) or CFG.block_id
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

-- 20. BINDING HOOKS RESMI (onValue, onSendPacket, onVariant)
function OnValue(a1, a2, a3)
    pcall(handleUIValue, a1, a2, a3)
end
onValue = OnValue
onSendPacket = onSendPacketDialogHook
OnSendPacket = onSendPacketDialogHook

-- Daftarkan Hook onsendpacket & onvariant
if addHook then
    pcall(addHook, onSendPacketDialogHook, "onsendpacket")
    pcall(addHook, onVariantDialogHook, "onvariant")
    pcall(addHook, onValue, "onvalue")
    if applyHook then pcall(applyHook) end
end

-- 21. INISIALISASI UI & ALIAS REGISTRATION
registerNativeSoilUI()
updatePowerStatusList()
updateWorldDisplayList()
updateBagDisplayList()

local ALL_UI_ALIASES = {
    "sb_run_power", "sb_btn_stop", "sb_pause_toggle",
    "sb_manual_world_input", "sb_manual_door_input",
    "sb_btn_add_world", "sb_btn_add_cur_world", "sb_btn_view_worlds", "sb_btn_clear_worlds",
    "sb_world_file", "sb_btn_save_worlds", "sb_btn_load_worlds",
    "sb_chk_auto_blast", "sb_in_blast_id", "sb_world_random", "sb_random_target", "sb_random_len", "sb_random_num",
    "sb_use_wl", "sb_wl_public", "sb_use_sl", "sb_sl_ignore", "sb_sl_public",
    "sb_use_jammer", "sb_use_id_door", "sb_door_id", "sb_door_label", "sb_delay_tele_door",
    "sb_tool_w", "sb_tool_d", "sb_btn_add_cur_tool",
    "sb_block_w", "sb_block_d", "sb_btn_add_cur_block", "sb_block_id",
    "sb_in_row_step", "sb_in_start_y", "sb_in_end_y", "sb_in_start_x", "sb_in_end_x",
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
_G.setupWorldLocks = setupWorldLocks
