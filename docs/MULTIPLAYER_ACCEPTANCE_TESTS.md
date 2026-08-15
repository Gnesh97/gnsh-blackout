# gnsh-blackout — Çoklu Oyuncu Kabul Testleri

Bu belge, Phase 35 final kabulü için tek oyunculu testlerden sonra yapılacak
canlı çoklu oyuncu testlerini içerir. Ayrıntılı canlı test adımları README'ye
eklenmez; operasyon sırasında bu belge kullanılır.

## Kapsam ve durum

Fonksiyonel çoklu oyuncu kabulü 6 ana test paketinden oluşur:

1. State senkronu ve district izolasyonu
2. Eşzamanlı repair/session lock davranışı
3. Aktif blackout sırasında reconnect
4. Aktif blackout sırasında late-join
5. İki oyuncu bağlıyken resource restart/resync
6. District geçişi ve visual resync

Phase 27 performans yük testleri ayrı tutulur:

- PERF-32: 32 oyuncu
- PERF-64: 64 oyuncu
- PERF-128: 128 oyuncu

32/64/128 gerçek oyuncu veya uygun bir load harness bulunmadığı sürece bu
üç test `DEFERRED/BLOCKED` olarak kaydedilir; `FAIL` yazılmaz. Bu durum
fonksiyonel çoklu oyuncu testlerinin yapılmasına engel değildir.

## Test öncesi şartlar

- En az iki gerçek FiveM client'ı aynı server'a bağlı olmalı.
- `oxmysql` başlamış olmalı ve mevcut `sql/schema.sql` import edilmiş olmalı.
- `gnsh-blackout` güncel kodla çalışıyor olmalı.
- Her iki oyuncunun player ID'si not edilmeli.
- Test boyunca oyuncu A ve oyuncu B ayrımı korunmalı.
- `Config.RandomFailure.enabled = false` kalmalı; test sonucu otomatik
  random failure tarafından kirletilmemeli.
- Debug doğrulama komutları için test oturumu öncesinde server konsolunda
  `setr gnsh_blackout_debug true` ayarlanmalı ve resource yeniden başlatılmalı.
  Test tamamlanınca `setr gnsh_blackout_debug false` yapılıp resource tekrar
  başlatılarak production default'una dönülür.
- Admin test komutları için ACE/txAdmin yetkisi hazır olmalı.
- Sabotaj ve tamir için gereken item'lar hazır olmalı.

### Test alanları ve topology hedefleri

| Hedef | Konum | Etkilenen district | Grid/feeder |
|---|---|---|---|
| `sandy_tr_01` | `vector3(1961.0, 3745.0, 32.2)` | `SANDY`, `HARMO` | `blaine_south` / `blaine_south_feed_a` |
| `blaine_south_tr_02` | `vector3(1975.0, 3745.0, 32.2)` | `DESRT` | `blaine_south` / `blaine_south_feed_b` |
| `ls_central_tr_01` | `vector3(-195.0, -615.0, 33.0)` | `DOWNT`, `PBOX`, `SKID` | `ls_central` / `ls_central_feed_a` |

Koordinat uyuşmazlığı görülürse koordinat uydurulmaz; server tarafında
`showinfrastructure` veya mevcut topology verisi kontrol edilir.

### Her testten önce temiz başlangıç

Server konsolunda:

```text
refresh
restart gnsh-blackout
```

Resource başladıktan sonra 10–15 saniye beklenir. Oyunculardan biri şu
kontrolleri yapar:

```text
showtransformers
showfeeders
showsubstations
/apiquery incidents
/apiquery grid blaine_south
/apiquery grid ls_central
```

Beklenen temiz başlangıç:

- `sandy_tr_01`, `blaine_south_tr_02` ve `ls_central_tr_01`:
  `ONLINE / HEALTHY / damage=0`
- `/apiquery incidents` sonucu `[]`
- `blaine_south` ve `ls_central`: `ONLINE`, `powered=true`, `level=1.0`
- Aktif repair lock veya yarım kalmış session olmaması
- Server/F8 konsolunda script, SQL veya bridge hatası olmaması

Temiz başlangıç sağlanamıyorsa test başlatılmaz. Gerekirse yalnızca cleanup
için admin `/repairall` kullanılır ve temiz başlangıç tekrar doğrulanır.

### Item hazırlığı

Gerçek sabotage/repair akışında item tüketimi gözlenmek isteniyorsa item
sayısı testten önce not edilir. Planı görmek için server konsolunda:

```text
repairdebug sandy_tr_01
```

Çıktıdaki materyaller oyunculara admin test komutuyla verilebilir:

```text
giveitem <playerId> <item> <amount>
```

Blackout beklenen sabotage testlerinde C4 sabotage seçeneği kullanılmalıdır.
Varsayılan config'te thermite 60 damage ile `MAJOR_DAMAGE` üretir ve
`OfflineAtCondition = DESTROYED` olduğu için tek başına blackout başlatmaz.
Sabotaj için kullanılan item adı mevcut config/bridge ayarından alınır; test
metni içinde item adı varsayılmaz. Item miktarı testten önce ve sonra not
edilir. `/repairall` gerçek repair/session davranışı ölçülen testlerin
ortasında kullanılmaz.

Başarısız sabotage skillcheck'i de geçerli bir denemedir: yapılandırılmış
sabotaj item'ı server tarafından tüketilir, fakat transformer damage, incident
ve başarı cooldown'u oluşturulmaz. Item tüketimi başarısız olursa işlem fail
closed olarak reddedilir.

## Ortak doğrulama komutları

### Oyuncu tarafı

```text
/showdistrict
/griddebug
/visualprofile
/reloadvisual
```

`/griddebug` ve `/visualprofile` çıktıları oyuncunun bulunduğu district/grid
ve client visual durumunu gösterir. `/reloadvisual` yalnızca visual state'i
yeniler; logical power state'i değiştirmemelidir.

### Server/API tarafı

```text
/apiquery incidents
/apiquery path SANDY
/apiquery path HARMO
/apiquery path DESRT
/apiquery path DOWNT
/apiquery path PBOX
/apiquery grid blaine_south
/apiquery grid ls_central
showtransformers
showfeeders
showsubstations
```

`apiquery` sonucu komutu çalıştıran oyuncunun F8 çıktısına gönderilir. Server
konsolunda aynı satır `source=<playerId>` ile yazılır. Aynı sorgu iki oyuncuda
da çalıştırılarak state snapshot'ı karşılaştırılır.

### Admin ve lifecycle komutları

```text
/resyncvisual all
/resyncvisual <playerId>
/repairall
```

`/resyncvisual` yalnızca client visual state'ini yeniler. `/repairall` yalnızca
test cleanup'ı içindir; normal repair kabulü olarak sayılmaz.

Server console lifecycle komutları:

```text
refresh
restart gnsh-blackout
```

## MP-01 — State senkronu ve district izolasyonu

### Amaç

Bir oyuncunun yaptığı sabotage sonucunun diğer oyuncuya doğru incident ve
visual state olarak ulaşmasını, aynı zamanda bağımsız district'in yanlışlıkla
kararmamasını doğrulamak.

### Yerleşim

- Oyuncu A: `SANDY`, `sandy_tr_01` yanında
- Oyuncu B: `DESRT` veya `DOWNT`

### Adımlar

1. Temiz başlangıç kontrollerini çalıştır.
2. Oyuncu A `sandy_tr_01` ile etkileşime girsin.
3. Sabotaj menüsünden sabotage seçsin.
4. Skillcheck'i tamamlasın.
5. Sabotaj tamamlandıktan sonra A ve B aynı anda aşağıdaki sorguları
   çalıştırsın:

   ```text
   /apiquery incidents
   /apiquery path SANDY
   /apiquery path DESRT
   /showdistrict
   /griddebug
   ```

6. A'nın bulunduğu SANDY'de blackout visual'ı gözlenir.
7. B'nin bulunduğu DESRT'te elektrik ve visual state'in değişmediği gözlenir.
8. Incident ID'nin A ve B çıktısında aynı olduğu kontrol edilir.
9. Oyuncu A normal repair akışını tamamlasın.
10. Repair tamamlanınca iki oyuncu tekrar path/grid/incident sorgularını
    çalıştırsın.

### Beklenen sonuç

- Tek bir aktif incident oluşur.
- Incident `targetType=transformer`, `targetId=sandy_tr_01`,
  `cause=SABOTAGE` olur.
- `affectedDistricts` en az `SANDY` ve `HARMO` içerir.
- A'nın SANDY visual state'i blackout olur.
- B'nin DESRT state'i `ONLINE`, `powered=true` kalır.
- Aynı incident iki kez oluşturulmaz.
- Repair sonrası incident listesi `[]` olur.
- SANDY/HARMO tekrar online olur; DESRT zaten online kalır.
- Her iki client'ta F8 script hatası görülmez.

### Başarısızlık örnekleri

- B'nin bağımsız district'i de kararıyorsa izolasyon hatası.
- A ve B farklı incident ID görüyorsa replication hatası.
- Repair sonrası yalnızca bir client online oluyorsa resync hatası.
- Geçerli işlem sırasında `SECURITY_REJECTED`, SQL duplicate veya script
  error oluşuyorsa test başarısızdır.

## MP-02 — Eşzamanlı repair ve session lock

### Amaç

Aynı transformer üzerinde iki oyuncunun aynı anda repair başlatmasının tek
bir server-authoritative session üretmesini doğrulamak.

### Yerleşim

- Oyuncu A ve B: `sandy_tr_01` yanında
- İki oyuncuda da gerekirse repair materyalleri bulunmalı

### Adımlar

1. `sandy_tr_01` üzerinde sabotage ile aktif incident oluştur.
2. İki oyuncunun da SANDY blackout'u gördüğünü doğrula.
3. Oyuncu A repair başlatsın.
4. A ilk stage'i tamamlamadan B aynı transformer üzerinde repair başlatsın.
5. B'nin aldığı mesajı ve server logunu kaydet.
6. A tüm stage'leri normal akışla tamamlasın.
7. A'nın her stage'inden sonra B şu kontrolleri yapsın:

   ```text
   /apiquery path SANDY
   /apiquery incidents
   ```

8. A final stage'i tamamladığında A ve B state'i tekrar karşılaştırsın.
9. Her iki oyuncunun envanterindeki materyal miktarını test öncesiyle
   karşılaştır.

### Beklenen sonuç

- Aynı target için yalnızca bir aktif repair session bulunur.
- B'nin ikinci repair isteği lock/target-busy benzeri kontrollü bir nedenle
  reddedilir.
- B'nin reddedilen isteği yeni incident, yeni session veya duplicate reward
  üretmez.
- A'nın başarılı repair'i tamamlanır ve tek bir recovery oluşur.
- Final stage öncesi transformer/district online olarak raporlanmaz.
- Final stage sonrası iki client aynı `ONLINE` state'i görür.
- Başarılı repair item'ları tüketir; başarısız sabotage skillcheck'i bir
  sabotage item'ı tüketir. Reddedilen duplicate işlem item tüketmez.
- Server/F8'te beklenmeyen hata olmaz.

### Ek kontrol

A repair sırasında disconnect edilirse testin MP-03 disconnect cleanup
varyantına geçilir; aynı session'ın B tarafından otomatik devralınması
beklenmez. Stale lock kalmamalı ve sonraki temiz repair mümkün olmalıdır.

## MP-03 — Aktif blackout sırasında reconnect

### Amaç

Blackout başladıktan sonra daha önce bağlı bir oyuncunun disconnect/reconnect
sonrasında güncel logical ve visual snapshot'ı almasını doğrulamak.

### Yerleşim

- Oyuncu A: SANDY veya server state'i gözlemleyecek konum
- Oyuncu B: SANDY içinde veya reconnect sonrası SANDY'ye gidebilecek durumda

### Adımlar

1. A, `sandy_tr_01` üzerinde sabotage tamamlasın.
2. A ve B incident ID'sini ve SANDY path state'ini not etsin.
3. Oyuncu B serverdan ayrılıp yeniden bağlansın.
4. B karaktere girdikten sonra 10 saniye beklesin.
5. B SANDY'de değilse SANDY'ye geçsin.
6. B şu kontrolleri çalıştırsın:

   ```text
   /showdistrict
   /griddebug
   /apiquery incidents
   /apiquery path SANDY
   ```

7. A aynı anda incident ID'sini ve SANDY state'ini tekrar kontrol etsin.
8. A normal repair'i tamamlasın.
9. B recovery state'ini gözlemlesin.

### Beklenen sonuç

- B reconnect sonrası mevcut active incident'i görür; yeni incident oluşmaz.
- B'nin SANDY logical state'i `BLACKOUT/powered=false` olur.
- Visual state güncel snapshot'tan uygulanır; eski blackout sequence baştan
  hatalı şekilde oynatılmaz.
- A'nın state'i reconnect nedeniyle değişmez.
- Repair sonrası iki client da aynı recovery state'ini görür.
- Reconnect sırasında stale target lock veya stale repair session oluşmaz.

## MP-04 — Aktif blackout sırasında late-join

### Amaç

Blackout başlamadan önce serverda olmayan bir oyuncunun sonradan bağlandığında
doğru district/grid/visual snapshot'ı almasını doğrulamak.

### Adımlar

1. Oyuncu B serverda bağlı değilken A, `sandy_tr_01` üzerinde sabotage
   tamamlasın.
2. A şu verileri kaydetsin:

   ```text
   /apiquery incidents
   /apiquery path SANDY
   /apiquery path DESRT
   ```

3. Oyuncu B servera bağlansın.
4. B spawn noktasından sonra 10 saniye beklesin.
5. B SANDY'ye gitsin. Spawn noktası SANDY ise doğrudan mevcut konumda
   gözlem yapılır.
6. B aşağıdaki kontrolleri çalıştırsın:

   ```text
   /showdistrict
   /griddebug
   /visualprofile
   /apiquery incidents
   /apiquery path SANDY
   ```

7. B DESRT'e geçerek bağımsız branch state'ini de kontrol etsin.
8. A incident ID'sinin değişmediğini kontrol etsin.
9. A normal repair'i tamamlasın; B recovery'yi gözlemlesin.

### Beklenen sonuç

- Late-join oyuncusu SANDY'de doğrudan güncel blackout state'ini alır.
- Blackout için yeni incident veya duplicate dispatch oluşmaz.
- B'de gri/siyah ekranda takılı kalma veya eski visual sequence görülmez.
- B DESRT'e geçtiğinde DESRT online kalır.
- Repair sonrası B ve A aynı online state'i görür.

## MP-05 — İki oyuncu bağlıyken resource restart/resync

### Amaç

Aktif persistent failure sırasında resource restart'ın iki client'ta cleanup,
restore ve replication sırasını bozmadığını doğrulamak.

### Yerleşim

- Oyuncu A: SANDY
- Oyuncu B: DESRT

### Adımlar

1. A, `sandy_tr_01` üzerinde sabotage tamamlasın.
2. A'da SANDY blackout, B'de DESRT online state'ini doğrula.
3. Incident ID'sini kaydet.
4. Server konsolunda:

   ```text
   refresh
   restart gnsh-blackout
   ```

5. 10–15 saniye boyunca server ve iki client F8 konsolunu izle.
6. İki oyuncu da aşağıdaki sorguları çalıştırsın:

   ```text
   /showdistrict
   /griddebug
   /apiquery incidents
   /apiquery path SANDY
   /apiquery path DESRT
   /apiquery grid blaine_south
   ```

7. A ve B görsel state'lerini karşılaştırsın.
8. A normal repair'i tamamlasın.
9. İki oyuncu recovery state'ini doğrulasın.

### Beklenen sonuç

- Resource restart sırasında client gri/siyah ekranda takılı kalmaz.
- Restart sonrası `sandy_tr_01` persistent olarak offline/destroyed kalır.
- A SANDY'de blackout'u, B DESRT'te online state'i görür.
- Aynı incident ID restore edilir; duplicate SQL insert veya duplicate event
  oluşmaz.
- `ls_central` ve bağımsız district'ler etkilenmez.
- A'nın repair'i sonrasında iki client online recovery görür.
- Server/F8 loglarında `SCRIPT ERROR`, ox_lib function reference, SQL
  duplicate veya bridge rebuild hatası bulunmaz.

## MP-06 — District geçişi ve visual resync

### Amaç

Logical power state'in server tarafından belirlenmeye devam ettiğini ve
district değişimi/resync işlemlerinin yalnızca doğru client visual state'ini
etkilediğini doğrulamak.

### Yerleşim

- Oyuncu A: SANDY'de başlayacak
- Oyuncu B: SANDY'de kalacak veya HARMO'ya geçecek

### Adımlar

1. `sandy_tr_01` üzerinde aktif sabotage oluştur.
2. A ve B'nin SANDY/HARMO blackout state'ini doğrula.
3. A SANDY'den DESRT'e geçsin.
4. A geçiş tamamlandıktan sonra:

   ```text
   /showdistrict
   /griddebug
   /apiquery path DESRT
   ```

5. A'nın DESRT'te visual blackout taşımadığını kontrol et.
6. A SANDY'ye geri dönsün ve blackout visual'ının tekrar doğru uygulandığını
   kontrol et.
7. Admin olarak server konsolundan veya admin chat'inden:

   ```text
   /resyncvisual <A_playerId>
   ```

8. A'nın visual state'i yenilenirken B'nin state'inin değişmediğini kontrol
   et.
9. Ardından:

   ```text
   /resyncvisual all
   ```

10. İki oyuncu da `/griddebug`, `/visualprofile` ve `/apiquery incidents`
    çıktısını karşılaştırsın.
11. A normal repair'i tamamlasın; iki client'ta recovery cleanup'ı gözle.

### Beklenen sonuç

- District geçişi logical grid/incident state'ini değiştirmez.
- A DESRT'e geçtiğinde SANDY blackout visual'ı temizlenir.
- A SANDY'ye döndüğünde blackout visual'ı tekrar uygulanır.
- Targeted resync yalnızca hedef client'ın visual state'ini yeniler.
- Broadcast resync iki client'ı doğru district state'ine getirir.
- Resync incident oluşturmaz, transformer damage değiştirmez ve SQL yazmaz.
- Repair sonrası iki client'ta visual cleanup tamamlanır.

## Çoklu topology varyantları

Ana test paketleri yukarıdaki 6 vaka olarak kalır. Aşağıdaki varyantlar aynı
senkron/reconnect/restart adımlarının farklı topology branch'lerinde tekrar
edilmesidir; en az birer kez çalıştırılmaları önerilir.

### Varyant A — İki feeder, aynı substation

1. Oyuncu A `SANDY`, oyuncu B `DESRT` konumunda olsun.
2. B, gözlem için DESRT'te kalır; sabotage ve repair için fiziksel olarak
   `blaine_south_tr_02` konumuna (`vector3(1975.0, 3745.0, 32.2)`) gider.
   `blaine_south_tr_02` üzerinde C4 sabotage yap.
3. A'nın SANDY/HARMO'sunun online, B'nin DESRT'inin blackout olduğunu
   doğrula.
4. B tarafındaki incident ID'sinin A tarafında da aynı olduğunu kontrol et.
5. B normal repair'i tamamlasın.
6. İki client'ta `blaine_south` ve ilgili district'lerin online olduğunu
   doğrula.

Beklenti: Feeder B failure'ı Feeder A branch'ini kapatmaz.

### Varyant B — Bağımsız grid

1. Oyuncu A `SANDY`, oyuncu B `DOWNT` konumunda olsun.
2. `ls_central_tr_01` üzerinde sabotage yap.
3. B'de `DOWNT/PBOX/SKID` blackout, A'da `SANDY/HARMO` online olmalı.
4. `/apiquery grid blaine_south` ve `/apiquery grid ls_central` sonuçlarını
   iki oyuncuda karşılaştır.
5. B normal repair'i tamamlasın.
6. İki grid'in de online olduğunu doğrula.

Beklenti: `ls_central` failure'ı `blaine_south` state'ini değiştirmez.

### Varyant C — Parent feeder/substation state

Bu varyant admin operasyonu ile yapılır; oyuncu sabotage akışı yerine parent
failure replication'ını ölçer.

1. Oyuncu A `SANDY/HARMO`, oyuncu B `DESRT` konumunda olsun.
2. Admin olarak:

   ```text
   /setfeederstate blaine_south_feed_a OFFLINE
   ```

3. İki oyuncunun path/grid/visual state'ini karşılaştır.
4. Admin olarak:

   ```text
   /restorefeeder blaine_south_feed_a
   ```

5. Parent restore sonrası child transformer online ise district'lerin
   recovery'sini doğrula.
6. Aynı kontrolü gerekirse `sandy_substation_01` için tekrarla:

   ```text
   /setsubstationstate sandy_substation_01 OFFLINE
   /restoresubstation sandy_substation_01
   ```

Beklenti: Parent offline iken child online olsa bile district offline kalır;
parent restore sonrası child online ise recovery iki client'a da ulaşır.

## Negatif ve güvenlik gözlemleri

Bu belge yeni bir güvenlik unit testi yerine canlı çoklu oyuncu gözlemi sağlar.
Geçerli isteklerde aşağıdaki durumlar görülmemelidir:

- İkinci oyuncunun client payload'ı ile damage/impact/district/grid state
  değiştirmesi
- Aynı repair veya sabotage başarısının iki kez mutation üretmesi
- Bir oyuncunun diğer oyuncu adına session tamamlaması
- Bir client'ın diğer client'ın visual state'ini tek başına değiştirmesi
- Disconnect sonrası stale lock/session kalması
- Geçersiz target veya cross-grid target'ın state değiştirmesi

Beklenen kontrollü red durumları (`target busy`, `session owner`, `stale
revision`, `out of range`) test başarısızlığı değildir. Bu red'in yanında
mutation, item tüketimi veya duplicate incident oluşuyorsa test başarısızdır.

## PERF-32 / PERF-64 / PERF-128 — Performans testleri

Bu testler gerçek oyuncu veya load harness olmadan çalıştırılmayacaktır.
Manuel tek oyuncu ile bu acceptance criterion ölçülemez.

### Ortak prosedür

1. Baseline için tüm sistem online ve incident listesi boş olmalı.
2. Metrics yalnızca ölçüm penceresi için açılmalı; production default'u
   tekrar kapatılmalı.
3. Ölçüm öncesi temiz server/F8 log snapshot'ı alınmalı.
4. Oyuncuların en az yarısı farklı district/grid branch'lerine dağıtılmalı.
5. Sırasıyla şu senaryolar çalıştırılmalı:
   - 0 blackout
   - 1 transformer blackout
   - 1 feeder blackout
   - 2 bağımsız grid blackout
   - adjacent district blackout
   - substation blackout
   - rapid repair + sabotage
6. Her senaryoda server tick/recalculation, statebag, network event, DB
   write, district resolver, visual apply/remove, PTFX ve memory değerleri
   baseline ile karşılaştırılmalı.
7. Cleanup sonrası memory growth ve stale session/lock kontrol edilmeli.
8. Her ölçüm penceresi sonunda metrics kapatılıp resource restart edilmeli.

### Kabul kriteri

- Baseline'a göre ek yük `%20` üzerinde olmamalı.
- Bounded rolling window dışına taşan metrics/memory growth olmamalı.
- Cleanup sonrası aktif repair/session/incident beklenmedik kalmamalı.
- Server/F8 script error olmamalı.
- DB write ve network event sayıları açıklanabilir olmalı.

### Mevcut durum

- PERF-32: `DEFERRED` — 32 oyuncu veya load harness yok.
- PERF-64: `DEFERRED` — 64 oyuncu veya load harness yok.
- PERF-128: `DEFERRED` — 128 oyuncu veya load harness yok.

Bu üç madde için kullanıcı canlı kabulü olmadan `PASS` yazılmaz.

## Test sonrası cleanup

Her fonksiyonel vaka sonunda:

1. Aktif repair stage varsa tamamla veya kontrollü şekilde iptal et.
2. Transformer, feeder, substation ve grid state'lerini tekrar online yap.
3. Gerekirse yalnızca cleanup amacıyla:

   ```text
   /repairall
   ```

4. Server konsolunda:

   ```text
   showtransformers
   showfeeders
   showsubstations
   ```

5. Oyunculardan biri:

   ```text
   /apiquery incidents
   /apiquery grid blaine_south
   /apiquery grid ls_central
   ```

6. Beklenen son durum: tüm transformer'lar `ONLINE/HEALTHY/damage=0`,
   incident listesi `[]`, iki grid `ONLINE/level=1.0`.
7. İki client'ta F8 görsel cleanup'ı kontrol et.

Cleanup doğrulanmadan sonraki test başlatılmaz.

## PASS / FAIL / BLOCKED ölçütü

### PASS

- Beklenen logical ve visual state iki client'ta doğru.
- Incident/session/revision davranışı tekil ve server-authoritative.
- Repair/recovery sonrası cleanup tamam.
- Server/F8 ve SQL loglarında beklenmeyen hata yok.
- Test evidence'i kaydedildi.

### FAIL

- Beklenen state yanlış veya client'lar arasında farklı.
- Duplicate incident/mutation/item tüketimi oluştu.
- State başka grid/district'e sızdı.
- Restart/reconnect sonrası stale visual/session kaldı.
- Geçerli işlem server/F8/SQL hatası üretti.

### BLOCKED / DEFERRED

- İkinci client bağlanamıyor.
- Test için gereken item/permission/topology hazır değil.
- 32/64/128 oyuncu veya load harness bulunmuyor.
- Dış dependency test ortamında mevcut değil.

BLOCKED durumunda sebep ve tekrar koşulunu yaz; sonucu `PASS` olarak
işaretleme.

## Sonuç kayıt şablonu

Her test için aşağıdaki şablon doldurulur:

```text
Test ID:
Tarih/saat:
Resource version:
Oyuncu A / source:
Oyuncu B / source:
Topology hedefi:
Başlangıç durumu:
Uygulanan adımlar:
Oyuncu A gözlemi:
Oyuncu B gözlemi:
Server log özeti:
F8 log özeti:
Incident ID / cause:
Cleanup sonucu:
Sonuç: PASS / FAIL / BLOCKED / DEFERRED
Kanıt: ekran görüntüsü, log veya API çıktısı
Notlar:
```

## Final kapanış koşulu

Phase 35 final kabulü için MP-01–MP-06 testlerinin tamamı `PASS` olmalı,
cleanup son durumunda incident listesi boş olmalı ve server/F8 hata kontrolü
temiz olmalıdır. PERF-32/64/128 çalıştırılmadıysa bu durum changelog'da
`DEFERRED` olarak kalır; ölçek kabulü tamamlanmadan final release için
`1.0.0` kararı verilmez.
