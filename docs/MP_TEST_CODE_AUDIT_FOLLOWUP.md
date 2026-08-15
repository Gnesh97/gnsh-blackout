# gnsh-blackout — Kod Denetimi Takip Turu (Round 2)

**Tarih:** 2026-08-13
**Önceki tur:** `docs/MP_TEST_CODE_AUDIT.md` (10 bulgu)
**Kapsam:** Birinci tur bulgularına uygulanan düzeltmelerin doğrulanması ve
düzeltmelerin kendi içinde yeni hata üretip üretmediğinin incelenmesi.
**Yöntem:** Statik kod okuması. Değişen dosyalar ve yeni eklenen regresyon testleri
satır satır okundu.

**Test çalıştırma durumu:** Birim testleri **yerelde çalıştırılamadı** — makinede
`lua` / `lua5.4` / `luajit` yorumlayıcısı kurulu değil. `.github/workflows/validate.yml`
CI'da `lua5.4` kuruyor ve `lua5.4 tests/run.lua` çalıştırıyor; asıl doğrulama orada
yapılmalıdır. Aşağıdaki test değerlendirmesi, spec dosyasının beklentileri ile
implementasyonun elle karşılaştırılmasına dayanır.

---

## Bölüm 1 — Birinci tur bulgularının durumu

| # | Başlık | Durum | Kanıt |
|---|---|---|---|
| 1 | Revision sayacı restart'ta sıfırlanıyor | Düzeltildi | `server/replication.lua:49-77`, `:235` |
| 2 | Test komutları debug kapalıyken kayıtlı değil | Düzeltildi | `docs/MULTIPLAYER_ACCEPTANCE_TESTS.md:38-39` |
| 3 | Termit blackout üretmiyor | Düzeltildi | Doküman `:103`, `:480`; `server/sabotage.lua:203-220` |
| 4 | `/apiquery` çıktısı oyuncuya gitmiyor | Düzeltildi | `server/debug.lua` `printApiQueryResult`, `client/debug.lua:13` |
| 5 | Varyant A yerleşimi tutarsız | Düzeltildi | Doküman Varyant A adım 2 |
| 6 | `severity` tip karışıklığı | Düzeltildi | `server/incident_manager.lua:29-47`, `:150`, `:280`, `:341-361` |
| 7 | `CompleteRepair` state dönüşünü kontrol etmiyor | Düzeltildi | `server/repair_manager.lua:289-405` |
| 8 | `RestoreState` olmayan kolonu okuyor | Düzeltildi | `server/transformer_manager.lua:120-123` |
| 9 | `bridge/loader.lua` yanlış `Notify` imzası | Düzeltildi | `bridge/loader.lua:326-331` |
| 10 | `nativeBlackout.enabled` okunmuyor | Düzeltildi | `client/visual/manager.lua:49-51`, `:103`, `:154` |

### Uygulama detayları ve doğrulama notları

**Bulgu 1 — revision tabanı.** `publishedRevisionFloor()` her grid, feeder ve grid'e
bağlı district anahtarını GlobalState üzerinden tarayıp en yüksek revision'ı buluyor;
`Replication.Init()` sayacı `math.max(revisionCounter, floor) + 1` ile başlatıyor.
Böylece restart sonrası ilk yayın, client'ın elinde kalmış eski revision'ın kesin
olarak üstünde oluyor ve stale-guard artık geçerli güncellemeyi düşürmüyor. Aynı
düzeltme `/reloadtopology` ve geç oxmysql restore yollarını da kapsıyor, çünkü ikisi de
aynı `Init()` fonksiyonundan geçiyor. Ardışık iki `Init()` çağrısında da monotonluk
korunuyor (ikinci çağrının tabanı birincinin yayınladığı değer olur).

**Bulgu 7 — repair rollback.** Üç aşama da artık kontrol ediliyor:
`SetState(RECOVERING)` başarısızsa malzeme iade edilip `CancelRepair` çağrılıyor;
`SetDamage(0)` başarısızsa iade + zorunlu OFFLINE + `CancelRepair`; gecikmeli
`SetState(ONLINE)` başarısızsa hasar `originalDamage`'a geri yazılıp trafo OFFLINE'a
alınıyor. Ek olarak `AdvanceStage` session başlatamadığında artık `CancelRepair`
çağırıyor — eskiden yalnız `activeRepairs` kaydı siliniyor ve trafo REPAIRING'de asılı
kalıyordu; bu, denetimde raporlanmamış ikinci bir sızıntıyı da kapatmış oluyor.

**Bulgu 6 — severity.** `normalizeSeverity` sayı, sayısal string ve isimli seviye
(`MINOR`, `MAJOR_DAMAGE`, `DESTROYED` …) girdilerini sayıya çeviriyor; oluşturma,
restore ve karşılaştırma noktalarının üçünde de uygulanıyor. `GetActiveIncidentForGrid`
artık ayrı bir `bestSeverity` değişkeni üzerinden karşılaştırıyor, karışık tipli
karşılaştırma kalmadı.

**Regresyon testleri.** `tests/spec/audit_regression_spec.lua` eklenmiş ve
`tests/run.lua` içine kaydedilmiş. Altı senaryonun beklentileri implementasyonla birebir
örtüşüyor:

- Init, GlobalState'te duran revision 41'in üstüne 42 yazıyor; ikinci Init daha büyük.
- Restore edilen `'100'` string severity sayıya dönüyor, aynı grid'de sayısal severity
  ile karşılaştırılabiliyor.
- RECOVERING geçişi başarısızken hasar yazılmıyor ve malzeme iade ediliyor.
- Final ONLINE başarısızken hasar `originalDamage`'a dönüyor, trafo OFFLINE oluyor,
  malzeme iade ediliyor.
- Başarısız sabotaj item tüketmiyor, cooldown başlatmıyor, hedefi değiştirmiyor.
- Native blackout kapalı profile geçişte paylaşılan efekt `ForceSync(false)` ile
  temizleniyor (`{true, false}` sırası).

Harness uyumu kontrol edildi: `vector3` shim mevcut (`tests/run.lua:60`), `GlobalState`
başka hiçbir spec tarafından kullanılmıyor, `Replication.Init()` yalnız bu spec
tarafından çağrılıyor — dolayısıyla spec'in global'leri geçici olarak değiştirip geri
yüklemesi diğer testleri etkilemiyor.

---

## Bölüm 2 — Bu turda çıkan yeni bulgular

### N1 — Orta: Recovery rollback'inde koşulsuz malzeme iadesi

**Dosya:** `server/repair_manager.lua:391-394`

**Neden**

Gecikmeli recovery callback'inde hasar/state geri alma işlemi
`if current and current.state == RECOVERING then` bloğunun içinde, ama malzeme iadesi
bu bloğun **dışında**: `SetState(ONLINE)` hangi nedenle başarısız olursa olsun iade
çalışıyor. Trafo RECOVERING'den başka bir sebeple çıktıysa tamir aslında geçerli
şekilde tamamlanmıştır; iade hak edilmemiş olur.

**Erişilebilir senaryo**

`server/sabotage.lua:83` RECOVERING durumundaki bir trafoyu reddetmiyor — state OFFLINE
değil ve `SetDamage(0)` sonrası condition HEALTHY. Yani 5 saniyelik recovery penceresinde
ikinci bir oyuncu C4 ile sabotaj yapabiliyor:

1. Tamirci son aşamayı bitirir, malzemeler tüketilir, trafo RECOVERING olur.
2. Saldırgan aynı pencerede sabotaj yapar → `SetDamage(100)` → trafo OFFLINE.
3. Recovery timer'ı çalışır: `SetState(ONLINE)` OFFLINE'dan geçersiz → başarısız.
4. `current.state` artık RECOVERING olmadığı için hasar rollback'i atlanır (doğru), ama
   malzeme iadesi yine de çalışır.

Sonuç: saldırgan 1 C4 harcar, tamirci `fuse` / `wiring_kit` / `control_module` setini
geri alır ve district tekrar kararır. Aynı sonuç `/repairall`,
`/setgridpower <grid> 0` veya `/restoretransformer` bu pencerede çalıştırıldığında da
oluşur.

Bu, kabul testleri dokümanının "Aynı repair veya sabotage başarısının iki kez mutation
üretmesi" / duplicate ödül maddesiyle aynı sınıfta bir davranış.

**Öneri**

`refundMaterials` çağrısı, hasarın gerçekten geri alındığı `current.state == RECOVERING`
bloğunun içine taşınsın; dışarıda kalan durumda yalnız `REPAIR_FAILED` log'u üretilsin.

---

### N2 — Orta (tasarım kararı): Başarısız sabotajın hiçbir maliyeti kalmadı

**Dosya:** `server/sabotage.lua:203-220`

**Neden**

Denetimde istenen düzeltme "başarısız minigame item yakmasın" idi. Uygulamada
`startCooldown(targetId)` çağrısı da `success` dalının içine alındı, yani başarısız bir
deneme artık ne item ne de cooldown maliyeti taşıyor.

**Etki**

Skillcheck'i geçemeyen oyuncu sınırsız kez yeniden deneyebilir; tek fren
`Config.Security.maxEventsPerWindow` (10 saniyede 20 event). Skillcheck pratikte yalnız
zaman maliyeti olan bir formaliteye dönüşüyor. Çoklu oyuncu testlerinde doğrudan bir
FAIL üretmez, ama sabotaj ekonomisi beklentisini değiştirir.

**Öneri**

Başarısızlıkta kısa bir cooldown bırakılsın (örneğin `Config.Sabotage.cooldownSec / 3`
veya ayrı bir `failedCooldownSec`), item tüketimi ise başarıya bağlı kalsın. Mevcut
davranış kasıtlıysa, kabul testleri dokümanının "beklenen kontrollü red" listesine
"başarısız sabotaj cooldown başlatmaz" satırı eklensin.

---

### N3 — Düşük: Test harness'ında `Log.debug` stub'ı yok

**Dosya:** `tests/run.lua:84`

`Log = { event = function() end, warn = function() end, error = function() end }` —
`debug` alanı tanımlı değil. `server/replication.lua`'nın `RecalculateGrid`,
`RecalculateDistrict` ve `RecalculateFeeder` fonksiyonları `Log.debug(...)` çağırıyor.

Bugün hiçbir spec bu fonksiyonları çağırmadığı için suite geçiyor; ancak
`audit_regression_spec.lua` artık `server/replication.lua`'yı yüklüyor, dolayısıyla ilk
recalculate testi eklendiğinde nil-call hatası alınır.

**Öneri:** stub'a `debug = function() end` eklensin.

---

### N4 — Düşük: Yeni mesajlarda Türkçe karakterler düşmüş

Yeni eklenen kullanıcıya görünen metinler diakritiksiz yazılmış, komşu satırlar ise tam
Türkçe:

- `server/repair_manager.lua:329` — `'Tamir durumu guncellenemedi, islem iptal edildi.'`
- `server/repair_manager.lua:343` — `'Tamir hasari sifirlanamadi, islem iptal edildi.'`
- `server/repair_manager.lua:396` — `'Tamir recovery asamasi basarisiz oldu, islem geri alindi.'`
- `server/sabotage.lua:215` — `'Sabotaj esyasi envanterden dusurulemedi, islem iptal edildi.'`
- `bridge/loader.lua:327`, `:329` — `'Bridge durumu server konsoluna yazildi.'`

Karşılaştırma: `server/repair_manager.lua:355` `'Tamir tamamlandı, sistem yeniden
başlatılıyor...'`. Kozmetik tutarsızlık; işlevsel etkisi yok.

---

### N5 — Düşük (not): `acquireHold` sahiplik asimetrisi

**Dosya:** `client/visual/manager.lua:94-114`

`nativeBlackoutEnabled(profile)` false olduğunda `VisualOwnership.Acquire` zaten
çağrılmış ve `heldByDistrict` atanmış oluyor; fonksiyon efekti uygulamadan dönüyor.
Bırakma sırasında ise `releaseCurrentHold` hiç uygulanmamış bir efekt için
`Transition.ForceSync(false)` veya `PlayRecovery` çalıştırıyor.

Adapter idempotent olduğu ve bir client aynı anda tek district'te bulunduğu için bugün
zararsız. Hybrid profillere gerçek asset bağlandığında refcount, kullanılmayan bir
sahiplik tutacağı için ikinci bir sahibin `Acquire` çağrısını bastırabilir
(`VisualOwnership.Acquire` ikinci sahip için false döner).

**Öneri:** native devre dışıyken ya `Acquire` hiç çağrılmasın, ya da ownership kaydı
ayrı bir asset id ile tutulsun.

---

## Önerilen sıra

1. **N1** — malzeme iadesini rollback bloğunun içine taşı (istismar edilebilir tek yol).
2. **N2** — başarısız sabotaj cooldown'u için karar ver, kod veya doküman güncellensin.
3. **N3** — tek satırlık harness düzeltmesi, ileride kırılmayı önler.
4. **N4 / N5** — fırsat bulundukça.

Testler CI'da (`lua5.4 tests/run.lua`) bir kez yeşil görülmeden çoklu oyuncu kabul
testlerine geçilmemesi önerilir.

## Round 2 uygulama durumu

- N1 düzeltildi: recovery callback'i transformer `RECOVERING` durumundan dışarı
  taşınmışsa repair materyali iade edilmiyor.
- N2 kararı kaydedildi: başarısız sabotage skillcheck'i de yapılandırılmış item'ı
  tüketiyor; başarısız sonuç damage, incident veya success cooldown üretmiyor.
- N3 düzeltildi: test harness `Log.debug` stub'ı ekledi.
- N4 düzeltildi: yeni kullanıcı bildirimlerinde Türkçe karakterler tamamlandı.
- N5 düzeltildi: native blackout kapalı profiller native ownership kaydı almıyor;
  hybrid adapter lifecycle çağrıları korunuyor.
- Lua 5.4.8 doğrulaması: `165 passed, 0 failed`.
