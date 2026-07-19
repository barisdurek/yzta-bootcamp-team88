# **Takım İsmi**

Ekip 88

# Ürün İle İlgili Bilgiler

## Takım Elemanları

- Aycan Kurt: Scrum Master
- Barış Dürek: Product Owner
- Zahid Nabi Çelik: Ekip Üyesi

## Ürün İsmi

Tarla Gözcüsü

## Ürün Açıklaması

- Tarla Gözcüsü; tarımsal üretim süreçlerini proaktif ve önleyici bir yaklaşımla dijitalleştiren, veri yoğunluklu bir karar destek sistemidir. Projenin temel amacı; harici iklim verilerini, toprak parametrelerini ve bitki biyolojisi formüllerini merkezi bir yapay zeka mimarisiyle işleyerek üreticiye su ve gübre tasarrufu sağlamak, hastalıkları sahada ortaya çıkmadan önce engellemektir. Geleneksel reaktif tarım uygulamalarının aksine Tarla Gözcüsü dinamik veri analizi ile sürdürülebilir ve maliyet etkin bir tarım modeli sunar.

## Ürün Özellikleri

- Bölgesel Veri Paylaşımı ve Kolektif Koruma: Havza bazlı anonim veri toplama sistemi sayesinde, yakındaki tarlalarda tespit edilen zararlı ve hastalıkları bölgedeki diğer üreticilere proaktif bildirimlerle iletir. (Ana kullanım yolu)
- Dinamik Sulama ve Su Optimizasyonu: Mahsulün kök derinliği, büyüme evresi ve hava durumu API'larından gelen anlık/tarihsel verileri birleştirerek gereksiz su tüketimini engeller.
- Besin Takibi ve Gübre Yıkanma Simülasyonu: Yağış ve sulama verileri üzerinden topraktaki NPK (azot, fosfor, potasyum) kaybını analitik modellerle hesaplayarak optimum gübreleme tavsiyeleri verir.
- Hastalık Erken Uyarı ve Teşhis: Erken evre bitki besin stresi ve hastalık tespiti için evrişimli sinir ağlarının (CNN) karşılaştırmalı analizini kullanan, mobil kamera entegreli genişletilebilir görüntü işleme boru hattı.
- Merkezi AI Ajanı (Orkestratör): Harici iklim verilerini, makine öğrenmesi tahminlerini ve görsel analiz çıktılarını birleştirerek kullanıcıya doğal dilde net aksiyon planları sunar.

## Hedef Kitle

- Tarımsal girdi maliyetlerini (su, gübre, ilaç) optimize etmek isteyen ticari üreticiler ve çiftçiler
- Hobi amaçlı tarıma yönelen, veri odaklı karar almayı tercih eden her yaştan telefon sahibi kullanıcılar
- Teknolojik tarım asistanlarına entegre olmaya açık tüm tarım sektörü paydaşları

## Product Backlog URL

Jira Backlog URL: https://zahidnabicelik.atlassian.net/jira/software/projects/E88/boards/133/backlog?atlOrigin=eyJpIjoiNmRiZmM1MmU4MjY2NGVlM2JiMjQxODFiOTU1MzE5YTciLCJwIjoiaiJ9

- **Backlog düzeni ve Story seçimleri**: Backlog'umuz oluşturduğumuz epic'lerdeki story'lere göre düzenlenmiştir. 
Story'ler yapılacak işlere sub-task'lara bölünmüştür. Sprint'ler tamamlandıkça yeni sprint'in bakcloguna geçilir. 
---
**Board Düzeni**: 
- Turuncu Simge: Zahid Nabi Çelik
- Mavi Simge: Aycan Kurt
- Mor Simge: Barış Dürek

<details>
<summary> <h2>Sprint 1</h2> </summary>
<br>

- **Daily Scrum**:

- Daily Scrum toplantıları meşguliyet sebeplerinden dolayı Whatsapp üzerinden yapılmasına karar verilmiştir. Daily Scrum toplantısı örneği jpeg olarak Readme'de paylaşılmaktadır:
- <img width="797" height="558" alt="DailyScrum" src="https://github.com/user-attachments/assets/e82a05e4-9bd4-4786-97aa-cbb355bcd612" />

- **Sprint board update (screenshotlar)**: 
- <img width="1920" height="3488" alt="Sprint1_Board1" src="https://github.com/user-attachments/assets/9f90d497-3e97-41d4-890c-c08cf67b0208" />

- <img width="2561" height="4578" alt="Sprint1_Board2" src="https://github.com/user-attachments/assets/f2927710-c97f-4b35-8a49-c9e7e9f6ec79" />

- <img width="2561" height="4686" alt="Sprint1_Board3" src="https://github.com/user-attachments/assets/3be0ef1b-a3af-45d4-a1ab-dd399c77ca5d" />

- <img width="2561" height="5620" alt="Sprint1_Board4" src="https://github.com/user-attachments/assets/771d1fed-77e4-4749-80b3-0309bd588d5e" />

- **Ürün Durumu**: 

- Veritabanı Şeması:

- <img width="1341" height="1820" alt="database_schema_updated" src="https://github.com/user-attachments/assets/4eeb4161-68f5-4800-98f8-9c8c6a58102e" />

- CNN model - EfficientNet-B2: Hastalıkların daha iyi teşhis edilebilmesi amacıyla bu modelin kullanılması uygun görülmüştür. Uygun parametreler seçilerek model eğitimi başarıyla tamamlanmış olup, ek olarak fine-tuning işlemi gerçekleştirilmiştir. Belirlenen temel parametreler ile modelin augmentation örneği aşağıdaki görseldeki gibidir:

- <img width="476" height="224" alt="augmentation_preview" src="https://github.com/user-attachments/assets/62583536-aba1-4af8-82ba-1d247279d8d6" />

- Training işleminde modelin accuracy-loss değişimleri aşağıdaki grafikteki gibidir:
- <img width="2048" height="717" alt="model_training_accuracy-loss_graphic" src="https://github.com/user-attachments/assets/f8e16629-1800-46d3-8429-9a794756ade3" />

- **Sprint Review:**
- Tarla Gözcüsü projemizin veri mimarisini ve yapay zeka altyapısını kurduğumuz Sprint 1'i, "'Hava Durumu' Verilerinin Sisteme Entegre Edilmesi" storymiz dışındaki tüm görevleri başarıyla tamamlayarak kapattık. GitHub repomuzu yayına aldık ve WhatsApp üzerinden yürüttüğümüz asenkron iletişim ile veritabanı şemasını repomuza ekledik. Veri hazırlığı sürecinde oldukça kapsamlı bir ön işleme yürüttük; agriculture_dataset.csv dosyasındaki Türkçe karakter (cp1254) sorunlarını Python ile çözerek UTF-8 formatında temizledik ve satır sayısını optimize ettik. NASA Power 2001-2025 iklim verilerini 6 farklı bölge için (Adana, Şanlıurfa, Antalya, Konya, Manisa, Tekirdağ) birleştirip nasa_climatic_summary.csv tablosunu oluşturduk. Hiperspektral Toprak Nemi verisindeki 125 özelliği PCA (Temel Bileşenler Analizi) ve StandardScaler ile işleyerek eğitime hazır hale getirdik. Görüntü işleme tarafında PlantVillage veri setindeki sınıf dengesizliğini veri artırma (Data Augmentation) ile giderdik ve EfficientNet-B3 mimarisiyle CNN modelimizi eğittik. Modelimizin yüksek performansını confusion matrix ve loss/accuracy grafikleriyle doğrulayarak dokümante ettik. 

- **Sprint Retrospective:**
- Sprint 1 boyunca metin, tablo ve görüntü gibi üç farklı veri tipinde yürüttüğümüz yoğun ön işleme ve modelleme süreçlerini, belirlediğimiz görev dağılımı sayesinde yüksek bir verimlilikle yönettik. WhatsApp üzerinden yürüttüğümüz Daily Scrum toplantıları, şeffaf bir iletişim kurmamızı sağlayarak karşılaştığımız teknik engelleri hızla aşmamıza yardımcı oldu. Jira tahtamızdaki zorlu API entegrasyonu, JSON ayrıştırma ve model eğitimi görevlerinin neredeyse tamamını "Done" statüsüne çekebilmemiz, takım içindeki uyumun ve paralel çalışma refleksimizin ne kadar güçlü olduğunu kanıtladı. EfficientNet-B3 modelimizin eğitiminde ve veri artırma (augmentation) aşamalarında elde ettiğimiz başarılı sonuçlar, sistemin temelini sağlam atmamızı sağladı. Sprint 2'ye geçerken en büyük odak noktamız, ilk sprintte titizlikle hazırladığımız bu veri kümelerini ve eğitilmiş güçlü CNN modelini arka uç (backend) mimarisine entegre etmek ve API entegrasyonunu tamamlamak olacaktır.
</details>

<details>
<summary> <h2>Sprint 2</h2> </summary>
<br>

- **Daily Scrum**:
- <img width="788" height="320" alt="DailyScrum 1" src="https://github.com/user-attachments/assets/917fe3d4-bc4c-466d-be58-885b182eb163" />
- <img width="793" height="473" alt="DailyScrum 2" src="https://github.com/user-attachments/assets/22d1e101-2395-461d-8547-3b622218fe6d" />

- **Sprint board update (screenshotlar)**: 
- <img width="2561" height="7591" alt="Sprint2_Board1" src="https://github.com/user-attachments/assets/85ea4c45-d79a-4c20-a337-58a7f24c5b45" />
- <img width="2561" height="7132" alt="Sprint2_Board2" src="https://github.com/user-attachments/assets/d76a8503-6d09-4d8e-aedd-7f4fc1a1ffc5" />
- <img width="2561" height="7354" alt="Sprint2_Board3" src="https://github.com/user-attachments/assets/ae78300b-b753-4a73-87ae-4f849f07a25a" />
- <img width="2561" height="7900" alt="Sprint2_Board4" src="https://github.com/user-attachments/assets/735c46f5-824f-44f9-a9be-e85046ee429a" />
- **Ürün Durumu**:
- <img width="496" height="1020" alt="Hesap_olusturma_ekrani" src="https://github.com/user-attachments/assets/be11eb9a-6107-4da8-bf19-567f2d68e57b" />
- <img width="496" height="1020" alt="Giris_ekrani" src="https://github.com/user-attachments/assets/55156d2f-ff33-4779-90eb-f74936313f43" />
- <img width="500" height="1015" alt="Ozet_ekrani" src="https://github.com/user-attachments/assets/c21143a1-2d9a-4e0c-a461-b96ac994270a" />
- <img width="505" height="1017" alt="Tarla_ekleme_ekrani" src="https://github.com/user-attachments/assets/d603e78f-a1b1-4099-9c5d-f2d0bb4de3fc" />
- <img width="500" height="1015" alt="Risk_harita_ekrani" src="https://github.com/user-attachments/assets/f2477de9-f42d-4574-9f98-21c4fa1b1c07" />
- <img width="501" height="1022" alt="Profil_ayarlar" src="https://github.com/user-attachments/assets/40c0b511-e3a1-4071-9399-59e619f45b92" />

- **Sprint Review**:
- Tarla Gözcüsü projemizin backend mimarisini, karar destek algoritmalarını ve mobil arayüz temellerini kurguladığımız Sprint 2'de önemli ilerlemeler kaydettik; ancak bazı teknik görevlerimizi zaman kısıtları nedeniyle Sprint 3'e devretmek durumunda kaldık. Sprint 1'den devraldığımız koordinat bazlı OpenWeatherMap API entegrasyonunu tamamlayarak canlı hava durumu verilerini sisteme başarıyla dahil ettik. Karar destek algoritmaları tarafında, FAO-56 Penman-Monteith denklemini temel alan günlük optimal sulama ihtiyacı modelini ve birinci derece kinetikle çalışan NPK gübre yıkanma (leaching) modelini geliştirdik. PostgreSQL veritabanı mimarimizi kurarak SQLAlchemy ORM üzerinden kullanıcı, tarla, risk ve AI öneri kayıtları için tüm CRUD operasyonlarını tamamladık. Yapay zeka tarafında EfficientNet-B2 TFLite yaprak hastalığı modelini ve Gemini API destekli proaktif "Terra AI" Ziraat Mühendisi ajanı sistem promptunu hazırladık. Mobil uygulamamızda ise Dashboard ve Teşhis ekranı tasarımlarını başlatabilmiş olsak da tamamlanamayarak Sprint 3 backlog'una devredilmiştir.

- **Sprint Retrospective:**
- Sprint 2 boyunca analitik modellerin formülleştirilmesi, veritabanı tasarımı ve AI ajan kurgusu gibi karmaşık teknik süreçleri WhatsApp ve Daily Scrum toplantılarımız aracılığıyla yüksek bir iletişim ve koordinasyonla yürüttük. Karar destek modellerimizin ve veritabanı altyapımızın başarıyla tamamlanması projemizin omurgasını sağlamlaştırdı. Mobil arayüz geliştirme ve API entegrasyon süreçlerinin beklediğimizden daha yoğun ve zaman alıcı olması sebebiyle Jira tahtamızdaki bazı görevleritam olarak bitirmedik. Sprint 3'e geçerken odağımız; devrettiğimiz görevleri tamamlamak, uçtan uca hata yönetimi testleriyle ürün bütünlüğünü korumak, kodumuzu arındırıp frontend ve backend katmanlarımızı buluta taşımak, 3 dakikalık proje sunum videosunu hazırlamak ve 2 Ağustos'a teslim formunu eksiksiz bir şekilde tamamlamak olacaktır.
</details>

<details>
<summary> <h2>Sprint 3</h2> </summary>
<br>

- **Daily Scrum**:

- **Sprint board update (screenshotlar)**: 
 
- **Ürün Durumu**:

- **Sprint Review**:
- 

- **Sprint Retrospective:**
-
</details>
---
