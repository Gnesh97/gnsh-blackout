# gnsh-blackout — Çoklu Oyuncu Kabul Testleri Kod Denetimi

**Tarih:** 2026-08-13
**Kapsam:** `docs/MULTIPLAYER_ACCEPTANCE_TESTS.md` içindeki MP-01–MP-06, Varyant A/B/C ve
cleanup adımlarını sağlayan tüm kod yolları.
**Yöntem:** Statik kod okuması. Testler henüz canlı ortamda çalıştırılmadı; aşağıdaki bulgular
kodun kendisinden türetilmiştir, gözlemlenmiş test sonuçları değildir.

**İncelenen dosyalar:** `server/replication.lua`, `server/incident_manager.lua`,
`server/repair_manager.lua`, `server/sabotage.lua`, `server/transformer_manager.lua`,
`server/feeder_manager.lua`, `server/substation_manager.lua`, `server/failure_manager.lua`,
`server/power_calculator.lua`, `server/grid_manager.lua`, `server/incident_impact.lua`,
`server/persistence.lua`, `server/security_manager.lua`, `server/interaction_manager.lua`,
`server/admin_operations.lua`, `server/debug.lua`, `server/api.lua`, `server/api_helpers.lua`,
`server/zone_resolver.lua`, `server/main.lua`, `server/logging.lua`, `server/dispatch.lua`,
`client/main.lua`, `client/district_manager.lua`, `client/state.lua`, `client/debug.lua`,
`client/repair.lua`, `client/sabotage.lua`, `client/zone_resolver.lua`, `client/visual/*.lua`,
`shared/*.lua`, `bridge/loader.lua`, `bridge/**`, `config.lua`, `sql/schema.sql`,
`profiles/*.lua`.

---

## Özet tablo

| # | Önem | Başlık | Etkilenen test |
|---|---|---|---|
| 1 | Kritik | Restart sonrası revision sayacı sıfırlanıyor, client güncellemeyi düşürüyor | MP-05, `/reloadtopology`, geç oxmysql |
| 2 | Bloklayıcı | Test komutlarının çoğu varsayılan config'de kayıtlı değil | Tüm testler |
| 3 | Bloklayıcı | Termit sabotajı blackout üretmiyor, sadece C4 üretiyor | MP-01…MP-06 |
| 4 | Orta | `/apiquery` çıktısı oyuncuya değil server konsoluna gidiyor | MP-01…MP-05 doğrulama adımları |
| 5 | Orta | Varyant A yerleşimi kod ile tutarsız | Varyant A |
| 6 | Orta | `severity` tip karışıklığı → Lua karşılaştırma hatası | MP-05 + Varyant A birleşimi |
| 7 | Düşük-Orta | `CompleteRepair` state dönüşünü kontrol etmiyor | MP-02 kenar durumu |
| 8 | Düşük | `RestoreState` var olmayan `revision` kolonunu okuyor | — |
| 9 | Düşük | `bridge/loader.lua` server tarafı `Notify` imzası yanlış | `/blackoutbridge` |
| 10 | Düşük | `profile.nativeBlackout.enabled` hiç okunmuyor | — |

---

## 1. Kritik — Restart sonrası revision sayacı sıfırlanıyor, client güncellemeyi düşürüyor

**Dosyalar**

- `server/replication.lua:200` — `Replication.Init()` içinde `revisionCounter = 0`
- `client/main.lua:105` — `if value.revision <= ClientState.CurrentPowerRevision then return end`
- `client/main.lua:74` — `ClientState.CurrentPowerRevision = state.revision` (GlobalState'ten okunan değer)
- `server/main.lua:72` — `onResourceStop` hiçbir GlobalState anahtarını temizlemiyor

**Neden**

GlobalState anahtarları resource'a değil server'a ait; `restart gnsh-blackout` sonrasında eski
değerler hem server'da hem client'ın yerel state bag kopyasında duruyor. Client tarafında
`ClientState.Reset()` revision'ı `-1` yapıyor, ancak `start()` hemen ardından
`applyDistrictState()` ile GlobalState'i okuyup **restart öncesine ait** revision değerini geri
yüklüyor. Server ise `Replication.Init()` ile sayacı sıfırdan başlatıyor.

Sayılarla, dokümanın MP-05 senaryosu:

1. Temiz başlangıç, tüm anahtarlar `revision = 0`.
2. C4 ile `sandy_tr_01` sabotajı → `RecalculateForTransformer`: grid değişmiyor (PRIMARY
   politikası `blaine_south_tr_02` sayesinde ONLINE kalıyor, bump yok), feeder A `rev 1`,
   `SANDY` `rev 2`, `HARMO` `rev 3`.
3. `restart gnsh-blackout`. Client `CurrentPowerRevision = -1` yapıyor, sonra GlobalState'teki
   eski `SANDY` kaydını okuyup `CurrentPowerRevision = 2` yapıyor.
4. Server boot → `Init()` her anahtarı `rev 0` ile yeniden yayınlıyor. Client `0 <= 2` diyerek
   düşürüyor; içerik aynı olduğu için görsel fark oluşmuyor, hata bu adımda gizli kalıyor.
5. A tamiri tamamlıyor → trafo ONLINE → feeder `rev 1`, `SANDY` **`rev 2`**, `HARMO` `rev 3`.
6. Client `2 <= 2` → **güncelleme düşürülüyor**. Server ONLINE derken oyuncu görsel blackout'ta
   kalıyor.

Restart sonrası artış dizisi restart öncesiyle birebir aynı olduğu için çakışma rastlantısal
değil, sistematiktir. Tek belirsizlik client'ın GlobalState'i Init publish'inden önce mi sonra
mı okuduğudur; server boot'u `Persistence.LoadAll()` üzerinden DB sorgusu beklediği için
client'ın eski değeri okuması olası senaryodur.

**Test etkisi**

MP-05 "Beklenen sonuç" maddesi *"A'nın repair'i sonrasında iki client online recovery görür"*
FAIL verir. `/resyncvisual`, `/reloadvisual` veya district'ten çıkıp girmek hatayı maskeler; bu
yüzden yanlışlıkla PASS verilmesi de mümkündür.

Aynı kök neden iki yerde daha, **yarış olmadan** tetiklenir:

- `server/admin_operations.lua:216` — `/reloadtopology` canlı oyuncularla `Replication.Init()`
  çağırıyor.
- `server/main.lua:69` — oxmysql, gnsh-blackout'tan sonra başlarsa geç restore yolunda
  `Replication.Init()` çağrılıyor.

Her iki durumda da tüm anahtarlar `rev 0`'a döner ve o an revision'ı sıfırdan büyük olan her
client, kendi district'i için sonraki güncellemeleri sayaç eski değeri geçene kadar yok sayar.

**Not:** `tests/spec/restart_resync_spec.lua` revision ile ilgili hiçbir assert içermiyor, yani
bu davranış test kapsamı dışında.

**Öneriler (biri yeterli)**

- `Replication.Init()` sayacı sıfırlamasın; `os.time()` gibi restart'lar arasında monotonik bir
  değerle seed edilsin.
- Ya da Init, hâlihazırda yayınlanmış anahtarlardaki en yüksek revision + 1 ile başlasın.
- Ya da payload'a `bootEpoch` eklensin; client farklı epoch gördüğünde stale-guard'ı atlasın.
- Ek olarak `onResourceStop` sırasında GlobalState anahtarlarının temizlenmesi eski değerin hiç
  okunmamasını sağlar (tek başına yarışı kapatır ama `/reloadtopology` yolunu kapatmaz).

---

## 2. Bloklayıcı — Test komutlarının çoğu varsayılan config'de kayıtlı değil

**Dosyalar**

- `config.lua:33` — `Config.Debug.enabled = false`
- `server/debug.lua:17` — `if not Config.IsDebugEnabled() then return end`
- `client/debug.lua:11` — aynı erken `return`

**Neden**

Her iki debug dosyası da `Config.IsDebugEnabled()` false iken dosyanın ilk satırında dönüyor,
dolayısıyla içindeki hiçbir `RegisterCommand` çalışmıyor.

Bu durumda **kayıtlı olmayan** komutlar: `apiquery`, `griddebug` (hem server hem client),
`showtransformers`, `showfeeders`, `showsubstations`, `showdistrictpower`, `powerpath`,
`topologyaudit`, `showincidents`, `powerdebug`, `repairdebug`, `forcerepair`, `setdamage`,
`setgridpower`, `giveitem`, `showinfrastructure`, `showdistrict`, `visualprofile`,
`reloadvisual`, `districtaudit`, `districtauditauto`, `districtauditreport`,
`districtregistry`, `testtransition`, `visualdebug`.

Debug'dan bağımsız çalışanlar (`server/admin_operations.lua`): `setgridstate`,
`setsubstationstate`, `setfeederstate`, `restoregrid`, `restoresubstation`, `restorefeeder`,
`restoretransformer`, `createincident`, `resolveincident`, `reloadtopology`, `resyncvisual`,
`repairall`.

**Test etkisi**

Doküman "Test öncesi şartlar" bölümü debug'ın açılmasından hiç söz etmiyor; "temiz başlangıç"
adımındaki `showtransformers` / `showfeeders` / `showsubstations` / `/apiquery` çağrılarının
tamamı sessizce hiçbir şey yapmaz. Test doküman haliyle başlatılamaz.

**Öneri**

Doküman şartlarına `setr gnsh_blackout_debug true` (ve test sonunda geri kapatma) adımı
eklensin. Alternatif olarak salt-okunur teşhis komutları (`apiquery`, `showfeeders`,
`showtransformers`, `showdistrictpower`, `powerpath`, `topologyaudit`) admin gate'i korunarak
`admin_operations.lua` tarafına taşınabilir; böylece production'da debug kapalıyken de
operasyon görünürlüğü kalır.

---

## 3. Bloklayıcı — Termit sabotajı blackout üretmiyor, sadece C4 üretiyor

**Dosyalar**

- `config.lua:163` — `thermite = { item = 'thermite', damage = 60, ... }`
- `config.lua:164` — `c4 = { item = 'plastic', damage = 100, ... }`
- `shared/constants.lua:187` — `51-80 → MAJOR_DAMAGE`, `100 → DESTROYED`
- `config.lua:91` — `Config.OfflineAtCondition = 'DESTROYED'`
- `server/transformer_manager.lua:244` — OFFLINE'a zorlama yalnız `condition == DESTROYED` iken
- `client/sabotage.lua:72-73` — etkileşim menüsünde iki seçenek de sunuluyor

**Neden**

Termit 60 hasar veriyor, bu `MAJOR_DAMAGE` demek. `Config.OfflineAtCondition` `DESTROYED`
olduğu için trafo ONLINE kalıyor. Trafo OFFLINE olmadığı için incident de oluşmuyor — incident
yalnızca `SetState(..., OFFLINE, ...)` yolunda üretiliyor (`server/transformer_manager.lua:176`).
Feeder ve district hesabı ONLINE trafo gördüğü için hiçbir şey kararmıyor.

**Test etkisi**

MP-01, MP-02, MP-03, MP-04, MP-05 ve MP-06'nın tamamı "sabotaj tamamlandıktan sonra blackout"
varsayımıyla başlıyor ama doküman hangi sabotaj türünün seçileceğini söylemiyor. Termit
seçilirse hiçbir incident ve blackout oluşmaz; test yanlışlıkla FAIL olarak kaydedilir.

**İkincil bulgular (aynı akış)**

- `server/transformer_manager.lua:231` — `SetDamage` hasarı **mutlak** yazıyor, biriktirmiyor.
  Üst üste iki termit yine 60'ta kalır, hiçbir zaman DESTROYED olmaz.
- `server/sabotage.lua:200` — item tüketimi `if success` kontrolünden **önce** yapılıyor;
  minigame başarısız olsa da item gidiyor. Dokümanın "item yalnızca yetkili başarılı akışta
  tüketilir" beklentisiyle (MP-02 madde 7) çelişebilir.

**Öneri**

Doküman adımlarında sabotaj türü açıkça "C4" yazılsın. Termitin de blackout üretmesi
isteniyorsa `Config.OfflineAtCondition = 'CRITICAL_DAMAGE'` yapılabilir veya termit hasarı
yükseltilebilir — ama bu bir davranış değişikliğidir, test öncesi karar gerektirir.

---

## 4. Orta — `/apiquery` çıktısı oyuncuya değil server konsoluna gidiyor

**Dosyalar**

- `server/debug.lua:26-44` — `printApiQueryResult`: sonuç `print()` ile server konsoluna,
  oyuncuya yalnız "API sonucu server konsoluna yazıldı." bildirimi
- `server/debug.lua:47` — `if not isAllowed(source) then return end` (admin şartı)

**Neden**

Komut server tarafında kayıtlı ve çıktı `print` ile server konsoluna basılıyor. Çıktı satırında
komutu çalıştıran oyuncunun id'si de yer almıyor.

**Test etkisi**

- Doküman satır 135: *"apiquery sonucu komutu çalıştıran oyuncunun chat/F8 çıktısına düşer"* —
  yanlış.
- MP-01 adım 8 (*"Incident ID'nin A ve B çıktısında aynı olduğu kontrol edilir"*) ve MP-05
  adım 6 (*"İki oyuncu da aşağıdaki sorguları çalıştırsın"*) bu haliyle uygulanamaz: iki
  oyuncunun çıktıları konsolda ayırt edilemez.
- Doküman her iki oyuncunun da çalıştırmasını istiyor ancak komut admin yetkisi gerektiriyor.

**İkincil:** Boş incident listesi `json.encode` ile `{}` basar, doküman `[]` bekliyor.

**Öneri**

Sonuç çağırana da gönderilsin (`TriggerClientEvent` ile F8 konsoluna) veya konsol satırına
`source=<id>` eklensin. Doküman metni de buna göre düzeltilsin.

---

## 5. Orta — Varyant A yerleşimi kod ile tutarsız

**Dosyalar**

- `shared/world_placement.lua:31` — `blaine_south_tr_02` konumu `vector3(1975.0, 3745.0, 32.2)`
- `shared/districts.lua:57` — `SANDY` AABB `{1450,3300,20} … {2450,3850,100}`
- `server/repair_manager.lua:176-180` — repair için 6 m mesafe şartı
- `server/sabotage.lua:101-106` — sabotaj için 5 m mesafe şartı

**Neden**

`blaine_south_tr_02` mantıksal olarak DESRT'i besliyor ama fiziksel olarak Sandy Shores'ta,
`sandy_tr_01`'in 14 metre yanında duruyor.

**Test etkisi**

Varyant A "Oyuncu B `DESRT` konumunda olsun" diyor, sonra "B normal repair'i tamamlasın" diyor.
B, tamir için Sandy'ye gitmek zorunda. Adım sırası bunu belirtmiyor; test sırasında "mesafe
hatası" alınıp yanlış FAIL kaydedilebilir.

**Öneri**

Varyant A adımlarına "B, gözlem için DESRT'te durur; sabotaj/tamir için trafonun yanına gider,
sonra tekrar DESRT'e döner" notu eklensin.

---

## 6. Orta — `severity` tip karışıklığı → Lua karşılaştırma hatası

**Dosyalar**

- `server/incident_manager.lua:329-330` — `inc.severity > best.severity`
- `server/incident_manager.lua:130` — yeni incident'ta `severity = params.severity or 100` (number)
- `server/persistence.lua:125` — DB'ye `tostring(inc.severity)` yazılıyor
- `sql/schema.sql` — `severity VARCHAR(16) NOT NULL DEFAULT 'MINOR'`
- `server/persistence.lua:84` — restore'da `severity = row.severity` (string)

**Neden**

Bellekte üretilen incident'ların `severity` alanı sayı, DB'den restore edilenlerinki string.
`GetActiveIncidentForGrid` aynı grid'deki aktif incident'ları severity'ye göre karşılaştırıyor.
Aynı grid altında biri restore edilmiş, diğeri yeni iki aktif incident varsa Lua
"attempt to compare number with string" hatası verir.

**Test etkisi**

MP-05 (restart ile restore edilmiş `sandy_tr_01` incident'ı) + Varyant A
(`blaine_south_tr_02` sabotajı) birlikte çalıştırılırsa `blaine_south` grid'inde iki aktif
incident olur. `InfrastructureApi.GetActiveIncident` export'unu çağıran her şey (dış
entegrasyonlar) patlar. Doküman komutları bu export'u kullanmıyor, bu yüzden testte doğrudan
görünmeyebilir.

**Öneri**

`CreateIncident` ve `RestoreIncident` içinde severity `tonumber(...)` ile normalize edilsin
(sayıya çevrilemiyorsa sabit bir sayısal karşılık kullanılsın), veya karşılaştırma
`tonumber(inc.severity) or 0` üzerinden yapılsın.

---

## 7. Düşük-Orta — `CompleteRepair` state dönüş değerini kontrol etmiyor

**Dosya:** `server/repair_manager.lua:281-312`

**Neden**

Sıra şu: malzemeler tüketiliyor (`:281`) → `SetState(RECOVERING)` (`:301`, dönüş değeri yok
sayılıyor) → `SetDamage(0)` → 5 sn sonra `SetState(ONLINE)`.

Trafo o anda `REPAIRING` değilse `REPAIRING → RECOVERING` kenarı geçersizdir
(`server/transformer_manager.lua:40`), `SetState` false döner ve sessizce yutulur. Sonraki
`RECOVERING → ONLINE` de geçersiz olur (OFFLINE'dan ONLINE'a doğrudan geçiş yok). Sonuç:
malzeme harcanmış, hasar sıfırlanmış, trafo OFFLINE'da kalmış, incident çözülmemiş.

**Test etkisi**

Dokümanın FAIL tanımıyla birebir örtüşen bir durum ("item tüketildi ama recovery yok").
Bugünkü akışlarda tetiklenmesi zor — `/repairall` ve `/restoretransformer`, `CancelRepair`
üzerinden `activeRepairs` kaydını temizlediği için `CompleteRepair` erken dönüyor. Yine de
savunmasız bir yol.

**Öneri**

`SetState(RECOVERING)` false dönerse `CancelRepair` + malzeme iadesi yapılsın veya en azından
`REPAIR_FAILED` log'u üretilip akış durdurulsun.

---

## 8. Düşük — `RestoreState` var olmayan `revision` kolonunu okuyor

**Dosyalar**

- `server/transformer_manager.lua:120` — `rec.revision = tonumber(row.revision) or rec.revision or 0`
- `server/persistence.lua:103-115` — `SaveTransformer` böyle bir kolon yazmıyor
- `sql/schema.sql` — `infrastructure_transformers` tablosunda `revision` kolonu yok

**Neden**

Yazılmayan bir kolon okunuyor; değer her zaman `nil` gelir ve revision restart sonrası 0'dan
başlar.

**Test etkisi**

Bugün zararsız: interaction session'ları bellekte tutuluyor ve restart'ta yok oluyor, dolayısıyla
restart öncesi bir `targetRevision` ile restart sonrası bir trafo revision'ı hiç karşılaşmıyor.
Yine de ölü okuma; ileride session persistence eklenirse sessiz hataya dönüşür.

---

## 9. Düşük — `bridge/loader.lua` server tarafında yanlış `Notify` imzası

**Dosya:** `bridge/loader.lua:325`

```lua
if source and source ~= 0 and Bridge.Notify then Bridge.Notify('Bridge durumu server konsoluna yazıldı.', 'info') end
```

Server tarafında imza `Notify(source, message, notifyType)` (`bridge/notify/internal.lua:8`).
Mesaj `source` parametresine geçiyor; bildirim hiçbir oyuncuya ulaşmıyor. Yalnız
`/blackoutbridge` komutunu etkiliyor.

---

## 10. Düşük — `profile.nativeBlackout.enabled` hiç okunmuyor

**Dosyalar:** `client/visual/manager.lua:79`, `client/visual/manager.lua:99`

Profillerde `nativeBlackout.enabled` alanı tanımlı (`profiles/sandy.lua:46`,
`shared/visual_profile_resolver.lua:15`) ama görsel katman yalnız `affectVehicles` alanını
okuyor. `enabled = false` ayarlanmış bir profilde de native blackout uygulanır. Bugün tüm
profillerde `true` olduğu için görünür etkisi yok.

---

## Doğrulanan ve doğru bulunan davranışlar

Aşağıdaki test beklentileri kod tarafından karşılanıyor:

- **District izolasyonu (MP-01, Varyant A/B).** `sandy_tr_01` OFFLINE iken grid `blaine_south`
  PRIMARY politikası gereği `blaine_south_tr_02` sayesinde ONLINE kalıyor; yalnız feeder A'nın
  district'leri (SANDY, HARMO) kararıyor. `recalculateGridFallbackDistricts`
  (`server/replication.lua:364`) feeder kapsamındaki district'lere dokunmuyor, bu yüzden DESRT
  etkilenmiyor. `ls_central` tamamen ayrı grid/feeder zincirinde.
- **Repair session lock (MP-02).** İkinci repair isteği `activeRepairs[transformerId]`
  kontrolünde reddediliyor (`server/repair_manager.lua:160`); malzeme kontrolü salt-okunur,
  tüketim yalnız `CompleteRepair` içinde. Duplicate session, duplicate incident veya duplicate
  item tüketimi üretmiyor. `InteractionManager` target lock'u aynı hedefte ikinci bir etkileşimi
  kontrollü şekilde reddediyor.
- **Disconnect temizliği (MP-02 ek kontrol, MP-03).** `playerDropped` iki yerde işleniyor:
  `server/interaction_manager.lua:159` session ve target lock'u serbest bırakıyor,
  `server/repair_manager.lua:401` yalnız kendi kaydını siliyor. Trafo REPAIRING kalıyor,
  ilerleme incident metadata'sında duruyor, ikinci oyuncu kaldığı yerden devam edebiliyor.
  Stale lock kalmıyor.
- **Incident tekilliği ve restore (MP-01, MP-03, MP-04, MP-05).** Hedef başına tek aktif
  incident (`server/incident_manager.lua:106`). `RestoreIncident` `CreateIncident`'ı bypass
  ediyor, yani restart'ta yeni ID üretilmiyor ve duplicate SQL INSERT olmuyor; sayaç
  `SetCounterAtLeast` ile en yüksek kalıcı ID'nin üstüne çıkıyor.
- **Late-join / reconnect snapshot (MP-03, MP-04).** `applyDistrictState(..., instant = true)`
  yolu Phase 15 sekansını oynatmadan doğrudan doğru duruma sıçrıyor; `playerSpawned` ek bir
  force-resolve tetikliyor. Yayınlanmış state yoksa fail-open (powered) davranıyor.
- **Resync yan etkisizliği (MP-06).** `/resyncvisual` yalnız client event tetikliyor; incident
  oluşturmuyor, transformer damage'ına dokunmuyor, SQL yazmıyor (yalnızca bir `ADMIN_ACTION`
  log satırı). `Log.event` sadece konsola yazıyor (`server/logging.lua:46`).
- **Parent failure replication (Varyant C).** Feeder/substation override'ı
  `FailureManager.GetBlockingAncestor` üzerinden feeder ve district state'ine iniyor; restore
  ilgili incident'ı çözüyor. Parent OFFLINE iken child ONLINE olsa bile district OFFLINE kalıyor.
- **Anti-speedhack zamanlaması.** `os.time()` saniye çözünürlüğüne rağmen
  `now - issuedAt >= minDuration` her zaman sağlanıyor (her iki uç da aşağı yuvarlandığı için
  fark en az `minDuration` çıkıyor), yani geçerli akışlar yanlışlıkla reddedilmiyor.

---

## Önerilen sıra

1. **Test başlatmadan önce (doküman/config):** Bulgu 2 (debug convar adımı) ve Bulgu 3 (sabotaj
   türü olarak C4), ardından Bulgu 4 ve Bulgu 5 (doküman metni düzeltmeleri).
2. **Kod düzeltmesi:** Bulgu 1 (revision epoch/monotonluk) — MP-05 bu düzeltilmeden güvenilir
   sonuç vermez.
3. **Ardından:** Bulgu 6 (severity normalize) ve Bulgu 7 (`CompleteRepair` dönüş kontrolü).
4. **Fırsat bulundukça:** Bulgu 8, 9, 10.
