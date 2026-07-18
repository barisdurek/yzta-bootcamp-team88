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

- Tarla Gözcüsü, tarımsal üretim süreçlerini "proaktif" (önleyici) bir yaklaşımla dijitalleştiren, veri yoğun bir karar destek sistemidir. Projenin temel amacı; harici iklim verilerini, toprak parametrelerini ve bitki biyolojisi formüllerini merkezi bir yapay zeka mimarisiyle işleyerek, üreticiye su ve gübre tasarrufu sağlamak, hastalıkları sahada ortaya çıkmadan önce engellemektir. Geleneksel reaktif tarım uygulamalarının aksine, Tarla Gözcüsü dinamik veri analizi ile sürdürülebilir ve maliyet etkin bir tarım modeli sunar.

## Ürün Özellikleri

- Bölgesel Veri Paylaşımı ve Kolektif Koruma: Havza bazlı anonim veri toplama sistemi sayesinde, yakındaki tarlalarda tespit edilen zararlı ve hastalıkları bölgedeki diğer üreticilere proaktif bildirimlerle iletir. (Ana kullanım yolu)
- Dinamik Sulama ve Su Optimizasyonu: Mahsulün kök derinliği, büyüme evresi ve hava durumu API'lerinden gelen anlık/tarihsel verileri birleştirerek gereksiz su tüketimini engeller.
- Besin Takibi ve Gübre Yıkanma Simülasyonu: Yağış ve sulama verileri üzerinden topraktaki NPK (azot, fosfor, potasyum) kaybını analitik modellerle hesaplayarak optimum gübreleme tavsiyeleri verir.
- Hastalık Erken Uyarı ve Teşhis: Erken evre bitki besin stresi ve hastalık tespiti için evrişimli sinir ağlarının (CNN) karşılaştırmalı analizini kullanan, mobil kamera entegreli genişletilebilir görüntü işleme boru hattı.
- Merkezi AI Ajanı (Orkestratör): Harici iklim verilerini, makine öğrenmesi tahminlerini (örneğin; CatBoost veya benzeri topluluk algoritmaları) ve görsel analiz çıktılarını birleştirerek kullanıcıya doğal dilde net aksiyon planları sunar.

## Hedef Kitle

- Tarımsal girdi maliyetlerini (su, gübre, ilaç) optimize etmek isteyen ticari üreticiler ve çiftçiler
- Hobi amaçlı tarıma yönelen, veri odaklı karar almayı tercih eden her yaştan telefon sahibi kullanıcılar
- Teknolojik tarım asistanlarına entegre olmaya açık tüm tarım sektörü paydaşları

## Product Backlog URL

Jira Backlog URL: https://zahidnabicelik.atlassian.net/jira/software/projects/E88/boards/133/backlog?atlOrigin=eyJpIjoiNmRiZmM1MmU4MjY2NGVlM2JiMjQxODFiOTU1MzE5YTciLCJwIjoiaiJ9

- **Backlog düzeni ve Story seçimleri**: Backlog'umuz oluşturduğumuz epic'lerdeki story'lere göre düzenlenmiştir. 
Story'ler yapılacak işlere sub-task'lara bölünmüştür. 
---
**Board Düzeni**: 
Turuncu Simge: Zahid Nabi Çelik
Mavi Simge: Aycan Kurt
Mor Simge: Barış Dürek

# Sprint 1

- **Daily Scrum**:

- -Daily Scrum toplantıları meşguliyet sebeplerinden dolayı Whatsapp üzerinden yapılmasına karar verilmiştir. Daily Scrum toplantısı örneği jpeg olarak Readme'de paylaşılmaktadır:
- <img width="797" height="558" alt="DailyScrum" src="https://github.com/user-attachments/assets/e82a05e4-9bd4-4786-97aa-cbb355bcd612" />

- **Sprint board update (screenshotlar)**: 
-----------------------<img width="1920" height="3488" alt="Sprint1_Board1" src="https://github.com/user-attachments/assets/9f90d497-3e97-41d4-890c-c08cf67b0208" />

-----------------------<img width="2561" height="4578" alt="Sprint1_Board2" src="https://github.com/user-attachments/assets/f2927710-c97f-4b35-8a49-c9e7e9f6ec79" />

-----------------------<img width="2561" height="4686" alt="Sprint1_Board3" src="https://github.com/user-attachments/assets/3be0ef1b-a3af-45d4-a1ab-dd399c77ca5d" />

-----------------------<img width="2561" height="5620" alt="Sprint1_Board4" src="https://github.com/user-attachments/assets/771d1fed-77e4-4749-80b3-0309bd588d5e" />

- **Ürün Durumu**: 

-Veritabanı Şeması:

<img width="1341" height="1820" alt="database_schema_updated" src="https://github.com/user-attachments/assets/4eeb4161-68f5-4800-98f8-9c8c6a58102e" />

-CNN model - EfficientNet-B2: Hastalıkların daha iyi teşhis edilebilmesi amacıyla bu modelin kullanılması uygun görülmüştür. Uygun parametreler seçilerek model eğitimi başarıyla tamamlanmış olup, ek olarak fine-tuning işlemi gerçekleştirilmiştir. Belirlenen temel parametreler ile modelin augmentation örneği aşağıdaki görseldeki gibidir:

<img width="476" height="224" alt="augmentation_preview" src="https://github.com/user-attachments/assets/62583536-aba1-4af8-82ba-1d247279d8d6" />

-Training işleminde modelin accuracy-loss değişimleri aşağıdaki grafikteki gibidir:
<img width="2048" height="717" alt="model_training_accuracy-loss_graphic" src="https://github.com/user-attachments/assets/f8e16629-1800-46d3-8429-9a794756ade3" />

- **Sprint Review:**
- Tarla Gözcüsü projemizin veri mimarisini ve yapay zeka altyapısını kurduğumuz Sprint 1'i, "'Hava Durumu' Verilerinin Sisteme Entegre Edilmesi" storymiz dışındaki tüm görevleri başarıyla tamamlayarak kapattık. GitHub repomuzu yayına aldık ve WhatsApp üzerinden yürüttüğümüz asenkron iletişim ile veritabanı şemasını repomuza ekledik. Veri hazırlığı sürecinde oldukça kapsamlı bir ön işleme yürüttük; agriculture_dataset.csv dosyasındaki Türkçe karakter (cp1254) sorunlarını Python ile çözerek UTF-8 formatında temizledik ve satır sayısını optimize ettik. NASA Power 2001-2025 iklim verilerini 6 farklı bölge için (Adana, Şanlıurfa, Antalya, Konya, Manisa, Tekirdağ) birleştirip nasa_climatic_summary.csv tablosunu oluşturduk. Hiperspektral Toprak Nemi verisindeki 125 özelliği PCA (Temel Bileşenler Analizi) ve StandardScaler ile işleyerek eğitime hazır hale getirdik. Görüntü işleme tarafında PlantVillage veri setindeki sınıf dengesizliğini veri artırma (Data Augmentation) ile giderdik ve EfficientNet-B3 mimarisiyle CNN modelimizi eğittik. Modelimizin yüksek performansını confusion matrix ve loss/accuracy grafikleriyle doğrulayarak dokümante ettik. 

- **Sprint Retrospective:**
- Sprint 1 boyunca metin, tablo ve görüntü gibi üç farklı veri tipinde yürüttüğümüz yoğun ön işleme ve modelleme süreçlerini, belirlediğimiz görev dağılımı sayesinde yüksek bir verimlilikle yönettik. WhatsApp üzerinden yürüttüğümüz Daily Scrum toplantıları, şeffaf bir iletişim kurmamızı sağlayarak karşılaştığımız teknik engelleri hızla aşmamıza yardımcı oldu. Jira tahtamızdaki zorlu API entegrasyonu, JSON ayrıştırma ve model eğitimi görevlerinin neredeyse tamamını "Done" statüsüne çekebilmemiz, takım içindeki uyumun ve paralel çalışma refleksimizin ne kadar güçlü olduğunu kanıtladı. EfficientNet-B3 modelimizin eğitiminde ve veri artırma (augmentation) aşamalarında elde ettiğimiz başarılı sonuçlar, sistemin temelini sağlam atmamızı sağladı. Sprint 2'ye geçerken en büyük odak noktamız, ilk sprintte titizlikle hazırladığımız bu veri kümelerini ve eğitilmiş güçlü CNN modelini arka uç (backend) mimarisine entegre etmek ve API entegrasyonunu tamamlamak olacaktır.

---

# Sprint 2

- **Daily Scrum**:
<img width="788" height="320" alt="DailyScrum 1" src="https://github.com/user-attachments/assets/917fe3d4-bc4c-466d-be58-885b182eb163" />
<img width="793" height="473" alt="DailyScrum 2" src="https://github.com/user-attachments/assets/22d1e101-2395-461d-8547-3b622218fe6d" />

- **Sprint board update**: Sprint board screenshotları:

- **Ürün Durumu**:

- **Sprint Review**:
- Tarla Gözcüsü projemizin backend entegrasyonu, karar destek algoritmaları ve mobil uygulama arayüzlerini geliştirdiğimiz Sprint 2'yi, tüm hedeflerimizi ve planlanan Jira görevlerimizi eksiksiz tamamlayarak başarıyla kapattık. Bir önceki sprintten devraldığımız koordinat bazlı OpenWeatherMap API entegrasyonunu tamamlayarak sisteme dahil ettik. Karar destek algoritmaları tarafında, FAO-56 Penman-Monteith denklemini temel alan günlük optimal sulama ihtiyacı modelini ve birinci derece reaksiyon kinetiğiyle çalışan NPK gübre yıkanma (leaching) modelini geliştirdik. Merkezi API sunucumuz olan FastAPI üzerinde; bu matematiksel modelleri, PostgreSQL (SQLAlchemy) veritabanı persistence katmanını, EfficientNet-B2 TFLite yaprak hastalığı teşhis modelini ve Google Gemini API entegrasyonlu proaktif Terra AI karar destek asistanını bir araya getirdik. Ayrıca, tüm bu servislerin entegrasyonunu kolaylaştırmak amacıyla istek/yanıt şemalarını içeren kapsamlı API dokümantasyonunu backend/README.md dosyamıza ekledik. Mobil tarafta ise Flutter uygulamamızın; Dashboard, Leaf Disease Diagnosis, Giriş/Kayıt, Optimizasyon Detayları, Risk Haritası ve Terra Chat ekranlarını tamamlayarak ApiService üzerinden backend servisleriyle entegre ettik. (taslak)

- **Sprint Retrospective:**
- Sprint 2 süresince paralel yürüttüğümüz backend servis kodlaması, tarımsal algoritmaların formülleştirilmesi ve mobil arayüz geliştirme çalışmalarını, aramızdaki güçlü koordinasyon ve net görev dağılımı sayesinde yüksek bir verimlilikle tamamladık. WhatsApp üzerinden yürüttüğümüz asenkron iletişim, karşılaştığımız teknik engelleri anında aşmamızı sağladı. Jira tahtamızdaki tüm entegrasyon görevlerini tamamladık. Final adımlarını atacağımız Sprint 3'e geçerken ana odak noktamız; uçtan uca hata yönetimi testleriyle ürün bütünlüğünü korumak, kodumuzu arındırıp frontend ve backend katmanlarımızı buluta taşımak, 3 dakikalık proje sunum videosunu hazırlamak ve 2 Ağustos'a teslim formunu eksiksiz bir şekilde tamamlamak olacaktır. (taslak)

---

# Sprint 3

- **Daily Scrum**:

- **Sprint board update**: Sprint board screenshotları:
 
- **Ürün Durumu**:

- **Sprint Review**:
- 

- **Sprint Retrospective:**
-
---
