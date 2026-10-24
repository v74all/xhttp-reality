#!/usr/bin/env bash
#
# xhttp-reality - VLESS + XHTTP + REALITY (Xray-core) on your own server
# https://github.com/v74all/xhttp-reality
#
# Read it before you run it. Everything it touches is listed in README.md.

set -euo pipefail
umask 077

VERSION=1.1.0

BIN=/usr/local/bin/xray
ASSETS=/usr/local/share/xray
ETC=/usr/local/etc/xray
CONF=$ETC/config.json
STATE=$ETC/xhttp-reality.env
USERS=$ETC/users
CDN_CERT=$ETC/cdn.crt
CDN_KEY=$ETC/cdn.key
UNIT=/etc/systemd/system/xray.service
REPO=XTLS/Xray-core
# HTTPS ports Cloudflare proxies (developers.cloudflare.com/fundamentals/reference/network-ports/)
CF_PORTS="443 2053 2083 2087 2096 8443"

port=
sni=
transport=
user=main
address=
xray_ver=latest
firewall=0
new_keys=0
force=0
qr=0
json=0
security=reality
domain=
cdn_address=
cert=./origin.pem
key=./origin.key
undo=0

usage() {
	cat <<EOF
xhttp-reality $VERSION

usage: bash install.sh [install] --sni DOMAIN [options]
       bash install.sh check DOMAIN
       bash install.sh cdn DOMAIN [--cert FILE] [--key FILE] [--address IP] | cdn --undo
       bash install.sh check-cdn DOMAIN
       bash install.sh show [NAME] [--qr|--json]
       bash install.sh add NAME | del NAME | users
       bash install.sh uninstall

install options:
  --sni DOMAIN       site REALITY borrows (check it first)
  --port N           listen port (443)
  --vision           VLESS+Vision over raw TCP instead of XHTTP
  --user NAME        first user (main)
  --address IP       address put in links (auto)
  --xray vX.Y.Z      pin a release (latest)
  --firewall         turn ufw on: ssh + this port only
  --new-keys         new keys, short id and path on reinstall
  --force            install even if the sni check fails

cdn (server behind Cloudflare; REALITY can't work behind a CDN, so it switches to TLS):
  DOMAIN             your proxied (orange cloud) name, e.g. sub.example.com
  --cert FILE        origin certificate from Cloudflare (./origin.pem)
  --key FILE         its private key (./origin.key)
  --address IP       put a clean Cloudflare IP in links instead of DOMAIN
  --undo             back to REALITY with the old keys
  it writes and tests the config; restart xray when your DNS record and links are ready
EOF
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
step() { printf '[%s/6] %-8s %s\n' "$1" "$2" "$3"; }
need_root() { [ "$(id -u)" -eq 0 ] || die "run it with sudo"; }
have() { command -v "$1" >/dev/null 2>&1; }

valid_name() { [[ $1 =~ ^[A-Za-z0-9_-]{1,32}$ ]] || die "names may use A-Z a-z 0-9 _ - (max 32): $1"; }

urlenc() {
	local s=$1 out='' c i
	for ((i = 0; i < ${#s}; i++)); do
		c=${s:i:1}
		case $c in
		[a-zA-Z0-9._~-]) out+=$c ;;
		*) printf -v c '%%%02X' "'$c"; out+=$c ;;
		esac
	done
	printf '%s' "$out"
}

# --- sni check --------------------------------------------------------------

# Prints a short report and returns 0 when DOMAIN is fine for REALITY:
# TLS 1.3, HTTP/2 and a certificate that is valid for that exact name.
check_sni() {
	local host=$1 out rc=0 ver code tcp tls ip redir ms
	out=$(curl -sS -o /dev/null --tlsv1.3 --http2 --max-time 8 \
		-w '%{http_version} %{http_code} %{time_connect} %{time_appconnect} %{remote_ip} %{redirect_url}' \
		"https://$host/" 2>&1) || rc=$?
	if [ $rc -ne 0 ]; then
		printf '%s\n' "$host"
		case $rc in
		6) printf '  dns        no address for this name\n' ;;
		7 | 28) printf '  connect    no answer on port 443 from here\n' ;;
		35) printf '  tls 1.3    no (handshake failed with tls 1.3 only)\n' ;;
		60) printf '  cert       not valid for %s\n' "$host" ;;
		*) printf '  curl       %s\n' "${out##*curl: }" ;;
		esac
		printf "  verdict    don't use it\n"
		return 1
	fi
	read -r ver code tcp tls ip redir <<<"$out"
	ms=$(awk -v a="$tcp" -v b="$tls" 'BEGIN { printf "%d", (b - a) * 1000 + 0.5 }')
	printf '%s (%s)\n' "$host" "$ip"
	printf '  tls 1.3    yes\n'
	if [ "$ver" = 2 ]; then printf '  http/2     yes\n'; else printf '  http/2     no\n'; fi
	printf '  cert       valid for %s\n' "$host"
	[ -n "$redir" ] && printf '  redirect   %s -> %s\n' "$code" "$redir"
	printf '  handshake  %s ms\n' "$ms"
	if [ "$ver" != 2 ]; then
		printf "  verdict    don't use it (no http/2)\n"
		return 1
	fi
	# the decoy should sit close to the server, so its handshake looks like ours
	if [ "$ms" -gt 80 ]; then
		printf '  verdict    usable, but far from this server\n'
	else
		printf '  verdict    good\n'
	fi
}

# --- helpers ----------------------------------------------------------------

arch_suffix() {
	case $(uname -m) in
	x86_64 | amd64) echo 64 ;;
	aarch64 | arm64) echo arm64-v8a ;;
	*) die "unsupported cpu: $(uname -m)" ;;
	esac
}

public_ip() {
	local ip
	# a public address on an interface (most VPS) ...
	ip=$(ip -4 -o addr show scope global 2>/dev/null | awk '{ split($4, a, "/"); print a[1] }' |
		grep -Ev '^(10\.|127\.|169\.254\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.)' | head -n1)
	# ... or ask, when the box sits behind 1:1 NAT (Oracle, AWS, GCP)
	if [ -z "$ip" ]; then
		for u in https://api.ipify.org https://ipv4.icanhazip.com https://ifconfig.me/ip; do
			ip=$(curl -4 -fsS --max-time 5 "$u" 2>/dev/null | tr -d '[:space:]') && [ -n "$ip" ] && break
		done
	fi
	[ -n "$ip" ] || die "can't find the public address, pass --address"
	echo "$ip"
}

ssh_ports() {
	ss -tlnpH 2>/dev/null | awk '/"sshd"/ { n = split($4, a, ":"); print a[n] }' | sort -u
}

load_state() {
	[ -f "$STATE" ] || die "not installed yet"
	# shellcheck disable=SC1090
	. "$STATE"
	# state files from 1.0.0 have no cdn lines
	SECURITY=${SECURITY:-reality} DOMAIN=${DOMAIN:-} CDN_ADDRESS=${CDN_ADDRESS:-}
}

# the lowercase variables write_config and save_state use, from the saved state
use_state() {
	# shellcheck disable=SC2153 # PORT, TRANSPORT, ADDRESS come from the state file
	port=$PORT sni=$SNI transport=$TRANSPORT address=$ADDRESS priv=$PRIVATE_KEY pub=$PUBLIC_KEY
	sid=$SHORT_ID xpath=$XHTTP_PATH security=$SECURITY domain=$DOMAIN cdn_address=$CDN_ADDRESS
}

save_state() {
	cat >"$STATE" <<EOF
PORT=$port
SNI=$sni
TRANSPORT=$transport
ADDRESS=$address
PRIVATE_KEY=$priv
PUBLIC_KEY=$pub
SHORT_ID=$sid
XHTTP_PATH=$xpath
SECURITY=$security
DOMAIN=$domain
CDN_ADDRESS=$cdn_address
EOF
	chmod 600 "$STATE"
}

# --- xray binary ------------------------------------------------------------

# Uses Xray-linux-*.zip (+ .dgst) from the current directory when it is there
# (servers that can't reach GitHub), otherwise downloads the release.
install_xray() {
	local a zip want got src tmp
	a=$(arch_suffix)
	zip=Xray-linux-$a.zip
	tmp=$(mktemp -d)
	TMPD=$tmp
	trap 'rm -rf "$TMPD"' EXIT
	if [ -f "./$zip" ]; then
		[ -f "./$zip.dgst" ] || die "found ./$zip but not ./$zip.dgst next to it"
		cp "./$zip" "./$zip.dgst" "$tmp/"
		src="local $zip"
	else
		if [ "$xray_ver" = latest ]; then
			xray_ver=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$REPO/releases/latest")
			xray_ver=${xray_ver##*/}
			[[ $xray_ver == v* ]] || die "can't read the latest Xray release from GitHub"
		fi
		curl -fsSL --retry 2 -o "$tmp/$zip" "https://github.com/$REPO/releases/download/$xray_ver/$zip" ||
			die "download failed: $xray_ver/$zip"
		curl -fsSL --retry 2 -o "$tmp/$zip.dgst" "https://github.com/$REPO/releases/download/$xray_ver/$zip.dgst" ||
			die "download failed: $xray_ver/$zip.dgst"
		src="github $zip"
	fi
	want=$(awk -F'= ' '/^SHA2-256=/ { print $2 }' "$tmp/$zip.dgst")
	got=$(sha256sum "$tmp/$zip" | cut -d' ' -f1)
	[ -n "$want" ] && [ "$want" = "$got" ] || die "sha256 mismatch for $zip, not installing it"
	unzip -qo "$tmp/$zip" xray geoip.dat geosite.dat -d "$tmp/x"
	install -m 755 "$tmp/x/xray" "$BIN"
	install -d -m 755 "$ASSETS"
	install -m 644 "$tmp/x/geoip.dat" "$tmp/x/geosite.dat" "$ASSETS/"
	step 3 xray "$("$BIN" version | awk 'NR == 1 { print "v" $2 }'), $src, sha256 ok"
}

# --- config -----------------------------------------------------------------

clients_json() {
	local flow=
	[ "$transport" = vision ] && flow=xtls-rprx-vision
	awk -v flow="$flow" '
		NF == 2 {
			printf "%s          { \"id\": \"%s\", \"email\": \"%s\"%s }", (n++ ? ",\n" : ""), $2, $1,
				(flow != "" ? ", \"flow\": \"" flow "\"" : "")
		}' "$USERS"
}

write_config() {
	local stream tag=reality-in
	if [ "$transport" = vision ]; then
		stream='"network": "raw",'
	elif [ "$security" = tls ]; then
		stream="\"network\": \"xhttp\",
        \"xhttpSettings\": { \"path\": \"$xpath\", \"mode\": \"packet-up\" },"
	else
		stream="\"network\": \"xhttp\",
        \"xhttpSettings\": { \"path\": \"$xpath\" },"
	fi
	if [ "$security" = tls ]; then
		tag=cdn-in
		stream+="
        \"security\": \"tls\",
        \"tlsSettings\": {
          \"alpn\": [\"h2\", \"http/1.1\"],
          \"certificates\": [{ \"certificateFile\": \"$CDN_CERT\", \"keyFile\": \"$CDN_KEY\" }]
        }"
	else
		stream+="
        \"security\": \"reality\",
        \"realitySettings\": {
          \"target\": \"$sni:443\",
          \"serverNames\": [\"$sni\"],
          \"privateKey\": \"$priv\",
          \"shortIds\": [\"$sid\"]
        }"
	fi
	cat >"$ETC/config.new.json" <<EOF
{
  "log": { "loglevel": "warning", "access": "none" },
  "inbounds": [
    {
      "tag": "$tag",
      "port": $port,
      "protocol": "vless",
      "settings": {
        "clients": [
$(clients_json)
        ],
        "decryption": "none"
      },
      "streamSettings": {
        $stream
      },
      "sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"], "routeOnly": true }
    }
  ],
  "outbounds": [
    { "tag": "direct", "protocol": "freedom" },
    { "tag": "block", "protocol": "blackhole" }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      { "ip": ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "100.64.0.0/10", "127.0.0.0/8",
               "169.254.0.0/16", "0.0.0.0/8", "fc00::/7", "fe80::/10", "::1/128"], "outboundTag": "block" },
      { "protocol": ["bittorrent"], "outboundTag": "block" },
      { "domain": ["geosite:category-ir", "regexp:\\\\.ir\$"], "outboundTag": "block" },
      { "ip": ["geoip:ir"], "outboundTag": "block" }
    ]
  }
}
EOF
	XRAY_LOCATION_ASSET=$ASSETS "$BIN" run -test -config "$ETC/config.new.json" >/dev/null 2>&1 || {
		XRAY_LOCATION_ASSET=$ASSETS "$BIN" run -test -config "$ETC/config.new.json" >&2 || true
		die "xray rejected the new config, see above"
	}
	chown root:xray "$ETC/config.new.json"
	chmod 640 "$ETC/config.new.json"
	mv "$ETC/config.new.json" "$CONF"
}

write_unit() {
	cat >"$UNIT" <<EOF
[Unit]
Description=Xray (xhttp-reality)
Documentation=https://github.com/v74all/xhttp-reality
After=network-online.target
Wants=network-online.target

[Service]
User=xray
Group=xray
Environment=XRAY_LOCATION_ASSET=$ASSETS
ExecStart=$BIN run -config $CONF
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictNamespaces=true
RestrictSUIDSGID=true
LockPersonality=true
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX AF_NETLINK
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
EOF
	chmod 644 "$UNIT"
}

restart_xray() {
	systemctl daemon-reload
	systemctl enable xray >/dev/null 2>&1
	systemctl restart xray
	sleep 1
	systemctl is-active --quiet xray || {
		journalctl -u xray -n 20 --no-pager >&2 || true
		die "xray did not start"
	}
}

# --- network ----------------------------------------------------------------

setup_network() {
	local fw bbr p
	if have ufw && ufw status 2>/dev/null | grep -q '^Status: active'; then
		ufw allow "$port/tcp" >/dev/null
		fw="ufw: $port/tcp allowed"
	elif [ $firewall -eq 1 ]; then
		have ufw || { apt-get install -y -qq ufw >/dev/null 2>&1 || die "can't install ufw"; }
		ufw default deny incoming >/dev/null
		ufw default allow outgoing >/dev/null
		for p in $(ssh_ports) 22; do ufw allow "$p/tcp" >/dev/null; done
		ufw allow "$port/tcp" >/dev/null
		ufw --force enable >/dev/null
		fw="ufw on: ssh + $port/tcp, rest closed"
	else
		fw="ufw off (--firewall turns it on)"
	fi
	# Oracle's Ubuntu images ship an iptables REJECT at the end of INPUT
	if have iptables && iptables -S INPUT 2>/dev/null | grep -q 'icmp-host-prohibited'; then
		iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null ||
			iptables -I INPUT 1 -p tcp --dport "$port" -j ACCEPT
		have netfilter-persistent && netfilter-persistent save >/dev/null 2>&1 || true
		fw="$fw, iptables $port/tcp open"
	fi
	local cc=/proc/sys/net/ipv4/tcp_congestion_control
	if [ "$(cat $cc 2>/dev/null)" = bbr ]; then
		bbr="bbr on"
	elif modprobe tcp_bbr 2>/dev/null || grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
		printf 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr\n' >/etc/sysctl.d/90-bbr.conf
		chmod 644 /etc/sysctl.d/90-bbr.conf
		{ echo fq >/proc/sys/net/core/default_qdisc; } 2>/dev/null || true
		{ echo bbr >$cc; } 2>/dev/null || true
		if [ "$(cat $cc)" = bbr ]; then bbr="bbr on"; else bbr="bbr after reboot"; fi
	else
		bbr="no bbr in this kernel"
	fi
	step 6 network "$fw; $bbr"
}

# --- commands ---------------------------------------------------------------

cmd_install() {
	need_root
	have systemctl && [ -d /run/systemd/system ] || die "this needs a systemd server"
	valid_name "$user"

	local reinstall=0
	if [ -f "$STATE" ]; then
		reinstall=1
		load_state
		port=${port:-$PORT} sni=${sni:-$SNI} transport=${transport:-$TRANSPORT} address=${address:-$ADDRESS}
		priv=$PRIVATE_KEY pub=$PUBLIC_KEY sid=$SHORT_ID xpath=$XHTTP_PATH
		# install always means REALITY; the cdn name stays saved for a later "cdn"
		domain=$DOMAIN cdn_address=$CDN_ADDRESS
	fi
	port=${port:-443} transport=${transport:-xhttp}
	[ -n "$sni" ] || die "--sni is required (pick one with: bash install.sh check DOMAIN)"
	[[ $port =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || die "bad port: $port"

	local os missing=() p
	# shellcheck source=/dev/null
	os=$(. /etc/os-release 2>/dev/null && echo "$ID $VERSION_ID") || os=linux
	for p in curl unzip openssl qrencode; do have $p || missing+=("$p"); done
	if [ ${#missing[@]} -gt 0 ]; then
		have apt-get || die "install these first: ${missing[*]}"
		{ apt-get update -qq && apt-get install -y -qq "${missing[@]}" ca-certificates; } >/dev/null 2>&1 ||
			die "apt-get install ${missing[*]} failed"
	fi
	step 1 system "$os, $(uname -m), systemd"

	if ss -tlnpH "sport = :$port" 2>/dev/null | grep -v '"xray"' | grep -q .; then
		die "port $port is already used by: $(ss -tlnpH "sport = :$port" | grep -o 'users:(("[^"]*' | cut -d'"' -f2 | head -n1)"
	fi

	local report
	if report=$(check_sni "$sni"); then
		step 2 sni "$sni: tls1.3 h2, $(awk '/handshake/ { print $2, $3 }' <<<"$report")"
	elif [ $force -eq 1 ]; then
		step 2 sni "$sni: check failed, --force"
	else
		printf '%s\n' "$report" >&2
		die "$sni is not a good REALITY target (or use --force)"
	fi

	install_xray

	id -u xray >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin xray
	install -d -m 750 -o root -g xray "$ETC"
	if [ $reinstall -eq 0 ] || [ $new_keys -eq 1 ]; then
		local keys
		keys=$("$BIN" x25519)
		priv=$(awk -F': *' '/^Private/ { print $2 }' <<<"$keys")
		pub=$(awk -F': *' '/^Password|^Public/ { print $2 }' <<<"$keys")
		sid=$(openssl rand -hex 8)
		xpath=/$(openssl rand -hex 6)
		[ -n "$priv" ] && [ -n "$pub" ] || die "can't parse: xray x25519"
	fi
	[ -s "$USERS" ] || printf '%s %s\n' "$user" "$("$BIN" uuid)" >"$USERS"
	chmod 600 "$USERS"
	[ -n "$address" ] || address=$(public_ip)
	save_state
	write_config
	step 4 config "$CONF, xray -test ok"

	write_unit
	restart_xray
	step 5 service "xray.service active, runs as user xray"

	setup_network
	echo "done. your link: sudo bash install.sh show"
}

link_for() {
	local name=$1 id=$2 q addr=$ADDRESS
	if [ "$SECURITY" = tls ]; then
		addr=${CDN_ADDRESS:-$DOMAIN}
		q="encryption=none&security=tls&sni=$DOMAIN&fp=chrome&type=xhttp&host=$DOMAIN"
		q+="&path=$(urlenc "$XHTTP_PATH")&mode=packet-up"
	else
		q="encryption=none&security=reality&sni=$SNI&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID"
		if [ "$TRANSPORT" = vision ]; then
			q+="&type=tcp&flow=xtls-rprx-vision"
		else
			q+="&type=xhttp&path=$(urlenc "$XHTTP_PATH")&mode=auto"
		fi
	fi
	printf 'vless://%s@%s:%s?%s#%s\n' "$id" "$addr" "$PORT" "$q" "$(urlenc "$name")"
}

client_json() {
	local id=$1 stream flow='' addr=$ADDRESS sec
	if [ "$TRANSPORT" = vision ]; then
		stream='"network": "raw",'
		flow=', "flow": "xtls-rprx-vision"'
	elif [ "$SECURITY" = tls ]; then
		stream="\"network\": \"xhttp\", \"xhttpSettings\": { \"path\": \"$XHTTP_PATH\", \"mode\": \"packet-up\", \"host\": \"$DOMAIN\" },"
	else
		stream="\"network\": \"xhttp\", \"xhttpSettings\": { \"path\": \"$XHTTP_PATH\", \"mode\": \"auto\" },"
	fi
	if [ "$SECURITY" = tls ]; then
		addr=${CDN_ADDRESS:-$DOMAIN}
		sec="\"security\": \"tls\",
      \"tlsSettings\": { \"serverName\": \"$DOMAIN\", \"fingerprint\": \"chrome\" }"
	else
		sec="\"security\": \"reality\",
      \"realitySettings\": { \"serverName\": \"$SNI\", \"fingerprint\": \"chrome\",
        \"password\": \"$PUBLIC_KEY\", \"shortId\": \"$SHORT_ID\" }"
	fi
	cat <<EOF
{
  "log": { "loglevel": "warning" },
  "inbounds": [{ "listen": "127.0.0.1", "port": 10808, "protocol": "socks", "settings": { "udp": true } }],
  "outbounds": [{
    "protocol": "vless",
    "settings": { "vnext": [{ "address": "$addr", "port": $PORT,
      "users": [{ "id": "$id", "encryption": "none"$flow }] }] },
    "streamSettings": {
      $stream
      $sec
    }
  }]
}
EOF
}

cmd_show() {
	need_root
	load_state
	local name=${1:-} n id found=0
	while read -r n id; do
		[ -z "$name" ] || [ "$n" = "$name" ] || continue
		found=1
		if [ $json -eq 1 ]; then
			client_json "$id"
			return
		fi
		[ -z "$name" ] && printf '%s\n' "$n"
		link_for "$n" "$id"
		if [ $qr -eq 1 ]; then
			have qrencode || die "qrencode is not installed"
			link_for "$n" "$id" | qrencode -t ANSIUTF8 -m 1
		fi
	done <"$USERS"
	[ $found -eq 1 ] || die "no user named $name"
}

cmd_add() {
	need_root
	load_state
	local name=${1:-}
	[ -n "$name" ] || die "usage: install.sh add NAME"
	valid_name "$name"
	grep -q "^$name " "$USERS" && die "$name already exists"
	printf '%s %s\n' "$name" "$("$BIN" uuid)" >>"$USERS"
	use_state
	write_config
	restart_xray
	link_for "$name" "$(awk -v n="$name" '$1 == n { print $2 }' "$USERS")"
}

cmd_del() {
	need_root
	load_state
	local name=${1:-}
	[ -n "$name" ] || die "usage: install.sh del NAME"
	grep -q "^$name " "$USERS" || die "no user named $name"
	[ "$(grep -c . "$USERS")" -gt 1 ] || die "$name is the last user; uninstall instead"
	sed -i "/^$name /d" "$USERS"
	use_state
	write_config
	restart_xray
	echo "removed $name (its link stops working now)"
}

# Moves the server behind Cloudflare. REALITY can't survive a CDN (the CDN ends TLS itself),
# so the inbound switches to TLS with Cloudflare's origin certificate; XHTTP stays, in packet-up
# mode. It only writes and tests the config: restart when the DNS record and links are ready.
cmd_cdn() {
	need_root
	local flag_addr=$address
	load_state
	use_state
	local name=${1,,} old=$security end
	[ "$transport" = xhttp ] || die "a CDN can't carry raw TCP (Vision); reinstall without --vision first"
	if [ $undo -eq 1 ]; then
		[ "$old" = tls ] || die "already on REALITY"
		security=reality
		write_config
		save_state
		printf 'security  tls -> reality (sni %s, same keys)\n' "$sni"
		printf 'next      sudo systemctl restart xray\n'
		printf 'link      sudo bash install.sh show\n'
		return
	fi
	[ -n "$name" ] || die "usage: install.sh cdn DOMAIN (your orange-cloud name)"
	[[ $name =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ ]] || die "not a domain name: $name"
	[[ " $CF_PORTS " == *" $port "* ]] || [ $force -eq 1 ] ||
		die "Cloudflare doesn't proxy port $port; reinstall with --port 443 (or: $CF_PORTS), or use --force"
	[ -z "$flag_addr" ] || [[ $flag_addr =~ ^[A-Za-z0-9.:-]+$ ]] || die "bad --address: $flag_addr"
	[ -f "$cert" ] || die "no certificate at $cert (Cloudflare: SSL/TLS > Origin Server > Create Certificate)"
	[ -f "$key" ] || die "no private key at $key"
	openssl x509 -in "$cert" -noout 2>/dev/null || die "$cert is not a PEM certificate"
	[ "$(openssl x509 -in "$cert" -noout -pubkey 2>/dev/null)" = "$(openssl pkey -in "$key" -pubout 2>/dev/null)" ] ||
		die "$key is not the private key of $cert"
	openssl x509 -in "$cert" -noout -checkhost "$name" 2>/dev/null | grep -q 'does match' ||
		die "$cert is not valid for $name"
	openssl x509 -in "$cert" -noout -checkend 86400 >/dev/null || die "$cert has expired"
	end=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
	end=$(date -u -d "$end" +%F 2>/dev/null || echo "$end")

	install -m 640 -o root -g xray "$cert" "$CDN_CERT"
	install -m 640 -o root -g xray "$key" "$CDN_KEY"
	security=tls domain=$name cdn_address=$flag_addr
	write_config
	save_state
	printf 'cert      %s, valid for %s until %s\n' "${cert##*/}" "$name" "$end"
	if [ "$old" = tls ]; then
		printf 'security  tls (already), certificate replaced\n'
	else
		printf 'security  reality -> tls\n'
		printf 'xhttp     mode auto -> packet-up; path and users unchanged\n'
	fi
	printf 'config    %s, xray -test ok\n' "$CONF"
	printf 'next      sudo systemctl restart xray\n'
	printf 'link      sudo bash install.sh show\n'
}

# A proxied (orange cloud) record answers with Cloudflare's addresses; a DNS only (grey) one
# answers with the server's own address, which is the one thing a block list needs.
check_cdn() {
	local name=$1 ips me
	ips=$(getent ahosts "$name" 2>/dev/null | awk '{ print $1 }' | sort -u | tr '\n' ' ') || true
	printf '%s\n' "$name"
	if [ -z "$ips" ]; then
		printf '  dns        no address for this name yet\n'
		printf '  verdict    add the record (proxied) and try again\n'
		return 1
	fi
	printf '  resolves   %s\n' "${ips% }"
	if [ -r "$STATE" ]; then
		load_state
		me=$ADDRESS
	else
		me=$(public_ip)
	fi
	if [[ " $ips" == *" $me "* ]]; then
		printf '  server     %s (in the answer)\n' "$me"
		printf '  verdict    DNS only (grey cloud): this name shows your server address\n'
		return 1
	fi
	printf '  server     %s (not in the answer)\n' "$me"
	printf '  verdict    good, the name points at the CDN\n'
}

cmd_uninstall() {
	need_root
	systemctl disable --now xray >/dev/null 2>&1 || true
	rm -f "$UNIT" "$BIN" /etc/sysctl.d/90-bbr.conf
	rm -rf "$ETC" "$ASSETS"
	systemctl daemon-reload
	id -u xray >/dev/null 2>&1 && userdel xray
	echo "removed xray, its config and the xray user (ufw rules stay as they are)"
}

# --- main -------------------------------------------------------------------

cmd=install
case ${1:-} in
install | check | cdn | check-cdn | show | add | del | users | uninstall) cmd=$1; shift ;;
esac
args=()
while [ $# -gt 0 ]; do
	case $1 in
	--sni) sni=${2:?--sni needs a domain}; shift ;;
	--port) port=${2:?}; shift ;;
	--vision) transport=vision ;;
	--user) user=${2:?}; shift ;;
	--address) address=${2:?}; shift ;;
	--xray) xray_ver=${2:?}; shift ;;
	--firewall) firewall=1 ;;
	--new-keys) new_keys=1 ;;
	--force) force=1 ;;
	--qr) qr=1 ;;
	--json) json=1 ;;
	--cert) cert=${2:?--cert needs a file}; shift ;;
	--key) key=${2:?--key needs a file}; shift ;;
	--undo) undo=1 ;;
	-h | --help) usage; exit 0 ;;
	--version) echo "$VERSION"; exit 0 ;;
	-*) die "unknown option: $1 (see --help)" ;;
	*) args+=("$1") ;;
	esac
	shift
done
sni=${sni,,}

case $cmd in
install) cmd_install ;;
check) [ -n "${args[0]:-}" ] || die "usage: install.sh check DOMAIN"; check_sni "${args[0],,}" ;;
cdn) cmd_cdn "${args[0]:-}" ;;
check-cdn) [ -n "${args[0]:-}" ] || die "usage: install.sh check-cdn DOMAIN"; check_cdn "${args[0],,}" ;;
show) cmd_show "${args[0]:-}" ;;
add) cmd_add "${args[0]:-}" ;;
del) cmd_del "${args[0]:-}" ;;
users) need_root; load_state; awk '{ print $1 }' "$USERS" ;;
uninstall) cmd_uninstall ;;
esac
