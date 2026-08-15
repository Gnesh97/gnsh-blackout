-- Volatile database fallback. It deliberately does not survive resource
-- restart; runtime behavior remains available without SQL.

if not IsDuplicityVersion() then return end
DatabaseAdapters = DatabaseAdapters or {}
DatabaseAdapters.memory = {}
local A = DatabaseAdapters.memory

function A.Available() return false end
function A.Query(_query, _params) return {} end
function A.Insert(_query, _params) return 0 end
function A.Update(_query, _params) return 0 end
