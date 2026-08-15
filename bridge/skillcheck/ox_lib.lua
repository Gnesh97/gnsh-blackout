if IsDuplicityVersion() then return end
SkillcheckAdapters = SkillcheckAdapters or {}
SkillcheckAdapters.ox_lib = {}
local A = SkillcheckAdapters.ox_lib

local function normalizeDifficulty(difficulty)
    if type(difficulty) == 'string' then
        return { difficulty }
    end

    if type(difficulty) ~= 'table' then
        return { 'easy' }
    end

    if difficulty.areaSize ~= nil then
        return { difficulty }
    end

    local normalized = {}
    for index = 1, #difficulty do
        local stage = difficulty[index]
        if type(stage) == 'string' or type(stage) == 'table' then
            normalized[#normalized + 1] = stage
        end
    end

    if #normalized == 0 then
        return { 'easy' }
    end

    return normalized
end

local function normalizeInputs(inputs)
    local normalized = {}
    if type(inputs) == 'table' then
        for index = 1, #inputs do
            local input = inputs[index]
            if type(input) == 'string' and input ~= '' then
                normalized[#normalized + 1] = input:lower()
            end
        end
    elseif type(inputs) == 'string' and inputs ~= '' then
        normalized[1] = inputs:lower()
    end

    if #normalized == 0 then
        return { 'e' }
    end

    return normalized
end

local function strictFallback(difficulty, inputs)
    if InternalUI and type(InternalUI.SkillCheck) == 'function' then
        return InternalUI.SkillCheck(difficulty, inputs) == true
    end

    return false
end

local function callOxLibSkillCheck(difficulty, inputs)
    if not OxLibBridge
        or type(OxLibBridge.IsAvailable) ~= 'function'
        or OxLibBridge.IsAvailable('skillCheck') ~= true
        or not exports then
        return false, nil
    end

    -- ox_lib exports are owner-bound. Keep the documented `:` call shape for
    -- skillCheck; passing the export function through a generic dynamic
    -- wrapper can shift difficulty into the wrong argument position.
    local ok, result = pcall(function()
        return exports['ox_lib']:skillCheck(difficulty, inputs)
    end)
    return ok, result
end

function A.SkillCheck(difficulty, inputs)
    local normalizedDifficulty = normalizeDifficulty(difficulty)
    local normalizedInputs = normalizeInputs(inputs)

    local ok, result = callOxLibSkillCheck(normalizedDifficulty, normalizedInputs)
    if ok then return result == true end

    -- An explicit ox_lib selection must never silently fall through to the
    -- universal NUI adapter. That adapter is a timed bar, not ox_lib's
    -- strict angular target, and would make a failed export look successful.
    return strictFallback(normalizedDifficulty, normalizedInputs)
end
