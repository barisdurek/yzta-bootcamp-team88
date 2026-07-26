# Tarla Gözcüsü - Karar Destek ve Çiftçi Aksiyon Çeviri Matrisi

## 📋 Genel Bakış
Bu doküman, Tarla Gözcüsü platformunda arka planda çalışan karmaşık analitik modellerin (FAO-56 Penman-Monteith su bütçesi, NPK yıkanma simülasyonu, NASA Power iklim verileri ve EfficientNet-B2 CNN hastalık tespiti) çiftçilerin doğrudan anlayabileceği ve uygulayabileceği sade aksiyon kartlarına dönüştürülme kurallarını tanımlar.

---

## 🟢 1. Sulama ve Su Yönetimi Kuralları (FAO-56 PM & Toprak Nemi)

### 1.1 Yüksek Sulama İhtiyacı
- **Arka Plan Koşulu:** 
  - FAO-56 $ET_c$ (Buharlaşma) $> 7.5 \text{ mm/gün}$
  - Hiperspektral Toprak Nemi $< \%30$
  - Önümüzdeki 24 saatte beklenen yağış $< 2 \text{ mm}$
- **Çiftçi Kartı Başlığı:** 🚨 **YÜKSEK SULAMA İHTİYACI**
- **Çiftçi Mesajı:** *"Sıcaklık ve buharlaşma yüksek. Mahsulünüzün su stresine girmemesi için bu akşam 19:00 sonrasında 2.5 saat sulama yapın."*
- **Tasarruf / Etki Metriği:** Su stresi kaynaklı rekolte kaybı önlendi.

### 1.2 Sulama Durdurma / Erteleme
- **Arka Plan Koşulu:**
  - Önümüzdeki 24-48 saat içinde tahmini yağış $> 15 \text{ mm}$
  - VEYA Toprak Nemi $> \%75$ (Doygunluk seviyesi)
- **Çiftçi Kartı Başlığı:** 🛑 **SULAMAYI DURDURUN**
- **Çiftçi Mesajı:** *"Yaklaşan kuvvetli yağış nedeniyle kök çürümesini önlemek ve su tasarrufu sağlamak için bugün sulama vanalarını kapatın."*
- **Tasarruf / Etki Metriği:** Tahmini ~150 TL Elektrik/Su Tasarrufu & Kök Çürümesi Önleme.

### 1.3 Optimum Nem Denge Durumu
- **Arka Plan Koşulu:**
  - Toprak Nemi $\%50 - \%70$ arasında
  - $ET_c$ normal seviyede ($3 - 5 \text{ mm/gün}$)
- **Çiftçi Kartı Başlığı:** ✅ **TOPRAK NEMİ İDEAL**
- **Çiftçi Mesajı:** *"Toprağınız şu an optimum nem seviyesinde. Önümüzdeki 48 saat sulama yapmanıza gerek yoktur."*
- **Tasarruf / Etki Metriği:** Optimum su dengesi korundu.

---

## 🟡 2. Gübreleme ve NPK Yıkanma Risk Yönetimi

### 2.1 Gübreleme Erteleme (Yıkanma Riski)
- **Arka Plan Koşulu:**
  - Önümüzdeki 48 saatlik yağış/sulama simülasyonu $> 20 \text{ mm}$
  - Toprak Azot (N) Yıkanma İndeksi $> \%30$
- **Çiftçi Kartı Başlığı:** ⚠️ **GÜBRELEMEYİ ERTELEYİN**
- **Çiftçi Mesajı:** *"Beklenen şiddetli yağış topraktaki azotu yıkayıp boşa harcatacaktır. Gübreleme işlemini yağış sonrasına (Salı gününe) erteleyin."*
- **Tasarruf / Etki Metriği:** %100 Gübre Yıkanma İsrafı Önleme.

### 2.2 Azot Takviyesi Zamanı
- **Arka Plan Koşulu:**
  - Mahsul gelişim evresi: Vejetatif Büyüme
  - Son 14 gündür Azot takviyesi yapılmadı
  - Yağış riski $< \%20$
- **Çiftçi Kartı Başlığı:** 🌿 **AZOT TAKVİYESİ ZAMANI**
- **Çiftçi Mesajı:** *"Mahsulünüzün hızlı büyüme evresi için azot ihtiyacı artıyor. Havanın açık olduğu önümüzdeki 2 gün içinde dönüm başı 5 kg Azot içerikli gübre uygulayabilirsiniz."*
- **Tasarruf / Etki Metriği:** Optimum yaprak ve gövde gelişimi.

---

## 🔵 3. Zirai Mücadele ve İlaçlama Zamanlaması

### 3.1 İlaçlama Yasak / Uyumsuz Şartlar
- **Arka Plan Koşulu:**
  - Rüzgar Hızı $> 20 \text{ km/s}$
  - VEYA Hava Sıcaklığı $> 30^\circ\text{C}$
- **Çiftçi Kartı Başlığı:** 🚫 **İLAÇLAMA YAPMAYIN**
- **Çiftçi Mesajı:** *"Rüzgar hızı yüksek. Atacağınız ilaç rüzgarla savrulur ve yaprağa tutunamaz. İlaçlamayı yarın sabah erken saatlere (06:00-08:00) kaydırın."*
- **Tasarruf / Etki Metriği:** İlaç israfı ve çevre kirliliği önlendi.

### 3.2 Erken Evre Hastalık Tespiti (CNN Model)
- **Arka Plan Koşulu:**
  - EfficientNet-B2 CNN modeli güven skoru $> \%80$ (Örn: Erken Yaprak Lekesi)
- **Çiftçi Kartı Başlığı:** 🔍 **ERKEN EVRE HASTALIK TESPİTİ**
- **Çiftçi Mesajı:** *"Tarlanızda Erken Yaprak Lekesi başlangıcı tespit edildi. Hastalık yayılmadan sadece enfekte bölgeye bakır esaslı koruyucu ilaç uygulayın."*
- **Tasarruf / Etki Metriği:** Bölgesel lokal müdahale ile %70 İlaç Tasarrufu.

---

## 🔴 4. Havza Bazlı Erken Uyarı ve Kolektif Koruma

### 4.1 Bölgesel Salgın Uyarısı
- **Arka Plan Koşulu:**
  - 5 km yarıçapındaki komşu tarlada doğrulanan hastalık/zararlı vaka sayısı $\ge 1$
- **Çiftçi Kartı Başlığı:** 📢 **BÖLGESEL SALGIN UYARISI**
- **Çiftçi Mesajı:** *"3 km yakınınızdaki komşu tarlada Pas Hastalığı tespiti yapıldı. Tarlanızda henüz belirti olmasa bile koruyucu sprey kontrolü yapmanız önerilir."*
- **Tasarruf / Etki Metriği:** Bölgesel yayılım ve toplu rekolte kaybı önlendi.
