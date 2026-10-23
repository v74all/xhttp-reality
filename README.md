# xhttp-reality

نصب Xray با VLESS + XHTTP + REALITY روی سرور شخصی، با یه دستور.
English version: [below](#english)

آموزش ویدیویی (فارسی): کانال یوتیوب [@V7lthronyx](https://www.youtube.com/@V7lthronyx)، اینترنت آزاد فصل ۲، قسمت ۱.

## چی کار می‌کنه

- قبل از هر تغییری، سایتی رو که برای REALITY انتخاب کردی تست می‌کنه: TLS 1.3، HTTP/2، گواهی معتبر، زمان هندشیک.
- آخرین نسخه‌ی Xray رو از گیت‌هاب خود XTLS می‌گیره و هش SHA-256 اون رو با فایل `.dgst` رسمی چک می‌کنه. اگه سرورت به گیت‌هاب دسترسی نداره، `Xray-linux-64.zip` و `.dgst` رو کنار اسکریپت بذار.
- کلید x25519، UUID، short id و path تصادفی می‌سازه و کانفیگ رو قبل از اعمال با `xray run -test` چک می‌کنه.
- سرویس با کاربر جدای `xray` اجرا میشه، نه root، با محدودیت‌های systemd (`ProtectSystem=strict`، `NoNewPrivileges` و ...).
- سرور به آدرس‌های داخلی (مثل `169.254.169.254`)، تورنت و سایت‌های ایرانی (`geosite:category-ir`، `geoip:ir`، `*.ir`) وصل نمیشه.
- با `--firewall`، ufw رو روشن می‌کنه و فقط پورت SSH و پورت Xray باز می‌مونه. روی ایمیج‌های اوبونتوی اوراکل، قانون iptables پورت رو هم اضافه می‌کنه.
- BBR رو اگه کرنل داشته باشه روشن می‌کنه.

## پیش‌نیاز

- سرور خارج از ایران با Ubuntu 22.04 / 24.04 یا Debian 12 (x86_64 یا arm64) و systemd
- دسترسی root یا sudo
- یه دامنه‌ی خارجی برای REALITY که TLS 1.3 و HTTP/2 داشته باشه (پایین‌تر توضیح دادم)

## نصب

```bash
curl -fsSLO https://github.com/v74all/xhttp-reality/releases/latest/download/install.sh
curl -fsSLO https://github.com/v74all/xhttp-reality/releases/latest/download/install.sh.sha256
sha256sum -c install.sh.sha256

bash install.sh check www.example.com      # اول SNI رو تست کن
sudo bash install.sh --sni www.example.com --firewall
sudo bash install.sh show                  # لینک vless://
```

اسکریپت رو با `curl | bash` اجرا نکن. دانلود کن، هشش رو چک کن، یه نگاه بهش بنداز، بعد اجرا کن. یه فایل bash ساده‌ست، بدون هیچ وابستگی عجیبی.

خروجی نصب این شکلیه:

```
[1/6] system   ubuntu 24.04, x86_64, systemd
[2/6] sni      www.example.com: tls1.3 h2, 4 ms
[3/6] xray     v26.10.21, github Xray-linux-64.zip, sha256 ok
[4/6] config   /usr/local/etc/xray/config.json, xray -test ok
[5/6] service  xray.service active, runs as user xray
[6/6] network  ufw on: ssh + 443/tcp, rest closed; bbr on
done. your link: sudo bash install.sh show
```

## دستورها

| دستور | کار |
|---|---|
| `bash install.sh check DOMAIN` | تست یه دامنه برای REALITY (root لازم نداره) |
| `sudo bash install.sh --sni DOMAIN` | نصب، یا آپدیت اگه قبلاً نصب شده |
| `sudo bash install.sh show [NAME] [--qr]` | لینک کاربرها، با `--qr` کد QR توی ترمینال |
| `sudo bash install.sh show NAME --json` | کانفیگ JSON کلاینت Xray (SOCKS روی 127.0.0.1:10808) |
| `sudo bash install.sh add NAME` | کاربر جدید با UUID جدا |
| `sudo bash install.sh del NAME` | حذف کاربر (لینکش همون لحظه از کار میفته) |
| `sudo bash install.sh users` | لیست کاربرها |
| `sudo bash install.sh uninstall` | حذف کامل |

گزینه‌های نصب:

| گزینه | پیش‌فرض | توضیح |
|---|---|---|
| `--sni DOMAIN` | - | سایتی که REALITY ازش تقلید می‌کنه |
| `--port N` | 443 | پورت. پورت غیر از ۴۴۳ شانس شناسایی رو بیشتر می‌کنه |
| `--vision` | خاموش | به جای XHTTP، VLESS + Vision روی TCP (برای اپ‌های قدیمی‌تر) |
| `--user NAME` | main | اسم کاربر اول |
| `--address IP` | خودکار | آدرسی که توی لینک میاد |
| `--xray vX.Y.Z` | latest | نسخه‌ی مشخص Xray |
| `--firewall` | خاموش | روشن کردن ufw: فقط SSH و همین پورت |
| `--new-keys` | خاموش | موقع نصب دوباره، کلید و short id و path جدید بساز |
| `--force` | خاموش | نصب حتی اگه تست SNI رد بشه |

اجرای دوباره‌ی `install.sh` (بدون `--new-keys`) فقط Xray رو آپدیت می‌کنه؛ کلیدها، کاربرها و لینک‌ها عوض نمیشن. برای عوض کردن SNI کافیه دوباره با `--sni` جدید اجراش کنی.

## انتخاب SNI

شرط‌ها: TLS 1.3، HTTP/2، گواهی معتبر برای همون اسم، و ترجیحاً نزدیک سرورت (همون کشور یا همون دیتاسنتر). دستور `check` سه شرط اول رو تست می‌کنه و زمان هندشیک رو هم نشون میده؛ هرچی کمتر، نزدیک‌تر. بالای ۸۰ میلی‌ثانیه رو «usable, but far» نشون میده.

برای پیدا کردن کاندید نزدیک، ابزار رسمی XTLS هست: [RealiTLScanner](https://github.com/XTLS/RealiTLScanner). فقط آروم و روی رنج آی‌پی خود سرورت اجراش کن.

## کلاینت‌ها

- اندروید: v2rayNG (دکمه‌ی + و Import config from Clipboard)
- ویندوز، لینوکس، مک: v2rayN (Ctrl+V توی پنجره‌ی اصلی)
- آیفون و اندروید: Hiddify 4.0.5 به بعد (+ و Add from clipboard)

نسخه‌های قدیمی XHTTP رو نمی‌شناسن. اگه نمی‌تونی آپدیت کنی، سرور رو با `--vision` نصب کن.
توی بخش Routing کلاینت، سایت‌ها و آی‌پی‌های ایران رو Direct بذار؛ سرور خودش اون‌ها رو رد می‌کنه.

## چه فایل‌هایی عوض میشه

| مسیر | محتوا |
|---|---|
| `/usr/local/bin/xray` | باینری Xray |
| `/usr/local/share/xray/` | `geoip.dat` و `geosite.dat` |
| `/usr/local/etc/xray/config.json` | کانفیگ سرور (root:xray، 640) |
| `/usr/local/etc/xray/xhttp-reality.env` | پورت، SNI، کلیدها (فقط root) |
| `/usr/local/etc/xray/users` | اسم و UUID کاربرها (فقط root) |
| `/etc/systemd/system/xray.service` | سرویس |
| `/etc/sysctl.d/90-bbr.conf` | فقط اگه BBR از قبل روشن نبوده |

به‌علاوه‌ی کاربر سیستمی `xray` و قانون‌های ufw (با `--firewall`). `uninstall` همه رو پاک می‌کنه جز قانون‌های ufw.

## مشکلات رایج

- **تایم‌اوت:** پورت جایی بسته‌ست. فایروال پنل ارائه‌دهنده رو چک کن (توی اوراکل: Security List).
- **وصل میشه ولی اینترنت نداره:** `pbk`، `sid` یا `sni` با سرور نمی‌خونه. لینک رو دوباره از `show` بگیر.
- **اپ لینک رو نمی‌شناسه:** اپ رو آپدیت کن یا `--vision`.
- **چند روز کار کرد و بعد قطع شد:** احتمالاً آی‌پی مسدود شده. آی‌پی جدید و SNI دیگه، یا قسمت بعدی آموزش (XHTTP پشت CDN).
- **`xray did not start`:** خروجی `journalctl -u xray -n 50` رو ببین.

## مجوز

MIT. Xray-core مال پروژه‌ی [XTLS](https://github.com/XTLS/Xray-core) با مجوز MPL-2.0 است و این اسکریپت فقط نصبش می‌کنه.

---

## English

One-command install of Xray (VLESS + XHTTP + REALITY) on your own Ubuntu/Debian server.

```bash
curl -fsSLO https://github.com/v74all/xhttp-reality/releases/latest/download/install.sh
curl -fsSLO https://github.com/v74all/xhttp-reality/releases/latest/download/install.sh.sha256
sha256sum -c install.sh.sha256
bash install.sh check www.example.com
sudo bash install.sh --sni www.example.com --firewall
sudo bash install.sh show
```

What it does:

- checks the REALITY target first (TLS 1.3, HTTP/2, valid certificate, handshake time) and refuses a bad one unless `--force`
- downloads Xray from the official XTLS release and verifies it against the release `.dgst` file; a local `Xray-linux-*.zip` + `.dgst` next to the script is used instead when the server can't reach GitHub
- generates the x25519 key pair, UUID, short id and a random XHTTP path, and tests the config with `xray run -test` before it replaces the old one
- runs Xray as its own `xray` user under a sandboxed systemd unit (`systemd-analyze security xray` scores about 3.6 "OK")
- refuses private/link-local destinations, BitTorrent and Iranian destinations (`geosite:category-ir`, `geoip:ir`, `*.ir`) on the server side
- `--firewall` turns ufw on with only SSH and the Xray port open; on Oracle Cloud Ubuntu images it also opens the port in iptables
- enables BBR when the kernel has it

Re-running it updates Xray and keeps keys, users and links. `add NAME` / `del NAME` manage users, `show NAME --qr` prints a QR code, `show NAME --json` prints an Xray client config, `uninstall` removes everything except ufw rules.

Clients that understand XHTTP: v2rayNG and v2rayN (Xray core), Hiddify 4.0.5+. For older apps install with `--vision`.

License: MIT. Xray-core is MPL-2.0, by [XTLS](https://github.com/XTLS/Xray-core).
