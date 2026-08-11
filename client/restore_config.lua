--[[
    client/restore_config.lua

    menuv/menuv.lua declares its own bare global `Config` and, because
    '@menuv/menuv.lua' is imported into this resource's client_scripts
    (see fxmanifest.lua), it overwrites gnsh-blackout's `Config` global
    the instant it loads. This file MUST be the very next client_script
    after the menuv import (and before bridge/loader.lua, or any other
    file that reads Config) — it restores the real Config from the
    collision-proof backup config.lua stashed at _G.__GnshBlackoutConfig.
]]

Config = _G.__GnshBlackoutConfig
