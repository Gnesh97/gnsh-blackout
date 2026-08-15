if IsDuplicityVersion() then return end
SkillcheckAdapters = SkillcheckAdapters or {}
SkillcheckAdapters.internal = {}
local universalForwarding = false

local function tryUniversal(difficulty, inputs, metadata)
    if universalForwarding then return false, nil end
    local adapter = SkillcheckAdapters.nui
    if type(adapter) ~= 'table' or type(adapter.SkillCheck) ~= 'function' then return false, nil end

    universalForwarding = true
    local ok, result = pcall(adapter.SkillCheck, difficulty, inputs, metadata)
    universalForwarding = false
    return true, ok and result or false
end

function SkillcheckAdapters.internal.SkillCheck(difficulty, inputs, metadata)
    local handled, universal = tryUniversal(difficulty, inputs, metadata)
    if handled then return universal end
    return InternalUI.SkillCheck(difficulty, inputs)
end
