⚙️ Matematiksel Model ve Katsayı Mantığı (Mühendislik Açıklaması)

Yazılan karar destek algoritması, tarımsal su bütçesi denklemlerinin temelini oluşturan FAO-56 Penman-Monteith yaklaşımına dayanmaktadır. Hava durumu API'sinden gelen girdilerin fiziksel sınırları içinde kalarak şu mühendislik adımlarıyla çalışır:

Termodinamik ve Atmosferik Buhar Basıncı İlişkileri ($e_s$, $e_a$, $VPD$, $\Delta$):

Doymuş Buhar Basıncı ($e_s$): Bitki yaprak gözeneklerinin (stoma) içindeki havanın neme tamamen doymuş olduğu kabul edilir. Bu basınç Tetens denklemi ile hesaplanır: $$e_s = 0.6108 \cdot e^{\frac{17.27 \cdot T}{T + 237.3}}$$

Buhar Basıncı Açığı ($VPD$): $VPD = e_s - e_a$ formülüyle bulunur. Havadaki kuruluk derecesini (sürükleyici kuvveti) gösterir. $VPD$ ne kadar yüksekse, havanın yapraktan su çekme potansiyeli o kadar artar.

Doymuş Buhar Basıncı Eğrisinin Eğimi ($\Delta$): Sıcaklığa bağlı olarak değişen bu parametre, radyasyon (enerji dengesi) ve rüzgar (aerodinamik transfer) arasındaki ağırlığı belirler.

Net Radyasyon ($R_n$) Modellemesi:

Doğrudan solar radyasyon verisi olmadığında, havadaki bulutluluk ve enerji dengesini yansıtacak şekilde bir ampirik radyasyon modeli ($MJ/m^2/gün$) kurulmuştur: $$R_n = 13.5 \cdot \left(1.0 - \frac{RH}{200}\right) + 0.1 \cdot T$$

Bu formül, bağıl nem ($RH$) arttıkça bulutluluğun arttığını varsayarak solar radyasyonu azaltırken, sıcaklık ($T$) yükseldikçe radyasyon girdisini lineer olarak artırır.

FAO-56 Penman-Monteith Denklemi ile Referans Evapotranspirasyon ($ET_0$):

Enerji ve kütle transferi ilkelerini birleştiren denklemle referans yüzeyin su kaybı hesaplanır: $$ET_0 = \frac{0.408 \cdot \Delta \cdot R_n + \gamma \cdot \frac{900}{T + 273.15} \cdot u_2 \cdot VPD}{\Delta + \gamma \cdot (1.0 + 0.34 \cdot u_2)}$$

Burada $\gamma = 0.067 , \text{kPa/}^\circ\text{C}$ psikrometrik sabiti, $u_2$ ise 2 metre yükseklikteki rüzgar hızını temsil eder.

Kök Derinliği ($RD$) ve Asimptotik Su Alma Sınırı ($K_{root}$):

Sığ köklü bitkilerin (örneğin fide aşamasındaki bitkilerin) kılcal kök yüzey alanı dar olduğu için ne kadar yüksek terleme talebi olursa olsun topraktan su çekme kapasitesi sınırlıdır.

Bu sınır, asimptotik bir verimlilik fonksiyonuyla modele eklenmiştir: $$K_{root} = 1.0 - e^{-3.5 \cdot RD}$$

Burada $\lambda = 3.5$ katsayısı, kök derinliği arttıkça su alımının doyuma ulaşma hızını belirler. Böylece 15 cm ($0.15\text{m}$) kök derinliğindeki bir bitki sadece kısıtlı oranda terleme yapabilirken, mature aşamadaki ($0.8\text{m}$) bitki tam kapasiteye ($K_{root} \approx 0.94$) ulaşır.

Etkin Yağış ($P_{eff}$) ve Net Sulama:

Doğal yağışların bir kısmı yüzey akışı ve derin süzülme ile kaybolduğundan tarımsal verimlilik katsayısı olarak SCS yaklaşımına uygun olarak %80 ($0.80$) oranında efektif yağış kabulü yapılmıştır: $$\text{Net Sulama} = \max(0.0, ET_{crop} - (P \cdot 0.80))$$

📊 Yapılan Testler ve Doğrulama Özeti

test_irrigation.py ile yapılan testlerin çıktıları aşağıdaki gibidir:

Test 1 (Sıcak/Kuru, Yağışsız): 8.95 mm net sulama ihtiyacı hesaplandı.

Test 2 (Yağışlı): Doğal yağış ihtiyacı tamamen karşıladığı için sulama 0.0 mm döndü.

Test 3 (Kök Derinliği Karşılaştırması): Aynı hava koşullarında 15 cm köklü fide için sulama ihtiyacı 2.0 mm iken, 80 cm köklü yetişkin bitki için 4.6 mm olarak hesaplandı (kök kapasite kısıtlaması başarılı şekilde çalıştı).

Test 4 (Hatalı Veri Toleransı): String tipinde veya geçersiz değerler geldiğinde sistem hata vermeyip try-except bloğunda yakalayarak güvenli varsayılan değer olan 0.0 değerini döndürdü.