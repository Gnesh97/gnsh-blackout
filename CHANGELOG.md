# CHANGELOG — gnsh-blackout (City Infrastructure)

## [Unreleased]

- Added the universal sabotage/repair NUI redesign for the FiveM gameplay flow:
  transparent terminal-style presentation, Turkish UI copy, corrected success
  feedback wrapping, and blackout-aware red `LINK UNSTABLE` status treatment.
- Scoped the gameplay NUI to the relevant sabotage/repair interaction instead
  of showing a persistent fullscreen panel; removed the unwanted opaque
  `#121212` background and edge fade from the map presentation.
- Added the admin operations NUI foundation with command-based opening, a
  two-tab structure, and the first map tab built around the GTA V district map.
  The map includes the native district overlay, adjusted map alignment,
  district labels, hover/selection feedback, pan/zoom controls, and a cleaner
  high-contrast infrastructure visual language.
- Localized the NUI-facing labels, status messages, controls and completion
  feedback to Turkish while preserving native district identifiers for logic
  and diagnostics.
- Added admin regional blackout controls for city, north, towns, south side,
  Vinewood and related operational groupings. Regional actions now resolve all
  districts in the selected region independently of transformer, feeder or
  assigned-grid ownership.

- Citywide native topology expansion (0.38.0-rc.2): all 90 native district
  codes now have explicit single-grid and single-feeder ownership across 11
  grids, 11 substations, 22 feeders and 22 transformers. The synthetic
  `HARMOSUB` overlap-test zone is assigned separately and is not counted in
  the native 90.
- Added geometry-backed XY AABBs for the ten native codes that were missing
  from the registry: `ALTA`, `BAYTRE`, `BHAMCA`, `DELSOL`, `EAST_V`, `GALLI`,
  `LDAM`, `OBSERV`, `PALHIGH` and `PALMPOW`. Z ranges remain conservative;
  no physical interaction point or prop was invented.
- Added logical-only world records for the new grids, substations and
  transformers. Existing Sandy/Central physical points remain enabled;
  server API, admin, incident, persistence, replication and topology
  validation cover every new logical target.
- Expanded `tests/spec/citywide_topology_spec.lua` to verify all enabled
  districts, unique feeder ownership and multi-feeder topology for every
  configured grid. Lua 5.4.8 suite: 190 passed, 0 failed. Lua syntax scan:
  121 files, 0 failures. Live citywide acceptance and verified physical
  placements remain pending.
- Corrected the mapped city boundary: the `city` operational region now
  includes Tataviam Mountains (`TATAMO`) along with the full Los Santos area;
  its AABB now uses the native geometry envelope as well. This does not merge
  logical grids.
- Improved standalone infrastructure interaction UX: external target resources
  keep their native target menu, while the dependency-free fallback no longer
  draws a large orange floor marker. It now shows one contextual 3D `[E]
  Trafoyu incele` prompt only near the closest transformer.
- Expanded bridge startup diagnostics to report framework, inventory, target,
  notify, menu, progress, skillcheck, and database adapters; the startup line
  now matches the full `/blackoutbridge` diagnostic output.
- Fixed optional `ox_lib` adapter selection without reintroducing a hard
  dependency. The bridge now validates and calls ox_lib's public resource
  exports directly (`registerContext`, `showContext`, `notify`, `progressBar`
  and `skillCheck`), with a safe internal fallback when an export is absent.
- Fixed the explicit `ox_lib` skillcheck adapter so difficulty/input payloads
  are normalized and a failed ox_lib call cannot silently fall through to the
  permissive universal timed-bar adapter; the fallback is now strict native
  input validation.
- Fixed the `ox_lib` skillcheck export invocation to use its owner-bound `:`
  contract. This prevents malformed difficulty data from rendering a full
  target ring with a stalled indicator.
- Interaction/bridge regression suite: `173 passed, 0 failed`; Lua 5.4.8 syntax
  scan: 114 files, `SyntaxFailures=0`.
- Audit follow-up kararları uygulandı: başarısız sabotage skillcheck'leri artık
  yapılandırılmış sabotage item'ını tüketiyor; damage, incident ve success
  cooldown üretmiyor. Recovery rollback refund yarışı, test `Log.debug` stub'ı,
  Türkçe bildirimler ve native visual ownership lifecycle düzeltildi. Lua 5.4.8
  suite sonucu: 165 passed, 0 failed.
- Added the production branch, CI validation, release checklist, rollback notes, backup notes, and staging test matrix.
- No gameplay behavior was changed by this release-management update.
- Fixed a join-time fullscreen overlay by removing the internal `ui_page`.
  Dependency-free UI fallback now uses GTA native help text, notifications
  and controls without NUI focus or browser callbacks.
- Fixed txAdmin master/admin users being rejected by /repairall when their
  QBCore/ACE admin permission was not present. Server-local txAdmin
  adminAuth and adminsUpdated signals now feed the centralized security
  gateway; client network events cannot forge this authorization.
- Added automatic txAdmin auth refresh through txAdmin's own
  txsv:checkIfAdmin server flow, rate-limited and still validated only from
  server-local adminAuth results.
- Added txAdmin authorization regression coverage. Lua 5.4.8 suite result:
  149 passed, 0 failed; Lua syntax scan: 110 files, 0 failures. Live
  txAdmin /repairall acceptance remains pending.
- Fixed command-specific ACE operators being rejected by `/repairall` and
  other resource admin commands. `Security.RequireAdmin` now checks the
  configured server-side `command`, `command.refresh` and `command.restart`
  ACE permissions in addition to framework and txAdmin authorization.
  Regression suite: 152 passed, 0 failed; live acceptance remains pending.
- Fixed the `qb-menu` bridge callback contract. The installed qb-menu sends
  `params.args` as one table; sabotage/repair actions now unpack that shape
  (while retaining legacy two-argument compatibility), so selecting sabotage
  reaches the server request and skillcheck stage.
- Improved the dependency-free native skillcheck fallback with a visible
  centered prompt showing the required key and remaining time. Bridge
  regression suite: 154 passed, 0 failed; Lua syntax scan: 111 files, 0
  failures.
- Fixed the native skillcheck/target input collision: E and R are now
  temporarily disabled for the target adapter during each skill stage and
  read through the disabled-control API, preventing E from reopening the
  sabotage menu between stages. Regression suite: 155 passed, 0 failed.
- Fixed the `progressbar` bridge contract for repair stages. Generic
  `disable` options are now translated to the resource's required
  `controlDisables` shape, preventing repeated `Action.controlDisables` nil
  errors during repair. Regression suite: 156 passed, 0 failed; Lua syntax
  scan: 111 files, 0 failures.
- Fixed inventory item consumption through the universal bridge. The
  `ox_inventory` mutating exports now use the correct export contract;
  sabotage aborts when its item cannot be removed, and repair revalidates
  and consumes all condition materials at the final stage with rollback on a
  partial removal. Regression suite: 158 passed, 0 failed; Lua syntax scan:
  111 files, 0 failures.

- Applied MP test code-audit hardening. Replication now advances its startup
  baseline above revisions already published in StateBags; restored incident
  severity is normalized to numeric values; repair completion checks state and
  damage mutations and refunds consumed materials on rollback; failed sabotage
  skillchecks do not consume items or start cooldown; runtime-only transformer
  revisions are no longer read from the SQL row; bridge diagnostics use the
  correct server/client Notify signature; and profiles honor
  `nativeBlackout.enabled`.
- Added `tests/spec/audit_regression_spec.lua` covering restart revision
  monotonicity, mixed persisted/new incident severity, repair rollback, and
  failed sabotage side effects. Lua 5.4.8 regression suite: 165 passed, 0
  failed.
- Updated `docs/MULTIPLAYER_ACCEPTANCE_TESTS.md` with the debug convar setup and
  cleanup, explicit C4 usage for blackout scenarios, the physical location
  note for `blaine_south_tr_02`, and the corrected `apiquery` output contract.
- `apiquery` now sends its encoded result to the invoking player's F8 console
  and includes `source=<playerId>` in the server log.
- Lua 5.4.8 syntax scan: 112 Lua files checked, 0 failures.
- Added final repair recovery rollback/refund handling, sabotage session cleanup
  on stale/distance/completion rejection, and native visual cleanup when the
  destination profile disables native blackout. Regression coverage now also
  covers those three paths.

## Universal Bridge RC - 2026-08-11

Universal FiveM conversion applied according to `C:\Users\Gnesh\Desktop\plan.md`.

- Removed hard `ox_lib`, MenuV, `ox_inventory` and `oxmysql` dependencies and
  direct imports from `fxmanifest.lua`.
- Added atomic bridge snapshots, alias normalization, adapter contract checks,
  explicit fallback logging, `/blackoutbridge`, resource start/stop rebuild and
  target interactable rebind without duplicate zones.
- Added QBCore, Qbox, ESX Legacy and standalone framework adapters.
- Added ox/qs/ps/qb/framework/none inventory adapters and ox/qb/qtarget/
  standalone target adapters.
- Added notify, menu, progress, skillcheck and database adapter categories.
- Added dependency-free native fallback for menu, notification, cancelable
  progress and keyboard skillcheck. Server sessions remain authoritative.
- Moved gameplay UI and persistence behind Bridge contracts. oxmysql uses
  documented async exports; memory fallback keeps runtime operational without
  SQL and intentionally does not survive restart.
- Added `tests/spec/bridge_contract_spec.lua`; pure Lua suite now reports
  `146 passed, 0 failed` with Lua 5.4.8. Lua syntax scan: 110 files,
  `SyntaxFailures=0`.
- Live compatibility tests for Qbox, ESX, qs/ps inventory, ox_target and
  no-dependency standalone stack remain pending. Phase 35 final acceptance
  stays blocked until those stacks and deferred multiplayer tests are accepted.

Bu dosya `CITY INFRASTRUCTURE (1).md` (Master Specification V3) spec'inin
uygulama planına göre, aşama aşama (phase-by-phase) proje durumunu takip
eder. Format: her phase kendi bölümü, o phase **tamamlandığında** yazılır.

Kapsam: bu sürüm Phase 1-35 release-candidate kapsamını taşır. **2026-08-09'da spec güncellendi**
(V3, citywide roadmap) — eski Phase 17-22 (Sandy hybrid visual, external
API, random failure, security hardening, scale test, city expansion)
kaldırıldı, yerine Phase 16.5-35 citywide roadmap geldi: "Sandy artık
PROJECT SCOPE değil, FIRST VALIDATED DISTRICT." Phase 19 (Citywide
District Blackout Controller) ve sonrası bir sonraki parçaya ait.

## Durum Özeti

| Phase | Ad | Durum | Unit Test | Oyun İçi Test |
|---|---|---|---|---|
| 1 | Core Foundation | TAMAMLANDI | — | ✅ Doğrulandı (temiz start, ACE/bridge çalışıyor) |
| 2 | GTA District Manager | TAMAMLANDI | — | ✅ Kısmen (Sandy↔komşu sınır geçişi doğru; tam district taraması yok) |
| 3 | Hybrid Zone Resolver | TAMAMLANDI | ✅ (zone_resolver_spec) | Bekliyor (custom zone hiç kurulmadı) |
| 4 | Grid Topology | TAMAMLANDI | — | ✅ Doğrulandı (griddebug doğru grid/state basıyor) |
| 5 | Transformer Model | TAMAMLANDI | — (yapı test edildi, geçiş tablosu oyun içi) | ✅ Kısmen (setgridpower ile dolaylı; /setdamage ayrıca denenmedi) |
| 6 | Power Calculator | TAMAMLANDI | ✅ (power_policy_spec) | ✅ Doğrulandı (PRIMARY policy, tek trafo OFFLINE→grid BLACKOUT) |
| 7 | State Replication | TAMAMLANDI | — | ✅ Kısmen (revision artışı doğrulandı; reconnect/late-join denenmedi) |
| 8 | Sandy Native Blackout PoC | TAMAMLANDI | — | ✅ Doğrulandı (§75 senaryosunun çekirdeği: blackout, sınır gating, cleanup) |
| 9 | Test dosyaları | TAMAMLANDI | ✅ (4 spec dosyası yazıldı) | N/A |
| 11 | Incident System | TAMAMLANDI (redo, 08-08) | — | ✅ Doğrulandı (incident create + grid BLACKOUT, sabotaj testiyle birlikte) |
| 12 | Sabotage Framework | TAMAMLANDI (redo, 08-08) | — | ✅ Kısmen (Termit ile uçtan uca doğrulandı; fail/cooldown/C4-item-farkı/incident-resolve ayrıca denenmedi) |
| 13 | Repair System & Diagnostics | TAMAMLANDI, 08-08 | — | ✅ Doğrulandı (kullanıcı onayı, disconnect/reconnect senaryosu ayrıntılı denenmedi) |
| 14 | Persistence | TAMAMLANDI, 08-08 | — | ✅ Doğrulandı (2 gerçek hata bulunup düzeltildikten sonra: restart'ta sabotaj kalıcı) |
| 15 | Transition Engine | TAMAMLANDI, 08-08 | — | ✅ Doğrulandı (kullanıcı onayı) |
| 16 | Visual Ownership | TAMAMLANDI, 08-08 | ✅ (visual_ownership_spec, 10 test — lokal Lua yokluğunda çalıştırılamadı) | ✅ Doğrulandı (kullanıcı onayı) |
| 16.5 | Citywide Migration Audit | TAMAMLANDI, 08-09 | — (dokümantasyon phase'i) | ✅ Doğrulandı (kullanıcı onayı — regresyon yok) |
| 17 | Complete GTA District Registry | TAMAMLANDI, 08-09 | ✅ (district_registry_spec, 9 test — lokal Lua yokluğunda çalıştırılamadı) | ✅ Doğrulandı (kullanıcı onayı) |
| 18 | Citywide Power Topology + Feeder Layer | TAMAMLANDI, 08-09 | ✅ (topology_spec, 9 test — lokal Lua yokluğunda çalıştırılamadı) | ✅ Doğrulandı (kullanıcı: "Testleri yaptım oldu") |
| 19 | Generic Citywide District Blackout Controller | TAMAMLANDI, 08-09 | ✅ (district_controller_spec — lokal Lua yok) | ✅ Doğrulandı (kullanıcı onayı, 10-08) |
| 20 | Citywide District Transition Engine | TAMAMLANDI, 08-09 | — (token/akış kod incelemesi) | ✅ Doğrulandı (kullanıcı onayı, 10-08) |
| 21 | Citywide Failure Propagation | TAMAMLANDI (kod), 08-09 | ✅ (failure_propagation_spec — lokal Lua yok) | Bekliyor (SQL + oyun içi kabul testi) |
| 22 | Citywide Transformer/Substation World Placement | TAMAMLANDI (kod), 08-09 | ✅ (world_placement_spec — lokal Lua yok) | ✅ Doğrulandı (kullanıcı onayı; final placement ertelendi) |
| 23 | Incident ve Dispatch | TAMAMLANDI, 10-08 | ✅ (incident_impact_spec — lokal Lua yok) | ✅ Doğrulandı (kullanıcı onayı, 10-08) |
| 24 | External Power API | TAMAMLANDI, 10-08 | ✅ (api_spec yazıldı — lokal Lua yok) | ✅ Doğrulandı (kullanıcı onayı, feeder/path/position/fail-open) |
| 25 | Citywide Random Failure | TAMAMLANDI, 10-08 | ⏳ (random_failure_spec yazıldı; lokal Lua yok) | ✅ Doğrulandı (kullanıcı onayı, 10-08) |
| 26 | Security Hardening | RC kod tamamlandı | ⏳ (security_spec yazıldı; lokal Lua yok) | Bekliyor (kullanıcı canlı kabulü) |
| 27 | Scale ve Performance | RC kod tamamlandı | ⏳ (metrics_spec yazıldı; lokal Lua yok) | Bekliyor (kapasite/metric kabulü) |
| 28 | Visual Quality | RC kod tamamlandı | ⏳ (visual_profile_spec yazıldı; lokal Lua yok) | Bekliyor (kullanıcı canlı kabulü) |
| 29 | Recovery ve Cascade | RC kod/test sözleşmesi tamamlandı | ⏳ (recovery_spec; lokal Lua yok) | Bekliyor (kullanıcı canlı kabulü) |
| 30 | Admin ve Operations | TAMAMLANDI, 2026-08-11 | ✅ (admin_operations_spec; suite içinde geçti) | ✅ Doğrulandı (ACE/komut canlı kabulü) |
| 31 | Restart ve Resync | RC boot/resync sözleşmesi tamamlandı | ⏳ (restart_resync_spec; lokal Lua yok) | Bekliyor (restart/reconnect kabulü) |
| 32 | Citywide Integration | RC entegrasyon sözleşmeleri korundu | — | Bekliyor (Sandy/Downtown/Pillbox ve adapter kabulü) |
| 33 | Production Hardening | RC production varsayılanları uygulandı | — | Bekliyor (SQL/soft dependency/error kabulü) |
| 34 | Documentation | TAMAMLANDI (kod/docs) | — | Bekliyor (kullanıcı operasyon onayı) |
| 35 | Final Release Acceptance | BEKLEMEDE | — | Bekliyor (kullanıcı final kabulü) |

---

## Repair Hotfix — 2026-08-10

- Repair server mesafe kontrolü transformer world placement `interactionRadius`
  ile hizalandı; client menü aralığı ile server reddi ayrışmıyor.
- FiveM `vector3` world placement koordinatları Security distance validator
  tarafından geçerli kabul ediliyor; stage completion artık yanlış `OUT_OF_RANGE`
  reddi üretmiyor.
- Stage completion mesafe/session/revision hatasında repair session, target lock
  ve `REPAIRING` state temizleniyor; sonraki repair denemesi kilitlenmiyor.
- ACE korumalı `/repairall` test komutu eklendi; tüm transformer damage/state,
  feeder/substation/grid override ve aktif repair lock'larını normal persistence,
  replication ve incident çözüm zinciri üzerinden temizliyor.
- Canlı hotfix doğrulaması bekliyor. Lokal Lua interpreter hâlâ yok.

---

## Phase 25 — Citywide Random Failure · TAMAMLANDI · 2026-08-10

### Ne yapıldı

- Server-only `RandomFailureManager` eklendi. Scheduler disabled-by-default,
  ilk tick `tickSec` sonrasında çalışıyor ve online player yoksa failure üretmiyor.
- Transformer candidate seçimi default aktif. Seçilen transformer mevcut
  `TransformerManager.SetDamage(..., 100, ...)` zinciriyle `DESTROYED`/`OFFLINE`
  oluyor; incident cause `RANDOM_FAILURE` olarak kaydediliyor.
- Feeder/substation candidate desteği eklendi; default weight değerleri `0.0`.
  Parent failure incident cause için geriye uyumlu optional context eklendi.
- Impact öncesi district limiti, active incident district union, blocked/offline/
  active-target filtreleri, weighted selection ve global cooldown eklendi.
- Injectable clock, random ve player-count provider'ları test determinism için
  eklendi. SQL schema değişmedi; mevcut transformer/incident/override tabloları
  kullanıldı.
- `Config.RandomFailure` validation, boot/start-stop entegrasyonu, version `0.25.0`
  ve README davranış/config dokümantasyonu güncellendi.

### Dosyalar

- `server/random_failure_manager.lua` (yeni)
- `server/failure_manager.lua`, `server/main.lua`, `shared/validators.lua`
- `config.lua`, `fxmanifest.lua`, `tests/spec/random_failure_spec.lua`,
  `tests/run.lua`, `README.md`

### Test durumu

- [x] Disabled scheduler, no-player gate, deterministic transformer selection (kullanıcı canlı testinde doğrulandı).
- [x] Offline/blocked/active target filtering (kullanıcı canlı testinde doğrulandı).
- [x] Overlapping district deduplication and district limit (kullanıcı canlı testinde doğrulandı).
- [x] Global cooldown and feeder parent context tests (kullanıcı canlı testinde doğrulandı).
- [x] Failed mutation cooldown davranışı (kod/runtime kontrolü tamamlandı).
- [x] Invalid random-failure config validation (kod/runtime kontrolü tamamlandı).
- [x] Lokal `lua5.4 tests/run.lua`: Lua 5.4.8 ile `136 passed, 0 failed`.
- [x] `refresh` + `restart gnsh-blackout` sonrası random failure oyun içi kabulü (kullanıcı onayı).
- [x] Server/F8 hata kontrolü ve kullanıcı onayı (2026-08-10).

### Sonraki adım

Phase 25 canlı kabulü tamamlandı. Phase 26-35 RC kodu uygulanmıştır. Sıradaki
adım kullanıcı canlı kabulü; final kabul sonrası version `1.0.0` yapılacaktır.

**Test sonucu güncellemesi (2026-08-11):** Lua 5.4.8, kullanıcının
yerel Lua 5.4.8 executable'ı ile
`tests/run.lua` çalıştırıldı ve `136 passed, 0 failed` sonucu alındı.

Oyun içi doğrulama ise **kullanıcının kendi FXServer'ında canlı olarak
yapıldı** (2026-08-10) — bkz. aşağıdaki "Canlı Doğrulama Oturumu" bölümü
ve her phase'in güncellenmiş "Test durumu" checkbox'ları.

---

## Canlı Doğrulama Oturumu — 2026-08-07 (kullanıcının FXServer'ında)

Uygulama bittikten sonra kullanıcıyla birlikte gerçek sunucuda test edildi.

### Karşılaşılan ve çözülen sorunlar
1. **ACE object adı yanlıştı** — ilk önerilen `server.cfg` satırı
   (`add_ace group.admin command allow`) `server/debug.lua`'nın gerçekte
   kontrol ettiği object adıyla (`admin`, `IsPlayerAceAllowed(source,
   'admin')` — `Config.Debug.adminGroup` değeri) eşleşmiyordu. Doğrusu:
   `add_ace group.admin admin allow` + `add_principal group.user
   group.admin`. Bu, dokümantasyon/talimat hatasıydı, kod hatası değildi.
2. **Komut kaynağı karışıklığı** — `/setgridpower` server-side komut;
   kullanıcı önce F8 (client) konsoluna yazdığı için "hiçbir şey olmuyor"
   sanmıştı. ACE düzeltmesi + chat'ten (`/setgridpower ...`) çağırma ile
   çözüldü.
3. `shared/districts.lua` tablosunda olmayan district kodları
   (`SanAnd`, `OCEANA`) için beklenen/zararsız uyarı logları görüldü —
   bunlar gerçek GTA zone kodları, tablo kasıtlı olarak eksiksiz değil
   (bkz. Phase 2 notu). Davranış değişikliği gerekmedi.

### Doğrulanan senaryolar (§75'in çekirdeği)
- Resource temiz başladı, konsolda beklenmeyen hata yok.
- `/setgridpower blaine_south 0` → `griddebug` revision 0→1, Power OFF.
- Sandy Shores'ta iken native blackout uygulandı (ışıklar söndü).
- Komşu district'e geçiş → blackout kalktı (district-based gating
  doğrulandı — spec §22'nin iddia ettiği "sadece o an bulunulan district"
  davranışı, tüm sunucu değil).
- Sandy'ye geri dönüş → blackout yeniden uygulandı.
- Blackout aktifken `restart gnsh-blackout` → ışıklar normale döndü
  (spec §61 cleanup doğrulandı — oyuncu karanlıkta takılı kalmadı),
  restart sonrası `griddebug` Power ON (persistence olmadığı için
  beklenen — Phase 14'e kadar tasarım gereği).

### Doğrulanmayanlar (sonraki oturum)
- İkinci client ile senkron testi (tek oyuncu ortamıydı).
- Gerçek reconnect/late-join testi (blackout aktifken yeniden bağlanma).
- `/setdamage` ile damage→condition→OFFLINE zorlaması.
- Custom zone (`Config.Zones`) — hiç yapılandırılmadı/denenmedi.
- `IsPositionPowered` export'unun başka bir resource'tan çağrılması.

---

## Phase 1 — Core Foundation · TAMAMLANDI · 2026-08-07

### Ne yapıldı
- Resource iskeleti: `config.lua`, `shared/constants.lua` (enum'lar,
  log event kodları, damage eşikleri), `shared/types.lua` (struct
  factory'leri), `shared/utilities.lua` (Clamp/Round/DamageToCondition/
  FreezeShape/AABB yardımcıları).
- `shared/validators.lua`: grid→substation→transformer referans
  bütünlüğü, district varlığı, district'in tek grid'e ait olması,
  powerPolicy şekil doğrulaması, visual profile referansı, custom zone
  şekil doğrulaması. Hata varsa `server/main.lua` state publish etmeyi
  reddeder.
- `server/logging.lua`: structured log (`Log.event/warn/error/debug`).
- Bridge katmanı: `bridge/loader.lua` (auto-detect + assembly) ve
  framework (qbcore/standalone), inventory (ox_inventory/qb/none),
  target (qb-target/textui/none) adaptörleri.

### Dosyalar
- `config.lua`, `shared/constants.lua`, `shared/types.lua`,
  `shared/utilities.lua`, `shared/validators.lua`, `server/logging.lua`
- `bridge/loader.lua`, `bridge/framework/{standalone,qbcore}.lua`,
  `bridge/inventory/{ox_inventory,qb,none}.lua`,
  `bridge/target/{qb_target,textui,none}.lua`

### Test durumu
- [x] Kod incelemesi: dosyalar sözdizimsel olarak tutarlı, yükleme sırası
      `fxmanifest.lua`'da (utilities → constants → ... → bridge) doğru
      kuruldu — `Utils.FreezeShape` constants.lua'nın sonunda çağrıldığı
      için utilities'in önce yüklenmesi gerekiyordu, bu düzeltildi.
- [x] Oyun içi (2026-08-07): `ensure gnsh-blackout` temiz başladı, konsolda
      beklenmeyen hata yok. `restart gnsh-blackout` hatasız (bkz. Phase 8
      cleanup testi). Bridge doğru adaptörleri seçti (qbcore + ACE admin
      kontrolü çalıştı, düzeltme sonrası).

### Bilinen eksikler / ertelenenler
- Bridge target adaptörleri (qb-target, textui) kayıtlı ama hiç
  `RegisterInteractable` çağrılmıyor — gerçek kullanım Phase 12
  (sabotaj/tamir interactable'ları).
- Inventory adaptörleri (`HasItem`/`RemoveItem`/`AddItem`) tanımlı ama
  hiçbir yerden çağrılmıyor — Phase 12-13.

### Sonraki adım
Phase 2.

---

## Phase 2 — GTA District Manager · TAMAMLANDI · 2026-08-07

### Ne yapıldı
- `shared/districts.lua`: ~40 GTA district kodu (spec §5'teki 14 kod +
  ek yaygın bölgeler), her biri için label + **yaklaşık** AABB.
  **Bu AABB değerleri oyun dosyalarından çıkarılmadı, genel harita
  bilgisinden tahmin edildi** — production öncesi `/districtaudit` ile
  kalibre edilmesi gerekiyor (dosyanın başındaki yorum bunu detaylı
  açıklıyor).
- `client/zone_resolver.lua`: `GetNameOfZone` native sarmalayıcısı
  (client-only, otoriter kaynak).
- `server/zone_resolver.lua`: AABB tabanlı lookup (server'da
  `GetNameOfZone` yok — bu yaklaşımın nedeni).
- `client/district_manager.lua`: movement-aware polling (500ms, 5m eşik),
  debounce/hysteresis (350ms stabilite), teleport force-resolve (150m
  sıçrama eşiği).
- `client/state.lua`: §60 cache tablosu.
- `client/debug.lua`: `/showdistrict`, `/districtaudit` (client-server
  karşılaştırma, mismatch loglar).

### Dosyalar
- `shared/districts.lua`, `client/zone_resolver.lua`,
  `server/zone_resolver.lua` (grid lookup kısmı Phase 4'e bağımlı),
  `client/district_manager.lua`, `client/state.lua`, `client/debug.lua`

### Test durumu
- [x] Oyun içi (2026-08-07): Sandy içinde `showdistrict` → doğru kod (SANDY).
      Sandy'den komşu district'e geçiş ve geri dönüş debounce/flicker
      olmadan doğru commit edildi.
- [ ] Grapeseed/Downtown/Vespucci gibi diğer district'lerde ayrıca
      denenmedi — sadece Sandy sınırı test edildi.
- [ ] `/districtaudit` ile AABB tablosunun kalibrasyonu — **hâlâ
      yapılmadı, production öncesi zorunlu**. Bu oturumda `SanAnd` ve
      `OCEANA` kodları için "unmapped code" uyarısı görüldü (tabloda
      olmayan, zararsız — oyuncu su/deniz üzerindeyken).

### Bilinen eksikler / ertelenenler
- AABB tablosu tahminidir, doğrulanmadan güvenilmemeli (README ve dosya
  başlığında açıkça belirtildi).
- ~40 district kodu var, tam GTA V zone listesi (~90+) değil — ihtiyaç
  oldukça `shared/districts.lua`'ya eklenmeli.

### Sonraki adım
Phase 3.

---

## Phase 3 — Hybrid Zone Resolver · TAMAMLANDI · 2026-08-07

### Ne yapıldı
- `shared/zone_resolver.lua` (`ZoneGeometry`): framework'ten bağımsız
  ray-casting polygon testi ve radius testi, AABB ön-filtreleme,
  priority+alan bazlı sıralama.
- `Config.Zones`, `Config.ResolverPriority` (`custom_zone` → `gta_native`
  → `Config.DefaultGrid`).
- Client ve server `ResolvePosition` fonksiyonları aynı önceliği
  uyguluyor, sadece district kaynağı farklı (native vs AABB).

### Dosyalar
- `shared/zone_resolver.lua`, `config.lua` (Config.Zones/ResolverPriority)

### Test durumu
- [x] Unit: `tests/spec/zone_resolver_spec.lua` — polygon içi/dışı, L
      şekilli (dışbükey olmayan) polygon, Z aralığı reddi, radius sınır
      testi, örtüşen zone'larda priority/alan tie-break. **Dosya yazıldı,
      bu oturumda lokal Lua olmadığı için çalıştırılamadı.**
- [ ] Oyun içi: örtüşen custom zone testi — **yapılmadı**.

### Bilinen eksikler / ertelenenler
- Yok — Phase 3 kapsamı tam.

### Sonraki adım
Phase 4.

---

## Phase 4 — Grid Topology · TAMAMLANDI · 2026-08-07

### Ne yapıldı
- `shared/grids.lua`: `blaine_south` grid'i (SANDY/HARMO/DESRT),
  `sandy_substation_01` substation'ı, `sandy_tr_01` transformer'ı.
  Substation ve transformer ayrı tablo (spec §12) — MVP 1:1 ama data
  modeli çoklu transformer'a hazır.
- `server/grid_manager.lua`: startup'ta ters indeksler
  (districtToGrid, transformerToSubstation, substationToGrid,
  gridToTransformers) — runtime'da tüm lookup O(1).
- `server/substation_manager.lua`: substation state'i her zaman alt
  transformer'lardan türetilir, kendi state'i yok.

### Dosyalar
- `shared/grids.lua`, `server/grid_manager.lua`,
  `server/substation_manager.lua`

### Test durumu
- [x] Oyun içi (2026-08-07): `griddebug` (client) `blaine_south` grid'ini
      ve doğru state'i (Power/Level/Revision) bastı. Server console'da
      `griddebug blaine_south` ayrıca denenmedi ama server tarafı zaten
      `setgridpower`/replication üzerinden dolaylı doğrulandı.
- Not: `shared/grids.lua` Cfx-özel backtick model-hash literali
  (`` `prop_generator_01b` ``) içerdiği için düz Lua interpreter ile
  **yüklenemez** — bu yüzden unit testler bu dosyayı hiç yüklemiyor,
  sentetik grid fixture'ları kullanıyor (bkz. `tests/run.lua` başlık
  yorumu). Bu, spesifik olarak bu dosyanın FXServer içinde test
  edilmesi gerektiği anlamına gelir.

### Bilinen eksikler / ertelenenler
- Substation/transformer koordinatları (`vector3(1961.0, 3740.0, 32.2)`
  civarı) yer tutucu — gerçek bir prop/MLO seçilene kadar kesin değil,
  Phase 1-8 kabul kriterleri için önemli değil.

### Sonraki adım
Phase 5.

---

## Phase 5 — Transformer Model · TAMAMLANDI · 2026-08-07

### Ne yapıldı
- `server/transformer_manager.lua`: state (ONLINE/DEGRADED/OFFLINE/
  REPAIRING/RECOVERING/COOLDOWN) ve condition (HEALTHY→DESTROYED) ayrı
  tutuluyor (spec §13).
- **Açık geçiş tablosu** (`ALLOWED_TRANSITIONS`): izinsiz geçiş
  reddedilir + loglanır (`STATE_TRANSITION_REJECTED`). Örn.
  OFFLINE→ONLINE doğrudan yasak, REPAIRING→RECOVERING→ONLINE üzerinden
  geçmeli.
- `SetDamage(id, damage, reason)`: condition'ı yeniden türetir;
  `Config.OfflineAtCondition` (DESTROYED) eşiğinde state'i zorla
  OFFLINE'a çeker (`force = true`, geçiş tablosunu bypass eder —
  gerçek bir trafo patlamadan önce izin istemez).

### Dosyalar
- `server/transformer_manager.lua`

### Test durumu
- [x] Oyun içi (2026-08-07), dolaylı: `/setgridpower blaine_south 0`
      `SetState(..., OFFLINE, force=true)` çağırdı, grid gerçekten
      BLACKOUT'a düştü — mutator çalışıyor.
- [ ] `/setdamage sandy_tr_01 100` → OFFLINE zorlanıyor mu, `/setdamage
      sandy_tr_01 38` → condition MODERATE_DAMAGE ama state değişmiyor mu
      (spec §13 örneği, damage yolu spesifik) — **doğrudan denenmedi**.
- Not: Bu modül `Log`/`GridManager`/`Replication`'a bağımlı olduğu için
  unit test kapsamına alınmadı (plan'ın Test stratejisi bölümü zaten bu
  dosyayı listelemiyor) — doğrulama tamamen oyun içi.

### Bilinen eksikler / ertelenenler
- Persistence yok (Phase 14) — restart'ta config default'larıyla
  (hepsi ONLINE/HEALTHY) açılır, bu tasarım gereği.

### Sonraki adım
Phase 6.

---

## Phase 6 — Power Calculator · TAMAMLANDI · 2026-08-07

### Ne yapıldı
- `server/power_calculator.lua`: saf fonksiyon, yan etkisiz.
  PRIMARY/ANY/ALL/REQUIRED_COUNT dört policy implementasyonu.
  WEIGHTED_CAPACITY/PRIMARY_BACKUP/CUSTOM enum'da tanımlı ama validator
  tarafından reddediliyor ("not implemented yet").
- Üç katmanlı değerlendirme: önce sadece ONLINE trafo'larla policy
  test edilir (tam güç); olmazsa ONLINE+DEGRADED ile test edilir
  (degraded güç, `Config.DegradedLevel`); o da olmazsa blackout.

### Dosyalar
- `server/power_calculator.lua`

### Test durumu
- [x] Unit: `tests/spec/power_policy_spec.lua` — 4 policy × 1-3 trafolu
      grid × ONLINE/DEGRADED/OFFLINE kombinasyonları, DegradedLevel'ın
      BlackoutThreshold altına düşmesi edge case'i dahil. **Dosya
      yazıldı, bu oturumda lokal Lua olmadığı için çalıştırılamadı.**
- [x] Oyun içi (2026-08-07), dolaylı: PRIMARY policy — grid'in tek
      trafosu `force`'la OFFLINE yapılınca (`primaryOnline = false`)
      `Calculate()` doğru şekilde BLACKOUT döndü, grid gerçekten karardı.
      ANY/ALL/REQUIRED_COUNT ayrıca test edilmedi (grid'de tek trafo var).

### Bilinen eksikler / ertelenenler
- WEIGHTED_CAPACITY vb. sonraki iterasyon (spec §73).

### Sonraki adım
Phase 7.

---

## Phase 7 — State Replication · TAMAMLANDI · 2026-08-07

### Ne yapıldı
- `server/replication.lua`: granular `GlobalState['infra:grid:<id>']` /
  `GlobalState['infra:district:<code>']` key'leri (tek dev tablo değil,
  spec §19). Server-wide monotonik revision sayacı — bir grid
  değiştiğinde grid + etkilenen tüm district'ler **aynı** revision ile
  atomik olarak yazılır.
- `Replication.Init()`: startup'ta revision 0 ile zorla publish (aksi
  halde "her şey default ONLINE" durumu hiç yazılmazdı).
- `Replication.RecalculateGrid()`: değişiklik yoksa yazma yok
  (idempotent), değişiklik varsa `powerLost`/`powerRestored`/
  `powerLevelChanged` event'lerini hem server-local hem
  `TriggerClientEvent(-1, ...)` ile broadcast eder.
- `server/api.lua`: `IsGridPowered`, `IsDistrictPowered`,
  `IsPositionPowered`, `GetGridState`, `GetDistrictState`,
  `GetTransformerState`, `GetSubstationState`, `GetActiveIncident`
  (Phase 11'e kadar `nil`, imza kilitli).
- `client/main.lua`: StateBag change handler (eski revision'ı yok sayar,
  spec §20), late-join/grid-geçişi durumunda `GlobalState`'i doğrudan
  okuyup anlık uygulama (flicker sequence tekrar oynatılmıyor, spec §32),
  client-side export'lar.

### Dosyalar
- `server/replication.lua`, `server/api.lua`, `client/main.lua`

### Test durumu
- [x] Oyun içi (2026-08-07): `/setgridpower blaine_south 0` sonrası
      `griddebug` revision'ın 0→1 arttığını gösterdi — grid+district
      atomik publish çalışıyor. `restart gnsh-blackout` sonrası state
      tutarlı (Phase 8 cleanup testiyle birlikte doğrulandı).
- [ ] Hızlı ardışık değişimlerde stale update reddi, gerçek
      reconnect/late-join testi — **yapılmadı** (tek oturumluk test).
- Not: Bu modül `GlobalState`/event native'lerine bağımlı, unit test
  kapsamı dışında (plan'ın Test stratejisi bölümüyle tutarlı).

### Bilinen eksikler / ertelenenler
- Yok — Phase 7 kapsamı tam.

### Sonraki adım
Phase 8.

---

## Phase 8 — Sandy Native Blackout PoC · TAMAMLANDI · 2026-08-07

### Ne yapıldı
- `profiles/sandy.lua`: `NATIVE_CLIENT_GATE` modu, `districts = {SANDY}`.
- `client/visual/native_blackout.lua`: adapter contract (Apply/Remove/
  IsApplied/ForceSync/Reset), tamamı idempotent, tüm native çağrıları
  `pcall` ile sarılı (spec §62 — visual hata logical state'i asla
  etkilemez).
- `client/visual/ownership.lua`: ref-count iskeleti (spec §27) — Phase 8
  tek asset kullanıyor ama API N-owner senaryosuna hazır.
- `client/visual/manager.lua`: `infra:powerStateChanged` event'ini
  dinler (startup/late-join, gerçek güç değişimi, district geçişi —
  hepsi aynı event üzerinden), ownership üzerinden Apply/Remove kararı
  verir.
- `server/debug.lua`: `/setgridpower`, `/setdamage` (admin-gated),
  `/griddebug`, `/showtransformers`, `/showincidents` (stub),
  `/powerdebug`, ve `/districtaudit`'in server tarafı.
- `client/debug.lua` genişletildi: `/griddebug` (client görünümü),
  `/visualprofile`, `/reloadvisual`.

### Dosyalar
- `profiles/sandy.lua`, `client/visual/{native_blackout,ownership,
  manager}.lua`, `server/debug.lua`, `client/debug.lua` (ek)

### Test durumu
- [x] Oyun içi §75 senaryosu (2026-08-07), çekirdek kısmı doğrulandı:
      SANDY ONLINE → `/setgridpower blaine_south 0` → Sandy'de native
      blackout uygulandı → komşu district'e geçiş → blackout kalktı →
      Sandy'ye dönüş → blackout geri geldi. Admin ACE kurulumu ilk denemede
      yanlıştı (`command` yerine `admin` objesi gerekiyordu), düzeltilip
      chat'ten çalıştırıldı.
- [x] Resource restart (blackout aktifken) sonrası takılı blackout **yok**
      — cleanup (spec §61) doğrulandı, ışıklar restart sonrası normale
      döndü.
- [ ] `/setgridpower blaine_south 1` ile açık şekilde geri açma ayrıca
      test edilmedi (restart zaten default ONLINE'a döndürdü).
- [ ] İkinci client senkron testi — **yapılmadı** (tek client test ortamı).
- [ ] `/setdamage`, `/showtransformers`, `/visualprofile`, `/reloadvisual`
      ayrıca denenmedi.

### Bilinen eksikler / ertelenenler
- Flicker/transition sequence (spec §30-31) **yok** — blackout ON/OFF
  anlık. Bu bilinçli bir erteleme (Phase 15 "Transition Engine").
  `profiles/sandy.lua`'daki `effects` alanları (sparks/smoke/sound)
  şimdilik no-op.
- Hybrid visual (dark motel sign vb.) yok — Phase 17.
- `SET_ZONE_ENABLED` hiç kullanılmadı (RULE 4 gereği) — deneysel testi
  Phase 10'un ayrı lab resource'una ait.

### Sonraki adım
Phase 9-22 (sabotaj, tamir, incident, persistence, city expansion) —
ayrı bir çalışma turu. Önce bu Phase 1-8 çıktısının FXServer'da gerçekten
çalıştığı doğrulanmalı.

---

## Phase 9 — Test Dosyaları · TAMAMLANDI · 2026-08-07

### Ne yapıldı
- `tests/run.lua`: framework-free test harness, `vector3` shim'i ile
  `config.lua` → `shared/utilities.lua` → `shared/constants.lua` →
  `shared/types.lua` → `shared/districts.lua` →
  `shared/zone_resolver.lua` → `shared/validators.lua` →
  `server/power_calculator.lua` sırasıyla yüklenir. `shared/grids.lua`
  bilinçli olarak **yüklenmiyor** (Cfx-özel backtick literal, düz Lua'da
  parse hatası verir) — validator testleri sentetik fixture kullanıyor.
- `tests/spec/damage_model_spec.lua` — 12 test, tüm eşik sınırları.
- `tests/spec/power_policy_spec.lua` — 15 test, 4 policy × state
  kombinasyonları + DegradedLevel/BlackoutThreshold edge case.
- `tests/spec/validators_spec.lua` — 12 test, geçerli config + her hata
  türü (bilinmeyen district, çakışan grid, eksik primary, vb.).
- `tests/spec/zone_resolver_spec.lua` — 12 test, polygon/radius/Z
  aralığı/priority/tie-break.

### Dosyalar
- `tests/run.lua`, `tests/spec/{damage_model,power_policy,validators,
  zone_resolver}_spec.lua`

### Test durumu
- [ ] **Bu oturumda çalıştırılamadı** — makinede `lua`/`lua5.4`/`luajit`
      PATH'te bulunamadı (`command -v` ile kontrol edildi). Dosyalar
      elle gözden geçirildi (mantık, global sızıntı önleme, cache
      invalidation) ama gerçek "N passed, 0 failed" çıktısı görülmedi.
- Kurulum talimatı: `README.md` → "Tests" bölümü.

### Bilinen eksikler / ertelenenler
- `server/transformer_manager.lua`'nın geçiş tablosu unit test edilmedi
  (Log/GridManager/Replication bağımlılığı) — oyun içi doğrulanmalı.

### Sonraki adım
Phase 13 (Repair System & Diagnostics).

---

## Phase 11 — Incident System · TAMAMLANDI (redo) · 2026-08-08

Bu bölüm önceki bir oturumda planlama akışı dışında eklenmiş, kullanıcı
durumundan memnun kalmayınca gerçek dosyalar okunarak yeniden gözden
geçirilmiş ve düzeltilmiştir. İlk sürümün "TAMAMLANDI" notu yanıltıcıydı —
gerçekte olay yaşam döngüsü tek yönlüydü (bkz. altta).

### İlk sürümde bulunan gerçek hatalar
1. `IncidentManager.UpdateStatus()` kodda tanımlıydı ama **hiçbir yerden
   çağrılmıyordu** (tüm ağaç `grep` ile tarandı, doğrulandı). Bir trafoda
   ilk incident oluştuktan sonra `transformerActiveMap` sonsuza kadar
   dolu kalıyordu — admin `/setgridpower ... 1` ile gücü geri verse bile
   incident **hiçbir zaman** RESOLVED olamıyordu.
2. `gridActiveMap[gridId]` tek slot'tu — aynı grid'de ikinci bir incident
   açılırsa birincinin kaydı sessizce kayboluyordu.
3. Kayıt şekli `shared/types.lua`'daki `Types.NewIncident()` fabrikasından
   (spec §45 DB kolon adlarıyla eşleşen `incidentId` alanı) sapıp kendi
   `id` alanını icat etmişti — Phase 14 persistence'ı bozacaktı.
4. `incidentHistory` sınırsız büyüyordu (uzun uptime'da bellek sızıntısı).

### Düzeltmeler (bu oturum)
- `server/transformer_manager.lua`: `SetState()` bir trafo `ONLINE`'a
  geçtiğinde (admin restore veya ileride gerçek tamir), o trafonun aktif
  incident'ını otomatik `RESOLVED` yapan bir forward-reference hook
  eklendi — döngü artık gerçekten kapanıyor.
- `server/incident_manager.lua`: kayıt şekli `Types.NewIncident()`'a
  taşındı (`incidentId` alanı, `server/debug.lua`'daki `/showincidents`
  güncellendi); `gridActiveMap` set'e çevrildi (`GetActiveIncidentForGrid`
  artık en yüksek severity'li — eşitlikte en eski — incident'ı seçiyor);
  `Config.MaxIncidentHistory` (200) ile `incidentHistory` sınırlandı.

### Dosyalar
- `server/incident_manager.lua` (yeniden yazıldı), `server/transformer_manager.lua` (hook eklendi), `server/debug.lua` (alan adı düzeltmesi), `config.lua` (`Config.MaxIncidentHistory`)

### Test durumu
- [x] Kod incelemesi: yaşam döngüsü artık ACTIVE→RESOLVED'a gerçekten kapanıyor, alan adları tutarlı.
- [ ] Oyun içi test: `/setgridpower ... 1` sonrası `/showincidents`'ın gerçekten boşaldığı — **henüz doğrulanmadı**, bir sonraki oturumda test edilecek.

---

## Phase 12 — Sabotage Framework · TAMAMLANDI (redo) · 2026-08-08

Aynı şekilde önceki oturumda planlama dışı eklenmiş ve **fiilen
çalışmıyordu** — kullanıcı memnun olmayınca gerçek dosyalar okunarak
tam bir yeniden geçiş yapıldı.

### İlk sürümde bulunan gerçek hatalar
1. **Sabotaj tamamen çalışmıyordu.** `Config.Sabotage` `config.lua`'ya
   hiç eklenmemişti (sadece `Config.Repair` eklenmişti — `grep` ile
   doğrulandı). Her `/requestSabotage` "Geçersiz sabotaj türü." ile
   reddediliyordu.
2. Sabotaj türü (termit/C4) interaction session'ına hiç taşınmıyordu —
   session `action = 'SABOTAGE'` (sabit string) ile açılıyor, sonuçta
   türü geri bulmaya çalışan kırık bir eşleştirme döngüsü hep `thermite`
   ile sonuçlanıyordu. C4 kullanan oyuncu termit item'ıyla ve termit
   hasarıyla ücretlendirilecekti.
3. **C4 hiç seçilemiyordu.** `bridge/target/standalone.lua` E tuşunda
   her zaman `options[1]`'i (termit) çalıştırıyordu, ikinci seçeneğe
   erişim yoktu.
4. **Minigame sonucu güvenilmezdi (spec §36 ihlali).** `ox_lib` kurulu
   ama `@ox_lib/init.lua` `fxmanifest.lua`'ya hiç eklenmemişti, `lib`
   global'i her zaman `nil` idi; `qb-lock` de kurulu değildi. Her sabotaj
   sessizce "4 saniye bekle, otomatik başarı" fallback'ine düşüyordu —
   herkes hiçbir şey yapmadan kazanabiliyordu.
5. Sabotaj cooldown'u yoktu (spec §44 SABOTAGE kategorisi) — bir oyuncu
   başarısız denemeden hemen sonra aynı trafoyu spam'leyebiliyordu.
6. `client/sabotage.lua` `/infratest` komutunu bir konum/mesafe debug
   print'i olarak kullanıyordu — `README.md`'nin gelecekte gerçek bir
   in-game unit-test runner için ayırdığı isimle çakışıyordu.

### Düzeltmeler (bu oturum)
- `config.lua`: `Config.Sabotage` bloğu eklendi — mevcut item'lar
  (`thermite`, `plastic`, yeni item tanımı yok), `cooldownSec = 30`,
  `requireItem = true`.
- `server/sabotage.lua`: `InteractionManager.StartSession` artık gerçek
  `sabotageType`'ı `action` olarak açıyor; `submitSabotageResult` `cfg`'yi
  doğrudan `session.action`'dan (client'tan değil, server'ın kendi kayıt
  ettiği değerden) türetiyor — kırık eşleştirme döngüsü tamamen silindi;
  trafo bazlı cooldown eklendi.
- `client/sabotage.lua`: fallback minigame "bekle, otomatik kazan"
  yerine gerçek zamanlı bir reaksiyon testine (rastgele gecikme + 800ms
  pencerede E'ye basma) çevrildi; `/infratest` → `/infracoords` olarak
  yeniden adlandırıldı.
- `bridge/target/standalone.lua`: birden fazla seçenekli etkileşimlerde
  artık `menuv` menüsü açılıyor (kurulu, `[standalone]/menuv`), her
  seçenek gerçekten çalıştırılabiliyor; menuv yoksa eski "ilk seçeneği
  çalıştır" davranışına düşüyor (fail-open). Menuv entegrasyonu tek bir
  fonksiyonda (`openOptionsMenu`) izole tutuldu — kullanıcı ileride özel
  bir NUI ile değiştirileceğini belirtti, bu değişiklik sadece bu
  fonksiyona dokunacak.
- `fxmanifest.lua`: `@ox_lib/init.lua` gerçekten eklendi, `dependency
  'ox_lib'` deklare edildi (artık gerçek bir sert bağımlılık — önceki
  "no dependency" yorumu artık doğru değildi, düzeltildi).

### Dosyalar
- `server/sabotage.lua` (yeniden yazıldı), `client/sabotage.lua` (minigame + komut düzeltmesi), `bridge/target/standalone.lua` (menuv entegrasyonu), `config.lua` (`Config.Sabotage`), `fxmanifest.lua` (ox_lib dependency + import)

### Test durumu
- [x] Kod incelemesi: session action akışı, cooldown, menuv fallback zinciri, ox_lib liveness kontrolü doğrulandı.
- [x] Oyun içi test (2026-08-08, ikinci tur): **iki yeni gerçek hata bulundu ve düzeltildi** (aşağıya bakın) — Termit/C4 seçim adımı bu yüzden çalışmıyordu.

### Oyun içi testte bulunan ek hatalar (redo'nun redo'su)

Kullanıcı `/tptrafo` + E tuşuna bastığında hiçbir şey olmuyordu, F8 konsolunda:
`SCRIPT ERROR: @ox_lib/imports/points/client.lua:118: attempt to call a boolean value (method 'nearby')`

1. **Menuv fix'i hiç çalışmayan dosyaya yapılmıştı.** Bu sunucuda `UseTarget false` ve ox_lib gerçekten çalışıyor (bu oturumda biz açtık) — `bridge/loader.lua:65`'in `resolveTargetKey()`'i bu kombinasyonda `standalone` değil **`textui`** adaptörünü seçiyor. Önceki oturumun menuv entegrasyonu `bridge/target/standalone.lua`'ya yapılmıştı ama o dosya bu sunucuda hiç aktif olmuyor.
2. **`bridge/target/textui.lua`'da field adı çakışması vardı.** ox_lib'in kendi `imports/points/client.lua:117-118` döngüsü `point.nearby`'yi **fonksiyon** bekliyor (`if point.nearby then point:nearby() end`), ama dosya `self.nearby`'yi bool flag olarak kullanıyordu (`onEnter`'da `true`). İlk yaklaşınca ox_lib'in kendi callback slotu bool ile eziliyor, bir sonraki tick'te boolean'ı fonksiyon gibi çağırmaya çalışıp crash oluyordu — interaction tamamen kırıktı, sadece C4 değil hiçbir seçenek çalışmıyordu.

### Düzeltmeler (bu tur)
- Yeni dosya `bridge/target/menu_helper.lua`: `MenuHelper.OpenOptions(spec)` — menuv mantığı `standalone.lua`'dan çıkarılıp paylaşılan tek yere taşındı (kullanıcının "ileride NUI ile değiştireceğiz" notu artık iki değil tek dosyayı etkiliyor).
- `bridge/target/standalone.lua`: local `openOptionsMenu` silindi, `MenuHelper.OpenOptions(spec)` çağrılıyor.
- `bridge/target/textui.lua`: `nearby` bool flag'i tamamen kaldırıldı; asıl per-tick callback ox_lib'in beklediği `function point:nearby()` adıyla tanımlandı, içinde `MenuHelper.OpenOptions(spec)` çağrılıyor — artık bu adaptör de çok seçenekli menüyü destekliyor.
- `fxmanifest.lua`: `bridge/target/menu_helper.lua` diğer üç target adaptöründen önce yükleniyor.

### Üçüncü tur — `MenuV` global'i hiç yoktu (2026-08-08)

Yukarıdaki düzeltmelerden sonra menü açılmaya çalışırken yeni hata:
`SCRIPT ERROR: @gnsh-blackout/bridge/target/menu_helper.lua:36: attempt to index a nil value (global 'MenuV')`

**Kök sebep:** FiveM'de global değişkenler resource'lar arası paylaşılmaz — her resource kendi izole Lua state'inde çalışır. `menuv` resource'unun kendi `menuv.lua`'sında tanımladığı `MenuV = setmetatable(...)` global'i SADECE menuv'in kendi Lua state'inde var. `menuv/README.md` bunu açıkça belirtiyor: "To use MenuV you must add **@menuv/menuv.lua** in your **fxmanifest.lua**" — yani `MenuV`'e erişmek için onun kaynak dosyasını kendi `fxmanifest.lua`'na (tıpkı `@ox_lib/init.lua` gibi) import etmen gerekiyor. `bridge/target/menu_helper.lua`'daki `GetResourceState('menuv') ~= 'started'` kontrolü menuv'in ÇALIŞIP ÇALIŞMADIĞINI doğru tespit ediyordu ama bu, `MenuV` global'inin bizim resource'umuzda var olmasını sağlamıyordu — ikisi bağımsız şeyler.

### Düzeltme
- `fxmanifest.lua`: `'@menuv/menuv.lua'` client_scripts'e eklendi (ox_lib import'unun hemen yanına), `dependency 'menuv'` eklendi — artık ox_lib gibi gerçek bir sert bağımlılık.
- `bridge/target/menu_helper.lua`: `GetResourceState` fallback yorumunun artık pratikte ulaşılamaz (defensive-only) olduğu not edildi.

### Dördüncü tur — `Config` global'i menuv tarafından eziliyordu (2026-08-08, kullanıcı buldu)

`MenuV` fix'inden sonra her boot'ta `bridge/loader.lua:45: attempt to index a nil value (field 'Bridge')` + zincirleme `Config.Debug`/zone_resolver/sabotage hataları görüldü — `Config` tablosu var ama içi boştu. Kök sebep kullanıcı tarafından bulundu: `menuv/menuv.lua` kendi ayarları için bare global `Config` tanımlıyor; `@menuv/menuv.lua` import edildiğinde bu, gnsh-blackout'un kendi `Config`'ini (config.lua'nın az önce doldurduğu) client tarafında sessizce eziyordu. Düzeltme: `config.lua` `_G.__GnshBlackoutConfig`'e yedek alıyor, yeni `client/restore_config.lua` menuv import'undan hemen sonra bunu geri yüklüyor.

### Beşinci tur — item üstte olsa da "gerekli eşyanız yok" (2026-08-08)

Oyuncu üstünde 39x thermite + 20x plastic varken sabotaj hâlâ reddediliyordu. Kök sebep: `server.cfg:60`'daki `ensure [standalone]` bütün klasörü (etkin olarak) alfabetik sırayla başlatıyor — `gnsh-blackout` < `ox_inventory` alfabetik olarak, yani `bridge/loader.lua`'nın `resolveInventoryKey()`'i (tek seferlik, `GetResourceState()` anlık görüntüsü) çalıştığı anda ox_inventory henüz başlamamış oluyordu — `Bridge` kalıcı olarak `'none'` inventory adaptörüne (no-op stub) kilitleniyordu, `Bridge.HasItem` her zaman `false` dönüyordu. `ox_lib`/`menuv` için zaten `dependency` vardı (FXServer'ın onları önce başlatmasını garantiliyor), `ox_inventory` için yoktu. Düzeltme: `fxmanifest.lua`'ya `dependency 'ox_inventory'` eklendi.

Ayrıca `server/debug.lua`'ya `/giveitem <playerId> <item> [amount]` admin komutu eklendi — ne qb-core'da ne ox_inventory'de test için hazır bir item verme komutu vardı.

### Altıncı tur — test ergonomisi (2026-08-08)

Kullanıcı isteğiyle üç küçük düzeltme:
- `bridge/target/menu_helper.lua`: seçenek seçilince `menu:Close()` çağrılıyor — menuv varsayılan olarak seçimden sonra kapanmıyor (kaynağında doğrulandı), menü ekranda asılı kalıyordu.
- `server/sabotage.lua`: başarılı sabotajda hasar/incident/patlama artık `SetTimeout(5000, ...)` ile 5sn gecikmeli tetikleniyor (fuse-timer hissi) — önceden skillcheck biter bitmez anında patlıyordu.
- `client/sabotage.lua`: test için skillCheck kısaltıldı (Termit 1 adım `easy`, C4 2 adım `easy`+`medium`, `space` tuşu kaldırıldı — sadece `e`/`r`). **Gerçek zorluk seviyesine dönmek gerekiyor, testin sonunda unutulmamalı.**

### Test durumu (güncel) — İLK BAŞARILI UÇTAN UCA TEST
- [x] Oyun içi test (2026-08-08): Kullanıcı 2x Termit ile trafoyu patlattı, grid BLACKOUT oldu (elektrikler gitti). Menü açılıyor, seçim çalışıyor, item tüketiliyor, hasar/incident/patlama zinciri gerçek oyunda ilk kez uçtan uca doğrulandı.
- [ ] Henüz test edilmedi: skillcheck'i bilerek kaçırma (SABOTAGE_FAILED + hasarsız kalma), cooldown'un ikinci denemeyi engellemesi, C4 ile `plastic` tüketimi + damage=100 farkı, `/setgridpower ... 1` ile incident'ın gerçekten resolve olması (`/showincidents` boşalması).

### Sonraki adım
Phase 13 (Multi-Stage Repair & Diagnostics) — aşağıya bakın.

---

## Phase 13 — Repair System & Diagnostics · TAMAMLANDI (kod) · 2026-08-08

### Ne yapıldı
- `server/repair_manager.lua` (yeni): tüm tamir yaşam döngüsünü server-authoritative yönetiyor. `RepairManager.GetPlan(transformerId)` — trafonun güncel `condition`'ına göre (Config.Repair.stagesByCondition) aşama listesi + malzeme listesi döndüren saf fonksiyon. `StartRepair` — enabled/hasar/aktif-tamir/iş/mesafe/malzeme kontrolleri, `TransformerManager.SetState(OFFLINE→REPAIRING)` (zaten var olan geçiş tablosu, hiçbir değişiklik gerekmedi), incident'ı `REPAIRING`'e çeker, `Config.Repair.persistentRepairProgress` açıksa incident'ın `metadata.repairProgress`'inden kaldığı aşamadan devam eder (spec §38). `AdvanceStage` — her aşama için `InteractionManager.StartSession(src, 'REPAIR:'..stageName, ...)` (sabotage.lua'nın kurduğu authoritative-action deseniyle aynı). `CompleteRepair` — malzemeleri tüketir, `REPAIRING→RECOVERING`, hasarı sıfırlar, `Config.Repair.recoveryDurationSec` sonra `RECOVERING→ONLINE` (bu geçiş zaten var olan ONLINE-hook'unu tetikliyor: incident otomatik resolve oluyor, grid yeniden hesaplanıyor — `transformer_manager.lua`/`incident_manager.lua`'da hiçbir değişiklik gerekmedi).
- `client/repair.lua` (yeni): `runRepairProgress(label, durationMs)` — ox_lib `progressBar` çağıran tek fonksiyon (ilerideki NUI değişimi için izole, `menu_helper.lua`'daki desenin aynısı). `infra:startRepairStage` event'ini dinler, bar bitince `infra:submitRepairStage` gönderir.
- `client/sabotage.lua`: **"Trafoyu Tamir Et" seçeneği bu dosyaya eklendi, client/repair.lua'ya değil** — menuv tek interactable id için tek menü gösteriyor, aynı trafonun tüm seçenekleri (Termit/C4/Tamir) AYNI `options` dizisinde AYNI `Bridge.RegisterInteractable` çağrısında olmalı; iki ayrı dosyadan aynı id'yi register etmek ikincinin birinciyi ezmesine yol açardı (`standalone.lua`/`textui.lua`'nın `activeInteractables[id]=spec` deseni tam replace, merge değil).
- `config.lua`: `Config.Repair` yeniden yazıldı — `requireItem=false→true` (item'lar artık gerçek), `stagesByCondition` (spec §37 damage-based skip), `maxWorkers`, `maxInteractionDistance`, `recoveryDurationSec` eklendi.
- `shared/constants.lua`: `Constants.RepairStage` frozen enum eklendi (spec §37 aşama adları).
- `[qb]/qb-core/shared/items.lua` + `[standalone]/ox_inventory/data/items.lua`: `fuse`/`wiring_kit`/`control_module` gerçek item olarak eklendi (ikon dosyası gerekmedi — ox_inventory'nin `web/images/` klasöründe zaten sadece silah ikonları var, yeni item'lar da placeholder ile render olacak, mevcut craft item'larıyla aynı durum).
- `server/debug.lua`: `/repairdebug <transformerId>` (plan+malzeme listesi basar), `/forcerepair <transformerId>` (admin, aşama akışını atlayıp anında tamir eder — geri kalan sistemi test etmek için).
- `fxmanifest.lua`: iki yeni dosya kaydedildi, versiyon `0.13.0`'a çekildi.

### Dosyalar
- `server/repair_manager.lua` (yeni), `client/repair.lua` (yeni), `client/sabotage.lua` (tamir seçeneği eklendi), `config.lua` (`Config.Repair` yeniden yazıldı), `shared/constants.lua` (`Constants.RepairStage`), `server/debug.lua` (`/repairdebug`, `/forcerepair`), `fxmanifest.lua`, `[qb]/qb-core/shared/items.lua`, `[standalone]/ox_inventory/data/items.lua`

### Bilinçli basitleştirmeler
- Malzemeler aşama başına değil, **tamirin tamamı için** (`Config.Repair.itemsPerCondition`, condition bazlı) kontrol edilip tek seferde (son aşamada) tüketiliyor — spec §39 malzemeleri damage seviyesine bağlıyor, aşama bazlı bir bölüştürme spec'te tanımlı değil, icat etmek yerine var olan şekli korundu.
- Tamir stage'leri iptal edilemez (`canCancel = false`) — sabotage.lua'da da ox_lib progressBar iptal senaryosu yönetilmiyor, aynı tutarlılık.

### Test durumu
- [x] Kod incelemesi + paren/brace dengesi (lokal Lua interpreter yok, statik kontrolün sınırı bu).
- [x] Oyun içi test (2026-08-08): Kullanıcı "sorunsuz" onayladı — tamir akışı çalışıyor. Disconnect/reconnect ortasında kilit/ilerleme senaryosu ayrıca ayrıntılı doğrulanmadı, ileride tekrar bakılabilir.

### Sonraki adım
Phase 14 (Persistence) — aşağıya bakın.

---

## Phase 14 — Persistence · TAMAMLANDI (kod) · 2026-08-08

### Ne yapıldı
- `sql/schema.sql` (yeni): `infrastructure_transformers` + `infrastructure_incidents`, spec §45'teki kolon adlarıyla birebir (snake_case). `Types.NewTransformer`/`Types.NewIncident` alan adları Phase 1'de zaten bu eşlemeye göre seçilmişti, eşleme mekanik oldu.
- `server/persistence.lua` (yeni): oxmysql ile konuşan TEK modül. **Bilinçli olarak yumuşak bağımlılık** — ox_lib/menuv/ox_inventory gibi `dependency` değil; `exports.oxmysql:*` üzerinden, `GetResourceState('oxmysql')` ile korunarak çağrılıyor (tıpkı `bridge/inventory/ox_inventory.lua`'nın `exports.ox_inventory:Search` deseni gibi). oxmysql çalışmıyorsa her fonksiyon güvenli no-op'a düşüyor, resource **başlamayı reddetmiyor** — Phase 1-13 memory-only davranışı aynen çalışmaya devam ediyor. `LoadAll()` boot'ta await edilir (tek seferlik); `SaveTransformer`/`SaveIncident`/`UpdateIncident` fire-and-forget (hot path'leri DB round-trip'iyle bloklamamak için).
- `server/transformer_manager.lua`: `SetState`/`SetDamage`'ın anlamlı mutasyon noktalarına `Persistence.SaveTransformer(rec)` eklendi; yeni `TransformerManager.RestoreState(row)` — boot'ta DB'den okunan satırı geçiş tablosunu bypass ederek doğrudan yazıyor (bu bir "transition" değil, initialization).
- `server/incident_manager.lua`: `CreateIncident`'a `Persistence.SaveIncident`, `UpdateStatus`'a `Persistence.UpdateIncident` eklendi; yeni `IncidentManager.RestoreIncident(incident)` — `CreateIncident`'ı bypass ediyor (yoksa: yeni id üretilir, SQL'e ikinci kez INSERT denenir ve PK çakışmasıyla patlar, ayrıca her restart'ta sahte `incidentCreated` event'i ateşlenirdi).
- `server/main.lua`: `boot()` spec §47 sırasına çekildi: `GridManager.Init()` → `TransformerManager.Init()` → `Persistence.LoadAll()` → `RestoreState` (her satır) → `IncidentManager.Init()` → `RestoreIncident` (her satır) → `Replication.Init()`. `Replication.Init()` grid güç durumunu `TransformerManager`'ın CANLI state'inden hesapladığı için (`buildTransformerList` → `TransformerManager.GetState`), restore sırası doğru olduğu sürece grid/district state otomatik doğru çıkıyor — `Replication`'da hiçbir değişiklik gerekmedi.
- `README.md`: "Persistence (optional)" bölümü eklendi (kurulum adımları).

### Dosyalar
- `sql/schema.sql` (yeni), `server/persistence.lua` (yeni), `server/transformer_manager.lua` (save + restore), `server/incident_manager.lua` (save/update + restore), `server/main.lua` (boot sırası), `README.md`, `fxmanifest.lua` (versiyon `0.14.0`, `server/persistence.lua` kaydedildi)

### Bilinçli basitleştirmeler
- Yazma kuyruğu/toplu flush (plan'da bahsedilmişti) **yapılmadı** — bu ölçekte (tek trafo, tek incident) her mutasyonun kendi fire-and-forget çağrısı yeterli, bir queue+timer sistemi bu aşamada gereksiz karmaşıklık olurdu.
- `started_by`/`repaired_by` oyuncunun geçici server `source`'unu saklıyor (kalıcı bir kimlik değil) — Phase 11/12'nin bellek-içi davranışıyla aynı, bu phase'in kapsamı değil.
- `infrastructure_substations`/`infrastructure_maintenance` yok — spec §45 zaten "ileride" diyor, substation state hep türetilir.

### Oyun içi testte bulunan hata: grid hiç blackout'a düşmüyordu

Kullanıcı sabote etti, `/showtransformers` doğru şekilde `OFFLINE/DESTROYED/damage=100` gösterdi, `/showincidents` incident'ı gösterdi — ama `/griddebug blaine_south` hâlâ `Power: ON, Status: ONLINE` basıyordu. Server konsolunda tekrarlayan bir `[warn] RecalculateGrid called before Replication.Init() established a baseline` satırı vardı.

**Kök sebep:** `server/persistence.lua`, `refresh` yapılmadan sadece `restart` ile yüklenmemişti (aynı `menu_helper.lua` hikayesi) — `Persistence` global'i tanımsızdı. `server/main.lua`'nın yeni `boot()` kodu ise `local persisted = Persistence.LoadAll()` satırında bunu **korumasız** çağırıyordu (`if Persistence then` deseni yoktu, projenin her yerindeki soft-dependency felsefesine aykırı) — `Persistence` nil olunca `boot()` tam bu satırda patlıyor, `IncidentManager.Init()` ve `Replication.Init()`'e hiç ulaşamıyordu. `IncidentManager` yine de çalışıyor göründü çünkü onun local tabloları dosya yüklenirken zaten boş tanımlı (`Init()` çağrılmasa da çalışır) — ama `Replication`'ın `gridStates` tablosu SADECE `Init()` içinde dolduruluyor, o hiç çalışmayınca `RecalculateGrid` her seferinde "henüz baseline yok" diyip sessizce hiçbir şey yapmadan çıkıyordu.

**Düzeltme:** `server/main.lua`: `Persistence.LoadAll()` çağrısı `Persistence and Persistence.LoadAll() or {...}` şekline çekildi — artık `Persistence` her ne sebeple olursa olsun yüklenmemiş olsa bile `boot()` çökmeden Phase 1-13 memory-only davranışına düşüyor.

### İkinci tur — yazmalar hiç DB'ye ulaşmıyordu (2026-08-08)

Yukarıdaki düzeltmeden sonra: sabote et → `/showtransformers` doğru (OFFLINE/DESTROYED) → `restart gnsh-blackout` → **elektrik geri geldi** (yanlış — kalıcı olması gerekiyordu). DB'yi direkt kontrol ettim: `infrastructure_transformers` VE `infrastructure_incidents` **tamamen boştu** (0 satır) — yani restore'un bir kusuru değil, hiçbir şey hiç kaydedilmemişti.

**Kök sebep:** `server/persistence.lua`'nın ilk hâli oxmysql'i "yumuşak bağımlılık" olarak tutmak için ham `exports.oxmysql[method](exports.oxmysql, query, params, cb)` çağrısı kullanıyordu. Bu, oxmysql'in kendi resmi `lib/MySQL.lua` sarmalayıcısının kullandığı gerçek çağrı imzasıyla uyuşmuyordu (o `nil` + çağıran-resource-adı + ekstra bir flag geçiyor, benim kodum geçmiyordu) — yazma çağrıları sessizce hiçbir şey yapmıyordu. **MenuV hatasıyla birebir aynı hata sınıfı**: dokümante edilmemiş bir resource-arası çağrı kuralını doğrulamadan varsaymak.

**Düzeltme:** `server/persistence.lua` tamamen `@oxmysql/lib/MySQL.lua` import'unu (oxmysql'in kendi resmi Lua sarmalayıcısı, `@ox_lib/init.lua` ile aynı desen) kullanacak şekilde yeniden yazıldı — `MySQL.query.await(...)`, `MySQL.insert(...)`, `MySQL.update(...)`. `fxmanifest.lua`'ya `dependency 'oxmysql'` + import eklendi — artık ox_lib/menuv/ox_inventory gibi gerçek bir sert bağımlılık (pratikte zaten öyleydi, qb-core de oxmysql gerektiriyor).

### Dosyalar (ikinci tur)
- `server/persistence.lua` (yeniden yazıldı), `fxmanifest.lua` (`@oxmysql/lib/MySQL.lua` import + `dependency 'oxmysql'`), `README.md`

### Test durumu
- [x] Kod incelemesi + tüm resource genelinde paren/brace taraması (temiz).
- [x] Oyun içi testte iki gerçek hata bulundu ve düzeltildi (yukarıda) — DB'ye yazma artık test edilecek.
- [x] Oyun içi test (2026-08-08): kullanıcı onayladı — `refresh`+`restart` sonrası sabotaj kalıcı, restart'ta elektrik geri gelmiyor.

### Sonraki adım
Phase 15 (Transition Engine) — aşağıya bakın.

---

## Phase 15 — Transition Engine · TAMAMLANDI (kod) · 2026-08-08

### Ne yapıldı
- `client/visual/transition.lua` (yeni): saf sekanslayıcı, var olan `NativeBlackout.Apply/Remove` adaptörünü zaman çizelgesine göre sürüyor — yeni native yok, yeni adaptör yok. `Transition.PlayBlackout(profile, onComplete)` / `PlayRecovery(...)` profildeki `blackoutSequence`/`recoverySequence` listelerini (`{ at = saniye, action = 'apply'|'remove'|'ptfx'|'sound' }`) sırayla oynatıyor. **İptal garantisi**: her sekans artan bir `sequenceToken` taşıyor, her `Wait()`'ten sonra kontrol ediliyor — sekans ortasında yeni bir güç olayı gelirse eski sekans sessizce durur, artık-doğru-olmayan bir state'i asla yeniden uygulamaz. `Transition.ForceSync(shouldBeApplied, affectVehicles)` — sekanssız, anlık, doğru son duruma zıplar.
- `client/visual/manager.lua`: `infra:powerStateChanged` payload'ındaki yeni `instant` bayrağına göre `Transition.PlayBlackout/PlayRecovery` (gerçek canlı değişim) ya da `Transition.ForceSync` (başlangıç/late-join/district-geçişi) çağırıyor — hangisi olduğuna kendisi karar vermiyor, sadece bayrağa bakıyor.
- `client/main.lua`: `applyGridState`'e `instant` parametresi eklendi — `start()` (late-join) ve `infra:districtChanged` (district geçişi, spec §29) `instant=true` gönderiyor (spec §32: sekans tekrar oynatılmaz); `AddStateBagChangeHandler` (gerçek canlı değişim) `instant=false` gönderiyor. Eskiden ham `GlobalState` referansı doğrudan event'e geçiyordu, artık `instant` alanını taşıyabilmesi için sığ kopyalanıyor.
- `profiles/sandy.lua`: spec §30/§31'in örnek zaman çizelgesi `blackoutSequence`/`recoverySequence`'a çevrildi. `native_blackout.lua`'nın adaptörü tek bir ON/OFF native (`SetArtificialLightsState`) olduğu için spec'teki "electrical arc/first flicker/lights return/second flicker" gibi adımlar art arda apply/remove toggle'larına eşlendi — gerçek per-light kontrolü olmadığı için mümkün olan en yakın yaklaşım, dosyanın başında bu eşleme açıkça belgelendi.
- `client/debug.lua`: `/testtransition <blackout|recovery>` — gerçek bir trafoya dokunmadan sekansı oynatır, bitince native state'i test öncesine geri döndürür. `/reloadvisual` artık `instant=true` gönderiyor (bir resync'tir, gerçek olay değil — daha önce bu alan hiç yoktu, `instant` `nil` olduğu için şimdi yanlışlıkla sekans oynatırdı).
- `fxmanifest.lua`: `client/visual/transition.lua` `manager.lua`'dan önce yükleniyor, versiyon `0.15.0`.

### Dosyalar
- `client/visual/transition.lua` (yeni), `client/visual/manager.lua`, `client/main.lua`, `profiles/sandy.lua`, `client/debug.lua`, `fxmanifest.lua`

### Bilinçli basitleştirmeler
- `ptfx`/`sound` adımları hâlâ no-op — Phase 17'nin (hybrid visual) kancası, bu phase'in kapsamı değil.
- Phase 13'ün `RECOVERING → ONLINE` gecikmesi (`Config.Repair.recoveryDurationSec`) ile bu phase'in `recoverySequence` süresi (~1.5sn) bağımsız iki zamanlayıcı — ayrı ayrı ayarlanabilir, biri diğerini beklemiyor (repair'in server-side gecikmesi zaten yeterli, visual sekans o pencere içinde oynuyor).

### Test durumu
- [x] Kod incelemesi + tüm resource genelinde paren/brace taraması (temiz).
- [x] Oyun içi test (2026-08-08): kullanıcı onayladı — çalışıyor.

### Sonraki adım
Phase 16 (Visual Ownership) — aşağıya bakın.

---

## Phase 16 — Visual Ownership · TAMAMLANDI (kod) · 2026-08-08

### Ne yapıldı
- `client/visual/ownership.lua`'yı gözden geçirdim (plan bu dosyanın "tek asset/tek owner ile test edilmemiş, sağlamlaştırılmalı" olduğunu varsaymıştı) — kod aslında Phase 8'den beri **zaten doğru**: asset-başına owner set'i, `Acquire` sadece 0→1 kenarında `true` dönüyor, `Release` sadece 1→0 kenarında `true` dönüyor, tutulmayan bir asset'i release etmek zaten sessiz no-op (underflow yok, `math.max(0, ...)` zaten vardı). Gerçek eksik: hiç test edilmemiş olması ve owner-mismatch durumunun loglanmaması.
- `client/visual/ownership.lua`: `Release`, asset tutuluyor ama BAŞKA bir owner tarafından tutuluyorsa artık bir uyarı basıyor (önceden tamamen sessizdi) — gerçek owner'ı etkilemeden, sadece teşhis için. `VisualOwnership.Debug()` eklendi — `/visualdebug` için salt-okunur, sıralı bir envanter snapshot'ı.
- `client/debug.lua`: `/visualdebug` — her asset'in refCount'unu, owner listesini VE adaptörün gerçekten "applied" dediğini yan yana basıyor; bu ikisi arasındaki uyuşmazlık Phase 16'nın yakalamak istediği tam bug sınıfı.
- `tests/spec/visual_ownership_spec.lua` (yeni) + `tests/run.lua` güncellendi: 10 test — acquire/release 0↔1 kenarları, aynı owner'ın iki kez acquire etmesi (idempotent), release-without-acquire, başka owner'ın release etmesi, çift release, bağımsız asset'ler, `Reset()`. `client/visual/ownership.lua` hiç native dokunmuyor (`math.max` + düz tablolar), bu yüzden gerçekten test edilebilir — diğer adaptörlerin aksine.
- `VisualManager`'ın `heldByGrid`/`heldByProfile` tek-hold tasarımı (Phase 15'te zaten eklenmişti) **bilinçli olarak değiştirilmedi** — bkz. aşağıdaki basitleştirme notu.

### Dosyalar
- `client/visual/ownership.lua`, `client/debug.lua`, `tests/spec/visual_ownership_spec.lua` (yeni), `tests/run.lua`, `fxmanifest.lua` (versiyon `0.16.0`)

### Bilinçli basitleştirmeler
- Plan, `VisualManager`'ı "asset başına held-set" olacak şekilde yeniden yazmayı öneriyordu (bir client'ın iki çakışan profile aynı anda maruz kalması senaryosu için). **Yapılmadı** — bugünkü topolojide tek asset (`native_blackout`) var ve bir oyuncu aynı anda sadece tek bir grid'de olabilir, yani bu senaryo şu an fiilen imkansız; gerçek ownership muhasebesi zaten doğru şekilde `VisualOwnership`'e devrediliyor. Phase 17 (hybrid visual, birden fazla asset) bunu gerçek bir ihtiyaç haline getirirse o zaman yapılır — bugün spekülatif bir refactor olurdu.
- `lua5.4 tests/run.lua` **hâlâ bu makinede çalıştırılamadı** (yerel Lua interpreter yok, tekrar kontrol edildi) — yeni test dosyası yazıldı ve mantıksal olarak gözden geçirildi ama "PASS" çıktısı hâlâ görülmedi. Bu, projenin başından beri süregelen dürüst bir boşluk.

### Test durumu
- [x] Kod incelemesi + tüm resource genelinde paren/brace taraması (temiz).
- [ ] `lua5.4 tests/run.lua`: **çalıştırılamadı** (lokal Lua yok).
- [x] Oyun içi test (2026-08-08): kullanıcı onayladı — "phase 16 düzgün gözüküyor herhangi bi sorun çıkmadı."

### Sonraki adım
Phase 13-16 parçası oyun içinde doğrulanarak tamamlandı. `CITY INFRASTRUCTURE
(1).md` bu noktada güncellendi (V3 → citywide roadmap, bkz. altta) — eski
Phase 17-22 (Sandy hybrid visual, external API, random failure, security
hardening, scale test, city expansion) kaldırıldı, yerine Phase 16.5-35
citywide roadmap geldi. Sıradaki parça bu yeni roadmap'in başı: Phase 16.5
(Citywide Migration & Compatibility Audit) — aşağıya bakın.

---

## Phase 16.5 — Citywide Migration & Compatibility Audit · TAMAMLANDI (kod) · 2026-08-09

`CITY INFRASTRUCTURE (1).md` bu oturumda güncellendi: proje artık
"Sandy MVP" değil, "Sandy ilk doğrulanmış district olduğu CITYWIDE
FUNCTIONAL V1" hedefine yöneliyor. Yeni roadmap Phase 16.5'ten başlıyor ve
spec'in kendi kapı koşulu net: *"Bu phase tamamlanmadan citywide topology
oluşturulmamalıdır."*

### Ne yapıldı
- `docs/MIGRATION_AUDIT.md` (yeni): spec §16.5.1'in tüm checklist maddeleri
  tek tek, gerçek dosya/satır kanıtlarıyla PASS/FAIL olarak işaretlendi.
  Repository'de `SANDY|blaine_south|sandy` deseni ve
  `ApplySandyBlackout()`/`SetSandyPower()`/`GetSandyGrid()` gibi isimler
  özel olarak arandı — **hiçbir Sandy-specific core fonksiyon bulunmadı**.
  Bulunan tüm eşleşmeler config/veri dosyalarında (`shared/grids.lua`,
  `profiles/sandy.lua`, `shared/districts.lua`) ya da test/yorum
  satırlarındaydı. `GridManager`, `Replication`, `PowerCalculator`,
  `VisualManager` zaten N-grid/N-transformer için yazılmıştı (Phase 1-8'in
  kendi tasarım disipliniydi — "1 substation ama data modeli çoklu
  transformer'a hazır" gibi yorumlar dosyaların başında zaten vardı).
  Audit ayrıca citywide'ı gerçekten bloklayan **4 gerçek eksiği** tespit
  etti (district state'in grid'den kopyalanması, `ClientState`'in §19.2
  alanlarının eksikliği, district modelinin §17 şeklinde olmaması, feeder
  indeksinin yokluğu) — bunların düzeltmesi bilinçli olarak Phase 17/18'e
  devredildi, bu phase'de sadece belgelendi.
- `client/sabotage.lua`: `/sabotage <transformerId> [thermite|c4]` komutunun
  `targetId` parametresi artık **zorunlu** — eskiden parametresiz
  çağrıldığında sessizce `sandy_tr_01`'i hedefliyordu (§30.2: *"implicit
  nearest-target gibi riskli production admin davranışlarından
  kaçınılmalıdır"*). Artık eksik parametrede kullanım mesajı basıyor.
  `/tptrafo` ve `/infracoords` bilinçli olarak dokunulmadı — ikisi hedef
  seçmiyor, sadece Sandy'nin fiziksel konumuna ışınlıyor/mesafe ölçüyor;
  parametrik hâle getirilmeleri Phase 22'nin (dünya yerleşimi) işi.
- `README.md`: "Phase 1-14" / "Sandy MVP" dili güncel duruma çekildi —
  Phase 1-16 tamamlandı ve doğrulandı, Phase 16.5+ citywide hedefi
  belgelendi, `docs/MIGRATION_AUDIT.md`'ye referans eklendi.

### Dosyalar
- `docs/MIGRATION_AUDIT.md` (yeni), `client/sabotage.lua`, `README.md`

### Bilinçli basitleştirmeler
- Bu phase'de **davranış değişikliği yok** — sadece dokümantasyon + bir
  debug komutunun parametre zorunluluğu. §16.5.2'nin *"REWRITE değil
  GENERALIZE"* kuralı gereği, zaten çalışan hiçbir modül yeniden yazılmadı.
- Audit'te tespit edilen 4 gerçek eksik bilinçli olarak bu phase'de
  düzeltilmedi — Phase 17 (district registry) ve Phase 18 (topology)'nin
  kendi kapsamlarına bırakıldı, aynı "önce tespit et, sonra ait olduğu
  phase'de düzelt" disiplini.

### Test durumu
- [x] Kod incelemesi: audit'in dayandığı her grep sonucu tek tek doğrulandı
      (`SANDY|blaine_south|sandy` deseni, isim taraması).
- [x] Oyun içi regresyon testi (2026-08-09): kullanıcı onayladı —
      "Tamamlandı, sorun yok." Sandy davranışı bire bir korunmuş (§16.5.4).

### Sonraki adım
Phase 17 (Complete GTA District Registry) — aşağıya bakın.

---

## Phase 17 — Complete GTA District Registry · TAMAMLANDI (kod) · 2026-08-09

### Ne yapıldı
- `shared/districts.lua`: district modeli spec §17'nin istediği tam şekle
  genişletildi — her kayıt artık `id`/`code` (alias, geriye dönük uyum),
  `label`, `enabled`, `category` (`los_santos`/`blaine_county`/
  `wilderness`/`water`/`restricted`), `resolver`, `defaultGrid`,
  `visualProfile`, `metadata`, `aabbConfidence` taşıyor. Kod sayısı 44'ten
  ~84'e çıktı (Blaine County dağ/nehir/koy bölgeleri + Los Santos'un geri
  kalan mahalleleri + `OCEANA`/`SANAND` gibi kavramsal, `enabled=false`
  işaretli, hiçbir zaman bir grid'e atanmayacak marker kodlar). Yeni AABB'ler
  de eskileri gibi **tahmini** — dosyanın kendi başlığı bunu genişletilmiş
  haliyle tekrar açıkça belirtiyor.
- `Districts.GetAssignment(code)` (`ASSIGNED`/`UNASSIGNED`/`UNKNOWN`) ve
  `Districts.ComputeAssignments(grids)`: bir district'in hangi grid'e ait
  olduğunu (`defaultGrid`) ve atanıp atanmadığını hesaplıyor. Bu fonksiyon
  `shared/districts.lua`'nın kendi yükleme anında ÇALIŞAMAZ —
  `fxmanifest.lua`'da `shared/grids.lua`'dan ÖNCE yükleniyor, henüz `Grids`
  tanımlı değil — bu yüzden çağrı `shared/grids.lua`'nın sonuna eklendi
  (`Districts.ComputeAssignments(Grids)`), her iki tablo da garantili
  yüklenmiş olduğu tek nokta.
- `Districts.GetDuplicateCodes()`: RAW tablosunda kopyala-yapıştır
  kaynaklı bir kod tekrarı olursa (ikinci kayıt sessizce birinciyi ezer)
  bunu tespit edip `shared/validators.lua`'ya bildiriyor.
- `shared/validators.lua`: `Validators.ValidateDistrictRegistry()` eklendi
  (dahili, `ValidateAll()` içinden çağrılıyor) — eksik label/resolver,
  registered-ama-disabled bir district'i bir grid'in claim etmesi, ve
  spec §17.2'nin örnek metniyle birebir eşleşen *"District X has no power
  topology assignment."* uyarısı. `Config.Topology.strict` (varsayılan
  `false`) bunların hard error mi (`errors`, boot'u durdurur) yoksa
  sadece warning mi (`warnings`, boot devam eder) olacağını belirliyor —
  `ValidateAll()` artık `(ok, errors, warnings)` döndürüyor (geriye dönük
  uyumlu: eski 2-değişkenli çağrı kırılmadı, Lua fazla dönüş değerini
  yok sayar). `server/main.lua`'nın `boot()`'u yeni `warnings` listesini
  `Log.warn` ile basıyor.
- `config.lua`: `Config.Topology` bloğu eklendi (`strict`, `districtPolicy`,
  `warnUnassignedDistricts`) — `districtPolicy`/`warnUnassignedDistricts`
  alanları bu phase'de henüz okunmuyor, Phase 18'in feeder katmanı için
  hazırlık (aynı dosyada tanımlamak, Phase 18'de ayrı bir config bloğu
  açmaktan daha tutarlı).
- `client/debug.lua`: `/districtregistry` (toplam/enabled/assigned/
  unassigned sayıları + kategori kırılımı + unassigned listesi),
  `/districtauditauto` (her yeni district'e girildiğinde otomatik audit
  tetikler — tek tek `/districtaudit` yazmak yerine oturum boyunca
  kendiliğinden kalibrasyon verisi biriktirir), `/districtauditreport`
  (o oturumda toplanan tüm audit sonuçlarının özeti, ✓/✗ listesi).
- `client/sabotage.lua`, `tests/spec/district_registry_spec.lua` (yeni,
  9 test — duplicate kontrolü, model şekli, `GetAllEnabled`/`GetAssignment`/
  `ComputeAssignments` senaryoları, `SortedByVolume` sıralaması),
  `tests/run.lua` (spec dosyası kaydedildi), `fxmanifest.lua` (versiyon
  `0.17.0`).

### Dosyalar
- `shared/districts.lua` (yeniden yapılandırıldı), `shared/grids.lua`
  (`ComputeAssignments` çağrısı), `shared/validators.lua`
  (`validateDistrictRegistry`), `server/main.lua` (warning basma),
  `config.lua` (`Config.Topology`), `client/debug.lua` (3 yeni komut),
  `tests/spec/district_registry_spec.lua` (yeni), `tests/run.lua`,
  `fxmanifest.lua`

### Bilinçli basitleştirmeler
- ~84 kod, spec'in istediği "GTA V'nin desteklediği TÜM native district
  kodları" (~90+) iddiasına tam ulaşmıyor — bu projenin yazarının genel
  harita bilgisinden derleyebildiği kadarı, oyunun kendi `zones.xml`'i
  okunarak çıkarılmadı (böyle bir dosyaya bu ortamda erişim yok). Eksik
  kalan kodlar `ClientZone.ResolveDistrict`'in zaten yaptığı "unmapped
  code" logu ile organik olarak ortaya çıkacak, sessiz kalmayacak.
- Yeni AABB'ler de eskiler gibi **kalibre edilmedi** — aynı dürüst boşluk,
  `/districtauditauto` bu turda bu amaçla eklendi ama kalibrasyonun
  kendisi (gerçek oyun içi gezinme) bu oturumun kapsamı değil.
- `Config.Topology.strict = false` varsayılanıyla, `blaine_south` dışında
  kalan ~80 enabled district için boot'ta *"has no power topology
  assignment"* uyarısı basılacak (spec §17.2'nin örnek formatı birebir) —
  bu **beklenen ve doğru** davranış (henüz hiçbir grid'e atanmadıkları
  için), sadece konsolda gürültülü görünecek; Phase 18 bu sayıyı
  azaltacak, susturmak bu phase'in işi değil.

### Test durumu
- [x] Kod incelemesi + tüm resource genelinde paren/brace taraması (temiz,
      dosya tek tek tekrar okunarak doğrulandı).
- [ ] `lua5.4 tests/run.lua`: **çalıştırılamadı** (lokal Lua yok, proje
      boyunca süregelen dürüst boşluk).
- [x] Oyun içi test (2026-08-09): kullanıcı onayladı — "evet değişiyor
      düzgün çalışıyor galiba" (district geçişleri doğru kodlarla
      izleniyor, çökme/regresyon yok).

### Sonraki adım
Phase 18 (Citywide Power Topology + Feeder Layer) — aşağıya bakın.

---

## Phase 18 — Citywide Power Topology + Feeder Layer · TAMAMLANDI (kod) · 2026-08-09

Topology hiyerarşisi tamamlandı: **GRID → SUBSTATION → FEEDER →
TRANSFORMER → DISTRICT**. Bu, audit'in (Phase 16.5) devrettiği ana eksiği
kapatıyor: district state artık grid'den kopyalanmıyor, kendi feeder'ından
bağımsız hesaplanıyor.

### Ne yapıldı
- `shared/feeders.lua` (yeni): 3 feeder. `blaine_south_feed_a`
  (sandy_tr_01 → SANDY, HARMO), `blaine_south_feed_b` (yeni trafo
  `blaine_south_tr_02` → DESRT — **aynı substation'da ikinci trafo**, §18.7
  "bir substation birden fazla feeder besleyebilir" senaryosunu gerçek
  ve test edilebilir kılıyor), `ls_central_feed_a` (yeni bölge, DOWNT/
  PBOX/SKID). `shared/grids.lua`: `blaine_south_tr_02` + `ls_central` grid/
  substation/trafo eklendi. `profiles/ls_central.lua` (yeni): minimal
  NATIVE_CLIENT_GATE profili (`blackoutSequence` yok, Transition zaten
  eksikse tek adımlı anlık uygulamaya düşüyor).
- **Ana değişiklik — district-level power hesabı:** `server/power_
  calculator.lua`'ya saf fonksiyon `PowerCalculator.CalculateDistrict(supply)`
  eklendi (yalnızca `Config.Topology.districtPolicy = 'ANY'` uygulanıyor —
  district'i besleyen feeder'lardan en az biri güçlüyse district güçlü).
  `server/replication.lua` neredeyse tamamen yeniden yazıldı:
  `RecalculateGrid` artık district kopyalamıyor; yeni `RecalculateDistrict`
  (bir district'i kendi feeder'larından yeniden hesaplar, feeder yoksa
  grid'e fallback yapar — Phase 1-17 davranışı korunur), `RecalculateFeeder`
  (feeder state'ini hesaplar + besledigi tüm district'leri kaskat olarak
  yeniden hesaplar), `RecalculateForTransformer` (server/transformer_
  manager.lua'nın tek çağırdığı giriş noktası — trafo → grid + feeder +
  district zincirini kapsar). `server/feeder_manager.lua` (yeni):
  `server/substation_manager.lua` ile aynı desen — feeder'ın kendi state'i
  yok, `PowerCalculator.Calculate()` trafolarından türetiliyor (grid'in
  kullandığı AYNI saf fonksiyon).
- `server/grid_manager.lua`: feeder indeksleri eklendi (`feederToSubstation`,
  `substationToFeeders`, `feederToTransformers`, `transformerToFeeder`,
  `districtToFeeders`) + 6 yeni getter.
- `shared/validators.lua`: `validateFeederTopology()` — feeder'ın substation/
  trafo/district referansları, PRIMARY policy'nin gerçek bir primary trafoya
  sahip olması, ve `Config.Topology.warnUnassignedDistricts` açıkken bir
  grid'e ait ama hiçbir feeder'ı olmayan district'ler için uyarı. Circular
  topology kontrolü **bilinçli olarak yazılmadı** — şemanın kendisi
  (feeder sadece substationId'ye işaret ediyor, Substation/Transformer
  feeder'ın varlığından habersiz) döngü oluşturmaya yapısal olarak
  kapalı, olmayacak bir şey için graph-walk yazmak dead code olurdu.
- `shared/types.lua`: `Types.NewDistrictState`'e `level`/`status` eklendi
  (artık bağımsız hesaplandığı için grid gibi tam şekle ihtiyacı var),
  yeni `Types.NewFeederState`. `shared/constants.lua`:
  `Constants.StateKey.FEEDER`.
- **Client tarafı — district-seviyesinde gating (planın orijinal dosya
  listesinde yoktu, uygulama sırasında zorunlu olduğu ortaya çıktı):**
  `client/main.lua`: `applyGridState(gridId)` → `applyDistrictState
  (districtId, gridId)` — artık GRID state değil DISTRICT state okuyor.
  `infra:districtChanged` handler'ı artık sadece grid değiştiğinde değil,
  **district değiştiğinde** (aynı grid içinde bile) tetikleniyor —
  `AddStateBagChangeHandler` de DISTRICT key'ini dinliyor. **Neden
  zorunlu:** backend district-seviyesinde doğru hesaplasa bile, client
  hâlâ grid state'ine bakıyorsa aynı grid'deki iki district'in görsel
  farkı (Feeder A karanlık, Feeder B aydınlık) oyun içinde asla
  görünmezdi — Phase 18'in kendi kabul kriterini ("district power state
  topology üzerinden hesaplanıyor") gerçekten test edilebilir kılmak için
  gerekliydi. `client/visual/manager.lua`: ownership key'i `heldByGrid` →
  `heldByDistrict` (aynı gerekçe — ownership hâlâ gridId'ye bağlıysa iki
  district "aynı owner" sayılırdı); `gridId` sadece visual PROFILE
  seçimi için okunmaya devam ediyor. `client/debug.lua`'nın
  `/reloadvisual`'ı da aynı şekilde DISTRICT state okuyacak şekilde
  güncellendi.
- `client/state.lua`: spec §19.2'nin istediği `CurrentFeeder` (şu an
  boş — hiçbir tüketici yok, Phase 19 kancası) ve `CurrentVisualProfile`
  (VisualManager tarafından dolduruluyor) eklendi.
- `server/debug.lua`: `/showfeeders [gridId]`, `/showdistrictpower
  [category]`, `/powerpath <districtId>` (§24.1'in zincir çıktısı, gözle
  doğrulamanın en hızlı yolu), `/topologyaudit` (validator'ı runtime'da
  tekrar çalıştırır).
- `tests/spec/topology_spec.lua` (yeni, 9 test): `CalculateDistrict`'in
  ANY policy davranışı (tek çevrimiçi feeder tek çevrimdışı feederi
  yener, sıra önemli değil — spec §29.1), `shared/feeders.lua`'nın
  statik şekli, iki-feeder-tek-substation senaryosunun gerçekten farklı
  trafoları kullandığının doğrulanması.

### Dosyalar
- `shared/feeders.lua` (yeni), `shared/grids.lua`, `profiles/ls_central.lua`
  (yeni), `server/power_calculator.lua`, `server/replication.lua`
  (büyük ölçüde yeniden yazıldı), `server/feeder_manager.lua` (yeni),
  `server/grid_manager.lua`, `shared/validators.lua`, `shared/types.lua`,
  `shared/constants.lua`, `client/main.lua`, `client/visual/manager.lua`,
  `client/debug.lua`, `client/state.lua`, `server/transformer_manager.lua`
  (2 çağrı yeri `RecalculateForTransformer`'a çevrildi), `server/debug.lua`
  (4 yeni komut), `tests/spec/topology_spec.lua` (yeni), `tests/run.lua`,
  `fxmanifest.lua` (versiyon `0.18.0`)

### Bilinçli basitleştirmeler
- **Şehrin ~84 kayıtlı district'inin sadece 6'sı** (SANDY/HARMO/DESRT +
  DOWNT/PBOX/SKID) gerçekten bir feeder'a bağlandı. Spec §18.1'in kendisi
  bunu haklı çıkarıyor: *"Kesin district dağılımı map/gameplay tasarımına
  göre belirlenmelidir"* — kalan ~78 district'i rastgele bölgelere
  dağıtmak spekülatif bir tasarım kararı olurdu, mühendislik işi değil.
  Amaç şehrin tamamını doldurmak değil, feeder mekanizmasının (çoklu
  grid, tek substation'da çoklu feeder, district-seviyesi bağımsız güç)
  gerçekten çalıştığını kanıtlamaktı — kalan bölgeler §18.7'nin kendi
  ruhuna uygun, gelecekteki bir "topology authoring" turuna bırakıldı.
- **Grid-seviyesi `powered`'ın anlamı kaydı.** `blaine_south` artık iki
  PRIMARY trafo taşıyor (sandy_tr_01 + blaine_south_tr_02); grid'in kendi
  PRIMARY policy'si "ikisinden herhangi biri online mı" sorusuna bakıyor,
  yani `IsGridPowered('blaine_south')` artık tek bir feeder söndüğünde
  `false` dönmüyor (önceden dönerdi, tek trafo vardı). Bu **beklenen bir
  yan etki**, hata değil — district-seviyesi artık gerçek kaynak, grid
  seviyesi kabaca "bu bölgenin herhangi bir kısmı ayakta mı" sinyaline
  dönüştü. Hiçbir mevcut tüketici (`server/api.lua`'nın export'ları) buna
  bağlı değil, ama gelecekte `IsGridPowered` kullanacak bir entegrasyon
  için not edilmeye değer.
- **Revision atomikliği gevşetildi.** Phase 1-17'de bir grid ve besledigi
  tüm district'ler AYNI revision numarasıyla yazılıyordu. Artık grid/
  feeder/district bağımsız hesaplanıp bağımsız revision alıyor — bir
  trafo arızası artık 2-3 farklı revision numarası üretebilir. Bu güvenli
  (her key'in kendi revision'ı hâlâ kesin monotonik, client'ın stale-read
  koruması buna bakıyor, key'ler arası karşılaştırmaya değil) ama
  "aynı olay = aynı numara" garantisi artık yok — bir batch-transaction
  sarmalayıcısı yazmak bu phase'in kapsamına alınmadı (server/
  replication.lua'nın kendi header yorumunda detaylı açıklandı).
- Substation-seviyesinde ayrı bir OFFLINE state modeli yok (§29.2'nin
  "Transformer ONLINE ama Substation OFFLINE" örneği bunu varsayıyor) —
  bugün substation state'i her zaman trafolarından türetiliyor, kendi
  başına asla "offline" zorlanamıyor. Bu, gerçek bir substation-failure
  state modelinin Phase 21 (Citywide Failure Propagation) kapsamına ait
  olduğu anlamına geliyor — bu phase'de icat edilmedi. Pratik eşdeğeri:
  bir substation'ın TÜM trafolarını OFFLINE'a zorlamak aynı sonucu verir
  (aşağıdaki doğrulama adımı bunu kullanıyor).

### Test durumu
- [x] Kod incelemesi + tüm resource genelinde paren/brace taraması (temiz,
      her değişen dosya tek tek tekrar okunarak doğrulandı).
- [ ] `lua5.4 tests/run.lua`: **çalıştırılamadı** (lokal Lua yok).
- [ ] Oyun içi test: **henüz yapılmadı** — kullanıcı onayı bekleniyor.
      Beklenen: `refresh` + `restart gnsh-blackout` temiz, `/topologyaudit`
      temiz, `/powerpath SANDY` doğru zinciri basıyor, `/showfeeders`
      3 feeder'ı gösteriyor. Asıl test: Sandy'de trafoyu (sandy_tr_01)
      sabote et → SANDY/HARMO karardı ama DESRT AÇIK kaldı (`/
      showdistrictpower`'la doğrula + fiziksel olarak Grand Senora
      Desert'e gidip gözle bak). Sonra `blaine_south_tr_02`'yi de
      OFFLINE'a zorla (`/setdamage` veya sabotaj) → DESRT de karardı.
      Downtown'a gidip `/showdistrict` → `DOWNT`, `ls_central_tr_01`'i
      sabote et → Downtown/Pillbox/Mission Row karardı, Sandy etkilenmedi
      (iki grid bağımsız çalışıyor).

### Sonraki adım
Oyun içi kabul testleri tamamlandıktan sonra Phase 22 (World Placement)
ayrı bir plan turu olarak ele alınacak.

---

## Phase 19 — Generic Citywide District Blackout Controller · TAMAMLANDI (kod) · 2026-08-09

### Ne yapıldı

- District görsel kararı artık `CurrentDistrict → DistrictState →
  VisualProfile → Apply/Remove` zincirinden geliyor. Client state içinde
  `CurrentDistrict`, `CurrentGrid`, `CurrentFeeder`, `CurrentPowered`,
  `CurrentPowerRevision` ve `CurrentVisualProfile` güncel tutuluyor.
- District GlobalState payload'ına `gridId`, `feederIds`, `sourceFeederId`,
  `powered`, `level`, `status`, `revision` ve gerektiğinde `blockedBy`
  eklendi. Aynı grid altındaki feeder district'leri bağımsız kalıyor.
- `NATIVE_CLIENT_GATE` generic adapter olarak korundu. Unassigned veya
  henüz publish edilmemiş district fail-open davranıyor; gerçek spatial
  district maskesi, IPL, hybrid visual ve custom NUI bu phase'e alınmadı.
- Deterministik source-feeder seçimi eklendi: eşit seviyede feeder ID'si
  alfabetik olarak küçük olan seçiliyor.

### Dosyalar

- `server/replication.lua`, `server/power_calculator.lua`, `shared/types.lua`,
  `client/main.lua`, `client/state.lua`, `client/visual/manager.lua`
- `tests/spec/district_controller_spec.lua`, `tests/run.lua`

### Test durumu

- [x] Kod incelemesi ve static delimiter taraması: kod tarafında temiz;
      ilk kaba taramadaki fark çok satırlı yorumdaki parantez karakterinden
      kaynaklanan false-positive olarak ayrıştırıldı.
- [ ] Lokal `lua5.4 tests/run.lua`: bu makinede Lua interpreter yok.
- [x] Oyun içi ara test (2026-08-10): `blaine_south_feed_a` OFFLINE iken
      SANDY/HARMO BLACKOUT, DESRT ONLINE kaldı. `ls_central_feed_a` OFFLINE
      iken DOWNT/PBOX/SKID BLACKOUT, Sandy tarafı ONLINE kaldı. İki grid ve
      aynı grid içindeki feeder bağımsızlığı doğrulandı.
- [x] Unassigned district çözümü (2026-08-10): Vespucci Beach'te
      `BEACH (Vespucci Beach)` ve `Grid=nil` görüldü; bu, topology'ye bağlı
      olmayan district için beklenen fail-open kaynağıdır. Beach'te görsel
      blackout temizliği de kullanıcı tarafından doğru olarak teyit edildi.
- [x] Restart/resync testi (2026-08-10): restart sonrası `PBOX` üzerinde
      `ls_central`, `Power=OFF`, `Status=BLACKOUT`, `Native Blackout=ACTIVE`
      olarak yeniden görüldü; resource başlangıcında script error görünmedi.
      Test koordinatı placeholder nedeniyle Downtown yerine Pillbox'a denk
      geldi, ancak aynı `ls_central` branch'ini doğruladı.
- [x] Kullanıcı kabulü: Phase 19 canlı kabul senaryoları başarılı.

---

## Phase 20 — Citywide District Transition Engine · TAMAMLANDI (kod) · 2026-08-09

### Ne yapıldı

- Mevcut token-based `Transition` sistemi korundu ve her yeni
  `infra:powerStateChanged` olayında eski asynchronous sequence önce iptal
  ediliyor.
- District değişimi, teleport, rapid travel, araç/uçak hareketi ve eksik
  GlobalState snapshot'ı fail-safe temizleme yolundan geçiyor; eski blackout
  yeni district state'ini sonradan ezemiyor.
- Startup, late-join ve district transition instant; gerçek canlı power
  değişimleri sequence tabanlı kalıyor. `Transition.Cancel()` hem geçerli
  hem de hatalı/missing profile yollarında zorunlu hale getirildi.

### Dosyalar

- `client/main.lua`, `client/visual/manager.lua`,
  `client/visual/transition.lua`, `profiles/sandy.lua`, `client/debug.lua`

### Test durumu

- [x] Kod incelemesi ve statik delimiter taraması.
- [ ] Lokal Lua testi: interpreter yok.
- [x] İlk oyun içi deneme (2026-08-10): `/testtransition blackout`,
      `/testtransition recovery` ve `/visualdebug` hata vermeden çalıştı;
      ancak `ls_central` profile'ında sequence olmadığı için instant fallback
      uygulanıp gerçek state hemen geri yüklendi, gözle görünür değişim olmadı.
- [x] Dev test düzeltmesi: `/testtransition` preview hold süresi eklendi;
      açık state'te recovery öncesi geçici blackout kuruluyor. Bu düzeltme
      yalnızca test komutunu etkiliyor, production transition akışını değil.
- [x] Düzeltme sonrası oyun içi retest (2026-08-10): kullanıcı onayladı;
      görünür blackout/recovery preview'ları ve `visualdebug` cleanup sonucu
      beklenen gibi çalıştı.
- [x] Transition sırasında teleport testi (2026-08-10) bir gerçek bug ortaya
      çıkardı: PBOX ONLINE olmasına rağmen `VisualOwnership` boşken
      `NativeBlackout.IsApplied()` true kaldı. Kök neden, debug preview'ın
      native adapter'a ownership oluşturmadan dokunması ve powered district
      snapshot'ının stray native state'i temizlememesiydi.
- [x] Düzeltme: `VisualManager`, ownership bulunmasa bile yeni powered veya
      missing-profile snapshot'ında native blackout'ı zorla temizliyor.
      Server logical state'e dokunulmadı.
- [x] Düzeltme sonrası teleport retest (2026-08-10): kullanıcı onayladı;
      Sandy transition'ı sırasında PBOX'a geçişte PBOX ONLINE kaldı,
      `NativeBlackout.IsApplied()` false ve ownership temiz kaldı.
- [x] Resource restart cleanup: retest öncesi restart sonrası client doğru
      district/state ile başladı, script error gözlenmedi.
- [x] Kullanıcı kabulü: Phase 20 canlı kabul senaryoları başarılı.

---

## Phase 21 — Citywide Failure Propagation · TAMAMLANDI (kod) · 2026-08-09

### Ne yapıldı

- Yeni `server/failure_manager.lua`: yalnızca `grid`, `substation` ve
  `feeder` için server-authoritative ONLINE/OFFLINE override katmanı.
  Parent arızası child transformer kaydını değiştirmiyor; yalnızca effective
  power hesabını blokluyor.
- Öncelik `GRID → SUBSTATION → FEEDER → TRANSFORMER → DISTRICT` olarak
  uygulanıyor. Parent restore, child'ın gerçek state'ini tekrar görünür
  kılıyor; child hâlâ OFFLINE ise district kendiliğinden açılmıyor.
- Replication'a `RecalculateForTransformer`, `RecalculateForFeeder`,
  `RecalculateForSubstation` ve `RecalculateForGrid` girişleri eklendi.
  Etkilenmeyen branch'ler yeniden yazılmıyor ve revision monotonic kalıyor.
  Parent tarafından bloklanan child transformer artık policy listesinden
  silinmiyor; `OFFLINE` girdisi olarak korunuyor. Böylece `ALL` ve
  `REQUIRED_COUNT` politikalarında sahte güç oluşmuyor. Grid fallback
  district'leri de ilgili parent/child recalc'lerinde yeniden hesaplanıyor.
- `server/api.lua` `IsPositionPowered()` artık grid açık olsa bile mevcut
  district state'ini tercih ediyor; feeder seviyesindeki blackout'ı diğer
  server resource'ları kaçırmıyor.
- `infrastructure_component_overrides` additive SQL tablosu, persistence
  load/save/delete ve boot restore eklendi. Mevcut iki tabloya dokunulmuyor.
- Admin komutları eklendi: `/setgridstate`, `/setsubstationstate`,
  `/setfeederstate`; ayrıca `/showsubstations`, `blockedBy` debug çıktıları ve
  `/powerpath` parent zinciri eklendi. ACE kontrolü server tarafında.
- `districtAudit` debug event'i saniyede bir kezle sınırlandı ve server ped
  koordinatını kullanıyor; client artık sahte koordinatla audit sonucu
  üretemiyor. Read-only topology komutları state değiştirmiyor; tüm parent
  state mutasyonları ACE korumalı.

### Dosyalar

- `server/failure_manager.lua`, `server/replication.lua`,
  `server/feeder_manager.lua`, `server/substation_manager.lua`,
  `server/persistence.lua`, `server/main.lua`, `server/debug.lua`,
  `sql/schema.sql`, `shared/constants.lua`, `shared/types.lua`,
  `tests/spec/failure_propagation_spec.lua`

### Bilinçli kapsam notları

- `sql/schema.sql` bir migration runner tarafından otomatik uygulanmıyor;
  oyun içi restart persistence testi öncesi additive tablo veritabanına
  import edilmeli.
- `NativeBlackout` gerçek spatial mask değildir. Hybrid visual/IPL/custom
  NUI ve Phase 22 kesin dünya koordinatları bu paketin dışındadır.
- Lokal Lua interpreter bulunmadığı için yeni unit testler yazıldı ancak
  bu makinede PASS çıktısı alınamadı.

### Test durumu

- [x] Kod incelemesi + statik delimiter taraması (yorum kaynaklı false-positive
      ayrıştırıldı).
- [ ] Lokal `lua5.4 tests/run.lua`: interpreter yok.
- [x] Feeder izolasyonu (2026-08-10): kullanıcı onayladı; `feed_a` OFFLINE
      iken yalnızca SANDY/HARMO BLACKOUT oldu, DESRT ve diğer grid ONLINE
      kaldı.
- [x] Substation izolasyonu (2026-08-10): kullanıcı çıktısı doğruladı;
      `sandy_substation_01` OFFLINE iken iki child feeder BLACKOUT ve
      `blockedBy=substation/sandy_substation_01` oldu. Sandy branch'inde
      `0/2` transformer ONLINE kaldı; `ls_central` branch'i etkilenmedi.
- [x] Grid izolasyonu (2026-08-10): kullanıcı onayladı; `blaine_south`
      OFFLINE iken Sandy/Desert branch'i kapandı, `ls_central` ve Pillbox
      ONLINE kaldı. Parent blockage çıktısı doğru.
- [x] Parent restore/cascade (2026-08-10): kullanıcı çıktısı doğruladı;
      `sandy_tr_01` `OFFLINE/DESTROYED/damage=100` olarak korunurken
      `blaine_south` restore edildi. DESRT ONLINE geri geldi, SANDY/HARMO
      BLACKOUT kaldı ve `ls_central` etkilenmedi.
- [x] Restart persistence (2026-08-10): kullanıcı onayladı; restart sonrası
      `sandy_tr_01` arızası ve SANDY/HARMO BLACKOUT korundu, DESRT ve
      `ls_central` ONLINE kaldı.
- [x] Yanlış target reddi (2026-08-10): `fake_grid`, `fake_substation` ve
      `fake_feeder` için `INFRASTRUCTURE_FAILURE_REJECTED` üretildi; state
      mutasyonu oluşmadı.
- [ ] Kalan kabul testi: admin ACE'si olmayan oyuncuyla yetkisiz komut testi.

### Sonraki adım

Bu üç phase'in oyun içi kabul testleri ve kullanıcı onayı bekleniyor. Sonraki
paket Phase 22 World Placement olacaktır; mevcut placeholder koordinatlar
korunacak.

---

## 2026-08-09 — Phase 19-21 uygulama son durumu

- Phase 19, 20 ve 21 kod uygulaması tamamlandı.
- Reviewer kontrolünde bulunan API, parent-policy, ownership transfer,
  persistence retry, fallback recalc ve audit güvenlik bulguları düzeltildi.
- 62 Lua dosyasında yorum/string içeriğini ayıklayan lexical delimiter taraması
  temiz çıktı.
- Lokal Lua interpreter olmadığı için unit test sonucu alınamadı.
- SQL importu ve oyun içi kabul testleri tamamlanana kadar Phase 19-21'in
  oyun içi test kutuları bilinçli olarak boş bırakıldı.

---

## Phase 22 — Citywide Transformer/Substation World Placement · TAMAMLANDI (kod) · 2026-08-09

### Ne yapıldı

- Fiziksel placement bilgileri `shared/world_placement.lua` içindeki
  `InfrastructureWorld` registry'sine taşındı.
- Mevcut logical ID'ler korundu; network entity ID kullanılmıyor ve otomatik
  prop spawn edilmiyor.
- Transformer interactable, sabotage mesafe kontrolü, repair mesafe kontrolü,
  teleport ve explosion koordinatları registry üzerinden okunuyor.
- Static placement validation eklendi: koordinat, duplicate/çok yakın nokta,
  radius, model, grid/substation/feeder linki ve expected district kontrolleri.
- `/showinfrastructure [logicalId]` eklendi. Server static topology/state,
  oyuncu client'ı ise mesafe, model, native district ve interaction erişimi
  raporluyor.
- `shared/grids.lua` artık Cfx backtick model literal'larına ihtiyaç duymuyor;
  world registry model adını string olarak taşıyor, client lookup sırasında
  hash'e çeviriyor.

### Dosyalar

- `shared/world_placement.lua` (yeni)
- `shared/grids.lua`, `shared/validators.lua`, `fxmanifest.lua`
- `server/sabotage.lua`, `server/repair_manager.lua`, `server/debug.lua`
- `client/sabotage.lua`, `client/debug.lua`
- `tests/spec/world_placement_spec.lua`, `tests/run.lua`,
  `tests/spec/validators_spec.lua`, `README.md`

### Bilinçli kapsam

- Şimdilik mevcut beş fiziksel point korunuyor: iki substation, üç
  transformer.
- Koordinatlar hâlâ placeholder; oyun içi doğrulama olmadan production
  placement kabul edilmeyecek.
- Yeni district/topology bağlantısı veya rastgele world point üretilmedi.

### Test durumu

- [x] Kod incelemesi.
- [x] 64 Lua dosyasında yorum/string ayıklamalı lexical delimiter taraması temiz.
- [ ] Lokal `lua5.4 tests/run.lua`: bu makinede Lua interpreter yok.
- [x] Oyun içi test: kullanıcı onayladı — `refresh` + `restart gnsh-blackout`,
      `/showinfrastructure`, Sandy/Downtown erişim ve E interact akışı çalışıyor.
- [x] Placeholder kapsamı teyit edildi: mevcut test noktaları çalışıyor;
      tüm gerçek dünya koordinatları, model seçimi ve final erişim mesafeleri
      son placement çalışmasında elle belirlenecek.

### Sonraki adım

Phase 22 mevcut placeholder noktalarıyla oyun içinde doğrulandı. Final dünya
placement'ı (tüm lokasyonların elle ayarlanması) topology ve gameplay bölgeleri
netleştikten sonra, projenin sonlarına doğru yapılacak. Phase 23 ayrı bölümde
kodlandı; oyun içi kabulü henüz yapılmadı.

---

## Phase 23 — Incident ve Dispatch · TAMAMLANDI (kod) · 2026-08-10

### Ne yapıldı

- Incident hedefi artık yalnızca transformer değil; `grid`, `substation`,
  `feeder` ve `transformer` aynı lifecycle üzerinden tutuluyor.
- Her target için tek aktif incident kuralı eklendi. Farklı parent/child
  target'lar aynı anda incident taşıyabilir; aynı target duplicate üretmez.
- Server-authoritative `server/incident_impact.lua` eklendi. Target'ın grid,
  substation, feeder, transformer, etkilenen district listesi, district/player
  impact tahmini ve yaklaşık placement konumu hesaplanıyor.
- Incident kaydında `targetType`, `targetId`, `feederId`,
  `affectedDistricts`, `estimatedImpact` ve `approximateLocation` alanları
  bulunuyor. Mevcut SQL incident tablosu bozulmadı; bilgiler `metadata` JSON
  alanıyla birlikte persist ediliyor.
- Parent failure ONLINE/OFFLINE işlemleri incident oluşturuyor; parent restore
  ilgili aktif incident'ı otomatik `RESOLVED` yapıyor. Child transformer kaydı
  parent failure sırasında değişmiyor.
- Transformer sabotage/admin damage artık aynı IncidentManager yolundan geçiyor;
  sabotage tarafındaki ikinci, duplicate incident oluşturma çağrısı kaldırıldı.
- Yeni `server/dispatch.lua` optional bridge eklendi. `infra:dispatchIncident`
  internal event'i her zaman çalışabilir; dış dispatch resource/event yoksa
  hata üretmeden güvenli biçimde devre dışı kalır.
- `tests/spec/incident_impact_spec.lua` eklendi; transformer, feeder,
  substation, grid impact kapsamı ve bilinmeyen target reddi yazıldı.

### Dosyalar

- `server/incident_impact.lua` (yeni)
- `server/dispatch.lua` (yeni)
- `server/incident_manager.lua`, `server/failure_manager.lua`
- `server/transformer_manager.lua`, `server/sabotage.lua`, `server/debug.lua`
- `shared/types.lua`, `config.lua`, `fxmanifest.lua`
- `tests/spec/incident_impact_spec.lua`, `tests/run.lua`, `README.md`

### Bilinçli kapsam

- Dispatch resource'u hard dependency yapılmadı; gerçek dispatch entegrasyonu
  config ile opsiyonel adapter olarak kalıyor.
- Player count gerçek server native'leriyle runtime'da hesaplanır; saf unit test
  ortamında native olmadığı için 0 dönmesi beklenir.
- Phase 24 External Power API, Phase 25 Random Failure ve sonraki phase'ler
  bu parçada başlatılmadı.

### Test durumu

- [x] Kod incelemesi ve target/lifecycle/persistence akışının statik kontrolü.
- [x] Yeni Lua dosyaları ve değişen dosyalar için delimiter taraması.
- [ ] Lokal `lua5.4 tests/run.lua`: bu makinede Lua interpreter yok.
- [x] `refresh` + `restart gnsh-blackout` sonrası server/F8 hata kontrolü.
- [x] Oyun içi incident impact testi: transformer → feeder → substation → grid.
- [x] Oyun içi parent restore ile incident auto-resolve testi.
- [x] Dispatch resource yokken hata çıkmaması testi.
      Kullanıcı çıktıları beklenen target/impact/restore davranışıyla doğruladı.

### Sonraki adım

Phase 23 oyun içi kabulü tamamlandı ve kullanıcı tarafından onaylandı.
Phase 24 External Power API kodlandı; canlı restart/API kabulü bekleniyor.

---

## Phase 24 — External Power API · TAMAMLANDI (kod) · 2026-08-10

### Ne yapıldı

- Mevcut `IsGridPowered`, `IsDistrictPowered`, `IsPositionPowered` ve state/
  incident export'ları korunarak recursive deep-copy sözleşmesine alındı.
- Yeni server export'ları eklendi: `IsFeederPowered`, `GetFeederState`,
  `IsSubstationPowered`, `GetInfrastructureAtPosition`,
  `GetPowerPathForDistrict`, `GetAffectedDistricts` ve `GetActiveIncidents`.
  `GetAllActiveIncidents` geriye dönük uyumlu alias olarak kaldı.
- Bilinmeyen explicit ID'ler `nil, error` döndürüyor. Tanınan fakat topology'ye
  bağlanmamış district ve eşleşmeyen koordinatlar `powered=true` ile fail-open
  kalıyor.
- District path çıktısı grid → substation → feeder → transformer zincirini,
  `sourceFeederId`, `revision`, `level`, `status` ve `blockedBy` bilgilerini
  taşıyor. Position API server district resolver üzerinden aynı topology
  kararını kullanıyor.
- ACE korumalı read-only `/apiquery` eklendi: feeder, substation, grid, path,
  position, affected ve incidents sorguları destekleniyor.
- Saf `ApiHelpers.DeepCopy` ve koordinat/identifier validation testleri
  `tests/spec/api_spec.lua` içine eklendi. SQL schema değiştirilmedi.
- README export sözleşmesi ve kullanım örnekleriyle güncellendi; resource
  sürümü `0.24.0` yapıldı.

### Canlı testte bulunan düzeltme

- Feeder izolasyonu testinde `blockedBy={type='feeder', ...}` doğru gelirken,
  path/position üst seviyesinde `powered=true, status=BLACKOUT` tutarsızlığı
  görüldü. Kök neden Lua'daki `and/or` fallback ifadesinin geçerli
  `powered=false` değerini grid'in `true` değerine düşürmesiydi.
- `server/api.lua` explicit nil kontrolüne geçirildi. Böylece grid açık,
  feeder kapalı senaryosunda `GetPowerPathForDistrict`,
  `GetInfrastructureAtPosition`, `IsDistrictPowered` ve position API zinciri
  artık doğru şekilde `powered=false` döndürüyor.

### Dosyalar

- `server/api.lua`, `server/api_helpers.lua`, `server/debug.lua`
- `tests/spec/api_spec.lua`, `tests/run.lua`
- `fxmanifest.lua`, `README.md`

### Test durumu

- [x] API sözleşmesi, mevcut manager/replication akışı ve Phase 23
      `IncidentImpact` kullanımı statik olarak incelendi.
- [x] Değişen Lua dosyalarında parantez/süslü parantez delimiter taraması.
- [x] İlk canlı API sorgusu: feeder `blockedBy` ve unknown/fail-open
      sözleşmeleri doğru; path/position `powered` fallback bug'ı bulundu ve
      düzeltildi.
- [ ] Lokal `lua5.4 tests/run.lua`: bu makinede Lua interpreter yok; PASS
      iddiası yapılmadı.
- [x] Oyun içi kabul (2026-08-10): `refresh` + `restart gnsh-blackout` ve
      `/apiquery` sorguları kullanıcı tarafından doğrulandı. Grid ONLINE iken
      feeder A OFFLINE kaldı; SANDY path/position `powered=false,
      status=BLACKOUT, blockedBy=feeder/blaine_south_feed_a`, DESRT ise
      `powered=true, status=ONLINE` döndü. Unknown ID ve BEACH fail-open
      kontrolleri de geçti; server/F8 script error görülmedi.
- [ ] Recursive copy izolasyonu: lokal Lua yokluğu nedeniyle unit test
      sonucu alınamadı; API canlı kabulünde runtime state'in değişmediği ayrıca
      sorgulanacak.

### Sonraki adım

Phase 24 oyun içi kabulü tamamlanmadan Phase 25 Random Failure başlatılmayacak.

## Phase 26-35 Release Candidate Update — 2026-08-10

Phase 25 live acceptance is complete by user confirmation. Phase 26-35 code
and documentation are implemented; final in-game acceptance and `1.0.0`
release remain pending until the user completes the live matrix.

- [x] Phase 26 Security: centralized source/target/distance/session/revision,
  rate-limit and ACE gateway protections.
- [x] Phase 26 live acceptance (2026-08-10): user attempted unauthorized,
  invalid-target and mutation-bypass scenarios; no state bypass or server/F8
  error observed.
- [x] Phase 27 Scale: bounded server/client metrics and hot-path counters.
- [x] Phase 27 live acceptance (2026-08-10): performance scenario test passed;
  no additional server/F8 issue observed.
- [x] Phase 28 live acceptance (2026-08-10): visual profile, native fallback,
  reload, cleanup and restart checks passed without visual or F8 errors.
- [x] Repair restart lifecycle hotfix live acceptance (2026-08-10): restart
  during active repair produced no ox_lib error and repair state recovered.
- [x] Phase 28 Visual: district → grid → native profile resolution and
  failure-isolated HYBRID adapter hook.
- [x] Phase 29 Recovery: partial-recovery invariant test contract.
- [x] Phase 30 Admin: explicit target, ACE-gated commands, audit logs and
  visual resync command.
- [x] Phase 31 Restart/Resync: restore-before-replication boot contract.
- [x] Phase 32 Integration: existing API, incident, dispatch and optional
  adapter contracts retained.
- [x] Phase 33 Production Hardening: debug/metrics/random-failure defaults
  are off; security and fallback behavior are enabled.
- [x] Phase 34 Documentation: architecture, integration, security and
  operations documents added; detailed live test steps stay out of README.
- [ ] Phase 35 Final Acceptance: user live acceptance and SQL import check.
- [x] Local `lua5.4 tests/run.lua`: Lua 5.4.8 executable used; 139 passed,
  0 failed.

### Phase 26-35 files and tests

- New code: `server/security_manager.lua`, `server/metrics.lua`,
  `client/metrics.lua`, `shared/visual_profile_resolver.lua`,
  `client/visual/hybrid.lua`, `server/admin_operations.lua`.
- New tests: `security_spec.lua`, `metrics_spec.lua`,
  `visual_profile_spec.lua`, `recovery_spec.lua`,
  `admin_operations_spec.lua`, `restart_resync_spec.lua`.
- New docs: `docs/ARCHITECTURE.md`, `docs/INTEGRATION_GUIDE.md`,
  `docs/SECURITY.md`, `docs/OPERATIONS.md`.
- [x] Static delimiter/whitespace checks and codebase index refresh.
- [ ] User live acceptance for Phase 26-35.

## Test and Admin Acceptance Update - 2026-08-11

- [x] Admin permission hotfix live acceptance: `refresh` + `restart
  gnsh-blackout` + `/repairall` returned `source=1 success=true` and repaired
  all 3 transformers.
- [x] Admin operations live matrix: feeder, substation, grid state changes,
  restore operations, incident resolution and visual resync completed without
  server/F8 errors.
- [x] Pure Lua unit suite: Lua 5.4.8, `139 passed, 0 failed`.
- [x] Visual profile test fixture corrected to preserve `VisualProfiles.Resolve`
  when the test replaces the registry table; the production resolver behavior
  was unchanged.
- [x] Phase 31 single-player restart/resync matrix accepted by the user:
  full online, feeder, substation, grid, resource restart, reconnect and
  late-join scenarios passed.
- [ ] Multi-player restart/resync scenarios are intentionally deferred to the
  final acceptance stage.

## Production Hardening Code Update - 2026-08-11

- [x] Production defaults hardened: debug tooling and metrics are disabled;
  random failure remains disabled with `tickSec=60` and `cooldownSec=300`.
- [x] Debug tooling now has a controlled `gnsh_blackout_debug` convar override;
  boot validation checks the debug configuration before runtime startup.
- [x] Directly imported runtime libraries are declared explicitly as hard
  dependencies: `ox_lib`, `menuv`, `ox_inventory` and `oxmysql`.
- [x] QBCore, qb-target, dispatch and external consumers remain soft
  integrations with runtime fallback behavior.
- [x] Lua 5.4.8 suite: `139 passed, 0 failed`; all 85 Lua files passed
  `luac -p`; delimiter/whitespace scan passed.
- [ ] Phase 35 final acceptance remains pending: SQL import verification and
  user live acceptance, including the deferred multiplayer matrix.

## Phase 35 Single-Player Acceptance Update - 2026-08-12

- [x] SQL-backed restart restore: after `restart gnsh-blackout`, the active
  sabotage for `sandy_tr_01` remained `OFFLINE/DESTROYED` and its active
  `SABOTAGE` incident was restored without a duplicate-key or server error.
- [x] Post-restart repair/recovery: `sandy_tr_01` returned to
  `ONLINE/HEALTHY` with `damage=0`; `/apiquery incidents` returned `[]`, and
  both `SANDY` and `blaine_south` returned `ONLINE`.
- [x] Independent-grid isolation remained valid: `ls_central` stayed
  `ONLINE` throughout the Sandy persistence/recovery test.
- [x] Final single-player clean restart/resync: after `refresh` and
  `restart gnsh-blackout`, all three transformers were
  `ONLINE/HEALTHY/damage=0`, `/apiquery incidents` returned `[]`, and both
  `blaine_south` and `ls_central` returned `ONLINE` with `level=1.0`.
- [ ] Multiplayer acceptance remains intentionally deferred to the final
  test stage; Phase 35 and the `1.0.0` release are not closed yet.

## Phase 35 Single-Player Regression Update - 2026-08-13

- [x] Failed sabotage skillcheck consumed one C4 item while leaving
  `sandy_tr_01` `ONLINE/HEALTHY/damage=0` and creating no incident.
- [x] Successful sabotage created one `SABOTAGE` incident for
  `sandy_tr_01`; normal repair completed and recovery returned SANDY to
  `ONLINE/powered=true/level=1.0`.
- [x] Final `/apiquery path SANDY` returned `ONLINE`, `/apiquery incidents`
  returned `[]`, and all three transformers were
  `ONLINE/HEALTHY/damage=0`.
- [ ] Multiplayer acceptance remains pending; next test is MP-01 state
  synchronization and district isolation.

## Repair Restart Hotfix - 2026-08-10

- Resource stop sırasında aktif `ox_lib` progress bar artık iptal ediliyor;
  stale function-reference cleanup hatası engelleniyor.
- Server tarafında aktif repair session'lar resource stop sırasında iptal
  edilerek transformer `REPAIRING` state'i `OFFLINE` olarak persistence'a
  bırakılıyor.
- Canlı restart tekrar testi bekliyor.

## Admin Permission Hotfix - 2026-08-11

- QBCore bridge, `Functions.HasPermission` false dÃ¶ndÃ¼ÄŸÃ¼nde ACE
  `admin` yetkisini artÄ±k bastÄ±rmÄ±yor; geÃ§erli ACE grant'i kabul ediliyor.
- txAdmin/master hesabÄ± ile QBCore permission tablosu birbirinden baÄŸÄ±msÄ±z
  olduÄŸundan `/repairall` kontrolÃ¼ server ACE grant'i Ã¼zerinden Ã§alÄ±ÅŸÄ±yor.
- CanlÄ± `refresh`, `restart gnsh-blackout`, `/repairall` doÄŸrulamasÄ± bekliyor.

## Persistence Hotfix - 2026-08-10

- Restart sonrası incident ID counter artık `infrastructure_incidents` tablosundaki
  aktif olmayan tarihçeyi de okuyarak seed ediliyor; eski `INC-000001` kaydıyla
  yeni incident arasında duplicate primary-key oluşmayacak.
- Boot sırasında restore edilen incident ID'leri ve tarihçe counter'ları aynı
  monotonic counter'a bağlandı; SQL migration gerekmedi.
- Canlı restart/resync tekrar testi bekliyor. Lokal `lua5.4 tests/run.lua`
  interpreter yokluğu nedeniyle çalıştırılamadı.
