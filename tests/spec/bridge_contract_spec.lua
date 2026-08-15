-- Universal bridge pure contract tests.

TEST('bridge normalizes legacy aliases without changing canonical keys', function()
    ASSERT_EQ(BridgeCore.Normalize('framework', 'qb-core'), 'qbcore')
    ASSERT_EQ(BridgeCore.Normalize('framework', 'qbox'), 'qbox')
    ASSERT_EQ(BridgeCore.Normalize('framework', 'esx-legacy'), 'esx')
    ASSERT_EQ(BridgeCore.Normalize('inventory', 'qb-inventory'), 'qb_inventory')
    ASSERT_EQ(BridgeCore.Normalize('target', 'qb-target'), 'qb_target')
    ASSERT_EQ(BridgeCore.Normalize('database', 'ox'), 'oxmysql')
end)

TEST('bridge rejects unknown adapter aliases', function()
    ASSERT_EQ(BridgeCore.Normalize('framework', 'unknown-framework'), nil)
    ASSERT_EQ(BridgeCore.Normalize('inventory', 'unknown-inventory'), nil)
    ASSERT_EQ(BridgeCore.Normalize('menu', 'unknown-menu'), nil)
end)

TEST('bridge selects explicit compatible adapter and safe fallback', function()
    local key = BridgeCore.Select('preferred', {
        { key = 'preferred', available = true },
        { key = 'fallback', available = true },
    }, 'fallback')
    ASSERT_EQ(key, 'preferred')

    local fallback, reason = BridgeCore.Select('missing', {
        { key = 'preferred', available = true },
    }, 'fallback')
    ASSERT_EQ(fallback, 'fallback')
    ASSERT_TRUE(type(reason) == 'string')
end)

TEST('bridge validates required adapter functions', function()
    local ok, missing = BridgeCore.ValidateAdapter('inventory', {
        HasItem = function() end,
        AddItem = function() end,
    }, 'server')
    ASSERT_FALSE(ok)
    ASSERT_EQ(missing[1], 'RemoveItem')

    local valid = BridgeCore.ValidateAdapter('target', {
        RegisterInteractable = function() end,
        RemoveInteractable = function() end,
    }, 'client')
    ASSERT_TRUE(valid)
end)

TEST('bridge snapshot copy does not mutate source', function()
    local source = { adapter = { key = 'standalone' }, list = { 'one' } }
    local copy = BridgeCore.Copy(source)
    copy.adapter.key = 'changed'
    copy.list[1] = 'changed'
    ASSERT_EQ(source.adapter.key, 'standalone')
    ASSERT_EQ(source.list[1], 'one')
end)

TEST('bridge config accepts legacy aliases and rejects unknown values', function()
    local original = Config.Bridge.framework
    Config.Bridge.framework = 'qb-core'
    local ok = Validators.ValidateAll()
    ASSERT_TRUE(ok)
    Config.Bridge.framework = 'not-a-framework'
    local invalid, errors = Validators.ValidateAll()
    ASSERT_FALSE(invalid)
    ASSERT_TRUE(#errors > 0)
    Config.Bridge.framework = original
end)

TEST('universal NUI adapter is framework-independent and UI routes stay universal', function()
    local manifestFile = assert(io.open('fxmanifest.lua', 'r'))
    local manifest = manifestFile:read('*a')
    manifestFile:close()
    ASSERT_TRUE(manifest:find("ui_page 'web/index.html'", 1, true) ~= nil)
    ASSERT_TRUE(manifest:find("'bridge/nui.lua'", 1, true) ~= nil)
    ASSERT_EQ(BridgeCore.Normalize('menu', 'universal'), 'nui')
    ASSERT_EQ(BridgeCore.Normalize('progress', 'nui'), 'nui')
    ASSERT_EQ(BridgeCore.Normalize('skillcheck', 'universal-ui'), 'nui')

    local internalRoutes = {
        ['bridge/menu/internal.lua'] = 'MenuAdapters.nui',
        ['bridge/notify/internal.lua'] = 'NotifyAdapters.nui',
        ['bridge/progress/internal.lua'] = 'ProgressAdapters.nui',
        ['bridge/skillcheck/internal.lua'] = 'SkillcheckAdapters.nui',
    }
    for path, marker in pairs(internalRoutes) do
        local file = assert(io.open(path, 'r'))
        local source = file:read('*a')
        file:close()
        ASSERT_TRUE(source:find(marker, 1, true) ~= nil, path .. ': missing universal UI route')
    end

    local nativeFallback = assert(io.open('bridge/ux/internal.lua', 'r'))
    local nativeSource = nativeFallback:read('*a')
    nativeFallback:close()
    ASSERT_TRUE(nativeSource:find('DrawRect', 1, true) ~= nil)

    local cssFile = assert(io.open('web/style.css', 'r'))
    local cssSource = cssFile:read('*a')
    cssFile:close()
    ASSERT_TRUE(cssSource:find('html:not(.ui-active) body', 1, true) ~= nil)
    ASSERT_TRUE(cssSource:find('html.ui-active body', 1, true) ~= nil)

    local jsFile = assert(io.open('web/app.js', 'r'))
    local jsSource = jsFile:read('*a')
    jsFile:close()
    local geometryFile = assert(io.open('web/assets/gta-native-districts.json', 'r'))
    local geometrySource = geometryFile:read('*a')
    geometryFile:close()
    ASSERT_TRUE(jsSource:find('document.documentElement.classList.toggle', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('closeAll%(%)', 1) ~= nil)
end)

TEST('NUI is transparent and hidden before its first explicit UI message', function()
    local htmlFile = assert(io.open('web/index.html', 'r'))
    local htmlSource = htmlFile:read('*a')
    htmlFile:close()
    local cssFile = assert(io.open('web/style.css', 'r'))
    local cssSource = cssFile:read('*a')
    cssFile:close()

    local criticalStyle = htmlSource:find('<style id="nui-boot-style">', 1, true)
    local externalStyle = htmlSource:find('<link rel="stylesheet" href="style.css">', 1, true)
    ASSERT_TRUE(criticalStyle ~= nil, 'missing first-paint NUI visibility guard')
    ASSERT_TRUE(externalStyle ~= nil and criticalStyle < externalStyle, 'first-paint guard must load before external CSS')
    ASSERT_TRUE(htmlSource:find('html:not(.ui-active)', 1, true) ~= nil, 'inactive document must stay hidden')
    ASSERT_TRUE(htmlSource:find('background: transparent !important', 1, true) ~= nil, 'inactive document must stay transparent')
    ASSERT_TRUE(htmlSource:find('color-scheme: dark', 1, true) == nil, 'dark color scheme can paint an opaque browser canvas')
    ASSERT_TRUE(cssSource:find('color-scheme: dark', 1, true) == nil, 'dark color scheme can paint an opaque browser canvas')
end)

TEST('blackout link status is reflected by the universal NUI', function()
    local htmlFile = assert(io.open('web/index.html', 'r'))
    local htmlSource = htmlFile:read('*a')
    htmlFile:close()
    local jsFile = assert(io.open('web/app.js', 'r'))
    local jsSource = jsFile:read('*a')
    jsFile:close()
    local cssFile = assert(io.open('web/style.css', 'r'))
    local cssSource = cssFile:read('*a')
    cssFile:close()
    local clientFile = assert(io.open('client/main.lua', 'r'))
    local clientSource = clientFile:read('*a')
    clientFile:close()
    local nuiFile = assert(io.open('bridge/nui.lua', 'r'))
    local nuiSource = nuiFile:read('*a')
    nuiFile:close()

    ASSERT_TRUE(htmlSource:find('id="link-status"', 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('id="link-state"', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find("data.action === 'linkStatus'", 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find("'KARARSIZ'", 1, true) ~= nil)
    ASSERT_TRUE(cssSource:find('.header-status.is-unstable::before', 1, true) ~= nil)
    ASSERT_TRUE(cssSource:find('.header-status.is-unstable strong', 1, true) ~= nil)
    ASSERT_TRUE(clientSource:find("action = 'linkStatus'", 1, true) ~= nil)
    ASSERT_TRUE(clientSource:find('publishLinkStatus', 1, true) ~= nil)
    ASSERT_TRUE(nuiSource:find('linkUnstable', 1, true) ~= nil)
end)

TEST('admin panel command, snapshot, and tab contracts stay aligned', function()
    local htmlFile = assert(io.open('web/index.html', 'r'))
    local htmlSource = htmlFile:read('*a')
    htmlFile:close()
    local jsFile = assert(io.open('web/app.js', 'r'))
    local jsSource = jsFile:read('*a')
    jsFile:close()
    local nuiFile = assert(io.open('bridge/nui.lua', 'r'))
    local nuiSource = nuiFile:read('*a')
    nuiFile:close()
    local clientFile = assert(io.open('client/txadmin_auth.lua', 'r'))
    local clientSource = clientFile:read('*a')
    clientFile:close()
    local serverFile = assert(io.open('server/admin_operations.lua', 'r'))
    local serverSource = serverFile:read('*a')
    serverFile:close()

    ASSERT_TRUE(clientSource:find("RegisterCommand('blackoutadmin'", 1, true) ~= nil)
    ASSERT_TRUE(serverSource:find('requestAdminPanel', 1, true) ~= nil)
    ASSERT_TRUE(serverSource:find('requestAdminSnapshot', 1, true) ~= nil)
    ASSERT_TRUE(serverSource:find('AdminOperations.CommandCatalog', 1, true) ~= nil)
    ASSERT_TRUE(serverSource:find('function AdminOperations.Execute', 1, true) ~= nil)
    ASSERT_TRUE(nuiSource:find("registerCallback('adminRefresh'", 1, true) ~= nil)
    ASSERT_TRUE(nuiSource:find("registerCallback('adminCommand'", 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('role="tablist"', 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('id="admin-map-svg"', 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('id="admin-tab-commands"', 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('CANLI HARİTA / 01', 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('KOMUT KATALOĞU / 02', 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('YETKİLİ İŞLEM', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find("data.action === 'adminOpen'", 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find("post('adminCommand'", 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('function adminProjectPoint', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('function adminCategoryCopy', 1, true) ~= nil)
end)

TEST('admin map asset and coordinate viewer contracts stay aligned', function()
    local manifestFile = assert(io.open('fxmanifest.lua', 'r'))
    local manifestSource = manifestFile:read('*a')
    manifestFile:close()
    local htmlFile = assert(io.open('web/index.html', 'r'))
    local htmlSource = htmlFile:read('*a')
    htmlFile:close()
    local jsFile = assert(io.open('web/app.js', 'r'))
    local jsSource = jsFile:read('*a')
    jsFile:close()
    local cssFile = assert(io.open('web/style.css', 'r'))
    local cssSource = cssFile:read('*a')
    cssFile:close()
    local geometryFile = assert(io.open('web/assets/gta-native-districts.json', 'r'))
    local geometrySource = geometryFile:read('*a')
    geometryFile:close()

    ASSERT_TRUE(manifestSource:find("'web/assets/gta-base-map.png'", 1, true) ~= nil)
    ASSERT_TRUE(manifestSource:find("'web/assets/gta-native-districts.json'", 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('src="assets/gta-base-map.png"', 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('href="assets/gta-district-map.png"', 1, true) == nil)
    ASSERT_TRUE(htmlSource:find('viewBox="0 0 2048 2048"', 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('id="admin-map-zoom-in"', 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('id="admin-map-reset"', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('function applyAdminMapCamera', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('function loadAdminGeometry', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('function adminDistrictBounds', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find("data.format === 'world-rects'", 1, true) ~= nil)
    ASSERT_TRUE(cssSource:find('admin-zone__shape--native', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('adminMapZoom', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('adminMapZoomMax = 12', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find("addEventListener('pointerdown'", 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('!event.ctrlKey', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('function adminMapPointFromClient', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('Math.exp(', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find("addEventListener('click'", 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('event.stopPropagation()', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('adminMapMarkers.append', 1, true) ~= nil)
    ASSERT_TRUE(cssSource:find('.admin-marker { pointer-events: none;', 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('class="admin-map-image"', 1, true) ~= nil)
    ASSERT_TRUE(geometrySource:find('"format":"world-rects"', 1, true) ~= nil)
    ASSERT_TRUE(geometrySource:find('"source":"popzone.ipl"', 1, true) ~= nil)
    ASSERT_TRUE(geometrySource:find('"originX":939', 1, true) ~= nil)
    ASSERT_TRUE(geometrySource:find('"originY":1381', 1, true) ~= nil)
    ASSERT_TRUE(geometrySource:find('"scaleX":0.16425', 1, true) ~= nil)
    ASSERT_TRUE(geometrySource:find('"scaleY":0.16425', 1, true) ~= nil)
end)

TEST('NUI visible copy is Turkish, including dynamic operation labels', function()
    local htmlFile = assert(io.open('web/index.html', 'r'))
    local htmlSource = htmlFile:read('*a')
    htmlFile:close()
    local jsFile = assert(io.open('web/app.js', 'r'))
    local jsSource = jsFile:read('*a')
    jsFile:close()
    local nuiFile = assert(io.open('bridge/nui.lua', 'r'))
    local nuiSource = nuiFile:read('*a')
    nuiFile:close()
    local repairFile = assert(io.open('client/repair.lua', 'r'))
    local repairSource = repairFile:read('*a')
    repairFile:close()
    local sabotageFile = assert(io.open('client/sabotage.lua', 'r'))
    local sabotageSource = sabotageFile:read('*a')
    sabotageFile:close()

    ASSERT_TRUE(htmlSource:find('ALTYAPI KONTROLÜ', 1, true) ~= nil)
    ASSERT_TRUE(htmlSource:find('YETKİLİ İŞLEMLER', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find("'KARARSIZ'", 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('TAMİR PROTOKOLÜ', 1, true) ~= nil)
    ASSERT_TRUE(jsSource:find('SİSTEM UYARISI', 1, true) ~= nil)
    ASSERT_TRUE(nuiSource:find("'Altyapı Kontrolü'", 1, true) ~= nil)
    ASSERT_TRUE(repairSource:find("DIAGNOSE = 'Teşhis'", 1, true) ~= nil)
    ASSERT_TRUE(sabotageSource:find('localizeTransformerLabel', 1, true) ~= nil)
end)

TEST('NUI callback names stay aligned between Lua adapter and browser client', function()
    local luaFile = assert(io.open('bridge/nui.lua', 'r'))
    local luaSource = luaFile:read('*a')
    luaFile:close()
    local jsFile = assert(io.open('web/app.js', 'r'))
    local jsSource = jsFile:read('*a')
    jsFile:close()

    local callbacks = { 'menuSelect', 'menuClose', 'progressComplete', 'progressCancel', 'skillResult' }
    for _, name in ipairs(callbacks) do
        ASSERT_TRUE(luaSource:find("registerCallback('" .. name .. "'", 1, true) ~= nil, name .. ': missing Lua callback')
        ASSERT_TRUE(jsSource:find("post('" .. name .. "'", 1, true) ~= nil, name .. ': missing browser callback')
    end
end)

TEST('qb-menu adapter forwards its action token through the args table', function()
    local previousDuplicity = IsDuplicityVersion
    local previousRegisterNetEvent = RegisterNetEvent
    local previousGetResourceState = GetResourceState
    local previousExports = exports
    local previousMenuAdapters = MenuAdapters

    local registeredHandler
    local openedEntries
    local actionCalled = false

    IsDuplicityVersion = function() return false end
    RegisterNetEvent = function(_, handler) registeredHandler = handler end
    GetResourceState = function() return 'started' end
    exports = setmetatable({}, {
        __index = function()
            return {
                openMenu = function(_, entries) openedEntries = entries end,
            }
        end,
    })

    MenuAdapters = nil
    local loadOk, loadError = pcall(dofile, 'bridge/menu/qb_menu.lua')
    if loadOk then
        loadOk = pcall(MenuAdapters.qb_menu.OpenMenu, {
            label = 'Test',
            options = { { label = 'Sabotaj', action = function() actionCalled = true end } },
        })
    end
    if loadOk and registeredHandler and openedEntries then
        registeredHandler(openedEntries[1].params.args)
    end

    IsDuplicityVersion = previousDuplicity
    RegisterNetEvent = previousRegisterNetEvent
    GetResourceState = previousGetResourceState
    exports = previousExports
    MenuAdapters = previousMenuAdapters

    ASSERT_TRUE(loadOk, loadError)
    ASSERT_TRUE(registeredHandler ~= nil)
    ASSERT_TRUE(openedEntries ~= nil)
    ASSERT_TRUE(actionCalled)
end)

TEST('native skillcheck fallback contains a visible prompt renderer', function()
    local file = assert(io.open('bridge/ux/internal.lua', 'r'))
    local source = file:read('*a')
    file:close()

    ASSERT_TRUE(source:find('DrawRect', 1, true) ~= nil)
    ASSERT_TRUE(source:find('EndTextCommandDisplayText', 1, true) ~= nil)
end)

TEST('native skillcheck isolates the interaction key from target adapters', function()
    local file = assert(io.open('bridge/ux/internal.lua', 'r'))
    local source = file:read('*a')
    file:close()

    ASSERT_TRUE(source:find('DisableControlAction', 1, true) ~= nil)
    ASSERT_TRUE(source:find('IsDisabledControlJustPressed', 1, true) ~= nil)
end)

TEST('standalone target uses a contextual prompt without a floor marker', function()
    local file = assert(io.open('bridge/target/standalone.lua', 'r'))
    local source = file:read('*a')
    file:close()

    ASSERT_TRUE(source:find('World3dToScreen2d', 1, true) ~= nil)
    ASSERT_TRUE(source:find('IsControlJustReleased', 1, true) ~= nil)
    ASSERT_TRUE(source:find('DrawMarker', 1, true) == nil)
    ASSERT_TRUE(source:find('standalonePromptDistance', 1, true) ~= nil)
end)

TEST('bridge startup diagnostics include every adapter category', function()
    local file = assert(io.open('bridge/loader.lua', 'r'))
    local source = file:read('*a')
    file:close()

    ASSERT_TRUE(source:find('notify=%s menu=%s progress=%s skillcheck=%s', 1, true) ~= nil)
end)

TEST('ox_lib bridge uses an optional runtime import', function()
    local manifestFile = assert(io.open('fxmanifest.lua', 'r'))
    local manifest = manifestFile:read('*a')
    manifestFile:close()

    ASSERT_TRUE(manifest:find("'bridge/optional.lua'", 1, true) ~= nil)
    ASSERT_TRUE(manifest:find("@ox_lib/init.lua", 1, true) == nil)

    local file = assert(io.open('bridge/optional.lua', 'r'))
    local source = file:read('*a')
    file:close()

    ASSERT_TRUE(source:find("exports['ox_lib']", 1, true) ~= nil)
    ASSERT_TRUE(source:find('function O.IsAvailable', 1, true) ~= nil)
    ASSERT_TRUE(source:find('function O.Call', 1, true) ~= nil)
end)

TEST('ox_lib skillcheck normalizes payload and keeps a strict fallback', function()
    local file = assert(io.open('bridge/skillcheck/ox_lib.lua', 'r'))
    local source = file:read('*a')
    file:close()

    ASSERT_TRUE(source:find('normalizeDifficulty', 1, true) ~= nil)
    ASSERT_TRUE(source:find('normalizeInputs', 1, true) ~= nil)
    ASSERT_TRUE(source:find("exports['ox_lib']:skillCheck(difficulty, inputs)", 1, true) ~= nil)
    ASSERT_TRUE(source:find('InternalUI.SkillCheck', 1, true) ~= nil)
    ASSERT_TRUE(source:find('SkillcheckAdapters.internal.SkillCheck', 1, true) == nil)
end)

TEST('progressbar adapter translates generic disable options to its control contract', function()
    local file = assert(io.open('bridge/progress/progressbar.lua', 'r'))
    local source = file:read('*a')
    file:close()

    ASSERT_TRUE(source:find('controlDisables', 1, true) ~= nil)
    ASSERT_TRUE(source:find('disableMovement', 1, true) ~= nil)
    ASSERT_TRUE(source:find('disableCarMovement', 1, true) ~= nil)
    ASSERT_TRUE(source:find('disableCombat', 1, true) ~= nil)
    ASSERT_TRUE(source:find('disableMouse', 1, true) ~= nil)
end)

TEST('ox inventory adapter uses mutating exports for item consumption', function()
    local file = assert(io.open('bridge/inventory/ox_inventory.lua', 'r'))
    local source = file:read('*a')
    file:close()

    ASSERT_TRUE(source:find('exports.ox_inventory:RemoveItem', 1, true) ~= nil)
    ASSERT_TRUE(source:find('exports.ox_inventory:AddItem', 1, true) ~= nil)
end)
