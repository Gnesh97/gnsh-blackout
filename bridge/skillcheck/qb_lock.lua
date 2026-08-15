if IsDuplicityVersion() then return end
SkillcheckAdapters = SkillcheckAdapters or {}
SkillcheckAdapters.qb_lock = {}
local A = SkillcheckAdapters.qb_lock

function A.SkillCheck(_difficulty, _inputs)
    if GetResourceState('qb-lock') ~= 'started' then return SkillcheckAdapters.internal.SkillCheck(_difficulty, _inputs) end
    local request = promise.new()
    local ok = pcall(function()
        exports['qb-lock']:StartLockPick(function(result) request:resolve(result == true) end, 4, 3)
    end)
    if not ok then return SkillcheckAdapters.internal.SkillCheck(_difficulty, _inputs) end
    return Citizen.Await(request) == true
end

