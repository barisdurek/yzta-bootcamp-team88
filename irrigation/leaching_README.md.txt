⚙️ Metodoloji ve Mühendislik Teorisi Açıklaması
Tarımsal sistem analizi yaklaşımlarına dayanarak kurgulanan model iki ana mekanizmadan oluşur: Su Hareketliliği (Percolation) ve Besin Elementi Kimyası (Adsorption ve Solubilisation).

1. Derine Süzülme ve Toprak Fiziği (Percolation)
Toprağa giren suyun tamamı yıkanmaya neden olmaz. Toprak, gözenek yapısına göre belirli bir miktar suyu yerçekimine karşı tutabilir (Tarla Kapasitesi sınırı).

Sıcaklık ve Gözenek Sınırı ($S_{cap}$): Toprağın günlük su tutma kapasitesi ($S_{cap}$, mm) aşıldığında yerçekimi suyun derine süzülmesini tetikler.
Kumlu (Sand) Toprak: Büyük makro gözeneklere sahiptir, su tutma kapasitesi çok düşüktür ($S_{cap} = 8 , \text{mm}$). Aşırı suyun %85 ($f_{perc} = 0.85$) gibi çok yüksek bir oranı derine süzülür.
Tınlı (Loam) Toprak: Dengeli gözenek yapısına sahiptir ($S_{cap} = 20 , \text{mm}$), süzülme katsayısı %50 ($f_{perc} = 0.50$)'dir.
Killi (Clay) Toprak: Mikro gözenek oranı yüksek, su tutma kapasitesi çok güçlüdür ($S_{cap} = 35 , \text{mm}$). Sızma katsayısı oldukça düşüktür %20 ($f_{perc} = 0.20$).
Formül: $$V_{perc} = \max(0.0, (P + I) - S_{cap}) \cdot f_{perc}$$
2. Element Mobilitesi ve Adsorpsiyon Dinamikleri ($\alpha$)
Yıkanma hızları, toprak kimyasındaki Katyon Değişim Kapasitesine (CEC) ve elementlerin anyon/katyon formuna bağlı olarak değişir:

Azot (N - Yüksek Yıkanma Hızı, $\alpha_N$): Bitkiler azotu çoğunlukla Nitrat ($NO_3^-$) şeklinde alır. Nitrat negatif yüklü bir anyondur. Toprak kolloidleri de negatif yüklü olduğu için nitratı tutamazlar; azot suyla birlikte son derece hızlı hareket eder ve yıkanır.
Potasyum (K - Orta Yıkanma Hızı, $\alpha_K$): Potasyum ($K^+$) pozitif yüklü bir katyondur. Killi topraklardaki negatif yüklü kil minerallerine elektrostatik olarak tutunur. Kumlu topraklarda bu tutunma zayıf olduğundan yıkanması hızlanır.
Fosfor (P - Çok Düşük Yıkanma Hızı, $\alpha_P$): Fosfat ($H_2PO_4^-$) anyon formunda olmasına rağmen toprakta serbestçe çözünmüş halde kalmaz. Alüminyum, Demir (asidik topraklarda) ve Kalsiyum (alkali topraklarda) iyonları ile reaksiyona girerek çözünmeyen çökeltiler oluşturur (adsorpsiyon/sabitleme). Bu nedenle yıkanma riski ihmal edilebilir düzeydedir.
3. Birinci Derece Kinetik Yıkanma Modeli (Kayıp Yüzdesi)
Süzülen su miktarı ($V_{perc}$) arttıkça yıkanma miktarının asimptotik olarak %100 sınırına yaklaşmasını sağlamak amacıyla Birinci Derece Reaksiyon Kinetiği (First-Order Kinetic) modeli kullanılmıştır: $$\text{Kayıp %} = 100 \cdot \left(1.0 - e^{-\alpha \cdot V_{perc}}\right)$$ Bu sayede su miktarı katlansa bile kayıpların fiziksel olarak gerçekçi bir şekilde dengelenmesi (diminishing returns) sağlanır.

📊 Simülasyon Doğrulama Özeti


test_irrigation.py
 betiği ile yapılan doğrulama sonuçları:

Kumlu Toprakta (40 mm su girişi): Su tutma sınırı düşük olduğundan derine süzülme yüksek gerçekleşti. Azot kaybı %88.65, Potasyum kaybı %55.78, Fosfor kaybı ise sadece %12.72 hesaplandı (Mobilitenin $N > K > P$ sıralaması doğrulandı).
Killi Toprakta (40 mm su girişi): Kilin yüksek su tutma kapasitesi ($35,\text{mm}$) ve düşük süzülme katsayısı ($0.20$) sayesinde derine süzülme $1.0,\text{mm}$ seviyesinde kaldı. Azot kaybı %2.96, Potasyum kaybı %0.80, Fosfor kaybı %0.05 olarak sınırlı kaldı (Killi toprağın koruma etkisi doğrulandı).
Sınır Altındaki Su Girişinde (2 mm su girişi): Toprak kapasitesi aşılmadığı için derine süzülme gerçekleşmedi ve tüm element kayıpları %0.00 olarak hesaplandı.