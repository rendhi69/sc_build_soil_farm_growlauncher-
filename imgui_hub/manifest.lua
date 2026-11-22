-- ============================================================================
-- BOREN STORE - DEDICATED FEATURE MANIFEST (BUILD SOIL)
-- File: imgui_hub/manifest.lua
-- Repo: https://github.com/rendhi69/sc_build_soil_farm_growlauncher-.git
-- ============================================================================

return {
    schema = "boren_gl_manifest_v1",
    core = {
        { key = "conn", path = "imgui_hub/conn_guard.lua", required = false },
    },
    features = {
        { id = "build_soil", label = "Build Soil", order = 30, path = "imgui_hub/mod_soil_builder.lua" },
    },
}
