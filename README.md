# xhttp-reality

نصب Xray با VLESS + XHTTP + REALITY روی سرور شخصی، با یه دستور.
English version: [below](#english)

آموزش ویدیویی (فارسی): کانال یوتیوب [@V7lthronyx](https://www.youtube.com/@V7lthronyx)، اینترنت آزاد فصل ۲: قسمت ۱ (نصب)، قسمت ۲ (پشت کلودفلر)، قسمت ۷ (`audit`)، قسمت ۱۰ (ضدکوانتوم)، و نصب فقط با گوشی.

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

## نصب فقط با گوشی اندروید

کامپیوتر لازم نیست. دکمه‌ی کپی کنار هر دستور رو بزن و توی Termux انگشتت رو نگه دار و Paste رو بزن. آموزش ویدیویی این بخش توی همون کانال یوتیوبه.

۱. [Termux](https://github.com/termux/termux-app/releases/latest) رو از گیت‌هاب یا F-Droid نصب کن، بعد ابزار SSH رو نصب کن:

```bash
pkg install openssh
```

۲. آی‌پی سرور رو از گوشی خودت تست کن و وارد سرور شو (`IP_SERVER` رو عوض کن):

```bash
ping -c 3 IP_SERVER
```

```bash
ssh root@IP_SERVER
```

۳. روی سرور، اول رمز رو عوض کن:

```bash
passwd
```

۴. اسکریپت رو بگیر و چکش کن؛ باید `install.sh: OK` ببینی:

```bash
curl -fsSLO https://github.com/v74all/xhttp-reality/releases/latest/download/install.sh
curl -fsSLO https://github.com/v74all/xhttp-reality/releases/latest/download/install.sh.sha256
sha256sum -c install.sh.sha256
```

۵. یه سایت برای پوشش انتخاب کن (`SITE` رو عوض کن)؛ باید `good` بده:

```bash
bash install.sh check SITE
```

۶. نصب کن:

```bash
bash install.sh --sni SITE --firewall
```

۷. لینک رو بریز توی کلیپ‌بورد گوشی:

```bash
bash install.sh show --copy
```

۸. [v2rayNG](https://github.com/2dust/v2rayNG/releases/latest) رو نصب کن، علامت + رو بزن و Import from Clipboard رو انتخاب کن، بعد دکمه‌ی پایین رو بزن.

کاربر سرورت root نیست؟ اول دستورهای `install.sh` بنویس `sudo`. روی آیفون Termux نیست و این مسیر تست نشده.

## دستورها

| دستور | کار |
|---|---|
| `bash install.sh check DOMAIN` | تست یه دامنه برای REALITY (root لازم نداره) |
| `sudo bash install.sh --sni DOMAIN` | نصب، یا آپدیت اگه قبلاً نصب شده |
| `sudo bash install.sh cdn DOMAIN` | بردن سرور پشت کلودفلر (پایین‌تر توضیح دادم) |
| `sudo bash install.sh cdn --undo` | برگشت به REALITY با همون کلیدهای قبلی |
| `sudo bash install.sh check-cdn DOMAIN` | آیا دامنه به کلودفلر اشاره می‌کنه یا آی‌پی سرورت رو لو میده؟ |
| `sudo bash install.sh show [NAME] [--qr]` | لینک کاربرها، با `--qr` کد QR توی ترمینال |
| `sudo bash install.sh show [NAME] --copy` | لینک رو از راه SSH می‌ریزه توی کلیپ‌بورد گوشی یا کامپیوترت (Termux و بیشتر ترمینال‌ها) |
| `sudo bash install.sh show NAME --json` | کانفیگ JSON کلاینت Xray (SOCKS روی 127.0.0.1:10808) |
| `sudo bash install.sh add NAME` | کاربر جدید با UUID جدا |
| `sudo bash install.sh del NAME` | حذف کاربر (لینکش همون لحظه از کار میفته) |
| `sudo bash install.sh users` | لیست کاربرها |
| `sudo bash install.sh audit` | چک کردن سرور خودت برای چیزهایی که زودتر لوش میدن (فقط می‌خونه، چیزی رو عوض نمی‌کنه) |
| `sudo bash install.sh pq [--mldsa]` | اضافه کردن لایه‌ی ضدکوانتوم به سرور REALITY (پایین‌تر توضیح دادم) |
| `sudo bash install.sh pq --undo` | برگشت به VLESS معمولی؛ لینک‌های قبلی دوباره کار می‌کنن |
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

## پشت کلودفلر (وقتی آی‌پی سرور بسته شد)

اگه آی‌پی سرورت مسدود شد، لازم نیست سرور عوض کنی: سرور رو پشت کلودفلر ببر. فیلترینگ فقط آی‌پی‌های مشترک کلودفلر رو می‌بینه و کلودفلر پشت صحنه به سرورت وصل میشه.

REALITY پشت CDN کار نمی‌کنه، چون کلودفلر TLS رو خودش باز می‌کنه ([Xray-core #1944](https://github.com/XTLS/Xray-core/discussions/1944)). برای همین `cdn` امنیت رو از REALITY به TLS با گواهی Origin کلودفلر عوض می‌کنه و XHTTP رو روی حالت `packet-up` می‌ذاره که با CDNها سازگارترین حالته ([XHTTP: Beyond REALITY](https://github.com/XTLS/Xray-core/discussions/4113)). UUIDها، path و کاربرها عوض نمیشن.

۱. یه دامنه رو به حساب رایگان کلودفلر اضافه کن.
۲. توی DNS یه رکورد `A` بساز، مثلاً `sub.example.com`، به آی‌پی سرورت. ابر نارنجی (Proxied) باید روشن باشه.
۳. توی SSL/TLS حالت رو بذار روی **Full (strict)**.
۴. توی SSL/TLS > Origin Server > Create Certificate یه گواهی بساز. متن Origin Certificate رو توی `origin.pem` و Private key رو توی `origin.key` کنار اسکریپت ذخیره کن.
۵. روی سرور:

```bash
sudo bash install.sh cdn sub.example.com
sudo systemctl restart xray
sudo bash install.sh show
sudo bash install.sh check-cdn sub.example.com
```

خروجی `cdn` این شکلیه:

```
cert      origin.pem, valid for sub.example.com until 2041-10-20
security  reality -> tls
xhttp     mode auto -> packet-up; path and users unchanged
config    /usr/local/etc/xray/config.json, xray -test ok
next      sudo systemctl restart xray
link      sudo bash install.sh show
```

`cdn` فقط کانفیگ رو می‌نویسه و تست می‌کنه. تا وقتی `systemctl restart xray` رو نزنی، لینک‌های REALITY قبلی کار می‌کنن؛ پس اول رکورد DNS و لینک‌های جدید رو آماده کن، بعد ری‌استارت کن.

نکته‌ها:

- پورت سرور باید یکی از پورت‌های HTTPS کلودفلر باشه: 443، 2053، 2083، 2087، 2096 یا 8443 ([مستند کلودفلر](https://developers.cloudflare.com/fundamentals/reference/network-ports/)).
- اگه آی‌پی‌های پیش‌فرض کلودفلر کند یا بسته‌ان، با `--address` یه آی‌پی تمیز کلودفلر رو توی لینک بذار؛ اسم دامنه توی `sni` و `host` می‌مونه.
- `check-cdn` باید `good` بده. اگه آی‌پی سرورت رو توی جواب دید، ابر نارنجی خاموشه. هیچ رکورد دیگه‌ای هم با ابر خاکستری روی آی‌پی سرورت نذار.
- کلودفلر اتصالی رو که ۱۰۰ ثانیه هیچ داده‌ای نفرسته می‌بنده. برای اتصال‌های بی‌کار مثل SSH داخل تونل، keepalive رو روشن کن.
- کلودفلر TLS رو باز می‌کنه و می‌تونه ببینه به چه آدرس‌هایی وصل میشی. محتوای سایت‌های HTTPS همچنان رمز شده می‌مونه.

## لایه‌ی ضدکوانتوم (pq)

ترافیکی که امروز ضبط بشه رو میشه نگه داشت و اگه یه روز کامپیوتر کوانتومی به اندازه‌ی کافی قوی ساخته بشه، تبادل کلیدش رو شکست. به این میگن harvest now, decrypt later. `pq` برای همین خطره: یه لایه‌ی VLESS Encryption با تبادل کلید هیبرید ML-KEM-768 + X25519 داخل تونل اضافه می‌کنه ([Xray-core #5067](https://github.com/XTLS/Xray-core/pull/5067)).

```bash
sudo bash install.sh pq
sudo bash install.sh show               # لینک‌های جدید
sudo bash install.sh show main --json   # برای اپی که لینک بلند نمی‌گیره
```

خروجی `pq` این شکلیه:

```text
[1/4] xray     v26.10.21, vlessenc ok
[2/4] keys     ML-KEM-768 + X25519, ticket 600 s, link part 1610 characters
[3/4] reality  ML-DSA-65 off (--mldsa turns it on)
[4/4] service  xray.service active; every old link stopped working
done. new links: sudo bash install.sh show (apps that can't take a long link: show --json)
```

چیزهایی که باید بدونی:

- سرعت رو بیشتر نمی‌کنه و فیلترینگ امروز رو بهتر رد نمی‌کنه. فقط برای اینه که ترافیک ضبط‌شده بعداً باز نشه.
- همه‌ی لینک‌ها عوض میشن و لینک‌های قبلی همون لحظه از کار میفتن. `add` و نصب دوباره لایه رو نگه می‌دارن.
- لینک بلند میشه: حدود ۱۸۰۰ کاراکتر، و با `--mldsa` حدود ۴۵۰۰ کاراکتر. `show --qr` لینک بالای ۲۹۰۰ کاراکتر رو قبول نمی‌کنه؛ از `show NAME --json` استفاده کن.
- کلاینت باید هسته‌ی جدید Xray داشته باشه (تست‌شده با Xray 26.10.21). خروجی `--json` کانفیگ Xray هست. sing-box تا نسخه‌ی 1.14.4 نه XHTTP داره نه VLESS Encryption، پس به این سرور وصل نمیشه.
- `pq` فقط روی حالت REALITY اجرا میشه. سرور پشت کلودفلر باشه، اول `cdn --undo`.
- اگه خطای `this xray has no vlessenc` گرفتی، `sudo bash install.sh` رو دوباره بزن تا Xray آپدیت بشه؛ کلیدها و لینک‌ها عوض نمیشن.

`--mldsa` امضای ML-DSA-65 رو هم به REALITY اضافه می‌کنه ([Xray-core #4915](https://github.com/XTLS/Xray-core/pull/4915)). این یکی جلوی جعل سرور در آینده رو می‌گیره و برای ترافیکی که قبلاً ضبط شده کاری نمی‌کنه. سایت قرضی باید زنجیره‌ی گواهی بالای ۳۵۰۰ بایت داشته باشه، چون امضا باید داخل اون جا بشه. اسکریپت اندازه رو با `xray tls ping` می‌سنجه و اگه کمتر باشه قبول نمی‌کنه. روی زنجیره‌ی کوچیک با `--force` هم اتصال‌ها reset میشن.

`pq --undo` سرور رو به VLESS معمولی برمی‌گردونه و لینک‌های قبلی دوباره کار می‌کنن.

## چک کردن سرور (audit)

`sudo bash install.sh audit` فقط روی سرور خودت اجرا میشه، چیزی رو عوض نمی‌کنه و برای هر مورد یه خط `ok` یا `warn` میده:

| خط | چی رو چک می‌کنه |
|---|---|
| `sni` یا `cdn` | سایتی که REALITY ازش قرض می‌گیره (TLS 1.3، HTTP/2، فاصله)، یا اینکه دامنه‌ی پشت کلودفلر آی‌پی سرور رو لو نده |
| `ssh` | ورود با رمز یا ورود root روشنه؟ |
| `ports` | پورت‌های دیگه‌ای که روی آی‌پی عمومی بازن (مثلاً پنل)، و فایروال |
| `users` | تعداد لینک‌ها روی یه سرور؛ بیشتر از ۵ تا هشدار میده |
| `cover` | وقتی کسی بدون کلید به سرور سر بزنه چی می‌بینه |
| `backup` | پروتکل دوم (Hysteria2 یا AmneziaWG) کنار Xray هست یا نه |

اگه چیزی `warn` باشه، خروجی دستور ۱ میشه.

## کلاینت‌ها

- اندروید: v2rayNG (دکمه‌ی + و Import config from Clipboard)
- ویندوز، لینوکس، مک: v2rayN (Ctrl+V توی پنجره‌ی اصلی)
- آیفون و اندروید: Hiddify 4.0.5 به بعد (+ و Add from clipboard)

نسخه‌های قدیمی XHTTP رو نمی‌شناسن. اگه نمی‌تونی آپدیت کنی، سرور رو با `--vision` نصب کن.

بعد از `pq` هم اپ باید هسته‌ی جدید Xray داشته باشه.
توی بخش Routing کلاینت، سایت‌ها و آی‌پی‌های ایران رو Direct بذار؛ سرور خودش اون‌ها رو رد می‌کنه.

## چه فایل‌هایی عوض میشه

| مسیر | محتوا |
|---|---|
| `/usr/local/bin/xray` | باینری Xray |
| `/usr/local/share/xray/` | `geoip.dat` و `geosite.dat` |
| `/usr/local/etc/xray/config.json` | کانفیگ سرور (root:xray، 640) |
| `/usr/local/etc/xray/xhttp-reality.env` | پورت، SNI، کلیدها (فقط root) |
| `/usr/local/etc/xray/users` | اسم و UUID کاربرها (فقط root) |
| `/usr/local/etc/xray/cdn.crt`، `cdn.key` | گواهی Origin کلودفلر، فقط بعد از `cdn` (root:xray، 640) |
| `/etc/systemd/system/xray.service` | سرویس |
| `/etc/sysctl.d/90-bbr.conf` | فقط اگه BBR از قبل روشن نبوده |

به‌علاوه‌ی کاربر سیستمی `xray` و قانون‌های ufw (با `--firewall`). `uninstall` همه رو پاک می‌کنه جز قانون‌های ufw.

## مشکلات رایج

- **تایم‌اوت:** پورت جایی بسته‌ست. فایروال پنل ارائه‌دهنده رو چک کن (توی اوراکل: Security List).
- **وصل میشه ولی اینترنت نداره:** `pbk`، `sid` یا `sni` با سرور نمی‌خونه. لینک رو دوباره از `show` بگیر.
- **اپ لینک رو نمی‌شناسه:** اپ رو آپدیت کن یا `--vision`.
- **چند روز کار کرد و بعد قطع شد:** احتمالاً آی‌پی مسدود شده. سرور رو با `cdn` پشت کلودفلر ببر (بالاتر توضیح دادم).
- **پشت کلودفلر وصل نمیشه:** ابر نارنجی روشن باشه، SSL/TLS روی Full (strict) باشه نه Flexible، و `path` لینک با سرور یکی باشه. بعد یه آی‌پی تمیز دیگه با `--address` امتحان کن.
- **بعد از `pq` وصل نمیشه:** لینک‌های قبلی دیگه کار نمی‌کنن؛ لینک رو دوباره از `show` بگیر و اپ رو آپدیت کن.
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

On a phone over SSH, `bash install.sh show --copy` also sends the link to the phone clipboard (OSC 52; tested with Termux and v2rayNG).

What it does:

- checks the REALITY target first (TLS 1.3, HTTP/2, valid certificate, handshake time) and refuses a bad one unless `--force`
- downloads Xray from the official XTLS release and verifies it against the release `.dgst` file; a local `Xray-linux-*.zip` + `.dgst` next to the script is used instead when the server can't reach GitHub
- generates the x25519 key pair, UUID, short id and a random XHTTP path, and tests the config with `xray run -test` before it replaces the old one
- runs Xray as its own `xray` user under a sandboxed systemd unit (`systemd-analyze security xray` scores about 3.6 "OK")
- refuses private/link-local destinations, BitTorrent and Iranian destinations (`geosite:category-ir`, `geoip:ir`, `*.ir`) on the server side
- `--firewall` turns ufw on with only SSH and the Xray port open; on Oracle Cloud Ubuntu images it also opens the port in iptables
- enables BBR when the kernel has it

`sudo bash install.sh audit` (1.2.0) is read-only: one `ok`/`warn` line each for the REALITY target or the CDN name, SSH password/root login, other ports open on the public address plus the firewall, the number of links on the server (more than 5 warns), what an unauthenticated probe gets back, and whether a second transport (Hysteria2 / AmneziaWG) runs next to Xray. It exits 1 when something is worth fixing.

`sudo bash install.sh pq` (1.3.0) adds VLESS Encryption to a running REALITY server: an ML-KEM-768 + X25519 hybrid key exchange inside the tunnel ([Xray-core #5067](https://github.com/XTLS/Xray-core/pull/5067)), against traffic recorded today and decrypted later. It is no faster and gets through filtering no better. Every link changes and the old ones stop working at once; `add` and a reinstall keep the layer. Links grow to about 1800 characters, about 4500 with `--mldsa`, and `show --qr` refuses anything over 2900, so use `show NAME --json`. Clients need a recent Xray core (tested with Xray 26.10.21); sing-box up to 1.14.4 has neither XHTTP nor VLESS Encryption. `--mldsa` also turns on REALITY ML-DSA-65 ([Xray-core #4915](https://github.com/XTLS/Xray-core/pull/4915)), which stops a future impostor server and does nothing for old recordings; it refuses a target whose certificate chain is 3500 bytes or less. `pq --undo` goes back to plain VLESS and the old links work again. `pq` runs on the REALITY mode only, so `cdn --undo` first.

Re-running it updates Xray and keeps keys, users and links. `add NAME` / `del NAME` manage users, `show NAME --qr` prints a QR code, `show NAME --json` prints an Xray client config, `uninstall` removes everything except ufw rules.

Behind Cloudflare, when the server IP gets blocked: REALITY can't work behind a CDN, so `cdn` switches the inbound to TLS with a Cloudflare origin certificate and XHTTP `packet-up` mode, keeping UUIDs, path and users. Add a proxied (orange cloud) `A` record for a subdomain, set SSL/TLS to Full (strict), save the origin certificate and key as `origin.pem` / `origin.key`, then:

```bash
sudo bash install.sh cdn sub.example.com     # writes and tests the config only
sudo systemctl restart xray                  # when the DNS record and the new links are ready
sudo bash install.sh show
sudo bash install.sh check-cdn sub.example.com
```

The port must be a Cloudflare HTTPS port (443, 2053, 2083, 2087, 2096, 8443). `--address IP` puts a clean Cloudflare IP in the links, `cdn --undo` goes back to REALITY with the old keys.

Clients that understand XHTTP: v2rayNG and v2rayN (Xray core), Hiddify 4.0.5+. For older apps install with `--vision`.

License: MIT. Xray-core is MPL-2.0, by [XTLS](https://github.com/XTLS/Xray-core).
