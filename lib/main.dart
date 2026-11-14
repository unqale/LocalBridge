import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'localization/extra_strings.dart';
import 'models/file_staging.dart';
import 'theme/editorial_theme.dart';
import 'widgets/editorial_graphics.dart';
import 'widgets/file_staging_view.dart';

export 'models/file_staging.dart';
export 'theme/editorial_theme.dart';
export 'widgets/editorial_graphics.dart';
export 'widgets/file_staging_view.dart';

const int kDefaultPort = 53317;
const String kAppId = 'localbridge';
const String kAppName = 'LocalBridge';
const String kVersion = '3.0.6 Beta';

Future<void> _writeJsonAtomically(File target, String json) async {
  final temporary = File('${target.path}.tmp');
  try {
    await temporary.writeAsString(json, flush: true);
    await temporary.rename(target.path);
  } finally {
    if (await temporary.exists()) await temporary.delete();
  }
}

/// Brand colors used by the double-arch studio bridge logo and startup animation.
const Color kBrand1 = Color(0xFFE06D53);
const Color kBrand2 = Color(0xFFD9822B);
const Color kBrand3 = Color(0xFF289D8F);

/// Phone / small-window layout: one column that never gets wider than this.
const double kMaxContentWidth = 600;

/// From this window width on, the bottom bar is replaced by a side menu.
const double kWideBreakpoint = 900;

/// Widest the content area gets on huge monitors.
const double kMaxWideWidth = 2200;

/// Pages switch to two columns when their own area is at least this wide.
const double kTwoColWidth = 700;

class ChangelogItem {
  final String version;
  final Map<AppLang, String> titles;
  final Map<AppLang, List<String>> details;
  const ChangelogItem(this.version, this.titles, this.details);

  String title(AppLang l) => titles[l] ?? titles[AppLang.english] ?? '';
  List<String> lines(AppLang l) =>
      details[l] ?? details[AppLang.english] ?? const <String>[];
}

const List<ChangelogItem> kChangelog = [
  ChangelogItem(
    kVersion,
    {
      AppLang.english: 'Better file transfers and local sharing',
      AppLang.turkish: 'Dosya aktarımı ve yerel paylaşım iyileştirmeleri',
      AppLang.russian: 'Улучшения передачи файлов и локального обмена',
      AppLang.german: 'Dateiübertragung und lokales Teilen verbessert',
      AppLang.spanish: 'Mejoras en la transferencia y el uso compartido local',
      AppLang.french: 'Transferts de fichiers et partage local améliorés',
    },
    {
      AppLang.english: [
        'Choose a nearby device from the radar, or right-click its card to open chat, send files or remove it.',
        'Connect on the same network using Desk Code. The other device accepts the request before a chat can start.',
        'Review the recipient, file names, sizes and image previews before sending. Add or remove individual files.',
        'Drag files and folders in from Windows Explorer. On Android, review files in a bottom sheet and recover a selection if Android interrupts the picker.',
        'Cancel an active send. If a batch is interrupted, retry the files whose delivery has not been acknowledged.',
        'Incoming files are written to a temporary file first. The receiver checks the byte count before saving them under their final name.',
        'Share with a browser using a QR code generated on the device. PIN approval is per browser and active downloads count towards the limit.',
        'Search transfer history by file or device name and open the folder of a saved file.',
        'The Windows sidebar shows nearby devices, sent and received files, and downloads during an active link share.',
        'Unopened tabs are loaded on demand, and hidden tabs pause their animations. German, Spanish and French are available alongside English, Turkish and Russian.',
      ],
      AppLang.turkish: [
        'Radardan yakındaki cihazı seç. Cihaz kartına sağ tıklayarak sohbet aç, dosya gönder veya cihazı kaldır.',
        'Aynı ağda Desk Code ile bağlan. Sohbet başlamadan önce karşı cihaz bağlantı isteğini onaylar.',
        'Göndermeden önce alıcıyı, dosya adlarını, boyutları ve görsel önizlemelerini kontrol et. Listeye tek tek dosya ekleyebilir veya çıkarabilirsin.',
        'Windows’ta Explorer’dan dosya ve klasör sürükle. Android’de dosyaları alt panelde incele ve sistem dosya seçicisini kesintiye uğratırsa seçimi geri al.',
        'Süren gönderimi iptal et. Toplu gönderim yarıda kalırsa teslimi onaylanmamış dosyaları yeniden gönder.',
        'Gelen dosyalar önce geçici bir dosyaya yazılır. Alıcı, dosyayı son adıyla kaydetmeden önce bayt sayısını doğrular.',
        'Tarayıcı paylaşımı için QR kodu cihazda üretilir. PIN onayı tarayıcı oturumuna aittir ve devam eden indirmeler kotaya dahil edilir.',
        'Geçmişte dosya veya cihaz adıyla ara ve kaydedilmiş dosyanın klasörünü aç.',
        'Windows sol menüsünde yakındaki cihazları, gönderilen ve alınan dosya sayılarını ve paylaşım sırasında indirme sayısını gör.',
        'Sekmeler ilk açıldığında yüklenir ve görünmeyen sekmelerin animasyonları durur. İngilizce, Türkçe ve Rusçaya Almanca, İspanyolca ve Fransızca eklendi.',
      ],
      AppLang.russian: [
        'Выберите ближайшее устройство на радаре или откройте контекстное меню карточки для чата, отправки файлов или удаления.',
        'Подключайтесь по Desk Code в одной сети. Другое устройство должно принять запрос перед началом чата.',
        'Проверьте получателя, имена и размеры файлов и миниатюры изображений. Добавляйте и удаляйте файлы перед отправкой.',
        'Перетаскивайте файлы и папки из Проводника Windows. На Android используйте нижнюю панель и восстанавливайте выбор после прерывания системного диалога.',
        'Отменяйте отправку и повторяйте передачу файлов, доставка которых не была подтверждена.',
        'Полученные данные сначала сохраняются во временный файл. Перед сохранением под итоговым именем проверяется размер.',
        'QR-код создаётся на устройстве. Допуск по PIN действует в рамках сеанса браузера, а текущие загрузки учитываются в лимите.',
        'Ищите в истории по имени файла или устройства и открывайте папку сохранённого файла.',
        'В боковом меню Windows видны ближайшие устройства, счётчики отправленных и полученных файлов и число загрузок по активной ссылке.',
        'Вкладки загружаются при первом открытии. Анимации скрытых вкладок приостанавливаются. Добавлены немецкий, испанский и французский языки.',
      ],
      AppLang.german: [
        'Wähle ein Gerät im Radar oder öffne per Rechtsklick Chat, Dateiübertragung oder Entfernen.',
        'Verbinde Geräte im selben Netz per Desk Code. Das andere Gerät muss die Anfrage annehmen.',
        'Prüfe Empfänger, Dateinamen, Größen und Bildvorschauen. Dateien lassen sich vor dem Senden hinzufügen oder entfernen.',
        'Ziehe Dateien und Ordner aus dem Windows-Explorer in die App. Android zeigt die Auswahl unten an und kann eine unterbrochene Auswahl wiederherstellen.',
        'Brich eine Übertragung ab und sende Dateien ohne Zustellbestätigung bei Bedarf erneut.',
        'Empfangene Dateien werden zunächst temporär gespeichert. Vor dem Umbenennen wird die Bytezahl geprüft.',
        'Der QR-Code wird lokal erzeugt. Die PIN-Freigabe gilt pro Browsersitzung, laufende Downloads zählen zum Limit.',
        'Durchsuche den Verlauf nach Datei oder Gerät und öffne den Speicherordner.',
        'Die Windows-Seitenleiste zeigt Geräte, gesendete und empfangene Dateien sowie Downloads einer aktiven Freigabe.',
        'Ansichten laden beim ersten Öffnen. Verborgene Ansichten pausieren ihre Animationen. Deutsch, Spanisch und Französisch wurden ergänzt.',
      ],
      AppLang.spanish: [
        'Elige un dispositivo en el radar o abre su menú contextual para chatear, enviar archivos o quitarlo.',
        'Conéctate por Desk Code en la misma red. El otro dispositivo debe aceptar la solicitud.',
        'Revisa el destinatario, los nombres, tamaños y vistas previas. Añade o quita archivos antes de enviar.',
        'Arrastra archivos y carpetas desde el Explorador de Windows. En Android revisa la selección en un panel inferior y recupera una selección interrumpida.',
        'Cancela una transferencia y vuelve a enviar los archivos cuya entrega siga pendiente de confirmación.',
        'Los archivos entrantes se guardan de forma temporal. El receptor verifica el número de bytes antes de asignar el nombre final.',
        'El código QR se genera en el dispositivo. La aprobación con PIN es por sesión del navegador y las descargas activas cuentan para el límite.',
        'Busca por archivo o dispositivo en el historial y abre la carpeta de un archivo guardado.',
        'La barra lateral de Windows muestra dispositivos cercanos, archivos enviados y recibidos y descargas del enlace activo.',
        'Las pestañas cargan al abrirse y las ocultas pausan sus animaciones. Se añadieron alemán, español y francés.',
      ],
      AppLang.french: [
        'Sélectionnez un appareil dans le radar ou utilisez son menu contextuel pour discuter, envoyer des fichiers ou le retirer.',
        'Connectez-vous avec un Desk Code sur le même réseau. L’autre appareil doit accepter la demande.',
        'Vérifiez le destinataire, les noms, tailles et aperçus. Ajoutez ou retirez des fichiers avant l’envoi.',
        'Glissez-déposez fichiers et dossiers depuis l’Explorateur Windows. Sur Android, vérifiez la sélection dans un panneau inférieur et récupérez une sélection interrompue.',
        'Annulez un envoi et reprenez avec les fichiers dont la réception reste à confirmer.',
        'Les fichiers entrants sont enregistrés temporairement. Le nombre d’octets est vérifié avant de leur attribuer leur nom final.',
        'Le QR code est généré sur l’appareil. Le PIN autorise une session de navigateur et les téléchargements en cours comptent dans le quota.',
        'Recherchez un fichier ou un appareil dans l’historique et ouvrez le dossier d’un fichier enregistré.',
        'La barre latérale Windows affiche les appareils, les fichiers envoyés et reçus et les téléchargements du lien actif.',
        'Les onglets se chargent à leur première ouverture et suspendent leurs animations lorsqu’ils sont masqués. L’allemand, l’espagnol et le français ont été ajoutés.',
      ],
    },
  ),
  ChangelogItem(
    '3.0.5',
    {
      AppLang.english: 'Android scrolling and display refresh',
      AppLang.turkish: 'Android kaydırma ve ekran yenileme',
      AppLang.russian: 'Прокрутка и частота обновления на Android',
      AppLang.german: 'Scrollleiste und Bildwiederholrate unter Android',
      AppLang.spanish: 'Desplazamiento y frecuencia de pantalla en Android',
      AppLang.french: 'Défilement et fréquence de l’écran sur Android',
    },
    {
      AppLang.english: [
        'Fixed the Android scrollbar and limited radar animation to active scans.',
        'This release requested the highest refresh mode available at the current resolution on supported Android devices.',
      ],
      AppLang.turkish: [
        'Android kaydırma çubuğu düzeltildi ve radar animasyonu etkin taramalarla sınırlandı.',
        'Bu sürüm, desteklenen Android cihazlarda mevcut çözünürlükteki en yüksek yenileme hızını istiyordu.',
      ],
      AppLang.russian: [
        'Исправлена полоса прокрутки. Радар анимируется только во время поиска.',
        'На поддерживаемых устройствах Android эта версия запрашивала максимальную частоту обновления для текущего разрешения.',
      ],
      AppLang.german: [
        'Die Android-Scrollleiste wurde korrigiert. Das Radar animiert nur während der Suche.',
        'Auf unterstützten Geräten wurde die höchste Bildwiederholrate der aktuellen Auflösung angefragt.',
      ],
      AppLang.spanish: [
        'Se corrigió la barra de desplazamiento de Android y se limitó la animación del radar a la búsqueda activa.',
        'En dispositivos compatibles se solicitaba la frecuencia de pantalla más alta para la resolución actual.',
      ],
      AppLang.french: [
        'La barre de défilement Android a été corrigée. Le radar ne s’anime que pendant la recherche.',
        'Sur les appareils compatibles, cette version demandait la fréquence la plus élevée pour la résolution actuelle.',
      ],
    },
  ),
  ChangelogItem(
    '3.0.0',
    {
      AppLang.english: 'Device discovery and desktop settings',
      AppLang.turkish: 'Cihaz keşfi ve masaüstü ayarları',
      AppLang.russian: 'Поиск устройств и настройки',
    },
    {
      AppLang.english: [
        "Faster startup: the app, the server and your history now load at the same time, and the logo animation is shorter by default (new Startup animation setting: Off, Quick or Full)",
        "Much faster device scanning: devices appear the moment they answer, devices seen before are checked first, and the scan no longer waits for the slowest address",
        "New Scan speed setting (Balanced, Fast, Turbo): faster scans find devices sooner but use more network and battery",
        "Smarter scanning: VPN, virtual machine and Docker networks are skipped (new Scan VPN and virtual networks setting), auto scan only re-checks known devices between full sweeps, and devices no longer flicker when one scan misses them",
        "Share links now list only your real network addresses",
        "Eleven new settings: status bar on/off, light follows the mouse, background glow strength, 24-hour clock, sort devices (name, address, found order), sound when a transfer ends, confirm before sending, start turned on, confirm before clearing history, hover effects and side menu stats",
        "New look: a redesigned What's new window, a nicer Devices header, What's new and Made by links at the bottom of the side menu, the Turn on / Turn off button now sits at the top right of the Devices page, and the scroll bar sits at the edge of the window",
        "Settings page redesigned for big windows: category list on the left, a search box for settings and a Reset preferences button",
        "New status bar at the bottom of the window with the connection state, server port and your address",
        "The light around the mouse cursor is smaller and softer",
        "The background glow now follows your mouse smoothly and breathes gently where the cursor rests",
        "Settings rows now match the new look: hover and press effects, rounded icon badges, new switches, sliders, menus and text fields",
        "The side menu is fuller: your device card (Windows / Android, name and IP), live stats, a power button and the connection status",
        "Devices page: new Quick settings card, bigger cards and bars, so the page no longer feels empty",
        "New receive settings: accept only from trusted devices, incoming size limit and open the folder after receiving",
        "Snackbars and menus use the new rounded dark style",
        "The background light now follows the mouse instantly, with no delay",
        "New bridge logo in the assets folder, also used as the real app icon of the .exe and .apk (no more Flutter logo)",
      ],
      AppLang.turkish: [
        "Daha hızlı açılış: uygulama, sunucu ve geçmişin artık aynı anda yükleniyor, logo animasyonu varsayılan olarak daha kısa (yeni Açılış animasyonu ayarı: Kapalı, Kısa veya Uzun)",
        "Çok daha hızlı cihaz taraması: cihazlar cevap verdiği anda görünüyor, daha önce görülen cihazlar önce kontrol ediliyor ve tarama artık en yavaş adresi beklemiyor",
        "Yeni Tarama hızı ayarı (Dengeli, Hızlı, Turbo): daha hızlı tarama cihazları daha çabuk bulur ama daha fazla ağ ve pil kullanır",
        "Daha akıllı tarama: VPN, sanal makine ve Docker ağları atlanıyor (yeni VPN ve sanal ağları tara ayarı), otomatik tarama tam taramalar arasında yalnızca bilinen cihazları kontrol ediyor ve bir tarama cihazı kaçırınca cihazlar artık listeden titreyerek kaybolmuyor",
        "Paylaşım bağlantıları artık yalnızca gerçek ağ adreslerini listeliyor",
        "On bir yeni ayar: durum çubuğunu aç/kapat, ışık fareyi takip etsin, arka plan parlama gücü, 24 saat biçimi, cihazları sırala (isim, adres, bulunma sırası), aktarım bitince ses, göndermeden önce onay, açık başlat, geçmişi silmeden önce onay, üzerine gelme efektleri ve yan menü istatistikleri",
        "Yeni görünüm: yenilenen Yenilikler penceresi, daha güzel Cihazlar başlığı, yan menünün altında Yenilikler ve Made by bağlantıları, Aç / Kapat düğmesi artık Cihazlar sayfasının sağ üstünde ve kaydırma çubuğu pencerenin kenarında",
        "Ayarlar sayfası büyük pencereler için yenilendi: solda kategori listesi, ayar arama kutusu ve Ayarları sıfırla düğmesi",
        "Pencerenin altında bağlantı durumu, sunucu portu ve adresini gösteren yeni durum çubuğu",
        "Fare imlecinin etrafındaki ışık daha küçük ve daha yumuşak",
        "Arka plan ışığı artık fareni akıcı şekilde takip ediyor ve imlecin durduğu yerde hafifçe nefes alıyor",
        "Ayar satırları yeni görünüme uyumlu: üzerine gelme ve basma efektleri, yuvarlak ikon rozetleri, yeni anahtarlar, kaydırıcılar, menüler ve yazı alanları",
        "Yan menü daha dolu: cihaz kartın (Windows / Android, ad ve IP), canlı istatistikler, güç düğmesi ve bağlantı durumu",
        "Cihazlar sayfası: yeni Hızlı ayarlar kartı, daha büyük kartlar ve çubuklar, sayfa artık boş hissettirmiyor",
        "Yeni alma ayarları: yalnızca güvenilir cihazlardan kabul, gelen dosya boyutu sınırı ve aldıktan sonra klasörü açma",
        "Bildirimler ve menüler yeni yuvarlak koyu stili kullanıyor",
        "Arka plan ışığı artık fareyi gecikmesiz, anında takip ediyor",
        "assets klasöründe yeni köprü logosu var; .exe ve .apk uygulamalarının gerçek simgesi de bu logo (Flutter logosu kalktı)",
      ],
      AppLang.russian: [
        "Быстрее запуск: приложение, сервер и история теперь загружаются одновременно, а анимация логотипа по умолчанию короче (новая настройка Анимация запуска: Выкл, Короткая или Полная)",
        "Намного быстрее поиск устройств: устройства появляются сразу после ответа, ранее найденные проверяются первыми, а сканирование больше не ждёт самый медленный адрес",
        "Новая настройка Скорость сканирования (Сбалансированная, Быстрая, Турбо): быстрое сканирование находит устройства раньше, но использует больше сети и батареи",
        "Умнее сканирование: сети VPN, виртуальных машин и Docker пропускаются (новая настройка Сканировать VPN и виртуальные сети), автоматическое сканирование между полными проходами проверяет только известные устройства, а устройства больше не мигают в списке, если один проход их пропустил",
        "Ссылки для раздачи теперь показывают только реальные сетевые адреса",
        "Одиннадцать новых настроек: строка состояния вкл/выкл, свет следует за мышью, сила свечения фона, 24-часовой формат, сортировка устройств (имя, адрес, порядок обнаружения), звук по окончании передачи, подтверждение отправки, запуск включённым, подтверждение очистки истории, эффекты наведения и статистика в боковом меню",
        "Новый вид: переработанное окно «Что нового», более красивый заголовок устройств, ссылки «Что нового» и Made by внизу бокового меню, кнопка включения и выключения теперь вверху справа на странице устройств, а полоса прокрутки у края окна",
        "Страница настроек переработана для больших окон: список категорий слева, поиск по настройкам и кнопка сброса настроек",
        "Новая строка состояния внизу окна: состояние подключения, порт сервера и ваш адрес",
        "Свет вокруг курсора мыши стал меньше и мягче",
        "Фоновое свечение теперь плавно следует за мышью и мягко «дышит» там, где остановился курсор",
        "Строки настроек в новом стиле: эффекты наведения и нажатия, круглые значки, новые переключатели, ползунки, меню и поля ввода",
        "Боковое меню стало насыщеннее: карточка устройства (Windows / Android, имя и IP), живая статистика, кнопка питания и состояние подключения",
        "Страница устройств: новая карточка быстрых настроек, карточки и панели крупнее, страница больше не кажется пустой",
        "Новые настройки приёма: только от доверенных устройств, лимит размера входящих и открытие папки после получения",
        "Уведомления и меню в новом закруглённом тёмном стиле",
        "Фоновый свет теперь следует за мышью мгновенно, без задержки",
        "Новый логотип моста в папке assets, он же настоящая иконка .exe и .apk (логотипа Flutter больше нет)",
      ],
    },
  ),
  ChangelogItem(
    '2.0.0',
    {
      AppLang.english: 'Big Update: Desktop Layout & Side Menu',
      AppLang.turkish: 'Büyük Güncelleme: Masaüstü Düzeni ve Yan Menü',
      AppLang.russian: 'Большое обновление: десктопный макет и боковое меню',
    },
    {
      AppLang.english: [
        "Big update: LocalBridge 2.0.0 now looks great in full screen and on big monitors",
        "New side menu on wide windows replaces the bottom bar",
        "The Devices page now has two columns: radar, sharing and link options on the left, nearby devices and more sharing settings on the right",
        "Sharing settings are now right on the Devices page, no separate screen to open",
        "Settings uses two columns on wide windows instead of one long narrow strip",
        "History is tidier on wide windows: a totals row and a multi-column grid",
        "Phones and small windows keep the familiar single column and bottom bar",
        'New radar hub: nearby devices appear on the radar and can be tapped to send',
        'Devices are now shown in a responsive grid with big Send buttons',
        'Floating bottom navigation bar',
        "New quick action tile for sharing via link",
        'History: filter chips (All / Sent / Received) and totals',
        'Settings: profile header and icon section headers',
        'Power switch: tap "Active" at the top right to turn LocalBridge off. It stops scanning and becomes invisible to other devices',
        'Hover animations: cards, buttons and navigation react when you move the mouse over them',
        'The "What\'s new" list is now translated into Turkish and Russian too',
        'New sharing settings: download limit, PIN attempt limit, a custom message on the download page, optional QR code and automatic link copying',
        'Completely removed legacy brand references and leftover text from the UI',
        'Fixed various UI layout shifts and pixel alignment issues',
        'Resolved a rare background crash issue during network scanning',
        'Optimized memory usage during large file transfers',
        'Fixed a bug causing background services to drop the Wi-Fi connection',
        'Corrected missing and inaccurate translations in Turkish and Russian language files',
        'Optimized the instant loading delay on the QR code generation screen',
        'Fixed a UI freezing issue when clearing the file transfer history list',
        'Removed AMOLED dark theme support because for New UI',
        'Added a dedicated inline QR Code area when clicking Share via Link ',
        "Sharing settings for one-time downloads, extension filters, PIN and auto-stop controls",
        'Cursor glow: a soft spotlight follows your mouse on the background and inside cards, like modern websites',
        'Devices page reworked on wide windows: radar on the left, nearby devices and sharing on the right, sharing settings in three even columns, fewer empty gaps',
        'Share via link is now a slim horizontal bar',
        'The GitHub link now opens directly in your browser instead of copying',
        'New startup animation: the bridge logo draws itself on a black screen when the app opens',
        'New bridge logo and app icon (Windows .exe, Android, macOS)',
      ],
      AppLang.turkish: [
        "Büyük güncelleme: LocalBridge 2.0.0 artık tam ekranda ve büyük monitörlerde çok daha iyi görünüyor",
        "Geniş pencerelerde alt çubuğun yerini yeni yan menü alıyor",
        "Cihazlar sayfası artık iki sütunlu: solda radar, paylaşım ve bağlantı seçenekleri, sağda yakındaki cihazlar ve diğer paylaşım ayarları",
        "Paylaşım ayarları artık doğrudan Cihazlar sayfasında, ayrı bir ekran açmana gerek yok",
        "Ayarlar, geniş pencerelerde tek uzun dar şerit yerine iki sütunda gösteriliyor",
        "Geçmiş geniş pencerelerde daha derli toplu: toplam satırı ve çok sütunlu ızgara",
        "Telefonlarda ve küçük pencerelerde alışkın olduğun tek sütun ve alt çubuk aynen kalıyor",
        "Yeni radar merkezi: yakındaki cihazlar radarda görünür ve dokunarak dosya gönderebilirsin",
        "Cihazlar artık büyük Gönder butonlu, ekrana uyumlu bir ızgarada gösteriliyor",
        "Yüzen alt gezinme çubuğu",
        "Bağlantıyla paylaşım için yeni hızlı eylem kutucuğu",
        "Geçmiş: filtre çipleri (Tümü / Gönderilen / Alınan) ve toplamlar",
        "Ayarlar: profil başlığı ve simgeli bölüm başlıkları",
        "Güç anahtarı: sağ üstteki \"Aktif\" yazısına dokununca LocalBridge kapanır, tarama durur ve diğer cihazlar seni göremez",
        "Fare animasyonları: kartlar, butonlar ve gezinme çubuğu fareyle üzerine gelince tepki verir",
        "\"Yenilikler\" listesi artık Türkçe ve Rusça olarak da çevriliyor",
        "Yeni paylaşım ayarları: indirme limiti, PIN deneme sınırı, indirme sayfasında özel mesaj, isteğe bağlı QR kod ve bağlantıyı otomatik kopyalama",
        'Eski marka adı ve arayüzde kalan eski metinler tamamen kaldırıldı',
        'Çeşitli arayüz kaymaları ve piksel hizalama sorunları düzeltildi',
        'Ağ taraması sırasında nadiren görülen arka plan çökmesi giderildi',
        'Büyük dosya aktarımları sırasında bellek kullanımı iyileştirildi',
        'Arka plan hizmetlerinin Wi-Fi bağlantısını düşürmesine neden olan hata düzeltildi',
        'Türkçe ve Rusça dil dosyalarındaki eksik ve hatalı çeviriler düzeltildi',
        'QR kod oluşturma ekranındaki yükleme gecikmesi azaltıldı',
        'Dosya aktarım geçmişi temizlenirken oluşan arayüz donması düzeltildi',
        'Yeni arayüz nedeniyle AMOLED koyu tema desteği kaldırıldı',
        "Bağlantı ile Paylaş'a tıklanınca özel bir QR kod alanı eklendi",
        "Tek seferlik indirme, uzantı filtresi, PIN ve otomatik durdurma için paylaşım ayarları",
        'İmleç parlaması: modern web siteleri gibi arka planda ve kartların içinde fareni takip eden yumuşak bir ışık eklendi',
        'Geniş pencerelerde Cihazlar sayfası yenilendi: solda radar, sağda yakındaki cihazlar ve paylaşım, paylaşım ayarları üç eşit sütunda, daha az boşluk',
        'Bağlantı ile paylaş artık ince yatay bir çubuk',
        'GitHub bağlantısı artık kopyalamak yerine doğrudan tarayıcıda açılıyor',
        'Yeni açılış animasyonu: uygulama açılırken siyah ekranda köprü logosu kendini çiziyor',
        'Yeni köprü logosu ve uygulama simgesi (Windows .exe, Android, macOS)',
      ],
      AppLang.russian: [
        "Большое обновление: LocalBridge 2.0.0 теперь отлично выглядит в полноэкранном режиме и на больших мониторах",
        "Новое боковое меню в широких окнах заменяет нижнюю панель",
        "Страница устройств теперь в две колонки: слева радар, раздача и параметры ссылки, справа ближайшие устройства и остальные настройки раздачи",
        "Настройки раздачи теперь прямо на странице устройств, отдельный экран открывать не нужно",
        "Настройки в широких окнах располагаются в две колонки вместо одной длинной узкой полосы",
        "История в широких окнах стала аккуратнее: строка итогов и сетка из нескольких колонок",
        "На телефонах и в маленьких окнах остаются привычная одна колонка и нижняя панель",
        'Новый радар-хаб: ближайшие устройства отображаются на радаре, нажмите на устройство, чтобы отправить файл',
        'Устройства теперь показаны в адаптивной сетке с большими кнопками «Отправить»',
        'Плавающая нижняя панель навигации',
        "Новая плитка быстрого действия для раздачи по ссылке",
        'История: фильтры (Все / Отправленные / Полученные) и итоги',
        'Настройки: заголовок профиля и разделы с иконками',
        'Кнопка питания: нажмите «Активен» справа вверху, чтобы выключить LocalBridge. Сканирование остановится, а другие устройства вас не увидят',
        'Анимации при наведении: карточки, кнопки и навигация реагируют на курсор мыши',
        'Список «Что нового» теперь переведён на турецкий и русский',
        'Новые настройки раздачи: лимит загрузок, лимит попыток PIN, своё сообщение на странице загрузки, необязательный QR-код и автокопирование ссылки',
        'Полностью удалены упоминания старого бренда и остатки старого текста в интерфейсе',
        'Исправлены сдвиги макета и проблемы с выравниванием пикселей',
        'Устранён редкий фоновый сбой при сканировании сети',
        'Оптимизировано использование памяти при передаче больших файлов',
        'Исправлена ошибка, из-за которой фоновые службы разрывали соединение Wi-Fi',
        'Исправлены отсутствующие и неточные переводы в турецком и русском языках',
        'Сокращена задержка загрузки на экране создания QR-кода',
        'Исправлено зависание интерфейса при очистке истории передач',
        'Поддержка тёмной темы AMOLED удалена из-за нового интерфейса',
        'Добавлена отдельная область QR-кода при нажатии «Поделиться ссылкой»',
        "Настройки раздачи: разовая загрузка, фильтр расширений, PIN и автоостановка",
        'Подсветка курсора: мягкий свет следует за мышью на фоне и внутри карточек, как на современных сайтах',
        'Страница устройств в широких окнах обновлена: слева радар, справа ближайшие устройства и раздача, настройки раздачи в три равные колонки, меньше пустых мест',
        '«Поделиться ссылкой» теперь компактная горизонтальная панель',
        'Ссылка на GitHub теперь открывается прямо в браузере, а не копируется',
        'Новая анимация запуска: логотип моста рисуется на чёрном экране при открытии приложения',
        'Новый логотип моста и значок приложения (Windows .exe, Android, macOS)',
      ],
    },
  ),
  ChangelogItem(
    '1.4.0',
    {
      AppLang.english: 'Multi-language & Extra Sharing Settings',
      AppLang.turkish: 'Çoklu Dil ve Ek Paylaşım Ayarları',
      AppLang.russian: 'Мультиязычность и дополнительные настройки раздачи',
    },
    {
      AppLang.english: [
        'Languages: English, Turkish, Russian support added',
        'Link sharing: One-time download mode & allowed file extension filter',
        'More security and sharing controls',
      ],
      AppLang.turkish: [
        'Diller: İngilizce, Türkçe ve Rusça desteği eklendi',
        'Bağlantı paylaşımı: tek seferlik indirme modu ve izin verilen dosya uzantısı filtresi',
        'Daha fazla güvenlik ve paylaşım kontrolü',
      ],
      AppLang.russian: [
        'Языки: добавлена поддержка английского, турецкого и русского',
        'Раздача по ссылке: режим одноразовой загрузки и фильтр разрешённых расширений',
        'Больше настроек безопасности и раздачи',
      ],
    },
  ),
  ChangelogItem(
    '1.3.0',
    {
      AppLang.english: 'Trusted Devices & Custom Save Folders',
      AppLang.turkish: 'Güvenilir Cihazlar ve Özel Kayıt Klasörleri',
      AppLang.russian: 'Доверенные устройства и свои папки сохранения',
    },
    {
      AppLang.english: [
        'Added trusted devices system to auto-accept transfers',
        'Custom save directory selection for Windows, Android, and macOS',
        'Improved network scanning stability',
      ],
      AppLang.turkish: [
        'Aktarımları otomatik kabul etmek için güvenilir cihazlar sistemi eklendi',
        'Windows, Android ve macOS için özel kayıt klasörü seçimi',
        'Ağ tarama kararlılığı iyileştirildi',
      ],
      AppLang.russian: [
        'Добавлена система доверенных устройств для автоприёма передач',
        'Выбор своей папки сохранения для Windows, Android и macOS',
        'Улучшена стабильность сканирования сети',
      ],
    },
  ),
  ChangelogItem(
    '1.2.0',
    {
      AppLang.english: 'File Transfer History & Progress Indicators',
      AppLang.turkish: 'Aktarım Geçmişi ve İlerleme Göstergeleri',
      AppLang.russian: 'История передач и индикаторы прогресса',
    },
    {
      AppLang.english: [
        'Persistent history log for sent and received files',
        'Real-time transfer progress bars and speed calculation',
        'AMOLED dark theme support',
      ],
      AppLang.turkish: [
        'Gönderilen ve alınan dosyalar için kalıcı geçmiş kaydı',
        'Gerçek zamanlı aktarım ilerleme çubukları ve hız hesabı',
        'AMOLED koyu tema desteği',
      ],
      AppLang.russian: [
        'Постоянный журнал отправленных и полученных файлов',
        'Индикаторы прогресса передачи в реальном времени и расчёт скорости',
        'Поддержка тёмной темы AMOLED',
      ],
    },
  ),
  ChangelogItem(
    '1.1.0',
    {
      AppLang.english: 'Web Browser Sharing via Link',
      AppLang.turkish: 'Bağlantı ile Tarayıcıdan Paylaşım',
      AppLang.russian: 'Раздача через браузер по ссылке',
    },
    {
      AppLang.english: [
        'Share files with anyone on the same Wi-Fi using a browser link',
        'Optional PIN protection for browser downloads',
        'Configurable server port and discovery options',
      ],
      AppLang.turkish: [
        "Aynı Wi-Fi'daki herkesle tarayıcı bağlantısı üzerinden dosya paylaş",
        'Tarayıcı indirmeleri için isteğe bağlı PIN koruması',
        'Ayarlanabilir sunucu portu ve keşif seçenekleri',
      ],
      AppLang.russian: [
        'Делитесь файлами с любым в той же Wi-Fi сети через ссылку в браузере',
        'Необязательная защита PIN-кодом для загрузок из браузера',
        'Настраиваемый порт сервера и параметры обнаружения',
      ],
    },
  ),
  ChangelogItem(
    '1.0.0',
    {
      AppLang.english: 'Initial Release',
      AppLang.turkish: 'İlk Sürüm',
      AppLang.russian: 'Первый релиз',
    },
    {
      AppLang.english: [
        'Local network peer discovery and fast file transfer',
        'Clean Material 3 user interface',
        'Cross-platform support for Windows, Android, macOS, and Linux',
      ],
      AppLang.turkish: [
        'Yerel ağda cihaz keşfi ve hızlı dosya aktarımı',
        'Temiz Material 3 kullanıcı arayüzü',
        'Windows, Android, macOS ve Linux için çoklu platform desteği',
      ],
      AppLang.russian: [
        'Обнаружение устройств в локальной сети и быстрая передача файлов',
        'Чистый интерфейс Material 3',
        'Кроссплатформенная поддержка Windows, Android, macOS и Linux',
      ],
    },
  ),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final settings = Settings();
  await settings.load();
  runApp(LocalBridgeApp(settings: settings));
}

// ------------------------------------------------------------- i18n (Localization)

enum AppLang {
  english('English'),
  turkish('Türkçe'),
  russian('Русский'),
  german('Deutsch'),
  spanish('Español'),
  french('Français');

  const AppLang(this.label);
  final String label;
}

class L10n {
  static final Map<AppLang, Map<String, String>> keys = {
    AppLang.english: {
      'devices': 'Devices',
      'history': 'History',
      'settings': 'Settings',
      'scan': 'Rescan',
      'scanning': 'Scanning…',
      'ready': 'Ready to receive',
      'serverOff': 'Server off',
      'autoAccept': 'Auto-accept',
      'askFirst': 'Ask first',
      'nearby': 'Nearby devices',
      'noDevices': 'No devices found',
      'shareViaLink': 'Share via link',
      'shareDesc': 'Anyone on your Wi-Fi can download in a browser',
      'shareBtn': 'Share',
      'stopShare': 'Stop sharing',
      'copyLink': 'Copy link',
      'linkCopied': 'Link copied',
      'showQr': 'QR Code',
      'qrTitle': 'Scan to Download',
      'send': 'Send',
      'clearHistory': 'Clear history',
      'noTransfers': 'No transfers yet',
      'device': 'Device',
      'deviceName': 'Device name',
      'appearance': 'Appearance',
      'receive': 'Receive',
      'network': 'Network',
      'about': 'About',
      'language': 'Language',

      'amoledTitle': 'Pure black (AMOLED)',
      'amoledSub': 'True black background in dark mode',
      'radarTitle': 'Device radar',
      'radarSub': 'Show devices and animate active scans',
      'compactTitle': 'Compact header',
      'compactSub': 'Hide the big radar to fit more on screen',
      'ipTitle': 'Show IP addresses',
      'ipSub': 'Turn off to hide IPs on screen',
      'hapticTitle': 'Haptic feedback',
      'hapticSub': 'Vibrate when a transfer finishes',
      'textSize': 'Text size',

      'autoAcceptTitle': 'Auto-accept',
      'autoAcceptSub': 'Save incoming files without asking.',
      'saveFolder': 'Save folder',
      'openFolder': 'Open save folder',
      'groupBySender': 'Group by sender',
      'groupBySenderSub': 'Save files into a folder named after the sender',
      'overwrite': 'Overwrite existing files',
      'overwriteSub': 'Off: keeps both and adds numbers',
      'trustedAuto': 'Auto-accept from trusted devices',
      'trustedAutoSub': 'Tap the star next to a device to trust it',
      'trustedDevs': 'Trusted devices',
      'timeout': 'Request timeout',

      'sharingSettings': 'Sharing Settings',
      'sharingSettingsDesc': 'Configure link sharing rules, PIN, and filters',
      'linkSharingOptions': 'Link sharing options',
      'oneTimeDownload': 'One-time download',
      'oneTimeDownloadDesc': 'Stop sharing automatically after the first successful download',
      'allowedExtensions': 'Allowed extensions filter',
      'allowedExtensionsDesc': 'All files allowed (e.g. png,jpg,pdf)',
      'askBeforeDownload': 'Ask before download',
      'askBeforeDownloadDesc': 'Approve each browser before download',
      'pin': 'PIN',
      'autoStopSharing': 'Auto-stop sharing',

      'visibleToDevices': 'Visible to other devices',
      'visibleToDevicesDesc': 'Off: others cannot find you in a scan',
      'autoScan': 'Auto scan',
      'autoScanDesc': 'Look for devices periodically',
      'scanInterval': 'Scan interval',
      'scanSpeed': 'Scan speed',
      'scanSpeedDesc': 'Faster scans find devices sooner but use more network and battery',
      'scanBalanced': 'Balanced',
      'scanFast': 'Fast',
      'scanTurbo': 'Turbo',
      'scanVirtual': 'Scan VPN and virtual networks',
      'scanVirtualDesc': 'Off: skips VPN, VM and Docker adapters, so scanning is faster',
      'bootAnim': 'Startup animation',
      'bootAnimDesc': 'Choose how long the logo animation plays when the app opens',
      'bootOff': 'Off',
      'bootQuick': 'Quick',
      'bootFull': 'Full',
      'searchSettings': 'Search settings...',
      'resetPrefs': 'Reset preferences',
      'noResults': 'No settings found',
      'statusConnected': 'connected',
      'statusOffline': 'Offline',
      'statusScanning': 'Scanning...',
      'statusServer': 'Server',
      'subLanguage': 'Choose the language of the app.',
      'subAppearance': 'Colors, text size, startup and how the app looks.',
      'subReceive': 'Where files go and who may send you files.',
      'subLink': 'Options for sharing files with a link.',
      'subNetwork': 'Visibility, scanning and port.',
      'subHistory': 'Keep or clear the list of transfers.',
      'subAbout': 'Version, changelog and reset.',
      'copied': 'Copied',
      'remoteTitle': 'Remote access',
      'subRemote': 'Send files to devices on other networks over the internet.',
      'remoteAllow': 'Allow remote access',
      'remoteAllowDesc': 'Let devices outside your Wi-Fi send you files. Forward the port on your router or use a VPN such as Tailscale',
      'remoteKey': 'Access key',
      'remoteNewKey': 'New key',
      'remoteAddress': 'Your public address',
      'remoteAddressDesc': 'Tap the magnifier to look it up (asks api.ipify.org)',
      'remoteConnect': 'Connect to a device',
      'deskTitle': 'Desk Code',
      'deskOwnCode': 'Your Desk Code',
      'deskHelp': 'Paste the Desk Code of a device on your local network. The other device must accept.',
      'deskOwnCodeError': 'Enter the other device’s code.',
      'deskNotFound': 'Device not found. Check the code and make sure both devices are on the same local network.',
      'incomingMessage': 'New message from {name}',
      'incomingFile': 'File received from {name}',
      'deskOffline': 'Turn on LocalBridge before connecting.',
      'deskDeclined': 'Connection declined or access key rejected.',
      'deskBusy': 'The other device is handling a request. Try again.',
      'deskUpdateRequired': 'Update LocalBridge on the other device to use Desk Code approval.',
      'deskIncoming': '{name} wants to connect',
      'deskApprove': 'Allow connection',
      'deskApprovalInfo': 'Allow this device to open a chat and request file transfers.',
      'deskConnected': 'Connected to {name}',
      'deviceRemove': 'Remove device',
      'chatSendFailed': 'Message could not be sent. Check the selected device’s connection.',
      'chatApprovalPending': 'Waiting for the other device to accept…',
      'muteChat': 'Mute notifications',
      'unmuteChat': 'Unmute notifications',
      'muteChatUntil': 'Muted until {time}',
      'muteMinutes': '{n} minutes',
      'muteHours': '{n} hours',
      'chatOnline': 'Online',
      'globalChatConnect': 'Connect to remote chat',
      'globalChatHelp': 'Enter IP:port (or a VPN address) and the receiving device’s access key. A Desk Code finds devices on the local network.',
      'remoteConnectDesc': 'Add a device on another network by its address',
      'remoteConnectHelp': 'Enter the public address of the other device and its access key. For VPN addresses such as Tailscale the key can stay empty.',
      'remoteAddrHint': 'Address (for example 203.0.113.5:53317)',
      'remoteKeyHint': 'Access key',
      'remoteConnectBtn': 'Connect',
      'remoteBadAddr': 'That address is not valid',
      'remoteUnreach': 'Could not reach the device. Check the address, the port forwarding and that LocalBridge is turned on there',
      'remoteDenied': 'Access denied. Wrong key, or remote access is off on that device',
      'remoteWarnTitle': 'Not encrypted',
      'remoteWarn': 'Remote transfers use plain HTTP, so the key and files can be read on the way. Use a VPN such as Tailscale for private files',
      'statusBar': 'Status bar',
      'statusBarDesc': 'Show the bar at the bottom of big windows',
      'mouseGlow': 'Light follows the mouse',
      'mouseGlowDesc': 'A soft glow under the mouse cursor',
      'glowLevel': 'Background glow',
      'use24h': '24-hour clock',
      'use24hDesc': 'Off: show times with AM and PM',
      'sortDevices': 'Sort devices',
      'sortName': 'Name',
      'sortIp': 'Address',
      'sortFound': 'Found order',
      'soundDone': 'Sound when a transfer ends',
      'soundDoneDesc': 'Play a short sound after sending or receiving',
      'confirmSend': 'Confirm before sending',
      'confirmSendDesc': 'Ask before files are sent to a device',
      'sendConfirm': 'Send to {n}?',
      'startOnline': 'Start turned on',
      'startOnlineDesc': 'Off: LocalBridge stays hidden until you press the power button',
      'confirmClear': 'Confirm before clearing history',
      'confirmClearDesc': 'Ask before the transfer list is deleted',
      'hoverFx': 'Hover effects',
      'hoverFxDesc': 'Cards grow and glow when the mouse is over them',
      'railStats': 'Side menu statistics',
      'railStatsDesc': 'Show nearby, sent and received counts in the side menu',
      'port': 'Port',

      'saveHistory': 'Save history',
      'historySize': 'History size',
      'resetSettings': 'Reset settings',
      'whatsNew': "What's new",
      'current': 'Current',
      'update': 'Update',
      'cancel': 'Cancel',
      'save': 'Save',
      'reset': 'Reset',
      'clear': 'Clear',
      'resetConfirm': 'Reset all settings?',

      'filterAll': 'All',
      'filterSent': 'Sent',
      'filterReceived': 'Received',
      'to': 'To',
      'from': 'From',
      'active': 'Active',
      'sharingNow': 'Sharing now',
      'noDevicesHint': 'Make sure $kAppName is open on the other device and both are on the same Wi-Fi.',
      'firewallHint': 'If Windows Firewall asks, allow "Private networks".',

      'disabled': 'Disabled',
      'turnOn': 'Turn on',
      'turnOff': 'Turn off',
      'offlineTitle': '$kAppName is turned off',
      'offlineHint': 'Nothing is scanned and other devices cannot see you. Tap the button at the top right to turn it back on.',
      'security': 'Security',
      'sharePage': 'Share page',
      'maxDownloads': 'Download limit',
      'maxDownloadsDesc': 'Stop sharing after this many downloads',
      'unlimited': 'Unlimited',
      'off': 'Off',
      'pinAttempts': 'PIN attempt limit',
      'pinAttemptsDesc': 'Block a browser after too many wrong PINs',
      'shareMessage': 'Message on download page',
      'shareMessageDesc': 'Optional note shown to people who open your link',
      'shareMessageHint': 'e.g. Photos from the trip',
      'showQrTitle': 'Show QR code',
      'showQrDesc': 'Display a QR code while sharing',
      'autoCopy': 'Copy link automatically',
      'autoCopyDesc': 'Copy the link to the clipboard when sharing starts',

      'quickSettings': 'Quick settings',
      'trustedOnly': 'Trusted devices only',
      'trustedOnlyDesc': 'Ignore transfer requests from devices you have not starred',
      'maxReceive': 'Incoming size limit',
      'maxReceiveDesc': 'Reject transfers bigger than this',
      'openAfter': 'Open folder after receiving',
      'openAfterDesc': 'Show the saved file when a transfer finishes',
      'sidebarNearby': 'Nearby',
      'globalConnect': 'Global Connect',
      'globalTransfer': 'Global Transfer',
      'bridgeChat': 'Bridge Chat',
      'globalConnectDesc': 'Connect to peers on other networks via Public IP, Tailscale, or ZeroTier',
      'globalTransferDesc': 'Send files directly to local & remote devices or share instant web links',
      'bridgeChatDesc': 'Instant P2P messages, links, and clipboard sync with connected devices',
      'chatPlaceholder': 'Write a message, link, or code snippet…',
      'sendClipboard': 'Send Clipboard',
      'broadcastAll': 'All Devices (Broadcast)',
      'noMessages': 'No messages yet',
      'noMessagesHint': 'Send instant P2P messages, links, or clipboard text to any connected device.',
      'selectFiles': 'Choose Files to Transfer',
      'dropZoneSub': 'Direct high-speed P2P transfer to any local or global peer',
      'savedPeers': 'Saved Global Peers',
      'noSavedPeers': 'No remote devices saved yet',
      'nodeIdentity': 'Global Node Identity',
      'clearChat': 'Clear chat',
      'globalNodeCard': 'Your Global Node Identity',
      'globalActiveBadge': 'Global Access Active — Ready for remote peers',
      'copyInviteInfo': 'Copy Connection Invite',
      'inviteCopied': 'Connection invite copied to clipboard',
      'globalConnectSub': 'Connect using Desk Code to chat and send files',
      'globalTransferSub': 'Send files directly to local & remote devices or share instant web links',
      'bridgeChatSub': 'Instant P2P messages, links, and clipboard sync with connected devices',
      'dropZoneTitle': 'Send files',
      'selectTargetPeer': 'Target Device / Channel',
      'allPeersChannel': 'All Devices (Broadcast)',
      'chatEmpty': 'No messages yet',
      'chatEmptySub': 'Send instant P2P messages, links, or clipboard text to any connected device.',
      'chatInputHint': 'Write a message, link, or code snippet…',
      'sendMsg': 'Send',
      'portForwardTitle': 'Router Port Forwarding (Direct Internet)',
      'portForwardDesc': 'Forward TCP port 53317 on your router to this device and share your public IP + Access Key.',
      'tailscaleTitle': 'Tailscale Mesh VPN (Zero-Config Encrypted)',
      'tailscaleDesc': 'Enter your peer\'s 100.x.y.z Tailscale IP address. Works across NAT & firewalls without port forwarding.',
      'zerotierTitle': 'ZeroTier Virtual LAN',
      'zerotierDesc': 'Join the same ZeroTier network ID and connect using the managed virtual IP address.',
      'remoteSaved': 'Saved Global Peers',
      'remoteNone': 'No remote devices saved yet',
    },
    AppLang.turkish: {
      'devices': 'Cihazlar',
      'history': 'Geçmiş',
      'settings': 'Ayarlar',
      'scan': 'Yeniden Tara',
      'scanning': 'Taranıyor…',
      'ready': 'Almaya hazır',
      'serverOff': 'Sunucu kapalı',
      'autoAccept': 'Otomatik kabul',
      'askFirst': 'Önce sor',
      'nearby': 'Yakındaki cihazlar',
      'noDevices': 'Cihaz bulunamadı',
      'shareViaLink': 'Bağlantı ile paylaş',
      'shareDesc': 'Wi-Fi\'daki herkes tarayıcıdan indirebilir',
      'shareBtn': 'Paylaş',
      'stopShare': 'Paylaşımı durdur',
      'copyLink': 'Bağlantıyı kopyala',
      'linkCopied': 'Bağlantı kopyalandı',
      'showQr': 'QR Kod',
      'qrTitle': 'İndirmek için Tarayın',
      'send': 'Gönder',
      'clearHistory': 'Geçmişi temizle',
      'noTransfers': 'Henüz transfer yok',
      'device': 'Cihaz',
      'deviceName': 'Cihaz adı',
      'appearance': 'Görünüm',
      'receive': 'Alma',
      'network': 'Ağ',
      'about': 'Hakkında',
      'language': 'Dil / Language',

      'amoledTitle': 'Saf siyah (AMOLED)',
      'amoledSub': 'Karanlık modda tam siyah arka plan',
      'radarTitle': 'Cihaz radarı',
      'radarSub': 'Cihazları göster ve tarama sırasında radarı hareketlendir',
      'compactTitle': 'Kompakt başlık',
      'compactSub': 'Ekrana daha çok şey sığdırmak için büyük radarı gizle',
      'ipTitle': 'IP adreslerini göster',
      'ipSub': 'Ekrandaki IP\'leri gizlemek için kapat',
      'hapticTitle': 'Titreşim geri bildirimi',
      'hapticSub': 'Aktarım bittiğinde titreş',
      'textSize': 'Metin boyutu',

      'autoAcceptTitle': 'Otomatik kabul',
      'autoAcceptSub': 'Gelen dosyaları sormadan kaydet.',
      'saveFolder': 'Kayıt klasörü',
      'openFolder': 'Kayıt klasörünü aç',
      'groupBySender': 'Gönderene göre grupla',
      'groupBySenderSub': 'Dosyaları gönderenin adıyla kaydet',
      'overwrite': 'Mevcut dosyaların üzerine yaz',
      'overwriteSub': 'Kapalı: ikisini de tutar ve numara ekler',
      'trustedAuto': 'Güvenilir cihazlardan otomatik kabul',
      'trustedAutoSub': 'Cihazlar sekmesinde yıldıza dokunarak güvenin',
      'trustedDevs': 'Güvenilir cihazlar',
      'timeout': 'İstek zaman aşımı',

      'sharingSettings': 'Paylaşım Ayarları',
      'sharingSettingsDesc': 'Bağlantı paylaşım kurallarını, PIN ve filtreleri yönet',
      'linkSharingOptions': 'Bağlantı paylaşım seçenekleri',
      'oneTimeDownload': 'Tek seferlik indirme',
      'oneTimeDownloadDesc': 'İlk başarılı indirmeden sonra paylaşımı otomatik durdur',
      'allowedExtensions': 'İzin verilen uzantı filtresi',
      'allowedExtensionsDesc': 'Tüm dosyalar serbest (örn. png,jpg,pdf)',
      'askBeforeDownload': 'İndirmeden önce sor',
      'askBeforeDownloadDesc': 'Tarayıcıların dosyalarınızı görmesini onaylayın',
      'pin': 'PIN',
      'autoStopSharing': 'Paylaşımı otomatik durdur',

      'visibleToDevices': 'Diğer cihazlarca görülebilir',
      'visibleToDevicesDesc': 'Kapalı: başkaları sizi aramada göremez',
      'autoScan': 'Otomatik tarama',
      'autoScanDesc': 'Periyodik olarak cihazları ara',
      'scanInterval': 'Tarama aralığı',
      'scanSpeed': 'Tarama hızı',
      'scanSpeedDesc': 'Daha hızlı tarama cihazları daha çabuk bulur ama daha fazla ağ ve pil kullanır',
      'scanBalanced': 'Dengeli',
      'scanFast': 'Hızlı',
      'scanTurbo': 'Turbo',
      'scanVirtual': 'VPN ve sanal ağları tara',
      'scanVirtualDesc': 'Kapalı: VPN, sanal makine ve Docker adaptörleri atlanır, tarama daha hızlı olur',
      'bootAnim': 'Açılış animasyonu',
      'bootAnimDesc': 'Uygulama açılırken logo animasyonunun ne kadar süreceğini seç',
      'bootOff': 'Kapalı',
      'bootQuick': 'Kısa',
      'bootFull': 'Uzun',
      'searchSettings': 'Ayarlarda ara...',
      'resetPrefs': 'Ayarları sıfırla',
      'noResults': 'Ayar bulunamadı',
      'statusConnected': 'bağlı',
      'statusOffline': 'Kapalı',
      'statusScanning': 'Taranıyor...',
      'statusServer': 'Sunucu',
      'subLanguage': 'Uygulamanın dilini seç.',
      'subAppearance': 'Renkler, yazı boyutu, açılış ve uygulamanın görünümü.',
      'subReceive': 'Dosyaların nereye gideceği ve kimlerin dosya gönderebileceği.',
      'subLink': 'Dosyaları bağlantı ile paylaşma seçenekleri.',
      'subNetwork': 'Görünürlük, tarama ve port.',
      'subHistory': 'Aktarım listesini sakla veya temizle.',
      'subAbout': 'Sürüm, değişiklik günlüğü ve sıfırlama.',
      'copied': 'Kopyalandı',
      'remoteTitle': 'Uzaktan erişim',
      'subRemote': 'Başka ağlardaki cihazlara internet üzerinden dosya gönder.',
      'remoteAllow': 'Uzaktan erişime izin ver',
      'remoteAllowDesc': 'Wi-Fi ağın dışındaki cihazların sana dosya göndermesine izin verir. Router\'da portu yönlendir ya da Tailscale gibi bir VPN kullan',
      'remoteKey': 'Erişim anahtarı',
      'remoteNewKey': 'Yeni anahtar',
      'remoteAddress': 'Genel adresin',
      'remoteAddressDesc': 'Bulmak için büyüteç simgesine dokun (api.ipify.org\'a sorar)',
      'remoteConnect': 'Cihaza bağlan',
      'deskTitle': 'Desk Code',
      'deskOwnCode': 'Senin Desk Code’un',
      'deskHelp': 'Aynı yerel ağdaki cihazın Desk Code’unu yapıştır. Karşı cihaz isteği onaylamalı.',
      'deskOwnCodeError': 'Karşı cihazın kodunu gir.',
      'deskNotFound': 'Cihaz bulunamadı. Kodu ve iki cihazın da aynı yerel ağda olduğunu kontrol et.',
      'incomingMessage': '{name} cihazından yeni mesaj',
      'incomingFile': '{name} cihazından dosya geldi',
      'deskOffline': 'Bağlanmak için LocalBridge’i aç.',
      'deskDeclined': 'Bağlantı reddedildi veya erişim anahtarı geçersiz.',
      'deskBusy': 'Karşı cihaz başka bir isteği işliyor. Tekrar dene.',
      'deskUpdateRequired': 'Desk Code onayı için karşı cihazdaki LocalBridge’i güncelle.',
      'deskIncoming': '{name} bağlanmak istiyor',
      'deskApprove': 'Bağlantıya izin ver',
      'deskApprovalInfo': 'Bu cihaz sohbet başlatabilir ve dosya gönderme isteği iletebilir.',
      'deskConnected': '{name} cihazına bağlanıldı',
      'deviceRemove': 'Cihazı kaldır',
      'chatSendFailed': 'Mesaj gönderilemedi. Seçili cihazın bağlantısını kontrol et.',
      'chatApprovalPending': 'Karşı cihazın onayı bekleniyor…',
      'muteChat': 'Bildirimleri sustur',
      'unmuteChat': 'Bildirimlerin sesini aç',
      'muteChatUntil': '{time} saatine kadar sessizde',
      'muteMinutes': '{n} dakika',
      'muteHours': '{n} saat',
      'chatOnline': 'Çevrimiçi',
      'globalChatConnect': 'Uzak sohbete bağlan',
      'globalChatHelp': 'IP:port veya VPN adresini ve karşı cihazın erişim anahtarını gir. Desk Code yerel ağdaki cihazları bulur.',
      'remoteConnectDesc': 'Başka ağdaki bir cihazı adresiyle ekle',
      'remoteConnectHelp': 'Diğer cihazın genel adresini ve erişim anahtarını gir. Tailscale gibi VPN adreslerinde anahtar boş kalabilir.',
      'remoteAddrHint': 'Adres (örnek 203.0.113.5:53317)',
      'remoteKeyHint': 'Erişim anahtarı',
      'remoteConnectBtn': 'Bağlan',
      'remoteBadAddr': 'Bu adres geçerli değil',
      'remoteUnreach': 'Cihaza ulaşılamadı. Adresi, port yönlendirmeyi ve orada LocalBridge\'in açık olduğunu kontrol et',
      'remoteDenied': 'Erişim reddedildi. Anahtar yanlış ya da o cihazda uzaktan erişim kapalı',
      'remoteWarnTitle': 'Şifreli değil',
      'remoteWarn': 'Uzak aktarımlar düz HTTP kullanır, anahtar ve dosyalar yolda okunabilir. Özel dosyalar için Tailscale gibi bir VPN kullan',
      'statusBar': 'Durum çubuğu',
      'statusBarDesc': 'Büyük pencerelerde alttaki çubuğu göster',
      'mouseGlow': 'Işık fareyi takip etsin',
      'mouseGlowDesc': 'Fare imlecinin altında yumuşak bir parlama',
      'glowLevel': 'Arka plan parlaması',
      'use24h': '24 saat biçimi',
      'use24hDesc': 'Kapalı: saatler ÖÖ/ÖS ile gösterilir',
      'sortDevices': 'Cihazları sırala',
      'sortName': 'İsim',
      'sortIp': 'Adres',
      'sortFound': 'Bulunma sırası',
      'soundDone': 'Aktarım bitince ses çal',
      'soundDoneDesc': 'Gönderme veya alma sonrası kısa bir ses çalar',
      'confirmSend': 'Göndermeden önce onayla',
      'confirmSendDesc': 'Dosyalar bir cihaza gönderilmeden önce sorar',
      'sendConfirm': '{n} cihazına gönderilsin mi?',
      'startOnline': 'Açık başlat',
      'startOnlineDesc': 'Kapalı: güç düğmesine basana kadar LocalBridge gizli kalır',
      'confirmClear': 'Geçmişi silmeden önce onayla',
      'confirmClearDesc': 'Aktarım listesi silinmeden önce sorar',
      'hoverFx': 'Üzerine gelme efektleri',
      'hoverFxDesc': 'Fare üzerine gelince kartlar büyür ve parlar',
      'railStats': 'Yan menü istatistikleri',
      'railStatsDesc': 'Yan menüde yakındaki, gönderilen ve alınan sayılarını göster',
      'port': 'Port',

      'saveHistory': 'Geçmişi kaydet',
      'historySize': 'Geçmiş boyutu',
      'resetSettings': 'Ayarları sıfırla',
      'whatsNew': 'Yenilikler neler?',
      'current': 'Mevcut',
      'update': 'Güncelleme',
      'cancel': 'İptal',
      'save': 'Kaydet',
      'reset': 'Sıfırla',
      'clear': 'Temizle',
      'resetConfirm': 'Tüm ayarlar sıfırlansın mı?',

      'filterAll': 'Tümü',
      'filterSent': 'Gönderilen',
      'filterReceived': 'Alınan',
      'to': 'Alıcı',
      'from': 'Gönderen',
      'active': 'Aktif',
      'sharingNow': 'Şu an paylaşılıyor',
      'noDevicesHint': '$kAppName uygulamasının diğer cihazda açık ve ikisinin de aynı Wi-Fi\'da olduğundan emin ol.',
      'firewallHint': 'Windows Güvenlik Duvarı sorarsa "Özel ağlar"a izin ver.',

      'disabled': 'Devre dışı',
      'turnOn': 'Aç',
      'turnOff': 'Kapat',
      'offlineTitle': '$kAppName kapalı',
      'offlineHint': 'Tarama yapılmıyor ve diğer cihazlar seni göremez. Yeniden açmak için sağ üstteki düğmeye dokun.',
      'security': 'Güvenlik',
      'sharePage': 'Paylaşım sayfası',
      'maxDownloads': 'İndirme limiti',
      'maxDownloadsDesc': 'Bu kadar indirmeden sonra paylaşımı durdur',
      'unlimited': 'Sınırsız',
      'off': 'Kapalı',
      'pinAttempts': 'PIN deneme sınırı',
      'pinAttemptsDesc': 'Çok fazla yanlış PIN girince tarayıcıyı engelle',
      'shareMessage': 'İndirme sayfası mesajı',
      'shareMessageDesc': 'Bağlantıyı açanlara gösterilen isteğe bağlı not',
      'shareMessageHint': 'örn. Tatil fotoğrafları',
      'showQrTitle': 'QR kodu göster',
      'showQrDesc': 'Paylaşım sırasında QR kod göster',
      'autoCopy': 'Bağlantıyı otomatik kopyala',
      'autoCopyDesc': 'Paylaşım başlayınca bağlantıyı panoya kopyala',

      'quickSettings': 'Hızlı ayarlar',
      'trustedOnly': 'Yalnızca güvenilir cihazlar',
      'trustedOnlyDesc': 'Yıldızlamadığın cihazların gönderme isteklerini yok say',
      'maxReceive': 'Gelen dosya boyutu sınırı',
      'maxReceiveDesc': 'Bundan büyük aktarımları reddet',
      'openAfter': 'Aldıktan sonra klasörü aç',
      'openAfterDesc': 'Aktarım bitince kaydedilen dosyayı göster',
      'sidebarNearby': 'Yakında',
      'globalConnect': 'Global Connect',
      'globalTransfer': 'Global Transfer',
      'bridgeChat': 'Bridge Chat',
      'globalConnectDesc': 'Genel IP, Tailscale veya ZeroTier üzerinden başka ağlardaki cihazlara bağlan',
      'globalTransferDesc': 'Yerel ve küresel cihazlara doğrudan dosya gönder veya anında web bağlantısı paylaş',
      'bridgeChatDesc': 'Bağlı cihazlarla anlık P2P mesajlaşma, bağlantı ve pano senkronizasyonu',
      'chatPlaceholder': 'Bir mesaj, bağlantı veya kod parçası yaz…',
      'sendClipboard': 'Panoyu Gönder',
      'broadcastAll': 'Tüm Cihazlar (Yayın)',
      'noMessages': 'Henüz mesaj yok',
      'noMessagesHint': 'Bağlı herhangi bir cihaza anında P2P mesaj, bağlantı veya pano metni gönder.',
      'selectFiles': 'Aktarılacak Dosyaları Seç',
      'dropZoneSub': 'Yerel veya küresel herhangi bir cihaza tam hızda doğrudan P2P aktarım',
      'savedPeers': 'Kayıtlı Küresel Cihazlar',
      'noSavedPeers': 'Henüz kayıtlı uzak cihaz yok',
      'nodeIdentity': 'Küresel Düğüm Kimliği',
      'clearChat': 'Sohbeti temizle',
      'globalNodeCard': 'Küresel Düğüm Kimliğin',
      'globalActiveBadge': 'Uzaktan Erişim Aktif — Küresel bağlantılara hazır',
      'copyInviteInfo': 'Bağlantı Davetini Kopyala',
      'inviteCopied': 'Bağlantı daveti panoya kopyalandı',
      'globalConnectSub': 'Desk Code ile bağlan, mesaj ve dosya gönder',
      'globalTransferSub': 'Yerel ve küresel cihazlara doğrudan dosya gönder veya anında web bağlantısı paylaş',
      'bridgeChatSub': 'Bağlı cihazlarla anlık P2P mesajlaşma, bağlantı ve pano senkronizasyonu',
      'dropZoneTitle': 'Yüksek Hızlı P2P Aktarım Merkezi',
      'selectTargetPeer': 'Hedef Cihaz / Kanal',
      'allPeersChannel': 'Tüm Cihazlar (Yayın)',
      'chatEmpty': 'Henüz mesaj yok',
      'chatEmptySub': 'Bağlı herhangi bir cihaza anında P2P mesaj, bağlantı veya pano metni gönder.',
      'chatInputHint': 'Bir mesaj, bağlantı veya kod parçası yaz…',
      'sendMsg': 'Gönder',
      'portForwardTitle': 'Router Port Yönlendirme (Doğrudan İnternet)',
      'portForwardDesc': 'Modeminizden 53317 TCP portunu bu cihaza yönlendirin ve Genel IP + Erişim Anahtarınızı paylaşın.',
      'tailscaleTitle': 'Tailscale Mesh VPN (Şifreli & Ayarsız)',
      'tailscaleDesc': 'Karşı cihazın 100.x.y.z Tailscale IP adresini girin. Port açmadan tüm güvenlik duvarlarını aşar.',
      'zerotierTitle': 'ZeroTier Sanal LAN',
      'zerotierDesc': 'Aynı ZeroTier ağına katılın ve atanan sanal IP adresiyle doğrudan bağlanın.',
      'remoteSaved': 'Kayıtlı Küresel Cihazlar',
      'remoteNone': 'Henüz kayıtlı uzak cihaz yok',
    },
    AppLang.russian: {
      'devices': 'Устройства',
      'history': 'История',
      'settings': 'Настройки',
      'scan': 'Сканировать',
      'scanning': 'Сканирование…',
      'ready': 'Готов к приему',
      'serverOff': 'Сервер выключен',
      'autoAccept': 'Автоприем',
      'askFirst': 'Спрашивать',
      'nearby': 'Устройства поблизости',
      'noDevices': 'Устройства не найдены',
      'shareViaLink': 'Поделиться ссылкой',
      'shareDesc': 'Любой в вашей Wi-Fi сети может скачать через браузер',
      'shareBtn': 'Поделиться',
      'stopShare': 'Остановить обмен',
      'copyLink': 'Копировать ссылку',
      'linkCopied': 'Ссылка скопирована',
      'showQr': 'QR-код',
      'qrTitle': 'Сканируйте для скачивания',
      'send': 'Отправить',
      'clearHistory': 'Очистить историю',
      'noTransfers': 'Нет переводов',
      'device': 'Устройство',
      'deviceName': 'Имя устройства',
      'appearance': 'Внешний вид',
      'receive': 'Получение',
      'network': 'Сеть',
      'about': 'О программе',
      'language': 'Язык',

      'amoledTitle': 'Чистый черный (AMOLED)',
      'amoledSub': 'Истинно черный фон в темном режиме',
      'radarTitle': 'Радар устройств',
      'radarSub': 'Показывать устройства и анимировать поиск',
      'compactTitle': 'Компактный заголовок',
      'compactSub': 'Скрыть большой радар',
      'ipTitle': 'Показывать IP-адреса',
      'ipSub': 'Отключите, чтобы скрыть IP',
      'hapticTitle': 'Виброотклик',
      'hapticSub': 'Вибрация по завершении передачи',
      'textSize': 'Размер текста',

      'autoAcceptTitle': 'Автоприем',
      'autoAcceptSub': 'Сохранять входящие файлы без вопросов.',
      'saveFolder': 'Папка сохранения',
      'openFolder': 'Открыть папку сохранения',
      'groupBySender': 'Группировать по отправителю',
      'groupBySenderSub': 'Сохранять файлы в папку отправителя',
      'overwrite': 'Перезаписывать существующие',
      'overwriteSub': 'Выкл: сохраняет оба файла',
      'trustedAuto': 'Автоприем от доверенных устройств',
      'trustedAutoSub': 'Нажмите звездочку рядом с устройством',
      'trustedDevs': 'Доверенные устройства',
      'timeout': 'Тайм-аут запроса',

      'sharingSettings': 'Настройки общего доступа',
      'sharingSettingsDesc': 'Управление правилами ссылок, PIN и фильтрами',
      'linkSharingOptions': 'Параметры ссылок',
      'oneTimeDownload': 'Одноразовая загрузка',
      'oneTimeDownloadDesc': 'Остановить обмен после первой загрузки',
      'allowedExtensions': 'Фильтр расширений',
      'allowedExtensionsDesc': 'Разрешены все файлы',
      'askBeforeDownload': 'Спрашивать перед скачиванием',
      'askBeforeDownloadDesc': 'Подтверждать доступ для браузера',
      'pin': 'PIN-код',
      'autoStopSharing': 'Авто-остановка',

      'visibleToDevices': 'Видим для других',
      'visibleToDevicesDesc': 'Выкл: вас не найдут в поиске',
      'autoScan': 'Автосканирование',
      'autoScanDesc': 'Искать устройства периодически',
      'scanInterval': 'Интервал сканирования',
      'scanSpeed': 'Скорость сканирования',
      'scanSpeedDesc': 'Быстрое сканирование находит устройства раньше, но использует больше сети и батареи',
      'scanBalanced': 'Сбалансированная',
      'scanFast': 'Быстрая',
      'scanTurbo': 'Турбо',
      'scanVirtual': 'Сканировать VPN и виртуальные сети',
      'scanVirtualDesc': 'Выкл: адаптеры VPN, виртуальных машин и Docker пропускаются, сканирование быстрее',
      'bootAnim': 'Анимация запуска',
      'bootAnimDesc': 'Выберите, как долго играет анимация логотипа при запуске',
      'bootOff': 'Выкл',
      'bootQuick': 'Короткая',
      'bootFull': 'Полная',
      'searchSettings': 'Поиск настроек...',
      'resetPrefs': 'Сбросить настройки',
      'noResults': 'Настройки не найдены',
      'statusConnected': 'подключено',
      'statusOffline': 'Выключено',
      'statusScanning': 'Сканирование...',
      'statusServer': 'Сервер',
      'subLanguage': 'Выберите язык приложения.',
      'subAppearance': 'Цвета, размер текста, запуск и внешний вид.',
      'subReceive': 'Куда сохраняются файлы и кто может их отправлять.',
      'subLink': 'Параметры раздачи файлов по ссылке.',
      'subNetwork': 'Видимость, сканирование и порт.',
      'subHistory': 'Хранить или очистить список передач.',
      'subAbout': 'Версия, список изменений и сброс.',
      'copied': 'Скопировано',
      'remoteTitle': 'Удалённый доступ',
      'subRemote': 'Отправка файлов на устройства в других сетях через интернет.',
      'remoteAllow': 'Разрешить удалённый доступ',
      'remoteAllowDesc': 'Позволяет устройствам вне вашей Wi-Fi сети отправлять вам файлы. Пробросьте порт на роутере или используйте VPN, например Tailscale',
      'remoteKey': 'Ключ доступа',
      'remoteNewKey': 'Новый ключ',
      'remoteAddress': 'Ваш публичный адрес',
      'remoteAddressDesc': 'Нажмите на лупу, чтобы узнать (запрос к api.ipify.org)',
      'remoteConnect': 'Подключиться к устройству',
      'deskTitle': 'Desk Code',
      'deskOwnCode': 'Ваш Desk Code',
      'deskHelp': 'Вставьте Desk Code устройства в локальной сети. Второе устройство должно принять запрос.',
      'deskOwnCodeError': 'Введите код другого устройства.',
      'deskNotFound': 'Устройство не найдено. Проверьте код и убедитесь, что оба устройства в одной локальной сети.',
      'incomingMessage': 'Новое сообщение от {name}',
      'incomingFile': 'Получен файл от {name}',
      'deskOffline': 'Включите LocalBridge перед подключением.',
      'deskDeclined': 'Подключение отклонено или ключ доступа неверен.',
      'deskBusy': 'Устройство обрабатывает другой запрос. Попробуйте снова.',
      'deskUpdateRequired': 'Обновите LocalBridge на другом устройстве для подтверждения по Desk Code.',
      'deskIncoming': '{name} запрашивает подключение',
      'deskApprove': 'Разрешить подключение',
      'deskApprovalInfo': 'Устройство сможет открыть чат и запросить передачу файлов.',
      'deskConnected': 'Подключено к {name}',
      'deviceRemove': 'Удалить устройство',
      'chatSendFailed': 'Не удалось отправить сообщение. Проверьте подключение выбранного устройства.',
      'chatApprovalPending': 'Ожидание подтверждения на другом устройстве…',
      'chatOnline': 'В сети',
      'globalChatConnect': 'Подключиться к удалённому чату',
      'globalChatHelp': 'Введите IP:порт или VPN-адрес и ключ доступа второго устройства. Desk Code находит устройства в локальной сети.',
      'muteChat': 'Отключить уведомления',
      'unmuteChat': 'Включить уведомления',
      'muteChatUntil': 'Без уведомлений до {time}',
      'muteMinutes': '{n} мин',
      'muteHours': '{n} ч',
      'remoteConnectDesc': 'Добавить устройство в другой сети по адресу',
      'remoteConnectHelp': 'Введите публичный адрес другого устройства и его ключ доступа. Для VPN-адресов, например Tailscale, ключ можно не вводить.',
      'remoteAddrHint': 'Адрес (например 203.0.113.5:53317)',
      'remoteKeyHint': 'Ключ доступа',
      'remoteConnectBtn': 'Подключиться',
      'remoteBadAddr': 'Неверный адрес',
      'remoteUnreach': 'Не удалось связаться с устройством. Проверьте адрес, проброс порта и что LocalBridge там включён',
      'remoteDenied': 'Доступ запрещён. Неверный ключ или удалённый доступ выключен на том устройстве',
      'remoteWarnTitle': 'Без шифрования',
      'remoteWarn': 'Удалённые передачи идут по обычному HTTP, ключ и файлы могут быть прочитаны по пути. Для личных файлов используйте VPN, например Tailscale',
      'statusBar': 'Строка состояния',
      'statusBarDesc': 'Показывать полосу внизу больших окон',
      'mouseGlow': 'Свет следует за мышью',
      'mouseGlowDesc': 'Мягкое свечение под курсором мыши',
      'glowLevel': 'Свечение фона',
      'use24h': '24-часовой формат',
      'use24hDesc': 'Выкл: время с AM и PM',
      'sortDevices': 'Сортировка устройств',
      'sortName': 'Имя',
      'sortIp': 'Адрес',
      'sortFound': 'Порядок обнаружения',
      'soundDone': 'Звук по окончании передачи',
      'soundDoneDesc': 'Короткий звук после отправки или получения',
      'confirmSend': 'Подтверждать отправку',
      'confirmSendDesc': 'Спрашивать перед отправкой файлов на устройство',
      'sendConfirm': 'Отправить на {n}?',
      'startOnline': 'Запускать включённым',
      'startOnlineDesc': 'Выкл: LocalBridge скрыт, пока вы не нажмёте кнопку питания',
      'confirmClear': 'Подтверждать очистку истории',
      'confirmClearDesc': 'Спрашивать перед удалением списка передач',
      'hoverFx': 'Эффекты наведения',
      'hoverFxDesc': 'Карточки увеличиваются и светятся под мышью',
      'railStats': 'Статистика в боковом меню',
      'railStatsDesc': 'Показывать число найденных, отправленных и полученных в боковом меню',
      'port': 'Порт',

      'saveHistory': 'Сохранять историю',
      'historySize': 'Размер истории',
      'resetSettings': 'Сбросить настройки',
      'whatsNew': 'Что нового',
      'current': 'Текущая',
      'update': 'Обновление',
      'cancel': 'Отмена',
      'save': 'Сохранить',
      'reset': 'Сбросить',
      'clear': 'Очистить',
      'resetConfirm': 'Сбросить все настройки?',

      'filterAll': 'Все',
      'filterSent': 'Отправленные',
      'filterReceived': 'Полученные',
      'to': 'Кому',
      'from': 'От',
      'active': 'Активен',
      'sharingNow': 'Идёт раздача',
      'noDevicesHint': 'Убедитесь, что $kAppName открыт на другом устройстве и оба подключены к одной Wi-Fi сети.',
      'firewallHint': 'Если брандмауэр Windows спросит, разрешите «Частные сети».',

      'disabled': 'Отключено',
      'turnOn': 'Включить',
      'turnOff': 'Выключить',
      'offlineTitle': '$kAppName выключен',
      'offlineHint': 'Сканирование остановлено, другие устройства вас не видят. Чтобы включить снова, нажмите кнопку справа вверху.',
      'security': 'Безопасность',
      'sharePage': 'Страница раздачи',
      'maxDownloads': 'Лимит загрузок',
      'maxDownloadsDesc': 'Остановить обмен после указанного числа загрузок',
      'unlimited': 'Без лимита',
      'off': 'Выкл',
      'pinAttempts': 'Лимит попыток PIN',
      'pinAttemptsDesc': 'Блокировать браузер после нескольких неверных PIN',
      'shareMessage': 'Сообщение на странице загрузки',
      'shareMessageDesc': 'Необязательная заметка для открывших ссылку',
      'shareMessageHint': 'например, Фото из поездки',
      'showQrTitle': 'Показывать QR-код',
      'showQrDesc': 'Показывать QR-код во время раздачи',
      'autoCopy': 'Копировать ссылку автоматически',
      'autoCopyDesc': 'Копировать ссылку в буфер обмена при начале раздачи',

      'quickSettings': 'Быстрые настройки',
      'trustedOnly': 'Только доверенные устройства',
      'trustedOnlyDesc': 'Игнорировать запросы от устройств без звёздочки',
      'maxReceive': 'Лимит размера входящих',
      'maxReceiveDesc': 'Отклонять передачи больше этого размера',
      'openAfter': 'Открывать папку после получения',
      'openAfterDesc': 'Показывать сохранённый файл по завершении передачи',
      'sidebarNearby': 'Рядом',
      'globalConnect': 'Global Connect',
      'globalTransfer': 'Global Transfer',
      'bridgeChat': 'Bridge Chat',
      'globalConnectDesc': 'Подключение к устройствам в других сетях через публичный IP, Tailscale или ZeroTier',
      'globalTransferDesc': 'Прямая отправка файлов на локальные и удалённые устройства или раздача по ссылке',
      'bridgeChatDesc': 'Мгновенный P2P-чат, обмен ссылками и буфером с подключёнными устройствами',
      'chatPlaceholder': 'Введите сообщение, ссылку или код…',
      'sendClipboard': 'Отправить буфер',
      'broadcastAll': 'Все устройства (Эфир)',
      'noMessages': 'Сообщений пока нет',
      'noMessagesHint': 'Отправляйте мгновенные P2P-сообщения, ссылки или текст из буфера.',
      'selectFiles': 'Выбрать файлы для отправки',
      'dropZoneSub': 'Прямая высокоскоростная P2P-передача на любое устройство',
      'savedPeers': 'Сохранённые удалённые устройства',
      'noSavedPeers': 'Удалённых устройств пока нет',
      'nodeIdentity': 'Глобальный идентификатор узла',
      'clearChat': 'Очистить чат',
      'globalNodeCard': 'Ваш глобальный узел',
      'globalActiveBadge': 'Удалённый доступ активен',
      'copyInviteInfo': 'Скопировать приглашение',
      'inviteCopied': 'Приглашение скопировано в буфер обмена',
      'globalConnectSub': 'Подключайтесь по Desk Code, отправляйте сообщения и файлы',
      'globalTransferSub': 'Прямая отправка файлов на локальные и удалённые устройства или раздача по ссылке',
      'bridgeChatSub': 'Мгновенный P2P-чат, обмен ссылками и буфером с подключёнными устройствами',
      'dropZoneTitle': 'Центр высокоскоростной P2P-передачи',
      'selectTargetPeer': 'Целевое устройство / Канал',
      'allPeersChannel': 'Все устройства (Эфир)',
      'chatEmpty': 'Сообщений пока нет',
      'chatEmptySub': 'Отправляйте мгновенные P2P-сообщения, ссылки или текст из буфера.',
      'chatInputHint': 'Введите сообщение, ссылку или код…',
      'sendMsg': 'Отправить',
      'portForwardTitle': 'Проброс портов роутера (Прямой Интернет)',
      'portForwardDesc': 'Пробросьте TCP-порт 53317 на роутере и передайте публичный IP и ключ доступа.',
      'tailscaleTitle': 'Tailscale Mesh VPN (Зашифровано)',
      'tailscaleDesc': 'Введите IP-адрес Tailscale (100.x.y.z) без необходимости проброса портов.',
      'zerotierTitle': 'Виртуальная сеть ZeroTier',
      'zerotierDesc': 'Подключитесь к одной сети ZeroTier и используйте виртуальный IP-адрес.',
      'remoteSaved': 'Сохранённые удалённые устройства',
      'remoteNone': 'Удалённых устройств пока нет',
    },
    AppLang.german: {
      'devices': 'Geräte',
      'history': 'Verlauf',
      'settings': 'Einstellungen',
      'language': 'Sprache',
      'appearance': 'Darstellung',
      'about': 'Über LocalBridge',
      'network': 'Netzwerk',
      'device': 'Gerät',
      'deviceName': 'Gerätename',
      'receive': 'Empfangen',
      'scan': 'Erneut suchen',
      'scanning': 'Suche läuft…',
      'ready': 'Empfangsbereit',
      'serverOff': 'Server aus',
      'statusOffline': 'Offline',
      'statusConnected': 'verbunden',
      'disabled': 'Deaktiviert',
      'turnOn': 'Einschalten',
      'turnOff': 'Ausschalten',
      'askFirst': 'Vorher fragen',
      'autoAccept': 'Automatisch annehmen',
      'nearby': 'Geräte in der Nähe',
      'noDevices': 'Keine Geräte gefunden',
      'noDevicesHint': 'Öffne LocalBridge auf beiden Geräten und verbinde sie mit demselben lokalen Netz.',
      'firewallHint': 'Erlaube LocalBridge für private Netzwerke, wenn Windows danach fragt.',
      'offlineTitle': 'LocalBridge ist offline',
      'offlineHint': 'Aktiviere LocalBridge, um Geräte zu finden und Dateien zu übertragen.',
      'send': 'Senden',
      'cancel': 'Abbrechen',
      'copied': 'Kopiert',
      'copyLink': 'Link kopieren',
      'deviceRemove': 'Gerät entfernen',
      'globalConnect': 'Verbinden',
      'globalConnectSub': 'Mit Desk Code verbinden und Nachrichten oder Dateien senden',
      'globalTransfer': 'Dateiübertragung',
      'globalTransferSub': 'Dateien direkt versenden oder per Link teilen',
      'bridgeChat': 'Bridge-Chat',
      'bridgeChatSub': 'Nachrichten und Links an verbundene Geräte senden',
      'deskTitle': 'Desk Code',
      'deskOwnCode': 'Dein Desk Code',
      'deskHelp': 'Füge den Desk Code eines Geräts im lokalen Netz ein. Das andere Gerät muss zustimmen.',
      'deskOwnCodeError': 'Gib den Code des anderen Geräts ein.',
      'deskNotFound': 'Gerät nicht gefunden. Prüfe den Code und das lokale Netz.',
      'deskOffline': 'Schalte LocalBridge ein, um dich zu verbinden.',
      'deskDeclined': 'Verbindung abgelehnt oder Zugangsschlüssel ungültig.',
      'deskBusy': 'Das andere Gerät bearbeitet bereits eine Anfrage.',
      'deskUpdateRequired': 'Aktualisiere LocalBridge auf dem anderen Gerät.',
      'deskIncoming': '{name} möchte sich verbinden',
      'deskApprove': 'Verbindung zulassen',
      'deskApprovalInfo': 'Dieses Gerät darf chatten und Dateiübertragungen anfragen.',
      'deskConnected': 'Mit {name} verbunden',
      'remoteConnectBtn': 'Verbinden',
      'remoteConnect': 'Gerät verbinden',
      'remoteBadAddr': 'Ungültiger Code oder ungültige Adresse.',
      'remoteUnreach': 'Das Gerät ist nicht erreichbar.',
      'remoteTitle': 'Fernzugriff',
      'remoteSaved': 'Gespeicherte Geräte',
      'remoteNone': 'Keine Geräte gespeichert',
      'shareViaLink': 'Per Link teilen',
      'shareDesc': 'Dateien im lokalen Netz im Browser herunterladen',
      'shareBtn': 'Teilen',
      'stopShare': 'Freigabe beenden',
      'linkCopied': 'Link kopiert',
      'showQr': 'QR-Code',
      'selectFiles': 'Dateien auswählen',
      'selectTargetPeer': 'Ziel auswählen',
      'dropZoneTitle': 'Dateien senden',
      'dropZoneSub': 'Dateien direkt an ein Gerät übertragen',
      'allPeersChannel': 'Alle Geräte',
      'broadcastAll': 'Alle Geräte',
      'chatEmpty': 'Keine Nachrichten',
      'chatEmptySub': 'Sende Nachrichten, Links oder Text an ein verbundenes Gerät.',
      'chatInputHint': 'Nachricht schreiben…',
      'sendMsg': 'Senden',
      'sendClipboard': 'Zwischenablage senden',
      'clearChat': 'Chat leeren',
      'chatSendFailed': 'Nachricht konnte nicht gesendet werden.',
      'chatApprovalPending': 'Warte auf die Bestätigung des anderen Geräts…',
      'chatOnline': 'Online',
      'globalChatConnect': 'Mit entferntem Chat verbinden',
      'globalChatHelp': 'IP:Port oder VPN-Adresse und den Zugangsschlüssel des Zielgeräts eingeben. Desk Code findet Geräte im lokalen Netzwerk.',
      'muteChat': 'Benachrichtigungen stummschalten',
      'unmuteChat': 'Benachrichtigungen einschalten',
      'muteChatUntil': 'Stumm bis {time}',
      'muteMinutes': '{n} Minuten',
      'muteHours': '{n} Stunden',
      'incomingMessage': 'Neue Nachricht von {name}',
      'incomingFile': 'Datei von {name} empfangen',
      'filterSent': 'Gesendet',
      'filterReceived': 'Empfangen',
      'clearHistory': 'Verlauf löschen',
      'noTransfers': 'Noch keine Übertragungen',
      'whatsNew': 'Neuigkeiten',
      'radarTitle': 'Geräteradar',
      'radarSub': 'Geräte anzeigen und die Suche animieren',
    },
    AppLang.spanish: {
      'devices': 'Dispositivos',
      'history': 'Historial',
      'settings': 'Ajustes',
      'language': 'Idioma',
      'appearance': 'Apariencia',
      'about': 'Acerca de LocalBridge',
      'network': 'Red',
      'device': 'Dispositivo',
      'deviceName': 'Nombre del dispositivo',
      'receive': 'Recepción',
      'scan': 'Volver a buscar',
      'scanning': 'Buscando…',
      'ready': 'Listo para recibir',
      'serverOff': 'Servidor apagado',
      'statusOffline': 'Sin conexión',
      'statusConnected': 'conectados',
      'disabled': 'Desactivado',
      'turnOn': 'Activar',
      'turnOff': 'Desactivar',
      'askFirst': 'Preguntar antes',
      'autoAccept': 'Aceptar automáticamente',
      'nearby': 'Dispositivos cercanos',
      'noDevices': 'No se encontraron dispositivos',
      'noDevicesHint': 'Abre LocalBridge en ambos dispositivos y conéctalos a la misma red local.',
      'firewallHint': 'Si Windows lo solicita, permite LocalBridge en redes privadas.',
      'offlineTitle': 'LocalBridge está sin conexión',
      'offlineHint': 'Activa LocalBridge para buscar dispositivos y transferir archivos.',
      'send': 'Enviar',
      'cancel': 'Cancelar',
      'copied': 'Copiado',
      'copyLink': 'Copiar enlace',
      'deviceRemove': 'Quitar dispositivo',
      'globalConnect': 'Conexión',
      'globalConnectSub': 'Conéctate con un Desk Code para enviar mensajes y archivos',
      'globalTransfer': 'Transferencia',
      'globalTransferSub': 'Envía archivos directamente o compártelos por enlace',
      'bridgeChat': 'Chat de Bridge',
      'bridgeChatSub': 'Envía mensajes y enlaces a dispositivos conectados',
      'deskTitle': 'Desk Code',
      'deskOwnCode': 'Tu Desk Code',
      'deskHelp': 'Pega el Desk Code de un dispositivo de tu red local. El otro dispositivo debe aceptar.',
      'deskOwnCodeError': 'Introduce el código del otro dispositivo.',
      'deskNotFound': 'No se encontró el dispositivo. Comprueba el código y la red local.',
      'deskOffline': 'Activa LocalBridge para conectarte.',
      'deskDeclined': 'Conexión rechazada o clave de acceso incorrecta.',
      'deskBusy': 'El otro dispositivo está atendiendo una solicitud.',
      'deskUpdateRequired': 'Actualiza LocalBridge en el otro dispositivo.',
      'deskIncoming': '{name} quiere conectarse',
      'deskApprove': 'Permitir conexión',
      'deskApprovalInfo': 'Este dispositivo podrá chatear y solicitar transferencias.',
      'deskConnected': 'Conectado a {name}',
      'remoteConnectBtn': 'Conectar',
      'remoteConnect': 'Conectar un dispositivo',
      'remoteBadAddr': 'Código o dirección no válidos.',
      'remoteUnreach': 'No se puede acceder al dispositivo.',
      'remoteTitle': 'Acceso remoto',
      'remoteSaved': 'Dispositivos guardados',
      'remoteNone': 'Sin dispositivos guardados',
      'shareViaLink': 'Compartir por enlace',
      'shareDesc': 'Descarga en el navegador dentro de la red local',
      'shareBtn': 'Compartir',
      'stopShare': 'Dejar de compartir',
      'linkCopied': 'Enlace copiado',
      'showQr': 'Código QR',
      'selectFiles': 'Elegir archivos',
      'selectTargetPeer': 'Elegir destino',
      'dropZoneTitle': 'Enviar archivos',
      'dropZoneSub': 'Transfiere archivos directamente a un dispositivo',
      'allPeersChannel': 'Todos los dispositivos',
      'broadcastAll': 'Todos los dispositivos',
      'chatEmpty': 'Sin mensajes',
      'chatEmptySub': 'Envía mensajes, enlaces o texto a un dispositivo conectado.',
      'chatInputHint': 'Escribe un mensaje…',
      'sendMsg': 'Enviar',
      'sendClipboard': 'Enviar portapapeles',
      'clearChat': 'Borrar chat',
      'chatSendFailed': 'No se pudo enviar el mensaje.',
      'chatApprovalPending': 'Esperando la confirmación del otro dispositivo…',
      'chatOnline': 'En línea',
      'globalChatConnect': 'Conectar al chat remoto',
      'globalChatHelp': 'Introduce la IP:puerto o dirección VPN y la clave del otro dispositivo. Desk Code encuentra dispositivos en la red local.',
      'muteChat': 'Silenciar notificaciones',
      'unmuteChat': 'Activar notificaciones',
      'muteChatUntil': 'En silencio hasta las {time}',
      'muteMinutes': '{n} minutos',
      'muteHours': '{n} horas',
      'incomingMessage': 'Nuevo mensaje de {name}',
      'incomingFile': 'Archivo recibido de {name}',
      'filterSent': 'Enviados',
      'filterReceived': 'Recibidos',
      'clearHistory': 'Borrar historial',
      'noTransfers': 'Aún no hay transferencias',
      'whatsNew': 'Novedades',
      'radarTitle': 'Radar de dispositivos',
      'radarSub': 'Muestra los dispositivos y anima la búsqueda',
    },
    AppLang.french: {
      'devices': 'Appareils',
      'history': 'Historique',
      'settings': 'Paramètres',
      'language': 'Langue',
      'appearance': 'Apparence',
      'about': 'À propos de LocalBridge',
      'network': 'Réseau',
      'device': 'Appareil',
      'deviceName': 'Nom de l’appareil',
      'receive': 'Réception',
      'scan': 'Relancer la recherche',
      'scanning': 'Recherche en cours…',
      'ready': 'Prêt à recevoir',
      'serverOff': 'Serveur arrêté',
      'statusOffline': 'Hors ligne',
      'statusConnected': 'connectés',
      'disabled': 'Désactivé',
      'turnOn': 'Activer',
      'turnOff': 'Désactiver',
      'askFirst': 'Demander d’abord',
      'autoAccept': 'Accepter automatiquement',
      'nearby': 'Appareils à proximité',
      'noDevices': 'Aucun appareil trouvé',
      'noDevicesHint': 'Ouvrez LocalBridge sur les deux appareils et connectez-les au même réseau local.',
      'firewallHint': 'Si Windows le demande, autorisez LocalBridge sur les réseaux privés.',
      'offlineTitle': 'LocalBridge est hors ligne',
      'offlineHint': 'Activez LocalBridge pour trouver des appareils et transférer des fichiers.',
      'send': 'Envoyer',
      'cancel': 'Annuler',
      'copied': 'Copié',
      'copyLink': 'Copier le lien',
      'deviceRemove': 'Retirer l’appareil',
      'globalConnect': 'Connexion',
      'globalConnectSub': 'Connectez-vous avec un Desk Code pour envoyer des messages et des fichiers',
      'globalTransfer': 'Transfert',
      'globalTransferSub': 'Envoyez des fichiers ou partagez-les par lien',
      'bridgeChat': 'Chat Bridge',
      'bridgeChatSub': 'Envoyez des messages et des liens aux appareils connectés',
      'deskTitle': 'Desk Code',
      'deskOwnCode': 'Votre Desk Code',
      'deskHelp': 'Collez le Desk Code d’un appareil du réseau local. L’autre appareil doit accepter.',
      'deskOwnCodeError': 'Saisissez le code de l’autre appareil.',
      'deskNotFound': 'Appareil introuvable. Vérifiez le code et le réseau local.',
      'deskOffline': 'Activez LocalBridge pour vous connecter.',
      'deskDeclined': 'Connexion refusée ou clé d’accès incorrecte.',
      'deskBusy': 'L’autre appareil traite déjà une demande.',
      'deskUpdateRequired': 'Mettez LocalBridge à jour sur l’autre appareil.',
      'deskIncoming': '{name} souhaite se connecter',
      'deskApprove': 'Autoriser la connexion',
      'deskApprovalInfo': 'Cet appareil pourra discuter et demander des transferts.',
      'deskConnected': 'Connecté à {name}',
      'remoteConnectBtn': 'Connecter',
      'remoteConnect': 'Connecter un appareil',
      'remoteBadAddr': 'Code ou adresse invalide.',
      'remoteUnreach': 'L’appareil est inaccessible.',
      'remoteTitle': 'Accès à distance',
      'remoteSaved': 'Appareils enregistrés',
      'remoteNone': 'Aucun appareil enregistré',
      'shareViaLink': 'Partager par lien',
      'shareDesc': 'Téléchargez depuis le navigateur sur le réseau local',
      'shareBtn': 'Partager',
      'stopShare': 'Arrêter le partage',
      'linkCopied': 'Lien copié',
      'showQr': 'Code QR',
      'selectFiles': 'Choisir les fichiers',
      'selectTargetPeer': 'Choisir un destinataire',
      'dropZoneTitle': 'Envoyer des fichiers',
      'dropZoneSub': 'Transférez les fichiers directement vers un appareil',
      'allPeersChannel': 'Tous les appareils',
      'broadcastAll': 'Tous les appareils',
      'chatEmpty': 'Aucun message',
      'chatEmptySub': 'Envoyez des messages, liens ou du texte à un appareil connecté.',
      'chatInputHint': 'Écrivez un message…',
      'sendMsg': 'Envoyer',
      'sendClipboard': 'Envoyer le presse-papiers',
      'clearChat': 'Effacer la discussion',
      'chatSendFailed': 'Impossible d’envoyer le message.',
      'chatApprovalPending': 'En attente de confirmation sur l’autre appareil…',
      'chatOnline': 'En ligne',
      'globalChatConnect': 'Se connecter au chat distant',
      'globalChatHelp': 'Saisissez IP:port ou une adresse VPN et la clé de l’autre appareil. Desk Code trouve les appareils du réseau local.',
      'muteChat': 'Couper les notifications',
      'unmuteChat': 'Rétablir les notifications',
      'muteChatUntil': 'En sourdine jusqu’à {time}',
      'muteMinutes': '{n} minutes',
      'muteHours': '{n} heures',
      'incomingMessage': 'Nouveau message de {name}',
      'incomingFile': 'Fichier reçu de {name}',
      'filterSent': 'Envoyés',
      'filterReceived': 'Reçus',
      'clearHistory': 'Effacer l’historique',
      'noTransfers': 'Aucun transfert pour le moment',
      'whatsNew': 'Nouveautés',
      'radarTitle': 'Radar des appareils',
      'radarSub': 'Affiche les appareils et anime la recherche',
    },
  };

  static String get(AppLang lang, String key) {
    final code = switch (lang) {
      AppLang.english => 'en',
      AppLang.turkish => 'tr',
      AppLang.russian => 'ru',
      AppLang.german => 'de',
      AppLang.spanish => 'es',
      AppLang.french => 'fr',
    };
    return keys[lang]?[key] ??
        kExtraLocalizedStrings[code]?[key] ??
        keys[AppLang.english]?[key] ??
        kExtraLocalizedStrings['en']?[key] ??
        key;
  }
}

// ------------------------------------------------------------- settings

const List<Color> kAccents = [
  Color(0xFF4F6DF5), // Atelier Cobalt
  Color(0xFF289D8F), // Verdigris Sage
  Color(0xFF8B6CEF), // Dusty Iris
  Color(0xFFD9597B), // Studio Rose
  Color(0xFFD9822B), // Warm Amber Ochre
  Color(0xFF2E9E6B), // Botanical Emerald
  Color(0xFF3A86FF), // Editorial Cerulean
  Color(0xFFC94A4A), // Terracotta Carmine
  Color(0xFFE06D53), // Signature Atelier Terracotta Coral (Default)
  Color(0xFFA67B5B), // Warm Umber Clay
  Color(0xFF607D8B), // Architectural Slate
];

class Settings extends ChangeNotifier {
  Directory? defaultStorageDirectory;
  String deviceName = _defaultName();
  ThemeMode themeMode = ThemeMode.dark;
  int accent = 10; // Default: Architectural Midnight Slate matching official logo
  bool autoAccept = false;
  bool autoScan = true;
  int scanSeconds = 8;
  int port = kDefaultPort;
  String saveDir = '';
  bool keepHistory = true;
  bool askShare = true;
  String sharePin = '';
  bool autoAcceptTrusted = true;
  Set<String> trusted = {};
  int requestTimeout = 60;
  bool overwrite = false;
  bool groupBySender = false;
  int historyLimit = 200;
  int shareMinutes = 0;
  bool discoverable = true;
  double textScale = 1.0;
  bool amoled = false; // Default: Atelier Dark (not AMOLED)
  bool showRadar = true;
  bool showIps = true;
  bool haptics = true;
  bool compactHeader = false;
  AppLang language = AppLang.english;

  bool oneTimeDownload = false;
  String allowedExtensionFilter = '';

  // sharing settings (2.0.0)
  int maxDownloads = 0; // 0 = unlimited
  int pinAttempts = 5; // 0 = off
  String shareMessage = '';
  bool showQr = true;
  bool autoCopyLink = false;

  // receive settings (2.1.0)
  bool trustedOnly = false;
  int maxReceiveMb = 0; // 0 = unlimited
  bool openAfterReceive = false;

  // speed settings (2.1.0)
  int scanSpeed = 0; // 0 balanced, 1 fast, 2 turbo
  bool scanVirtual = false; // also scan VPN / VM / Docker networks
  int bootAnim = 2; // 0 off, 1 quick, 2 full (default Full startup animation)
  // extra settings (2.1.0)
  bool showStatusBar = true;
  bool mouseGlow = true;
  int glowLevel = 100; // background glow strength in percent
  bool use24h = true;
  int sortDevices = 0; // 0 name, 1 address, 2 order found
  bool soundOnDone = false;
  bool confirmSend = false;
  bool startOnline = true;
  bool confirmClear = true;
  bool hoverFx = true;
  bool showRailStats = true;
  // remote access over the internet (3.1.0)
  bool remoteEnabled = false;
  String remoteKey = Settings.newKey();
  String deskId = Settings.newKey();
  List<Map<String, dynamic>> remotes = []; // saved devices on other networks

  static String newKey() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  static String _defaultName() {
    final os = Platform.isAndroid
        ? 'Android'
        : Platform.isIOS
            ? 'iPhone'
            : Platform.isWindows
                ? 'Windows'
                : Platform.isMacOS
                    ? 'Mac'
                    : 'Linux';
    return '$os-${Random().nextInt(900) + 100}';
  }

  Future<File> _file([Directory? storageDirectory]) async {
    final d = storageDirectory ??
        defaultStorageDirectory ??
        await getApplicationSupportDirectory();
    await d.create(recursive: true);
    return File(p.join(d.path, 'settings.json'));
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) {
        await _save();
        return;
      }
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final isV2Theme = (j['themeVersion'] as int?) == 2;
      deviceName = (j['deviceName'] as String?) ?? deviceName;
      themeMode = isV2Theme
          ? ThemeMode.values[(j['themeMode'] as int?) ?? ThemeMode.dark.index]
          : ThemeMode.dark;
      accent = isV2Theme
          ? ((j['accent'] as int?) ?? 10).clamp(0, kAccents.length - 1)
          : 10;
      autoAccept = (j['autoAccept'] as bool?) ?? false;
      autoScan = (j['autoScan'] as bool?) ?? true;
      scanSeconds = ((j['scanSeconds'] as int?) ?? 8).clamp(3, 120);
      port = ((j['port'] as int?) ?? kDefaultPort).clamp(1024, 65535);
      saveDir = (j['saveDir'] as String?) ?? '';
      keepHistory = (j['keepHistory'] as bool?) ?? true;
      askShare = (j['askShare'] as bool?) ?? true;
      sharePin = (j['sharePin'] as String?) ?? '';
      autoAcceptTrusted = (j['autoAcceptTrusted'] as bool?) ?? true;
      trusted = ((j['trusted'] as List?) ?? []).map((e) => '$e').toSet();
      requestTimeout = ((j['requestTimeout'] as int?) ?? 60).clamp(15, 120);
      overwrite = (j['overwrite'] as bool?) ?? false;
      groupBySender = (j['groupBySender'] as bool?) ?? false;
      historyLimit = ((j['historyLimit'] as int?) ?? 200).clamp(10, 1000);
      shareMinutes = (j['shareMinutes'] as int?) ?? 0;
      discoverable = (j['discoverable'] as bool?) ?? true;
      textScale = ((j['textScale'] as num?)?.toDouble() ?? 1.0).clamp(0.8, 1.4).toDouble();
      amoled = isV2Theme ? ((j['amoled'] as bool?) ?? false) : false;
      showRadar = (j['showRadar'] as bool?) ?? true;
      showIps = (j['showIps'] as bool?) ?? true;
      haptics = (j['haptics'] as bool?) ?? true;
      compactHeader = (j['compactHeader'] as bool?) ?? false;
      language = AppLang.values[((j['language'] as int?) ?? 0).clamp(0, AppLang.values.length - 1)];
      oneTimeDownload = (j['oneTimeDownload'] as bool?) ?? false;
      allowedExtensionFilter = (j['allowedExtensionFilter'] as String?) ?? '';
      maxDownloads = ((j['maxDownloads'] as int?) ?? 0).clamp(0, 1000);
      pinAttempts = ((j['pinAttempts'] as int?) ?? 5).clamp(0, 100);
      shareMessage = (j['shareMessage'] as String?) ?? '';
      showQr = (j['showQr'] as bool?) ?? true;
      autoCopyLink = (j['autoCopyLink'] as bool?) ?? false;
      trustedOnly = (j['trustedOnly'] as bool?) ?? false;
      maxReceiveMb = ((j['maxReceiveMb'] as int?) ?? 0).clamp(0, 1000000);
      openAfterReceive = (j['openAfterReceive'] as bool?) ?? false;
      scanSpeed = ((j['scanSpeed'] as int?) ?? 0).clamp(0, 2);
      scanVirtual = (j['scanVirtual'] as bool?) ?? false;
      bootAnim = isV2Theme ? ((j['bootAnim'] as int?) ?? 2).clamp(0, 2) : 2;
      showStatusBar = (j['showStatusBar'] as bool?) ?? true;
      mouseGlow = (j['mouseGlow'] as bool?) ?? true;
      glowLevel = ((j['glowLevel'] as int?) ?? 100).clamp(0, 200);
      use24h = (j['use24h'] as bool?) ?? true;
      sortDevices = ((j['sortDevices'] as int?) ?? 0).clamp(0, 2);
      soundOnDone = (j['soundOnDone'] as bool?) ?? false;
      confirmSend = (j['confirmSend'] as bool?) ?? false;
      startOnline = (j['startOnline'] as bool?) ?? true;
      confirmClear = (j['confirmClear'] as bool?) ?? true;
      hoverFx = (j['hoverFx'] as bool?) ?? true;
      showRailStats = (j['showRailStats'] as bool?) ?? true;
      remoteEnabled = (j['remoteEnabled'] as bool?) ?? false;
      final rk = j['remoteKey'];
      if (rk is String && rk.length >= 6) remoteKey = rk;
      final id = j['deskId'];
      if (id is String && RegExp(r'^[A-Z2-9]{8}$').hasMatch(id)) {
        deskId = id;
      }
      remotes = [
        for (final e in ((j['remotes'] as List?) ?? const []))
          if (e is Map && e['host'] is String) Map<String, dynamic>.from(e)
      ];
      if (deskId != id) await _save();
    } catch (_) {}
  }

  Future<void> _settingsWrite = Future.value();

  Future<void> _save([Directory? storageDirectory]) {
    final snapshot = jsonEncode({
        'themeVersion': 2,
        'deviceName': deviceName,
        'themeMode': themeMode.index,
        'accent': accent,
        'autoAccept': autoAccept,
        'autoScan': autoScan,
        'scanSeconds': scanSeconds,
        'port': port,
        'saveDir': saveDir,
        'keepHistory': keepHistory,
        'askShare': askShare,
        'sharePin': sharePin,
        'autoAcceptTrusted': autoAcceptTrusted,
        'trusted': trusted.toList(),
        'requestTimeout': requestTimeout,
        'overwrite': overwrite,
        'groupBySender': groupBySender,
        'historyLimit': historyLimit,
        'shareMinutes': shareMinutes,
        'discoverable': discoverable,
        'textScale': textScale,
        'amoled': amoled,
        'showRadar': showRadar,
        'showIps': showIps,
        'haptics': haptics,
        'compactHeader': compactHeader,
        'language': language.index,
        'oneTimeDownload': oneTimeDownload,
        'allowedExtensionFilter': allowedExtensionFilter,
        'maxDownloads': maxDownloads,
        'pinAttempts': pinAttempts,
        'shareMessage': shareMessage,
        'showQr': showQr,
        'autoCopyLink': autoCopyLink,
        'trustedOnly': trustedOnly,
        'maxReceiveMb': maxReceiveMb,
        'openAfterReceive': openAfterReceive,
        'scanSpeed': scanSpeed,
        'scanVirtual': scanVirtual,
        'bootAnim': bootAnim,
        'showStatusBar': showStatusBar,
        'mouseGlow': mouseGlow,
        'glowLevel': glowLevel,
        'use24h': use24h,
        'sortDevices': sortDevices,
        'soundOnDone': soundOnDone,
        'confirmSend': confirmSend,
        'startOnline': startOnline,
        'confirmClear': confirmClear,
        'hoverFx': hoverFx,
        'showRailStats': showRailStats,
        'remoteEnabled': remoteEnabled,
        'remoteKey': remoteKey,
        'deskId': deskId,
        'remotes': remotes,
    });
    return _settingsWrite = _settingsWrite.then((_) async {
      try {
        await _writeJsonAtomically(await _file(storageDirectory), snapshot);
      } on MissingPluginException {
        // Headless test environment without path_provider plugin channel
      } catch (error, stack) {
        debugPrintStack(label: 'LocalBridge settings save failed: $error', stackTrace: stack);
      }
    });
  }

  void update(void Function() change, {Directory? storageDirectory}) {
    change();
    notifyListeners();
    _save(storageDirectory);
  }

  void reset() {
    update(() {
      deviceName = _defaultName();
      themeMode = ThemeMode.dark;
      accent = 10;
      autoAccept = false;
      autoScan = true;
      scanSeconds = 8;
      port = kDefaultPort;
      saveDir = '';
      keepHistory = true;
      askShare = true;
      sharePin = '';
      autoAcceptTrusted = true;
      trusted = {};
      requestTimeout = 60;
      overwrite = false;
      groupBySender = false;
      historyLimit = 200;
      shareMinutes = 0;
      discoverable = true;
      textScale = 1.0;
      amoled = false;
      showRadar = true;
      showIps = true;
      haptics = true;
      compactHeader = false;
      language = AppLang.english;
      oneTimeDownload = false;
      allowedExtensionFilter = '';
      maxDownloads = 0;
      pinAttempts = 5;
      shareMessage = '';
      showQr = true;
      autoCopyLink = false;
      trustedOnly = false;
      maxReceiveMb = 0;
      openAfterReceive = false;
      scanSpeed = 0;
      scanVirtual = false;
      bootAnim = 2;
      showStatusBar = true;
      mouseGlow = true;
      glowLevel = 100;
      use24h = true;
      sortDevices = 0;
      soundOnDone = false;
      confirmSend = false;
      startOnline = true;
      confirmClear = true;
      hoverFx = true;
      showRailStats = true;
      remoteEnabled = false;
    });
  }

  void toggleTrusted(String name) {
    update(() {
      if (!trusted.remove(name)) trusted.add(name);
    });
  }

  String trustKeyFor(Device d) {
    final id = d.deskId.trim();
    if (id.isNotEmpty) return 'id:$id|${d.alias}';
    return 'ip:${d.ip}|${d.alias}';
  }

  bool isDeviceTrusted(Device d) {
    final id = d.deskId.trim();
    if (id.isNotEmpty) {
      if (trusted.any((e) => e == 'id:$id' || e.startsWith('id:$id|'))) {
        return true;
      }
    }
    if (trusted.contains('ip:${d.ip}|${d.alias}')) return true;
    if (d.connectionToken.isNotEmpty && trusted.contains(d.alias)) return true;
    return false;
  }

  void toggleTrustedDevice(Device d) {
    update(() {
      final id = d.deskId.trim();
      final key = trustKeyFor(d);
      final currentlyTrusted = isDeviceTrusted(d);
      if (currentlyTrusted) {
        trusted.remove(key);
        if (id.isNotEmpty) {
          trusted.removeWhere((e) => e == 'id:$id' || e.startsWith('id:$id|'));
        }
        trusted.remove('ip:${d.ip}|${d.alias}');
        trusted.remove(d.alias);
      } else {
        trusted.remove(d.alias);
        trusted.add(key);
      }
    });
  }

  static String formatTrustedEntry(String raw) {
    if (raw.startsWith('id:')) {
      final rest = raw.substring(3);
      final bar = rest.indexOf('|');
      if (bar > 0 && bar < rest.length - 1) {
        final id = rest.substring(0, bar);
        final name = rest.substring(bar + 1);
        return '$name ($id)';
      }
      return rest;
    }
    if (raw.startsWith('ip:')) {
      final rest = raw.substring(3);
      final bar = rest.indexOf('|');
      if (bar > 0 && bar < rest.length - 1) {
        final ip = rest.substring(0, bar);
        final name = rest.substring(bar + 1);
        return '$name ($ip)';
      }
      return rest;
    }
    return raw;
  }

  String tr(String key) => L10n.get(language, key);
}

// --------------------------------------------------------------- models

class Device {
  final String alias;
  final String ip;
  final String platform;
  final int port; // 0 = the normal LocalBridge port
  final String key; // access key for remote devices
  final bool remote; // reached over the internet or a VPN
  final String connectionToken;
  final String deskId;
  Device(this.alias, this.ip, this.platform,
      {this.port = 0, this.key = '', this.remote = false, this.connectionToken = '',
      this.deskId = ''});

  bool get isPhone => platform == 'android' || platform == 'ios';
}

class RequestFileItem {
  final String name;
  final int size;
  RequestFileItem(this.name, this.size);

  factory RequestFileItem.fromJson(Map<String, dynamic> json) {
    return RequestFileItem(
      json['name']?.toString() ?? 'file',
      (json['size'] as num?)?.toInt() ?? 0,
    );
  }
}

class IncomingRequest {
  final String from;
  final List<RequestFileItem> files;
  final bool download;
  final bool connection;
  final bool unverifiedTrustClaim;
  final Completer<bool> decision = Completer<bool>();

  IncomingRequest(
    this.from,
    this.files, {
    this.download = false,
    this.connection = false,
    this.unverifiedTrustClaim = false,
  });
}

class _Session {
  final List<String> names;
  final List<int> sizes;
  final String from;
  final String peerIp;
  final String? connectionToken;
  DateTime expires = DateTime.now().add(const Duration(minutes: 15));
  final Set<int> uploading = {};
  final Set<int> completed = {};
  _Session(this.names, this.sizes, this.from, this.peerIp, this.connectionToken);
}

class ShareSession {
  final String token;
  final List<PlatformFile> files;
  final List<int> sizes;
  final String? pin;
  final Set<String> allowed = {};
  final Map<String, int> pinFails = {};
  int downloads = 0;
  int activeDownloads = 0;
  ShareSession(this.token, this.files, this.sizes, this.pin);
}

class HistoryItem {
  final String name;
  final int size;
  final bool sent;
  final String peer;
  final DateTime time;
  final String? path;
  final String status; // 'completed', 'failed', 'cancelled'

  HistoryItem(
    this.name,
    this.size,
    this.sent,
    this.peer,
    this.time,
    this.path, {
    this.status = 'completed',
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
        'sent': sent,
        'peer': peer,
        'time': time.millisecondsSinceEpoch,
        'path': path,
        'status': status,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        '${j['name']}',
        (j['size'] as num?)?.toInt() ?? 0,
        (j['sent'] as bool?) ?? false,
        '${j['peer']}',
        DateTime.fromMillisecondsSinceEpoch((j['time'] as num?)?.toInt() ?? 0),
        j['path'] as String?,
        status: (j['status'] as String?) ?? 'completed',
      );
}

class _ChatChannel {
  static const maxRequestBytes = 16 * 1024;
  static const _timeout = Duration(seconds: 5);
  final WebSocket _socket;
  final bool Function(String) _receive;
  final VoidCallback _onClosed;
  final _pending = <int, Completer<bool>>{};
  final _ready = Completer<bool>();
  int _nextId = 0;
  bool _closed = false;

  _ChatChannel(this._socket, this._receive, this._onClosed) {
    _socket.pingInterval = const Duration(seconds: 15);
    _socket.listen(_onFrame, onDone: _finish, onError: (Object _) => _finish());
  }

  void _onFrame(dynamic frame) {
    if (_closed || frame is! String || frame.length > maxRequestBytes) return;
    if (frame == 'ready') {
      if (!_ready.isCompleted) _ready.complete(true);
      return;
    }
    try {
      final data = jsonDecode(frame);
      if (data is! Map<String, dynamic> || data['id'] is! int) return;
      final id = data['id'] as int;
      if (data['text'] case final String text) {
        _socket.add(jsonEncode({'id': id, 'ok': _receive(text)}));
      } else if (data['ok'] case final bool ok) {
        _pending.remove(id)?.complete(ok);
      }
    } on FormatException {
      close();
    } on StateError {
      close();
    }
  }

  Future<bool> send(String text) async {
    if (_closed || _socket.readyState != WebSocket.open) return false;
    final id = ++_nextId;
    final frame = jsonEncode({'id': id, 'text': text});
    if (utf8.encode(frame).length > maxRequestBytes) return false;
    final result = _pending[id] = Completer<bool>();
    try {
      _socket.add(frame);
      return await result.future.timeout(_timeout, onTimeout: () => false);
    } on StateError {
      close();
      return false;
    } finally {
      _pending.remove(id);
    }
  }

  void _finish() {
    if (_closed) return;
    _closed = true;
    if (!_ready.isCompleted) _ready.complete(false);
    for (final result in _pending.values) {
      result.complete(false);
    }
    _pending.clear();
    _onClosed();
  }

  void close() {
    _finish();
    unawaited(_socket.close(WebSocketStatus.goingAway));
  }

  void signalReady() => _socket.add('ready');

  Future<bool> waitUntilReady() =>
      _ready.future.timeout(_timeout, onTimeout: () => false);
}

class ChatMessage {
  final String id;
  final String sender;
  final String peerIp;
  final String text;
  final DateTime time;
  final bool outgoing;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.peerIp,
    required this.text,
    required this.time,
    required this.outgoing,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sender': sender,
        'peerIp': peerIp,
        'text': text,
        'time': time.millisecondsSinceEpoch,
        'outgoing': outgoing,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: '${j['id'] ?? ''}',
        sender: '${j['sender'] ?? ''}',
        peerIp: '${j['peerIp'] ?? ''}',
        text: '${j['text'] ?? ''}',
        time: DateTime.fromMillisecondsSinceEpoch((j['time'] as num?)?.toInt() ?? 0),
        outgoing: (j['outgoing'] as bool?) ?? false,
      );
}

enum StatusKind { info, success, error }

String fmtSize(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

String fmtTime(DateTime t, [bool h24 = true]) {
  String two(int n) => n.toString().padLeft(2, '0');
  if (h24) return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '${two(t.day)}.${two(t.month)} $h:${two(t.minute)} ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _page(String inner) => '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>$kAppName v$kVersion</title><style>
body{font-family:Inter,system-ui,sans-serif;margin:0;padding:28px 18px;background:radial-gradient(circle at 50% 0%,#0f1c2e 0%,#08090c 65%);color:#f4f4f5;min-height:100vh}
.wrap{max-width:580px;margin:0 auto}
.brand{display:flex;align-items:center;gap:12px;margin-bottom:20px}
.brand span{font-weight:800;font-size:20px;letter-spacing:.5px}
.badge{font-size:11px;padding:3px 8px;border-radius:99px;background:rgba(56,189,248,.16);color:#38bdf8;font-weight:700}
h1{font-size:22px;margin:0 0 12px}
.msg{opacity:.78;margin:0 0 16px;line-height:1.45}
.card{background:#111318;border:1px solid #222631;border-radius:18px;padding:15px 18px;margin:10px 0;display:flex;align-items:center;justify-content:space-between;gap:12px;box-shadow:0 8px 24px rgba(0,0,0,.35)}
.name{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:320px;font-weight:600}
.size{opacity:.6;font-size:13px;margin-top:2px}
a.btn,button{background:linear-gradient(135deg,#2dd4bf,#38bdf8);color:#061018;border:0;border-radius:12px;padding:9px 18px;text-decoration:none;font-size:14px;cursor:pointer;font-weight:800}
input{padding:10px 14px;border-radius:12px;border:1px solid #222631;background:#0c0e12;color:#fff;font-size:16px}
</style></head><body><div class="wrap">
<div class="brand">
<svg width="36" height="36" viewBox="0 0 512 512" fill="none" xmlns="http://www.w3.org/2000/svg">
<rect x="20" y="20" width="472" height="472" rx="112" fill="#050517" stroke="#607D8B" stroke-opacity="0.6" stroke-width="12"/>
<path d="M 106 286 Q 256 96 406 286" stroke="#FFFFFF" stroke-width="32" stroke-linecap="round" fill="none"/>
<line x1="166" y1="214" x2="166" y2="286" stroke="#FFFFFF" stroke-width="18" stroke-linecap="round"/>
<line x1="211" y1="184" x2="211" y2="286" stroke="#FFFFFF" stroke-width="18" stroke-linecap="round"/>
<line x1="256" y1="172" x2="256" y2="286" stroke="#FFFFFF" stroke-width="18" stroke-linecap="round"/>
<line x1="301" y1="184" x2="301" y2="286" stroke="#FFFFFF" stroke-width="18" stroke-linecap="round"/>
<line x1="346" y1="214" x2="346" y2="286" stroke="#FFFFFF" stroke-width="18" stroke-linecap="round"/>
<rect x="86" y="274" width="340" height="28" rx="14" fill="#FFFFFF"/>
<path d="M 150 296 L 132 356" stroke="#FFFFFF" stroke-width="32" stroke-linecap="round"/>
<path d="M 362 296 L 380 356" stroke="#FFFFFF" stroke-width="32" stroke-linecap="round"/>
</svg>
<span>$kAppName</span><span class="badge">v$kVersion</span>
</div>
$inner</div></body></html>''';

// --------------------------------------------------------------- service

class DropService extends ChangeNotifier {
  final Settings cfg;
  final Directory? storageDirectory;
  DropService(this.cfg, {this.storageDirectory}) {
    if (storageDirectory != null) {
      cfg.defaultStorageDirectory ??= storageDirectory;
    }
  }

  final Map<String, Device> devices = {};
  final Map<String, Device> _connections = {};
  final Map<String, _ChatChannel> _chatChannels = {};
  final Set<String> myIps = {};
  final Map<String, _Session> _sessions = {};
  final Set<String> _reservedPaths = {};
  HttpClient? _outgoingTransfer;
  bool _sendCancelled = false;
  final List<HistoryItem> history = [];
  int _sentFiles = 0;
  int _receivedFiles = 0;
  final List<ChatMessage> messages = [];
  final List<({String title, String body, String? chatAddress})> _notices = [];
  HttpServer? _server;
  RawDatagramSocket? _discovery;
  Timer? _timer;
  IncomingRequest? pending;
  ShareSession? share;
  Timer? _shareTimer;
  String status = '';
  StatusKind kind = StatusKind.info;
  double? progress;
  bool scanning = false;
  bool serverUp = false;
  bool online = true; // master power switch (the "Active" button)
  bool _changingPower = false;
  bool _disposed = false;
  int _networkGeneration = 0;
  bool _appBackgrounded = false;

  void setAppBackgrounded(bool bg) {
    if (_appBackgrounded == bg) return;
    _appBackgrounded = bg;
    if (bg) {
      _timer?.cancel();
      _timer = null;
    } else {
      reschedule();
    }
  }

  // scanning state
  DateTime? _lastSweep; // last time the whole network was swept
  final Map<String, int> _miss = {}; // ip -> consecutive scans without an answer
  Map<String, Device> _known = {}; // devices seen before (saved on disk)
  Future<void> _knownWrite = Future.value();
  final Set<String> _hiddenDevices = {};
  bool _rescanRequested = false;
  final Map<String, Device> _chatPeers = {};
  final Map<String, DateTime> _chatMutedUntil = {};
  final Map<String, Timer> _chatMuteTimers = {};

  DateTime? chatMutedUntil(String address) {
    final until = _chatMutedUntil[address];
    return until != null && until.isAfter(DateTime.now()) ? until : null;
  }

  void muteChat(String address, Duration duration) {
    _chatMuteTimers.remove(address)?.cancel();
    if (duration == Duration.zero) {
      _chatMutedUntil.remove(address);
    } else {
      _chatMutedUntil[address] = DateTime.now().add(duration);
      _chatMuteTimers[address] = Timer(duration, () {
        _chatMuteTimers.remove(address);
        _chatMutedUntil.remove(address);
        _notify();
      });
    }
    _notify();
  }

  Future<void> rescan() async {
    if (!online || _disposed) return;
    if (scanning) {
      _rescanRequested = true;
      return;
    }
    _hiddenDevices.clear();
    await scan();
  }

  String get alias => cfg.deviceName;

  String addressOf(Device d) => '${d.ip}:${d.port == 0 ? cfg.port : d.port}';
  Device? connectedDevice(String address) => devices[address];

  List<String> get shareUrls {
    final s = share;
    if (s == null) return [];
    return [for (final ip in myIps) 'http://$ip:${cfg.port}/s/${s.token}'];
  }

  Timer? _notifyTimer;

  /// Updates the screen at most about 16 times a second, so a busy scan or a
  /// fast transfer does not flood the UI with rebuilds (keeps scrolling smooth).
  void _notify() {
    if (_disposed || _notifyTimer != null) return;
    _notifyTimer = Timer(const Duration(milliseconds: 60), () {
      _notifyTimer = null;
      if (!_disposed) notifyListeners();
    });
  }

  void _setStatus(String s, [StatusKind k = StatusKind.info]) {
    status = s;
    kind = k;
  }

  void clearStatus() {
    status = '';
    progress = null;
    _notify();
  }

  void _buzz() {
    if (cfg.haptics) HapticFeedback.mediumImpact();
    if (cfg.soundOnDone) SystemSound.play(SystemSoundType.alert);
  }

  void _incomingNotice(String title, String body, {String? chatAddress}) {
    _notices.add((title: title, body: body, chatAddress: chatAddress));
    if (_notices.length > 5) _notices.removeAt(0);
    _notify();
  }

  /// Devices in the order chosen in Settings (name, address or found order).
  List<Device> sortedDevices() {
    final list = devices.values.toList();
    if (cfg.sortDevices == 0) {
      list.sort((a, b) => a.alias.toLowerCase().compareTo(b.alias.toLowerCase()));
    } else if (cfg.sortDevices == 1) {
      int key(String ip) {
        final p = ip.split('.').map((e) => int.tryParse(e) ?? 0).toList();
        return p.fold<int>(0, (a, b) => a * 256 + b);
      }
      list.sort((a, b) => key(a.ip).compareTo(key(b.ip)));
    }
    return list;
  }

  Future<void> start() async {
    // Independent startup work runs side by side instead of one after another,
    // so the app is ready (and scanning) sooner.
    unawaited(_loadHistory().then((_) => _notify()));
    if (!cfg.startOnline) {
      // "Start turned on" is off: stay hidden until the power button is pressed.
      online = false;
      _notify();
      return;
    }
    final bound = _bind();
    final generation = _networkGeneration;
    final ips = _localIps();
    final known = _loadKnown();
    await bound;
    final addresses = await ips;
    if (!online || _disposed || generation != _networkGeneration) return;
    myIps
      ..clear()
      ..addAll(addresses);
    await known;
    if (!online || _disposed || generation != _networkGeneration) return;
    _notify();
    reschedule();
    if (cfg.bootAnim > 0) {
      final delayMs = cfg.bootAnim == 2 ? 2150 : 880;
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      if (!online || _disposed || generation != _networkGeneration) return;
    }
    await scan();
  }

  /// Turns LocalBridge fully on/off. Off = no scanning, the server is closed
  /// (other devices cannot see you or send to you) and any link share stops.
  Future<void> setOnline(bool v) async {
    if (_disposed || _changingPower || online == v) return;
    _changingPower = true;
    try {
      await _applyOnline(v);
    } finally {
      _changingPower = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _applyOnline(bool v) async {
    online = v;
    if (cfg.haptics) HapticFeedback.selectionClick();
    if (!v) {
      final peers = _connections.values.toList();
      final directPeers = peers.where((d) => !_chatChannels.containsKey(d.connectionToken)).toList();
      _networkGeneration++;
      cancelOutgoingTransfer();
      scanning = false;
      _rescanRequested = false;
      serverUp = false;
      _timer?.cancel();
      _timer = null;
      _shareTimer?.cancel();
      _shareTimer = null;
      share = null;
      final pr = pending;
      if (pr != null) resolve(pr, false);
      _sessions.clear();
      _connections.clear();
      _closeChatChannels();
      _discovery?.close();
      _discovery = null;
      devices.clear();
      progress = null;
      status = '';
      kind = StatusKind.info;
      _notifyTimer?.cancel();
      _notifyTimer = null;
      if (!_disposed) notifyListeners();
      unawaited(Future.wait(directPeers.map(_disconnect)));
      final srv = _server;
      _server = null;
      try {
        await srv?.close(force: true);
      } catch (_) {}
    } else {
      _notifyTimer?.cancel();
      _notifyTimer = null;
      if (!_disposed) notifyListeners();
      final bound = _bind();
      final generation = _networkGeneration;
      await bound;
      final addresses = await _localIps();
      if (!online || _disposed || generation != _networkGeneration) return;
      myIps
        ..clear()
        ..addAll(addresses);
      if (serverUp) {
        reschedule();
        unawaited(scan());
      }
    }
  }

  void reschedule() {
    _timer?.cancel();
    _timer = null;
    if (!cfg.autoScan || !online || _appBackgrounded) return;
    _timer = Timer.periodic(Duration(seconds: cfg.scanSeconds), (_) => _autoScan());
  }

  Future<void> _bind() async {
    final generation = ++_networkGeneration;
    _discovery?.close();
    _discovery = null;
    final previous = _server;
    _server = null;
    serverUp = false;
    scanning = false;
    _rescanRequested = false;
    try {
      await previous?.close(force: true);
      if (!online || _disposed || generation != _networkGeneration) return;
      final server = await HttpServer.bind(InternetAddress.anyIPv4, cfg.port);
      if (!online || _disposed || generation != _networkGeneration) {
        await server.close(force: true);
        return;
      }
      _server = server;
      server.listen(_handle, onError: (_) {});
      serverUp = true;
      await _bindDiscovery(generation);
    } catch (e) {
      if (generation != _networkGeneration) return;
      serverUp = false;
      _setStatus('Could not start server (port ${cfg.port}): $e', StatusKind.error);
    }
    _notify();
  }

  static const _discoveryPort = 53318;

  Future<void> _bindDiscovery(int generation) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, _discoveryPort);
      if (_disposed || !online || generation != _networkGeneration) {
        socket.close();
        return;
      }
      _discovery = socket;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        Datagram? packet;
        while ((packet = socket.receive()) != null) {
          final request = packet!;
          if (!_isLocalAddr(request.address) || request.data.length != 11 ||
              ascii.decode(request.data, allowInvalid: true) != 'LB:${cfg.deskId}') {
            continue;
          }
          socket.send(ascii.encode('LB:${cfg.deskId}:${cfg.port}'), request.address, request.port);
        }
      }, onError: (Object _) => socket.close());
    } catch (_) {
      // HTTP discovery can still find devices when UDP is unavailable.
    }
  }

  Future<({String host, int port})?> _findDesk(String code) async {
    for (final device in devices.values) {
      if (device.deskId == code) {
        return (host: device.ip, port: device.port == 0 ? cfg.port : device.port);
      }
    }
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;
    final found = Completer<({String host, int port})?>();
    try {
      final client = socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      client.broadcastEnabled = true;
      subscription = client.listen((event) {
        if (event != RawSocketEvent.read || found.isCompleted) return;
        Datagram? packet;
        while ((packet = client.receive()) != null) {
          final response = packet!;
          final message = ascii.decode(response.data, allowInvalid: true);
          if (!_isLocalAddr(response.address) || !message.startsWith('LB:$code:')) continue;
          final port = int.tryParse(message.split(':').last);
          if (port == null || port < 1024 || port > 65535) continue;
          found.complete((host: response.address.address, port: port));
          return;
        }
      }, onError: (Object _) {
        if (!found.isCompleted) found.complete(null);
      });
      for (final host in {'255.255.255.255', '127.0.0.1',
        for (final ip in myIps) '${ip.substring(0, ip.lastIndexOf('.'))}.255',
      }) {
        try {
          client.send(ascii.encode('LB:$code'), InternetAddress(host), _discoveryPort);
        } on SocketException {
          continue;
        }
      }
      return await found.future.timeout(const Duration(seconds: 2), onTimeout: () => null);
    } on SocketException {
      return null;
    } finally {
      await subscription?.cancel();
      socket?.close();
    }
  }

  Future<void> restartServer() async {
    if (!online) return;
    cancelOutgoingTransfer();
    _sessions.clear();
    if (pending case final request?) resolve(request, false);
    _connections.clear();
    _closeChatChannels();
    final binding = _bind();
    final generation = _networkGeneration;
    await binding;
    if (!online || _disposed || generation != _networkGeneration) return;
    devices.clear();
    await scan();
  }

  @override
  void dispose() {
    _disposed = true;
    _closeChatChannels();
    for (final timer in _chatMuteTimers.values) {
      timer.cancel();
    }
    _networkGeneration++;
    cancelOutgoingTransfer();
    if (pending case final request?) resolve(request, false);
    _discovery?.close();
    _notifyTimer?.cancel();
    _timer?.cancel();
    _shareTimer?.cancel();
    _server?.close(force: true);
    super.dispose();
  }

  static final RegExp _skipStart = RegExp(
      r'^(lo|tun|tap|utun|ppp|wg|zt|veth|docker|br-|virbr|vmnet|vboxnet|rmnet|ccmni|dummy|awdl|llw|bridge|ip6tnl|sit|tailscale)',
      caseSensitive: false);
  static final RegExp _skipAny = RegExp(
      r'(loopback|vethernet|vmware|virtualbox|hyper-v|wsl|zerotier|tailscale|teredo|isatap|pseudo|bluetooth|npcap|tap-windows|openvpn|nordlynx|wireguard|vpn)',
      caseSensitive: false);

  static bool _isPrivate(String ip) {
    final parts = ip.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.contains(null)) return false;
    final a = parts[0]!, b = parts[1]!;
    return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
  }

  /// Local IPv4 addresses worth using, real LAN adapters first. VPN, virtual
  /// machine and Docker adapters are skipped (unless the setting allows them)
  /// so scans and share links do not waste time on networks nobody else is on.
  Future<List<String>> _localIps() async {
    final all = <String>[];
    final real = <String>[];
    try {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in i.addresses) {
          final ip = a.address;
          if (a.isLoopback || ip.startsWith('169.254.')) continue;
          all.add(ip);
          if (!_isPrivate(ip)) continue;
          if (!cfg.scanVirtual && (_skipStart.hasMatch(i.name) || _skipAny.hasMatch(i.name))) {
            continue;
          }
          real.add(ip);
        }
      }
    } catch (_) {}
    final out = (real.isNotEmpty ? real : all).toSet().toList();
    int rank(String ip) => ip.startsWith('192.168.') ? 0 : (ip.startsWith('10.') ? 1 : 2);
    out.sort((x, y) => rank(x).compareTo(rank(y)));
    return out;
  }

  Future<File> _knownFile() async {
    final d = storageDirectory ?? await getApplicationSupportDirectory();
    await d.create(recursive: true);
    return File(p.join(d.path, 'known_devices.json'));
  }

  Future<void> _loadKnown() async {
    try {
      final f = await _knownFile();
      if (!await f.exists()) return;
      final list = jsonDecode(await f.readAsString()) as List;
      _known = {
        for (final e in list)
          if (e is Map && e['ip'] is String)
            e['ip'] as String: Device('${e['alias']}', e['ip'] as String, '${e['platform'] ?? ''}'),
      };
    } catch (_) {}
  }

  /// Remembers devices between runs so the next start can check them first.
  Future<void> _saveKnown() async {
    if (!devices.values.any((d) => !d.remote && _known[d.ip]?.alias != d.alias)) return;
    final merged = <String, Device>{..._known};
    for (final d in devices.values) {
      if (d.remote) continue;
      merged.remove(d.ip);
      merged[d.ip] = d;
    }
    while (merged.length > 24) {
      merged.remove(merged.keys.first);
    }
    _known = merged;
    await _writeKnown();
  }

  Future<void> _writeKnown() {
    final entries = [
      for (final d in _known.values) {'alias': d.alias, 'ip': d.ip, 'platform': d.platform},
    ];
    return _knownWrite = _knownWrite.then((_) async {
      try {
        final f = await _knownFile();
        await f.writeAsString(jsonEncode(entries));
      } catch (_) {}
    });
  }

  Future<File> _historyFile() async {
    final d = storageDirectory ?? await getApplicationSupportDirectory();
    await d.create(recursive: true);
    return File(p.join(d.path, 'history.json'));
  }

  Future<void> _loadHistory() async {
    try {
      final f = await _historyFile();
      if (!await f.exists()) return;
      final list = jsonDecode(await f.readAsString()) as List;
      final records = list.map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (_disposed) return;
      history
        ..clear()
        ..addAll(records);
      _refreshHistoryCounts();
    } catch (_) {}
  }

  Future<void> _historyWrite = Future.value();

  Future<void> _saveHistory() {
    final snapshot = jsonEncode(history.map((e) => e.toJson()).toList());
    return _historyWrite = _historyWrite.then((_) async {
      try {
        await _writeJsonAtomically(await _historyFile(), snapshot);
      } catch (error, stack) {
        debugPrintStack(label: 'LocalBridge history save failed: $error', stackTrace: stack);
      }
    });
  }

  void _addHistory(HistoryItem h) {
    if (!cfg.keepHistory) return;
    history.insert(0, h);
    final lim = cfg.historyLimit;
    if (history.length > lim) history.removeRange(lim, history.length);
    _refreshHistoryCounts();
    _saveHistory();
  }

  void _refreshHistoryCounts() {
    _sentFiles = 0;
    _receivedFiles = 0;
    for (final record in history) {
      if (record.status != 'completed') continue;
      if (record.sent) {
        _sentFiles++;
      } else {
        _receivedFiles++;
      }
    }
  }

  void clearHistory() {
    history.clear();
    _refreshHistoryCounts();
    _saveHistory();
    _notify();
  }

  Future<void> _json(HttpRequest req, int code, Object body) async {
    req.response.statusCode = code;
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode(body));
    await req.response.close();
  }

  Future<void> _html(HttpRequest req, int code, String body) async {
    req.response.statusCode = code;
    req.response.headers.contentType = ContentType.html;
    req.response.write(body);
    await req.response.close();
  }

  /// True for addresses on your own network (or a trusted VPN such as
  /// Tailscale). Everything else is "remote" and needs the access key.
  static bool _isLocalAddr(InternetAddress a) {
    if (a.isLoopback || a.isLinkLocal) return true;
    final raw = a.rawAddress;
    if (raw.length != 4) return false;
    final b0 = raw[0], b1 = raw[1];
    return b0 == 10 ||
        (b0 == 172 && b1 >= 16 && b1 <= 31) ||
        (b0 == 192 && b1 == 168) ||
        (b0 == 100 && b1 >= 64 && b1 <= 127);
  }

  Future<void> _handle(HttpRequest req) async {
    try {
      final peer = req.connectionInfo?.remoteAddress;
      final path = req.uri.path;
      final segs = req.uri.pathSegments;
      final token = req.headers.value('x-lb-connection');
      final connected = token == null ? null : _connections[token];
      final approved = connected != null && connected.ip == peer?.address;
      final keyMatches = req.headers.value('x-lb-key') == cfg.remoteKey;
      final browserShare = (req.method == 'GET' || req.method == 'POST') &&
          segs.isNotEmpty && segs[0] == 's';
      if (token != null && !approved) {
        await _json(req, 403, {'error': 'connection ended'});
        return;
      }
      if (peer != null && !_isLocalAddr(peer) && !approved &&
          !(cfg.remoteEnabled && (keyMatches || browserShare))) {
        await _json(req, 403, {'error': 'remote access'});
        return;
      }
      if (browserShare) {
        await _onShare(req, segs);
      } else if (req.method == 'GET' && path == '/api/info') {
        if (!cfg.discoverable && !approved && !keyMatches) {
          await _json(req, 403, {'error': 'hidden'});
          return;
        }
        await _json(req, 200, {
          'app': kAppId,
          'alias': alias,
          'platform': Platform.operatingSystem,
          'deskId': cfg.deskId,
        });
      } else if (req.method == 'POST' && path == '/api/send-request') {
        await _onSendRequest(req, approved ? connected : null);
      } else if (req.method == 'POST' && path == '/api/connect' && peer != null) {
        await _onConnect(req, peer.address);
      } else if (path == '/api/chat-stream' && approved &&
          req.method == 'GET' && WebSocketTransformer.isUpgradeRequest(req)) {
        final socket = await WebSocketTransformer.upgrade(req, compression: CompressionOptions.compressionOff);
        _attachChatChannel(connected, socket)?.signalReady();
      } else if (req.method == 'POST' && path == '/api/disconnect' && approved) {
        _forgetConnection(connected);
        await _json(req, 200, {'ok': true});
      } else if (req.method == 'PUT' && path == '/api/upload') {
        await _onUpload(req);
      } else if (req.method == 'POST' && path == '/api/chat') {
        if (!approved) {
          await _json(req, 403, {'error': 'chat requires an approved connection'});
        } else {
          await _onChat(req, connected);
        }
      } else {
        await _json(req, 404, {'error': 'not found'});
      }
    } on FormatException {
      await _json(req, 400, {'error': 'invalid request'});
    } on TimeoutException {
      await _json(req, 408, {'error': 'request timed out'});
    } catch (e, stack) {
      debugPrintStack(label: 'LocalBridge request failed: $e', stackTrace: stack);
      try {
        await _json(req, 500, {'error': 'request failed'});
      } catch (_) {}
    }
  }

  Future<String> _readBody(HttpRequest req, {int limit = 128 * 1024}) async {
    final bytes = <int>[];
    await for (final chunk in req.timeout(const Duration(seconds: 10))) {
      if (chunk.length > limit - bytes.length) {
        throw const FormatException('Request body is too large');
      }
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  Future<void> _onConnect(HttpRequest req, String host) async {
    final body = jsonDecode(await _readBody(req, limit: 4096));
    final port = body is Map ? body['port'] : null;
    final token = body is Map ? body['token'] : null;
    if (body is Map && (body['deskId'] == cfg.deskId ||
        (body['target'] != null && body['target'] != cfg.deskId))) {
      await _json(req, 404, {'error': 'unknown desk'});
      return;
    }
    if (port is! int || port < 1 || port > 65535 ||
        token is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(token)) {
      await _json(req, 400, {'error': 'invalid connection'});
      return;
    }
    final device = Device(
      '${body['alias'] ?? host}', host, '${body['platform'] ?? ''}',
      port: port, remote: true, connectionToken: token, deskId: '${body['deskId'] ?? ''}',
    );
    if (_connections.containsKey(token) || pending != null) {
      await _json(req, 409, {'error': 'busy'});
      return;
    }
    if (!await _awaitDecision(IncomingRequest(device.alias, [], connection: true)) ||
        !online || _disposed) {
      await _json(req, 403, {'error': 'declined'});
      return;
    }
    _rememberConnection(device);
    await _json(req, 200, {
      'app': kAppId, 'alias': alias, 'platform': Platform.operatingSystem, 'deskId': cfg.deskId,
      'chatStream': true,
    });
  }

  void _rememberConnection(Device d) {
    final address = addressOf(d);
    final previous = devices[address];
    if (previous != null && previous.connectionToken.isNotEmpty) {
      _forgetConnection(previous);
    }
    _connections[d.connectionToken] = d;
    _hiddenDevices.remove(address);
    devices[address] = d;
    _chatPeers[address] = d;
    _notify();
  }

  void _forgetConnection(Device d) {
    _connections.remove(d.connectionToken);
    _chatChannels.remove(d.connectionToken)?.close();
    final address = addressOf(d);
    if (devices[address]?.connectionToken == d.connectionToken) devices.remove(address);
    _notify();
  }

  void _closeChatChannels() {
    final channels = _chatChannels.values.toList();
    _chatChannels.clear();
    for (final channel in channels) {
      channel.close();
    }
  }

  _ChatChannel? _attachChatChannel(Device peer, WebSocket socket) {
    final token = peer.connectionToken;
    if (_disposed || !online || !identical(_connections[token], peer)) {
      unawaited(socket.close());
      return null;
    }
    _chatChannels.remove(token)?.close();
    late final _ChatChannel channel;
    channel = _ChatChannel(socket, (message) => _receiveChat(peer, message), () {
      if (identical(_chatChannels[token], channel)) _forgetConnection(peer);
    });
    _chatChannels[token] = channel;
    return channel;
  }

  Future<void> _openChatChannel(String endpoint, Device peer, HttpClient client) async {
    var timedOut = false;
    try {
      final socket = await WebSocket.connect(
        'ws://$endpoint/api/chat-stream',
        headers: {'x-lb-connection': peer.connectionToken},
        compression: CompressionOptions.compressionOff,
        customClient: client,
      ).then((socket) async {
        if (timedOut) await socket.close();
        return socket;
      }).timeout(const Duration(seconds: 5));
      final channel = _attachChatChannel(peer, socket);
      if (channel != null && !await channel.waitUntilReady()) {
        channel.close();
      }
    } catch (_) {
      timedOut = true;
    }
  }

  Future<void> _disconnect(Device d) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await client.postUrl(Uri.parse('http://${addressOf(d)}/api/disconnect'));
      _identifyPeer(req, d);
      await (await req.close().timeout(const Duration(seconds: 3))).drain<void>();
    } catch (_) {
      // The other endpoint may already be offline.
    } finally {
      client.close(force: true);
    }
  }

  void _identifyPeer(HttpClientRequest request, Device d) {
    if (d.key.isNotEmpty) request.headers.set('x-lb-key', d.key);
    if (d.connectionToken.isNotEmpty) {
      request.headers.set('x-lb-connection', d.connectionToken);
    }
  }

  String _safeName(String name) {
    final sanitized = p.basename(name.replaceAll('\\', '/'))
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_')
        .trim()
        .replaceFirst(RegExp(r'[. ]+$'), '');
    if (sanitized.isEmpty) return 'file';
    if (RegExp(r'^(con|prn|aux|nul|com[0-9¹²³]|lpt[0-9¹²³])(\.|$)',
        caseSensitive: false).hasMatch(sanitized)) {
      return '_$sanitized';
    }
    return sanitized;
  }

  Future<bool> _awaitDecision(IncomingRequest r) async {
    pending = r;
    _notify();
    final ok = await r.decision.future.timeout(Duration(seconds: cfg.requestTimeout),
        onTimeout: () {
      resolve(r, false);
      return false;
    });
    pending = null;
    _notify();
    return ok;
  }

  ({bool verified, bool unverifiedClaim}) _verifySenderTrust(Device? connected, String from) {
    if (connected != null && cfg.isDeviceTrusted(connected) && !cfg.trusted.contains(from)) {
      return (verified: true, unverifiedClaim: false);
    }
    final claimsTrustedName = cfg.trusted.any(
      (e) => e == from || e.endsWith('|$from'),
    );
    return (verified: false, unverifiedClaim: claimsTrustedName);
  }

  Future<void> _onSendRequest(HttpRequest req, Device? connected) async {
    final decoded = jsonDecode(await _readBody(req));
    if (decoded is! Map<String, dynamic>) throw const FormatException('Invalid metadata');
    final body = decoded;
    final rawFiles = body['files'];
    if (rawFiles is! List || rawFiles.isEmpty || rawFiles.length > 256 ||
        rawFiles.any((f) => f is! Map || f['name'] is! String ||
            (f['name'] as String).length > 240 || f['size'] is! int ||
            (f['size'] as int) < 0 || (f['size'] as int) > 0x1FFFFFFFFFFFFF)) {
      throw const FormatException('Invalid file metadata');
    }
    final fileItems = rawFiles
        .map((e) => RequestFileItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final peerIp = req.connectionInfo?.remoteAddress.address;
    _sessions.removeWhere((_, s) => s.uploading.isEmpty && DateTime.now().isAfter(s.expires));
    if (peerIp == null || _sessions.length >= 64) {
      await _json(req, 503, {'error': 'transfer capacity reached'});
      return;
    }
    if (pending != null) {
      await _json(req, 409, {'error': 'busy'});
      return;
    }
    final from = connected?.alias ?? '${body['alias'] ?? req.connectionInfo?.remoteAddress.address}';
    final trustCheck = _verifySenderTrust(connected, from);

    // 2.1.0+: only verified trusted devices may send when trustedOnly is enabled
    // (if a device claims a trusted name without verified identity, reject if trustedOnly,
    // or require manual confirmation otherwise).
    if (cfg.trustedOnly && !trustCheck.verified) {
      await _json(req, 403, {'accepted': false});
      return;
    }
    if (cfg.maxReceiveMb > 0) {
      final total = fileItems.fold<int>(0, (a, f) => a + f.size);
      if (total > cfg.maxReceiveMb * 1024 * 1024) {
        await _json(req, 403, {'accepted': false});
        return;
      }
    }

    final fromTrusted = cfg.autoAcceptTrusted && trustCheck.verified;
    final mustPromptUnverified = trustCheck.unverifiedClaim && !trustCheck.verified;
    final ok = (!mustPromptUnverified && (cfg.autoAccept || fromTrusted))
        ? true
        : await _awaitDecision(
            IncomingRequest(
              from,
              fileItems,
              unverifiedTrustClaim: mustPromptUnverified,
            ),
          );
    if (!ok || !online || _disposed) {
      await _json(req, 403, {'accepted': false});
      return;
    }
    final rnd = Random.secure();
    final sid = List.generate(32, (_) => rnd.nextInt(16).toRadixString(16)).join();
    _sessions[sid] = _Session(
      fileItems.map((f) => _safeName(f.name)).toList(),
      fileItems.map((f) => f.size).toList(),
      from,
      peerIp,
      connected?.connectionToken,
    );
    await _json(req, 200, {'accepted': true, 'sessionId': sid});
  }

  void resolve(IncomingRequest r, bool ok) {
    if (!r.decision.isCompleted) r.decision.complete(ok);
  }

  Future<void> _onChat(HttpRequest req, Device connected) async {
    final text = await _readBody(req, limit: _ChatChannel.maxRequestBytes);
    final body = jsonDecode(text);
    final accepted = body is Map && _receiveChat(connected, body['text']);
    await _json(req, accepted ? 200 : 400, {'ok': accepted});
  }

  bool _receiveChat(Device connected, Object? text) {
    if (_disposed || !online || !identical(_connections[connected.connectionToken], connected) ||
        text is! String) {
      return false;
    }
    final msgText = text.trim();
    if (msgText.isEmpty) return false;
    final fromAlias = connected.alias;
    final address = addressOf(connected);
    messages.insert(
      0,
      ChatMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        sender: fromAlias,
        peerIp: address,
        text: msgText,
        time: DateTime.now(),
        outgoing: false,
      ),
    );
    if (messages.length > 200) messages.removeRange(200, messages.length);
    if (chatMutedUntil(address) == null) _buzz();
    _incomingNotice(
      cfg.tr('incomingMessage').replaceAll('{name}', fromAlias),
      msgText.length > 120 ? '${msgText.substring(0, 120)}…' : msgText,
      chatAddress: address,
    );
    _setStatus('Bridge Chat • $fromAlias: $msgText', StatusKind.info);
    _notify();
    return true;
  }

  Future<bool> sendChatMessage(Device? target, String text) async {
    final clean = text.trim();
    if (clean.isEmpty || !online) return false;
    final peerLabel = target == null ? cfg.tr('broadcastAll') : target.alias;
    final peerAddr = target == null ? 'broadcast' : addressOf(target);
    final targets = (target != null ? <Device>[target] : devices.values)
        .where((d) => d.connectionToken.isNotEmpty)
        .toList();
    if (targets.isEmpty) return false;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    var anyOk = false;
    try {
      final results = await Future.wait(targets.map((d) async {
        try {
          final channel = _chatChannels[d.connectionToken];
          if (channel != null) return await channel.send(clean);
          final port = d.port == 0 ? cfg.port : d.port;
          final req = await client.postUrl(Uri.parse('http://${d.ip}:$port/api/chat'));
          _identifyPeer(req, d);
          req.headers.contentType = ContentType.json;
          req.write(jsonEncode({'sender': alias, 'text': clean, 'port': cfg.port}));
          final resp = await req.close().timeout(const Duration(seconds: 4));
          await resp.drain<void>().timeout(const Duration(seconds: 4));
          return resp.statusCode == 200;
        } catch (_) {
          return false;
        }
      }));
      anyOk = results.contains(true);
      if (anyOk && online && !_disposed) {
        final now = DateTime.now();
        messages.insert(0, ChatMessage(
          id: '${now.microsecondsSinceEpoch}', sender: alias, peerIp: peerAddr,
          text: clean, time: now, outgoing: true,
        ));
        if (messages.length > 200) messages.removeRange(200, messages.length);
        _setStatus('Message sent to $peerLabel', StatusKind.success);
      }
    } finally {
      client.close(force: true);
      _notify();
    }
    return anyOk;
  }

  void clearChat() {
    messages.clear();
    _notify();
  }

  Future<Directory> defaultSaveDir() async {
    try {
      Directory? base;
      if (Platform.isAndroid) {
        final d = Directory('/storage/emulated/0/Download/$kAppName');
        try {
          await d.create(recursive: true);
          final t = File(p.join(d.path, '.write_test'));
          await t.writeAsString('x');
          await t.delete();
          return d;
        } catch (_) {}
        base = await getExternalStorageDirectory();
      } else {
        base = await getDownloadsDirectory();
      }
      base ??= await getApplicationDocumentsDirectory();
      final d = Directory(p.join(base.path, kAppName));
      await d.create(recursive: true);
      return d;
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  Future<Directory> _saveDir() async {
    if (cfg.saveDir.trim().isNotEmpty) {
      try {
        final d = Directory(cfg.saveDir.trim());
        await d.create(recursive: true);
        return d;
      } catch (_) {}
    }
    return defaultSaveDir();
  }

  String _pathKey(String path) => Platform.isWindows ? path.toLowerCase() : path;

  Future<File> _reserveUploadPath(Directory dir, String name) async {
    var f = File(p.join(dir.path, name));
    final overwrite = cfg.overwrite;
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var i = 1;
    while (!(overwrite || !await f.exists()) || !_reservedPaths.add(_pathKey(f.path))) {
      f = File(p.join(dir.path, '$base ($i)$ext'));
      i++;
    }
    return f;
  }

  /// Desktop only: shows the received file in the file manager.
  Future<void> _revealFile(File f) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,${f.path}']);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', f.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [f.parent.path]);
      }
    } catch (_) {}
  }

  static int _fnv1aUpdate(int hash, List<int> bytes) {
    var h = hash;
    for (var i = 0; i < bytes.length; i++) {
      h ^= (bytes[i] & 0xFF);
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  Future<void> _onUpload(HttpRequest req) async {
    final sid = req.uri.queryParameters['sessionId'];
    final idx = int.tryParse(req.uri.queryParameters['index'] ?? '');
    final s = sid == null ? null : _sessions[sid];
    if (s == null || idx == null || idx < 0 || idx >= s.names.length ||
        s.peerIp != req.connectionInfo?.remoteAddress.address ||
        s.connectionToken != req.headers.value('x-lb-connection') ||
        (s.uploading.isEmpty && DateTime.now().isAfter(s.expires))) {
      await _json(req, 403, {'error': 'invalid session'});
      return;
    }
    if (s.completed.contains(idx) || !s.uploading.add(idx)) {
      await _json(req, 409, {'error': 'file index already used'});
      return;
    }
    File? target;
    File? tempFile;
    RandomAccessFile? sink;
    final total = s.sizes[idx];
    var got = 0;
    var hash = 0x811C9DC5;
    final expectedHashHeader = req.headers.value('x-lb-fnv32');
    final sw = Stopwatch()..start();
    try {
      var dir = Directory(await (await _saveDir()).resolveSymbolicLinks());
      if (cfg.groupBySender) {
        final group = Directory(p.join(dir.path, _safeName(s.from)));
        await group.create(recursive: true);
        final resolved = await group.resolveSymbolicLinks();
        if (!p.isWithin(dir.path, resolved)) {
          throw const FileSystemException('Invalid receive directory');
        }
        dir = Directory(resolved);
      }
      target = await _reserveUploadPath(dir, s.names[idx]);
      tempFile = File(p.join(dir.path, '.localbridge-$sid-$idx.lbpart'));
      sink = await tempFile.open(mode: FileMode.write);
      await for (final chunk in req.timeout(const Duration(seconds: 30))) {
        got += chunk.length;
        if (total >= 0 && got > total) {
          throw FileSystemException(cfg.tr('stageIntegrityFailed'), target.path);
        }
        if (expectedHashHeader != null) hash = _fnv1aUpdate(hash, chunk);
        await sink.writeFrom(chunk);
        if (sw.elapsedMilliseconds > 100) {
          sw.reset();
          progress = total > 0 ? (got / total).clamp(0.0, 1.0) : null;
          _setStatus('Receiving from ${s.from}: ${p.basename(target.path)}');
          _notify();
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (got != total) {
        throw FileSystemException(cfg.tr('stageIntegrityFailed'), target.path);
      }
      if (expectedHashHeader != null && expectedHashHeader.isNotEmpty) {
        final actualHex = hash.toRadixString(16).padLeft(8, '0');
        if (actualHex.toLowerCase() != expectedHashHeader.trim().toLowerCase()) {
          throw FileSystemException(cfg.tr('stageIntegrityFailed'), target.path);
        }
      }

      if (!online || _disposed || !identical(_sessions[sid], s)) {
        throw const FileSystemException('Transfer cancelled');
      }
      await tempFile.rename(target.path);
      s.completed.add(idx);
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      progress = null;
      final errMsg = e is FileSystemException
          ? (e.message.isNotEmpty ? e.message : cfg.tr('stageDiskError'))
          : '${cfg.tr('stageTransferFailed')} ($e)';
      _setStatus(errMsg, StatusKind.error);
      _addHistory(
        HistoryItem(
          s.names[idx],
          got,
          false,
          s.from,
          DateTime.now(),
          null,
          status: 'failed',
        ),
      );
      _notify();
      try {
        await _json(req, 400, {'ok': false, 'error': errMsg});
      } catch (_) {}
      return;
    } finally {
      if (target != null) _reservedPaths.remove(_pathKey(target.path));
      s.uploading.remove(idx);
      s.expires = DateTime.now().add(const Duration(minutes: 15));
    }
    final allDone = s.completed.length == s.names.length;
    if (allDone) _sessions.remove(sid);
    progress = null;
    final savedMsg = cfg.tr('stageSavedTo').replaceAll('{path}', target.path);
    _setStatus(savedMsg, StatusKind.success);
    _buzz();
    _addHistory(
      HistoryItem(
        p.basename(target.path),
        got,
        false,
        s.from,
        DateTime.now(),
        target.path,
        status: 'completed',
      ),
    );
    _incomingNotice(
      cfg.tr('incomingFile').replaceAll('{name}', s.from),
      '${p.basename(target.path)}\n$savedMsg',
    );
    _notify();
    await _json(req, 200, {'ok': true, 'size': got});
    if (allDone && cfg.openAfterReceive) _revealFile(target);
  }

  Future<void> startShare(List<PlatformFile> files) async {
    if (!online) return;
    try {
      List<PlatformFile> filteredFiles = files;
      if (cfg.allowedExtensionFilter.trim().isNotEmpty) {
        final allowed = cfg.allowedExtensionFilter
            .toLowerCase()
            .split(',')
            .map((e) => e.trim().replaceAll('.', ''))
            .toSet();
        filteredFiles = files.where((f) {
          final ext = p.extension(f.name).toLowerCase().replaceAll('.', '');
          return allowed.contains(ext);
        }).toList();
      }

      if (filteredFiles.isEmpty) {
        _setStatus('No files matched extension filter', StatusKind.error);
        _notify();
        return;
      }

      final sizes = <int>[];
      for (final f in filteredFiles) {
        final n = f.lengthSync() ?? await f.length();
        if (n == null) throw 'Could not read file size: ${f.name}';
        sizes.add(n);
      }
      final rnd = Random.secure();
      final token = List.generate(10, (_) => rnd.nextInt(16).toRadixString(16)).join();
      final pin = cfg.sharePin.trim();
      share = ShareSession(token, filteredFiles, sizes, pin.isEmpty ? null : pin);
      _shareTimer?.cancel();
      if (cfg.shareMinutes > 0) {
        _shareTimer = Timer(Duration(minutes: cfg.shareMinutes), stopShare);
      }
      myIps
        ..clear()
        ..addAll(await _localIps());
    } catch (e) {
      _setStatus('Error: $e', StatusKind.error);
    }
    _notify();
  }

  void stopShare() {
    _shareTimer?.cancel();
    _shareTimer = null;
    share = null;
    _notify();
  }

  Future<void> _onShare(HttpRequest req, List<String> segs) async {
    final s = share;
    if (s == null || segs.length < 2 || segs[1] != s.token) {
      await _html(req, 404,
          _page('<h1>$kAppName</h1><p>This link is no longer active.</p>'));
      return;
    }
    final ip = req.connectionInfo?.remoteAddress.address ?? '';

    final response = req.response;
    response.headers.set('cache-control', 'no-store');
    response.headers.set('referrer-policy', 'no-referrer');
    final cookieName = 'lb_share_${s.token}';
    final browserId = req.cookies
        .where((cookie) => cookie.name == cookieName)
        .map((cookie) => cookie.value)
        .firstOrNull;
    final authorized = browserId != null && s.allowed.contains(browserId);

    if (req.method == 'GET' && segs.length == 4 && segs[2] == 'f') {
      final idx = int.tryParse(segs[3]);
      if (!authorized || idx == null || idx < 0 || idx >= s.files.length) {
        await req.response.redirect(Uri(path: '/s/${s.token}'));
        return;
      }
      final limit = cfg.oneTimeDownload ? 1 : cfg.maxDownloads;
      if (limit > 0 && s.downloads + s.activeDownloads >= limit) {
        await _html(req, 409, _page('<p>Download limit reached.</p>'));
        return;
      }
      s.activeDownloads++;
      final f = s.files[idx];
      final len = s.sizes[idx];
      final out = req.response;
      out.statusCode = 200;
      out.headers.contentType = ContentType.binary;
      out.headers.contentLength = len;
      out.headers.set('content-disposition',
          "attachment; filename*=UTF-8''${Uri.encodeComponent(f.name)}");
      var sent = 0;
      final sw = Stopwatch()..start();
      try {
        await out.addStream(f.readAsByteStream().map((chunk) {
          sent += chunk.length;
          if (sw.elapsedMilliseconds > 100) {
            sw.reset();
            progress = len > 0 ? (sent / len).clamp(0.0, 1.0) : null;
            _setStatus('Sending ${f.name} to $ip');
            _notify();
          }
          return chunk;
        }));
        await out.close();
        s.downloads++;
        progress = null;
        _setStatus('${f.name} downloaded by $ip', StatusKind.success);
        _addHistory(HistoryItem(f.name, len, true, 'Browser ($ip)', DateTime.now(), null));

        if (identical(share, s) && limit > 0 && s.downloads >= limit) stopShare();
      } catch (e) {
        progress = null;
        _setStatus('Download interrupted: ${f.name}', StatusKind.error);
        try {
          await out.close();
        } catch (_) {}
      } finally {
        s.activeDownloads--;
      }
      _notify();
      return;
    }

    if (!authorized) {
      if (s.pin != null) {
        final limit = cfg.pinAttempts;
        if (limit > 0 && (s.pinFails[ip] ?? 0) >= limit) {
          await _html(
            req,
            429,
            _page('<h1>$kAppName</h1><p>Too many wrong PIN attempts. This browser is blocked.</p>'),
          );
          return;
        }
        final given = req.method == 'POST'
            ? Uri.splitQueryString(await _readBody(req, limit: 1024))['pin']
            : null;
        if (given != s.pin) {
          final wrong = given != null;
          if (wrong) s.pinFails[ip] = (s.pinFails[ip] ?? 0) + 1;
          await _html(
            req,
            wrong ? 401 : 200,
            _page('<h1>$kAppName</h1><p>${wrong ? 'Wrong PIN. Try again.' : 'Enter the PIN to continue.'}</p>'
                '<form method="post"><input name="pin" type="password" inputmode="numeric" autofocus> <button>Open</button></form>'),
          );
          return;
        }
      }
      if (cfg.askShare) {
        if (pending != null) {
          await _html(req, 409,
              _page('<h1>$kAppName</h1><p>The owner is busy with another request. Refresh in a moment.</p>'));
          return;
        }
        final browserFiles = [
          for (var i = 0; i < s.files.length; i++)
            RequestFileItem(s.files[i].name, s.sizes[i])
        ];
        final r = IncomingRequest('Browser ($ip)', browserFiles, download: true);
        final ok = await _awaitDecision(r);
        if (!ok) {
          await _html(req, 403,
              _page('<h1>$kAppName</h1><p>The owner declined your request.</p>'));
          return;
        }
      }
      if (!identical(share, s) || s.allowed.length >= 256) {
        await _html(req, 409, _page('<p>This share is unavailable.</p>'));
        return;
      }
      final random = Random.secure();
      final session = List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
      s.allowed.add(session);
      response.cookies.add(Cookie(cookieName, session)
        ..httpOnly = true
        ..sameSite = SameSite.strict
        ..path = '/s/${s.token}');
      if (req.method == 'POST') {
        await response.redirect(Uri(path: '/s/${s.token}'), status: 303);
        return;
      }
    }

    final rows = StringBuffer();
    for (var i = 0; i < s.files.length; i++) {
      rows.write('<div class="card"><div><div class="name">${_esc(s.files[i].name)}</div>'
          '<div class="size">${fmtSize(s.sizes[i])}</div></div>'
          '<a class="btn" href="/s/${s.token}/f/$i">Download</a></div>');
    }
    final msg = cfg.shareMessage.trim();
    final msgHtml = msg.isEmpty ? '' : '<p class="msg">${_esc(msg)}</p>';
    await _html(req, 200,
        _page('<h1>${_esc(alias)} shared ${s.files.length} file${s.files.length == 1 ? '' : 's'}</h1>$msgHtml$rows'));
  }

  /// Scan tuning for the "Scan speed" setting. More workers and shorter
  /// timeouts find devices sooner but send more requests at once.
  ({int workers, int connectMs, int sweepSec}) get _tune {
    switch (cfg.scanSpeed) {
      case 2: // turbo: everything at once, full sweep on every auto scan
        return (workers: 254, connectMs: 300, sweepSec: 0);
      case 1: // fast
        return (workers: 128, connectMs: 450, sweepSec: 15);
      default: // balanced
        return (workers: 48, connectMs: 700, sweepSec: 30);
    }
  }

  /// Timer scan: only re-checks known devices, and sweeps the whole network
  /// every few seconds depending on the scan speed.
  void _autoScan() {
    final sweep = _tune.sweepSec;
    final last = _lastSweep;
    final due = last == null || sweep == 0 || DateTime.now().difference(last).inSeconds >= sweep;
    scan(full: due, auto: true);
  }

  Future<Device?> _probe(HttpClient c, String ip) async {
    try {
      final r = await c.getUrl(Uri.parse('http://$ip:${cfg.port}/api/info'));
      final resp = await r.close().timeout(const Duration(seconds: 2));
      final text = await utf8.decoder.bind(resp).join().timeout(const Duration(seconds: 2));
      final j = jsonDecode(text);
      if (j is! Map) return null;
      if (j['app'] != kAppId && j['app'] != 'localdrop') return null;
      return Device('${j['alias']}', ip, '${j['platform'] ?? ''}',
          deskId: '${j['deskId'] ?? ''}');
    } catch (_) {
      return null;
    }
  }

  // ---- remote devices & AnyDesk-style Bridge Code (other networks or LAN)

  /// Converts an IPv4 address (e.g. `192.168.1.104`) into a 10-digit AnyDesk-style
  /// Bridge Code formatted in groups (`323 223 5880`).
  static String ipToBridgeCode(String ip) {
    final parts = ip.trim().split('.');
    if (parts.length == 4) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      final c = int.tryParse(parts[2]);
      final d = int.tryParse(parts[3]);
      if (a != null && b != null && c != null && d != null &&
          a >= 0 && a <= 255 && b >= 0 && b <= 255 && c >= 0 && c <= 255 && d >= 0 && d <= 255) {
        final n = ((a << 24) | (b << 16) | (c << 8) | d) & 0xFFFFFFFF;
        final s = n.toString().padLeft(10, '0');
        return '${s.substring(0, 3)} ${s.substring(3, 6)} ${s.substring(6)}';
      }
    }
    return ip;
  }

  String get deskCode {
    if (!online || !serverUp) return '';
    final id = cfg.deskId;
    return '${id.substring(0, 4)}-${id.substring(4)}';
  }

  ({String host, int port})? parseAddress(String raw) {
    var t = raw.trim().replaceAll(RegExp(r'^https?://'), '');
    t = t.split('/').first.split('#').first.split('|').first.trim();
    if (t.isEmpty) return null;

    var host = t;
    var port = cfg.port;
    final i = t.lastIndexOf(':');
    if (i > 0) {
      host = t.substring(0, i).trim();
      port = int.tryParse(t.substring(i + 1)) ?? -1;
    }
    if (port < 1 || port > 65535) return null;

    final compactDigits = host.replaceAll(RegExp(r'[\s\-]'), '');
    if (RegExp(r'^\d{7,10}$').hasMatch(compactDigits)) {
      final n = int.tryParse(compactDigits);
      if (n != null && n > 0 && n <= 0xFFFFFFFF) {
        final a = (n >> 24) & 0xFF;
        final b = (n >> 16) & 0xFF;
        final c = (n >> 8) & 0xFF;
        final d = n & 0xFF;
        return (host: '$a.$b.$c.$d', port: i > 0 ? port : kDefaultPort);
      }
      return null;
    }
    if (!RegExp(r'^[A-Za-z0-9.\-]+$').hasMatch(host)) return null;
    return (host: host, port: port);
  }

  Future<({Device? dev, String err})> _probeRemote(
      HttpClient c, String host, int port, String key, {String connectionToken = ''}) async {
    try {
      final r = await c.getUrl(Uri.parse('http://$host:$port/api/info'));
      if (key.isNotEmpty) r.headers.set('x-lb-key', key);
      if (connectionToken.isNotEmpty) r.headers.set('x-lb-connection', connectionToken);
      final resp = await r.close().timeout(const Duration(seconds: 4));
      final text = await utf8.decoder.bind(resp).join().timeout(const Duration(seconds: 3));
      if (resp.statusCode == 403) return (dev: null, err: 'denied');
      final j = jsonDecode(text);
      if (j is! Map || j['app'] != kAppId) return (dev: null, err: 'unreach');
      return (
        dev: Device('${j['alias']}', host, '${j['platform'] ?? ''}',
            port: port, key: key, remote: true),
        err: ''
      );
    } catch (_) {
      return (dev: null, err: 'unreach');
    }
  }

  /// Saves a device on another network. Returns null on success or an error
  /// code: 'bad' (address), 'unreach' (no answer) or 'denied' (wrong key).
  Future<({Device? device, String? error})> connectDesk(String address, [String key = '']) =>
      _connectDesk(address, key, saveDevice: true);

  Future<({Device? device, String? error})> connectChat(Device device) =>
      _connectDesk(addressOf(device), device.key, saveDevice: false);

  Future<({Device? device, String? error})> _connectDesk(
    String address,
    String key, {
    required bool saveDevice,
  }) async {
    final separator = address.indexOf('#');
    if (separator >= 0) {
      key = address.substring(separator + 1);
      address = address.substring(0, separator);
    }
    if (!online || !serverUp) return (device: null, error: 'deskOffline');
    final code = address.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    final isDeskCode = RegExp(r'^[A-Z2-9]{8}$').hasMatch(code);
    if (code == cfg.deskId) return (device: null, error: 'deskOwnCodeError');
    final a = isDeskCode ? await _findDesk(code) : parseAddress(address);
    if (a == null && isDeskCode) return (device: null, error: 'deskNotFound');
    if (a == null || (a.port == cfg.port &&
        (myIps.contains(a.host) || a.host == '127.0.0.1' || a.host == 'localhost'))) {
      return (device: null, error: 'remoteBadAddr');
    }
    if (!online || !serverUp || _disposed) return (device: null, error: 'deskOffline');
    final generation = _networkGeneration;
    final endpoint = '${a.host}:${a.port}';
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      key = key.trim().toUpperCase();
      final random = Random.secure();
      final token = List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
      final req = await c.postUrl(Uri.parse('http://$endpoint/api/connect'));
      if (key.isNotEmpty) req.headers.set('x-lb-key', key);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'alias': alias, 'port': cfg.port, 'platform': Platform.operatingSystem, 'token': token,
        'deskId': cfg.deskId, if (isDeskCode) 'target': code,
      }));
      final resp = await req.close().timeout(const Duration(seconds: 150));
      final body = await utf8.decoder.bind(resp).join().timeout(const Duration(seconds: 5));
      if (resp.statusCode != 200) {
        return (device: null, error: switch (resp.statusCode) {
          403 => 'deskDeclined',
          404 => 'deskUpdateRequired',
          409 => 'deskBusy',
          _ => 'remoteUnreach',
        });
      }
      final result = jsonDecode(body);
      if (_disposed || !online || generation != _networkGeneration ||
          result is! Map || result['app'] != kAppId ||
          (isDeskCode && result['deskId'] != code)) {
        return (device: null, error: 'remoteUnreach');
      }
      final d = Device('${result['alias'] ?? a.host}', a.host, '${result['platform'] ?? ''}',
          port: a.port, key: key, remote: true, connectionToken: token,
          deskId: '${result['deskId'] ?? ''}');
      _rememberConnection(d);
      if (result['chatStream'] == true) {
        await _openChatChannel(endpoint, d, c);
      }
      if (!identical(_connections[token], d)) {
        return (device: null, error: 'remoteUnreach');
      }
      if (saveDevice) {
        cfg.update(() {
          cfg.remotes.removeWhere((r) => r['host'] == a.host && _savedPort(r) == a.port);
          cfg.remotes.add({
            'host': a.host, 'port': a.port, 'key': d.key, 'alias': d.alias, 'deskId': d.deskId,
          });
        }, storageDirectory: storageDirectory);
      }
      return (device: d, error: null);
    } catch (_) {
      return (device: null, error: 'remoteUnreach');
    } finally {
      c.close(force: true);
    }
  }

  int _savedPort(Map<String, dynamic> remote) => (remote['port'] as int?) ?? cfg.port;

  void removeRemote(String host, int port) {
    final address = '$host:$port';
    _hiddenDevices.add(address);
    final device = devices[address];
    if (device != null && device.connectionToken.isNotEmpty) {
      final streamed = _chatChannels.containsKey(device.connectionToken);
      _forgetConnection(device);
      if (!streamed) unawaited(_disconnect(device));
    } else {
      devices.remove(address);
    }
    _chatPeers.remove(address);
    _miss.remove(address);
    if (port == cfg.port && _known.remove(host) != null) unawaited(_writeKnown());
    if (cfg.remotes.any((r) => r['host'] == host && _savedPort(r) == port)) {
      cfg.update(() => cfg.remotes.removeWhere((r) => r['host'] == host && _savedPort(r) == port),
          storageDirectory: storageDirectory);
    }
    _notify();
  }

  void removeDevice(Device d) => removeRemote(d.ip, d.port == 0 ? cfg.port : d.port);

  /// Your public IP address (only asked when you tap the button).
  Future<String?> fetchPublicIp() async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final r = await c.getUrl(Uri.parse('https://api.ipify.org'));
      final resp = await r.close().timeout(const Duration(seconds: 6));
      final t = (await utf8.decoder.bind(resp).join()).trim();
      return RegExp(r'^[0-9a-fA-F:.]{3,45}$').hasMatch(t) ? t : null;
    } catch (_) {
      return null;
    } finally {
      c.close(force: true);
    }
  }

  /// Probes [ips] with a fixed number of workers that each grab the next
  /// address as soon as they finish (no waiting for the slowest one).
  Future<void> _probeAll(HttpClient c, Iterable<String> ips, int workers,
      void Function(Device) onFound) async {
    final it = ips.iterator;
    final generation = _networkGeneration;
    Future<void> worker() async {
      while (online && !_disposed && generation == _networkGeneration && it.moveNext()) {
        final d = await _probe(c, it.current);
        if (d != null) onFound(d);
      }
    }

    final n = max(1, min(workers, ips.length));
    await Future.wait([for (var i = 0; i < n; i++) worker()]);
  }

  /// [full] sweeps the whole network, otherwise only known devices are checked.
  /// [auto] marks timer scans, which tolerate one missed answer before a
  /// device disappears from the list.
  Future<void> scan({bool full = true, bool auto = false}) async {
    if (scanning || !online || _disposed || (auto && _appBackgrounded)) return;
    final generation = _networkGeneration;
    scanning = true;
    _notify();
    final t = _tune;
    final patient = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 900)
      ..idleTimeout = const Duration(seconds: 1);
    try {
      final mine = await _localIps();
      if (generation != _networkGeneration) return;
      myIps
        ..clear()
        ..addAll(mine);
      final mineSet = mine.toSet();
      final prefixes = <String>[];
      for (final ip in mine) {
        final parts = ip.split('.');
        if (parts.length != 4) continue;
        final pre = parts.sublist(0, 3).join('.');
        if (!prefixes.contains(pre) && prefixes.length < 4) prefixes.add(pre);
      }

      final found = <String, Device>{};
      void onFound(Device d) {
        if (!online || _disposed || generation != _networkGeneration) return;
        final address = addressOf(d);
        if (_hiddenDevices.contains(address)) return;
        found[address] = d;
        _miss.remove(address);
        final old = devices[address];
        if (old?.connectionToken.isNotEmpty ?? false) return;
        if (old == null || old.alias != d.alias || old.platform != d.platform ||
            (d.remote && (!old.remote || old.key != d.key))) {
          devices[address] = d;
          _notify();
        }
      }

      final connected = _connections.values.toList();
      await Future.wait(connected.map((device) async {
        final address = addressOf(device);
        if (_chatChannels.containsKey(device.connectionToken)) {
          onFound(device);
          return;
        }
        final alive = await _probeRemote(patient, device.ip,
            device.port == 0 ? cfg.port : device.port, device.key,
            connectionToken: device.connectionToken);
        if (generation != _networkGeneration ||
            devices[address]?.connectionToken != device.connectionToken) {
          return;
        }
        if (alive.dev != null) {
          onFound(device);
        } else if (!auto || (_miss[address] ?? 0) >= 1) {
          _miss.remove(address);
          _forgetConnection(device);
        } else {
          _miss[address] = 1;
        }
      }));
      if (generation != _networkGeneration) return;

      // 1) devices we already know answer first (short and cheap)
      final known = <String>{...devices.values.where((d) => !d.remote).map((d) => d.ip),
        ..._known.keys}..removeAll(mineSet);
      known.removeWhere((ip) => !prefixes.any((pre) => ip.startsWith('$pre.')));
      await _probeAll(patient, known, 32, onFound);
      if (generation != _networkGeneration) return;

      // 1b) saved remote devices (other networks)
      await Future.wait([
        for (final r in List<Map<String, dynamic>>.of(cfg.remotes))
          () async {
            final res = await _probeRemote(
                patient, '${r['host']}', (r['port'] as int?) ?? cfg.port, '${r['key'] ?? ''}');
            if (res.dev != null) onFound(res.dev!);
          }()
      ]);
      if (generation != _networkGeneration) return;

      await Future.wait(_chatPeers.entries.toList().map((entry) async {
        if (found.containsKey(entry.key) || _hiddenDevices.contains(entry.key) ||
            devices[entry.key]?.connectionToken.isNotEmpty == true ||
            cfg.remotes.any((r) => '${r['host']}:${_savedPort(r)}' == entry.key)) {
          return;
        }
        final peer = entry.value;
        final result = await _probeRemote(
          patient, peer.ip, peer.port == 0 ? cfg.port : peer.port, peer.key,
        );
        if (result.dev case final device?) onFound(device);
      }));
      if (generation != _networkGeneration) return;

      // 2) then everything else on the network(s) — offloaded via a top-level
      // Isolate runner so `this` (DropService) is never captured in the closure.
      if (full) {
        final rest = <String>[
          for (final pre in prefixes)
            for (var n = 1; n < 255; n++)
              if (!known.contains('$pre.$n') && !mineSet.contains('$pre.$n')) '$pre.$n',
        ];
        if (rest.isNotEmpty) {
          final rawDevices = await _runSubnetSweepInIsolate(
            rest,
            cfg.port,
            t.connectMs,
            min(t.workers, 64),
          );
          if (!online || _disposed || generation != _networkGeneration) return;
          for (final item in rawDevices) {
            onFound(
              Device(
                item['alias'] ?? '',
                item['ip'] ?? '',
                item['platform'] ?? '',
                deskId: item['deskId'] ?? '',
              ),
            );
          }
        }
        _lastSweep = DateTime.now();
      }
      if (!online || _disposed || generation != _networkGeneration) return;

      // forget devices that stopped answering
      for (final address in devices.keys.toList()) {
        if (found.containsKey(address) || devices[address]!.connectionToken.isNotEmpty ||
            _hiddenDevices.contains(address)) {
          continue;
        }
        final m = (_miss[address] ?? 0) + 1;
        if (auto && m < 2) {
          _miss[address] = m;
          continue;
        }
        devices.remove(address);
        _miss.remove(address);
      }
      _saveKnown();
    } catch (e) {
      _setStatus('Scan error: $e', StatusKind.error);
    } finally {
      patient.close(force: true);
      if (generation == _networkGeneration) {
        scanning = false;
        _notify();
        if (_rescanRequested) {
          _rescanRequested = false;
          unawaited(rescan());
        }
      }
    }
  }

  Future<void> sendFiles(Device d, List<PlatformFile> files) async {
    final staged = <StagedFileItem>[];
    for (var i = 0; i < files.length; i++) {
      final f = files[i];
      final n = f.lengthSync() ?? await f.length();
      if (n == null) {
        _setStatus('${cfg.tr('stageProviderError')} (${f.name})', StatusKind.error);
        _notify();
        return;
      }
      staged.add(
        StagedFileItem(
          id: 'pf:$i:${f.name}:$n',
          name: f.name,
          size: n,
          path: f.path,
          streamFactory: () => f.readAsByteStream(),
        ),
      );
    }
    await sendStagedFiles(d, staged);
  }

  void cancelOutgoingTransfer() {
    final client = _outgoingTransfer;
    if (client == null) return;
    _sendCancelled = true;
    client.close(force: true);
  }

  Future<bool> sendStagedFiles(
    Device d,
    List<StagedFileItem> files, {
    void Function(int currentIdx, int sentCount)? onProgress,
  }) async {
    if (!online || files.isEmpty || _outgoingTransfer != null) return false;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    _outgoingTransfer = client;
    _sendCancelled = false;
    try {
      _setStatus('Waiting for ${d.alias} to accept…');
      progress = null;
      _notify();
      final sizes = <int>[for (final f in files) f.size];
      final port = d.port == 0 ? cfg.port : d.port;
      final req = await client.postUrl(Uri.parse('http://${d.ip}:$port/api/send-request'));
      _identifyPeer(req, d);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'alias': alias,
        'deskId': cfg.deskId,
        'files': [
          for (var i = 0; i < files.length; i++)
            {'name': files[i].name, 'size': sizes[i]}
        ],
      }));
      final resp = await req.close().timeout(const Duration(seconds: 150));
      final text = await utf8.decoder.bind(resp).join().timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        final declined = resp.statusCode == 403;
        _setStatus(
          declined ? 'The other device declined' : 'Error: ${resp.statusCode} $text',
          StatusKind.error,
        );
        return false;
      }
      final sid = (jsonDecode(text) as Map)['sessionId'] as String;
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final len = sizes[i];
        onProgress?.call(i, i);
        final up = await client
            .putUrl(Uri.parse('http://${d.ip}:$port/api/upload?sessionId=$sid&index=$i'));
        _identifyPeer(up, d);
        up.contentLength = len;
        var sent = 0;
        var lastPct = -1;
        await up.addStream(f.openReadStream().timeout(const Duration(seconds: 30)).map((chunk) {
          sent += chunk.length;
          final pct = len > 0 ? (sent * 100 ~/ len) : 0;
          if (pct != lastPct) {
            lastPct = pct;
            progress = len > 0 ? (sent / len).clamp(0.0, 1.0) : null;
            _setStatus('Sending (${i + 1}/${files.length}): ${f.name}');
            _notify();
          }
          return chunk;
        })).timeout(const Duration(hours: 6));
        if (sent != len) {
          throw FileSystemException(cfg.tr('stageIntegrityFailed'), f.name);
        }
        final r2 = await up.close().timeout(const Duration(seconds: 30));
        final r2Body = await utf8.decoder.bind(r2).join().timeout(const Duration(seconds: 10));
        if (r2.statusCode != 200) {
          throw 'Upload failed (${r2.statusCode}): $r2Body';
        }
        onProgress?.call(i, i + 1);
        _addHistory(
          HistoryItem(
            f.name,
            len,
            true,
            d.alias,
            DateTime.now(),
            f.path,
            status: 'completed',
          ),
        );
      }
      _setStatus(
          '${files.length} file${files.length == 1 ? '' : 's'} sent to ${d.alias}',
          StatusKind.success);
      _buzz();
      return true;
    } catch (e) {
      _setStatus(_sendCancelled ? cfg.tr('stageTransferCancelled') : 'Error: $e', StatusKind.error);
      return false;
    } finally {
      progress = null;
      client.close(force: true);
      _outgoingTransfer = null;
      _notify();
    }
  }
}

/// Top-level isolate launcher — kept outside [DropService] so Dart's closure
/// context never captures `this` (`DropService` instance).
Future<List<Map<String, String>>> _runSubnetSweepInIsolate(
  List<String> ips,
  int port,
  int connectMs,
  int workers,
) {
  return Isolate.run(
    () => _sweepSubnetIsolateWorker(ips, port, connectMs, workers),
  );
}

Future<List<Map<String, String>>> _sweepSubnetIsolateWorker(
  List<String> ips,
  int port,
  int connectMs,
  int workers,
) async {
  final found = <Map<String, String>>[];
  if (ips.isEmpty) return found;
  final client = HttpClient()
    ..connectionTimeout = Duration(milliseconds: connectMs)
    ..idleTimeout = const Duration(seconds: 1);
  try {
    final it = ips.iterator;
    Future<void> worker() async {
      while (it.moveNext()) {
        final ip = it.current;
        try {
          final req = await client.getUrl(
            Uri.parse('http://$ip:$port/api/info'),
          );
          final resp = await req.close().timeout(
                const Duration(milliseconds: 1200),
              );
          final text = await utf8.decoder
              .bind(resp)
              .join()
              .timeout(const Duration(milliseconds: 1200));
          final j = jsonDecode(text);
          if (j is Map && (j['app'] == kAppId || j['app'] == 'localdrop')) {
            found.add({
              'alias': '${j['alias']}',
              'ip': ip,
              'platform': '${j['platform'] ?? ''}',
              'deskId': '${j['deskId'] ?? ''}',
            });
          }
        } catch (_) {}
      }
    }

    final n = max(1, min(workers, ips.length));
    await Future.wait([for (var i = 0; i < n; i++) worker()]);
  } finally {
    client.close(force: true);
  }
  return found;
}

// -------------------------------------------------------------------- UI

const Color kBg = Color(0xFF121215);
const Color kCard = Color(0xFF1C1C22);
const Color kCard2 = Color(0xFF17171B);
const Color kLine = Color(0xFF2D2D37);
const Color kLineBright = Color(0xFF3E3E4C);

LinearGradient _actionGradient(Color accent, {double strength = 1}) {
  final secondary = EditorialPalette.deriveSecondaryAccent(accent);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(kCard, accent, 0.90 * strength)!,
      Color.lerp(kCard, Color.lerp(accent, secondary, 0.52), 0.92 * strength)!,
    ],
  );
}

/// Editorial Atelier card decoration: warm surface tone, subtle top highlight,
/// controlled studio shadow, and crisp 1px border.
/// Context-aware editorial card decoration that adapts to Light, Warm Dark, and AMOLED.
BoxDecoration _editorialCardDeco(
  BuildContext context, {
  double r = 22,
  bool elevated = false,
  bool tinted = false,
  Color? borderColor,
  Color? glow,
}) {
  final p = EditorialTheme.of(context);
  final base = tinted
      ? p.cardTinted
      : elevated
          ? p.cardElevated
          : p.card;
  return BoxDecoration(
    color: base,
    borderRadius: BorderRadius.circular(r),
    border: Border.all(color: borderColor ?? p.border, width: 1),
    boxShadow: [
      ...p.cardShadow,
      if (glow != null) ...p.accentGlow(0.16),
    ],
  );
}

/// Desktop hover effect: the child grows a little, gets a soft glow, a small
/// light that follows the mouse inside it, and the cursor turns into a hand.
/// Does nothing on touch screens.
class _Hover extends StatefulWidget {
  final Widget child;
  final double scale;
  final double radius;
  final bool enabled;
  final bool glow;
  final bool spotlight;
  final bool clickable;

  /// Set from the "Hover effects" setting.
  static bool fx = true;
  const _Hover({
    required this.child,
    this.scale = 1.015,
    this.radius = 20,
    this.enabled = true,
    this.glow = true,
    this.spotlight = true,
    this.clickable = true,
  });

  @override
  State<_Hover> createState() => _HoverState();
}

class _HoverState extends State<_Hover> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final on = _hover && widget.enabled && _Hover.fx;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion ? Duration.zero : const Duration(milliseconds: 160);
    return MouseRegion(
      cursor: (widget.enabled && widget.clickable)
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) {
        if (!_hover) setState(() => _hover = true);
      },
      onExit: (_) {
        if (_hover) setState(() => _hover = false);
      },
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: (on && widget.glow)
              ? [
                  BoxShadow(
                    color: cs.primary.withAlpha(36),
                    blurRadius: 18,
                    spreadRadius: -2,
                  ),
                ]
              : const <BoxShadow>[],
        ),
        child: AnimatedScale(
          scale: on && !reducedMotion ? widget.scale : 1.0,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: _PointerLight(
            enabled: widget.enabled && _Hover.fx && widget.spotlight,
            color: cs.primary.withAlpha(54),
            radius: 90,
            borderRadius: BorderRadius.circular(widget.radius),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

bool _fxFrom(Settings st) {
  _Hover.fx = st.hoverFx;
  return st.mouseGlow;
}

/// Vertical page scroll with its OWN controller and scroll bar.
class _PageScroll extends StatefulWidget {
  final List<Widget> slivers;
  const _PageScroll({required this.slivers});

  @override
  State<_PageScroll> createState() => _PageScrollState();
}

class _PageScrollState extends State<_PageScroll> {
  final ScrollController _c = ScrollController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Scrollbar(
        controller: _c,
        interactive: true,
        thickness: 5,
        radius: const Radius.circular(8),
        child: CustomScrollView(
          controller: _c,
          primary: false,
          slivers: widget.slivers,
        ),
      ),
    );
  }
}

class _CursorGlow extends StatelessWidget {
  final Widget child;
  final Color color;
  final bool follow;
  final double level;
  const _CursorGlow({
    required this.child,
    required this.color,
    this.follow = true,
    this.level = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    return ColoredBox(
      color: p.canvas,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: StudioCanvasBackgroundPainter(palette: p),
            ),
          ),
          _PointerLight(
            enabled: follow && level > 0,
            color: Color.lerp(color, p.isDark ? Colors.white : p.accent, 0.55)!
                .withValues(alpha: (level * (p.isDark ? 0.12 : 0.09)).clamp(0.0, 1.0)),
            radius: 152,
            behindChild: true,
            child: RepaintBoundary(child: child),
          ),
        ],
      ),
    );
  }
}

class _PointerLight extends StatefulWidget {
  final bool enabled;
  final Color color;
  final double radius;
  final BorderRadius? borderRadius;
  final bool behindChild;
  final Widget child;

  const _PointerLight({
    required this.enabled,
    required this.color,
    required this.radius,
    this.borderRadius,
    this.behindChild = false,
    required this.child,
  });

  @override
  State<_PointerLight> createState() => _PointerLightState();
}

class _PointerLightState extends State<_PointerLight> {
  final ValueNotifier<Offset?> _position = ValueNotifier(null);

  @override
  void didUpdateWidget(covariant _PointerLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _position.value = null;
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius;
    Widget? light;
    if (widget.enabled) {
      final flow = Flow(
        clipBehavior: borderRadius == null ? Clip.hardEdge : Clip.none,
        delegate: _PointerLightFlow(_position, widget.radius),
        children: [
          RepaintBoundary(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  radius: 0.5,
                  colors: [widget.color, widget.color.withAlpha(0)],
                ),
              ),
            ),
          ),
        ],
      );
      light = Positioned.fill(
        child: IgnorePointer(
          child: borderRadius == null
              ? flow
              : ClipRRect(borderRadius: borderRadius, child: flow),
        ),
      );
    }
    return MouseRegion(
      opaque: false,
      onEnter: widget.enabled ? (e) => _position.value = e.localPosition : null,
      onHover: widget.enabled ? (e) => _position.value = e.localPosition : null,
      onExit: widget.enabled ? (_) => _position.value = null : null,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          if (widget.behindChild && light != null) light,
          widget.child,
          if (!widget.behindChild && light != null) light,
        ],
      ),
    );
  }
}

class _PointerLightFlow extends FlowDelegate {
  final ValueListenable<Offset?> position;
  final double radius;

  _PointerLightFlow(this.position, this.radius) : super(repaint: position);

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      BoxConstraints.tight(Size.square(radius * 2));

  @override
  void paintChildren(FlowPaintingContext context) {
    final point = position.value;
    if (point == null) return;
    context.paintChild(
      0,
      transform: Matrix4.translationValues(point.dx - radius, point.dy - radius, 0),
    );
  }

  @override
  bool shouldRelayout(covariant _PointerLightFlow oldDelegate) =>
      oldDelegate.radius != radius;

  @override
  bool shouldRepaint(covariant _PointerLightFlow oldDelegate) =>
      oldDelegate.position != position || oldDelegate.radius != radius;
}

// ------------------------------------------------------- bridge logo + splash

class _BridgeLogoPainter extends CustomPainter {
  final double t;
  final Color c1;
  final Color c2;
  const _BridgeLogoPainter(this.t, this.c1, this.c2);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    double seg(double a, double b) =>
        ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();

    final shader = LinearGradient(
      colors: [c1, c2],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Offset.zero & s);

    Paint strokePen(double width, {Color? color}) => Paint()
      ..shader = color == null ? shader : null
      ..color = color ?? c1
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final archW = (w * 0.068).clamp(1.8, 12.0);
    final pillarW = (w * 0.042).clamp(1.2, 7.5);
    final deckW = (w * 0.066).clamp(1.8, 11.5);
    final legW = (w * 0.072).clamp(2.0, 12.5);

    final deckY = h * 0.56;
    final archStartX = w * 0.19;
    final archEndX = w * 0.81;
    final archControlY = h * 0.16;

    double archY(double u) =>
        (1 - u) * (1 - u) * deckY +
        2 * (1 - u) * u * archControlY +
        u * u * deckY;

    // 1. Thick rounded horizontal deck with rounded overhangs (matches official logo)
    final pDeck = seg(0.0, 0.45);
    if (pDeck > 0) {
      final halfSpan = (w * 0.345) * pDeck;
      canvas.drawLine(
        Offset(w * 0.50 - halfSpan, deckY),
        Offset(w * 0.50 + halfSpan, deckY),
        strokePen(deckW),
      );
    }

    // 2. Two angled trapezoidal legs underneath the deck
    final pLegs = seg(0.15, 0.58);
    if (pLegs > 0) {
      final legLenY = h * 0.115 * pLegs;
      final legShiftX = w * 0.032 * pLegs;
      canvas.drawLine(
        Offset(w * 0.30, deckY + deckW * 0.15),
        Offset(w * 0.30 - legShiftX, deckY + deckW * 0.15 + legLenY),
        strokePen(legW),
      );
      canvas.drawLine(
        Offset(w * 0.70, deckY + deckW * 0.15),
        Offset(w * 0.70 + legShiftX, deckY + deckW * 0.15 + legLenY),
        strokePen(legW),
      );
    }

    // 3. Single bold parabolic arch
    final pArch = seg(0.22, 0.75);
    if (pArch > 0) {
      final arch = Path()
        ..moveTo(archStartX, deckY)
        ..quadraticBezierTo(w * 0.50, archControlY, archEndX, deckY);
      for (final m in arch.computeMetrics()) {
        canvas.drawPath(
          m.extractPath(0, m.length * pArch),
          strokePen(archW),
        );
      }
    }

    // 4. Five vertical pillars inside the arch
    const us = [0.22, 0.36, 0.50, 0.64, 0.78];
    for (var i = 0; i < us.length; i++) {
      final pPillar = seg(0.42 + i * 0.07, 0.78 + i * 0.05);
      if (pPillar <= 0) continue;
      final u = us[i];
      final px = archStartX + (archEndX - archStartX) * u;
      final topY = archY(u) + archW * 0.25;
      final curY = deckY - (deckY - topY) * pPillar;
      canvas.drawLine(
        Offset(px, deckY),
        Offset(px, curY),
        strokePen(pillarW),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BridgeLogoPainter old) =>
      old.t != t || old.c1 != c1 || old.c2 != c2;
}

class _BridgeLogoBadge extends StatelessWidget {
  final double size;
  final bool glow;
  const _BridgeLogoBadge({this.size = 38, this.glow = true});

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A0B1E),
            Color(0xFF050514),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: p.accent.withValues(alpha: 0.52),
          width: 1.15,
        ),
        boxShadow: glow
            ? [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.30),
                  blurRadius: size * 0.42,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.26),
        child: Image.asset(
          'assets/brand/logo_mark.png',
          width: size,
          height: size,
          cacheWidth: (size * 2.5).round().clamp(48, 256),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, _, _) => Padding(
            padding: EdgeInsets.all(size * 0.08),
            child: CustomPaint(
              painter: const _BridgeLogoPainter(
                1.0,
                Colors.white,
                Color(0xFFD8E2F0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom Windows 11/10 borderless window title bar communicating with `localbridge/window`.
class _CustomTitleBar extends StatefulWidget {
  final DropService svc;
  final VoidCallback onGlobalConnect;
  final void Function(List<String> paths)? onFilesDropped;
  const _CustomTitleBar({
    required this.svc,
    required this.onGlobalConnect,
    this.onFilesDropped,
  });

  @override
  State<_CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<_CustomTitleBar> {
  static const MethodChannel _ch = MethodChannel('localbridge/window');
  bool _maximized = false;

  @override
  void initState() {
    super.initState();
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onWindowStateChanged' && mounted) {
        setState(() => _maximized = call.arguments == true);
      } else if (call.method == 'onFilesDropped' && mounted) {
        final args = call.arguments;
        if (args is List) {
          final paths = args.map((e) => '$e').where((s) => s.isNotEmpty).toList();
          if (paths.isNotEmpty) {
            widget.onFilesDropped?.call(paths);
          }
        }
      }
    });
    _syncMaximized();
  }

  Future<void> _syncMaximized() async {
    try {
      final res = await _ch.invokeMethod<bool>('isMaximized');
      if (mounted && res != null) setState(() => _maximized = res);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ch.setMethodCallHandler(null);
    super.dispose();
  }

  Future<void> _invoke(String m) async {
    try {
      final res = await _ch.invokeMethod<dynamic>(m);
      if (m == 'toggleMaximize' && mounted && res is bool) {
        setState(() => _maximized = res);
      }
    } catch (_) {}
  }

  void _cycleThemeMode() {
    final s = widget.svc.cfg;
    s.update(() {
      if (s.themeMode == ThemeMode.dark && !s.amoled) {
        s.themeMode = ThemeMode.light;
      } else if (s.themeMode == ThemeMode.light) {
        s.themeMode = ThemeMode.dark;
        s.amoled = true;
      } else {
        s.themeMode = ThemeMode.dark;
        s.amoled = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final online = widget.svc.online;
    final deskCode = widget.svc.deskCode;
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: p.surfaceRecessed,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const _BridgeLogoBadge(size: 22, glow: false),
          const SizedBox(width: 10),
          Text(
            kAppName,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: p.ink,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: p.accent.withValues(alpha: 0.30)),
            ),
            child: Text(
              'v$kVersion',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: p.accent,
              ),
            ),
          ),
          if (online && deskCode.isNotEmpty) ...[
            const SizedBox(width: 10),
            InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: widget.onGlobalConnect,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: p.borderStrong),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: p.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      deskCode,
                      style: TextStyle(
                        fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: p.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Tooltip(
            message: p.isDark
                ? (p.isAmoled ? 'Switch to Studio Dark' : 'Switch to Alabaster Light')
                : 'Switch to AMOLED Dark',
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: _cycleThemeMode,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: p.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      p.isDark
                          ? (p.isAmoled
                              ? Icons.contrast_rounded
                              : Icons.dark_mode_rounded)
                          : Icons.light_mode_rounded,
                      size: 13,
                      color: p.accent,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      p.isDark ? (p.isAmoled ? 'AMOLED' : 'Atelier') : 'Paper',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: p.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => _invoke('startDrag'),
              onDoubleTap: () => _invoke('toggleMaximize'),
              onSecondaryTap: () => _invoke('showSystemMenu'),
              child: const SizedBox.expand(),
            ),
          ),
          _WinCtrlBtn(
            icon: Icons.horizontal_rule_rounded,
            tooltip: 'Minimize',
            onTap: () => _invoke('minimize'),
          ),
          _WinCtrlBtn(
            icon: _maximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
            iconSize: _maximized ? 13.5 : 14.5,
            tooltip: _maximized ? 'Restore' : 'Maximize',
            onTap: () => _invoke('toggleMaximize'),
          ),
          _WinCtrlBtn(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            isClose: true,
            onTap: () => _invoke('close'),
          ),
        ],
      ),
    );
  }
}

class _WinCtrlBtn extends StatefulWidget {
  final IconData icon;
  final double iconSize;
  final String tooltip;
  final bool isClose;
  final VoidCallback onTap;
  const _WinCtrlBtn({
    required this.icon,
    this.iconSize = 16,
    required this.tooltip,
    this.isClose = false,
    required this.onTap,
  });

  @override
  State<_WinCtrlBtn> createState() => _WinCtrlBtnState();
}

class _WinCtrlBtnState extends State<_WinCtrlBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final bg = !_hover
        ? Colors.transparent
        : (widget.isClose
            ? const Color(0xFFD64545)
            : p.ink.withValues(alpha: 0.08));
    final fg = (_hover && widget.isClose) ? Colors.white : p.inkSecondary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: 46,
          height: 42,
          color: bg,
          child: Center(
            child: Icon(widget.icon, size: widget.iconSize, color: fg),
          ),
        ),
      ),
    );
  }
}

class _Boot extends StatefulWidget {
  final Settings settings;
  const _Boot({required this.settings});

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> with SingleTickerProviderStateMixin {
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: widget.settings.bootAnim == 2 ? 1750 : 750,
    ),
  );
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_done) return;
    if (widget.settings.bootAnim == 0 ||
        MediaQuery.disableAnimationsOf(context)) {
      _animation.stop();
      _done = true;
    } else if (!_animation.isAnimating) {
      _animation.addStatusListener(_onStatus);
      _animation.forward();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() => _done = true);
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final accent = Color.lerp(p.accent, const Color(0xFFB6CDE3), 0.50)!;
    return Stack(
      fit: StackFit.expand,
      children: [
        Visibility(
          visible: _done,
          maintainState: true,
          child: RepaintBoundary(child: Shell(settings: widget.settings)),
        ),
        if (!_done)
          Material(
            key: const ValueKey('launch-screen'),
            color: const Color(0xFF080B16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.78,
                  colors: [
                    Color.lerp(const Color(0xFF10182A), accent, 0.09)!,
                    const Color(0xFF080B16),
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RepaintBoundary(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF111A2B),
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.42),
                                ),
                              ),
                              child: SizedBox.square(
                                dimension: 120,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: AnimatedBuilder(
                                    animation: _animation,
                                    builder: (context, _) => CustomPaint(
                                      painter: _BridgeLogoPainter(
                                        Curves.easeOutCubic.transform(
                                          (_animation.value / 0.72)
                                              .clamp(0.0, 1.0),
                                        ),
                                        const Color(0xFFF6F9FF),
                                        accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            kAppName,
                            style: TextStyle(
                              inherit: false,
                              fontFamily: 'Inter',
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF6F9FF),
                              decoration: TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'v$kVersion',
                            style: TextStyle(
                              inherit: false,
                              fontFamily: 'Inter',
                              fontSize: 12,
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w500,
                              color: accent,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class LocalBridgeApp extends StatelessWidget {
  final Settings settings;
  const LocalBridgeApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final seed = kAccents[settings.accent.clamp(0, kAccents.length - 1)];
        ThemeData theme(Brightness b) {
          final p = EditorialPalette.fromSettings(
            brightness: b,
            accent: seed,
            amoled: settings.amoled,
          );
          final baseScheme = ColorScheme.fromSeed(
            seedColor: seed,
            brightness: b,
            surface: p.card,
          ).copyWith(
            primary: seed,
            secondary: p.secondaryAccent,
            tertiary: p.warmHighlight,
            surface: p.card,
            onSurface: p.ink,
            onSurfaceVariant: p.inkSecondary,
            outline: p.borderStrong,
          );
          final fieldBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: p.borderStrong),
          );
          return ThemeData(
            colorScheme: baseScheme,
            brightness: b,
            useMaterial3: true,
            fontFamily: 'Inter',
            fontFamilyFallback: const [
              'Segoe UI Variable Display',
              'Segoe UI',
              'Roboto',
              'sans-serif',
            ],
            scaffoldBackgroundColor: Colors.transparent,
            cardColor: p.card,
            dialogBackgroundColor: p.card,
            dividerColor: p.border,
            hoverColor: seed.withAlpha(16),
            splashColor: seed.withAlpha(24),
            highlightColor: seed.withAlpha(14),
            appBarTheme: AppBarTheme(
              centerTitle: false,
              scrolledUnderElevation: 0,
              backgroundColor: p.canvas.withValues(alpha: 0.94),
              foregroundColor: p.ink,
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: p.surfaceRecessed,
              indicatorColor: seed.withAlpha(42),
            ),
            listTileTheme: ListTileThemeData(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              iconColor: p.inkSecondary,
              textColor: p.ink,
              titleTextStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
              subtitleTextStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                color: p.inkSecondary,
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: p.surfaceRecessed,
              selectedColor: seed.withAlpha(42),
              side: BorderSide(color: p.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith<Color?>(
                (st) => st.contains(WidgetState.selected) ? Colors.white : p.inkMuted,
              ),
              trackColor: WidgetStateProperty.resolveWith<Color?>(
                (st) => st.contains(WidgetState.selected) ? seed : p.surfaceRecessed,
              ),
              trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
                (st) => st.contains(WidgetState.selected) ? Colors.transparent : p.borderStrong,
              ),
            ),
            sliderTheme: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: seed,
              inactiveTrackColor: p.border,
              thumbColor: seed,
              overlayColor: seed.withAlpha(28),
              activeTickMarkColor: Colors.transparent,
              inactiveTickMarkColor: Colors.transparent,
            ),
            popupMenuTheme: PopupMenuThemeData(
              color: p.cardElevated,
              elevation: 12,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: p.borderStrong),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: p.card,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: p.borderStrong),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: p.cardElevated,
              contentTextStyle: TextStyle(
                color: p.ink,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: p.borderStrong),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: p.surfaceRecessed,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              border: fieldBorder,
              enabledBorder: fieldBorder,
              hoverColor: seed.withAlpha(10),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: seed, width: 1.5),
              ),
            ),
          );
        }

        return MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: Duration.zero,
          theme: theme(Brightness.light),
          darkTheme: theme(Brightness.dark),
          themeMode: settings.themeMode,
          builder: (context, child) {
            final effectiveBrightness = switch (settings.themeMode) {
              ThemeMode.light => Brightness.light,
              ThemeMode.dark => Brightness.dark,
              ThemeMode.system => MediaQuery.platformBrightnessOf(context),
            };
            final palette = EditorialPalette.fromSettings(
              brightness: effectiveBrightness,
              accent: seed,
              amoled: settings.amoled,
            );
            return EditorialTheme(
              palette: palette,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(settings.textScale)),
                child: _CursorGlow(
                  color: seed,
                  follow: _fxFrom(settings),
                  level: settings.glowLevel / 100.0,
                  child: child!,
                ),
              ),
            );
          },
          home: _Boot(settings: settings),
        );
      },
    );
  }
}

class Shell extends StatefulWidget {
  final Settings settings;
  const Shell({super.key, required this.settings});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  late final DropService svc;
  final FileStagingController staging = FileStagingController();
  bool _dialogOpen = false;
  bool _stagingModalOpen = false;
  int _tab = 0;
  final Set<int> _openedTabs = {0};
  String? _chatAddress;
  final Set<String> _unreadChats = {};

  void _selectChat(String? address) {
    _chatAddress = address;
    if (address == null) {
      _unreadChats.clear();
    } else {
      _unreadChats.remove(address);
    }
  }

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      if (index == 3) _selectChat(_chatAddress);
    });
  }
  int _lastPort = 0;
  int _lastScan = 0;
  bool _lastAutoScan = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    svc = DropService(widget.settings);
    _lastPort = widget.settings.port;
    _lastScan = widget.settings.scanSeconds;
    _lastAutoScan = widget.settings.autoScan;
    svc.addListener(_onChange);
    widget.settings.addListener(_onSettings);
    svc.start();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recoverAndroidPick());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.settings.removeListener(_onSettings);
    svc.removeListener(_onChange);
    staging.dispose();
    svc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bg = state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    svc.setAppBackgrounded(bg);
    if (mounted) setState(() {});
  }

  void _onSettings() {
    final s = widget.settings;
    if (s.port != _lastPort) {
      _lastPort = s.port;
      svc.stopShare();
      svc.restartServer();
    }
    if (s.scanSeconds != _lastScan || s.autoScan != _lastAutoScan) {
      _lastScan = s.scanSeconds;
      _lastAutoScan = s.autoScan;
      svc.reschedule();
    }
    if (mounted) setState(() {});
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null && svc._notices.isNotEmpty) {
      for (final notice in svc._notices) {
        final address = notice.chatAddress;
        if (address != null && _tab == 3 &&
            (_chatAddress == null || _chatAddress == address) &&
            !svc._appBackgrounded) {
          continue;
        }
        if (address != null) _unreadChats.add(address);
        if (address != null && svc.chatMutedUntil(address) != null) continue;
        messenger.showSnackBar(
          SnackBar(
            duration: Duration(seconds: address == null ? 4 : 8),
            behavior: SnackBarBehavior.floating,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notice.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(notice.body, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
            action: address == null ? null : SnackBarAction(
              label: widget.settings.tr('bridgeChat'),
              onPressed: () => _openChatAddress(address),
            ),
          ),
        );
      }
      svc._notices.clear();
    }
    final r = svc.pending;
    if (r != null && !_dialogOpen) {
      _dialogOpen = true;
      _showRequest(r);
    }
  }

  Future<void> _showRequest(IncomingRequest r) async {
    final total = r.files.fold<int>(0, (a, f) => a + f.size);
    var watching = false;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        if (!watching) {
          watching = true;
          final route = ModalRoute.of(ctx);
          unawaited(r.decision.future.then((_) {
            if (route != null && route.isActive) {
              route.navigator?.removeRoute(route, false);
            }
          }));
        }
        if (r.connection) {
          final tr = widget.settings.tr;
          return AlertDialog(
            icon: const Icon(Icons.link_rounded),
            title: Text(tr('deskIncoming').replaceAll('{name}', r.from)),
            content: Text(tr('deskApprovalInfo')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('deskApprove'))),
            ],
          );
        }
        final p = EditorialTheme.of(ctx);
        return AlertDialog(
          backgroundColor: p.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: p.borderStrong)),
          icon: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
                r.download ? Icons.link_rounded : Icons.download_for_offline_rounded,
                size: 30,
                color: cs.primary),
          ),
          title: Text(
            r.download
                ? '${r.from} wants to download your shared files'
                : '${r.from} wants to send you files',
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.unverifiedTrustClaim) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.warning.withAlpha(28),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: p.warning.withAlpha(90)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: p.warning, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.settings.tr('trustUnverifiedWarn'),
                            style: TextStyle(fontSize: 12, color: p.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Text('${r.files.length} file${r.files.length == 1 ? '' : 's'} • ${fmtSize(total)}',
                    style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: cs.primary)),
                const SizedBox(height: 8),
                for (final f in r.files.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        EditorialFileIllustration(fileName: f.name, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 8),
                        Text(fmtSize(f.size), style: Theme.of(ctx).textTheme.bodySmall),
                      ],
                    ),
                  ),
                if (r.files.length > 8)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('… +${r.files.length - 8} more'),
                  ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
                child: Text(widget.settings.tr('cancel'))),
            _GradButton(
              label: r.download ? 'Allow' : 'Accept',
              icon: Icons.check_rounded,
              compact: true,
              onTap: () => Navigator.of(ctx, rootNavigator: true).pop(true),
            ),
          ],
        );
      },
    );
    _dialogOpen = false;
    svc.resolve(r, ok ?? false);
  }

  Future<bool> _pickFilesIntoStaging() async {
    try {
      return await _stagePickedFiles(await FilePicker.pickFiles());
    } catch (_) {
      _showPickerError();
      return false;
    }
  }

  void _showPickerError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.settings.tr('stageProviderError'))),
    );
  }

  Future<void> _recoverAndroidPick() async {
    try {
      if (FilePickerPlatform.instance case final FilePickerAndroid picker) {
        final result = await picker.retrieveLostData();
        if (result == null || !mounted) return;
        if (result.exception != null) {
          _showPickerError();
        } else if (await _stagePickedFiles(result.files) && mounted) {
          await _openStagingModal();
        }
      }
    } catch (_) {
      _showPickerError();
    }
  }

  Future<bool> _stagePickedFiles(List<PlatformFile> files) async {
      if (!mounted || files.isEmpty) return false;
      final items = <StagedFileItem>[];
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        int? len;
        try {
          len = f.lengthSync() ?? await f.length();
        } catch (_) {}
        if (len == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${widget.settings.tr('stageProviderError')} (${f.name})')),
            );
          }
          continue;
        }
        items.add(
          StagedFileItem(
            id: f.path != null && f.path!.isNotEmpty
                ? 'path:${f.path}'
                : 'pf:${DateTime.now().microsecondsSinceEpoch}:$i:${f.name}',
            name: f.name,
            size: len,
            path: f.path,
            streamFactory: () => f.readAsByteStream(),
          ),
        );
      }
      return mounted && staging.addFiles(items) > 0;
  }

  Future<void> _onFilesDropped(List<String> paths) async {
    if (staging.isTransferring) return;
    final added = await staging.addLocalPaths(paths);
    if (added <= 0 || !mounted) return;
    if (staging.targetKey == null) {
      final devs = svc.sortedDevices();
      if (devs.length == 1) {
        final first = devs.single;
        staging.setTarget(
          key: svc.addressOf(first),
          alias: first.alias,
          ip: widget.settings.showIps ? first.ip : '',
        );
      }
    }
    if (!_stagingModalOpen) {
      await _openStagingModal();
    }
  }

  List<StagedTargetOption> _buildTargetOptions() {
    final devs = svc.sortedDevices();
    final showIp = widget.settings.showIps;
    return [
      for (final d in devs)
        StagedTargetOption(
          key: svc.addressOf(d),
          alias: d.alias,
          subtitle: showIp ? d.ip : '',
          isTrusted: widget.settings.isDeviceTrusted(d),
        ),
    ];
  }

  Future<void> _executeStagedSend(BuildContext modalContext) async {
    final targetKey = staging.targetKey;
    final current = targetKey != null ? svc.connectedDevice(targetKey) : null;
    if (staging.isTransferring) return;
    if (current == null || staging.isEmpty) {
      staging.failTransfer(widget.settings.tr('stageTransferFailed'));
      return;
    }
    staging.beginTransfer();
    final ok = await svc.sendStagedFiles(
      current,
      staging.items,
      onProgress: (idx, sentCount) {
        if (!mounted) return;
        staging.updateProgress(currentFileIndex: idx, sentFilesCount: sentCount);
      },
    );
    if (!mounted) return;
    if (ok) {
      staging.completeTransferSuccess();
      if (modalContext.mounted && Navigator.of(modalContext).canPop()) {
        Navigator.of(modalContext).pop(true);
      }
    } else {
      staging.discardAcknowledgedFiles();
      staging.failTransfer(
        svc.status.isNotEmpty
            ? svc.status
            : widget.settings.tr('stageTransferFailed'),
        cancelled: svc._sendCancelled,
      );
    }
  }

  Future<void> _openStagingModal() async {
    if (!mounted || _stagingModalOpen) return;
    _stagingModalOpen = true;
    final isWide = !Platform.isAndroid && !Platform.isIOS &&
        MediaQuery.sizeOf(context).width >= kWideBreakpoint;
    try {
      if (isWide) {
        final p = EditorialTheme.of(context);
        await showDialog<bool>(
          context: context,
          barrierDismissible: !staging.isTransferring,
          builder: (ctx) => Dialog(
            backgroundColor: p.card,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: p.borderStrong),
            ),
            child: ListenableBuilder(
              listenable: svc,
              builder: (context, _) => FileStagingModal(
                controller: staging,
                targetOptions: _buildTargetOptions(),
                tr: widget.settings.tr,
                formatBytes: fmtSize,
                onAddMoreFiles: () async {
                  await _pickFilesIntoStaging();
                },
                onStartSend: () => _executeStagedSend(ctx),
                onCancelTransfer: svc.cancelOutgoingTransfer,
                transferProgress: svc.progress,
                isDesktopLayout: true,
              ),
            ),
          ),
        );
      } else {
        final p = EditorialTheme.of(context);
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: p.card,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            side: BorderSide(color: p.borderStrong),
          ),
          builder: (ctx) => ListenableBuilder(
            listenable: svc,
            builder: (context, _) => FileStagingModal(
              controller: staging,
              targetOptions: _buildTargetOptions(),
              tr: widget.settings.tr,
              formatBytes: fmtSize,
              onAddMoreFiles: () async {
                await _pickFilesIntoStaging();
              },
              onStartSend: () => _executeStagedSend(ctx),
              onCancelTransfer: svc.cancelOutgoingTransfer,
              transferProgress: svc.progress,
              isDesktopLayout: false,
            ),
          ),
        );
      }
    } finally {
      _stagingModalOpen = false;
    }
  }

  Future<void> _pickAndSend(Device d) async {
    if (!svc.online || svc.connectedDevice(svc.addressOf(d)) == null) return;
    staging.setTarget(
      key: svc.addressOf(d),
      alias: d.alias,
      ip: widget.settings.showIps ? d.ip : '',
    );
    if (staging.isEmpty) {
      final picked = await _pickFilesIntoStaging();
      if (!picked && staging.isEmpty) return;
    }
    if (!mounted) return;
    await _openStagingModal();
  }

  void _openChat(Device device) => _openChatAddress(svc.addressOf(device));

  void _openChatAddress(String address) {
    if (!mounted) return;
    setState(() {
      _selectChat(address);
      _tab = 3;
    });
  }

  void _showConnectionActions(Device device) {
    if (!mounted) return;
    final tr = widget.settings.tr;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.link_rounded),
        title: Text(tr('deskConnected').replaceAll('{name}', device.alias)),
        content: Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.forum_rounded),
              label: Text(tr('bridgeChat')),
              onPressed: () {
                Navigator.pop(context);
                _openChat(device);
              },
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(tr('send')),
              onPressed: () {
                Navigator.pop(context);
                _pickAndSend(device);
              },
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel')))],
      ),
    );
  }

  Future<void> _pickAndShare() async {
    if (!svc.online) return;
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    await svc.startShare(files);
    final s = widget.settings;
    if (s.autoCopyLink && svc.shareUrls.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: svc.shareUrls.first));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(s.tr('linkCopied'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final pages = [
      DevicesPage(svc: svc, onSend: _pickAndSend, onShare: _pickAndShare,
          onChat: _openChat, onConnect: _showConnectionActions),
      GlobalConnectPage(
        svc: svc,
        onSend: _pickAndSend,
        onOpenChat: _openChat,
        onConnect: _showConnectionActions,
      ),
      GlobalTransferPage(svc: svc, onSend: _pickAndSend, onShare: _pickAndShare),
      BridgeChatPage(
        svc: svc,
        address: _chatAddress,
        onTargetChanged: (address) => setState(() => _selectChat(address)),
        onSendFiles: _pickAndSend,
      ),
      HistoryPage(svc: svc),
      SettingsPage(settings: widget.settings, svc: svc),
    ];
    final navItems = <(IconData, IconData, String)>[
      (Icons.radar_outlined, Icons.radar_rounded, s.tr('devices')),
      (Icons.public_outlined, Icons.public_rounded, s.tr('globalConnect')),
      (Icons.swap_horiz_rounded, Icons.swap_horizontal_circle_rounded, s.tr('globalTransfer')),
      (Icons.forum_outlined, Icons.forum_rounded, s.tr('bridgeChat')),
      (Icons.history_outlined, Icons.history_rounded, s.tr('history')),
      (Icons.settings_outlined, Icons.settings_rounded, s.tr('settings')),
    ];
    _openedTabs.add(_tab);
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _tab != 0) {
          setState(() => _tab = 0);
        }
      },
      child: LayoutBuilder(
        builder: (context, box) {
          final gatedPages = [
            for (var i = 0; i < pages.length; i++)
              if (_openedTabs.contains(i))
                TickerMode(
                  enabled: !svc._appBackgrounded && _tab == i,
                  child: RepaintBoundary(child: pages[i]),
                )
              else
                const SizedBox.shrink(),
          ];
          // Big window: custom title bar at top, side menu on the left, content fills the rest.
          if (box.maxWidth >= kWideBreakpoint) {
            return Scaffold(
              body: SafeArea(
                child: Column(children: [
                  if (Platform.isWindows)
                    _CustomTitleBar(
                      svc: svc,
                      onGlobalConnect: () => setState(() => _tab = 1),
                      onFilesDropped: _onFilesDropped,
                    ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SideRail(
                          index: _tab,
                          onChanged: _selectTab,
                          items: navItems,
                          svc: svc,
                          unreadChats: _unreadChats.length,
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: kMaxWideWidth),
                              child: IndexedStack(
                                index: _tab,
                                sizing: StackFit.expand,
                                children: gatedPages,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (s.showStatusBar) _StatusBar(svc: svc),
                ]),
              ),
            );
          }
          // Phone / small window: single column and floating bottom bar.
          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  if (Platform.isWindows)
                    _CustomTitleBar(
                      svc: svc,
                      onGlobalConnect: () => setState(() => _tab = 1),
                      onFilesDropped: _onFilesDropped,
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                        child: IndexedStack(
                          index: _tab,
                          sizing: StackFit.expand,
                          children: gatedPages,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                child: _NavBar(
                  index: _tab,
                  onChanged: _selectTab,
                  items: navItems,
                  unreadChats: _unreadChats.length,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------ shared widgets

/// Studio telemetry status bar at the bottom of wide windows.
class _StatusBar extends StatelessWidget {
  final DropService svc;
  const _StatusBar({required this.svc});

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final s = svc.cfg;
    final okColor = p.success;
    final on = svc.online;
    final n = svc.devices.length;
    final label = !on
        ? s.tr('statusOffline')
        : (svc.scanning && n == 0)
            ? s.tr('statusScanning')
            : '$n ${s.tr('statusConnected')}';
    final color = on ? okColor : p.inkMuted;
    final ip = (s.showIps && svc.myIps.isNotEmpty) ? svc.myIps.first : null;

    Widget chip(String text, {bool mono = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: p.border),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: mono ? 'Consolas' : 'Inter',
              fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: p.inkSecondary,
            ),
          ),
        );

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: p.surfaceRecessed,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: on
                  ? [BoxShadow(color: okColor.withAlpha(110), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Spacer(),
          if (on && svc.serverUp)
            chip('${s.tr('statusServer')} :${s.port}', mono: true),
          if (ip != null) ...[
            const SizedBox(width: 8),
            chip(ip, mono: true),
          ],
          const SizedBox(width: 10),
          Text(
            '$kAppName v$kVersion',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: p.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Left side menu used on wide windows (Editorial Atelier Studio Rail).
class _SideRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData, IconData, String)> items;
  final DropService svc;
  final int unreadChats;
  const _SideRail({
    required this.index,
    required this.onChanged,
    required this.items,
    required this.svc,
    required this.unreadChats,
  });

  String _platformName(TargetPlatform platform) => switch (platform) {
        TargetPlatform.windows => 'Windows',
        TargetPlatform.android => 'Android',
        TargetPlatform.macOS => 'macOS',
        TargetPlatform.iOS => 'iOS',
        TargetPlatform.linux => 'Linux',
        TargetPlatform.fuchsia => 'Fuchsia',
      };

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final tr = svc.cfg.tr;
    final platform = _platformName(Theme.of(context).platform);
    final ready = svc.online && svc.serverUp;
    final status = tr(!svc.online ? 'statusOffline' : ready ? 'ready' : 'serverOff');
    final indicator = ready ? p.success : p.inkMuted;

    return SizedBox(
      key: const ValueKey('desktop-sidebar'),
      width: 256,
      child: Material(
        color: p.surfaceRecessed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: p.border)),
          ),
          child: CustomScrollView(
            primary: false,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                sliver: SliverList.list(
                  children: [
                    _Hover(
                      radius: 18,
                      scale: 1.01,
                      glow: false,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: p.cardTinted,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: p.accent.withValues(alpha: 0.34),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: EditorialMotifPainter(
                                      variant: EditorialMotifVariant.archBridge,
                                      primary: p.accent,
                                      secondary: p.secondaryAccent,
                                      warm: p.warmHighlight,
                                      opacity: 0.16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 3,
                              ),
                              horizontalTitleGap: 11,
                              leading: const _BridgeLogoBadge(size: 38, glow: false),
                              title: Text(
                                svc.alias,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: p.ink,
                                ),
                              ),
                              subtitle: Text(
                                svc.cfg.showIps && svc.myIps.isNotEmpty
                                    ? '$platform · ${svc.myIps.first}'
                                    : platform,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                                  fontSize: 11,
                                  color: p.inkSecondary,
                                ),
                              ),
                              trailing: Icon(
                                Icons.tune_rounded,
                                size: 16,
                                color: p.accent,
                              ),
                              onTap: () => onChanged(items.length - 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: _SidebarDestination(
                          label: items[i].$3,
                          icon: i == index ? items[i].$2 : items[i].$1,
                          selected: i == index,
                          unreadCount: i == 3 ? unreadChats : 0,
                          hoverEffects: svc.cfg.hoverFx,
                          onTap: () => onChanged(i),
                        ),
                      ),
                    if (svc.cfg.showRailStats) ...[
                      const SizedBox(height: 12),
                      _SidebarStats(svc: svc),
                    ],
                  ],
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: ready
                                  ? indicator.withAlpha(90)
                                  : p.borderStrong,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: indicator,
                                  shape: BoxShape.circle,
                                  boxShadow: ready
                                      ? [
                                          BoxShadow(
                                              color: indicator.withAlpha(130),
                                              blurRadius: 7)
                                        ]
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  status,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: indicator,
                                  ),
                                ),
                              ),
                              _PowerButton(svc: svc, iconOnly: true),
                              const SizedBox(width: 4),
                              Material(
                                color: p.surfaceRecessed,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => showChangelog(context, svc.cfg),
                                  child: Tooltip(
                                    message: tr('whatsNew'),
                                    child: SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 15.5,
                                        color: p.warmHighlight,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: p.card.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: p.border),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => openGithub(
                                    context, 'https://github.com/unqale'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: p.accent.withAlpha(28),
                                          borderRadius:
                                              BorderRadius.circular(7),
                                          border: Border.all(
                                              color: p.accent.withAlpha(70)),
                                        ),
                                        child: Icon(Icons.code_rounded,
                                            size: 13, color: p.accent),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Made by unqale',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: p.ink,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.open_in_new_rounded,
                                          size: 12.5, color: p.inkMuted),
                                    ],
                                  ),
                                ),
                              ),
                              Divider(
                                  height: 4,
                                  thickness: 1,
                                  color: p.border.withAlpha(120)),
                              InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => openGithub(
                                    context, 'https://github.com/eratis-hq'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: p.warmHighlight.withAlpha(28),
                                          borderRadius:
                                              BorderRadius.circular(7),
                                          border: Border.all(
                                              color: p.warmHighlight
                                                  .withAlpha(70)),
                                        ),
                                        child: Icon(Icons.auto_awesome_rounded,
                                            size: 13, color: p.warmHighlight),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Contributor: eratis-hq',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: p.inkSecondary,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.open_in_new_rounded,
                                          size: 12.5, color: p.inkMuted),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarDestination extends StatefulWidget {
  const _SidebarDestination({
    required this.label,
    required this.icon,
    required this.selected,
    required this.hoverEffects,
    required this.onTap,
    this.unreadCount = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool hoverEffects;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  State<_SidebarDestination> createState() => _SidebarDestinationState();
}

class _SidebarDestinationState extends State<_SidebarDestination> {
  bool _hovered = false;
  bool _pressed = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final accent = p.accent;
    final active = widget.selected;
    final hovered = _hovered && widget.hoverEffects;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reducedMotion
        ? Duration.zero
        : Duration(milliseconds: _pressed ? 60 : hovered ? 190 : 240);
    final foreground = active || _pressed
        ? p.ink
        : hovered
            ? Color.lerp(p.ink, accent, 0.35)!
            : p.inkSecondary;
    final iconColor = active || _pressed
        ? accent
        : hovered
            ? accent
            : p.inkMuted;
    final background = accent.withAlpha(_pressed
        ? 44
        : active
            ? (hovered ? 34 : 24)
            : hovered
                ? 16
                : 0);
    final border = accent.withAlpha(_focused
        ? 180
        : _pressed
            ? 110
            : active
                ? (hovered ? 95 : 70)
                : hovered
                    ? 40
                    : 0);
    const curve = Curves.easeOutCubic;
    const radius = BorderRadius.all(Radius.circular(13));

    return Semantics(
      button: true,
      selected: active,
      child: AnimatedContainer(
        duration: duration,
        curve: curve,
        decoration: BoxDecoration(
          color: background,
          borderRadius: radius,
          border: Border.all(color: border),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            mouseCursor: SystemMouseCursors.click,
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            splashFactory: NoSplash.splashFactory,
            onTap: widget.onTap,
            onHover: (value) => setState(() => _hovered = value),
            onHighlightChanged: (value) => setState(() => _pressed = value),
            onFocusChange: (value) => setState(() => _focused = value),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 42),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: duration,
                      width: 3.5,
                      height: active ? 18 : 6,
                      decoration: BoxDecoration(
                        color: active ? accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: active
                            ? [BoxShadow(color: accent.withAlpha(120), blurRadius: 6)]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: AnimatedSlide(
                        offset: Offset(
                          reducedMotion
                              ? 0
                              : _pressed
                                  ? 0.02
                                  : hovered && !active
                                      ? 0.012
                                      : 0,
                          0,
                        ),
                        duration: duration,
                        curve: curve,
                        child: Row(
                          children: [
                            TweenAnimationBuilder<Color?>(
                              tween: ColorTween(end: iconColor),
                              duration: duration,
                              curve: curve,
                              builder: (context, color, _) => Badge.count(
                                count: widget.unreadCount,
                                isLabelVisible: widget.unreadCount > 0,
                                child: Icon(widget.icon, size: 19, color: color),
                              ),
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: AnimatedDefaultTextStyle(
                                duration: duration,
                                curve: curve,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: foreground,
                                  fontSize: 13.5,
                                  letterSpacing: 0.1,
                                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                                ),
                                child: Text(widget.label,
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarStats extends StatelessWidget {
  final DropService svc;
  const _SidebarStats({required this.svc});

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final tr = svc.cfg.tr;
    final share = svc.share;
    final rows = [
      (Icons.radar_rounded, p.accent, tr('sidebarNearby'), svc.devices.length),
      (Icons.arrow_upward_rounded, p.secondaryAccent, tr('filterSent'), svc._sentFiles),
      (
        Icons.arrow_downward_rounded,
        p.success,
        tr('filterReceived'),
        svc._receivedFiles
      ),
      if (share != null)
        (Icons.wifi_tethering_rounded, p.warmHighlight, tr('sharingNow'), share.downloads),
    ];

    return Container(
      key: const ValueKey('sidebar-statistics'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Divider(height: 1, color: p.border),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: rows[i].$2.withAlpha(24),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(rows[i].$1, size: 13.5, color: rows[i].$2),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      rows[i].$3,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: p.inkSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${rows[i].$4}',
                    style: TextStyle(
                      fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: rows[i].$2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> showRemoteDialog(BuildContext context, DropService svc,
    {void Function(Device)? onConnect, String address = '', String accessKey = '',
    bool forChat = false}) async {
  final addr = TextEditingController(text: address);
  final key = TextEditingController(text: accessKey);
  final s = svc.cfg;
  String? err;
  var busy = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: kLineBright),
        ),
        title: Text(s.tr(forChat ? 'globalChatConnect' : 'remoteConnect'),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 390,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.tr(forChat ? 'globalChatHelp' : 'remoteConnectHelp'),
                  style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.45)),
              const SizedBox(height: 16),
              TextField(
                controller: addr,
                autofocus: true,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: s.tr('remoteAddrHint'),
                  prefixIcon: const Icon(Icons.public_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: key,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: s.tr('remoteKeyHint'),
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                ),
                obscureText: true,
              ),
              if (err != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(err!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.tr('cancel'))),
          _GradButton(
            label: busy ? '...' : s.tr('remoteConnectBtn'),
            icon: Icons.link_rounded,
            compact: true,
            onTap: () async {
              if (busy) return;
              setSt(() {
                busy = true;
                err = null;
              });
              final result = await svc.connectDesk(addr.text, key.text);
              if (!ctx.mounted) return;
              if (result.device case final device?) {
                Navigator.pop(ctx);
                onConnect?.call(device);
                return;
              }
              setSt(() {
                busy = false;
                err = s.tr(result.error!);
              });
            },
          ),
        ],
      ),
    ),
  );
  addr.dispose();
  key.dispose();
}

Future<void> openGithub(BuildContext context, [String url = 'https://github.com/unqale']) async {
  var ok = false;
  try {
    ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the browser, link copied')),
    );
  }
}

class _AdaptiveColumns extends StatelessWidget {
  final List<Widget> children;
  final bool fullWidthFirst;
  final int maxColumns;
  const _AdaptiveColumns({
    required this.children,
    this.fullWidthFirst = false,
    this.maxColumns = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        var cols = box.maxWidth >= 960 ? 3 : (box.maxWidth >= kTwoColWidth - 32 ? 2 : 1);
        cols = min(cols, maxColumns);
        if (cols == 1 || children.length < 2) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
        }
        final head = fullWidthFirst ? children.take(1).toList() : <Widget>[];
        final rest = fullWidthFirst ? children.skip(1).toList() : children;
        final buckets = List.generate(cols, (_) => <Widget>[]);
        for (var i = 0; i < rest.length; i++) {
          buckets[i % cols].add(rest[i]);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...head,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var c = 0; c < cols; c++) ...[
                  if (c > 0) const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: buckets[c],
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Floating pill-shaped bottom navigation for compact / mobile viewports.
class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData, IconData, String)> items;
  final int unreadChats;
  const _NavBar({
    required this.index,
    required this.onChanged,
    required this.items,
    required this.unreadChats,
  });

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            color: p.cardElevated,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: p.borderStrong),
            boxShadow: p.cardShadow,
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Hover(
                          radius: 14,
                          scale: 1.08,
                          glow: false,
                          spotlight: false,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            padding: EdgeInsets.symmetric(
                                horizontal: i == index ? 16 : 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: i == index
                                  ? cs.primary.withAlpha(38)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: i == index
                                    ? cs.primary.withAlpha(85)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Badge.count(
                              count: unreadChats,
                              isLabelVisible: i == 3 && unreadChats > 0,
                              child: Icon(
                                i == index ? items[i].$2 : items[i].$1,
                                size: 22,
                                color: i == index ? cs.primary : p.inkMuted,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          items[i].$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                            color: i == index ? p.ink : p.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// High-craft primary action button with cohesive studio badge and gradient.
class _PowerButton extends StatelessWidget {
  const _PowerButton({required this.svc, this.iconOnly = false});

  final DropService svc;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final online = svc.online;
    final changing = svc._changingPower;
    final ready = online && svc.serverUp;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reducedMotion ? Duration.zero : const Duration(milliseconds: 220);
    final primary = Theme.of(context).colorScheme.primary;
    final action = svc.cfg.tr(online ? 'turnOff' : 'turnOn');
    final onPressed = changing ? null : () => svc.setOnline(!online);

    if (iconOnly) {
      final iconColor = ready ? p.success : (online ? p.warning : p.inkSecondary);
      return Material(
        color: iconColor.withAlpha(ready ? 28 : 16),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          child: Tooltip(
            message: action,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: iconColor.withAlpha(ready ? 110 : 65)),
              ),
              alignment: Alignment.center,
              child: changing && !reducedMotion
                  ? SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: iconColor),
                    )
                  : Icon(
                      Icons.power_settings_new_rounded,
                      size: 16,
                      color: iconColor,
                    ),
            ),
          ),
        ),
      );
    }

    // Full pill button (unified color harmony — never green inside red!)
    final pillTone = online ? p.danger : primary;
    final badgeColor = online ? p.danger : Colors.white;

    return _Hover(
      enabled: !changing,
      radius: 14,
      scale: 1.018,
      spotlight: false,
      glow: !online,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: online
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.alphaBlend(pillTone.withAlpha(26), p.cardElevated),
                    Color.alphaBlend(pillTone.withAlpha(14), p.card),
                  ],
                )
              : _actionGradient(primary),
          border: Border.all(
            color: online ? pillTone.withAlpha(115) : Colors.white.withAlpha(55),
            width: 1.1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: online
              ? null
              : [
                  BoxShadow(
                    color: primary.withAlpha(55),
                    blurRadius: 14,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 14, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: online
                          ? pillTone.withAlpha(32)
                          : Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: online
                            ? pillTone.withAlpha(110)
                            : Colors.white.withAlpha(90),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: changing && !reducedMotion
                        ? SizedBox.square(
                            key: const ValueKey('power-progress'),
                            dimension: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: badgeColor,
                            ),
                          )
                        : Icon(
                            Icons.power_settings_new_rounded,
                            size: 15,
                            color: badgeColor,
                          ),
                  ),
                  const SizedBox(width: 9),
                  AnimatedSwitcher(
                    duration: duration,
                    switchInCurve: Curves.easeOutCubic,
                    child: Text(
                      action,
                      key: ValueKey(action),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        letterSpacing: 0.1,
                        color: badgeColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool compact;
  const _GradButton({required this.label, this.icon, this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Hover(
      enabled: onTap != null,
      radius: 13,
      scale: 1.018,
      glow: true,
      child: Opacity(
        opacity: onTap == null ? 0.42 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: _actionGradient(cs.primary),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withAlpha(46), width: 1),
              boxShadow: onTap == null
                  ? null
                  : [
                      BoxShadow(
                        color: cs.primary.withAlpha(55),
                        blurRadius: 16,
                        spreadRadius: -3,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 9.5 : 12.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 17, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.15,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _Pill({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        border: Border.all(color: color.withAlpha(70)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  final String text;
  const _ValuePill(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6.5, 6, 6.5),
      decoration: BoxDecoration(
        color: cs.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: cs.primary.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.unfold_more_rounded, size: 17, color: cs.primary),
        ],
      ),
    );
  }
}

class _Ic extends StatelessWidget {
  final IconData icon;
  const _Ic(this.icon);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withAlpha(34),
            cs.primary.withAlpha(14),
          ],
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: cs.primary.withAlpha(55)),
      ),
      child: Icon(icon, size: 19, color: cs.primary),
    );
  }
}

// ------------------------------------------------------------ Devices page

class DevicesPage extends StatelessWidget {
  final DropService svc;
  final void Function(Device) onSend;
  final VoidCallback onShare;
  final void Function(Device) onChat;
  final void Function(Device) onConnect;
  const DevicesPage({
    super.key,
    required this.svc,
    required this.onSend,
    required this.onShare,
    required this.onChat,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final devs = svc.sortedDevices();
    final tr = svc.cfg.tr;
    final online = svc.online;
    return LayoutBuilder(builder: (context, box) {
      final wide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;
      final twoCol = box.maxWidth >= 820;
      final pad = wide ? 24.0 : 16.0;
      final sharing = _sharingSections(context, svc.cfg);
      final quick = _quickSettings(svc.cfg);

      final nearbyHeader = Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: cs.primary.withAlpha(24),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withAlpha(55)),
            ),
            child: Icon(Icons.devices_rounded, size: 17, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr('nearby'),
              style: tt.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: 0.2,
                color: p.ink,
              ),
            ),
          ),
          if (devs.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(28),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: cs.primary.withAlpha(75)),
              ),
              child: Text(
                '${devs.length}',
                style: TextStyle(
                  fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ),
        ],
      );

      Widget deviceCard(Device d) => _DeviceCard(
            device: d,
            showIp: svc.cfg.showIps,
            trusted: svc.cfg.isDeviceTrusted(d),
            tr: tr,
            onTrust: () => svc.cfg.toggleTrustedDevice(d),
            onTap: () => onSend(d),
            onChat: () => onChat(d),
            onRemove: () => svc.removeDevice(d),
          );

      const deviceGrid = SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 330,
        mainAxisExtent: 204,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      );

      final topBar = Container(
        height: wide ? 66 : kToolbarHeight,
        padding: EdgeInsets.symmetric(horizontal: pad),
        decoration: BoxDecoration(
          color: p.canvas.withAlpha(235),
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        child: Row(
          children: [
            if (wide) ...[
              Text(
                tr('devices'),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 21,
                  letterSpacing: 0.2,
                  color: p.ink,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: !online
                      ? p.surfaceRecessed
                      : p.success.withAlpha(22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: !online
                        ? p.border
                        : p.success.withAlpha(80),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: !online ? p.inkMuted : p.success,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      !online ? tr('statusOffline') : '${devs.length} ${tr('statusConnected')}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: !online ? p.inkSecondary : p.success,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const _BridgeLogoBadge(size: 32, glow: false),
              const SizedBox(width: 10),
              Text(
                kAppName,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  fontSize: 19,
                  color: p.ink,
                ),
              ),
            ],
            const Spacer(),
            _PowerButton(svc: svc),
          ],
        ),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          topBar,
          Expanded(
            child: _PageScroll(
              slivers: [
                if (twoCol)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 20, pad, 28),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: min(430.0, max(340.0, (box.maxWidth - 2 * pad) * 0.39)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _RadarHero(svc: svc, onSend: onSend, onChat: onChat),
                                if (svc.status.isNotEmpty || svc.progress != null) ...[
                                  const SizedBox(height: 16),
                                  _StatusCard(svc: svc),
                                ],
                                const SizedBox(height: 18),
                                quick,
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                nearbyHeader,
                                const SizedBox(height: 12),
                                if (devs.isEmpty)
                                  _EmptyDevices(svc: svc)
                                else
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: EdgeInsets.zero,
                                    gridDelegate: deviceGrid,
                                    itemCount: devs.length,
                                    itemBuilder: (context, i) => deviceCard(devs[i]),
                                  ),
                                const SizedBox(height: 18),
                                if (svc.share != null)
                                  _ShareCard(svc: svc)
                                else
                                  _ShareActions(svc: svc, onShare: onShare),
                                const SizedBox(height: 18),
                                _DeskCodeCard(svc: svc, onConnect: onConnect),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 16, pad, 12),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _DeskCodeCard(svc: svc, onConnect: onConnect),
                        const SizedBox(height: 14),
                        _RadarHero(svc: svc, onSend: onSend, onChat: onChat),
                        const SizedBox(height: 14),
                        if (svc.status.isNotEmpty || svc.progress != null) ...[
                          _StatusCard(svc: svc),
                          const SizedBox(height: 14),
                        ],
                        if (svc.share != null)
                          _ShareCard(svc: svc)
                        else
                          _ShareActions(svc: svc, onShare: onShare),
                        const SizedBox(height: 24),
                        nearbyHeader,
                        const SizedBox(height: 14),
                        if (devs.isEmpty) _EmptyDevices(svc: svc),
                      ]),
                    ),
                  ),
                  if (devs.isNotEmpty)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(pad, 0, pad, 12),
                      sliver: SliverGrid(
                        gridDelegate: deviceGrid,
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => deviceCard(devs[i]),
                          childCount: devs.length,
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 12, pad, 24),
                    sliver: SliverToBoxAdapter(
                      child: _AdaptiveColumns(maxColumns: 3, children: [quick, ...sharing]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }
}

/// Editorial Atelier Bridge Studio Canvas Card (replaces legacy radar with warm architectural motifs).
class _RadarHero extends StatefulWidget {
  final DropService svc;
  final void Function(Device) onSend;
  final void Function(Device) onChat;
  const _RadarHero({required this.svc, required this.onSend, required this.onChat});

  @override
  State<_RadarHero> createState() => _RadarHeroState();
}

class _RadarHeroState extends State<_RadarHero> with SingleTickerProviderStateMixin {
  static const _nodeSlots = [
    Offset(0, -1),
    Offset(1, -1),
    Offset(1, 0),
    Offset(1, 1),
    Offset(0, 1),
    Offset(-1, 1),
    Offset(-1, 0),
    Offset(-1, -1),
  ];

  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4));
  String? _selectedAddress;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    final svc = widget.svc;
    final tr = svc.cfg.tr;
    final devs = svc.online ? svc.sortedDevices() : <Device>[];
    final address = _selectedAddress;
    final selected = svc.online && address != null ? svc.connectedDevice(address) : null;
    if (selected == null) _selectedAddress = null;
    final animate = svc.online &&
        svc.scanning &&
        svc.cfg.showRadar &&
        !svc.cfg.compactHeader &&
        TickerMode.of(context) &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !_c.isAnimating) {
      _c
        ..reset()
        ..repeat();
    } else if (!animate && _c.isAnimating) {
      _c.stop();
    }

    return RepaintBoundary(
      child: Container(
        decoration: _editorialCardDeco(context, r: 26, borderColor: p.borderStrong),
        child: Column(
          children: [
          if (svc.cfg.showRadar && !svc.cfg.compactHeader)
            SizedBox(
              height: 236,
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  final h = box.maxHeight;
                  final c = Offset(w / 2, h / 2);
                  final horizontalRadius = (w / 2 - 48).clamp(0.0, 120.0);
                  const verticalRadius = 84.0;
                  final shown = devs.take(w < 280 ? 6 : 8).toList();
                  if (selected != null && shown.isNotEmpty && !shown.contains(selected)) {
                    shown[shown.length - 1] = selected;
                  }
                  final nodes = <Widget>[];
                  final nodeCenters = <Offset>[];
                  Offset? selectedPos;
                  for (var i = 0; i < shown.length; i++) {
                    final d = shown[i];
                    final slot = _nodeSlots[i * _nodeSlots.length ~/ shown.length];
                    final pos = c + Offset(
                      slot.dx * horizontalRadius,
                      slot.dy * verticalRadius,
                    );
                    final left = (pos.dx - 44).clamp(4.0, max(4.0, w - 92)).toDouble();
                    final top = (pos.dy - 20).clamp(4.0, max(4.0, h - 68)).toDouble();
                    final nodeCenter = Offset(left + 44, top + 20);
                    nodeCenters.add(nodeCenter);
                    if (d == selected) {
                      selectedPos = nodeCenter;
                    }
                    nodes.add(
                      Positioned(
                        key: ValueKey(svc.addressOf(d)),
                        left: left,
                        top: top,
                        width: 88,
                        child: _RadarNode(
                          device: d,
                          selected: d == selected,
                          onTap: () => setState(() {
                            final tapped = svc.addressOf(d);
                            _selectedAddress = tapped == address ? null : tapped;
                          }),
                        ),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: AtelierBridgeCanvasPainter(
                              accent: svc.online ? p.accent : p.inkMuted,
                              secondaryAccent: p.secondaryAccent,
                              warmHighlight: p.warmHighlight,
                              borderColor: p.borderStrong,
                              isDark: p.isDark,
                              isOnline: svc.online,
                              devicePositions: nodeCenters,
                              selectedPosition: selectedPos,
                            ),
                          ),
                        ),
                      ),
                      if (animate)
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: RadarSweepPainter(
                                phase: _c,
                                accent: p.accent,
                                warmHighlight: p.warmHighlight,
                                devicePositions: nodeCenters,
                                selectedPosition: selectedPos,
                              ),
                            ),
                          ),
                        ),
                      ...nodes,
                      Center(
                        child: RepaintBoundary(
                          child: Tooltip(
                            message: svc.online ? tr('scan') : tr('turnOn'),
                            child: GestureDetector(
                              onTap: svc._changingPower ? null : () {
                              if (!svc.online) {
                                svc.setOnline(true);
                              } else {
                                svc.rescan();
                              }
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: AnimatedSwitcher(
                                duration: MediaQuery.disableAnimationsOf(context)
                                    ? Duration.zero
                                    : const Duration(milliseconds: 230),
                                switchInCurve: Curves.easeOutCubic,
                                child: _RadarCenterDeviceHub(
                                  key: ValueKey<bool>(svc.online && svc.serverUp),
                                  online: svc.online && svc.serverUp,
                                  changing: svc._changingPower,
                                ),
                              ),
                            ),
                          ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, svc.cfg.compactHeader ? 20 : 6, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            svc.alias,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            !svc.online
                                ? tr('statusOffline')
                                : svc.scanning
                                    ? tr('radarScanning')
                                    : devs.isNotEmpty
                                        ? tr('radarDevicesFound')
                                            .replaceAll('{n}', '${devs.length}')
                                        : tr('radarIdle'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    RepaintBoundary(
                      child: _RoundBtn(
                        icon: Icons.refresh_rounded,
                        busy: svc.scanning,
                        tooltip: tr('scan'),
                        onTap: !svc.online ? null : () => svc.rescan(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      icon: svc.cfg.autoAccept ? Icons.bolt_rounded : Icons.shield_rounded,
                      text: svc.cfg.autoAccept ? tr('autoAccept') : tr('askFirst'),
                      color: cs.primary,
                    ),
                  ],
                ),
                if (selected != null &&
                    svc.cfg.showRadar && !svc.cfg.compactHeader) ...[
                  const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.surfaceRecessed,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                selected.isPhone ? Icons.smartphone_rounded : Icons.computer_rounded,
                                color: cs.primary,
                                size: 17,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selected.alias,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w700, color: p.ink),
                                ),
                              ),
                              IconButton(
                                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                                onPressed: () => setState(() => _selectedAddress = null),
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => widget.onChat(selected),
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                                label: Text(tr('bridgeChat')),
                              ),
                              FilledButton.tonalIcon(
                                key: const ValueKey('radar-send'),
                                onPressed: () => widget.onSend(selected),
                                icon: const Icon(Icons.attach_file_rounded, size: 16),
                                label: Text(tr('send')),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

/// Adaptive center radar hub that shapes itself as a PC Monitor (Desktop) or Smartphone (Mobile).
class _RadarCenterDeviceHub extends StatelessWidget {
  final bool online;
  final bool changing;

  const _RadarCenterDeviceHub({
    super.key,
    required this.online,
    required this.changing,
  });

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final isMobile = Platform.isAndroid || Platform.isIOS;
    final activeColor = online
        ? p.accent
        : changing
            ? p.warning
            : p.inkSecondary;

    if (isMobile) {
      // Mobile Smartphone Frame Silhouette (Vertical 46x62)
      return Container(
        width: 46,
        height: 62,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0E1124), Color(0xFF060714)],
          ),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: activeColor.withValues(alpha: online ? 0.85 : 0.45),
            width: 1.8,
          ),
          boxShadow: online
              ? [
                  BoxShadow(
                    color: p.accent.withValues(alpha: 0.35),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 4),
            Container(
              width: 12,
              height: 2.5,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Expanded(
              child: Center(
                child: online
                    ? Padding(
                        padding: const EdgeInsets.all(5),
                        child: Image.asset(
                          'assets/brand/logo_mark.png',
                          cacheWidth: 96,
                          filterQuality: FilterQuality.medium,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => Icon(
                            Icons.smartphone_rounded,
                            size: 20,
                            color: activeColor,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.power_settings_new_rounded,
                        size: 20,
                        color: activeColor,
                      ),
              ),
            ),
            Container(
              width: 14,
              height: 2.5,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: online ? p.success : activeColor.withValues(alpha: 0.40),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      );
    }

    // PC / Desktop Widescreen Monitor + Stand Silhouette (66x58)
    return SizedBox(
      width: 66,
      height: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0E1124), Color(0xFF060714)],
              ),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: activeColor.withValues(alpha: online ? 0.85 : 0.45),
                width: 1.8,
              ),
              boxShadow: online
                  ? [
                      BoxShadow(
                        color: p.accent.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (online)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 4),
                    child: Image.asset(
                      'assets/brand/logo_mark.png',
                      cacheWidth: 112,
                      filterQuality: FilterQuality.medium,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.desktop_windows_rounded,
                        size: 22,
                        color: activeColor,
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.power_settings_new_rounded,
                    size: 20,
                    color: activeColor,
                  ),
                Positioned(
                  right: 5,
                  bottom: 4,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: online ? p.success : p.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 5,
            color: activeColor.withValues(alpha: online ? 0.75 : 0.40),
          ),
          Container(
            width: 28,
            height: 3.5,
            decoration: BoxDecoration(
              color: activeColor.withValues(alpha: online ? 0.85 : 0.45),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final bool busy;
  final String tooltip;
  final VoidCallback? onTap;
  const _RoundBtn(
      {required this.icon, required this.busy, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    return _Hover(
      enabled: onTap != null,
      radius: 23,
      scale: 1.08,
      spotlight: false,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: cs.primary.withAlpha(onTap == null && !busy ? 14 : 26),
          shape: CircleBorder(
            side: BorderSide(color: cs.primary.withAlpha(onTap == null ? 30 : 80)),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 19,
                        height: 19,
                        child:
                            CircularProgressIndicator(strokeWidth: 2.3, color: cs.primary),
                      )
                    : Icon(icon, color: onTap == null ? p.inkMuted : cs.primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarNode extends StatelessWidget {
  final Device device;
  final bool selected;
  final VoidCallback onTap;
  const _RadarNode({required this.device, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: device.alias,
          isSelected: selected,
          onPressed: onTap,
          style: IconButton.styleFrom(
            visualDensity: VisualDensity.compact,
            backgroundColor: selected ? cs.primary : p.cardElevated,
            foregroundColor: selected ? cs.onPrimary : cs.primary,
            side: BorderSide(
              color: cs.primary.withAlpha(selected ? 255 : 140),
              width: selected ? 1.8 : 1.1,
            ),
          ),
          icon: Icon(
            device.isPhone ? Icons.smartphone_rounded : Icons.computer_rounded,
            size: 18,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
          decoration: BoxDecoration(
            color: selected ? cs.primary.withAlpha(230) : p.card.withAlpha(235),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? cs.primary : p.borderStrong,
              width: 0.8,
            ),
          ),
          child: Text(
            device.alias,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? cs.onPrimary : p.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final DropService svc;
  const _StatusCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final (Color bg, Color fg, IconData icon) = switch (svc.kind) {
      StatusKind.success => (
          p.success.withAlpha(p.isDark ? 36 : 24),
          p.success,
          Icons.check_circle_rounded
        ),
      StatusKind.error => (
          p.danger.withAlpha(p.isDark ? 36 : 24),
          p.danger,
          Icons.error_rounded
        ),
      StatusKind.info => (
          p.accent.withAlpha(p.isDark ? 36 : 24),
          p.accent,
          Icons.sync_rounded
        ),
    };
    final busy = svc.progress != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: fg.withAlpha(90)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: fg.withAlpha(20), blurRadius: 18, spreadRadius: -2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  svc.status,
                  style: TextStyle(
                    color: p.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (!busy)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: svc.clearStatus,
                  icon: Icon(Icons.close_rounded, color: fg, size: 19),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '${((svc.progress ?? 0) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                      color: fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          if (busy)
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: svc.progress,
                  minHeight: 6,
                  backgroundColor: p.surfaceRecessed,
                  color: fg,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShareActions extends StatelessWidget {
  final DropService svc;
  final VoidCallback onShare;
  const _ShareActions({required this.svc, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final tr = svc.cfg.tr;
    return SizedBox(
      width: double.infinity,
      child: _ActionTile(
        icon: Icons.link_rounded,
        title: tr('shareViaLink'),
        subtitle: tr('shareDesc'),
        filled: true,
        onTap: svc.serverUp ? onShare : null,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback? onTap;
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.filled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    return _Hover(
      enabled: onTap != null,
      radius: 22,
      scale: 1.01,
      glow: false,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: filled ? cs.primary.withAlpha(85) : p.border),
              gradient: filled
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [p.cardTinted, p.card],
                    )
                  : null,
              color: filled ? null : p.card,
              boxShadow: p.cardShadow,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: cs.primary.withAlpha(28),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: cs.primary.withAlpha(65)),
                      ),
                      child: Icon(icon, size: 22, color: cs.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: p.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(8.5),
                      decoration: BoxDecoration(
                        color: cs.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: cs.primary.withAlpha(60)),
                      ),
                      child: Icon(Icons.arrow_forward_rounded, size: 18, color: cs.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final DropService svc;
  const _ShareCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    final s = svc.share;
    if (s == null) return const SizedBox.shrink();
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final urls = svc.shareUrls;
    final tr = svc.cfg.tr;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withAlpha(105)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.cardTinted, p.card],
        ),
        boxShadow: p.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(40),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.wifi_tethering_rounded, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('sharingNow'),
                  style: tt.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800, color: p.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(
                icon: Icons.insert_drive_file_outlined,
                text: '${s.files.length}',
                color: p.inkSecondary,
              ),
              _Pill(
                icon: Icons.download_rounded,
                text: svc.cfg.maxDownloads > 0
                    ? '${s.downloads} / ${svc.cfg.maxDownloads}'
                    : '${s.downloads}',
                color: p.success,
              ),
              if (s.pin != null)
                _Pill(icon: Icons.pin_outlined, text: 'PIN: ${s.pin}', color: cs.primary),
              if (svc.cfg.oneTimeDownload)
                _Pill(icon: Icons.looks_one_rounded, text: '1×', color: p.warning),
              if (svc.cfg.shareMinutes > 0)
                _Pill(
                  icon: Icons.timer_outlined,
                  text: '${svc.cfg.shareMinutes} min',
                  color: p.inkSecondary,
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (urls.isEmpty)
            Text('No network found', style: TextStyle(color: cs.error))
          else ...[
            for (final u in urls)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.only(left: 14),
                decoration: _editorialCardDeco(context, r: 14, elevated: true),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        u,
                        style: tt.bodyMedium?.copyWith(
                          fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                          color: p.ink,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: tr('copyLink'),
                      icon: Icon(Icons.copy_rounded, size: 19, color: cs.primary),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: u));
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(tr('linkCopied'))));
                      },
                    ),
                  ],
                ),
              ),
            if (svc.cfg.showQr) ...[
              const SizedBox(height: 8),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: QrImageView(
                          data: urls.first,
                          version: QrVersions.auto,
                          size: 160,
                          padding: const EdgeInsets.all(6),
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('qrTitle'),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: svc.stopShare,
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(tr('stopShare')),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.danger,
                side: BorderSide(color: p.danger.withAlpha(120)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final Device device;
  final VoidCallback onTap;
  final VoidCallback onTrust;
  final bool showIp;
  final bool trusted;
  final String Function(String) tr;
  final VoidCallback onChat;
  final VoidCallback onRemove;
  const _DeviceCard({
    required this.device,
    required this.onTap,
    required this.onTrust,
    required this.showIp,
    required this.trusted,
    required this.tr,
    required this.onChat,
    required this.onRemove,
  });

  List<PopupMenuEntry<VoidCallback>> _menuItems() => [
        PopupMenuItem(value: onChat, child: Text(tr('bridgeChat'))),
        PopupMenuItem(value: onTap, child: Text(tr('send'))),
        const PopupMenuDivider(),
        PopupMenuItem(value: onRemove, child: Text(tr('deviceRemove'))),
      ];

  Future<void> _showMenu(BuildContext context, Offset position) async {
    final overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final point = overlay.globalToLocal(position);
    final action = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromSize(point & Size.zero, overlay.size),
      items: _menuItems(),
    );
    if (context.mounted) action?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    return _Hover(
      radius: 22,
      scale: 1.022,
      child: Container(
        decoration: _editorialCardDeco(
          context,
          r: 22,
          borderColor: trusted ? cs.primary.withAlpha(130) : p.borderStrong,
          glow: trusted ? cs.primary : null,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: EditorialMotifPainter(
                      variant: EditorialMotifVariant.pebbleRings,
                      primary: p.accent,
                      secondary: p.secondaryAccent,
                      warm: p.warmHighlight,
                      opacity: 0.14,
                    ),
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onTap,
                onSecondaryTapUp: (details) => _showMenu(context, details.globalPosition),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  cs.primary.withAlpha(38),
                                  cs.primary.withAlpha(14),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.primary.withAlpha(70)),
                            ),
                            child: Icon(
                              device.isPhone ? Icons.smartphone_rounded : Icons.computer_rounded,
                              color: cs.primary,
                            ),
                          ),
                          const Spacer(),
                          Tooltip(
                            message: trusted ? 'Trusted (tap to remove)' : 'Mark as trusted',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: onTrust,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  trusted ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: trusted ? p.warning : p.inkMuted,
                                ),
                              ),
                            ),
                          ),
                          PopupMenuButton<VoidCallback>(
                            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                            onSelected: (action) => action(),
                            itemBuilder: (_) => _menuItems(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        device.alias,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        showIp
                            ? (device.remote && device.port > 0
                                ? '${device.ip}:${device.port}'
                                : device.ip)
                            : 'Hidden',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                          fontSize: 12,
                          color: p.inkSecondary,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        child: _GradButton(
                          label: tr('send'),
                          icon: Icons.send_rounded,
                          compact: true,
                          onTap: onTap,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  final DropService svc;
  const _EmptyDevices({required this.svc});

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    final tr = svc.cfg.tr;
    final off = !svc.online;
    final scanning = !off && svc.scanning;
    return RepaintBoundary(
      child: Container(
        decoration: _editorialCardDeco(context, r: 22),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: EditorialMotifPainter(
                      variant: EditorialMotifVariant.horizonArch,
                      primary: p.accent,
                      secondary: p.secondaryAccent,
                      warm: p.warmHighlight,
                      opacity: 0.14,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.primary.withAlpha(22),
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.primary.withAlpha(60)),
                    ),
                    child: scanning
                        ? const RepaintBoundary(
                            child: SizedBox.square(
                              dimension: 32,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Icon(
                            off ? Icons.power_settings_new_rounded : Icons.wifi_find_rounded,
                            size: 32,
                            color: cs.primary,
                          ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr(off
                        ? 'offlineTitle'
                        : scanning
                            ? 'statusScanning'
                            : 'noDevices'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: p.ink, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Text(
                      off ? tr('offlineHint') : tr('noDevicesHint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.inkSecondary, fontSize: 13, height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 168, maxWidth: 230),
                    child: off
                        ? _PowerButton(svc: svc)
                        : _GradButton(
                            label: tr('scan'),
                            icon: Icons.refresh_rounded,
                            onTap: svc.scanning ? null : svc.scan,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ AnyDesk-style Quick Desk card

class _DeskCodeCard extends StatefulWidget {
  final DropService svc;
  final void Function(Device) onConnect;

  const _DeskCodeCard({required this.svc, required this.onConnect});

  @override
  State<_DeskCodeCard> createState() => _DeskCodeCardState();
}

class _DeskCodeCardState extends State<_DeskCodeCard> {
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await widget.svc.connectDesk(code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result.error;
    });
    if (result.device case final device?) {
      _codeCtrl.clear();
      widget.onConnect(device);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final svc = widget.svc;
    final tr = svc.cfg.tr;
    final cs = Theme.of(context).colorScheme;
    final code = svc.deskCode;
    final available = svc.online && svc.serverUp;

    return Container(
      decoration: _editorialCardDeco(context, r: 22, borderColor: p.borderStrong),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: EditorialMotifPainter(
                    variant: EditorialMotifVariant.parcelGrid,
                    primary: p.accent,
                    secondary: p.secondaryAccent,
                    warm: p.warmHighlight,
                    opacity: 0.14,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: LayoutBuilder(
              builder: (context, box) {
                final horizontalInput = box.maxWidth >= 420;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: cs.primary.withAlpha(26),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: cs.primary.withAlpha(65)),
                          ),
                          child: Icon(Icons.qr_code_scanner_rounded, size: 19, color: cs.primary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('deskTitle'),
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: p.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tr(available ? 'deskHelp' : 'deskOffline'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: p.inkSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                          decoration: BoxDecoration(
                            color: p.surfaceRecessed,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: cs.primary.withAlpha(75)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tr('deskOwnCode'),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: cs.primary,
                                    ),
                                  ),
                                  SelectableText(
                                    code.isEmpty ? '—' : code,
                                    style: TextStyle(
                                      fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                      fontSize: 15,
                                      color: p.ink,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: tr('copyLink'),
                                onPressed: code.isEmpty
                                    ? null
                                    : () {
                                        Clipboard.setData(ClipboardData(text: code));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(tr('copied'))),
                                        );
                                      },
                                icon: Icon(Icons.copy_rounded, size: 16, color: cs.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    if (horizontalInput)
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeCtrl,
                              enabled: available && !_busy,
                              textCapitalization: TextCapitalization.characters,
                              style: TextStyle(
                                fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: p.ink,
                              ),
                              decoration: InputDecoration(
                                labelText: tr('deskTitle'),
                                hintText: 'ABCD-EFGH',
                                prefixIcon: const Icon(Icons.link_rounded, size: 19),
                                isDense: true,
                              ),
                              onSubmitted: (_) => _connect(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 156,
                            child: _GradButton(
                              label: _busy ? '…' : tr('remoteConnectBtn'),
                              icon: Icons.link_rounded,
                              onTap: available && !_busy ? _connect : null,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      TextField(
                        controller: _codeCtrl,
                        enabled: available && !_busy,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(
                          fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: p.ink,
                        ),
                        decoration: InputDecoration(
                          labelText: tr('deskTitle'),
                          hintText: 'ABCD-EFGH',
                          prefixIcon: const Icon(Icons.link_rounded, size: 19),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _connect(),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: _GradButton(
                          label: _busy ? '…' : tr('remoteConnectBtn'),
                          icon: Icons.link_rounded,
                          onTap: available && !_busy ? _connect : null,
                        ),
                      ),
                    ],
                    if (_error case final error?) ...[
                      const SizedBox(height: 8),
                      Text(tr(error),
                          style: TextStyle(
                              color: cs.error, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ Global Connect page

class GlobalConnectPage extends StatefulWidget {
  final DropService svc;
  final void Function(Device) onSend;
  final void Function(Device) onOpenChat;
  final void Function(Device) onConnect;
  const GlobalConnectPage({
    super.key,
    required this.svc,
    required this.onSend,
    required this.onOpenChat,
    required this.onConnect,
  });

  @override
  State<GlobalConnectPage> createState() => _GlobalConnectPageState();
}

class _GlobalConnectPageState extends State<GlobalConnectPage> {
  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final svc = widget.svc;
    final s = svc.cfg;
    final tr = s.tr;
    final cs = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;
    final pad = wide ? 24.0 : 16.0;

    Widget savedPeersCard() {
      final remotes = [
        ...s.remotes,
        for (final d in svc.devices.values)
          if (d.connectionToken.isNotEmpty &&
              !s.remotes.any((r) => r['host'] == d.ip && svc._savedPort(r) == d.port))
            {'host': d.ip, 'port': d.port, 'alias': d.alias, 'deskId': d.deskId},
      ];
      return Container(
        decoration: _editorialCardDeco(context, r: 26, borderColor: p.borderStrong),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: EditorialMotifPainter(
                      variant: EditorialMotifVariant.archBridge,
                      primary: p.accent,
                      secondary: p.secondaryAccent,
                      warm: p.warmHighlight,
                      opacity: 0.14,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _Ic(Icons.hub_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr('remoteSaved'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: p.ink,
                          ),
                        ),
                      ),
                      if (remotes.isNotEmpty)
                        Badge(
                          label: Text('${remotes.length}'),
                          backgroundColor: cs.primary,
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: tr('scan'),
                        onPressed: svc.scanning ? null : svc.scan,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (remotes.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 16),
                      decoration: BoxDecoration(
                        color: p.surfaceRecessed,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.public_off_rounded,
                              size: 36, color: cs.primary.withAlpha(150)),
                          const SizedBox(height: 10),
                          Text(
                            tr('remoteNone'),
                            style: TextStyle(color: p.inkSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    )
                  else
                    ...remotes.map((r) {
                      final host = '${r['host'] ?? ''}';
                      final port = (r['port'] as int?) ?? s.port;
                      final alias = '${r['alias'] ?? host}';
                      final key = '${r['key'] ?? ''}';
                      final live = svc.connectedDevice('$host:$port');
                      final isOnline = live?.connectionToken.isNotEmpty ?? false;
                      final dev = live ??
                          Device(
                            alias.isEmpty ? host : alias,
                            host,
                            'Remote',
                            port: port,
                            key: key,
                            remote: true,
                          );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _Hover(
                          radius: 18,
                          scale: 1.01,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: p.surfaceRecessed,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isOnline ? cs.primary.withAlpha(95) : p.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: (isOnline ? cs.primary : p.inkMuted).withAlpha(32),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Icon(
                                    Icons.language_rounded,
                                    color: isOnline ? cs.primary : p.inkSecondary,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              dev.alias,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14.5,
                                                color: p.ink,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isOnline
                                                  ? p.success
                                                  : p.inkMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                  ),
                                ),
                                if (isOnline) ...[
                                  IconButton(
                                    tooltip: tr('bridgeChat'),
                                    onPressed: () => widget.onOpenChat(dev),
                                    icon: Icon(Icons.forum_rounded, size: 19, color: cs.primary),
                                  ),
                                  IconButton(
                                    tooltip: tr('send'),
                                    onPressed: () => widget.onSend(dev),
                                    icon: Icon(Icons.send_rounded, size: 19, color: cs.primary),
                                  ),
                                ] else
                                  IconButton(
                                    tooltip: tr('remoteConnectBtn'),
                                    onPressed: () => showRemoteDialog(
                                      context,
                                      svc,
                                      onConnect: widget.onConnect,
                                      address: '$host:$port',
                                      accessKey: key,
                                    ),
                                    icon: Icon(Icons.link_rounded, size: 19, color: cs.primary),
                                  ),
                                IconButton(
                                  tooltip: tr('deviceRemove'),
                                  onPressed: () => svc.removeRemote(host, port),
                                  icon: Icon(Icons.delete_outline_rounded,
                                      size: 19, color: p.danger),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _PageScroll(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: p.canvas.withAlpha(244),
          surfaceTintColor: Colors.transparent,
          toolbarHeight: wide ? 72 : kToolbarHeight,
          titleSpacing: pad,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary.withAlpha(65)),
                ),
                child: Icon(Icons.public_rounded, size: 22, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('globalConnect'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        height: 1.1,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr('globalConnectSub'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 28),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, box) {
                if (box.maxWidth >= 820) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 11,
                        child: Column(
                          children: [
                            _DeskCodeCard(svc: svc, onConnect: widget.onConnect),
                          ],
                        ),
                      ),
                      const SizedBox(width: 22),
                      Expanded(
                        flex: 10,
                        child: Column(
                          children: [
                            savedPeersCard(),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Column(
                  children: [
                    _DeskCodeCard(svc: svc, onConnect: widget.onConnect),
                    const SizedBox(height: 16),
                    savedPeersCard(),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Global Transfer page

class GlobalTransferPage extends StatefulWidget {
  final DropService svc;
  final void Function(Device) onSend;
  final VoidCallback onShare;
  const GlobalTransferPage({
    super.key,
    required this.svc,
    required this.onSend,
    required this.onShare,
  });

  @override
  State<GlobalTransferPage> createState() => _GlobalTransferPageState();
}

class _GlobalTransferPageState extends State<GlobalTransferPage> {
  String? _selectedAddress;

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final svc = widget.svc;
    final tr = svc.cfg.tr;
    final cs = Theme.of(context).colorScheme;
    final devs = svc.sortedDevices();
    final wide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;
    final pad = wide ? 24.0 : 16.0;

    final address = _selectedAddress;
    final selected = address == null
        ? (devs.length == 1 ? devs.single : null)
        : svc.connectedDevice(address);

    Widget launchpadCard() {
      return Container(
        decoration: _editorialCardDeco(
          context,
          r: 28,
          borderColor: cs.primary.withAlpha(90),
          glow: cs.primary,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: EditorialMotifPainter(
                      variant: EditorialMotifVariant.steppedCards,
                      primary: p.accent,
                      secondary: p.secondaryAccent,
                      warm: p.warmHighlight,
                      opacity: 0.16,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  EditorialLaunchpadIllustration(
                    accent: p.accent,
                    secondary: p.secondaryAccent,
                    warm: p.warmHighlight,
                    size: 82,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr('dropZoneTitle'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('dropZoneSub'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: p.inkSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 22),
                  if (devs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: p.surfaceRecessed,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.radar_rounded, color: cs.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              tr(svc.online ? 'noDevicesHint' : 'offlineHint'),
                              style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _GradButton(
                            label: tr(svc.online ? 'scan' : 'turnOn'),
                            icon: svc.online
                                ? Icons.refresh_rounded
                                : Icons.power_settings_new_rounded,
                            compact: true,
                            onTap: svc.scanning
                                ? null
                                : (svc.online ? svc.scan : () => svc.setOnline(true)),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        tr('selectTargetPeer'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: p.inkSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: devs.map((d) {
                        final active = selected == d;
                        return ChoiceChip(
                          selected: active,
                          label: Text(d.alias, maxLines: 1, overflow: TextOverflow.ellipsis),
                          avatar: Icon(
                            d.remote
                                ? Icons.public_rounded
                                : (d.isPhone ? Icons.smartphone_rounded : Icons.computer_rounded),
                            size: 16,
                            color: active ? cs.onPrimary : cs.primary,
                          ),
                          selectedColor: cs.primary,
                          labelStyle: TextStyle(
                            color: active ? cs.onPrimary : p.ink,
                            fontWeight: FontWeight.w700,
                          ),
                          onSelected: (_) => setState(() => _selectedAddress = svc.addressOf(d)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: _GradButton(
                        label: selected == null
                            ? tr('selectTargetPeer')
                            : '${tr('selectFiles')} → ${selected.alias}',
                        icon: Icons.rocket_launch_rounded,
                        onTap: selected == null ? null : () => widget.onSend(selected),
                      ),
                    ),
                  ],
                  if (svc.status.isNotEmpty || svc.progress != null) ...[
                    const SizedBox(height: 18),
                    _StatusCard(svc: svc),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _PageScroll(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: p.canvas.withAlpha(244),
          surfaceTintColor: Colors.transparent,
          toolbarHeight: wide ? 72 : kToolbarHeight,
          titleSpacing: pad,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary.withAlpha(65)),
                ),
                child: Icon(Icons.swap_horiz_rounded, size: 22, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('globalTransfer'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        height: 1.1,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr('globalTransferSub'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 28),
          sliver: SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, box) {
                final shareWidget = svc.share != null
                    ? _ShareCard(svc: svc)
                    : _ShareActions(svc: svc, onShare: widget.onShare);
                final sharingCols = _sharingSections(context, svc.cfg);
                if (box.maxWidth >= 820) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: launchpadCard()),
                          const SizedBox(width: 22),
                          Expanded(flex: 10, child: shareWidget),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _AdaptiveColumns(maxColumns: 3, children: sharingCols),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    launchpadCard(),
                    const SizedBox(height: 16),
                    shareWidget,
                    const SizedBox(height: 20),
                    _AdaptiveColumns(maxColumns: 3, children: sharingCols),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ Bridge Chat page

class BridgeChatPage extends StatefulWidget {
  final DropService svc;
  final String? address;
  final void Function(String?) onTargetChanged;
  final void Function(Device) onSendFiles;
  const BridgeChatPage({
    super.key,
    required this.svc,
    required this.address,
    required this.onTargetChanged,
    required this.onSendFiles,
  });

  @override
  State<BridgeChatPage> createState() => _BridgeChatPageState();
}

class _BridgeChatPageState extends State<BridgeChatPage> {
  final _msgCtrl = TextEditingController();
  final Map<String?, TextEditingValue> _drafts = {};
  String? get _targetIp => widget.address;
  bool _sending = false;
  bool _requestingConnection = false;

  @override
  void didUpdateWidget(covariant BridgeChatPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.address == widget.address) return;
    if (_msgCtrl.text.isEmpty) {
      _drafts.remove(oldWidget.address);
    } else {
      _drafts[oldWidget.address] = _msgCtrl.value;
    }
    _msgCtrl.value = _drafts[widget.address] ?? TextEditingValue.empty;
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendText([String? overrideText]) async {
    final text = (overrideText ?? _msgCtrl.text).trim();
    if (text.isEmpty || _sending) return;
    final address = _targetIp;
    final svc = widget.svc;
    var target = address == null ? null : svc.connectedDevice(address);
    if (address != null && target == null) return;
    setState(() {
      _sending = true;
      _requestingConnection = target != null && target.connectionToken.isEmpty;
    });
    try {
      if (target != null && target.connectionToken.isEmpty) {
        final connection = await svc.connectChat(target);
        if (!mounted) return;
        target = connection.device;
        if (target == null) {
          _showSendError(connection.error ?? 'chatSendFailed');
          return;
        }
        setState(() => _requestingConnection = false);
      }
      if (await svc.sendChatMessage(target, text)) {
        if (mounted && overrideText == null) {
          if (address == _targetIp && text == _msgCtrl.text.trim()) {
            _msgCtrl.clear();
          } else if (address != _targetIp && _drafts[address]?.text.trim() == text) {
            _drafts.remove(address);
          }
        }
      } else if (mounted) {
        _showSendError('chatSendFailed');
      }
    } finally {
      if (mounted) {
        setState(() {
          _requestingConnection = false;
          _sending = false;
        });
      }
    }
  }

  void _showSendError(String key) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.svc.cfg.tr(key))),
    );
  }

  Future<void> _sendClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) return;
    await _sendText(text);
  }

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final svc = widget.svc;
    final tr = svc.cfg.tr;
    final cs = Theme.of(context).colorScheme;
    final reachable = svc.online ? svc.sortedDevices() : <Device>[];
    final approvedCount = reachable.where((d) => d.connectionToken.isNotEmpty).length;
    final peers = {
      ...svc._chatPeers,
      for (final device in reachable) svc.addressOf(device): device,
    };
    final devs = peers.values.toList()
      ..sort((a, b) => a.alias.toLowerCase().compareTo(b.alias.toLowerCase()));
    final address = _targetIp;
    final msgs = address == null
        ? svc.messages
        : svc.messages.where((message) => message.peerIp == address).toList();
    final wide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;
    final pad = wide ? 24.0 : 16.0;
    final target = svc.online && address != null ? svc.connectedDevice(address) : null;
    final canSend = svc.online && (address == null ? approvedCount > 0 : target != null);
    final mutedUntil = address == null ? null : svc.chatMutedUntil(address);

    String presence(Device? device) =>
        tr(device == null ? 'statusOffline' : 'chatOnline');

    Widget channelRail() {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _editorialCardDeco(context, r: 24, borderColor: p.borderStrong),
        child: Material(
          color: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _BridgeLogoBadge(size: 32, glow: false),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('selectTargetPeer'),
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: p.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                dense: true,
                selected: _targetIp == null,
                selectedTileColor: cs.primary.withAlpha(32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                leading: Icon(Icons.campaign_rounded,
                    color: _targetIp == null ? cs.primary : p.inkMuted),
                title: Text(
                  tr('allPeersChannel'),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _targetIp == null ? cs.primary : p.ink,
                  ),
                ),
                subtitle: Text(
                  '$approvedCount ${tr('statusConnected')}',
                  style: TextStyle(fontSize: 11, color: p.inkSecondary),
                ),
                onTap: () => widget.onTargetChanged(null),
              ),
              if (devs.isNotEmpty) Divider(height: 16, color: p.border),
              ...devs.map((d) {
                final sel = _targetIp == svc.addressOf(d);
                final live = svc.online ? svc.connectedDevice(svc.addressOf(d)) : null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ListTile(
                    dense: true,
                    selected: sel,
                    selectedTileColor: cs.primary.withAlpha(32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    leading: Icon(
                      d.remote
                          ? Icons.public_rounded
                          : (d.isPhone ? Icons.smartphone_rounded : Icons.computer_rounded),
                      color: sel ? cs.primary : p.inkSecondary,
                      size: 20,
                    ),
                    title: Text(
                      d.alias,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: sel ? cs.primary : p.ink,
                      ),
                    ),
                    subtitle: Text(
                      presence(live),
                      style: TextStyle(
                        fontSize: 11,
                        color: live != null ? p.success : p.inkSecondary,
                        fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: tr('send'),
                      icon: Icon(Icons.attach_file_rounded, size: 17, color: cs.primary),
                      onPressed: live == null ? null : () => widget.onSendFiles(live),
                    ),
                    onTap: () => widget.onTargetChanged(svc.addressOf(d)),
                  ),
                );
              }),
            ],
          ),
        ),
      );
    }

    Widget chatFeed(double height, {bool compact = false}) {
      return Container(
        height: height,
        decoration: _editorialCardDeco(context, r: 26, borderColor: p.borderStrong),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: p.border)),
              ),
              child: Row(
                children: [
                  Icon(
                    address == null ? Icons.campaign_rounded : Icons.chat_bubble_rounded,
                    size: 20,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: compact
                        ? DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: peers.containsKey(address) ? address : '',
                              items: [
                                DropdownMenuItem(value: '', child: Text(
                                  tr('allPeersChannel'), overflow: TextOverflow.ellipsis,
                                )),
                                for (final device in devs)
                                  DropdownMenuItem(
                                    value: svc.addressOf(device),
                                    child: Text(device.alias, overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                              onChanged: (value) =>
                                  widget.onTargetChanged(value == '' ? null : value),
                            ),
                          )
                        : Text(
                      address == null
                          ? tr('allPeersChannel')
                          : peers[address]?.alias ?? tr('statusOffline'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        color: p.ink,
                      ),
                    ),
                  ),
                  if (address != null)
                    PopupMenuButton<Duration>(
                      tooltip: tr(mutedUntil == null ? 'muteChat' : 'unmuteChat'),
                      icon: Icon(mutedUntil == null
                          ? Icons.notifications_outlined : Icons.notifications_off_outlined),
                      onSelected: (duration) => svc.muteChat(address, duration),
                      itemBuilder: (context) => [
                        if (mutedUntil != null)
                          PopupMenuItem(value: Duration.zero, child: Text(tr('unmuteChat'))),
                        for (final minutes in [15, 60, 480])
                          PopupMenuItem(
                            value: Duration(minutes: minutes),
                            child: Text(minutes == 15
                                ? tr('muteMinutes').replaceAll('{n}', '15')
                                : tr('muteHours').replaceAll('{n}', '${minutes ~/ 60}')),
                          ),
                      ],
                    ),
                  if (target != null)
                    IconButton(
                      tooltip: tr('send'),
                      icon: const Icon(Icons.attach_file_rounded, size: 19),
                      onPressed: () => widget.onSendFiles(target),
                    ),
                  IconButton(
                    tooltip: tr('sendClipboard'),
                    onPressed: canSend && !_sending ? _sendClipboard : null,
                    icon: const Icon(Icons.content_paste_go_rounded, size: 17),
                  ),
                  if (msgs.isNotEmpty)
                    IconButton(
                      tooltip: tr('clearChat'),
                      onPressed: svc.clearChat,
                      icon: Icon(Icons.delete_sweep_rounded,
                          size: 20, color: p.inkSecondary),
                    ),
                ],
              ),
            ),
            if (address != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    mutedUntil == null
                        ? presence(target)
                        : '${presence(target)} · ${tr('muteChatUntil').replaceAll('{time}',
                            TimeOfDay.fromDateTime(mutedUntil).format(context))}',
                    style: TextStyle(color: target == null ? p.inkSecondary : p.success),
                  ),
                ),
              ),
            Expanded(
              child: msgs.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _BridgeLogoBadge(size: 56),
                            const SizedBox(height: 14),
                            Text(
                              tr('chatEmpty'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: p.ink,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tr('chatEmptySub'),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: msgs.length,
                      itemBuilder: (context, i) {
                        final m = msgs[i];
                        final align =
                            m.outgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start;
                        final bubbleColor =
                            m.outgoing ? cs.primary.withAlpha(32) : p.surfaceRecessed;
                        final borderColor =
                            m.outgoing ? cs.primary.withAlpha(95) : p.borderStrong;
                        final tod = TimeOfDay.fromDateTime(m.time);
                        final timeStr =
                            '${tod.hour.toString().padLeft(2, '0')}:${tod.minute.toString().padLeft(2, '0')}';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: align,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${m.sender} • $timeStr',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: p.inkSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: m.text));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(tr('copied'))),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      child: Icon(Icons.copy_rounded,
                                          size: 13, color: cs.primary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Container(
                                constraints: const BoxConstraints(maxWidth: 520),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                                decoration: BoxDecoration(
                                  color: bubbleColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor),
                                ),
                                child: SelectableText(
                                  m.text,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: p.ink,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_requestingConnection)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        tr('chatApprovalPending'),
                        style: TextStyle(color: p.inkSecondary, fontSize: 12),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _msgCtrl,
                          enabled: svc.online && (address != null || approvedCount > 0),
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            hintText: tr('chatInputHint'),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _sendText(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: tr('sendMsg'),
                        onPressed: _sending || !canSend ? null : () => _sendText(),
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _PageScroll(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: p.canvas.withAlpha(244),
          surfaceTintColor: Colors.transparent,
          toolbarHeight: wide ? 72 : kToolbarHeight,
          titleSpacing: pad,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withAlpha(28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.primary.withAlpha(65)),
                ),
                child: Icon(Icons.forum_rounded, size: 22, color: cs.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('bridgeChat'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        height: 1.1,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr('bridgeChatSub'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('globalChatConnect'),
                onPressed: () => showRemoteDialog(
                  context, svc,
                  forChat: true,
                  onConnect: (device) {
                    if (mounted) widget.onTargetChanged(svc.addressOf(device));
                  },
                ),
                icon: const Icon(Icons.add_link_rounded),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 8, pad, 28),
          sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final height = (constraints.viewportMainAxisExtent -
                    (wide ? 72 : kToolbarHeight) - 36).clamp(280.0, 660.0);
                if (constraints.crossAxisExtent >= 820) {
                  return SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 280, child: channelRail()),
                        const SizedBox(width: 20),
                        Expanded(child: chatFeed(height)),
                      ],
                    ),
                  );
                }
                return SliverToBoxAdapter(child: chatFeed(height, compact: true));
              },
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ History page

class HistoryPage extends StatefulWidget {
  final DropService svc;
  const HistoryPage({super.key, required this.svc});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _filter = 0;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _revealOrCheckFile(HistoryItem h) async {
    final path = h.path;
    if (path == null || path.isEmpty) return;
    final tr = widget.svc.cfg.tr;
    final file = File(path);
    var exists = false;
    try {
      exists = file.existsSync();
    } catch (_) {}
    if (!mounted) return;
    if (!exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF7F1D1D),
          content: Text(tr('historyFileMissing')),
        ),
      );
      return;
    }
    if (Platform.isWindows) {
      try {
        await Process.run('explorer', ['/select,$path']);
        return;
      } catch (_) {}
    } else if (Platform.isMacOS) {
      try {
        await Process.run('open', ['-R', path]);
        return;
      } catch (_) {}
    } else if (Platform.isLinux) {
      try {
        await Process.run('xdg-open', [file.parent.path]);
        return;
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${tr('stageSavedAt')}: $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final svc = widget.svc;
    final cs = Theme.of(context).colorScheme;
    final tr = svc.cfg.tr;
    final items = svc.history;

    var sentN = 0, recvN = 0, sentB = 0, recvB = 0;
    for (final h in items) {
      if (h.sent) {
        sentN++;
        sentB += h.size;
      } else {
        recvN++;
        recvB += h.size;
      }
    }
    final q = _searchQuery.trim().toLowerCase();
    final shown = items.where((h) {
      if (_filter == 1 && !h.sent) return false;
      if (_filter == 2 && h.sent) return false;
      if (q.isNotEmpty) {
        final matchName = h.name.toLowerCase().contains(q);
        final matchPeer = h.peer.toLowerCase().contains(q);
        if (!matchName && !matchPeer) return false;
      }
      return true;
    }).toList();

    Widget chip(int i, String label) {
      final sel = _filter == i;
      return _Hover(
        radius: 20,
        scale: 1.05,
        glow: false,
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          showCheckmark: false,
          onSelected: (_) => setState(() => _filter = i),
          backgroundColor: p.card,
          selectedColor: cs.primary.withAlpha(46),
          shape: StadiumBorder(side: BorderSide(color: sel ? cs.primary : p.border)),
          labelStyle: TextStyle(
            color: sel ? cs.primary : p.inkSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= kTwoColWidth;
      final ts = MediaQuery.textScalerOf(context).scale(14) / 14;
      final rowExtent = 92.0 + (ts > 1 ? (ts - 1) * 34 : 0.0);
      return _PageScroll(
        slivers: [
          SliverAppBar(
            floating: true,
            titleSpacing: wide ? 24 : 16,
            title: Text(tr('history'), style: TextStyle(fontWeight: FontWeight.w800, color: p.ink)),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  tooltip: tr('clearHistory'),
                  icon: const Icon(Icons.delete_sweep_rounded),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(color: p.borderStrong)),
                        title: Text(tr('clearHistory')),
                        content:
                            const Text('Files are not deleted, only the list is cleared.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(tr('cancel'))),
                          _GradButton(
                            label: tr('clear'),
                            compact: true,
                            onTap: () => Navigator.pop(ctx, true),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) svc.clearHistory();
                  },
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 4, wide ? 24 : 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatTile(
                          icon: Icons.arrow_upward_rounded,
                          color: cs.primary,
                          label: '${tr('filterSent')} · $sentN',
                          value: fmtSize(sentB),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatTile(
                          icon: Icons.arrow_downward_rounded,
                          color: p.success,
                          label: '${tr('filterReceived')} · $recvN',
                          value: fmtSize(recvB),
                        ),
                      ),
                      if (wide) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.swap_vert_rounded,
                            color: p.warning,
                            label: '${tr('filterAll')} · ${items.length}',
                            value: fmtSize(sentB + recvB),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: tr('historySearchHint'),
                            prefixIcon: const Icon(Icons.search_rounded, size: 20),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  ),
                            filled: true,
                            fillColor: p.card,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      chip(0, tr('filterAll')),
                      chip(1, tr('filterSent')),
                      chip(2, tr('filterReceived')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (shown.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history_toggle_off_rounded,
                        size: 56, color: p.inkMuted),
                    const SizedBox(height: 12),
                    Text(
                      q.isNotEmpty ? tr('noResults') : tr('noTransfers'),
                      style: TextStyle(color: p.inkSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(wide ? 24 : 16, 4, wide ? 24 : 16, 24),
              sliver: SliverGrid.builder(
                gridDelegate: wide
                    ? SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 460,
                        mainAxisExtent: rowExtent,
                        crossAxisSpacing: 12,
                      )
                    : SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 1,
                        mainAxisExtent: rowExtent,
                      ),
                itemCount: shown.length,
                itemBuilder: (context, i) {
                  final h = shown[i];
                  final isFailed = h.status == 'failed';
                  final isCancelled = h.status == 'cancelled';
                  final col = isFailed
                      ? p.danger
                      : isCancelled
                          ? p.warning
                          : (h.sent ? cs.primary : p.success);
                  final statusLabel = isFailed
                      ? tr('historyStatusFailed')
                      : isCancelled
                          ? tr('historyStatusCancelled')
                          : tr('historyStatusSuccess');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _Hover(
                      radius: 18,
                      scale: 1.012,
                      glow: false,
                      clickable: h.path != null,
                      child: Material(
                        color: p.card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(color: p.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(12, 4, 10, 4),
                          leading: SizedBox(
                            width: 46,
                            height: 46,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                EditorialFileIllustration(fileName: h.name, size: 42),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: p.cardElevated,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: col.withAlpha(140)),
                                    ),
                                    child: Icon(
                                      isFailed
                                          ? Icons.error_outline_rounded
                                          : (h.sent
                                              ? Icons.arrow_upward_rounded
                                              : Icons.arrow_downward_rounded),
                                      size: 11,
                                      color: col,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          title: Text(
                            h.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: p.ink, fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${h.sent ? tr('to') : tr('from')}: ${h.peer} • $statusLabel • ${fmtTime(h.time, svc.cfg.use24h)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.inkSecondary, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: p.surfaceRecessed,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: p.border),
                                ),
                                child: Text(
                                  fmtSize(h.size),
                                  style: TextStyle(
                                    fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                                    fontSize: 11.5,
                                    color: p.inkSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (h.path != null && h.path!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  tooltip: tr('historyShowInFolder'),
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    Icons.folder_open_rounded,
                                    size: 19,
                                    color: cs.primary,
                                  ),
                                  onPressed: () => _revealOrCheckFile(h),
                                ),
                              ],
                            ],
                          ),
                          onTap: h.path == null ? null : () => _revealOrCheckFile(h),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    });
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatTile(
      {required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    return _Hover(
      radius: 20,
      scale: 1.02,
      clickable: false,
      glow: false,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: _editorialCardDeco(context, r: 20, borderColor: p.borderStrong),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withAlpha(65)),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: p.inkSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Sharing settings

Future<String?> _askText(BuildContext context, Settings settings, String title, String initial,
    {String? hint, TextInputType? type, int? maxLength}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final p = EditorialTheme.of(ctx);
      return AlertDialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: p.borderStrong)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: p.ink)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: type,
          maxLength: maxLength,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(settings.tr('cancel'))),
          _GradButton(
            label: settings.tr('save'),
            compact: true,
            onTap: () => Navigator.pop(ctx, c.text.trim()),
          ),
        ],
      );
    },
  );
}

Widget _quickSettings(Settings settings) {
  final tr = settings.tr;
  final desktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  String sizeLabel(int n) {
    if (n == 0) return tr('unlimited');
    if (n >= 1024) return '${n ~/ 1024} GB';
    return '$n MB';
  }

  return _Section(
    title: tr('quickSettings'),
    icon: Icons.bolt_rounded,
    children: [
      SwitchListTile(
        secondary: const _Ic(Icons.bolt_rounded),
        title: Text(tr('autoAcceptTitle')),
        subtitle: Text(tr('autoAcceptSub')),
        value: settings.autoAccept,
        onChanged: (v) => settings.update(() => settings.autoAccept = v),
      ),
      SwitchListTile(
        secondary: const _Ic(Icons.verified_user_outlined),
        title: Text(tr('trustedOnly')),
        subtitle: Text(tr('trustedOnlyDesc')),
        value: settings.trustedOnly,
        onChanged: (v) => settings.update(() => settings.trustedOnly = v),
      ),
      ListTile(
        leading: const _Ic(Icons.data_usage_rounded),
        title: Text(tr('maxReceive')),
        subtitle: Text(tr('maxReceiveDesc')),
        trailing: PopupMenuButton<int>(
          initialValue: settings.maxReceiveMb,
          onSelected: (v) => settings.update(() => settings.maxReceiveMb = v),
          itemBuilder: (_) => [
            for (final n in [0, 50, 100, 500, 1024, 5120])
              PopupMenuItem(value: n, child: Text(sizeLabel(n))),
          ],
          child: _ValuePill(sizeLabel(settings.maxReceiveMb)),
        ),
      ),
      if (desktop)
        SwitchListTile(
          secondary: const _Ic(Icons.folder_open_rounded),
          title: Text(tr('openAfter')),
          subtitle: Text(tr('openAfterDesc')),
          value: settings.openAfterReceive,
          onChanged: (v) => settings.update(() => settings.openAfterReceive = v),
        ),
      SwitchListTile(
        secondary: const _Ic(Icons.podcasts_rounded),
        title: Text(tr('visibleToDevices')),
        subtitle: Text(tr('visibleToDevicesDesc')),
        value: settings.discoverable,
        onChanged: (v) => settings.update(() => settings.discoverable = v),
      ),
    ],
  );
}

List<Widget> _sharingSections(BuildContext context, Settings settings) {
  final tr = settings.tr;
  return [
    _Section(
      title: tr('linkSharingOptions'),
      icon: Icons.link_rounded,
      children: [
        SwitchListTile(
          secondary: const _Ic(Icons.looks_one_rounded),
          title: Text(tr('oneTimeDownload')),
          subtitle: Text(tr('oneTimeDownloadDesc')),
          value: settings.oneTimeDownload,
          onChanged: (v) => settings.update(() => settings.oneTimeDownload = v),
        ),
        ListTile(
          leading: const _Ic(Icons.download_done_rounded),
          title: Text(tr('maxDownloads')),
          subtitle: Text(tr('maxDownloadsDesc')),
          trailing: PopupMenuButton<int>(
            initialValue: settings.maxDownloads,
            onSelected: (v) => settings.update(() => settings.maxDownloads = v),
            itemBuilder: (_) => [
              for (final n in [0, 1, 3, 5, 10, 25, 50])
                PopupMenuItem(value: n, child: Text(n == 0 ? tr('unlimited') : '$n')),
            ],
            child: _ValuePill(
                settings.maxDownloads == 0 ? tr('unlimited') : '${settings.maxDownloads}'),
          ),
        ),
        ListTile(
          leading: const _Ic(Icons.filter_list_rounded),
          title: Text(tr('allowedExtensions')),
          subtitle: Text(settings.allowedExtensionFilter.isEmpty
              ? tr('allowedExtensionsDesc')
              : settings.allowedExtensionFilter),
          trailing: settings.allowedExtensionFilter.isEmpty
              ? const Icon(Icons.edit_outlined, size: 20)
              : IconButton(
                  tooltip: 'Clear filter',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => settings.update(() => settings.allowedExtensionFilter = ''),
                ),
          onTap: () async {
            final v = await _askText(context, settings, tr('allowedExtensions'),
                settings.allowedExtensionFilter,
                hint: 'png, jpg, pdf, zip');
            if (v != null) settings.update(() => settings.allowedExtensionFilter = v);
          },
        ),
        SwitchListTile(
          secondary: const _Ic(Icons.how_to_reg_outlined),
          title: Text(tr('askBeforeDownload')),
          subtitle: Text(tr('askBeforeDownloadDesc')),
          value: settings.askShare,
          onChanged: (v) => settings.update(() => settings.askShare = v),
        ),
      ],
    ),
    _Section(
      title: tr('security'),
      icon: Icons.shield_outlined,
      children: [
        ListTile(
          leading: const _Ic(Icons.pin_outlined),
          title: Text(tr('pin')),
          subtitle: Text(settings.sharePin.isEmpty
              ? (settings.language == AppLang.turkish
                  ? 'Kapalı (yeni paylaşımlar için)'
                  : 'Off (applies to new shares)')
              : (settings.language == AppLang.turkish
                  ? 'Etkin (yeni paylaşımlar için)'
                  : 'Enabled (applies to new shares)')),
          trailing: settings.sharePin.isEmpty
              ? const Icon(Icons.edit_outlined, size: 20)
              : IconButton(
                  tooltip: 'Remove PIN',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => settings.update(() => settings.sharePin = ''),
                ),
          onTap: () async {
            final v = await _askText(context, settings, tr('pin'), settings.sharePin,
                hint: 'Leave empty to disable', type: TextInputType.number);
            if (v != null) settings.update(() => settings.sharePin = v);
          },
        ),
        ListTile(
          leading: const _Ic(Icons.gpp_maybe_outlined),
          title: Text(tr('pinAttempts')),
          subtitle: Text(tr('pinAttemptsDesc')),
          trailing: PopupMenuButton<int>(
            initialValue: settings.pinAttempts,
            onSelected: (v) => settings.update(() => settings.pinAttempts = v),
            itemBuilder: (_) => [
              for (final n in [0, 3, 5, 10])
                PopupMenuItem(value: n, child: Text(n == 0 ? tr('off') : '$n')),
            ],
            child: _ValuePill(settings.pinAttempts == 0 ? tr('off') : '${settings.pinAttempts}'),
          ),
        ),
        ListTile(
          leading: const _Ic(Icons.timer_off_outlined),
          title: Text(tr('autoStopSharing')),
          subtitle: Text(settings.shareMinutes == 0
              ? (settings.language == AppLang.turkish
                  ? 'Asla (yeni paylaşımlar için)'
                  : 'Never (applies to new shares)')
              : (settings.language == AppLang.turkish
                  ? '${settings.shareMinutes} dk sonra (yeni paylaşımlar için)'
                  : 'After ${settings.shareMinutes} min (applies to new shares)')),
          trailing: PopupMenuButton<int>(
            initialValue: settings.shareMinutes,
            onSelected: (v) => settings.update(() => settings.shareMinutes = v),
            itemBuilder: (_) => [
              for (final m in [0, 5, 15, 30, 60, 180])
                PopupMenuItem(
                  value: m,
                  child: Text(m == 0
                      ? (settings.language == AppLang.turkish ? 'Asla' : 'Never')
                      : (settings.language == AppLang.turkish ? '$m dk' : '$m min')),
                ),
            ],
            child: _ValuePill(settings.shareMinutes == 0
                ? (settings.language == AppLang.turkish ? 'Asla' : 'Never')
                : (settings.language == AppLang.turkish
                    ? '${settings.shareMinutes} dk'
                    : '${settings.shareMinutes} min')),
          ),
        ),
      ],
    ),
    _Section(
      title: tr('sharePage'),
      icon: Icons.web_rounded,
      children: [
        ListTile(
          leading: const _Ic(Icons.chat_bubble_outline_rounded),
          title: Text(tr('shareMessage')),
          subtitle: Text(
            settings.shareMessage.isEmpty ? tr('shareMessageDesc') : settings.shareMessage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: settings.shareMessage.isEmpty
              ? const Icon(Icons.edit_outlined, size: 20)
              : IconButton(
                  tooltip: 'Clear message',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => settings.update(() => settings.shareMessage = ''),
                ),
          onTap: () async {
            final v = await _askText(
                context, settings, tr('shareMessage'), settings.shareMessage,
                hint: tr('shareMessageHint'), maxLength: 140);
            if (v != null) settings.update(() => settings.shareMessage = v);
          },
        ),
        SwitchListTile(
          secondary: const _Ic(Icons.qr_code_2_rounded),
          title: Text(tr('showQrTitle')),
          subtitle: Text(tr('showQrDesc')),
          value: settings.showQr,
          onChanged: (v) => settings.update(() => settings.showQr = v),
        ),
        SwitchListTile(
          secondary: const _Ic(Icons.content_copy_rounded),
          title: Text(tr('autoCopy')),
          subtitle: Text(tr('autoCopyDesc')),
          value: settings.autoCopyLink,
          onChanged: (v) => settings.update(() => settings.autoCopyLink = v),
        ),
      ],
    ),
  ];
}

class SharingSettingsPage extends StatelessWidget {
  final Settings settings;
  const SharingSettingsPage({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(settings.tr('sharingSettings'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AdaptiveColumns(maxColumns: 3, children: _sharingSections(context, settings)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ Settings page

class SettingsPage extends StatefulWidget {
  final Settings settings;
  final DropService svc;
  const SettingsPage({
    super.key,
    required this.settings,
    required this.svc,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Settings get s => widget.settings;
  String _defaultDir = '';
  String? _pubIp;
  bool _fetchingIp = false;
  int _cat = 0;
  String _q = '';
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.svc.defaultSaveDir().then((d) {
      if (mounted) setState(() => _defaultDir = d.path);
    });
  }

  Future<void> _openSaveFolder() async {
    try {
      final d = s.saveDir.trim().isNotEmpty
          ? Directory(s.saveDir.trim())
          : await widget.svc.defaultSaveDir();
      await d.create(recursive: true);
      if (Platform.isWindows) {
        await Process.run('explorer', [d.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [d.path]);
      } else {
        await Process.run('xdg-open', [d.path]);
      }
    } catch (_) {}
  }

  Future<String?> _ask(String title, String initial, {String? hint, TextInputType? type}) {
    return _askText(context, s, title, initial, hint: hint, type: type);
  }

  Future<void> _editName() async {
    final v = await _ask(s.tr('deviceName'), s.deviceName);
    if (v != null && v.isNotEmpty) s.update(() => s.deviceName = v);
  }

  Future<void> _openGithub([String url = 'https://github.com/unqale']) async {
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      Clipboard.setData(ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the browser, link copied')),
      );
    }
  }

  Future<void> _confirmReset() async {
    final p = EditorialTheme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: p.borderStrong)),
        title: Text(s.tr('resetConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(s.tr('cancel'))),
          _GradButton(
            label: s.tr('reset'),
            compact: true,
            onTap: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (ok == true) s.reset();
  }

  String _textsOf(Widget? w) {
    if (w == null) return '';
    if (w is Text) return w.data ?? '';
    if (w is SwitchListTile) return '${_textsOf(w.title)} ${_textsOf(w.subtitle)}';
    if (w is ListTile) return '${_textsOf(w.title)} ${_textsOf(w.subtitle)}';
    if (w is Padding) return _textsOf(w.child);
    if (w is Column) return w.children.map(_textsOf).join(' ');
    if (w is Row) return w.children.map(_textsOf).join(' ');
    return '';
  }

  Widget _catTile(int i, _Section sec, bool selected) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? cs.primary.withAlpha(28) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? cs.primary.withAlpha(75) : Colors.transparent),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() {
            _cat = i;
            _q = '';
            _search.clear();
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(sec.icon ?? Icons.settings_outlined,
                    size: 19, color: selected ? cs.primary : p.inkMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sec.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? p.ink : p.inkSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _twoPane(List<_Section> secs) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    final q = _q.trim().toLowerCase();
    final subs = [
      s.tr('subLanguage'),
      s.tr('subAppearance'),
      s.tr('subReceive'),
      s.tr('subLink'),
      s.tr('subNetwork'),
      s.tr('subRemote'),
      s.tr('subHistory'),
      s.tr('subAbout'),
    ];
    if (_cat >= secs.length) _cat = 0;

    final right = <Widget>[];
    if (q.isEmpty) {
      final sec = secs[_cat];
      right.addAll([
        Text(
          sec.title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(_cat < subs.length ? subs[_cat] : '',
            style: TextStyle(fontSize: 13.5, color: p.inkSecondary)),
        const SizedBox(height: 20),
        _Section(title: sec.title, icon: sec.icon, header: false, children: sec.children),
      ]);
    } else {
      for (final sec in secs) {
        final hit = sec.title.toLowerCase().contains(q);
        final rows = hit
            ? sec.children
            : [
                for (final c in sec.children)
                  if (_textsOf(c).toLowerCase().contains(q)) c
              ];
        if (rows.isEmpty) continue;
        right.add(_Section(title: sec.title, icon: sec.icon, children: rows));
      }
      if (right.isEmpty) {
        right.add(Padding(
          padding: const EdgeInsets.only(top: 48),
          child: Center(
            child: Text(s.tr('noResults'),
                style: TextStyle(fontSize: 15, color: p.inkSecondary)),
          ),
        ));
      }
    }

    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c),
        );

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: s.tr('searchSettings'),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: p.card,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: border(p.border),
            enabledBorder: border(p.border),
            focusedBorder: border(cs.primary),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < secs.length; i++) _catTile(i, secs[i], q.isEmpty && i == _cat),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _confirmReset,
          icon: const Icon(Icons.restart_alt_rounded, size: 18),
          label: Text(s.tr('resetPrefs')),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(46),
            foregroundColor: p.inkSecondary,
            side: BorderSide(color: p.borderStrong),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 268, child: left),
        const SizedBox(width: 28),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: right),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => _PageScroll(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(s.tr('settings'),
                style: TextStyle(fontWeight: FontWeight.w800, color: p.ink)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(builder: (context, box) {
                final profile = Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: cs.primary.withAlpha(85)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [p.cardTinted, p.card],
                    ),
                    boxShadow: p.cardShadow,
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: EditorialMotifPainter(
                                variant: EditorialMotifVariant.archBridge,
                                primary: p.accent,
                                secondary: p.secondaryAccent,
                                warm: p.warmHighlight,
                                opacity: 0.16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const _BridgeLogoBadge(size: 56),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.deviceName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18.5,
                                      fontWeight: FontWeight.w800,
                                      color: p.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    widget.svc.myIps.isEmpty || !s.showIps
                                        ? kAppName
                                        : widget.svc.myIps.join(' • '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                                      fontSize: 12,
                                      color: p.inkSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _Pill(
                                    icon: Icons.verified_rounded,
                                    text: 'v$kVersion',
                                    color: cs.primary,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: s.tr('deviceName'),
                              onPressed: _editName,
                              icon: const Icon(Icons.edit_outlined),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
                final secs = <_Section>[
                  _Section(title: s.tr('language'), icon: Icons.translate_rounded, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final language in AppLang.values)
                            ChoiceChip(
                              label: Text(language.label),
                              selected: s.language == language,
                              onSelected: (_) => s.update(() => s.language = language),
                            ),
                        ],
                      ),
                    ),
                  ]),
                  _Section(title: s.tr('appearance'), icon: Icons.palette_outlined, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            avatar: const Icon(Icons.dark_mode_rounded, size: 16),
                            label: Text(s.language == AppLang.turkish
                                ? 'Atelier Koyu'
                                : 'Atelier Dark'),
                            selected: s.themeMode == ThemeMode.dark && !s.amoled,
                            onSelected: (_) => s.update(() {
                              s.themeMode = ThemeMode.dark;
                              s.amoled = false;
                            }),
                          ),
                          ChoiceChip(
                            avatar: const Icon(Icons.light_mode_rounded, size: 16),
                            label: Text(s.language == AppLang.turkish
                                ? 'Sıcak Kağıt (Açık)'
                                : 'Warm Paper (Light)'),
                            selected: s.themeMode == ThemeMode.light,
                            onSelected: (_) => s.update(() {
                              s.themeMode = ThemeMode.light;
                              s.amoled = false;
                            }),
                          ),
                          ChoiceChip(
                            avatar: const Icon(Icons.contrast_rounded, size: 16),
                            label: const Text('AMOLED'),
                            selected: s.themeMode == ThemeMode.dark && s.amoled,
                            onSelected: (_) => s.update(() {
                              s.themeMode = ThemeMode.dark;
                              s.amoled = true;
                            }),
                          ),
                          ChoiceChip(
                            avatar: const Icon(Icons.brightness_auto_rounded, size: 16),
                            label: Text(s.language == AppLang.turkish ? 'Sistem' : 'System'),
                            selected: s.themeMode == ThemeMode.system,
                            onSelected: (_) => s.update(() {
                              s.themeMode = ThemeMode.system;
                            }),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (var i = 0; i < kAccents.length; i++)
                            GestureDetector(
                              onTap: () => s.update(() => s.accent = i),
                              child: _Hover(
                                radius: 19,
                                scale: 1.14,
                                glow: false,
                                spotlight: false,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: kAccents[i],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: s.accent == i ? p.ink : Colors.transparent,
                                      width: 3,
                                    ),
                                    boxShadow: s.accent == i
                                        ? [
                                            BoxShadow(
                                                color: kAccents[i].withAlpha(140),
                                                blurRadius: 12)
                                          ]
                                        : null,
                                  ),
                                  child: s.accent == i
                                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.radar_rounded),
                      title: Text(s.tr('radarTitle')),
                      subtitle: Text(s.tr('radarSub')),
                      value: s.showRadar,
                      onChanged: (v) => s.update(() => s.showRadar = v),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.view_compact_rounded),
                      title: Text(s.tr('compactTitle')),
                      subtitle: Text(s.tr('compactSub')),
                      value: s.compactHeader,
                      onChanged: (v) => s.update(() => s.compactHeader = v),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.visibility_off_outlined),
                      title: Text(s.tr('ipTitle')),
                      subtitle: Text(s.tr('ipSub')),
                      value: s.showIps,
                      onChanged: (v) => s.update(() => s.showIps = v),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.vibration_rounded),
                      title: Text(s.tr('hapticTitle')),
                      subtitle: Text(s.tr('hapticSub')),
                      value: s.haptics,
                      onChanged: (v) => s.update(() => s.haptics = v),
                    ),
                    ListTile(
                      leading: const _Ic(Icons.slow_motion_video_rounded),
                      title: Text(s.tr('bootAnim')),
                      subtitle: Text(s.tr('bootAnimDesc')),
                      trailing: PopupMenuButton<int>(
                        initialValue: s.bootAnim,
                        onSelected: (v) => s.update(() => s.bootAnim = v),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 0, child: Text(s.tr('bootOff'))),
                          PopupMenuItem(value: 1, child: Text(s.tr('bootQuick'))),
                          PopupMenuItem(value: 2, child: Text(s.tr('bootFull'))),
                        ],
                        child: _ValuePill([
                          s.tr('bootOff'),
                          s.tr('bootQuick'),
                          s.tr('bootFull'),
                        ][s.bootAnim.clamp(0, 2)]),
                      ),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.call_to_action_outlined),
                      title: Text(s.tr('statusBar')),
                      subtitle: Text(s.tr('statusBarDesc')),
                      value: s.showStatusBar,
                      onChanged: (v) => s.update(() => s.showStatusBar = v),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.ads_click_rounded),
                      title: Text(s.tr('hoverFx')),
                      subtitle: Text(s.tr('hoverFxDesc')),
                      value: s.hoverFx,
                      onChanged: (v) => s.update(() => s.hoverFx = v),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.bar_chart_rounded),
                      title: Text(s.tr('railStats')),
                      subtitle: Text(s.tr('railStatsDesc')),
                      value: s.showRailStats,
                      onChanged: (v) => s.update(() => s.showRailStats = v),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.mouse_outlined),
                      title: Text(s.tr('mouseGlow')),
                      subtitle: Text(s.tr('mouseGlowDesc')),
                      value: s.mouseGlow,
                      onChanged: (v) => s.update(() => s.mouseGlow = v),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const _Ic(Icons.blur_on_rounded),
                            const SizedBox(width: 16),
                            Expanded(child: Text('${s.tr('glowLevel')}: ${s.glowLevel}%')),
                          ]),
                          Slider(
                            min: 0,
                            max: 200,
                            divisions: 20,
                            value: s.glowLevel.toDouble().clamp(0.0, 200.0).toDouble(),
                            label: '${s.glowLevel}%',
                            onChanged: (v) =>
                                s.update(() => s.glowLevel = (v / 10).round() * 10),
                          ),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.schedule_rounded),
                      title: Text(s.tr('use24h')),
                      subtitle: Text(s.tr('use24hDesc')),
                      value: s.use24h,
                      onChanged: (v) => s.update(() => s.use24h = v),
                    ),
                    ListTile(
                      leading: const _Ic(Icons.sort_rounded),
                      title: Text(s.tr('sortDevices')),
                      trailing: PopupMenuButton<int>(
                        initialValue: s.sortDevices,
                        onSelected: (v) => s.update(() => s.sortDevices = v),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 0, child: Text(s.tr('sortName'))),
                          PopupMenuItem(value: 1, child: Text(s.tr('sortIp'))),
                          PopupMenuItem(value: 2, child: Text(s.tr('sortFound'))),
                        ],
                        child: _ValuePill([
                          s.tr('sortName'),
                          s.tr('sortIp'),
                          s.tr('sortFound'),
                        ][s.sortDevices.clamp(0, 2)]),
                      ),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.volume_up_outlined),
                      title: Text(s.tr('soundDone')),
                      subtitle: Text(s.tr('soundDoneDesc')),
                      value: s.soundOnDone,
                      onChanged: (v) => s.update(() => s.soundOnDone = v),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const _Ic(Icons.format_size_rounded),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Text(
                                    '${s.tr('textSize')}: ${(s.textScale * 100).round()}%')),
                          ]),
                          Slider(
                            min: 0.8,
                            max: 1.4,
                            divisions: 12,
                            value: s.textScale.clamp(0.8, 1.4).toDouble(),
                            label: '${(s.textScale * 100).round()}%',
                            onChanged: (v) => s.update(
                                () => s.textScale = double.parse(v.toStringAsFixed(2))),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  _Section(title: s.tr('receive'), icon: Icons.download_rounded, children: [
                    SwitchListTile(
                      secondary: const _Ic(Icons.bolt_rounded),
                      title: Text(s.tr('autoAcceptTitle')),
                      subtitle: Text(s.tr('autoAcceptSub')),
                      value: s.autoAccept,
                      onChanged: (v) => s.update(() => s.autoAccept = v),
                    ),
                    ListTile(
                      leading: const _Ic(Icons.folder_outlined),
                      title: Text(s.tr('saveFolder')),
                      subtitle: Text(s.saveDir.isEmpty
                          ? (_defaultDir.isEmpty ? 'Default' : 'Default: $_defaultDir')
                          : s.saveDir),
                      trailing: s.saveDir.isEmpty
                          ? const Icon(Icons.edit_outlined, size: 20)
                          : IconButton(
                              tooltip: 'Reset to default',
                              icon: const Icon(Icons.restart_alt_rounded),
                              onPressed: () => s.update(() => s.saveDir = ''),
                            ),
                      onTap: () async {
                        final v = await _ask(s.tr('saveFolder'), s.saveDir,
                            hint: Platform.isAndroid
                                ? '/storage/emulated/0/Download/MyFiles'
                                : r'C:\Users\you\Downloads\MyFiles');
                        if (v != null) s.update(() => s.saveDir = v);
                      },
                    ),
                    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
                      ListTile(
                        leading: const _Ic(Icons.folder_open_rounded),
                        title: Text(s.tr('openFolder')),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                        onTap: _openSaveFolder,
                      ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.folder_copy_outlined),
                      title: Text(s.tr('groupBySender')),
                      subtitle: Text(s.tr('groupBySenderSub')),
                      value: s.groupBySender,
                      onChanged: (v) => s.update(() => s.groupBySender = v),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.file_copy_outlined),
                      title: Text(s.tr('overwrite')),
                      subtitle: Text(s.tr('overwriteSub')),
                      value: s.overwrite,
                      onChanged: (v) => s.update(() => s.overwrite = v),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.star_outline_rounded),
                      title: Text(s.tr('trustedAuto')),
                      subtitle: Text(s.tr('trustedAutoSub')),
                      value: s.autoAcceptTrusted,
                      onChanged: (v) => s.update(() => s.autoAcceptTrusted = v),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.send_outlined),
                      title: Text(s.tr('confirmSend')),
                      subtitle: Text(s.tr('confirmSendDesc')),
                      value: s.confirmSend,
                      onChanged: (v) => s.update(() => s.confirmSend = v),
                    ),
                    ListTile(
                      leading: const _Ic(Icons.verified_user_outlined),
                      title: Text(s.tr('trustedDevs')),
                      subtitle: Text(
                        s.trusted.isEmpty
                            ? 'None yet'
                            : s.trusted.map(Settings.formatTrustedEntry).join(', '),
                      ),
                      trailing: s.trusted.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear trusted devices',
                              icon: const Icon(Icons.clear_all_rounded),
                              onPressed: () => s.update(() => s.trusted.clear()),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const _Ic(Icons.timer_outlined),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Text('${s.tr('timeout')}: ${s.requestTimeout} s')),
                          ]),
                          Slider(
                            min: 15,
                            max: 120,
                            divisions: 21,
                            value: s.requestTimeout.toDouble().clamp(15.0, 120.0).toDouble(),
                            label: '${s.requestTimeout} s',
                            onChanged: (v) =>
                                s.update(() => s.requestTimeout = (v / 5).round() * 5),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  _Section(
                      title: s.tr('linkSharingOptions'),
                      icon: Icons.link_rounded,
                      children: [
                        ListTile(
                          leading: const _Ic(Icons.tune_rounded),
                          title: Text(s.tr('sharingSettings')),
                          subtitle: Text(s.tr('sharingSettingsDesc')),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SharingSettingsPage(settings: s),
                            ),
                          ),
                        ),
                      ]),
                  _Section(title: s.tr('network'), icon: Icons.wifi_rounded, children: [
                    SwitchListTile(
                      secondary: const _Ic(Icons.podcasts_rounded),
                      title: Text(s.tr('visibleToDevices')),
                      subtitle: Text(s.tr('visibleToDevicesDesc')),
                      value: s.discoverable,
                      onChanged: (v) => s.update(() => s.discoverable = v),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.wifi_tethering_rounded),
                      title: Text(s.tr('autoScan')),
                      subtitle: Text(s.tr('autoScanDesc')),
                      value: s.autoScan,
                      onChanged: (v) => s.update(() => s.autoScan = v),
                    ),
                    if (s.autoScan)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const _Ic(Icons.update_rounded),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Text('${s.tr('scanInterval')}: ${s.scanSeconds} s')),
                            ]),
                            Slider(
                              min: 3,
                              max: 60,
                              divisions: 57,
                              value: s.scanSeconds.toDouble().clamp(3.0, 60.0).toDouble(),
                              label: '${s.scanSeconds} s',
                              onChanged: (v) => s.update(() => s.scanSeconds = v.round()),
                            ),
                          ],
                        ),
                      ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.power_settings_new_rounded),
                      title: Text(s.tr('startOnline')),
                      subtitle: Text(s.tr('startOnlineDesc')),
                      value: s.startOnline,
                      onChanged: (v) => s.update(() => s.startOnline = v),
                    ),
                    ListTile(
                      leading: const _Ic(Icons.speed_rounded),
                      title: Text(s.tr('scanSpeed')),
                      subtitle: Text(s.tr('scanSpeedDesc')),
                      trailing: PopupMenuButton<int>(
                        initialValue: s.scanSpeed,
                        onSelected: (v) => s.update(() => s.scanSpeed = v),
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 0, child: Text(s.tr('scanBalanced'))),
                          PopupMenuItem(value: 1, child: Text(s.tr('scanFast'))),
                          PopupMenuItem(value: 2, child: Text(s.tr('scanTurbo'))),
                        ],
                        child: _ValuePill([
                          s.tr('scanBalanced'),
                          s.tr('scanFast'),
                          s.tr('scanTurbo'),
                        ][s.scanSpeed.clamp(0, 2)]),
                      ),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.vpn_lock_rounded),
                      title: Text(s.tr('scanVirtual')),
                      subtitle: Text(s.tr('scanVirtualDesc')),
                      value: s.scanVirtual,
                      onChanged: (v) => s.update(() => s.scanVirtual = v),
                    ),
                    ListTile(
                      leading: const _Ic(Icons.lan_outlined),
                      title: Text(s.tr('port')),
                      subtitle: Text('${s.port} (must match on both devices)'),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
                      onTap: () async {
                        final v =
                            await _ask(s.tr('port'), '${s.port}', type: TextInputType.number);
                        final n = int.tryParse(v ?? '');
                        if (n != null && n >= 1024 && n <= 65535) {
                          s.update(() => s.port = n);
                        } else if (v != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Port must be between 1024 and 65535')),
                          );
                        }
                      },
                    ),
                  ]),
                  _Section(
                      title: s.tr('remoteTitle'),
                      icon: Icons.public_rounded,
                      children: [
                        SwitchListTile(
                          secondary: const _Ic(Icons.public_rounded),
                          title: Text(s.tr('remoteAllow')),
                          subtitle: Text(s.tr('remoteAllowDesc')),
                          value: s.remoteEnabled,
                          onChanged: (v) => s.update(() => s.remoteEnabled = v),
                        ),
                        ListTile(
                          leading: const _Ic(Icons.vpn_key_outlined),
                          title: Text(s.tr('remoteKey')),
                          subtitle: SelectableText(
                            s.remoteKey,
                            style: TextStyle(
                              fontFamily: 'Consolas', fontFamilyFallback: const ['Inter', 'Roboto', 'monospace'],
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: p.inkSecondary,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: s.tr('copyLink'),
                                icon: const Icon(Icons.copy_rounded, size: 19),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: s.remoteKey));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(s.tr('copied'))),
                                  );
                                },
                              ),
                              IconButton(
                                tooltip: s.tr('remoteNewKey'),
                                icon: const Icon(Icons.refresh_rounded, size: 20),
                                onPressed: () =>
                                    s.update(() => s.remoteKey = Settings.newKey()),
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          leading: const _Ic(Icons.travel_explore_rounded),
                          title: Text(s.tr('remoteAddress')),
                          subtitle: Text(
                            _pubIp == null ? s.tr('remoteAddressDesc') : '$_pubIp:${s.port}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_pubIp != null)
                                IconButton(
                                  tooltip: s.tr('copyLink'),
                                  icon: const Icon(Icons.copy_rounded, size: 19),
                                  onPressed: () {
                                    Clipboard.setData(
                                        ClipboardData(text: '$_pubIp:${s.port}'));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(s.tr('copied'))),
                                    );
                                  },
                                ),
                              IconButton(
                                tooltip: s.tr('remoteAddress'),
                                icon: _fetchingIp
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.search_rounded),
                                onPressed: _fetchingIp
                                    ? null
                                    : () async {
                                        setState(() => _fetchingIp = true);
                                        final ip = await widget.svc.fetchPublicIp();
                                        if (!mounted) return;
                                        setState(() {
                                          _fetchingIp = false;
                                          _pubIp = ip;
                                        });
                                      },
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          leading: const _Ic(Icons.add_link_rounded),
                          title: Text(s.tr('remoteConnect')),
                          subtitle: Text(s.tr('remoteConnectDesc')),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => showRemoteDialog(context, widget.svc),
                        ),
                        for (final r in s.remotes)
                          ListTile(
                            leading: const _Ic(Icons.dns_rounded),
                            title: Text('${r['alias'] ?? r['host']}'),
                            subtitle: Text('${r['host']}:${r['port']}'),
                            trailing: IconButton(
                              icon: Icon(Icons.delete_outline_rounded,
                                  color: p.danger),
                              onPressed: () => widget.svc.removeRemote(
                                '${r['host']}',
                                (r['port'] as int?) ?? s.port,
                              ),
                            ),
                          ),
                        ListTile(
                          leading: const _Ic(Icons.warning_amber_rounded),
                          title: Text(s.tr('remoteWarnTitle')),
                          subtitle: Text(s.tr('remoteWarn')),
                        ),
                      ]),
                  _Section(title: s.tr('history'), icon: Icons.history_rounded, children: [
                    SwitchListTile(
                      secondary: const _Ic(Icons.history_rounded),
                      title: Text(s.tr('saveHistory')),
                      value: s.keepHistory,
                      onChanged: (v) => s.update(() => s.keepHistory = v),
                    ),
                    ListTile(
                      leading: const _Ic(Icons.format_list_numbered_rounded),
                      title: Text(s.tr('historySize')),
                      subtitle: Text('Keep the last ${s.historyLimit} transfers'),
                      trailing: PopupMenuButton<int>(
                        initialValue: s.historyLimit,
                        onSelected: (v) => s.update(() => s.historyLimit = v),
                        itemBuilder: (_) => [
                          for (final n in [50, 100, 200, 500])
                            PopupMenuItem(value: n, child: Text('$n')),
                        ],
                        child: _ValuePill('${s.historyLimit}'),
                      ),
                    ),
                    SwitchListTile(
                      secondary: const _Ic(Icons.help_outline_rounded),
                      title: Text(s.tr('confirmClear')),
                      subtitle: Text(s.tr('confirmClearDesc')),
                      value: s.confirmClear,
                      onChanged: (v) => s.update(() => s.confirmClear = v),
                    ),
                    ListTile(
                      leading: const _Ic(Icons.delete_outline_rounded),
                      title: Text(s.tr('clearHistory')),
                      onTap: () async {
                        if (s.confirmClear) {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: p.card,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(color: p.borderStrong)),
                              title: Text('${s.tr('clearHistory')}?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text(s.tr('cancel'))),
                                _GradButton(
                                  label: s.tr('clearHistory'),
                                  compact: true,
                                  onTap: () => Navigator.pop(ctx, true),
                                ),
                              ],
                            ),
                          );
                          if (ok != true) return;
                        }
                        widget.svc.clearHistory();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('History cleared')));
                      },
                    ),
                  ]),
                  _Section(
                      title: s.tr('about'),
                      icon: Icons.info_outline_rounded,
                      children: [
                        ListTile(
                          leading: const _BridgeLogoBadge(size: 40, glow: true),
                          title: const Text(kAppName,
                              style: TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: const Text('Version $kVersion'),
                        ),
                        ListTile(
                          leading: const _Ic(Icons.code_rounded),
                          title: const Text('Made by unqale',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('https://github.com/unqale'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: p.accent.withAlpha(28),
                                  borderRadius: BorderRadius.circular(999),
                                  border:
                                      Border.all(color: p.accent.withAlpha(80)),
                                ),
                                child: Text(
                                  '@unqale',
                                  style: TextStyle(
                                    fontFamily: 'Consolas',
                                    fontFamilyFallback: const [
                                      'Inter',
                                      'Roboto',
                                      'monospace'
                                    ],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: p.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.open_in_new_rounded, size: 18),
                            ],
                          ),
                          onTap: () => _openGithub('https://github.com/unqale'),
                        ),
                        ListTile(
                          leading: const _Ic(Icons.auto_awesome_rounded),
                          title: const Text('Contributor: eratis-hq',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: const Text('https://github.com/eratis-hq'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                decoration: BoxDecoration(
                                  color: p.warmHighlight.withAlpha(28),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: p.warmHighlight.withAlpha(80)),
                                ),
                                child: Text(
                                  '@eratis-hq',
                                  style: TextStyle(
                                    fontFamily: 'Consolas',
                                    fontFamilyFallback: const [
                                      'Inter',
                                      'Roboto',
                                      'monospace'
                                    ],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: p.warmHighlight,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.open_in_new_rounded, size: 18),
                            ],
                          ),
                          onTap: () =>
                              _openGithub('https://github.com/eratis-hq'),
                        ),
                        ListTile(
                          leading: const _Ic(Icons.new_releases_outlined),
                          title: Text(s.tr('whatsNew')),
                          subtitle: Text(
                              '${s.tr('update')} $kVersion — ${kChangelog.first.title(s.language)}'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () => showChangelog(context, s),
                        ),
                        ListTile(
                          leading: const _Ic(Icons.restore_rounded),
                          title: Text(s.tr('resetSettings')),
                          onTap: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: p.card,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    side: BorderSide(color: p.borderStrong)),
                                title: Text(s.tr('resetConfirm')),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: Text(s.tr('cancel'))),
                                  _GradButton(
                                    label: s.tr('reset'),
                                    compact: true,
                                    onTap: () => Navigator.pop(ctx, true),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) s.reset();
                          },
                        ),
                      ]),
                ];
                if (box.maxWidth >= 820) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [profile, _twoPane(secs)],
                  );
                }
                return _AdaptiveColumns(fullWidthFirst: true, children: [profile, ...secs]);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;
  final bool header;
  const _Section(
      {required this.title, required this.children, this.icon, this.header = true});

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(Divider(height: 1, thickness: 1, color: p.border));
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: cs.primary.withAlpha(24),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: cs.primary.withAlpha(55)),
                      ),
                      child: Icon(icon, size: 15, color: cs.primary),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      title.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: cs.primary,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          _Hover(
            radius: 22,
            scale: 1.0,
            glow: false,
            clickable: false,
            child: Material(
              color: header ? p.card : p.card.withAlpha(220),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: BorderSide(color: p.borderStrong),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(children: rows),
            ),
          ),
        ],
      ),
    );
  }
}

void showChangelog(BuildContext context, Settings s) {
  showDialog<void>(
    context: context,
    builder: (ctx) {
      final p = EditorialTheme.of(ctx);
      final cs = Theme.of(ctx).colorScheme;
      return Dialog(
        backgroundColor: p.card,
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: p.borderStrong),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 12, 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary.withAlpha(42), Colors.transparent],
                  ),
                  border: Border(bottom: BorderSide(color: p.border)),
                ),
                child: Row(
                  children: [
                    const _BridgeLogoBadge(size: 46),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.tr('whatsNew'),
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: p.ink)),
                          const SizedBox(height: 2),
                          Text('$kAppName v$kVersion',
                              style: TextStyle(fontSize: 12.5, color: p.inkSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  children: [
                    for (var i = 0; i < kChangelog.length; i++)
                      _ChangelogEntry(item: kChangelog[i], s: s, latest: i == 0),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ChangelogEntry extends StatelessWidget {
  final ChangelogItem item;
  final Settings s;
  final bool latest;
  const _ChangelogEntry({required this.item, required this.s, required this.latest});

  Widget _chip(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 12)),
      );

  @override
  Widget build(BuildContext context) {
    final p = EditorialTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: latest ? cs.primary.withAlpha(16) : p.surfaceRecessed,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: latest ? cs.primary.withAlpha(120) : p.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: latest,
            shape: shape,
            collapsedShape: shape,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _chip('${s.tr('update')} ${item.version}',
                    latest ? cs.primary : p.cardElevated,
                    latest ? cs.onPrimary : p.inkSecondary),
                if (latest) _chip(s.tr('current'), cs.primary.withAlpha(34), cs.primary),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(item.title(s.language),
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: p.ink, height: 1.3)),
            ),
            children: [
              for (final line in item.lines(s.language))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration:
                              BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(line,
                            style: TextStyle(color: p.inkSecondary, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(switch (s.language) {
                    AppLang.english => 'Copy notes',
                    AppLang.turkish => 'Notları kopyala',
                    AppLang.russian => 'Копировать заметки',
                    AppLang.german => 'Hinweise kopieren',
                    AppLang.spanish => 'Copiar notas',
                    AppLang.french => 'Copier les notes',
                  }),
                  onPressed: () async {
                    final notes = [
                      '$kAppName v${item.version}',
                      item.title(s.language),
                      for (final line in item.lines(s.language)) '• $line',
                    ].join('\n');
                    await Clipboard.setData(ClipboardData(text: notes));
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
