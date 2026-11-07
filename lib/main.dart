import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

const int kDefaultPort = 53317;
const String kAppId = 'localbridge';
const String kAppName = 'LocalBridge';
const String kVersion = '2.1.0';

/// Brand colors used by the bridge logo and the startup animation.
const Color kBrand1 = Color(0xFFC4B5FD);
const Color kBrand2 = Color(0xFF7C3AED);

/// Phone / small-window layout: one column that never gets wider than this.
const double kMaxContentWidth = 600;

/// From this window width on, the bottom bar is replaced by a side menu.
const double kWideBreakpoint = 900;

/// Widest the content area gets on huge monitors.
const double kMaxWideWidth = 1240;

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
    '2.1.0',
    {
      AppLang.english: 'Last Update: Faster Scanning, Smarter Glow, Fuller Side Menu',
      AppLang.turkish: 'Son Güncelleme: Daha Hızlı Tarama, Daha Akıllı Işık, Daha Dolu Yan Menü',
      AppLang.russian: 'Последнее обновление: быстрее сканирование, умнее подсветка, полнее боковое меню',
    },
    {
      AppLang.english: [
        "This is the last big update. From now on LocalBridge will only get fixes and improvements. Support for more platforms such as macOS, Linux and iOS may come later",
        "Faster startup: the app, the server and your history now load at the same time, and the logo animation is shorter by default (new Startup animation setting: Off, Quick or Full)",
        "Much faster device scanning: devices appear the moment they answer, devices seen before are checked first, and the scan no longer waits for the slowest address",
        "New Scan speed setting (Balanced, Fast, Turbo): faster scans find devices sooner but use more network and battery",
        "Smarter scanning: VPN, virtual machine and Docker networks are skipped (new Scan VPN and virtual networks setting), auto scan only re-checks known devices between full sweeps, and devices no longer flicker when one scan misses them",
        "Share links now list only your real network addresses",
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
        "Bu son büyük güncelleme. Bundan sonra LocalBridge'e yalnızca düzeltmeler ve iyileştirmeler gelecek. macOS, Linux ve iOS gibi daha fazla platform desteği ileride gelebilir",
        "Daha hızlı açılış: uygulama, sunucu ve geçmişin artık aynı anda yükleniyor, logo animasyonu varsayılan olarak daha kısa (yeni Açılış animasyonu ayarı: Kapalı, Kısa veya Uzun)",
        "Çok daha hızlı cihaz taraması: cihazlar cevap verdiği anda görünüyor, daha önce görülen cihazlar önce kontrol ediliyor ve tarama artık en yavaş adresi beklemiyor",
        "Yeni Tarama hızı ayarı (Dengeli, Hızlı, Turbo): daha hızlı tarama cihazları daha çabuk bulur ama daha fazla ağ ve pil kullanır",
        "Daha akıllı tarama: VPN, sanal makine ve Docker ağları atlanıyor (yeni VPN ve sanal ağları tara ayarı), otomatik tarama tam taramalar arasında yalnızca bilinen cihazları kontrol ediyor ve bir tarama cihazı kaçırınca cihazlar artık listeden titreyerek kaybolmuyor",
        "Paylaşım bağlantıları artık yalnızca gerçek ağ adreslerini listeliyor",
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
        "Это последнее большое обновление. Дальше LocalBridge будет получать только исправления и улучшения. Поддержка других платформ, таких как macOS, Linux и iOS, может появиться позже",
        "Быстрее запуск: приложение, сервер и история теперь загружаются одновременно, а анимация логотипа по умолчанию короче (новая настройка Анимация запуска: Выкл, Короткая или Полная)",
        "Намного быстрее поиск устройств: устройства появляются сразу после ответа, ранее найденные проверяются первыми, а сканирование больше не ждёт самый медленный адрес",
        "Новая настройка Скорость сканирования (Сбалансированная, Быстрая, Турбо): быстрое сканирование находит устройства раньше, но использует больше сети и батареи",
        "Умнее сканирование: сети VPN, виртуальных машин и Docker пропускаются (новая настройка Сканировать VPN и виртуальные сети), автоматическое сканирование между полными проходами проверяет только известные устройства, а устройства больше не мигают в списке, если один проход их пропустил",
        "Ссылки для раздачи теперь показывают только реальные сетевые адреса",
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
        'Everything changed on New UI',
        'Completely removed legacy brand references and leftover text from the UI',
        'Fixed various UI layout shifts and pixel alignment issues',
        'Resolved a rare background crash issue during network scanning',
        'Optimized memory usage during large file transfers',
        'Fixed a bug causing background services to drop the Wi-Fi connection',
        'Corrected missing and inaccurate translations in Turkish and Russian language files',
        'Optimized the instant loading delay on the QR code generation screen',
        'Fixed a UI freezing issue when clearing the file transfer history list',
        'Removed AMOLED dark theme support because for New UI',
        'Redesigned UI',
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
        'Her şey yeni arayüzle değişti',
        'Eski marka adı ve arayüzde kalan eski metinler tamamen kaldırıldı',
        'Çeşitli arayüz kaymaları ve piksel hizalama sorunları düzeltildi',
        'Ağ taraması sırasında nadiren görülen arka plan çökmesi giderildi',
        'Büyük dosya aktarımları sırasında bellek kullanımı iyileştirildi',
        'Arka plan hizmetlerinin Wi-Fi bağlantısını düşürmesine neden olan hata düzeltildi',
        'Türkçe ve Rusça dil dosyalarındaki eksik ve hatalı çeviriler düzeltildi',
        'QR kod oluşturma ekranındaki yükleme gecikmesi azaltıldı',
        'Dosya aktarım geçmişi temizlenirken oluşan arayüz donması düzeltildi',
        'Yeni arayüz nedeniyle AMOLED koyu tema desteği kaldırıldı',
        'Yenilenen arayüz',
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
        'Весь интерфейс изменён в новом дизайне',
        'Полностью удалены упоминания старого бренда и остатки старого текста в интерфейсе',
        'Исправлены сдвиги макета и проблемы с выравниванием пикселей',
        'Устранён редкий фоновый сбой при сканировании сети',
        'Оптимизировано использование памяти при передаче больших файлов',
        'Исправлена ошибка, из-за которой фоновые службы разрывали соединение Wi-Fi',
        'Исправлены отсутствующие и неточные переводы в турецком и русском языках',
        'Сокращена задержка загрузки на экране создания QR-кода',
        'Исправлено зависание интерфейса при очистке истории передач',
        'Поддержка тёмной темы AMOLED удалена из-за нового интерфейса',
        'Обновлённый интерфейс',
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
  final settings = Settings();
  await settings.load();
  runApp(LocalBridgeApp(settings: settings));
}

// ------------------------------------------------------------- i18n (Localization)

enum AppLang { english, turkish, russian }

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
      'radarTitle': 'Radar animation',
      'radarSub': 'Animate the header while scanning',
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
      'radarTitle': 'Radar animasyonu',
      'radarSub': 'Tarama sırasında başlığı hareketlendir',
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
      'radarTitle': 'Анимация радара',
      'radarSub': 'Анимировать заголовок при сканировании',
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
    },
  };

  static String get(AppLang lang, String key) {
    return keys[lang]?[key] ?? keys[AppLang.english]?[key] ?? key;
  }
}

// ------------------------------------------------------------- settings

const List<Color> kAccents = [
  Colors.indigo,
  Colors.teal,
  Colors.deepPurple,
  Colors.pink,
  Colors.orange,
  Colors.green,
  Colors.blue,
  Colors.red,
  Colors.cyan,
  Colors.brown,
  Colors.blueGrey,
];

class Settings extends ChangeNotifier {
  String deviceName = _defaultName();
  ThemeMode themeMode = ThemeMode.dark;
  int accent = 2;
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
  bool amoled = true;
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
  int bootAnim = 1; // 0 off, 1 quick, 2 full

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

  Future<File> _file() async {
    final d = await getApplicationSupportDirectory();
    await d.create(recursive: true);
    return File(p.join(d.path, 'settings.json'));
  }

  Future<void> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      deviceName = (j['deviceName'] as String?) ?? deviceName;
      themeMode = ThemeMode.values[(j['themeMode'] as int?) ?? ThemeMode.dark.index];
      accent = ((j['accent'] as int?) ?? 2).clamp(0, kAccents.length - 1);
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
      amoled = (j['amoled'] as bool?) ?? true;
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
      bootAnim = ((j['bootAnim'] as int?) ?? 1).clamp(0, 2);
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      await f.writeAsString(jsonEncode({
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
      }));
    } catch (_) {}
  }

  void update(void Function() change) {
    change();
    notifyListeners();
    _save();
  }

  void reset() {
    update(() {
      deviceName = _defaultName();
      themeMode = ThemeMode.dark;
      accent = 2;
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
      amoled = true;
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
      bootAnim = 1;
    });
  }

  void toggleTrusted(String name) {
    update(() {
      if (!trusted.remove(name)) trusted.add(name);
    });
  }

  String tr(String key) => L10n.get(language, key);
}

// --------------------------------------------------------------- models

class Device {
  final String alias;
  final String ip;
  final String platform;
  Device(this.alias, this.ip, this.platform);

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
  final Completer<bool> decision = Completer<bool>();

  IncomingRequest(this.from, this.files, {this.download = false});
}

class _Session {
  final List<String> names;
  final List<int> sizes;
  final String from;
  int done = 0;
  _Session(this.names, this.sizes, this.from);
}

class ShareSession {
  final String token;
  final List<PlatformFile> files;
  final List<int> sizes;
  final String? pin;
  final Set<String> unlocked = {};
  final Set<String> allowed = {};
  final Map<String, int> pinFails = {};
  int downloads = 0;
  ShareSession(this.token, this.files, this.sizes, this.pin);
}

class HistoryItem {
  final String name;
  final int size;
  final bool sent;
  final String peer;
  final DateTime time;
  final String? path;

  HistoryItem(this.name, this.size, this.sent, this.peer, this.time, this.path);

  Map<String, dynamic> toJson() => {
        'name': name,
        'size': size,
        'sent': sent,
        'peer': peer,
        'time': time.millisecondsSinceEpoch,
        'path': path,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        '${j['name']}',
        (j['size'] as num?)?.toInt() ?? 0,
        (j['sent'] as bool?) ?? false,
        '${j['peer']}',
        DateTime.fromMillisecondsSinceEpoch((j['time'] as num?)?.toInt() ?? 0),
        j['path'] as String?,
      );
}

enum StatusKind { info, success, error }

String fmtSize(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

String fmtTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}.${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _page(String inner) => '''<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>$kAppName</title><style>
body{font-family:system-ui,sans-serif;margin:0;padding:24px;background:#09090b;color:#f4f4f5}
.wrap{max-width:560px;margin:0 auto}
h1{font-size:22px}
.msg{opacity:.75;margin:0 0 14px;line-height:1.4}
.card{background:#18181b;border:1px solid #27272a;border-radius:16px;padding:14px 16px;margin:10px 0;display:flex;align-items:center;justify-content:space-between;gap:12px}
.name{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:300px}
.size{opacity:.6;font-size:13px}
a.btn,button{background:#7c3aed;color:#fff;border:0;border-radius:12px;padding:8px 16px;text-decoration:none;font-size:14px;cursor:pointer;font-weight:600}
input{padding:10px;border-radius:10px;border:1px solid #3f3f46;background:#121214;color:#fff;font-size:16px}
</style></head><body><div class="wrap">$inner</div></body></html>''';

// --------------------------------------------------------------- service

class DropService extends ChangeNotifier {
  final Settings cfg;
  DropService(this.cfg);

  final Map<String, Device> devices = {};
  final Set<String> myIps = {};
  final Map<String, _Session> _sessions = {};
  final List<HistoryItem> history = [];
  HttpServer? _server;
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
  bool _disposed = false;

  // scanning state
  DateTime? _lastSweep; // last time the whole network was swept
  final Map<String, int> _miss = {}; // ip -> consecutive scans without an answer
  Map<String, Device> _known = {}; // devices seen before (saved on disk)

  String get alias => cfg.deviceName;

  List<String> get shareUrls {
    final s = share;
    if (s == null) return [];
    return [for (final ip in myIps) 'http://$ip:${cfg.port}/s/${s.token}'];
  }

  void _notify() {
    if (!_disposed) notifyListeners();
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
  }

  Future<void> start() async {
    // Independent startup work runs side by side instead of one after another,
    // so the app is ready (and scanning) sooner.
    unawaited(_loadHistory().then((_) => _notify()));
    final bound = _bind();
    final ips = _localIps();
    final known = _loadKnown();
    await bound;
    myIps
      ..clear()
      ..addAll(await ips);
    await known;
    _notify();
    reschedule();
    await scan();
  }

  /// Turns LocalBridge fully on/off. Off = no scanning, the server is closed
  /// (other devices cannot see you or send to you) and any link share stops.
  Future<void> setOnline(bool v) async {
    if (online == v) return;
    online = v;
    if (cfg.haptics) HapticFeedback.selectionClick();
    if (!v) {
      _timer?.cancel();
      _timer = null;
      _shareTimer?.cancel();
      _shareTimer = null;
      share = null;
      final pr = pending;
      if (pr != null) resolve(pr, false);
      _sessions.clear();
      devices.clear();
      progress = null;
      status = '';
      kind = StatusKind.info;
      try {
        await _server?.close(force: true);
      } catch (_) {}
      _server = null;
      serverUp = false;
      _notify();
    } else {
      await _bind();
      myIps
        ..clear()
        ..addAll(await _localIps());
      _notify();
      await scan();
      reschedule();
    }
  }

  void reschedule() {
    _timer?.cancel();
    _timer = null;
    if (!cfg.autoScan || !online) return;
    _timer = Timer.periodic(Duration(seconds: cfg.scanSeconds), (_) => _autoScan());
  }

  Future<void> _bind() async {
    try {
      await _server?.close(force: true);
      _server = await HttpServer.bind(InternetAddress.anyIPv4, cfg.port);
      _server!.listen(_handle, onError: (_) {});
      serverUp = true;
    } catch (e) {
      serverUp = false;
      _setStatus('Could not start server (port ${cfg.port}): $e', StatusKind.error);
    }
    _notify();
  }

  Future<void> restartServer() async {
    if (!online) return;
    await _bind();
    devices.clear();
    await scan();
  }

  @override
  void dispose() {
    _disposed = true;
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
    final d = await getApplicationSupportDirectory();
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
    try {
      if (!devices.values.any((d) => _known[d.ip]?.alias != d.alias)) return;
      final merged = <String, Device>{..._known};
      for (final d in devices.values) {
        merged.remove(d.ip);
        merged[d.ip] = d;
      }
      while (merged.length > 24) {
        merged.remove(merged.keys.first);
      }
      _known = merged;
      final f = await _knownFile();
      await f.writeAsString(jsonEncode([
        for (final d in merged.values) {'alias': d.alias, 'ip': d.ip, 'platform': d.platform},
      ]));
    } catch (_) {}
  }

  Future<File> _historyFile() async {
    final d = await getApplicationSupportDirectory();
    await d.create(recursive: true);
    return File(p.join(d.path, 'history.json'));
  }

  Future<void> _loadHistory() async {
    try {
      final f = await _historyFile();
      if (!await f.exists()) return;
      final list = jsonDecode(await f.readAsString()) as List;
      history
        ..clear()
        ..addAll(list.map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e as Map))));
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final f = await _historyFile();
      await f.writeAsString(jsonEncode(history.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  void _addHistory(HistoryItem h) {
    if (!cfg.keepHistory) return;
    history.insert(0, h);
    final lim = cfg.historyLimit;
    if (history.length > lim) history.removeRange(lim, history.length);
    _saveHistory();
  }

  void clearHistory() {
    history.clear();
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

  Future<void> _handle(HttpRequest req) async {
    try {
      final path = req.uri.path;
      final segs = req.uri.pathSegments;
      if (req.method == 'GET' && segs.isNotEmpty && segs[0] == 's') {
        await _onShare(req, segs);
      } else if (req.method == 'GET' && path == '/api/info') {
        if (!cfg.discoverable) {
          await _json(req, 403, {'error': 'hidden'});
          return;
        }
        await _json(req, 200, {
          'app': kAppId,
          'alias': alias,
          'platform': Platform.operatingSystem,
        });
      } else if (req.method == 'POST' && path == '/api/send-request') {
        await _onSendRequest(req);
      } else if (req.method == 'PUT' && path == '/api/upload') {
        await _onUpload(req);
      } else {
        await _json(req, 404, {'error': 'not found'});
      }
    } catch (e) {
      try {
        await _json(req, 500, {'error': '$e'});
      } catch (_) {}
    }
  }

  String _safeName(String name) {
    var n = p.basename(name).replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1f]'), '_');
    if (n.trim().isEmpty) n = 'file';
    return n;
  }

  Future<bool> _awaitDecision(IncomingRequest r) async {
    pending = r;
    _notify();
    final ok = await r.decision.future
        .timeout(Duration(seconds: cfg.requestTimeout), onTimeout: () => false);
    pending = null;
    _notify();
    return ok;
  }

  Future<void> _onSendRequest(HttpRequest req) async {
    final text = await utf8.decoder.bind(req).join();
    final body = jsonDecode(text) as Map<String, dynamic>;
    final rawFiles = (body['files'] as List?) ?? [];
    final fileItems = rawFiles
        .map((e) => RequestFileItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    if (fileItems.isEmpty) {
      await _json(req, 400, {'error': 'no files'});
      return;
    }
    if (pending != null) {
      await _json(req, 409, {'error': 'busy'});
      return;
    }
    final from = '${body['alias'] ?? req.connectionInfo?.remoteAddress.address}';

    // 2.1.0: only trusted devices may send, and optionally nothing too big.
    if (cfg.trustedOnly && !cfg.trusted.contains(from)) {
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

    final fromTrusted = cfg.autoAcceptTrusted && cfg.trusted.contains(from);
    final ok = (cfg.autoAccept || fromTrusted)
        ? true
        : await _awaitDecision(IncomingRequest(from, fileItems));
    if (!ok) {
      await _json(req, 403, {'accepted': false});
      return;
    }
    final rnd = Random.secure();
    final sid = List.generate(16, (_) => rnd.nextInt(16).toRadixString(16)).join();
    _sessions[sid] = _Session(
      fileItems.map((f) => _safeName(f.name)).toList(),
      fileItems.map((f) => f.size).toList(),
      from,
    );
    await _json(req, 200, {'accepted': true, 'sessionId': sid});
  }

  void resolve(IncomingRequest r, bool ok) {
    if (!r.decision.isCompleted) r.decision.complete(ok);
  }

  Future<Directory> defaultSaveDir() async {
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

  Future<File> _uniqueFile(Directory dir, String name) async {
    var f = File(p.join(dir.path, name));
    if (cfg.overwrite) return f;
    final base = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var i = 1;
    while (await f.exists()) {
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

  Future<void> _onUpload(HttpRequest req) async {
    final sid = req.uri.queryParameters['sessionId'];
    final idx = int.tryParse(req.uri.queryParameters['index'] ?? '');
    final s = sid == null ? null : _sessions[sid];
    if (s == null || idx == null || idx < 0 || idx >= s.names.length) {
      await _json(req, 403, {'error': 'invalid session'});
      return;
    }
    var dir = await _saveDir();
    if (cfg.groupBySender) {
      dir = Directory(p.join(dir.path, _safeName(s.from)));
      await dir.create(recursive: true);
    }
    final target = await _uniqueFile(dir, s.names[idx]);
    final sink = target.openWrite();
    final total = s.sizes[idx];
    var got = 0;
    final sw = Stopwatch()..start();
    try {
      await for (final chunk in req) {
        sink.add(chunk);
        got += chunk.length;
        if (sw.elapsedMilliseconds > 100) {
          sw.reset();
          progress = total > 0 ? (got / total).clamp(0.0, 1.0) : null;
          _setStatus('Receiving from ${s.from}: ${p.basename(target.path)}');
          _notify();
        }
      }
      await sink.flush();
      await sink.close();
    } catch (e) {
      try {
        await sink.close();
      } catch (_) {}
      progress = null;
      _setStatus('Receive error: $e', StatusKind.error);
      _notify();
      rethrow;
    }
    s.done++;
    final allDone = s.done >= s.names.length;
    if (allDone) _sessions.remove(sid);
    progress = null;
    _setStatus('Saved: ${target.path}', StatusKind.success);
    _buzz();
    _addHistory(HistoryItem(p.basename(target.path), got, false, s.from, DateTime.now(), target.path));
    _notify();
    await _json(req, 200, {'ok': true});
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

    if (segs.length == 4 && segs[2] == 'f') {
      final idx = int.tryParse(segs[3]);
      if (!s.allowed.contains(ip) || idx == null || idx < 0 || idx >= s.files.length) {
        await req.response.redirect(Uri(path: '/s/${s.token}'));
        return;
      }
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

        final limitReached = cfg.maxDownloads > 0 && s.downloads >= cfg.maxDownloads;
        if (cfg.oneTimeDownload || limitReached) {
          stopShare();
        }
      } catch (e) {
        progress = null;
        _setStatus('Download interrupted: ${f.name}', StatusKind.error);
      }
      _notify();
      return;
    }

    if (!s.allowed.contains(ip)) {
      if (s.pin != null && !s.unlocked.contains(ip)) {
        final limit = cfg.pinAttempts;
        if (limit > 0 && (s.pinFails[ip] ?? 0) >= limit) {
          await _html(
            req,
            429,
            _page('<h1>$kAppName</h1><p>Too many wrong PIN attempts. This browser is blocked.</p>'),
          );
          return;
        }
        final given = req.uri.queryParameters['pin'];
        if (given != null && given == s.pin) {
          s.unlocked.add(ip);
        } else {
          final wrong = given != null;
          if (wrong) s.pinFails[ip] = (s.pinFails[ip] ?? 0) + 1;
          await _html(
            req,
            wrong ? 401 : 200,
            _page('<h1>$kAppName</h1><p>${wrong ? 'Wrong PIN. Try again.' : 'Enter the PIN to continue.'}</p>'
                '<form method="get"><input name="pin" inputmode="numeric" autofocus> <button>Open</button></form>'),
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
      s.allowed.add(ip);
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
      return Device('${j['alias']}', ip, '${j['platform'] ?? ''}');
    } catch (_) {
      return null;
    }
  }

  /// Probes [ips] with a fixed number of workers that each grab the next
  /// address as soon as they finish (no waiting for the slowest one).
  Future<void> _probeAll(HttpClient c, Iterable<String> ips, int workers,
      void Function(Device) onFound) async {
    final it = ips.iterator;
    Future<void> worker() async {
      while (online && !_disposed && it.moveNext()) {
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
    if (scanning || !online) return;
    scanning = true;
    _notify();
    final t = _tune;
    final fast = HttpClient()
      ..connectionTimeout = Duration(milliseconds: t.connectMs)
      ..idleTimeout = const Duration(seconds: 1);
    final patient = HttpClient()
      ..connectionTimeout = const Duration(milliseconds: 1200)
      ..idleTimeout = const Duration(seconds: 1);
    try {
      final mine = await _localIps();
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
        if (!online || _disposed) return;
        found[d.ip] = d;
        _miss.remove(d.ip);
        final old = devices[d.ip];
        if (old == null || old.alias != d.alias || old.platform != d.platform) {
          devices[d.ip] = d; // shows up right away, no need to wait for the end
          _notify();
        }
      }

      // 1) devices we already know answer first (short and cheap)
      final known = <String>{...devices.keys, ..._known.keys}..removeAll(mineSet);
      known.removeWhere((ip) => !prefixes.any((pre) => ip.startsWith('$pre.')));
      await _probeAll(patient, known, 64, onFound);

      // 2) then everything else on the network(s)
      if (full) {
        final rest = <String>[
          for (final pre in prefixes)
            for (var n = 1; n < 255; n++)
              if (!known.contains('$pre.$n') && !mineSet.contains('$pre.$n')) '$pre.$n',
        ];
        await _probeAll(fast, rest, t.workers, onFound);
        _lastSweep = DateTime.now();
      }
      if (!online || _disposed) return;

      // forget devices that stopped answering
      for (final ip in devices.keys.toList()) {
        if (found.containsKey(ip)) continue;
        final m = (_miss[ip] ?? 0) + 1;
        if (auto && m < 2) {
          _miss[ip] = m;
          continue;
        }
        devices.remove(ip);
        _miss.remove(ip);
      }
      _saveKnown();
    } catch (e) {
      _setStatus('Scan error: $e', StatusKind.error);
    } finally {
      fast.close(force: true);
      patient.close(force: true);
      scanning = false;
      _notify();
    }
  }

  Future<void> sendFiles(Device d, List<PlatformFile> files) async {
    if (!online) return;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      _setStatus('Waiting for ${d.alias} to accept…');
      progress = null;
      _notify();
      final sizes = <int>[];
      for (final f in files) {
        final n = f.lengthSync() ?? await f.length();
        if (n == null) throw 'Could not read file size: ${f.name}';
        sizes.add(n);
      }
      final req = await client
          .postUrl(Uri.parse('http://${d.ip}:${cfg.port}/api/send-request'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'alias': alias,
        'files': [
          for (var i = 0; i < files.length; i++)
            {'name': files[i].name, 'size': sizes[i]}
        ],
      }));
      final resp = await req.close().timeout(const Duration(seconds: 150));
      final text = await utf8.decoder.bind(resp).join();
      if (resp.statusCode != 200) {
        _setStatus(
          resp.statusCode == 403
              ? 'The other device declined'
              : 'Error: ${resp.statusCode} $text',
          StatusKind.error,
        );
        return;
      }
      final sid = (jsonDecode(text) as Map)['sessionId'] as String;
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final len = sizes[i];
        final up = await client.putUrl(Uri.parse(
            'http://${d.ip}:${cfg.port}/api/upload?sessionId=$sid&index=$i'));
        up.contentLength = len;
        var sent = 0;
        var lastPct = -1;
        await up.addStream(f.readAsByteStream().map((chunk) {
          sent += chunk.length;
          final pct = len > 0 ? (sent * 100 ~/ len) : 0;
          if (pct != lastPct) {
            lastPct = pct;
            progress = len > 0 ? sent / len : null;
            _setStatus('Sending (${i + 1}/${files.length}): ${f.name}');
            _notify();
          }
          return chunk;
        }));
        final r2 = await up.close();
        await r2.drain<void>();
        if (r2.statusCode != 200) throw 'Upload failed (${r2.statusCode})';
        _addHistory(HistoryItem(f.name, len, true, d.alias, DateTime.now(), null));
      }
      _setStatus(
          '${files.length} file${files.length == 1 ? '' : 's'} sent to ${d.alias}',
          StatusKind.success);
      _buzz();
    } catch (e) {
      _setStatus('Error: $e', StatusKind.error);
    } finally {
      progress = null;
      client.close(force: true);
      _notify();
    }
  }
}

// -------------------------------------------------------------------- UI

const Color kBg = Color(0xFF09090B);
const Color kCard = Color(0xFF18181B);
const Color kCard2 = Color(0xFF121214);
const Color kLine = Color(0xFF27272A);

BoxDecoration _cardDeco({double r = 20, Color color = kCard, Color border = kLine}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: border),
    );

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
  const _Hover({
    required this.child,
    this.scale = 1.025,
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
  final ValueNotifier<Offset> _pos = ValueNotifier(Offset.zero);

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final on = _hover && widget.enabled;
    return MouseRegion(
      cursor: (widget.enabled && widget.clickable) ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (e) {
        _pos.value = e.localPosition;
        setState(() => _hover = true);
      },
      onHover: (e) => _pos.value = e.localPosition,
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: on ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: (on && widget.glow)
                ? [BoxShadow(color: cs.primary.withAlpha(64), blurRadius: 18)]
                : const <BoxShadow>[],
          ),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              widget.child,
              if (widget.spotlight)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: on ? 1 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.radius),
                        child: CustomPaint(painter: _SpotPainter(_pos, cs.primary)),
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

/// Small soft light that follows the cursor inside a card.
class _SpotPainter extends CustomPainter {
  final ValueNotifier<Offset> pos;
  final Color color;
  _SpotPainter(this.pos, this.color) : super(repaint: pos);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withAlpha(54), color.withAlpha(0)],
        ).createShader(Rect.fromCircle(center: pos.value, radius: 90)),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotPainter old) => old.color != color || old.pos != pos;
}

/// Page background: dark base + faint top glow + a glow that sticks to the
/// mouse instantly and gently breathes where the cursor rests.
class _CursorGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  const _CursorGlow({required this.child, required this.color});

  @override
  State<_CursorGlow> createState() => _CursorGlowState();
}

class _CursorGlowState extends State<_CursorGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  Offset _target = Offset.zero;
  bool _on = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (e) {
        _pulse.repeat(reverse: true);
        setState(() {
          _target = e.localPosition;
          _on = true;
        });
      },
      onHover: (e) => setState(() => _target = e.localPosition),
      onExit: (_) {
        _pulse.stop();
        setState(() => _on = false);
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: _on ? 1.0 : 0.0),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOut,
                builder: (context, k, _) => AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    // follows the cursor instantly, no gliding
                    painter: _BgGlowPainter(_target, widget.color, k, _pulse.value),
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _BgGlowPainter extends CustomPainter {
  final Offset pos;
  final Color color;
  final double k; // 0..1 fade in/out
  final double pulse; // 0..1 breathing
  const _BgGlowPainter(this.pos, this.color, this.k, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = kBg);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -1.2),
          radius: 1.0,
          colors: [color.withAlpha(28), color.withAlpha(0)],
        ).createShader(rect),
    );
    if (k <= 0.01) return;
    // soft outer halo (smaller than 2.0.0) that breathes
    final r1 = 190 + 28 * pulse;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withAlpha((40 * k).round()), color.withAlpha(0)],
        ).createShader(Rect.fromCircle(center: pos, radius: r1)),
    );
    // brighter core
    final r2 = 64 + 10 * pulse;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withAlpha((46 * k).round()), color.withAlpha(0)],
        ).createShader(Rect.fromCircle(center: pos, radius: r2)),
    );
  }

  @override
  bool shouldRepaint(covariant _BgGlowPainter old) =>
      old.pos != pos || old.color != color || old.k != k || old.pulse != pulse;
}

// ------------------------------------------------------- bridge logo + splash

/// The LocalBridge logo: an arch bridge. `t` goes 0..1 and draws it step by
/// step (arch, deck, hangers, piers, water). Use t = 1 for the finished logo.
class _BridgeLogoPainter extends CustomPainter {
  final double t;
  final Color c1;
  final Color c2;
  const _BridgeLogoPainter(this.t, this.c1, this.c2);

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    double seg(double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0).toDouble();
    final shader = LinearGradient(
      colors: [c1, c2],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Offset.zero & s);
    Paint pen(double width) => Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    final sw = w * 0.05;
    final deckY = h * 0.64;
    final x0 = w * 0.10;
    final x1 = w * 0.90;
    final cy = h * 0.02;
    double archY(double u) =>
        (1 - u) * (1 - u) * deckY + 2 * (1 - u) * u * cy + u * u * deckY;

    // arch
    final arch = Path()
      ..moveTo(x0, deckY)
      ..quadraticBezierTo(w * 0.5, cy, x1, deckY);
    final pa = seg(0.0, 0.5);
    if (pa > 0) {
      for (final m in arch.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * pa), pen(sw));
      }
    }

    // deck
    final pd = seg(0.25, 0.7);
    if (pd > 0) {
      canvas.drawLine(Offset(x0, deckY), Offset(x0 + (x1 - x0) * pd, deckY), pen(sw));
    }

    // hangers
    const us = [0.2, 0.35, 0.5, 0.65, 0.8];
    for (var k = 0; k < us.length; k++) {
      final ph = seg(0.45 + 0.06 * k, 0.75 + 0.06 * k);
      if (ph <= 0) continue;
      final x = x0 + (x1 - x0) * us[k];
      final y = archY(us[k]);
      canvas.drawLine(Offset(x, y), Offset(x, y + (deckY - y) * ph), pen(sw * 0.5));
    }

    // piers
    final pp = seg(0.6, 0.95);
    if (pp > 0) {
      for (final fx in [0.26, 0.74]) {
        canvas.drawLine(
            Offset(w * fx, deckY), Offset(w * fx, deckY + h * 0.22 * pp), pen(sw * 0.9));
      }
    }

    // water line
    final pw = seg(0.7, 1.0);
    if (pw > 0) {
      final a = w * 0.18, b = w * 0.82;
      final mid = (a + b) / 2;
      final half = (b - a) / 2 * pw;
      canvas.drawLine(Offset(mid - half, h * 0.86), Offset(mid + half, h * 0.86), pen(sw * 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _BridgeLogoPainter old) =>
      old.t != t || old.c1 != c1 || old.c2 != c2;
}

/// Small single-color bridge mark (used in the app bar and side menu).
class _BridgeMark extends StatelessWidget {
  final double size;
  final Color color;
  const _BridgeMark({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BridgeLogoPainter(1, color, color)),
    );
  }
}

/// Shows the real app behind a black splash screen where the bridge logo
/// draws itself, then fades away. The app starts loading while the splash plays.
class _Boot extends StatefulWidget {
  final Settings settings;
  const _Boot({required this.settings});

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> with SingleTickerProviderStateMixin {
  // Startup animation setting: 0 = off, 1 = quick, 2 = full.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.settings.bootAnim == 2 ? 2600 : 1100),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (widget.settings.bootAnim == 0) {
      _c.value = 1.0;
      _done = true;
      return;
    }
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _done = true);
    });
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Shell(settings: widget.settings),
        if (!_done)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final v = _c.value;
                double seg(double a, double b) => ((v - a) / (b - a)).clamp(0.0, 1.0).toDouble();
                final draw = Curves.easeInOutCubic.transform(seg(0.0, 0.62));
                final text = Curves.easeOut.transform(seg(0.45, 0.70));
                final out = Curves.easeIn.transform(seg(0.82, 1.0));
                final grow = 1.0 + 0.06 * Curves.easeOut.transform(seg(0.0, 1.0));
                return Opacity(
                  opacity: 1 - out,
                  child: Material(
                    color: kBg,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // soft glow behind the logo
                        Container(
                          width: 420,
                          height: 420,
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                kBrand2.withAlpha((70 * Curves.easeOut.transform(seg(0.1, 0.7))).round()),
                                kBrand2.withAlpha(0),
                              ],
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: grow,
                              child: SizedBox(
                                width: 170,
                                height: 170,
                                child: CustomPaint(
                                  painter: _BridgeLogoPainter(draw, kBrand1, kBrand2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Opacity(
                              opacity: text,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - text)),
                                child: Column(
                                  children: const [
                                    Text(
                                      kAppName,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 4,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'v$kVersion',
                                      style: TextStyle(
                                        fontSize: 12,
                                        letterSpacing: 2,
                                        color: Colors.white38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
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
        final seed = kAccents[settings.accent];
        ThemeData theme(Brightness b) {
          final pr = ColorScheme.fromSeed(seedColor: seed, brightness: b);
          final fieldBorder = OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kLine),
          );
          return ThemeData(
            colorSchemeSeed: seed,
            brightness: b,
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.transparent,
            cardColor: const Color(0xFF18181B),
            dialogBackgroundColor: const Color(0xFF18181B),
            hoverColor: pr.primary.withAlpha(18),
            splashColor: pr.primary.withAlpha(30),
            highlightColor: pr.primary.withAlpha(14),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              scrolledUnderElevation: 0,
              backgroundColor: Color(0xFF09090B),
              foregroundColor: Color(0xFFF4F4F5),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: const Color(0xFF09090B),
              indicatorColor: seed.withAlpha(50),
            ),
            listTileTheme: const ListTileThemeData(
              contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              iconColor: Colors.white70,
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith<Color?>(
                (st) => st.contains(WidgetState.selected) ? pr.onPrimary : Colors.white54,
              ),
              trackColor: WidgetStateProperty.resolveWith<Color?>(
                (st) => st.contains(WidgetState.selected) ? pr.primary : kCard2,
              ),
              trackOutlineColor: WidgetStateProperty.resolveWith<Color?>(
                (st) => st.contains(WidgetState.selected) ? Colors.transparent : kLine,
              ),
            ),
            sliderTheme: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: pr.primary,
              inactiveTrackColor: kLine,
              thumbColor: pr.primary,
              overlayColor: pr.primary.withAlpha(30),
              activeTickMarkColor: Colors.transparent,
              inactiveTickMarkColor: Colors.transparent,
            ),
            popupMenuTheme: PopupMenuThemeData(
              color: kCard,
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: kLine),
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: kCard,
              contentTextStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: kLine),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: kCard2,
              border: fieldBorder,
              enabledBorder: fieldBorder,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: pr.primary, width: 1.6),
              ),
            ),
          );
        }

        return MaterialApp(
          title: kAppName,
          debugShowCheckedModeBanner: false,
          theme: theme(Brightness.light),
          darkTheme: theme(Brightness.dark),
          themeMode: ThemeMode.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(settings.textScale)),
            child: _CursorGlow(color: seed, child: child!),
          ),
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

class _ShellState extends State<Shell> {
  late final DropService svc;
  bool _dialogOpen = false;
  int _tab = 0;
  int _lastPort = 0;
  int _lastScan = 0;
  bool _lastAutoScan = true;

  @override
  void initState() {
    super.initState();
    svc = DropService(widget.settings);
    _lastPort = widget.settings.port;
    _lastScan = widget.settings.scanSeconds;
    _lastAutoScan = widget.settings.autoScan;
    svc.addListener(_onChange);
    widget.settings.addListener(_onSettings);
    svc.start();
  }

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    svc.removeListener(_onChange);
    svc.dispose();
    super.dispose();
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
    final r = svc.pending;
    if (r != null && !_dialogOpen) {
      _dialogOpen = true;
      _showRequest(r);
    } else if (r == null && _dialogOpen) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _showRequest(IncomingRequest r) async {
    final total = r.files.fold<int>(0, (a, f) => a + f.size);
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFF27272A))),
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
                Text('${r.files.length} file${r.files.length == 1 ? '' : 's'} • ${fmtSize(total)}',
                    style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: cs.primary)),
                const SizedBox(height: 8),
                for (final f in r.files.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        const Icon(Icons.insert_drive_file_outlined, size: 18),
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

  Future<void> _pickAndSend(Device d) async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;
    svc.sendFiles(d, files);
  }

  Future<void> _pickAndShare() async {
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
      DevicesPage(svc: svc, onSend: _pickAndSend, onShare: _pickAndShare),
      HistoryPage(svc: svc),
      SettingsPage(settings: widget.settings, svc: svc),
    ];
    final navItems = <(IconData, IconData, String)>[
      (Icons.radar_outlined, Icons.radar, s.tr('devices')),
      (Icons.history_outlined, Icons.history, s.tr('history')),
      (Icons.settings_outlined, Icons.settings, s.tr('settings')),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        // Big window: side menu on the left, content fills the rest.
        if (box.maxWidth >= kWideBreakpoint) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  _SideRail(
                    index: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                    items: navItems,
                    svc: svc,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: kMaxWideWidth),
                        child: IndexedStack(
                          index: _tab,
                          sizing: StackFit.expand,
                          children: pages,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        // Phone / small window: single column and floating bottom bar.
        return Scaffold(
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                child: IndexedStack(
                  index: _tab,
                  sizing: StackFit.expand,
                  children: pages,
                ),
              ),
            ),
          ),
          bottomNavigationBar: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
              child: _NavBar(
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
                items: navItems,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------ shared widgets

/// Left side menu used on wide windows (replaces the bottom bar).
class _SideRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData, IconData, String)> items;
  final DropService svc;
  const _SideRail({
    required this.index,
    required this.onChanged,
    required this.items,
    required this.svc,
  });

  String get _platformName => Platform.isWindows
      ? 'Windows'
      : Platform.isAndroid
          ? 'Android'
          : Platform.isMacOS
              ? 'macOS'
              : Platform.isIOS
                  ? 'iOS'
                  : 'Linux';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tr = svc.cfg.tr;
    final online = svc.online;
    var sentN = 0, recvN = 0;
    for (final h in svc.history) {
      if (h.sent) {
        sentN++;
      } else {
        recvN++;
      }
    }
    final ip = (svc.cfg.showIps && svc.myIps.isNotEmpty) ? svc.myIps.first : null;
    return Container(
      width: 264,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      decoration: const BoxDecoration(
        color: kCard2,
        border: Border(right: BorderSide(color: kLine)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.7)!],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: _BridgeMark(size: 24, color: cs.onPrimary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    kAppName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5, fontSize: 19),
                  ),
                ),
              ],
            ),
          ),
          // Device card (same info as the top of the Settings page)
          _Hover(
            radius: 18,
            scale: 1.02,
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: kLine),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary.withAlpha(50), kCard],
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => onChanged(items.length - 1),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            gradient: LinearGradient(
                              colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.7)!],
                            ),
                          ),
                          child: Icon(
                            Platform.isAndroid || Platform.isIOS
                                ? Icons.smartphone_rounded
                                : Icons.laptop_rounded,
                            color: cs.onPrimary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                svc.cfg.deviceName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ip == null ? _platformName : '$_platformName • $ip',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, color: Colors.white54),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _Hover(
                        radius: 16,
                        scale: 1.02,
                        glow: false,
                        child: Material(
                          color: i == index ? cs.primary.withAlpha(40) : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => onChanged(i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              child: Row(
                                children: [
                                  Icon(
                                    i == index ? items[i].$2 : items[i].$1,
                                    size: 22,
                                    color: i == index ? cs.primary : Colors.white60,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      items[i].$3,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                                        color: i == index ? cs.primary : Colors.white70,
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
                  const SizedBox(height: 14),
                  // live stats
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: _cardDeco(r: 18),
                    child: Column(
                      children: [
                        _SideStat(
                          icon: Icons.radar_rounded,
                          color: cs.primary,
                          label: tr('sidebarNearby'),
                          value: '${svc.devices.length}',
                        ),
                        const SizedBox(height: 10),
                        _SideStat(
                          icon: Icons.arrow_upward_rounded,
                          color: Colors.lightBlueAccent,
                          label: tr('filterSent'),
                          value: '$sentN',
                        ),
                        const SizedBox(height: 10),
                        _SideStat(
                          icon: Icons.arrow_downward_rounded,
                          color: Colors.tealAccent,
                          label: tr('filterReceived'),
                          value: '$recvN',
                        ),
                        if (svc.share != null) ...[
                          const SizedBox(height: 10),
                          _SideStat(
                            icon: Icons.wifi_tethering_rounded,
                            color: Colors.greenAccent,
                            label: tr('sharingNow'),
                            value: '${svc.share!.downloads}',
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: online
                ? OutlinedButton.icon(
                    onPressed: () => svc.setOnline(false),
                    icon: const Icon(Icons.power_settings_new_rounded, size: 18),
                    label: Text(tr('turnOff')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withAlpha(110)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  )
                : _GradButton(
                    label: tr('turnOn'),
                    icon: Icons.power_settings_new_rounded,
                    onTap: () => svc.setOnline(true),
                  ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: _cardDeco(r: 16),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: !online
                        ? Colors.white38
                        : (svc.serverUp ? Colors.greenAccent : Colors.redAccent),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    !online
                        ? tr('disabled')
                        : (svc.serverUp ? tr('ready') : tr('serverOff')),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: online ? Colors.white : Colors.white54,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _Pill(icon: Icons.verified_rounded, text: 'v$kVersion', color: cs.primary),
          ),
        ],
      ),
    );
  }
}

class _SideStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _SideStat(
      {required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: color.withAlpha(26), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white70)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
      ],
    );
  }
}

/// One column on narrow areas, up to [maxColumns] on wide ones. Used for the
/// settings and sharing sections so labels and switches never end up far apart.
class _AdaptiveColumns extends StatelessWidget {
  final List<Widget> children;

  /// Keep the first child (e.g. a profile header) full width above the columns.
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

/// Floating pill-shaped bottom navigation.
class _NavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData, IconData, String)> items;
  const _NavBar({required this.index, required this.onChanged, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: kLine),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => onChanged(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Hover(
                          radius: 16,
                          scale: 1.1,
                          glow: false,
                          spotlight: false,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            padding: EdgeInsets.symmetric(
                                horizontal: i == index ? 20 : 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: i == index ? cs.primary.withAlpha(45) : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              i == index ? items[i].$2 : items[i].$1,
                              size: 24,
                              color: i == index ? cs.primary : Colors.white54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].$3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                            color: i == index ? cs.primary : Colors.white54,
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

/// Gradient filled button used everywhere instead of the plain FilledButton.
class _GradButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool compact;
  const _GradButton({required this.label, this.icon, this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c1 = cs.primary;
    final c2 = Color.lerp(cs.primary, cs.tertiary, 0.7)!;
    return _Hover(
      enabled: onTap != null,
      radius: 14,
      scale: 1.04,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c1, c2]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 9 : 13),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: cs.onPrimary),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        border: Border.all(color: color.withAlpha(60)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Small "current value" chip with a dropdown arrow, used for popup menus.
class _ValuePill extends StatelessWidget {
  final String text;
  const _ValuePill(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
      decoration: BoxDecoration(
        color: cs.primary.withAlpha(22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: cs.primary)),
          Icon(Icons.arrow_drop_down_rounded, size: 20, color: cs.primary),
        ],
      ),
    );
  }
}

/// Rounded tinted icon badge used as the leading icon of every settings row.
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
        color: cs.primary.withAlpha(24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: cs.primary),
    );
  }
}

// ------------------------------------------------------------ Devices page

class DevicesPage extends StatelessWidget {
  final DropService svc;
  final void Function(Device) onSend;
  final VoidCallback onShare;
  const DevicesPage({super.key, required this.svc, required this.onSend, required this.onShare});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final devs = svc.devices.values.toList();
    final tr = svc.cfg.tr;
    final online = svc.online;
    return LayoutBuilder(builder: (context, box) {
      // `wide`: the side menu is showing. `twoCol`: enough room for two columns.
      final wide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;
      final twoCol = box.maxWidth >= 820;
      final pad = wide ? 24.0 : 16.0;
      final sharing = _sharingSections(context, svc.cfg);
      final quick = _quickSettings(svc.cfg);

      final nearbyHeader = Row(
        children: [
          Text(tr('nearby'), style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          if (devs.isNotEmpty) Badge(label: Text('${devs.length}'), backgroundColor: cs.primary),
          const Spacer(),
          if (svc.scanning)
            Text(tr('scanning'), style: tt.labelMedium?.copyWith(color: cs.outline)),
        ],
      );

      Widget deviceCard(Device d) => _DeviceCard(
            device: d,
            showIp: svc.cfg.showIps,
            trusted: svc.cfg.trusted.contains(d.alias),
            sendLabel: tr('send'),
            onTrust: () => svc.cfg.toggleTrusted(d.alias),
            onTap: () => onSend(d),
          );

      const deviceGrid = SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250,
        mainAxisExtent: 198,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
      );

      return CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            titleSpacing: wide ? 24 : 16,
            title: wide
                ? Text(tr('devices'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 21))
                : Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.7)!],
                          ),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: _BridgeMark(size: 20, color: cs.onPrimary),
                      ),
                      const SizedBox(width: 10),
                      const Text(kAppName,
                          style: TextStyle(
                              fontWeight: FontWeight.w800, letterSpacing: 0.6, fontSize: 19)),
                    ],
                  ),
            actions: [
              // Power switch: turns scanning + the server on/off.
              Padding(
                padding: EdgeInsets.only(right: wide ? 24 : 16),
                child: _Hover(
                  radius: 20,
                  glow: false,
                  child: Tooltip(
                    message: online ? tr('turnOff') : tr('turnOn'),
                    child: Material(
                      color: kCard,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: online ? kLine : Colors.redAccent.withAlpha(110),
                        ),
                      ),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => svc.setOnline(!online),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: !online
                                      ? Colors.white38
                                      : (svc.serverUp ? Colors.greenAccent : Colors.redAccent),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                online ? tr('active') : tr('disabled'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: online ? Colors.white : Colors.white54,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.power_settings_new_rounded,
                                size: 15,
                                color: online ? cs.primary : Colors.redAccent,
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
          ),
          if (twoCol)
            // Wide window: radar + status + quick settings on the left, devices
            // + link share on the right, sharing settings in even columns below.
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 28),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: min(480.0, max(360.0, (box.maxWidth - 2 * pad) * 0.42)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _RadarHero(svc: svc, onSend: onSend, height: 340),
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
                              const SizedBox(height: 14),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _AdaptiveColumns(maxColumns: 3, children: sharing),
                  ],
                ),
              ),
            )
          else ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(pad, 4, pad, 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _RadarHero(svc: svc, onSend: onSend),
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
      );
    });
  }
}

/// The big radar card: nearby devices are plotted on the radar and can be tapped.
class _RadarHero extends StatefulWidget {
  final DropService svc;
  final void Function(Device) onSend;
  final double height;
  const _RadarHero({required this.svc, required this.onSend, this.height = 300});

  @override
  State<_RadarHero> createState() => _RadarHeroState();
}

class _RadarHeroState extends State<_RadarHero> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final svc = widget.svc;
    final tr = svc.cfg.tr;
    final devs = svc.devices.values.toList();
    final animate = svc.scanning && svc.cfg.showRadar;
    final ipText = svc.myIps.isEmpty
        ? 'No network found'
        : (svc.cfg.showIps ? svc.myIps.join(' • ') : 'IP address hidden');

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kLine),
        gradient: RadialGradient(
          center: const Alignment(0, -0.25),
          radius: 1.0,
          colors: [cs.primary.withAlpha(46), kCard, kCard2],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
      child: Column(
        children: [
          if (!svc.cfg.compactHeader)
            SizedBox(
              height: widget.height,
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  final h = box.maxHeight;
                  final c = Offset(w / 2, h / 2);
                  final maxR = min(w, h) / 2 - 40;
                  final n = devs.length;
                  final nodes = <Widget>[];
                  for (var i = 0; i < n; i++) {
                    final d = devs[i];
                    final ring = (n <= 3) ? 0.62 : (i.isEven ? 0.62 : 0.92);
                    final ang = -pi / 2 + i * 2 * pi / n + (n == 1 ? 0.7 : 0.0);
                    final pos = c + Offset(cos(ang), sin(ang)) * (maxR * ring);
                    nodes.add(
                      Positioned(
                        key: ValueKey(d.ip),
                        left: pos.dx - 44,
                        top: pos.dy - 22,
                        width: 88,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 450),
                          curve: Curves.easeOutBack,
                          builder: (context, v, child) => Transform.scale(scale: v, child: child),
                          child: _RadarNode(device: d, onTap: () => widget.onSend(d)),
                        ),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _c,
                          builder: (context, _) => CustomPaint(
                            painter: _RadarPainter(_c.value, cs.primary, animate),
                          ),
                        ),
                      ),
                      ...nodes,
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.7)!],
                            ),
                            boxShadow: [
                              BoxShadow(
                                  color: cs.primary.withAlpha(svc.online ? 110 : 30),
                                  blurRadius: 26,
                                  spreadRadius: 2),
                            ],
                          ),
                          child: Icon(
                            svc.online
                                ? (Platform.isAndroid || Platform.isIOS
                                    ? Icons.smartphone_rounded
                                    : Icons.laptop_rounded)
                                : Icons.power_settings_new_rounded,
                            size: 28,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, svc.cfg.compactHeader ? 20 : 0, 20, 20),
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
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ipText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _RoundBtn(
                      icon: Icons.refresh_rounded,
                      busy: svc.scanning,
                      tooltip: tr('scan'),
                      onTap: (svc.scanning || !svc.online) ? null : () => svc.scan(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      icon: !svc.online
                          ? Icons.power_settings_new_rounded
                          : (svc.serverUp ? Icons.check_circle_rounded : Icons.error_rounded),
                      text: !svc.online
                          ? tr('disabled')
                          : (svc.serverUp ? tr('ready') : tr('serverOff')),
                      color: !svc.online
                          ? Colors.white54
                          : (svc.serverUp ? Colors.greenAccent : Colors.redAccent),
                    ),
                    _Pill(
                      icon: svc.cfg.autoAccept ? Icons.bolt_rounded : Icons.shield_rounded,
                      text: svc.cfg.autoAccept ? tr('autoAccept') : tr('askFirst'),
                      color: cs.primary,
                    ),
                    _Pill(
                      icon: Icons.lan_rounded,
                      text: '${svc.cfg.port}',
                      color: Colors.white70,
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
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final bool busy;
  final String tooltip;
  final VoidCallback? onTap;
  const _RoundBtn({required this.icon, required this.busy, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Hover(
      enabled: onTap != null,
      radius: 23,
      scale: 1.1,
      spotlight: false,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: cs.primary.withAlpha(onTap == null && !busy ? 14 : 30),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.primary),
                      )
                    : Icon(icon, color: onTap == null ? Colors.white30 : cs.primary),
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
  final VoidCallback onTap;
  const _RadarNode({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: _Hover(
        radius: 16,
        scale: 1.12,
        glow: false,
        spotlight: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kBg,
                border: Border.all(color: cs.primary, width: 2),
                boxShadow: [BoxShadow(color: cs.primary.withAlpha(90), blurRadius: 14)],
              ),
              child: Icon(
                device.isPhone ? Icons.smartphone_rounded : Icons.computer_rounded,
                size: 22,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              device.alias,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double t;
  final Color color;
  final bool active;
  _RadarPainter(this.t, this.color, this.active);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = min(size.width, size.height) / 2 - 40;

    // crosshair
    final line = Paint()
      ..color = color.withAlpha(22)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(c.dx - maxR - 24, c.dy), Offset(c.dx + maxR + 24, c.dy), line);
    canvas.drawLine(Offset(c.dx, c.dy - maxR - 24), Offset(c.dx, c.dy + maxR + 24), line);

    // rings
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withAlpha(46);
    for (final f in [0.36, 0.62, 0.92]) {
      canvas.drawCircle(c, maxR * f, ring);
    }

    if (!active) return;

    // sweep
    final ang = t * 2 * pi;
    final r = maxR + 16;
    final sweep = Paint()
      ..shader = SweepGradient(
        colors: [color.withAlpha(0), color.withAlpha(120)],
        stops: const [0.72, 1.0],
        transform: GradientRotation(ang),
      ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, sweep);
    canvas.drawLine(
      c,
      c + Offset(cos(ang), sin(ang)) * r,
      Paint()
        ..color = color.withAlpha(200)
        ..strokeWidth = 2,
    );

    // pulses
    for (var i = 0; i < 2; i++) {
      final pr = (t * 2 + i / 2) % 1.0;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withAlpha(((1 - pr) * 90).toInt());
      canvas.drawCircle(c, 34 + (maxR - 34) * pr, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) =>
      old.t != t || old.color != color || old.active != active;
}

class _StatusCard extends StatelessWidget {
  final DropService svc;
  const _StatusCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, IconData icon) = switch (svc.kind) {
      StatusKind.success => (const Color(0xFF064e3b), const Color(0xFF34d399), Icons.check_circle_rounded),
      StatusKind.error => (const Color(0xFF7f1d1d), const Color(0xFFf87171), Icons.error_rounded),
      StatusKind.info => (const Color(0xFF1e1b4b), const Color(0xFFa78bfa), Icons.sync_rounded),
    };
    final busy = svc.progress != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 14),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: fg.withAlpha(60)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(svc.status,
                      style: TextStyle(color: fg, fontWeight: FontWeight.w500))),
              if (!busy)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: svc.clearStatus,
                  icon: Icon(Icons.close_rounded, color: fg, size: 20),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('${((svc.progress ?? 0) * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: fg, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          if (busy)
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: svc.progress, minHeight: 6, backgroundColor: Colors.black26, color: fg),
              ),
            ),
        ],
      ),
    );
  }
}

/// Slim "Share via link" bar.
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
    final cs = Theme.of(context).colorScheme;
    final fg = filled ? cs.onPrimary : Colors.white;
    final sub = filled ? cs.onPrimary.withAlpha(200) : Colors.white54;
    return _Hover(
      enabled: onTap != null,
      radius: 24,
      scale: 1.02,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: filled
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.7)!],
                    ),
                  )
                : _cardDeco(r: 24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: filled ? Colors.black.withAlpha(38) : cs.primary.withAlpha(28),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, size: 26, color: filled ? cs.onPrimary : cs.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, height: 1.3, color: sub),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: fg),
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

/// Shown instead of the action tiles while a link share is running.
class _ShareCard extends StatelessWidget {
  final DropService svc;
  const _ShareCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    final s = svc.share;
    if (s == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final urls = svc.shareUrls;
    final tr = svc.cfg.tr;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.primary.withAlpha(100)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary.withAlpha(36), kCard],
        ),
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
                child: Text(tr('sharingNow'),
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
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
                  color: Colors.white70),
              _Pill(
                  icon: Icons.download_rounded,
                  text: svc.cfg.maxDownloads > 0
                      ? '${s.downloads} / ${svc.cfg.maxDownloads}'
                      : '${s.downloads}',
                  color: Colors.greenAccent),
              if (s.pin != null)
                _Pill(icon: Icons.pin_outlined, text: 'PIN: ${s.pin}', color: cs.primary),
              if (svc.cfg.oneTimeDownload)
                _Pill(icon: Icons.looks_one_rounded, text: '1×', color: Colors.orangeAccent),
              if (svc.cfg.shareMinutes > 0)
                _Pill(
                    icon: Icons.timer_outlined,
                    text: '${svc.cfg.shareMinutes} min',
                    color: Colors.white70),
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
                decoration: _cardDeco(r: 14, color: kCard2),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(u,
                          style: tt.bodyMedium?.copyWith(color: Colors.white70, fontSize: 13)),
                    ),
                    IconButton(
                      tooltip: tr('copyLink'),
                      icon: Icon(Icons.copy_rounded, size: 20, color: cs.primary),
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
              const SizedBox(height: 6),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: 160,
                        height: 160,
                        child: Image.network(
                          'https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=${Uri.encodeComponent(urls.first)}',
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(urls.first,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(tr('qrTitle'),
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)),
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
                foregroundColor: Colors.redAccent,
                side: BorderSide(color: Colors.redAccent.withAlpha(120)),
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
  final String sendLabel;
  const _DeviceCard({
    required this.device,
    required this.onTap,
    required this.onTrust,
    required this.showIp,
    required this.trusted,
    required this.sendLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _Hover(
      radius: 22,
      scale: 1.03,
      child: Container(
        decoration: _cardDeco(r: 22, border: trusted ? cs.primary.withAlpha(120) : kLine),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: cs.primary.withAlpha(28),
                          borderRadius: BorderRadius.circular(15),
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
                              color: trusted ? cs.primary : Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    device.alias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    showIp ? device.ip : 'Hidden',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: Colors.white54),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: _GradButton(
                      label: sendLabel,
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
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  final DropService svc;
  const _EmptyDevices({required this.svc});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tr = svc.cfg.tr;
    final off = !svc.online;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: _cardDeco(r: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: cs.primary.withAlpha(24), shape: BoxShape.circle),
            child: Icon(off ? Icons.power_settings_new_rounded : Icons.wifi_find_rounded,
                size: 38, color: cs.primary),
          ),
          const SizedBox(height: 16),
          Text(off ? tr('offlineTitle') : tr('noDevices'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            off ? tr('offlineHint') : '${tr('noDevicesHint')}\n${tr('firewallHint')}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: off
                ? _GradButton(
                    label: tr('turnOn'),
                    icon: Icons.power_settings_new_rounded,
                    onTap: () => svc.setOnline(true),
                  )
                : _GradButton(
                    label: tr('scan'),
                    icon: Icons.refresh_rounded,
                    onTap: svc.scanning ? null : svc.scan,
                  ),
          ),
        ],
      ),
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
  int _filter = 0; // 0 all, 1 sent, 2 received

  @override
  Widget build(BuildContext context) {
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
    final shown = _filter == 0
        ? items
        : items.where((h) => _filter == 1 ? h.sent : !h.sent).toList();

    Widget chip(int i, String label) {
      final sel = _filter == i;
      return _Hover(
        radius: 20,
        scale: 1.06,
        glow: false,
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          showCheckmark: false,
          onSelected: (_) => setState(() => _filter = i),
          backgroundColor: kCard,
          selectedColor: cs.primary.withAlpha(50),
          shape: StadiumBorder(side: BorderSide(color: sel ? cs.primary : kLine)),
          labelStyle: TextStyle(
            color: sel ? cs.primary : Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= kTwoColWidth;
      // Row height grows with the text size setting so nothing overflows.
      final ts = MediaQuery.textScalerOf(context).scale(14) / 14;
      final rowExtent = 86.0 + (ts > 1 ? (ts - 1) * 34 : 0.0);
      return CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            titleSpacing: wide ? 24 : 16,
            title: Text(tr('history'), style: const TextStyle(fontWeight: FontWeight.w800)),
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
                            side: const BorderSide(color: Color(0xFF27272A))),
                        title: Text(tr('clearHistory')),
                        content: const Text('Files are not deleted, only the list is cleared.'),
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
                          color: Colors.tealAccent,
                          label: '${tr('filterReceived')} · $recvN',
                          value: fmtSize(recvB),
                        ),
                      ),
                      if (wide) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatTile(
                            icon: Icons.swap_vert_rounded,
                            color: Colors.amberAccent,
                            label: '${tr('filterAll')} · ${items.length}',
                            value: fmtSize(sentB + recvB),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),
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
                    const Icon(Icons.history_toggle_off_rounded, size: 56, color: Colors.white38),
                    const SizedBox(height: 12),
                    Text(tr('noTransfers'), style: const TextStyle(color: Colors.white54)),
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
                        maxCrossAxisExtent: 440,
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
                  final col = h.sent ? cs.primary : Colors.tealAccent;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _Hover(
                      radius: 18,
                      scale: 1.015,
                      glow: false,
                      clickable: h.path != null,
                      // Material (not Container) so hover / press effects show.
                      child: Material(
                        color: kCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: kLine),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(12, 4, 14, 4),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: col.withAlpha(26),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              h.sent ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              color: col,
                            ),
                          ),
                          title: Text(h.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700)),
                          subtitle: Text(
                            '${h.sent ? tr('to') : tr('from')}: ${h.peer} • ${fmtTime(h.time)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: kCard2,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kLine),
                            ),
                            child: Text(fmtSize(h.size),
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w600)),
                          ),
                          onTap: h.path == null
                              ? null
                              : () => ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text(h.path!))),
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
    return _Hover(
      radius: 20,
      scale: 1.03,
      clickable: false,
      glow: false,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDeco(r: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: color.withAlpha(26), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11.5, color: Colors.white54)),
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
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF27272A))),
      title: Text(title),
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
    ),
  );
}

/// Handy receive switches shown right on the Devices page.
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

/// The three link-sharing sections (options, security, share page). They live
/// directly on the Devices page and also on the standalone page below.
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
            final v = await _askText(
                context, settings, tr('allowedExtensions'), settings.allowedExtensionFilter,
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
              ? 'Off (applies to new shares)'
              : 'Enabled (applies to new shares)'),
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
              ? 'Never (applies to new shares)'
              : 'After ${settings.shareMinutes} min (applies to new shares)'),
          trailing: PopupMenuButton<int>(
            initialValue: settings.shareMinutes,
            onSelected: (v) => settings.update(() => settings.shareMinutes = v),
            itemBuilder: (_) => [
              for (final m in [0, 5, 15, 30, 60, 180])
                PopupMenuItem(value: m, child: Text(m == 0 ? 'Never' : '$m min')),
            ],
            child: _ValuePill(
                settings.shareMinutes == 0 ? 'Never' : '${settings.shareMinutes} min'),
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
  const SettingsPage({super.key, required this.settings, required this.svc});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Settings get s => widget.settings;
  String _defaultDir = '';

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

  Future<String?> _ask(String title, String initial,
      {String? hint, TextInputType? type}) {
    return _askText(context, s, title, initial, hint: hint, type: type);
  }

  Future<void> _editName() async {
    final v = await _ask(s.tr('deviceName'), s.deviceName);
    if (v != null && v.isNotEmpty) s.update(() => s.deviceName = v);
  }

  Future<void> _openGithub() async {
    const url = 'https://github.com/unqale';
    var ok = false;
    try {
      ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      Clipboard.setData(const ClipboardData(text: url));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the browser, link copied')),
      );
    }
  }

  Widget _langOption(AppLang l, String label) {
    final cs = Theme.of(context).colorScheme;
    final sel = s.language == l;
    return Expanded(
      child: GestureDetector(
        onTap: () => s.update(() => s.language = l),
        child: _Hover(
          radius: 14,
          scale: 1.04,
          glow: false,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: sel ? cs.primary.withAlpha(40) : kCard2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? cs.primary : kLine),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: sel ? cs.primary : Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text(s.tr('settings'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverToBoxAdapter(
              child: _AdaptiveColumns(fullWidthFirst: true, children: [
                // profile header
                Container(
                  margin: const EdgeInsets.only(bottom: 18),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: kLine),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cs.primary.withAlpha(50), kCard],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            colors: [cs.primary, Color.lerp(cs.primary, cs.tertiary, 0.7)!],
                          ),
                        ),
                        child: Icon(
                          Platform.isAndroid || Platform.isIOS
                              ? Icons.smartphone_rounded
                              : Icons.laptop_rounded,
                          color: cs.onPrimary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.deviceName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.svc.myIps.isEmpty || !s.showIps
                                  ? kAppName
                                  : widget.svc.myIps.join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.white54),
                            ),
                            const SizedBox(height: 8),
                            _Pill(
                                icon: Icons.verified_rounded,
                                text: 'v$kVersion',
                                color: cs.primary),
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
                _Section(title: s.tr('language'), icon: Icons.translate_rounded, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                    child: Row(
                      children: [
                        _langOption(AppLang.english, 'English'),
                        _langOption(AppLang.turkish, 'Türkçe'),
                        _langOption(AppLang.russian, 'Русский'),
                      ],
                    ),
                  ),
                ]),
                _Section(title: s.tr('appearance'), icon: Icons.palette_outlined, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (var i = 0; i < kAccents.length; i++)
                          GestureDetector(
                            onTap: () => s.update(() => s.accent = i),
                            child: _Hover(
                              radius: 19,
                              scale: 1.15,
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
                                    color: s.accent == i ? Colors.white : Colors.transparent,
                                    width: 3,
                                  ),
                                  boxShadow: s.accent == i
                                      ? [BoxShadow(color: kAccents[i].withAlpha(140), blurRadius: 12)]
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const _Ic(Icons.format_size_rounded),
                          const SizedBox(width: 16),
                          Text('${s.tr('textSize')}: ${(s.textScale * 100).round()}%'),
                        ]),
                        Slider(
                          min: 0.8,
                          max: 1.4,
                          divisions: 12,
                          value: s.textScale.clamp(0.8, 1.4).toDouble(),
                          label: '${(s.textScale * 100).round()}%',
                          onChanged: (v) =>
                              s.update(() => s.textScale = double.parse(v.toStringAsFixed(2))),
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
                  ListTile(
                    leading: const _Ic(Icons.verified_user_outlined),
                    title: Text(s.tr('trustedDevs')),
                    subtitle: Text(s.trusted.isEmpty ? 'None yet' : s.trusted.join(', ')),
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
                          Text('${s.tr('timeout')}: ${s.requestTimeout} s'),
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
                _Section(title: s.tr('linkSharingOptions'), icon: Icons.link_rounded, children: [
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
                            Text('${s.tr('scanInterval')}: ${s.scanSeconds} s'),
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
                      final v = await _ask(s.tr('port'), '${s.port}', type: TextInputType.number);
                      final n = int.tryParse(v ?? '');
                      if (n != null && n >= 1024 && n <= 65535) {
                        s.update(() => s.port = n);
                      } else if (v != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Port must be between 1024 and 65535')),
                        );
                      }
                    },
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
                  ListTile(
                    leading: const _Ic(Icons.delete_outline_rounded),
                    title: Text(s.tr('clearHistory')),
                    onTap: () {
                      widget.svc.clearHistory();
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('History cleared')));
                    },
                  ),
                ]),
                _Section(title: s.tr('about'), icon: Icons.info_outline_rounded, children: [
                  ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: cs.primary.withAlpha(24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(child: _BridgeMark(size: 22, color: cs.primary)),
                    ),
                    title: const Text(kAppName),
                    subtitle: const Text('Version $kVersion'),
                  ),
                  ListTile(
                    leading: const _Ic(Icons.code_rounded),
                    title: const Text('Made by unqale'),
                    subtitle: const Text('https://github.com/unqale'),
                    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                    onTap: _openGithub,
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
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                              side: const BorderSide(color: Color(0xFF27272A))),
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
              ]),
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
  const _Section({required this.title, required this.children, this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(height: 1, thickness: 1, color: Color(0xFF222226)));
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.primary.withAlpha(26),
                      borderRadius: BorderRadius.circular(9),
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
          // Material (not a decorated Container) so that hover, press and
          // ripple effects of the rows are actually visible on top of it.
          _Hover(
            radius: 22,
            scale: 1.0,
            glow: false,
            clickable: false,
            child: Material(
              color: kCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: kLine),
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
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: const Color(0xFF18181B),
    constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      final tt = Theme.of(ctx).textTheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text(s.tr('whatsNew'),
                style: tt.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(height: 16),
            for (var i = 0; i < kChangelog.length; i++) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: i == 0 ? cs.primary : const Color(0xFF27272A),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${s.tr('update')} ${kChangelog[i].version}',
                      style: TextStyle(
                        color: i == 0 ? cs.onPrimary : Colors.white70,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(kChangelog[i].title(s.language),
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                  if (i == 0)
                    Text(s.tr('current'), style: tt.labelMedium?.copyWith(color: cs.primary)),
                ],
              ),
              const SizedBox(height: 8),
              for (final line in kChangelog[i].lines(s.language))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: cs.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(line, style: const TextStyle(color: Colors.white70))),
                    ],
                  ),
                ),
              if (i != kChangelog.length - 1)
                const Divider(height: 28, color: Color(0xFF27272A)),
            ],
          ],
        ),
      );
    },
  );
}