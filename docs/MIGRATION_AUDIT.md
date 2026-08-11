# Migration Audit — Phase 16.5 (Citywide Migration & Compatibility Audit)

Spec: `CITY INFRASTRUCTURE (1).md` §16.5 ("PHASE 16.5 — CITYWIDE MIGRATION &
COMPATIBILITY AUDIT"). Bu dosya spec'in kendi kapı koşulunu karşılıyor:
*"Bu phase tamamlanmadan citywide topology oluşturulmamalıdır."*

Amaç REWRITE değil **GENERALIZE + MIGRATE + EXTEND** (§16.5.2) — Phase 1-16'da
çalışan `DistrictManager`, `ZoneResolver`, `GridManager`, `PowerCalculator`,
`TransformerManager`, `SubstationManager`, `Replication`, `TransitionManager`,
`VisualManager`, `VisualOwnershipManager`, `IncidentManager` hiçbiri gereksiz
yere yeniden yazılmadı — sadece Phase 17/18'i bloklayan gerçek eksikler
düzeltildi.

Yöntem: her `§16.5.1` sorusu için repository'de gerçek arama yapıldı
(`SANDY|blaine_south|sandy` deseni tüm `.lua` dosyalarında, ayrıca
`ApplySandyBlackout`/`SetSandyPower`/`GetSandyGrid` gibi isimler özel olarak
arandı — hiçbiri bulunmadı).

## §16.5.1 — Mevcut Implementation Audit

| Soru | Sonuç | Kanıt |
|---|---|---|
| SANDY hardcode edilmiş mi? | ✅ PASS | Eşleşen tüm satırlar veri/config dosyalarında (`shared/grids.lua`, `profiles/sandy.lua`, `shared/districts.lua`) veya test/yorum satırlarında. Core mantıkta (`server/*.lua`, `client/*.lua` — debug dosyaları hariç) `SANDY` string'i geçmiyor. |
| `blaine_south` hardcode edilmiş mi? | ✅ PASS (config seviyesinde, beklenen) | `shared/grids.lua`'da grid id'si olarak tanımlı — bu bir veri girdisi, kod dalı değil. `server/power_calculator.lua:14`'teki tek geçiş bir örnek-yorum. |
| Tek grid varsayımı var mı? | ✅ PASS | `server/grid_manager.lua:25` (`for gridId, grid in pairs(Grids) do`), `server/replication.lua:88` (`for _, gridId in ipairs(GridManager.GetAllGridIds())`) — ikisi de N-grid için yazılmış, tek grid'e özel dal yok. |
| Tek transformer varsayımı var mı? | ✅ PASS | `GridManager.GetTransformersForGrid(gridId)` liste döner (`server/grid_manager.lua:74-77`); `server/power_calculator.lua` PRIMARY/ANY/ALL/REQUIRED_COUNT dört policy'yi de N-trafo üzerinde çalıştırıyor. |
| Tek substation varsayımı var mı? | ✅ PASS | `shared/grids.lua`'nın kendi yorumu: *"SUBSTATION ve TRANSFORMER ayrı tablo... MVP 1:1 ama data modeli çoklu transformer'a hazır"* — `Substations[subId].transformers` zaten dizi. |
| VisualManager sadece Sandy için mi çalışıyor? | ✅ PASS | `client/visual/manager.lua:95-96`: `Grids[gridId]` ve `VisualProfiles[grid.visual.profile]` üzerinden çözer, `gridId == 'blaine_south'` gibi bir kontrol yok. |
| Native blackout sadece Sandy eventlerinden mi tetikleniyor? | ✅ PASS | Tetikleyici `infra:powerStateChanged` — payload'daki `gridId`'ye göre çalışır, Sandy'ye özel değil. |
| Replication dinamik district key destekliyor mu? | ✅ PASS | `server/replication.lua:44,48`: `Constants.StateKey.GRID .. gridState.gridId`, `Constants.StateKey.DISTRICT .. districtState.district` — key string concatenation, sabit liste değil. |
| DistrictManager herhangi bir GTA district'i kabul ediyor mu? | ✅ PASS | `client/zone_resolver.lua` native `GetNameOfZone()` sonucunu doğrudan döner, whitelist yok. |
| GridManager birden fazla grid aynı anda yönetebiliyor mu? | ✅ PASS | Yukarıdaki `pairs(Grids)` döngüleri. |

**Sonuç: §16.5.1'in aradığı "ApplySandyBlackout() / SetSandyPower() / GetSandyGrid()" türü Sandy-specific fonksiyonlar core'da yok.** Tek gerçek kod kalıntısı `client/sabotage.lua`'daki debug komutunun varsayılan parametresiydi (aşağıya bakın, düzeltildi).

## Citywide'ı gerçekten bloklayan 4 eksik (bu audit'te tespit edildi)

Bunlar §16.5.1'in sorduğu "Sandy hardcode mi" sorusundan farklı bir kategori:
kod Sandy'ye özel değil, ama **henüz citywide senaryoyu (birden fazla feeder,
district-seviyesinde farklı power state) desteklemiyor.**

1. **District state grid'den kopyalanıyor, bağımsız hesaplanmıyor.**
   `server/replication.lua:98-104` ve `:136-142` bir grid'in `powered`
   değerini o grid'in **tüm** district'lerine olduğu gibi yazıyor. Bugün
   (`blaine_south` → SANDY/HARMO/DESRT hepsi tek trafodan besleniyor) bu
   doğru sonuç veriyor, ama Phase 18'in feeder katmanı ile artık yanlış
   olacak (§18.4: transformer failure = 1 district, feeder failure = birkaç
   district — aynı büyüklükte olay değiller). **Düzeltmesi Phase 18'in
   kapsamında** ("Ana değişiklik: district-level power hesabı").
2. **`ClientState` §19.2'nin istediği alanları taşımıyor** — `CurrentFeeder`,
   `CurrentPowerRevision`, `CurrentVisualProfile` yok (`client/state.lua`
   sadece `CurrentDistrict`/`CurrentGrid`/`ActiveProfiles` tutuyor).
   Phase 19 (citywide visual controller) bunlara ihtiyaç duyacak — bu turda
   sadece not edildi, ekleme Phase 18'in district state yayınıyla birlikte.
3. **District modeli §17'nin istediği şekilde değil** — bugün `shared/
   districts.lua`'da sadece `code`/`label`/`aabb` var; `enabled`,
   `category`, `resolver`, `defaultGrid`, `visualProfile`, `metadata`
   eksik. **Phase 17'nin kapsamı.**
4. **`GridManager`'da feeder indeksi yok** — `feederToSubstation`,
   `substationToFeeders`, `transformerToFeeder`, `districtToFeeders`
   hiçbiri yok, çünkü feeder katmanı henüz yok. **Phase 18'in kapsamı.**

## Bu turda düzeltilen küçük hazırlıklar

- `client/sabotage.lua`: `/sabotage` komutunun `targetId` parametresi artık
  zorunlu — eskiden `args[1] or 'sandy_tr_01'` idi (parametresiz
  çağrıldığında sessizce Sandy trafosunu hedefliyordu). §30.2: *"Implicit
  nearest-target gibi riskli production admin davranışlarından
  kaçınılmalıdır."* Şimdi eksik parametrede kullanım mesajı basıyor.
  (`/tptrafo` ve `/infracoords` bilinçli olarak **dokunulmadı** — ikisi de
  saf debug/teleport yardımcıları, "hangi trafoyu etkileyeceğim" kararı
  vermiyorlar, sadece Sandy'nin fiziksel konumuna ışınlıyor/mesafe
  ölçüyorlar; Phase 22 dünya yerleşimi geldiğinde parametrik hâle
  getirilecekler.)
- `README.md`: "Sandy MVP" / "Phase 1-14" dili güncel duruma (Phase 1-16
  tamamlandı, Phase 16.5+ citywide hedefi) çekildi.

## §16.5.3 — Config-Driven Zorunluluğu

Şu ilişkilerin hiçbiri kod içinde hardcode değil, hepsi `shared/grids.lua` /
`shared/districts.lua` config tablolarından çözülüyor:
`district → grid` (`GridManager.districtToGrid`), `grid → substation`
(`grid.substations`), `substation → transformer` (`sub.transformers`).
`substation → feeder` ve `feeder → transformer` henüz **yok** (feeder katmanı
Phase 18'de ekleniyor) — bu satır bilinçli olarak "henüz uygulanamaz" olarak
işaretleniyor, atlanmıyor.

## §16.5.4 — Migration Acceptance Criteria

| Kriter | Durum |
|---|---|
| Sandy mevcut şekilde çalışmaya devam etmeli | ✅ Bu phase'de davranış değişikliği yok — sadece dokümantasyon + 1 debug komutu kısıtlaması. Oyun içi regresyon testiyle doğrulanacak (bkz. CHANGELOG). |
| Core içerisinde Sandy-specific gameplay logic kalmamalı | ✅ Yukarıdaki audit — zaten yoktu. |
| Birden fazla grid oluşturulabilmeli | ✅ Zaten destekleniyor (`GridManager`/`Replication` N-grid için yazılmış) — Phase 18'de gerçekten birden fazla grid tanımlanacak. |
| Birden fazla district eş zamanlı state taşıyabilmeli | ✅ Zaten destekleniyor (`districtStates` tablosu district-key'li). |
| VisualManager district/grid parametreli çalışmalı | ✅ Zaten öyle. |
| Replication dinamik district/grid ID desteklemeli | ✅ Zaten öyle. |
| Existing persistence bozulmamalı | ✅ Bu phase SQL şemasına dokunmuyor. |
| Existing Phase 1-16 testleri geçmeli | Oyun içi regresyon testiyle doğrulanacak (bkz. CHANGELOG "Test durumu"). |

**Sonuç:** Phase 16.5'in gerçek işi büyük ölçüde zaten Phase 1-16'nın kendi
tasarım disiplini (config-driven, N-grid/N-transformer'a hazır data modeli)
sayesinde tamamlanmış durumdaydı. Bu audit bunu resmî olarak doğruladı ve
kalan 4 gerçek eksiği (yukarıda) Phase 17/18'e net olarak devretti.
