# Phase 22–35 Citywide Geliştirme Planı

## Mevcut durum

- Phase 19–21 kodu ve canlı kabulü tamamlandı.
- Phase 22–35 kodu tamamlandı; tek oyunculu kabuller tamam, final çok oyunculu
  kabul matrisi sonraya bırakıldı.
- Native 90 district topology extension kodu tamamlandı; yeni logical-only
  component’lerin gerçek dünya placement kabulü ayrıca yapılacak.
- Her phase ayrı uygulanacak, test edilecek, kullanıcı onayı alınmadan sonraki phase başlamayacak.
- Her aşamada `CHANGELOG.md` güncellenecek.

## Citywide Topology Extension — 2026-08-15

Kullanıcı kararıyla Phase 22’deki sınırlı topology kapsamı genişletildi:

- Los Santos city region içindeki 44 enabled district tekil grid ve feeder
  sahipliğiyle bağlandı.
- `ls_central`, `ls_south`, `ls_west`, `ls_vinewood` ve
  `ls_east_industrial` olmak üzere beş şehir grid’i eklendi.
- Her şehir grid’i bir substation, iki primary feeder ve iki transformer
  içeriyor.
- Doğrulanmış fiziksel koordinat bulunmayan yeni component’ler
  `physical = false` logical-only olarak tutuluyor. Sahte coordinate, prop
  veya interaction noktası eklenmiyor.
- Fiziksel placement kabulü, gerçek oyun içi koordinatlar doğrulanıp
  `shared/world_placement.lua` içine eklendikten sonra yapılacak.

## Native 90 District Topology Extension — 2026-08-15

Kalan 43 native district, rastgele dağıtım yapılmadan statik logical topology’ye
bağlandı:

- Registry, `web/assets/gta-native-districts.json` içindeki 90 native code’un
  tamamını içeriyor. `HARMOSUB` yalnızca mevcut overlap testleri için synthetic
  zone olarak ayrıca korunuyor.
- `ALTA`, `BAYTRE`, `BHAMCA`, `DELSOL`, `EAST_V`, `GALLI`, `LDAM`, `OBSERV`,
  `PALHIGH` ve `PALMPOW` için geometry-backed XY AABB eklendi; Z aralıkları
  muhafazakâr kaldı. Gerçek dünya placement’ı temsil etmiyor.
- Toplam yapı 11 grid, 11 substation, 22 feeder ve 22 transformer oldu.
  Her grid iki bağımsız primary feeder ve birer transformer içeriyor.
- Yeni component’ler `physical = false` logical-only olarak kaldı. API,
  incident, admin, persistence ve replication zincirleri bu component’leri
  kullanabilir; client tarafında sahte interaction veya prop oluşmaz.
- Los Santos `city` operational region’ı haritadaki şehir sınırını takip
  edecek şekilde 51 district’e çıktı; Tataviam Mountains (`TATAMO`) da şehir
  kapsamındadır. Tüm enabled registry district’leri tek grid ve tek
  feeder ile kaplanıyor.

Unit sonucu: Lua 5.4.8 ile `190 passed, 0 failed`; 121 Lua dosyasında syntax
scan `0` failure. Oyun içi yeni bölgelerin gerçek placement kabulü daha sonra
ayrı yapılacak.

## Phase 22 — World Placement

Yeni `shared/world_placement.lua` modülü:

```lua
InfrastructureWorld = {
    [logicalId] = {
        logicalId,
        type = 'transformer' | 'substation',
        gridId,
        substationId,
        feederId,
        coords,
        heading,
        model,
        interactionRadius,
        visualRadius,
        enabled,
        expectedDistricts,
    }
}
```

- Mevcut logical ID’ler korunacak:
  - `sandy_substation_01`
  - `ls_central_substation_01`
  - `sandy_tr_01`
  - `blaine_south_tr_02`
  - `ls_central_tr_01`
- Network entity ID kalıcı kimlik olarak kullanılmayacak.
- Mevcut placeholder koordinatlar önce registry’ye taşınacak.
- Otomatik prop spawn edilmeyecek; `model` yalnızca beklenen dünya modeli olarak kullanılacak.
- Transformer interactable kayıtları yeni registry üzerinden yapılacak.
- `Validators` şu kontrolleri yapacak:
  - duplicate logical ID
  - duplicate/çok yakın koordinat
  - geçersiz model veya koordinat
  - grid/substation/feeder bağlantısı
  - beklenen district uyumu
  - interaction ve visual radius
- Yeni `/showinfrastructure [logicalId]` komutu:
  - static placement bilgisi
  - topology bağlantısı
  - oyuncuya uzaklık
  - yakın model kontrolü
  - district uyumu
  - interaction erişilebilirliği gösterecek.

Kabul testi:

- `refresh`
- `restart gnsh-blackout`
- `/showinfrastructure`
- Sandy ve Downtown noktalarında fiziksel erişim
- E ile interactable açılması
- yanlış/duplicate placement uyarılarının çalışması
- eski network ID değişse bile logical ID’nin sabit kalması

Phase 22 ayrıca mevcut altı bağlı district dışındaki bölgeler için topology placement üretmeyecek. Rastgele district dağıtımı yapılmayacak. Yeni district bağlantıları gerçek map/gameplay kararıyla ayrıca eklenecek.

## Phase 23 — Incident ve Dispatch

Incident modeli topology seviyesine çıkarılacak.

Yeni metadata şekli:

```lua
metadata = {
    targetType,
    targetId,
    feederId,
    affectedDistricts,
    estimatedImpact = {
        districtCount,
        playerCount,
    },
    approximateLocation,
}
```

- Transformer, feeder, substation ve grid incident’ları aynı lifecycle üzerinden çalışacak.
- `IncidentManager.GetActiveIncidentForTarget(type, id)` eklenecek.
- Aynı target için duplicate active incident engellenecek.
- Impact hesaplama server tarafında yapılacak.
- Parent failure restore edildiğinde ilgili incident otomatik resolve edilecek.
- Mevcut incident SQL tablosu bozulmayacak; yeni bilgiler `metadata` JSON alanında saklanacak.
- Dispatch sistemi bridge olarak eklenecek.
- Dispatch resource’u hard dependency olmayacak.
- Dispatch yoksa incident sistemi çalışmaya devam edecek.

Kabul testi:

- Transformer failure: tek feeder/district impact’i
- Feeder failure: bağlı district listesi
- Substation failure: tüm feeder impact’i
- Grid failure: tüm grid impact’i
- Incident metadata ve estimated impact çıktısı
- Dispatch yokken hata alınmaması

## Phase 24 — External Power API

Mevcut export’lar korunacak. Şunlar eklenecek:

```lua
IsFeederPowered(feederId)
GetFeederState(feederId)
GetInfrastructureAtPosition(coords)
GetPowerPathForDistrict(districtId)
GetAffectedDistricts(targetType, targetId)
GetActiveIncidents()
```

- Tüm dönen tablolar kopya olacak; dış resource runtime state’i değiştiremeyecek.
- `IsPositionPowered(coords)` temel entegrasyon API’si olarak kalacak.
- API topology detayını yalnızca ihtiyaç olduğunda döndürecek.
- ATM, kapı, CCTV gibi resource’lar feeder/grid bilmek zorunda kalmayacak.
- Unassigned district ve bilinmeyen koordinatlar fail-open kalacak.

Kabul testi:

- server export çağrıları
- grid açık / feeder kapalı ayrımı
- parent blockage bilgisi
- `GetPowerPathForDistrict('SANDY')`
- `GetInfrastructureAtPosition(coords)`
- bilinmeyen ID reddi

## Phase 25 — Random Failure

Yeni server-only scheduler:

```text
server/random_failure_manager.lua
```

Varsayılan config:

```lua
Config.RandomFailure = {
    enabled = false,
    tickSec = 60,
    transformerWeight = 1.0,
    feederWeight = 0.0,
    substationWeight = 0.0,
    maxAutomaticOfflineDistricts = 6,
    cooldownSec = 300,
}
```

- İlk sürümde otomatik failure yalnızca transformer seviyesinde aktif olacak.
- Feeder/substation random failure altyapısı desteklenecek ama varsayılan kapalı kalacak.
- Etki hesabı incident oluşmadan önce yapılacak.
- Aktif blackout limiti aşılırsa failure reddedilecek.
- Damage, condition, last failure, active incident ve etkilenen district sayısı ağırlıkta kullanılacak.
- Random failure doğrudan client’tan üretilemeyecek.
- Deterministic test için injectable random provider kullanılacak.

Kabul testi:

- scheduler kapalıyken hiçbir otomatik failure olmaması
- scheduler açıldığında yalnızca izin verilen target seçimi
- district limitinin çalışması
- iki grid’in birbirinden bağımsız kalması
- random failure sonrası incident/persistence/recovery zinciri

## Phase 26 — Security Hardening

Tüm server event sınırları merkezî doğrulama katmanından geçecek.

Kontroller:

- target type whitelist
- target ID existence
- string uzunluk sınırı
- enum doğrulama
- source/player doğrulama
- session owner doğrulama
- nonce/session süresi
- stage sırası
- interaction mesafesi
- duplicate success engeli
- event rate limit
- stale revision reddi
- admin ACE kontrolü

Client hiçbir zaman şunları belirleyemeyecek:

```text
damage
affectedDistricts
powerState
gridState
incident impact
```

Yeni test kapsamı:

- fake grid/feeder/substation/transformer
- fake session
- fake nonce
- wrong repair stage
- distance exploit
- event spam
- duplicate success
- unauthorized admin command
- cross-grid target
- stale revision
- client parent failure üretme denemesi

## Phase 27 — Scale ve Performance

Senaryolar:

- 0 blackout
- 1 transformer blackout
- 1 feeder blackout
- 2 bağımsız grid blackout
- adjacent district blackout
- substation blackout
- rapid repair + sabotage

Ölçümler:

- client frame time
- server tick süresi
- StateBag yazım sayısı
- network event sayısı
- DB write sayısı
- district resolver çağrı sıklığı
- visual apply/remove sayısı
- PTFX sayısı
- memory growth
- cleanup sonucu

- Instrumentation ayrı modülde tutulacak.
- Production’da sürekli debug spam kapalı olacak.
- 32/64/128 oyuncu testleri mümkün olan sunucu kapasitesinde yapılacak.
- Mutlak FPS yerine baseline’a göre regresyon ölçülecek.
- Beklenen üst sınır: baseline’a göre %20’den fazla ek yük olmaması.

## Phase 28 — Visual Quality

Profile çözümleme sırası:

```text
district profile
    ↓
grid profile
    ↓
default native profile
```

- `VisualProfiles.Resolve(districtId, gridId)` eklenecek.
- `NATIVE_CLIENT_GATE` varsayılan fallback olarak kalacak.
- `HYBRID` adapter ayrı modülde tutulacak.
- Native blackout gerçek spatial mask olarak belgelenmeye devam edecek.
- Full-city duplicate `.ymap` veya blackout map kullanılmayacak.
- Öncelik mevcut topology’ye göre:
  - Downtown
  - Pillbox
  - Sandy
- Custom asset yoksa profile yalnızca registry/fallback seviyesinde kalacak.
- Hybrid failure, logical power state’i etkileyemeyecek.

## Phase 29 — Recovery ve Cascade Testleri

Kod tarafında yalnızca testte ortaya çıkan eksikler düzeltilecek.

Test matrisi:

- Feeder A online, Feeder B offline
- Substation restore sonrası partial recovery
- Grid restore sonrası child transformer offline
- Transformer online, parent feeder offline
- Feeder online, parent grid offline
- adjacent district recovery
- recovery sırasında teleport
- recovery sırasında resource restart

Kriter:

```text
Child ONLINE + Parent OFFLINE = District OFFLINE
Parent restore + Child OFFLINE = District OFFLINE
Parent restore + Child ONLINE = District ONLINE
```

## Phase 30 — Admin ve Operations

ACE korumalı komutlar:

```text
/setgridstate <gridId> <ONLINE|OFFLINE>
/setsubstationstate <substationId> <ONLINE|OFFLINE>
/setfeederstate <feederId> <ONLINE|OFFLINE>
/restoregrid <gridId>
/restoresubstation <substationId>
/restorefeeder <feederId>
/restoretransformer <transformerId>
/createincident <targetType> <targetId>
/resolveincident <incidentId>
/reloadtopology
/resyncvisual
/showinfrastructure
```

- Implicit nearest-target kullanılmayacak.
- Her mutasyon açık target type + target ID isteyecek.
- Invalid ID state değiştirmeyecek.
- `/reloadtopology` kod dosyalarını runtime’da yeniden yüklemeyecek; validation + index rebuild yapacak.
- `/resyncvisual` yalnızca client visual state’i yenileyecek.
- Tüm admin işlemleri structured log’a yazılacak.

## Phase 31 — Restart ve Resync

Test edilecek:

- tamamen online server restart
- transformer blackout restart
- feeder blackout restart
- substation blackout restart
- grid blackout restart
- resource restart
- player reconnect
- late join blackout district
- çoklu oyuncu reconnect

Beklenen zincir:

```text
DB
→ topology restore
→ failure override restore
→ grid calculation
→ district replication
→ client visual sync
```

SQL schema import edilmeden persistence testi geçerli sayılmayacak. Mevcut tablolar silinmeyecek.

## Phase 32 — Citywide Integration

Tam akış:

```text
oyuncu district’e girer
→ infrastructure noktası bulunur
→ sabotage
→ incident
→ topology impact hesabı
→ district blackout
→ visual transition
→ external IsPositionPowered sonucu OFF
→ dispatch bilgisi
→ repair
→ recovery
→ district ONLINE
```

Öncelikli test bölgeleri:

- Sandy
- Downtown
- Pillbox
- Harmony
- Desert
- gelecekte topology’ye bağlanan district’ler

ATM/CCTV/doorlock entegrasyonları hard dependency olmadan test edilecek.

## Phase 33 — Production Hardening

- Debug spam temizlenecek.
- Dev komutları ACE korumalı olacak.
- Config/topology validation boot’ta zorunlu kalacak.
- SQL schema doğrulanacak.
- Event/export dokümantasyonu tamamlanacak.
- Error handling ve cleanup tekrar denetlenecek.
- Rate limit’ler test edilecek.
- Bridge yokluğu güvenli fallback verecek.
- Missing dependency davranışı test edilecek.
- Version production release seviyesine yükseltilecek.

## Phase 34 — Documentation

Yeni veya güncellenmiş dokümanlar:

- Architecture
- District registry
- Grid/substation/feeder/transformer ekleme
- World placement
- Power calculation
- Sabotage/repair
- Incident/dispatch
- External exports
- Events
- Framework bridges
- Security model
- Persistence
- Debug commands
- Troubleshooting
- Production checklist

README ve CHANGELOG her phase ile birlikte güncellenecek.

## Phase 35 — Final Release Acceptance

Final geçiş şartları:

- desteklenen district’ler registry’de
- aktif district’ler topology’ye bağlı
- multi-grid çalışıyor
- multi-substation çalışıyor
- multi-feeder çalışıyor
- transformer/feeder/substation/grid failure çalışıyor
- partial recovery çalışıyor
- restart/reconnect/late-join çalışıyor
- server authority korunuyor
- persistence deterministic
- visual cleanup garantili
- external API dokümante
- admin komutları güvenli
- SQL import doğrulanmış
- oyun içi testler kullanıcı tarafından onaylanmış

## Ortak phase kuralı

Her phase sonunda:

1. Kod uygulanır.
2. `refresh` + `restart gnsh-blackout`.
3. Lua interpreter yoksa test sonucu `PASS` yazılmaz.
4. Lexical delimiter taraması yapılır.
5. Server/F8 hata kontrolü yapılır.
6. `CHANGELOG.md` kod durumuyla güncellenir.
7. Kullanıcı oyun içi testi yapar.
8. Kullanıcı onayı olmadan sonraki phase başlamaz.

## Sabit varsayımlar

- Mevcut logical ID’ler korunacak.
- Placeholder koordinatlar kullanıcıyla oyun içinde doğrulanmadan kesin koordinat kabul edilmeyecek.
- Dispatch, hybrid visual ve custom asset sistemleri hard dependency olmayacak.
- Mevcut menuv/progressBar/skillCheck arayüzleri placeholder kalacak; toplu UI overhaul daha sonraki ayrı iş olacak.
- `NativeBlackout` spatial district maskesi değildir.
- Rastgele district/topology dağıtımı yapılmayacak.
- Phase 22–35 implementation’ında agent gerekirse `gpt-5.6-luna` kullanılacak.
