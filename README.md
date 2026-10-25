# MDLegacy

[English](#english) | [Русский](#русский)

---

## English

An unofficial native [MangaDex](https://mangadex.org) client for **iOS 6** (jailbroken devices), built with [Theos](https://theos.dev).

Modern MangaDex can't be reached from iOS 6 with the system networking stack, so MDLegacy ships its own TLS 1.3 client on top of [mbedTLS](https://github.com/Mbed-TLS/mbedtls). That is what makes old iPhones, iPods and iPads usable for reading manga again.

> The app interface is in Russian.
> MDLegacy is not affiliated with or endorsed by MangaDex. All content belongs to its respective authors and groups.

### Features

- **Catalog** – popular and latest titles, search by name, infinite scrolling, pull to refresh.
- **Manga page** – chapter list in the language of your choice, last-read position, favorites.
- **Reader** – horizontal paging, double-tap zoom (up to 3×), tap to show or hide the interface, previous/next chapter, portrait and landscape, resumes from the page where you stopped.
- **Library** – favorites, reading history and downloads in one place.
- **Offline reading** – download a chapter, all chapters, only unread ones, or "this and everything newer"; downloaded chapters open without a network.
- **Settings** – data saver (smaller images), 18+ content switch, default chapter language, cache and history cleanup.
- **Night mode** – warm tint in the reader with adjustable intensity: off, always, or on a schedule.

### Requirements

**On the device**
- iOS 6.0 or later, armv7 (iPhone 3GS and newer, iPad, iPod touch 3rd generation and newer)
- Jailbreak, to install the `.deb`
- A correct date and time (certificate validity is checked)

**On the build machine**
- [Theos](https://theos.dev/docs/installation) with the **iPhoneOS 6.1 SDK** in `$THEOS/sdks`
- `git` and `curl`

### Building

The project needs two things that are not stored in this repository: the mbedTLS sources and a CA bundle. Run once from the project root:

```sh
# mbedTLS 3.6.2 sources (compiled straight into the app)
git clone --depth 1 -b v3.6.2 https://github.com/Mbed-TLS/mbedtls.git mbedtls
```

Then build the package:

```sh
make clean package
```

The `.deb` appears in `packages/`. To install it directly on a device over SSH:

```sh
export THEOS_DEVICE_IP=<device ip>
make package install
```

You can also copy the `.deb` to the device and install it with `dpkg -i`.

### Why a custom TLS stack?

`api.mangadex.org` requires TLS 1.3, while the TLS implementation in iOS 6 stops at TLS 1.0 and fails with `NSURLErrorDomain -1200`. `MDHttp` therefore opens a plain socket, performs the handshake with mbedTLS, verifies the server certificate against `Resources/roots.pem`, and speaks HTTP/1.1 itself. Everything else in the app talks to `MDHttp` and never touches `NSURLConnection`.

### Troubleshooting

| Message in the app | Meaning |
|---|---|
| `TLS connect: NET - Failed to get an IP address for the given hostname (-0x0052)` | DNS lookup failed. Check that Safari opens sites on the same network, or try another DNS server (for example 1.1.1.1 or 8.8.8.8) in the Wi-Fi settings. The app retries automatically and prints the number of open file descriptors as `[fds=N]` to help with diagnostics. |
| Certificate verification failed (`-0x2700`) | The device clock is wrong, or `roots.pem` is outdated. Fix the date and time, or download a fresh `roots.pem` and rebuild. |
| Pull-down shows an error instead of the catalog | Pull down again to retry. If it persists, see the DNS note above. |

### Project structure

```
main.m, MDAppDelegate        App entry point and tab bar
MDHttp                       TLS 1.3 + HTTP client on top of mbedTLS
MDApi, MDModels              MangaDex API calls and model objects
MDCatalogViewController      Popular / latest / search
MDMangaViewController        Manga details, chapters, download menu
MDReaderViewController       Page reader
MDLibrary*                   Favorites, history, downloads screen
MDDownloads                  Offline chapter queue and storage
MDImageLoader                Image loading with memory and disk cache
MDSettings*, MDTimePicker*   Preferences UI and storage
MDNightMode, MDTheme, MDUtil Night tint, styling, helpers
Resources/                   Info.plist, icons, launch images, roots.pem
mbedtls/                     mbedTLS sources (not committed, see Building)
```

The code uses ARC and targets `iphone:clang:6.1:6.0` (see `Makefile`).

### Third-party software

- [mbedTLS](https://github.com/Mbed-TLS/mbedtls) 3.6.2 – Apache-2.0 OR GPL-2.0-or-later
- [Mozilla CA certificate bundle](https://curl.se/docs/caextract.html) as published by curl – MPL-2.0

---

## Русский

Неофициальный нативный клиент [MangaDex](https://mangadex.org) для **iOS 6** (устройства с джейлбрейком), написанный на [Theos](https://theos.dev).

Современный MangaDex недоступен из iOS 6 через системный сетевой стек, поэтому MDLegacy содержит собственный TLS 1.3 клиент на базе [mbedTLS](https://github.com/Mbed-TLS/mbedtls). Благодаря этому старые iPhone, iPod и iPad снова можно использовать для чтения манги.

> Интерфейс приложения на русском языке.
> MDLegacy не связан с MangaDex и не одобрен им. Весь контент принадлежит его авторам и группам.

### Возможности

- **Каталог**: популярное и новое, поиск по названию, подгрузка новых страниц при прокрутке, обновление жестом «потянуть вниз».
- **Страница манги**: список глав на выбранном языке, место последнего прочтения, избранное.
- **Ридер**: горизонтальное листание, зум двойным тапом (до 3×), тап скрывает и показывает интерфейс, переход к предыдущей и следующей главе, портретная и альбомная ориентация, продолжение с той страницы, где остановился.
- **Библиотека**: избранное, история чтения и загрузки в одном месте.
- **Чтение офлайн**: можно скачать главу, все главы, только непрочитанные или «эту и все новее»; скачанные главы открываются без сети.
- **Настройки**: экономия трафика (картинки меньшего размера), переключатель контента 18+, язык глав по умолчанию, очистка кэша и истории.
- **Ночной режим**: тёплый оттенок в ридере с регулируемой интенсивностью: выключен, всегда или по расписанию.

### Требования

**На устройстве**
- iOS 6.0 и новее, armv7 (iPhone 3GS и новее, iPad, iPod touch 3-го поколения и новее)
- Джейлбрейк для установки `.deb`
- Правильные дата и время (проверяются даты действия сертификатов)

**На компьютере для сборки**
- [Theos](https://theos.dev/docs/installation) с **iPhoneOS 6.1 SDK** в `$THEOS/sdks`
- `git` и `curl`

### Сборка

Проекту нужны две вещи, которых нет в репозитории: исходники mbedTLS и набор корневых сертификатов. Выполни один раз из корня проекта:

```sh
# исходники mbedTLS 3.6.2 (компилируются прямо в приложение)
git clone --depth 1 -b v3.6.2 https://github.com/Mbed-TLS/mbedtls.git mbedtls
```

Затем собери пакет:

```sh
make clean package
```

Готовый `.deb` появится в `packages/`. Чтобы установить его прямо на устройство по SSH:

```sh
export THEOS_DEVICE_IP=<IP устройства>
make package install
```

Можно также скопировать `.deb` на устройство и установить через `dpkg -i`.

### Зачем собственный TLS?

`api.mangadex.org` требует TLS 1.3, а TLS в iOS 6 заканчивается на TLS 1.0 и падает с ошибкой `NSURLErrorDomain -1200`. Поэтому `MDHttp` открывает обычный сокет, выполняет рукопожатие через mbedTLS, проверяет сертификат сервера по `Resources/roots.pem` и сам говорит по HTTP/1.1. Остальное приложение работает только через `MDHttp` и не использует `NSURLConnection`.

### Частые проблемы

| Сообщение в приложении | Что значит |
|---|---|
| `TLS connect: NET - Failed to get an IP address for the given hostname (-0x0052)` | Не удалось выполнить DNS-запрос. Проверь, открываются ли сайты в Safari в той же сети, или смени DNS-сервер (например, на 1.1.1.1 или 8.8.8.8) в настройках Wi-Fi. Приложение само делает повторные попытки и пишет в ошибке число открытых файловых дескрипторов `[fds=N]` для диагностики. |
| Ошибка проверки сертификата (`-0x2700`) | Неверные дата и время на устройстве или устаревший `roots.pem`. Исправь дату и время либо скачай свежий `roots.pem` и пересобери проект. |
| Вместо каталога сообщение об ошибке | Потяни вниз ещё раз, чтобы повторить. Если не помогает, смотри пункт про DNS выше. |

### Структура проекта

```
main.m, MDAppDelegate        Точка входа и таб-бар
MDHttp                       TLS 1.3 + HTTP клиент поверх mbedTLS
MDApi, MDModels              Запросы к API MangaDex и модели
MDCatalogViewController      Популярное / новое / поиск
MDMangaViewController        Страница манги, главы, меню загрузок
MDReaderViewController       Ридер страниц
MDLibrary*                   Избранное, история, экран загрузок
MDDownloads                  Очередь и хранение офлайн-глав
MDImageLoader                Загрузка картинок, кэш в памяти и на диске
MDSettings*, MDTimePicker*   Экран и хранение настроек
MDNightMode, MDTheme, MDUtil Ночной оттенок, оформление, утилиты
Resources/                   Info.plist, иконки, заставки, roots.pem
mbedtls/                     Исходники mbedTLS (не в репозитории, см. «Сборка»)
```

Код использует ARC и собирается под `iphone:clang:6.1:6.0` (см. `Makefile`).

### Сторонние компоненты

- [mbedTLS](https://github.com/Mbed-TLS/mbedtls) 3.6.2: Apache-2.0 OR GPL-2.0-or-later
- [Набор сертификатов Mozilla](https://curl.se/docs/caextract.html) в версии curl: MPL-2.0
