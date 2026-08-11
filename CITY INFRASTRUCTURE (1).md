# CITY INFRASTRUCTURE
## FiveM Dynamic Power Grid, District Blackout, Fault, Sabotage & Repair Framework
### MASTER TECHNICAL SPECIFICATION — V3
### Agent-Agnostic Development Plan

---

# 0. BELGENİN AMACI

Sen Kıdemli bir FiveM script geliştiricisisin.

Temel yaklaşım:

```text
SPECIFICATION
      ↓
WORK PACKAGE
      ↓
IMPLEMENTATION
      ↓
TEST
      ↓
VALIDATION
      ↓
NEXT PACKAGE
```

Her agent mevcut kod tabanını ve bu belgeyi kaynak gerçekliği olarak kabul etmelidir.

---

# 1. PROJE VİZYONU

Bu resource yalnızca:

```text
Trafo patlat
↓
Ekranı karart
```

scripti olmayacaktır.

Ana ürün:

```text
CITY INFRASTRUCTURE / POWER GRID FRAMEWORK
```

olacaktır.

Sistem şehrin:

- elektrik şebekesini,
- trafo ve substations sistemini,
- bölgesel elektrik durumlarını,
- arızaları,
- sabotajları,
- bakım/tamir işlemlerini,
- blackout olaylarını,
- diğer scriptlerin elektrik bağımlılıklarını,
- görsel blackout deneyimini

merkezi olarak yönetecektir.

---

# 2. DEĞİŞTİRİLEMEZ ANA KURAL

Sistem iki temel domain'e ayrılır:

```text
CITY INFRASTRUCTURE
        │
        ├── LOGICAL POWER DOMAIN
        │
        │     ├── Electricity State
        │     ├── Grid
        │     ├── Substations
        │     ├── Transformers
        │     ├── Feeders
        │     ├── District Supply
        │     ├── Damage
        │     ├── Fault
        │     ├── Sabotage
        │     ├── Repair
        │     ├── Incidents
        │     └── External Integrations
        │
        └── VISUAL POWER DOMAIN
              ├── GTA Native Blackout
              ├── District Gating
              ├── Blackout Profiles
              ├── IPL
              ├── Interior Entity Sets
              ├── Overlays
              ├── Model Swaps
              ├── PTFX
              ├── Sound
              └── Custom Visual Adapters
```

**Logical Power Domain hiçbir zaman Visual Power Domain'e bağımlı olmayacaktır.**

Bir visual adapter hata verse bile:

```text
SANDY.powered = false
```

durumu değişmez.

ATM:

```text
OFFLINE
```

olmaya devam eder.

Kameralar:

```text
POWER LOST
```

durumunda kalır.

Map/visual sisteminin hata vermesi gameplay state'ini geri açamaz.

Bu, V2 mimarisinin korunacak en önemli prensibidir.

---

# 3. SERVER AUTHORITY

Elektrik şebekesinin tek otoritesi server'dır.

Client:

```text
POWER OFF
POWER ON
TRANSFORMER DAMAGED
INCIDENT CREATED
```

gibi kararları hiçbir zaman veremez.

Client yalnızca:

```text
interaction request
minigame result
visual application
zone/district detection
local effects
```

işlemlerini gerçekleştirir.

Temel prensip:

```text
SERVER = TRUTH

CLIENT = REPRESENTATION
```

---

# 4. YENİ COĞRAFİ MİMARİ

V2 içerisindeki temel değişiklik burada yapılacaktır.

Eski yaklaşım:

```text
Infrastructure Zone
=
Custom Polygon
```

olmamalıdır.

Yeni sistem üç farklı location resolver destekleyecektir:

```text
ZONE RESOLVER
│
├── GTA_NATIVE_DISTRICT
│
├── CUSTOM_POLYGON
│
└── CUSTOM_RADIUS
```

Default vanilla GTA/FiveM kurulumu:

```text
GTA_NATIVE_DISTRICT
```

olacaktır.

---

# 5. GTA NATIVE DISTRICT SYSTEM

GTA'nın kendi zone/district isimleri mümkün olduğunda kullanılacaktır.

Örnek:

```text
SANDY   = Sandy Shores
HARMO   = Harmony
GRAPES  = Grapeseed
PALETO  = Paleto Bay

DOWNT   = Downtown
SKID    = Mission Row
STRAW   = Strawberry
DAVIS   = Davis
RANCHO  = Rancho

VESP    = Vespucci
VCANA   = Vespucci Canals

VINE    = Vinewood
WVINE   = West Vinewood
DTVINE  = Downtown Vinewood
```

Client konum çözümlemesi konsept olarak:

```lua
local coords = GetEntityCoords(PlayerPedId())

local district = GetNameOfZone(
    coords.x,
    coords.y,
    coords.z
)
```

üzerinden yapılabilir.

Bu sistem sayesinde bütün Los Santos için manuel polygon çizmek zorunlu değildir.

---

# 6. ÖNEMLİ KAVRAM AYRIMI

Şunlar aynı şey değildir:

```text
GTA DISTRICT

INFRASTRUCTURE ZONE

POWER GRID

TRANSFORMER

SUBSTATION
```

Örneğin:

```text
Infrastructure Zone:
blaine_south_grid
```

şunları kapsayabilir:

```text
SANDY
HARMO
DESRT
```

Ve bu alanı:

```text
sandy_substation_01
```

besleyebilir.

Mimari:

```text
SUBSTATION
     │
     ▼
POWER GRID
     │
     ▼
INFRASTRUCTURE ZONE
     │
     ├── GTA DISTRICT: SANDY
     ├── GTA DISTRICT: HARMO
     └── GTA DISTRICT: DESRT
```

şeklinde olacaktır.

---

# 7. ÖRNEK SANDY GRID

```text
                   BLAINE SOUTH GRID
                          │
                 SANDY SUBSTATION
                          │
               ┌──────────┼──────────┐
               │          │          │
             SANDY      HARMO      DESRT
```

Substation devre dışı kaldığında:

```text
SANDY    OFF
HARMO    OFF
DESRT    OFF
```

olabilir.

Ama:

```text
GRAPES   ONLINE
PALETO   ONLINE
```

kalabilir.

Bu sistem gameplay açısından gerçek bir elektrik şebekesi hissi oluşturmalıdır.

---

# 8. CUSTOM ZONE DESTEĞİ KALDIRILMAYACAK

Native GTA district'leri her durumda yeterli değildir.

Örneğin:

- özel MLO,
- custom ada,
- custom şehir genişletmesi,
- askeri üs,
- hapishane kompleksi,
- özel yarış alanı,
- custom map,
- küçük tesis,
- fabrika

için custom zone gerekebilir.

Bu nedenle:

```lua
resolver = "gta_native"
```

yanında:

```lua
resolver = "polygon"
```

ve:

```lua
resolver = "radius"
```

desteklenmelidir.

---

# 9. RESOLVER PRIORITY

Bir position kontrol edildiğinde resolution sırası configurable olmalıdır.

Önerilen default:

```text
1. Explicit Custom Zone
2. GTA Native District
3. Default World Grid
```

Örneğin Sandy içerisinde custom hapishane MLO'su varsa:

```text
custom_prison_grid
```

SANDY district'inin üzerine override olabilir.

---

# 10. RESOURCE MİMARİSİ

```text
city_infrastructure/
│
├── fxmanifest.lua
├── config.lua
│
├── shared/
│   ├── constants.lua
│   ├── types.lua
│   ├── utilities.lua
│   ├── locales.lua
│   ├── districts.lua
│   ├── grids.lua
│   └── validators.lua
│
├── client/
│   ├── main.lua
│   ├── state.lua
│   ├── district_manager.lua
│   ├── zone_resolver.lua
│   ├── interactions.lua
│   ├── sabotage.lua
│   ├── repair.lua
│   ├── diagnostics.lua
│   └── debug.lua
│
├── client/visual/
│   ├── manager.lua
│   ├── ownership.lua
│   ├── transition.lua
│   ├── native_blackout.lua
│   ├── ipl.lua
│   ├── interior_sets.lua
│   ├── entity_overlay.lua
│   ├── model_swap.lua
│   ├── ptfx.lua
│   ├── sound.lua
│   └── custom.lua
│
├── server/
│   ├── main.lua
│   ├── grid_manager.lua
│   ├── power_calculator.lua
│   ├── transformer_manager.lua
│   ├── substation_manager.lua
│   ├── incident_manager.lua
│   ├── interaction_manager.lua
│   ├── sabotage.lua
│   ├── repair.lua
│   ├── scheduler.lua
│   ├── replication.lua
│   ├── persistence.lua
│   ├── security.lua
│   ├── api.lua
│   └── logging.lua
│
├── bridge/
│   ├── framework/
│   ├── inventory/
│   ├── target/
│   ├── dispatch/
│   ├── doorlock/
│   └── minigame/
│
├── profiles/
│   ├── sandy.lua
│   ├── downtown.lua
│   └── ...
│
├── stream/
│
├── database/
│   └── infrastructure.sql
│
├── tests/
│
└── README.md
```

---

# 11. GRID CONFIG

Conceptual örnek:

```lua
Config.Grids["blaine_south"] = {

    label = "Blaine South Power Grid",

    resolver = "gta_native",

    districts = {
        "SANDY",
        "HARMO",
        "DESRT"
    },

    substations = {
        "sandy_substation_01"
    },

    powerPolicy = {
        mode = "PRIMARY"
    },

    visual = {
        profile = "sandy_native"
    }
}
```

---

# 12. SUBSTATION VE TRANSFORMER AYRIMI

İleride gerçekçi topology kurulabilmesi için:

```text
SUBSTATION
```

ve:

```text
TRANSFORMER
```

aynı entity olarak görülmemelidir.

Örnek:

```text
SANDY SUBSTATION
      │
      ├── Transformer A
      ├── Transformer B
      └── Transformer C
```

MVP'de tek transformer tek substation gibi davranabilir.

Ancak data modeli ileriye dönük tasarlanmalıdır.

---

# 13. TRANSFORMER CONDITION VE STATE AYRIMI

V2'deki önemli değişikliklerden biri budur.

Transformer için iki farklı kavram bulunacaktır:

```text
OPERATIONAL STATE
```

ve:

```text
CONDITION
```

Operational state:

```text
ONLINE
DEGRADED
OFFLINE
REPAIRING
RECOVERING
COOLDOWN
```

Condition:

```text
HEALTHY
MINOR_DAMAGE
MODERATE_DAMAGE
MAJOR_DAMAGE
CRITICAL_DAMAGE
DESTROYED
```

Örneğin:

```lua
{
    state = "ONLINE",
    condition = "MODERATE_DAMAGE",
    damage = 38
}
```

geçerli bir durumdur.

Hasarlı trafo mutlaka elektrik kesmek zorunda değildir.

---

# 14. DAMAGE MODEL

```text
0-20
HEALTHY / MINOR

21-50
MODERATE

51-80
MAJOR

81-99
CRITICAL

100
DESTROYED
```

Damage şunları etkileyebilir:

- failure probability,
- output capacity,
- tamir süresi,
- gerekli item miktarı,
- minigame zorluğu,
- sparks/smoke yoğunluğu.

---

# 15. POWER POLICY

Bir grid birden fazla transformer tarafından besleniyorsa davranış config ile belirlenmelidir.

Desteklenebilecek modlar:

```text
PRIMARY
ANY
ALL
REQUIRED_COUNT
WEIGHTED_CAPACITY
PRIMARY_BACKUP
CUSTOM
```

Örneğin:

```lua
powerPolicy = {
    mode = "REQUIRED_COUNT",
    requiredOnline = 2
}
```

veya:

```lua
powerPolicy = {

    mode = "WEIGHTED_CAPACITY",

    minimumCapacity = 0.50,

    weights = {
        sandy_tr_01 = 0.60,
        sandy_tr_02 = 0.40
    }
}
```

Bu altyapı ileride partial blackout sistemine izin verir.

---

# 16. POWER LEVEL

Sistem sadece boolean olmak zorunda değildir.

Internal representation:

```text
0.00 - 1.00
```

olabilir.

Örneğin:

```text
1.00 = FULL POWER

0.60 = DEGRADED

0.25 = EMERGENCY / PARTIAL

0.00 = BLACKOUT
```

MVP dış sistem API'sinde başlangıçta:

```text
powered = true / false
```

sunulabilir.

---

# 17. INCIDENT SYSTEM

Her önemli blackout/failure bir incident oluşturur.

```text
incidentId
gridId
districts
substationId
transformerId
cause
severity
status
startedAt
startedBy
repairer
completedAt
metadata
```

Cause:

```text
SABOTAGE
RANDOM_FAILURE
ADMIN
SCRIPT
DEPENDENCY_FAILURE
OVERLOAD
UNKNOWN
```

Status:

```text
ACTIVE
ACKNOWLEDGED
REPAIRING
RECOVERING
RESOLVED
CANCELLED
```

---

# 18. SERVER BLACKOUT FLOW

```text
Sabotage / Failure
        ↓
Server Validation
        ↓
Incident Created
        ↓
Transformer Condition Changed
        ↓
Transformer Operational State Changed
        ↓
Grid Capacity Recalculated
        ↓
Affected Districts Calculated
        ↓
Power State Changed
        ↓
Persistence
        ↓
Replication
        ↓
External API Event
        ↓
Dispatch
        ↓
Clients React
```

Visual sistem server karar zincirinin içine sokulmaz.

---

# 19. STATE REPLICATION V3

Tek bir dev table:

```lua
GlobalState.InfrastructureGrid = {...}
```

tercih edilmemelidir.

Daha granular runtime state kullanılmalıdır.

Örneğin:

```lua
GlobalState["infra:grid:blaine_south"] = {
    powered = false,
    level = 0.0,
    status = "BLACKOUT",
    revision = 183
}
```

District:

```lua
GlobalState["infra:district:SANDY"] = {
    powered = false,
    revision = 183
}
```

State içerisinde:

- map asset listeleri,
- polygon verileri,
- transformer coordinates,
- büyük static configler

taşınmamalıdır.

Bunlar resource config içerisindedir.

---

# 20. REVISION SYSTEM

Her grid state değişiminde monotonik revision bulunmalıdır.

```text
revision = revision + 1
```

Client:

```text
eski revision
```

ile gelen event'i ignore edebilir.

Bu sistem:

- event ordering,
- reconnect,
- rapid blackout/recovery,
- stale update

problemlerini azaltır.

---

# 21. GTA NATIVE BLACKOUT GERÇEĞİ

Native blackout:

```lua
SetArtificialLightsState(true)
```

district-scoped bir native olarak kabul edilmeyecektir.

Bu client üzerinde geniş artificial lighting state'ini etkiler.

Dolayısıyla:

```text
SANDY LIGHTS ONLY OFF
```

garantisi verdiği varsayılmamalıdır.

Bu nedenle sistemde özel bir adapter oluşturulur:

```text
NATIVE_BLACKOUT_CLIENT_GATE
```

---

# 22. NATIVE BLACKOUT CLIENT GATE

Mantık:

```text
Client Current District
          ↓
Infrastructure Lookup
          ↓
District Powered?
          ↓
NO
          ↓
Local Native Blackout ON
```

Örneğin:

```text
Current District = SANDY
SANDY powered = false

→ SetArtificialLightsState(true)
```

Oyuncu Harmony'ye geçer:

```text
Current District = HARMO
HARMO powered = true

→ SetArtificialLightsState(false)
```

Bu sistem:

```text
DISTRICT-BASED CLIENT GATING
```

olarak adlandırılmalıdır.

**Gerçek district-scoped native lighting** olarak adlandırılmamalıdır.

---

# 23. SET_ZONE_ENABLED ARAŞTIRMA KURALI

`SET_ZONE_ENABLED` veya undocumented native'ler elektrik sisteminin core gereksinimi yapılmayacaktır.

PoC sırasında deneysel olarak test edilebilir.

Ancak:

```text
SET_ZONE_ENABLED
=
DISTRICT LIGHT CONTROL
```

şeklinde kanıtlanmamış varsayım yapılmayacaktır.

Bir mekanizma ancak:

```text
repeatable test
+
multiple clients
+
multiple game builds
+
restart test
```

sonrasında production adapter olabilir.

---

# 24. VISUAL MODES V3

Her grid kendi visual strategy'sini seçebilir.

```text
NONE
NATIVE_CLIENT_GATE
IPL
INTERIOR_ENTITY_SET
ENTITY_OVERLAY
MODEL_SWAP
HYBRID
CUSTOM
```

Örneğin Sandy:

```text
NATIVE_CLIENT_GATE
```

ile başlayabilir.

Downtown:

```text
HYBRID
```

kullanabilir.

---

# 25. SANDY MVP VISUAL PROFILE

İlk gerçek PoC:

```lua
return {

    mode = "NATIVE_CLIENT_GATE",

    districts = {
        "SANDY"
    },

    nativeBlackout = {
        enabled = true,
        affectVehicles = false
    },

    effects = {
        transformerSparks = true,
        transformerSmoke = true,
        transformerSound = true
    }
}
```

MVP'de custom map gerekli değildir.

Önce GTA native blackout görüntüsünün Sandy için yeterli olup olmadığı test edilir.

---

# 26. HYBRID VISUAL PROFILE

Native görüntü yeterli olmazsa:

```text
NATIVE BLACKOUT
       +
DARK OVERLAYS
       +
MODEL SWAPS
       +
CUSTOM MATERIALS
       +
PTFX
       +
SOUND
```

kullanılabilir.

Örneğin:

```text
Sandy motel sign
hala fazla parlak
```

ise bütün Sandy map yeniden yapılmaz.

Sadece:

```text
dark motel sign override
```

hazırlanır.

---

# 27. VISUAL OWNERSHIP MANAGER

V3'e yeni eklenen kritik modüldür.

Problem:

```text
Grid A → Asset X

Grid B → Asset X
```

Her ikisi blackout olabilir.

Grid A düzelince:

```text
Remove Asset X
```

yapılırsa Grid B bozulur.

Bu nedenle:

```lua
VisualOwnership["asset_x"] = {

    refCount = 2,

    owners = {
        grid_a = true,
        grid_b = true
    }
}
```

tutulacaktır.

Asset yalnızca:

```text
refCount == 0
```

olduğunda kaldırılır.

---

# 28. VISUAL ADAPTER CONTRACT

Her adapter şu contract'a uymalıdır:

```text
Apply()
Remove()
IsApplied()
ForceSync()
Reset()
```

Operation'lar idempotent olmalıdır.

```text
Apply()
Apply()
Apply()
```

aynı asset'i üç kez oluşturmamalıdır.

Aynı şekilde:

```text
Remove()
Remove()
```

safe olmalıdır.

---

# 29. DISTRICT BORDER HANDLING

Native district sınırlarında oyuncu kısa süre içinde:

```text
SANDY
HARMO
SANDY
HARMO
```

şeklinde flip-flop yapabilir.

Bu nedenle district manager:

```text
debounce
+
hysteresis
```

mantığı kullanmalıdır.

Örneğin:

```text
candidate district detected
↓
250-500 ms stable?
↓
YES
↓
district change committed
```

Ani araç hareketlerinde excessive blackout toggle yapılmamalıdır.

---

# 30. BLACKOUT TRANSITION

Blackout:

```text
ON → OFF
```

şeklinde anlık olmamalıdır.

Öneri:

```text
Transformer Explosion
        ↓
Electrical Arc
        ↓
First Flicker
        ↓
Temporary Recovery
        ↓
Second Flicker
        ↓
Lighting Failure
        ↓
Stable Blackout
```

Örnek:

```text
0.00  explosion
0.15  electrical arc
0.35  first flicker
0.55  lights return
0.75  second flicker
1.00  major shutdown
1.30  native blackout
1.60  stable blackout
```

Timing tamamen visual'dır.

Server logical state daha önce OFF olmuş olabilir.

---

# 31. RECOVERY TRANSITION

```text
REPAIR COMPLETE
      ↓
RECOVERING
      ↓
Transformer Hum
      ↓
Electrical Flicker
      ↓
Partial Lighting
      ↓
Native Blackout OFF
      ↓
Custom Layers Removed
      ↓
ONLINE
```

Gameplay power'ın ne zaman geri verileceği config ile belirlenebilir:

```text
START_RECOVERY
```

veya:

```text
END_RECOVERY
```

---

# 32. LATE JOIN / RECONNECT

Blackout 20 dakika önce başladıysa:

```text
Player joins
↓
Current State Received
↓
Current District Resolved
↓
BLACKOUT detected
↓
Final blackout visual applied
```

Patlama/flicker sequence tekrar oynatılmaz.

Aynı kural:

- reconnect,
- teleport,
- resource restart,
- routing bucket change

için uygulanmalıdır.

---

# 33. SABOTAGE METHODS

Desteklenebilir:

```text
THERMITE
C4
HACK
PHYSICAL_DAMAGE
CUSTOM
```

Client blackout başlatamaz.

---

# 34. SABOTAGE SECURITY FLOW

```text
Target Interaction
        ↓
requestSabotage
        ↓
Server Validation
        ↓
Interaction Session
        ↓
Client Animation / Minigame
        ↓
Result
        ↓
Server Session Validation
        ↓
Item Transaction
        ↓
Damage
        ↓
Incident
        ↓
Grid Recalculation
```

---

# 35. INTERACTION SESSION

Basit token yerine interaction session kullanılmalıdır.

```text
sessionId
nonce
player
action
targetId
stage
issuedAt
expiresAt
minCompletionTime
attempt
```

Session başka:

- oyuncuda,
- trafoda,
- işlemde,
- stage'de

kullanılamaz.

---

# 36. SERVER VALIDATION

Server en az şunları kontrol eder:

```text
Target exists?
Grid exists?
Transformer exists?

Valid operational state?

Player alive?
Player nearby?

Correct job/permission?

Required item exists?

Interaction lock available?

Session valid?

Session expired?

Correct stage?

Minimum completion time passed?

Cooldown active?

Rate limit exceeded?

Duplicate request?

State changed while interaction active?
```

Client minigame sonucu hiçbir zaman tek başına güvenilir kabul edilmez.

---

# 37. REPAIR SYSTEM

Repair aşamaları:

```text
DIAGNOSE
ISOLATE_POWER
OPEN_PANEL
REPLACE_COMPONENTS
REWIRE
INSTALL_FUSE
SYSTEM_TEST
RECONNECT_POWER
```

Damage seviyesine göre bazı aşamalar skip edilebilir.

---

# 38. PERSISTENT REPAIR PROGRESS

İsteğe bağlı olarak repair progress incident üzerinde tutulabilir.

Örneğin:

```text
DIAGNOSE             DONE
ISOLATE_POWER        DONE
REPLACE_COMPONENTS   DONE
REWIRE               PENDING
SYSTEM_TEST          PENDING
```

Elektrikçi disconnect olduğunda başka elektrikçi kaldığı yerden devam edebilir.

Config ile:

```text
PersistentRepairProgress = true / false
```

olmalıdır.

---

# 39. REPAIR REQUIREMENTS

Damage'a göre gerekli materyaller değişebilir.

Örneğin:

```text
MINOR
1x fuse

MODERATE
2x fuse
1x wiring kit

MAJOR
3x fuse
2x wiring
1x control module

CRITICAL
HV fuse
wiring
control module
transformer oil
specialized tools
```

Bunlar bridge üzerinden inventory sistemine bağlanır.

---

# 40. REPAIR LOCK

Bir transformer üzerinde aynı anda yalnızca izin verilen sayıda interaction bulunur.

Default:

```text
1
```

İleride cooperative repair için:

```text
maxWorkers = 2
```

gibi support eklenebilir.

Disconnect/death/timeout halinde lock temizlenmelidir.

---

# 41. RANDOM FAILURE

Scheduler event-driven ve düşük maliyetli çalışmalıdır.

Kontrol:

```text
AutoFault enabled?

Minimum players online?

Required workers online?

Existing incident?

Grid already offline?

Global blackout limit?

Transformer cooldown?

Grid cooldown?

Maintenance condition?

Failure probability?
```

---

# 42. CONDITION BASED FAILURE

Failure probability yalnızca random olmamalıdır.

Örneğin:

```text
Healthy transformer
0.1%

Damaged transformer
1%

Major damage
5%

Critical damage
15%
```

gibi config tabanlı probability kullanılabilir.

İleride:

```text
weather
load
maintenance age
```

gibi faktörler eklenebilir.

---

# 43. CONCURRENT BLACKOUT

```lua
Config.MaxConcurrentAutomaticBlackouts = 2
```

Random scheduler bu sınırı aşamaz.

Admin ve scripted incidents ayrı policy kullanabilir.

---

# 44. COOLDOWNS

Ayrı cooldown kategorileri:

```text
PLAYER
TRANSFORMER
SUBSTATION
GRID
SABOTAGE
RANDOM_FAILURE
```

olmalıdır.

---

# 45. PERSISTENCE

Minimum tablolar:

```text
infrastructure_transformers
infrastructure_incidents
```

İleride:

```text
infrastructure_substations
infrastructure_maintenance
```

eklenebilir.

Transformer:

```text
transformer_id
substation_id
state
condition
damage
last_failure
last_repair
updated_at
```

Incident:

```text
incident_id
grid_id
districts
substation_id
transformer_id
cause
severity
status
started_by
started_at
repaired_by
completed_at
metadata
```

---

# 46. DATABASE CONSISTENCY

Incident creation ve critical state transition mümkün olduğunca atomik olmalıdır.

Mantık:

```text
BEGIN

Create Incident

Update Transformer

Update Critical Grid Metadata

COMMIT
```

Her küçük visual/state değişiminde SQL write yapılmamalıdır.

Runtime cache kullanılmalıdır.

---

# 47. SERVER RESTART

Startup:

```text
Load Static Configuration
        ↓
Load Database
        ↓
Build Runtime Cache
        ↓
Restore Transformer States
        ↓
Restore Active Incidents
        ↓
Recalculate Grids
        ↓
Build District Power Cache
        ↓
Publish Replicated State
        ↓
Start Scheduler
```

Visual state DB'ye ayrıca kaydedilmez.

Visual state:

```text
logical power state
+
visual profile config
```

üzerinden yeniden oluşturulur.

---

# 48. EXTERNAL POWER API

Exports:

```text
IsGridPowered(gridId)

IsDistrictPowered(district)

IsPositionPowered(coords)

GetGridState(gridId)

GetDistrictState(district)

GetTransformerState(transformerId)

GetSubstationState(substationId)

GetActiveIncident(gridId)
```

---

# 49. EVENTS

Server/client integration eventleri:

```text
powerLost

powerRestored

powerLevelChanged

transformerDamaged

transformerOffline

transformerRepaired

incidentCreated

incidentResolved

gridRecovering
```

Event payloadları versioned ve documented olmalıdır.

---

# 50. POSITION POWER LOOKUP

```text
IsPositionPowered(coords)
```

şu resolver pipeline'ını kullanmalıdır:

```text
coords
↓
Explicit Custom Zone?
↓
YES → custom grid

NO
↓
GTA Native District
↓
district → grid lookup
↓
power state
```

Bu API diğer resource'ların coğrafya implementation'ını bilmesini engeller.

---

# 51. ATM INTEGRATION

```text
Player uses ATM
↓
IsPositionPowered(coords)
↓
false
↓
ATM unavailable
```

ATM scriptinin:

```text
SANDY
```

veya transformer isimlerini bilmesine gerek yoktur.

---

# 52. DOORLOCK

Kapı bazında:

```text
NO_CHANGE

FAIL_SAFE

FAIL_SECURE

UNLOCK

LOCK

BACKUP_POWER
```

davranışları support edilebilir.

Infrastructure yalnızca power state sağlar.

Doorlock resource son davranışı kendi config'ine göre seçebilir.

---

# 53. SECURITY / ALARM

Banka elektriği kesildi diye güvenlik sistemi otomatik olarak tamamen kapanmamalıdır.

Örneğin:

```text
Main Power Lost
↓
Backup Battery
↓
5 Minutes
↓
Battery Empty
↓
Security Power Lost
```

Infrastructure framework dış sisteme:

```text
main power lost
```

bilgisini verir.

Backup davranışı ilgili resource tarafından yönetilebilir.

---

# 54. BACKUP POWER FUTURE SUPPORT

Core data model ileride şunları destekleyebilecek şekilde tasarlanmalıdır:

```text
Generator
UPS
Emergency Circuit
Secondary Grid
Automatic Transfer Switch
```

MVP implementation zorunlu değildir.

---

# 55. FRAMEWORK BRIDGE

Core doğrudan:

```text
QBCore
ESX
Qbox
ox_core
```

API'lerini çağırmamalıdır.

Bridge:

```text
Bridge.GetPlayer()
Bridge.GetJob()
Bridge.Notify()
Bridge.HasItem()
Bridge.RemoveItem()
Bridge.AddItem()
Bridge.HasPermission()
```

interface sağlamalıdır.

---

# 56. INVENTORY / TARGET / DISPATCH BRIDGE

Aynı prensip:

```text
inventory
target
dispatch
doorlock
minigame
```

için geçerlidir.

Auto detection opsiyonel olabilir.

Ancak:

```text
manual override
```

her zaman bulunmalıdır.

---

# 57. ROUTING BUCKET POLICY

Default:

```text
power scope = GLOBAL WORLD
```

olacaktır.

Ancak API gelecekte:

```text
GLOBAL
ROUTING_BUCKET
CUSTOM_SCOPE
```

destekleyebilecek şekilde hazırlanmalıdır.

MVP'de bucket-specific blackout implementation zorunlu değildir.

---

# 58. PERFORMANCE PRENSİBİ

Normal durumda:

```text
0 blackout
```

iken:

```text
no PTFX
no sound
no model scanning
no constant server callbacks
no unnecessary SQL
no heavy per-frame polygon checks
```

olmalıdır.

Core sistem event-driven tasarlanmalıdır.

---

# 59. DISTRICT DETECTION PERFORMANCE

Player district kontrolü gerekli periyotta yapılabilir.

Örneğin:

```text
500 ms
```

veya movement-aware şekilde.

Her frame:

```text
GetNameOfZone()
```

çağırmak zorunlu değildir.

Critical transitionlar event/state change ile tetiklenmelidir.

---

# 60. VISUAL CACHE

Client:

```text
CurrentDistrict

CurrentGrid

CurrentPowerRevision

AppliedNativeBlackout

ActiveProfiles

ActiveAssets

ActiveModelSwaps

ActiveIPLs

ActiveInteriorSets

ActivePTFX

ActiveSounds
```

cache tutmalıdır.

---

# 61. CLEANUP

Her visual override reversible olmalıdır.

`onResourceStop` sırasında:

```text
Native blackout OFF

All custom overlays removed

Model swaps restored

IPLs restored

Interior sets restored

PTFX removed

Sounds stopped

Cache cleared
```

olmalıdır.

Oyuncu resource restart sonrası karanlık dünyada kalmamalıdır.

---

# 62. VISUAL FAILURE SAFETY

Örneğin:

```text
dark motel model
```

load edilemedi.

Sistem:

```text
VisualProfileFailed
```

loglar.

Ama:

```text
SANDY powered = false
```

değişmez.

Visual failure logical grid'i ONLINE yapamaz.

---

# 63. DEBUG COMMANDS

Minimum dev tools:

```text
/griddebug

/showdistrict

/showgrid

/showtransformers

/showincidents

/visualprofile

/reloadvisual

/powerdebug
```

---

# 64. GRID DEBUG OUTPUT

Örneğin:

```text
Current GTA District: SANDY

Infrastructure Grid:
blaine_south

Power:
OFF

Power Level:
0.00

Revision:
183

Substation:
sandy_substation_01

Transformer:
sandy_tr_01

Transformer State:
OFFLINE

Condition:
DESTROYED

Incident:
INC-000381

Visual Mode:
NATIVE_CLIENT_GATE

Native Blackout:
ACTIVE
```

---

# 65. LOGGING

Structured logs:

```text
INTERACTION_CREATED

SABOTAGE_STARTED
SABOTAGE_FAILED
SABOTAGE_SUCCESS

TRANSFORMER_DAMAGED
TRANSFORMER_OFFLINE

INCIDENT_CREATED

GRID_POWER_LOST

VISUAL_APPLIED
VISUAL_FAILED

REPAIR_STARTED
REPAIR_STAGE_COMPLETE
REPAIR_FAILED

GRID_RECOVERING
POWER_RESTORED
INCIDENT_RESOLVED
```

---

# 66. AGENT-AGNOSTIC IMPLEMENTATION RULES

Bu bölümü projeyi uygulayan bütün coding agentlar takip etmelidir.

## RULE 1

Mevcut repository okunmadan dosya oluşturulmamalıdır.

Önce:

```text
repository structure
existing conventions
dependencies
framework
config
database
```

incelenmelidir.

## RULE 2

Büyük dosyalar tek seferde yeniden yazılmamalıdır.

Minimum scoped değişiklikler tercih edilmelidir.

## RULE 3

Her phase bağımsız test edilebilir durumda bırakılmalıdır.

## RULE 4

Bir native'in davranışı doğrulanmamışsa varsayım yapılmamalıdır.

Özellikle:

```text
SET_ZONE_ENABLED
```

gibi undocumented/poorly documented davranışlar production dependency yapılmamalıdır.

## RULE 5

Client hiçbir gameplay state'in otoritesi olamaz.

## RULE 6

Her network event server validation'dan geçmelidir.

## RULE 7

Config ile değiştirilebilecek değerler hardcode edilmemelidir.

## RULE 8

Core framework-specific kod içermemelidir.

## RULE 9

Yeni feature mevcut public API'yi kırmamalıdır.

Gerekirse migration/deprecation yolu oluşturulmalıdır.

## RULE 10

Her work package sonunda:

```text
implementation
+
tests
+
failure cases
+
cleanup
+
documentation
```

kontrol edilmelidir.

---

# 67. AGENT WORK PACKAGE FORMAT

Her geliştirme görevi şu formatta ele alınmalıdır:

```text
WORK PACKAGE

Goal:
...

Affected Modules:
...

Dependencies:
...

Implementation:
...

Security Considerations:
...

Edge Cases:
...

Tests:
...

Acceptance Criteria:
...
```

Agent doğrudan tüm projeyi aynı anda üretmeye çalışmamalıdır.

---

# 68. PHASE 1 — CORE FOUNDATION

Yapılacak:

```text
resource architecture

shared constants

types

config validation

logging

basic bridges
```

Başarı kriteri:

```text
resource clean start

resource clean stop

no framework hard dependency
```

---

# 69. PHASE 2 — GTA DISTRICT MANAGER

Implement:

```text
GetNameOfZone resolution

district cache

district labels

district change detection

debounce/hysteresis
```

Test:

```text
Sandy
Harmony
Grapeseed
Downtown
Vespucci

walking
vehicle
teleport
high speed
```

---

# 70. PHASE 3 — HYBRID ZONE RESOLVER

Implement:

```text
GTA_NATIVE

CUSTOM_POLYGON

CUSTOM_RADIUS

resolver priority
```

Test overlapping zones.

---

# 71. PHASE 4 — GRID TOPOLOGY

Implement:

```text
Grid Manager

Substation definitions

Transformer definitions

District assignments

Grid lookup
```

---

# 72. PHASE 5 — TRANSFORMER MODEL

Implement:

```text
Operational State

Condition

Damage

State transitions
```

State validation kesin olmalıdır.

---

# 73. PHASE 6 — POWER CALCULATOR

Implement:

```text
PRIMARY

ANY

ALL

REQUIRED_COUNT
```

Önce bu dört policy yeterlidir.

`WEIGHTED_CAPACITY` sonraki iteration olabilir.

---

# 74. PHASE 7 — STATE REPLICATION

Implement:

```text
granular GlobalState keys

revision

change handlers

late join state
```

Test:

```text
rapid changes

reconnect

resource restart
```

---

# 75. PHASE 8 — SANDY NATIVE BLACKOUT POC

Bu proje için en kritik erken PoC budur.

Sadece:

```text
SANDY
```

kullanılır.

Scenario:

```text
SANDY ONLINE
↓
debug command
↓
SANDY OFF
↓
player in Sandy
↓
native blackout
↓
leave Sandy
↓
native blackout removed
↓
return Sandy
↓
blackout restored
↓
SANDY ONLINE
↓
visual restored
```

---

# 76. PHASE 9 — DISTRICT BORDER TEST

Özellikle:

```text
SANDY ↔ DESRT

SANDY ↔ ALAMO

SANDY ↔ HARMO
```

sınırlarında test yapılmalıdır.

Kontrol:

```text
flicker?

rapid toggle?

distant lights?

transition quality?

vehicle lights?

```

Bu PoC sonucuna göre native client gate'in production kalitesi değerlendirilir.

---

# 77. PHASE 10 — NATIVE EXPERIMENT LAB

Production core'dan ayrı test resource hazırlanabilir.

Burada:

```text
SET_ZONE_ENABLED

unknown zone natives

lighting behavior
```

test edilir.

Bir yöntem gerçekten district lighting'i değiştirebiliyorsa:

```text
multiple clients
day/night
weather
restart
different builds
```

ile doğrulanmalıdır.

Başarılı olursa yeni visual adapter olarak eklenebilir.

Başarısız olması core development'ı durdurmamalıdır.

---

# 78. PHASE 11 — INCIDENT SYSTEM

Incident lifecycle uygulanır.

Test:

```text
create
update
resolve
restart restore
```

---

# 79. PHASE 12 — SABOTAGE

Implement:

```text
target

interaction session

items

animation

minigame

validation

damage

incident

blackout
```

---

# 80. PHASE 13 — REPAIR

Implement:

```text
diagnose

stages

materials

locks

recovery

power restore
```

---

# 81. PHASE 14 — PERSISTENCE

Implement:

```text
SQL schema

runtime cache

incident persistence

transformer persistence

restart recovery
```

---

# 82. PHASE 15 — TRANSITION ENGINE

Implement:

```text
blackout flicker

shutdown

recovery sequence

cancel transition

force sync
```

---

# 83. PHASE 16 — VISUAL OWNERSHIP

Implement:

```text
asset ownership

reference counting

safe apply/remove

reset
```

Bu yapılmadan büyük hybrid visual expansion yapılmamalıdır.

---

# PHASE 16.5 — CITYWIDE MIGRATION & COMPATIBILITY AUDIT

Bu phase mevcut Phase 1–16 implementation'ını yeniden yazmak için değildir.

Amaç:

```text
MEVCUT SANDY POC TABANLI IMPLEMENTATION
                ↓
GENERIC CITYWIDE INFRASTRUCTURE CORE
```

geçişini güvenli şekilde yapmaktır.

## 16.5.1 — MEVCUT IMPLEMENTATION AUDIT

Agent öncelikle repository içerisinde aşağıdakileri kontrol etmelidir:

```text
SANDY hardcode edilmiş mi?

blaine_south hardcode edilmiş mi?

Tek grid varsayımı var mı?

Tek transformer varsayımı var mı?

Tek substation varsayımı var mı?

VisualManager sadece Sandy için mi çalışıyor?

Native blackout sadece Sandy eventlerinden mi tetikleniyor?

Replication dinamik district key destekliyor mu?

DistrictManager herhangi bir GTA district'i kabul ediyor mu?

GridManager birden fazla grid aynı anda yönetebiliyor mu?
```

Özellikle aşağıdaki gibi fonksiyonlar aranmalıdır:

```lua
ApplySandyBlackout()

RemoveSandyBlackout()

SetSandyPower()

GetSandyGrid()
```

Bunlar core içerisinde mevcutsa generic interface'e dönüştürülmelidir.

Örneğin:

```lua
ApplyDistrictVisual(districtId)

SetGridPower(gridId, state)

GetGridState(gridId)

GetDistrictState(districtId)
```

---

## 16.5.2 — CORE REWRITE YAPILMAMALI

Phase 1–16 içerisinde çalışan:

```text
DistrictManager
ZoneResolver
GridManager
PowerCalculator
TransformerManager
SubstationManager
Replication
TransitionManager
VisualManager
VisualOwnershipManager
IncidentManager
```

gereksiz yere yeniden yazılmamalıdır.

Amaç:

```text
REWRITE
```

değil:

```text
GENERALIZE
+
MIGRATE
+
EXTEND
```

olmalıdır.

---

## 16.5.3 — CONFIG-DRIVEN ZORUNLULUĞU

Şu ilişkiler kod içerisinde hardcode edilmemelidir:

```text
district → grid

grid → substation

substation → feeder

feeder → transformer

transformer → affected districts
```

Bunların tamamı static topology/config üzerinden çözümlenmelidir.

---

## 16.5.4 — MIGRATION ACCEPTANCE CRITERIA

Phase 16.5 tamamlandığında:

```text
✓ Sandy mevcut şekilde çalışmaya devam etmeli

✓ Core içerisinde Sandy-specific gameplay logic kalmamalı

✓ Birden fazla grid oluşturulabilmeli

✓ Birden fazla district eş zamanlı state taşıyabilmeli

✓ VisualManager district/grid parametreli çalışmalı

✓ Replication dinamik district/grid ID desteklemeli

✓ Existing persistence bozulmamalı

✓ Existing Phase 1-16 testleri geçmeli
```

Bu phase tamamlanmadan citywide topology oluşturulmamalıdır.

---

# PHASE 17 — COMPLETE GTA DISTRICT REGISTRY

Artık yalnızca örnek district'ler değil, desteklenen GTA/FiveM world district'lerinin tamamı merkezi registry içerisinde tanımlanacaktır.

Dosya:

```text
shared/districts.lua
```

## DISTRICT MODEL

Her district minimum:

```text
id
label
enabled
category
resolver
defaultGrid
visualProfile
metadata
```

bilgilerini taşımalıdır.

Conceptual:

```lua
Districts["SANDY"] = {
    id = "SANDY",
    label = "Sandy Shores",
    enabled = true,
    resolver = "gta_native",
    category = "blaine_county"
}
```

---

## 17.1 — FULL REGISTRY

Amaç yalnızca:

```text
SANDY
DOWNT
VESP
VINE
```

gibi birkaç örnek eklemek değildir.

Playable world içerisinde infrastructure sistemi tarafından desteklenmesi beklenen **tüm native GTA district kodları** registry'e alınmalıdır.

Bir district:

```text
recognized
```

ama henüz fiziksel grid'e bağlanmamışsa bile açık şekilde:

```text
UNASSIGNED
```

olarak işaretlenmelidir.

Sessiz fallback yapılmamalıdır.

---

## 17.2 — REGISTRY VALIDATION

Startup sırasında kontrol:

```text
duplicate district?

invalid ID?

missing label?

missing resolver?

missing grid mapping?

disabled district?
```

yapılmalıdır.

Development mode içerisinde:

```text
[Infrastructure]
WARNING:
District X has no power topology assignment.
```

gibi warning üretilebilir.

---

## 17.3 — ACCEPTANCE

```text
✓ Native GTA district registry citywide çalışıyor

✓ GetNameOfZone sonucu registry ile resolve ediliyor

✓ Unknown district crash üretmiyor

✓ Unassigned district açıkça tespit ediliyor

✓ Sandy dahil mevcut districtler bozulmuyor
```

---

# PHASE 18 — CITYWIDE POWER TOPOLOGY

Bu phase projenin şehir çapına geçtiği ana phase'dir.

Power topology:

```text
REGION / GRID
      │
      ▼
SUBSTATION
      │
      ▼
FEEDER
      │
      ▼
TRANSFORMER
      │
      ▼
DISTRICT
```

mantığını desteklemelidir.

---

# 18.1 — MAJOR POWER REGIONS

Şehir tek grid olarak tasarlanmamalıdır.

Conceptual başlangıç:

```text
LOS SANTOS CENTRAL

LOS SANTOS SOUTH

LOS SANTOS WEST

LOS SANTOS NORTH

LOS SANTOS EAST / INDUSTRIAL

BLAINE SOUTH

BLAINE NORTH
```

Bu isimler config-level topology gruplarıdır.

Kesin district dağılımı map/gameplay tasarımına göre belirlenmelidir.

---

# 18.2 — ÖRNEK TOPOLOGY

```text
                     LOS SANTOS POWER NETWORK

                              │
         ┌────────────────────┼─────────────────────┐
         │                    │                     │
   CENTRAL GRID          WEST GRID             SOUTH GRID
         │                    │                     │
    SUBSTATION             SUBSTATION            SUBSTATION
         │                    │                     │
      FEEDERS               FEEDERS               FEEDERS
         │                    │                     │
   ┌─────┼─────┐        ┌─────┼─────┐         ┌─────┼─────┐
   │     │     │        │     │     │         │     │     │
DIST  DIST   DIST     DIST   DIST   DIST      DIST  DIST  DIST
```

Blaine County aynı sistem içerisinde ayrı power region'lar kullanabilir.

---

# 18.3 — FEEDER LAYER

Phase 1–16 içerisinde feeder manager oluşturulmadıysa bu phase'de eklenmelidir.

Yeni modüller:

```text
shared/feeders.lua

server/feeder_manager.lua
```

Feeder:

```text
feederId
substationId
transformers
districts
priority
state
capacity
```

taşıyabilir.

Feeder sayesinde:

```text
tek transformer failure
```

ile:

```text
substation failure
```

aynı büyüklükte olay olmak zorunda değildir.

---

# 18.4 — FAILURE SCOPE

Infrastructure failure scope desteklemelidir:

```text
LOCAL_TRANSFORMER

FEEDER

SUBSTATION

GRID
```

Örneğin:

```text
LOCAL TRANSFORMER 💥
        ↓
1 district etkilenebilir
```

```text
FEEDER 💥
        ↓
birkaç district etkilenebilir
```

```text
SUBSTATION 💥
        ↓
büyük district grubu etkilenebilir
```

```text
GRID FAILURE
        ↓
bütün region etkilenebilir
```

---

# 18.5 — TOPOLOGY VALIDATOR

Startup sırasında:

```text
District exists?

Grid exists?

Substation exists?

Feeder exists?

Transformer exists?

Duplicate district ownership?

Missing power source?

Invalid parent?

Circular topology?
```

kontrol edilmelidir.

Production'da invalid topology mümkün olduğunca fail-fast davranmalıdır.

---

# 18.6 — DISTRICT ASSIGNMENT RULE

Her normal district minimum bir:

```text
PRIMARY POWER SOURCE
```

taşımalıdır.

İleride:

```text
SECONDARY SOURCE
BACKUP SOURCE
```

desteklenebilir.

---

# 18.7 — ACCEPTANCE

```text
✓ Şehrin tüm desteklenen districtleri topology'ye bağlı

✓ Birden fazla grid aynı anda çalışıyor

✓ Bir substation birden fazla feeder besleyebiliyor

✓ Feeder birden fazla district besleyebiliyor

✓ District power state topology üzerinden hesaplanıyor

✓ Sandy artık özel durum değil

✓ Citywide state startup'ta build ediliyor
```

---

# PHASE 19 — CITYWIDE DISTRICT BLACKOUT CONTROLLER

Eski Sandy-specific native blackout PoC artık generic citywide visual controller'a dönüştürülür.

Client:

```text
Current GTA District
        ↓
District Registry
        ↓
District Power State
        ↓
Visual Strategy
        ↓
Apply / Remove
```

---

# 19.1 — GENERIC NATIVE CLIENT GATE

Sistem:

```lua
if not districtState.powered then
    ApplyNativeBlackout()
else
    RemoveNativeBlackout()
end
```

mantığının generic versiyonunu kullanmalıdır.

Core içerisinde:

```text
if district == "SANDY"
```

şeklinde special-case bulunmamalıdır.

---

# 19.2 — CURRENT DISTRICT STATE

Client cache:

```text
CurrentDistrict

CurrentGrid

CurrentFeeder

CurrentPowerState

CurrentPowerRevision

CurrentVisualProfile
```

tutmalıdır.

---

# 19.3 — MULTIPLE BLACKOUT SUPPORT

Aynı anda:

```text
DOWNT = OFF
VESP  = OFF
SANDY = ON
VINE  = OFF
DAVIS = ON
```

gibi durumlar tamamen geçerli olmalıdır.

Her client yalnızca bulunduğu location'ın geçerli visual state'ini uygular.

---

# 19.4 — NATIVE BLACKOUT SINIRLAMASI

Native artificial-light blackout gerçek spatial district maskesi değildir.

Bu limitation kaldırılmış gibi davranılmamalıdır.

Player blackout district içerisindeyken native blackout client üzerinde geniş lighting state'i etkileyebilir.

Bu nedenle:

```text
DISTRICT POWER STATE
```

ile:

```text
NATIVE VISUAL REPRESENTATION
```

aynı şey değildir.

Logical power state her durumda kesin source of truth'tur.

---

# PHASE 20 — CITYWIDE DISTRICT TRANSITION ENGINE

Artık transition yalnızca Sandy border için değil bütün map için generic olmalıdır.

Player:

```text
POWERED DISTRICT
      ↓
BLACKOUT DISTRICT
```

veya:

```text
BLACKOUT DISTRICT
      ↓
POWERED DISTRICT
```

geçişlerinde transition manager doğru final state'i sağlamalıdır.

---

# 20.1 — BORDER HYSTERESIS

Bütün native district sınırlarında:

```text
candidate district
        ↓
stable interval
        ↓
commit
```

kullanılmalıdır.

---

# 20.2 — RAPID TRAVEL

Test:

```text
high-speed car

motorcycle

aircraft

teleport

admin noclip

spawn relocation
```

ile yapılmalıdır.

Client eski district visual state'inde takılı kalmamalıdır.

---

# 20.3 — TRANSITION CANCELLATION

Örnek:

```text
Blackout transition başladı
        ↓
player district değiştirdi
        ↓
transition cancel
        ↓
new district final state
```

uygulanmalıdır.

Eski async transition yeni state'i sonradan override edememelidir.

---

# PHASE 21 — CITYWIDE FAILURE PROPAGATION

Bu phase fiziksel altyapı state'inin district'lere doğru propagation'ını tamamlar.

Örneğin:

```text
Transformer
    ↓
Feeder
    ↓
District
```

ve:

```text
Substation
    ↓
Multiple Feeders
    ↓
Multiple Districts
```

hesaplanmalıdır.

---

# 21.1 — LOCAL TRANSFORMER FAILURE

```text
Transformer X OFFLINE
       ↓
Feeder capacity recalculated
       ↓
Affected district recalculated
```

Diğer feeder'lar gereksiz yere etkilenmemelidir.

---

# 21.2 — FEEDER FAILURE

```text
Feeder B OFFLINE
       ↓
All districts supplied exclusively by Feeder B
       ↓
BLACKOUT
```

---

# 21.3 — SUBSTATION FAILURE

```text
Substation OFFLINE
       ↓
All child feeders affected
       ↓
All dependent districts recalculated
```

---

# 21.4 — GRID FAILURE

Admin veya scripted large-scale incident için:

```text
GRID OFFLINE
```

tüm child topology'yi etkileyebilir.

---

# PHASE 22 — CITYWIDE TRANSFORMER / SUBSTATION WORLD PLACEMENT

Artık fiziksel interaction noktaları bütün sistem için hazırlanacaktır.

Her entity:

```text
logicalId
type
gridId
substationId
feederId
coords
heading
model
interactionRadius
visualRadius
enabled
```

taşımalıdır.

---

# 22.1 — PERMANENT ID

Entity Network ID kalıcı kimlik olarak kullanılmamalıdır.

Örnek:

```text
ls_central_sub_01

ls_central_feed_a

ls_central_tr_01

blaine_south_tr_03
```

gibi logical ID kullanılmalıdır.

---

# 22.2 — WORLD VALIDATION

Her configured infrastructure point için dev validation:

```text
coordinates valid?

expected model nearby?

interaction accessible?

inside intended region?

duplicate ID?

duplicate coordinates?

correct feeder?

correct grid?
```

yapılmalıdır.

---

# 22.3 — MAP AUTHORING TOOLING

Debug araçları:

```text
/showinfrastructure

/showfeeders

/showsubstations

/showtransformers

/showdistrictpower
```

ile world placement doğrulanabilmelidir.

---

# PHASE 23 — CITYWIDE INCIDENT & DISPATCH EXPANSION

Incident sistemi topology seviyesini anlayacaktır.

Incident artık:

```text
targetType
targetId
gridId
substationId
feederId
transformerId
affectedDistricts
estimatedImpact
```

gibi metadata taşıyabilir.

---

# 23.1 — IMPACT CALCULATION

Incident oluşturulduğunda sistem:

```text
1 transformer affected

3 districts affected

5 districts affected

whole grid affected
```

gibi impact çıkarabilmelidir.

---

# 23.2 — DISPATCH INFORMATION

Elektrikçi dispatch'i:

```text
Incident ID

Failure Type

Infrastructure Target

Approximate Location

Affected District Count

Severity
```

bilgisi içerebilir.

---

# PHASE 24 — CITYWIDE EXTERNAL POWER API

External API artık tüm şehir topology'sini desteklemelidir.

Exports:

```text
IsPositionPowered(coords)

IsDistrictPowered(districtId)

IsGridPowered(gridId)

IsFeederPowered(feederId)

IsSubstationPowered(substationId)

GetDistrictState(districtId)

GetGridState(gridId)

GetFeederState(feederId)

GetTransformerState(transformerId)

GetInfrastructureAtPosition(coords)

GetPowerPathForDistrict(districtId)

GetAffectedDistricts(targetType, targetId)

GetActiveIncidents()
```

---

# 24.1 — POWER PATH API

Özellikle debug/integration için:

```text
GetPowerPathForDistrict("SANDY")
```

conceptual olarak:

```text
BLAINE SOUTH GRID
        ↓
SANDY SUBSTATION
        ↓
FEEDER A
        ↓
SANDY TRANSFORMER
        ↓
SANDY
```

döndürebilir.

---

# 24.2 — OTHER RESOURCE ABSTRACTION

ATM scripti:

```text
hangi grid?
hangi feeder?
hangi transformer?
```

bilmemelidir.

Sadece:

```lua
IsPositionPowered(coords)
```

kullanmalıdır.

---

# PHASE 25 — CITYWIDE RANDOM FAILURE SYSTEM

Random failure artık tek grid üzerinde değil tüm topology üzerinde çalışacaktır.

Candidate selection:

```text
Transformer

Feeder

Substation
```

seviyesinde yapılabilir.

Default automatic incidents mümkün olduğunca transformer seviyesinde olmalıdır.

Büyük substation/grid failure olayları daha nadir veya admin/script controlled olabilir.

---

# 25.1 — FAILURE WEIGHT

Probability:

```text
condition

damage

last maintenance

recent incidents

grid importance

online worker count

concurrent blackout count
```

ile ağırlıklandırılabilir.

---

# 25.2 — IMPACT AWARE SCHEDULER

Scheduler bir incident oluşturmadan önce:

```text
kaç district etkilenecek?

kaç oyuncu etkilenecek?

başka aktif blackout var mı?

critical region zaten offline mı?
```

değerlendirebilir.

---

# 25.3 — BLACKOUT LIMIT

Sadece:

```text
incident count
```

değil:

```text
affected district count
```

için de optional limit bulunabilir.

Örneğin:

```lua
MaxAutomaticOfflineDistricts = 6
```

---

# PHASE 26 — CITYWIDE SECURITY HARDENING

Phase 20'de planlanan security testing şehir topology'sine göre genişletilir.

Test:

```text
fake district

fake grid

fake feeder

fake substation

fake transformer

cross-grid interaction

wrong target ID

fake session

fake nonce

wrong stage

distance exploit

event spam

duplicate success

stale revision

invalid power target

unauthorized admin event

race condition
```

---

# 26.1 — TRUST BOUNDARY

Client hiçbir zaman:

```text
affectedDistricts
damage
powerState
gridState
```

belirleyemez.

Client:

```text
target ID
interaction input
minigame result
```

gibi minimum gerekli bilgiyi gönderir.

Affected topology server tarafından hesaplanır.

---

# PHASE 27 — MULTI-GRID & SCALE TESTING

Bu phase eski scale testing'in genişletilmiş sürümüdür.

Test:

```text
32 players
64 players
128 players
```

---

## SCENARIO A

```text
0 blackout
```

Baseline idle performance.

---

## SCENARIO B

```text
1 transformer blackout
1 district affected
```

---

## SCENARIO C

```text
1 feeder blackout
3-5 districts affected
```

---

## SCENARIO D

```text
2 independent grids blackout
```

---

## SCENARIO E

```text
multiple adjacent districts blackout
```

---

## SCENARIO F

```text
substation blackout
large district group
```

---

## SCENARIO G

```text
rapid repair + sabotage
```

---

# 27.1 — PERFORMANCE METRICS

Ölçülmesi gerekenler:

```text
client frame time

server tick impact

StateBag traffic

network event rate

database writes

district resolver frequency

visual apply/remove count

PTFX entity count

memory growth

cleanup correctness
```

---

# PHASE 28 — CITYWIDE VISUAL QUALITY PASS

Native client gate mekanizması bütün bölgelerde tek başına yeterli olmayabilir.

Bu phase gameplay için zorunlu değildir.

Ama görsel kalite için district-specific profile eklenebilir.

Örneğin:

```text
Downtown
→ Hybrid

Vespucci
→ Native + selected neon overrides

Sandy
→ Native

Industrial
→ Native + industrial light overrides
```

---

# 28.1 — VISUAL PROFILE REGISTRY

```lua
VisualProfiles["downtown"] = {
    mode = "HYBRID"
}

VisualProfiles["sandy"] = {
    mode = "NATIVE_CLIENT_GATE"
}
```

District veya grid profile seçebilir.

---

# 28.2 — FULL MAP DUPLICATE YASAK

Yine:

```text
normal_city.ymap

blackout_city.ymap
```

şeklinde bütün world duplicate edilmemelidir.

Tercih:

```text
CURRENT MAP
+
TARGETED BLACKOUT OVERRIDES
```

olmalıdır.

---

# 28.3 — PRIORITY DISTRICTS

Visual enhancement gameplay ihtiyacına göre yapılmalıdır.

Örneğin öncelik:

```text
high player density

robbery locations

nightlife areas

major RP hubs

important MLO areas
```

olabilir.

Bütün district'ler için custom asset üretmek zorunlu değildir.

---

# PHASE 29 — CITYWIDE RECOVERY & CASCADE TESTS

Elektrik şebekesinde yalnızca blackout değil recovery propagation da test edilmelidir.

Örneğin:

```text
Substation repaired
       ↓
Feeders recovering
       ↓
Transformer states recalculated
       ↓
District states restored
```

---

# 29.1 — PARTIAL RECOVERY

Aynı substation altındaki bütün district'ler aynı anda dönmek zorunda değildir.

Örneğin:

```text
Feeder A ONLINE
Feeder B OFFLINE
Feeder C ONLINE
```

ise:

```text
District A 🟢
District B 🔴
District C 🟢
```

olabilir.

---

# 29.2 — CASCADE SAFETY

Bir child component ONLINE olduğunda parent OFFLINE ise district yanlışlıkla power almamalıdır.

Örneğin:

```text
Transformer ONLINE

BUT

Substation OFFLINE

=

DISTRICT OFFLINE
```

olmalıdır.

---

# PHASE 30 — CITYWIDE ADMIN & OPERATIONS TOOLS

Admin/dev araçları artık tüm city infrastructure topology'sini yönetebilmelidir.

Commands veya admin UI üzerinden:

```text
grid status

district status

substation status

feeder status

transformer status

active incidents
```

görülebilmelidir.

---

# 30.1 — ADMIN ACTIONS

Permission protected:

```text
Force Transformer Failure

Force Feeder Failure

Force Substation Failure

Force Grid Blackout

Restore Target

Create Incident

Resolve Incident

Reload Topology

Force Client Visual Resync
```

---

# 30.2 — DANGEROUS COMMAND SAFETY

Admin komutları target type + target ID açık şekilde istemelidir.

Örneğin:

```text
/gridpower ls_central off
```

veya:

```text
/transformerstate ls_central_tr_01 offline
```

Implicit nearest-target gibi riskli production admin davranışlarından kaçınılmalıdır.

---

# PHASE 31 — FULL RESTART / RESYNC TEST

Test:

```text
server restart while city fully online

server restart during transformer blackout

server restart during feeder blackout

server restart during substation blackout

resource restart

visual resource restart

player reconnect

multiple players reconnect

late join into blackout district
```

---

# 31.1 — EXPECTED RESULT

Her restart sonrasında:

```text
DB state
      ↓
topology rebuild
      ↓
grid calculation
      ↓
district states
      ↓
replication
      ↓
client visual sync
```

deterministic olmalıdır.

---

# PHASE 32 — FINAL CITYWIDE INTEGRATION TEST

Artık tüm sistem tek bütün olarak test edilir.

Scenario:

```text
Player enters Downtown

Downtown powered
        ↓
ATM works
        ↓
local transformer sabotaged
        ↓
incident
        ↓
affected feeder recalculated
        ↓
Downtown district loses power
        ↓
visual blackout
        ↓
ATM unavailable
        ↓
CCTV affected
        ↓
dispatch
        ↓
technician repairs
        ↓
recovery
        ↓
Downtown restored
```

Aynı test:

```text
Vespucci

Vinewood

South LS

Industrial

Sandy

Grapeseed

Paleto

other configured districts
```

üzerinde topology'ye göre çalışmalıdır.

---

# PHASE 33 — FINAL PRODUCTION HARDENING

Production release öncesinde:

```text
debug spam removed

dev commands permission protected

config validation enabled

SQL migrations verified

event names documented

exports documented

error handling verified

cleanup verified

rate limits verified

bridge failures handled

missing dependency behavior tested
```

olmalıdır.

---

# PHASE 34 — DOCUMENTATION & INTEGRATION GUIDE

README yalnız kurulum anlatmamalıdır.

Şunları açıklamalıdır:

```text
Architecture

District Registry

Grid Topology

Substations

Feeders

Transformers

How Power Is Calculated

How to Add a District

How to Add a Grid

How to Add a Substation

How to Add a Feeder

How to Add a Transformer

Visual Profiles

Exports

Events

Framework Bridges

Security Model

Persistence

Debugging

Troubleshooting
```

---

# PHASE 35 — FINAL RELEASE ACCEPTANCE

Sistem production-ready sayılmadan önce aşağıdaki kriterler sağlanmalıdır.

## GEOGRAPHY

```text
✓ Supported GTA districts registry'de

✓ District → topology mapping mevcut

✓ No unintended unassigned district
```

## POWER

```text
✓ Multi-grid

✓ Multi-substation

✓ Multi-feeder

✓ Multi-transformer

✓ Multi-district
```

## FAILURE

```text
✓ Transformer failure

✓ Feeder failure

✓ Substation failure

✓ Grid failure
```

## RECOVERY

```text
✓ Transformer recovery

✓ Partial feeder recovery

✓ Substation recovery

✓ Full grid recovery
```

## MULTIPLAYER

```text
✓ Multiple clients

✓ Different districts

✓ Simultaneous blackouts

✓ Late join

✓ Reconnect

✓ Teleport

✓ High-speed district crossing
```

## SECURITY

```text
✓ Server authority

✓ Session validation

✓ Distance validation

✓ Rate limiting

✓ No client-defined topology impact
```

## PERSISTENCE

```text
✓ Active incident restore

✓ Transformer state restore

✓ Grid recalculation

✓ District state restore
```

## VISUAL

```text
✓ Apply

✓ Remove

✓ Transition cancel

✓ Resource cleanup

✓ No permanently stuck blackout
```

---

# UPDATED CITYWIDE V1 TARGET

Eski:

```text
1 grid
Sandy Shores
1 transformer
```

MVP tanımı artık kullanılmamalıdır.

Yeni hedef:

```text
CITYWIDE FUNCTIONAL V1
```

olacaktır.

Minimum:

```text
All supported native GTA districts registered

All active districts assigned to power topology

Multiple power grids

Multiple substations

Feeder topology

Multiple transformers

District-based logical power state

Citywide native blackout client gate

Multi-district blackout

Transformer sabotage

Substation/feeder propagation

Repair

Incident management

Persistence

Granular state replication

External power API

Debug/admin tooling

Security validation
```

Custom blackout map assetleri Citywide V1 için zorunlu değildir.

---

# UPDATED DEVELOPMENT STRATEGY

Eski yaklaşım:

```text
Sandy yap
↓
Sandy tamamla
↓
Downtown yap
↓
Vespucci yap
↓
şehir genişlet
```

kullanılmayacaktır.

Yeni yaklaşım:

```text
Phase 1-16 Core
        ↓
Sandy PoC already validated
        ↓
CITYWIDE MIGRATION
        ↓
FULL DISTRICT REGISTRY
        ↓
FULL POWER TOPOLOGY
        ↓
CITYWIDE BLACKOUT ENGINE
        ↓
CITYWIDE PHYSICAL INFRASTRUCTURE
        ↓
CITYWIDE GAMEPLAY
        ↓
OPTIONAL DISTRICT VISUAL ENHANCEMENTS
```

Sandy artık:

```text
PROJECT SCOPE
```

değil:

```text
FIRST VALIDATED DISTRICT
```

olarak değerlendirilir.

---

# UPDATED FINAL ARCHITECTURE

```text
                         CITY INFRASTRUCTURE
                                │
                                ▼
                         SERVER POWER GRID
                                │
        ┌───────────────────────┼────────────────────────┐
        │                       │                        │
      GRID A                  GRID B                   GRID C
        │                       │                        │
   SUBSTATIONS              SUBSTATIONS               SUBSTATIONS
        │                       │                        │
      FEEDERS                 FEEDERS                  FEEDERS
        │                       │                        │
  TRANSFORMERS            TRANSFORMERS             TRANSFORMERS
        │                       │                        │
        └───────────────────────┼────────────────────────┘
                                │
                         POWER CALCULATOR
                                │
                         DISTRICT STATES
                                │
             ┌──────────────────┼───────────────────┐
             │                  │                   │
           DOWNT              VESP                SANDY
           OFF                 ON                  OFF
             │                  │                   │
             └──────────────────┼───────────────────┘
                                │
                         STATE REPLICATION
                                │
                                ▼
                              CLIENT
                                │
                         DISTRICT RESOLVER
                                │
                         VISUAL MANAGER
                                │
               ┌────────────────┼────────────────┐
               │                │                │
          NATIVE GATE        HYBRID           EFFECTS
               │                │                │
               └────────────────┼────────────────┘
                                │
                         BLACKOUT EXPERIENCE
```

---

# UPDATED FINAL ENGINEERING PRINCIPLES

1. Server bütün logical power state'in tek otoritesidir.

2. Phase 1–16 implementation korunmalı ve mümkün olduğunca migrate edilmelidir.

3. Sandy-specific logic core içerisinde bırakılmamalıdır.

4. Sandy yalnızca ilk doğrulanmış district'tir.

5. Sistem başlangıçtan itibaren citywide topology olarak devam ettirilmelidir.

6. Desteklenen GTA native district'leri merkezi registry içerisinde bulunmalıdır.

7. GTA district ile infrastructure grid aynı kavram değildir.

8. Bir grid birçok district besleyebilir.

9. Bir grid birçok substation içerebilir.

10. Bir substation birçok feeder besleyebilir.

11. Bir feeder birçok transformer/district besleyebilir.

12. Transformer, feeder, substation ve grid failure farklı impact scope'larına sahip olmalıdır.

13. Her district'in power path'i topology üzerinden hesaplanmalıdır.

14. Power impact client tarafından belirlenemez.

15. Logical power ile visual blackout birbirinden bağımsızdır.

16. Native blackout gerçek spatial district maskesi olarak kabul edilmemelidir.

17. Client-side district gating görsel approximation olarak değerlendirilmelidir.

18. Citywide simultaneous blackout desteklenmelidir.

19. Adjacent blackout district'ler desteklenmelidir.

20. District border transition generic olmalıdır.

21. State replication granular ve revision-based kalmalıdır.

22. Visual adapters idempotent ve reversible olmalıdır.

23. Visual Ownership Manager citywide shared assetleri yönetmelidir.

24. Network entity ID kalıcı infrastructure identity değildir.

25. Topology config-driven olmalıdır.

26. Topology startup sırasında validate edilmelidir.

27. External resource'lar grid yapısını bilmek zorunda olmamalıdır.

28. `IsPositionPowered()` temel integration API'si olmaya devam etmelidir.

29. Random failure impact-aware olmalıdır.

30. Substation failure büyük bölgesel incident olarak ele alınmalıdır.

31. Recovery topology hierarchy'ye saygı göstermelidir.

32. Parent OFFLINE iken child ONLINE olması district'e elektrik vermemelidir.

33. Database critical physical/logical state'i saklamalıdır.

34. Visual state logical state üzerinden yeniden oluşturulmalıdır.

35. Server/resource restart deterministic resync üretmelidir.

36. Framework, inventory, target, dispatch ve minigame entegrasyonları bridge üzerinden kalmalıdır.

37. Citywide V1 için custom blackout map paketleri zorunlu değildir.

38. District-specific hybrid visual paketler sonraki kalite katmanıdır.

39. Full-city duplicate map yaklaşımı kullanılmamalıdır.

40. Final ürün yalnızca Sandy veya belirli birkaç bölgenin değil, **bütün desteklenen GTA şehir/district elektrik altyapısının merkezi framework'ü** olmalıdır.

---

# FINAL PLAYER EXPERIENCE

Oyuncu artık yalnızca Sandy trafosunu patlatmaz.

Örneğin:

```text
WEST LOS SANTOS

Player sabotages transformer
        ↓
Transformer OFFLINE
        ↓
Feeder capacity lost
        ↓
Vespucci power lost
        ↓
VESP = OFF
        ↓
Other feeder districts remain online
        ↓
ATM / CCTV / electronics affected
        ↓
Technician repairs transformer
        ↓
Feeder restored
        ↓
VESP = ONLINE
```

Başka bir olay:

```text
MAJOR SUBSTATION SABOTAGE
        ↓
Substation OFFLINE
        ↓
Multiple Feeders OFFLINE
        ↓
Multiple Districts BLACKOUT
        ↓
Large-scale city incident
```

Bu sırada başka bir grid:

```text
ONLINE
```

kalmaya devam edebilir.

Nihai sistem oyuncuya:

```text
"Blackout efekti açıldı."
```

hissi değil:

```text
"Şehrin elektrik dağıtım altyapısının belirli bir parçasını devre dışı bıraktık
ve bunun gerçek bölgesel sonuçları oldu."
```

hissi vermelidir.