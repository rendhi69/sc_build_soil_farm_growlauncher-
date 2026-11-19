-- ============================================================================
-- LOADER AUTO SOIL & BLOCK BUILDER - BOREN STORE
-- ============================================================================
-- Skrip ini memuat auto_soil_builder.lua untuk penempatan block soil sesuai
-- Layout Gambar 1 & Pengaman Kunci Gambar 2, dengan auto-fetch & local fallback.
-- ============================================================================

local RAW_URL = "https://raw.githubusercontent.com/rendhi69/sc_build_soil_farm_growlauncher-/main/auto_soil_builder.lua"
local cacheBuster = tostring(math.floor((os and os.time and os.time()) or (os and os.clock and os.clock() * 1000) or math.random(100000, 999999)))
local fetchUrl = RAW_URL .. "?v=" .. cacheBuster

local function notifyUser(msg)
    if sendNotification then
        pcall(sendNotification, msg)
    elseif growtopia and growtopia.notify then
        pcall(growtopia.notify, msg)
    end
end

if LogToConsole then
    LogToConsole("`9[Boren Soil Loader] `0Menghubungkan dan memuat Auto Soil Builder...")
end
notifyUser("Memuat Auto Soil Builder...")

local content, err = nil, nil
if fetch then
    local okFetch, res, fetchErr = pcall(fetch, fetchUrl)
    if okFetch and res and type(res) == "string" and res ~= "" and not res:match("^404") and (res:find("AUTO SOIL") or res:find("Boren Store")) then
        content = res
    else
        err = fetchErr or "Respons invalid atau kosong"
    end
end

-- Fallback jika koneksi offline atau fetch tidak tersedia di versi GL tertentu
if not content or content == "" then
    if LogToConsole then
        LogToConsole("`e[Boren Soil Loader] `0Fetch online dilewati / offline. Memuat file lokal...")
    end
    local candidatePaths = {
        "/storage/emulated/0/Android/media/launcher.powerkuy.growlauncher/ScriptLua/auto_soil_builder.lua",
        "/storage/emulated/0/Android/media/launcher.powerkuy.growlauncher/ScriptLua/script code/auto_soil_builder.lua",
        "/storage/emulated/0/Android/data/launcher.powerkuy.growlauncher/files/ScriptLua/auto_soil_builder.lua",
        "/storage/emulated/0/Download/auto_soil_builder.lua",
        "script/script code/auto_soil_builder.lua",
        "auto_soil_builder.lua"
    }
    for _, p in ipairs(candidatePaths) do
        local okF, fh = pcall(io.open, p, "r")
        if okF and fh then
            local text = fh:read("*a")
            fh:close()
            if text and text ~= "" then
                content = text
                if LogToConsole then
                    LogToConsole("`2[Boren Soil Loader] `0File lokal berhasil dimuat dari: " .. p)
                end
                break
            end
        end
    end
end

if content and content ~= "" then
    local loaderFn = loadstring or load
    local chunk, loadErr = loaderFn(content)
    if chunk then
        local okExec, runErr = pcall(chunk)
        if okExec then
            if LogToConsole then
                LogToConsole("`2[Boren Soil Loader] `0Auto Soil Builder berhasil dijalankan!")
            end
            notifyUser("Auto Soil Builder Siap Digunakan!")
        else
            local errMsg = "Error runtime: " .. tostring(runErr)
            if LogToConsole then LogToConsole("`4[Boren Soil Loader] `0" .. errMsg) end
            notifyUser(errMsg)
        end
    else
        local errMsg = "Error kompilasi script: " .. tostring(loadErr)
        if LogToConsole then LogToConsole("`4[Boren Soil Loader] `0" .. errMsg) end
        notifyUser(errMsg)
    end
else
    local errMsg = "Gagal memuat auto_soil_builder.lua (koneksi offline dan file lokal tidak ditemukan)."
    if LogToConsole then LogToConsole("`4[Boren Soil Loader] `0" .. errMsg) end
    notifyUser(errMsg)
end
