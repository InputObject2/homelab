#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Pinned versions - tested combination: timspb/chan-sccp@7e05ccd + Asterisk 22 + FreePBX 17
# chan-sccp upstream is effectively unmaintained (last merge 2022); timspb fork includes
# payload_mapping_tx fix for Asterisk 20+ RTP validation. Pin this SHA and do not upgrade
# without retesting full call path (direct call, transfer, hold, MoH) on physical hardware.
ASTERISK_VERSION="22.9.0"
FREEPBX_VERSION="17.0"
CHAN_SCCP_REPO="https://github.com/timspb/chan-sccp"
CHAN_SCCP_SHA="7e05ccd82d415fb99312912760f7542a3403182d"
TFTP_PATH="/srv/tftp"
INSTALL_SCCP=1
FETCH_FIRMWARE=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --asterisk-version) ASTERISK_VERSION="$2"; shift 2 ;;
    --freepbx-version) FREEPBX_VERSION="$2"; shift 2 ;;
    --tftp-path) TFTP_PATH="$2"; shift 2 ;;
    --no-sccp) INSTALL_SCCP=0; shift ;;
    --no-firmware) FETCH_FIRMWARE=0; shift ;;
    *) shift ;;
  esac
done

echo "[*] Installing build prerequisites"
apt-get update -y
apt-get install -y \
  unzip git sox gnupg2 curl pkg-config \
  libnewt-dev libssl-dev libncurses5-dev \
  libsqlite3-dev build-essential libjansson-dev \
  libxml2-dev libedit-dev uuid-dev subversion \
  apache2 mariadb-server atftpd

echo "[*] Installing PHP 8.3 and FreePBX dependencies"
# Ubuntu 24.04 ships PHP 8.3 which satisfies FreePBX 17's >= 8.2 requirement.
# No PPA needed.
apt-get install -y \
  php8.3 libapache2-mod-php8.3 \
  php8.3-cli php8.3-common php8.3-curl php8.3-gd \
  php8.3-mbstring php8.3-mysql php8.3-bcmath php8.3-zip \
  php8.3-xml php8.3-imap php8.3-soap php8.3-ldap \
  php8.3-intl php8.3-sqlite3 php-pear

echo "[*] Installing Node.js 22"
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

echo "[*] Downloading Asterisk ${ASTERISK_VERSION}"
cd /usr/src
wget -q "https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${ASTERISK_VERSION}.tar.gz"
tar -xzf "asterisk-${ASTERISK_VERSION}.tar.gz"
cd "asterisk-${ASTERISK_VERSION}"

echo "[*] Fetching MP3 codec and installing prereqs"
contrib/scripts/get_mp3_source.sh
# mysql is in add-ons
contrib/scripts/get_addon_source.sh
contrib/scripts/install_prereq install

echo "[*] Configuring Asterisk"
# --with-pjproject-bundled and --with-jansson-bundled avoid system library version conflicts
./configure --with-pjproject-bundled --with-jansson-bundled

echo "[*] Building Asterisk non-interactively"
make menuselect.makeopts
menuselect/menuselect --enable res_config_mysql menuselect.makeopts
menuselect/menuselect --enable format_mp3 menuselect.makeopts
make -j"$(nproc)"
make install
make install-headers
make config
make samples
ldconfig

echo "[*] Creating asterisk user"
groupadd asterisk || true
useradd -r -d /var/lib/asterisk -g asterisk asterisk || true
usermod -aG audio,dialout asterisk
chown -R asterisk:asterisk \
  /etc/asterisk /var/lib/asterisk /var/log/asterisk \
  /var/spool/asterisk /usr/lib/asterisk

sed -i 's/#AST_USER="asterisk"/AST_USER="asterisk"/' /etc/default/asterisk
sed -i 's/#AST_GROUP="asterisk"/AST_GROUP="asterisk"/' /etc/default/asterisk
sed -i 's/;runuser =.*/runuser = asterisk/' /etc/asterisk/asterisk.conf
sed -i 's/;rungroup =.*/rungroup = asterisk/' /etc/asterisk/asterisk.conf

# Asterisk 22 requires this file to exist or it logs warnings on startup
touch /etc/asterisk/stir_shaken.conf

systemctl restart asterisk
systemctl enable asterisk

echo "[*] Installing FreePBX ${FREEPBX_VERSION}"
cd /usr/src
wget -q "http://mirror.freepbx.org/modules/packages/freepbx/freepbx-${FREEPBX_VERSION}-latest.tgz"
tar -xzf "freepbx-${FREEPBX_VERSION}-latest.tgz"
cd freepbx
./install -n

echo "[*] Configuring Apache/PHP"
sed -i 's/^\(User\|Group\).*/\1 asterisk/' /etc/apache2/apache2.conf
sed -i 's/AllowOverride None/AllowOverride All/' /etc/apache2/apache2.conf
sed -i 's/upload_max_filesize = 2M/upload_max_filesize = 120M/' /etc/php/8.3/apache2/php.ini
sed -i 's/post_max_size = 8M/post_max_size = 120M/' /etc/php/8.3/apache2/php.ini
a2enmod rewrite
systemctl restart apache2

if [[ "$INSTALL_SCCP" -eq 1 ]]; then
  echo "[*] Installing chan_sccp from timspb fork @ ${CHAN_SCCP_SHA}"
  # Upstream chan-sccp is unmaintained since 2022. This fork includes the
  # payload_mapping_tx fix required for Asterisk 20+ RTP compatibility and
  # has been tested against FreePBX 17 + Asterisk 22 + PHP 8.2.
  # DO NOT update this SHA without re-validating: direct calls, transfer,
  # hold/MoH, and G722 negotiation on physical Cisco hardware.
  cd /usr/src
  git clone "${CHAN_SCCP_REPO}" chan-sccp
  cd chan-sccp
  git checkout "${CHAN_SCCP_SHA}"

  echo "[*] Verifying chan_sccp SHA"
  ACTUAL_SHA=$(git rev-parse HEAD)
  if [[ "$ACTUAL_SHA" != "$CHAN_SCCP_SHA" ]]; then
    echo "[!] ERROR: SHA mismatch. Expected ${CHAN_SCCP_SHA}, got ${ACTUAL_SHA}"
    exit 1
  fi

  if [[ ! -d /usr/include/asterisk && ! -d /usr/local/include/asterisk ]]; then
    echo "[!] ERROR: Could not find Asterisk headers under /usr/include/asterisk or /usr/local/include/asterisk"
    echo "[!] Re-enter /usr/src/asterisk-${ASTERISK_VERSION} and run: make install-headers"
    exit 1
  fi

  echo "[*] Running chan_sccp configure with Asterisk auto-detection"
  if ! ./configure --enable-conference --enable-advanced-functions; then
    echo "[*] Auto-detection failed, retrying with explicit Asterisk path"
    ASTERISK_BIN="$(command -v asterisk || true)"
    if [[ -z "$ASTERISK_BIN" ]]; then
      for candidate in /usr/sbin/asterisk /usr/local/sbin/asterisk; do
        if [[ -x "$candidate" ]]; then
          ASTERISK_BIN="$candidate"
          break
        fi
      done
    fi

    if [[ -z "$ASTERISK_BIN" ]]; then
      echo "[!] ERROR: Could not find the asterisk binary in PATH, /usr/sbin, or /usr/local/sbin"
      echo "[!] Run 'which asterisk' and ensure Asterisk is installed before building chan-sccp"
      exit 1
    fi

    ASTERISK_BIN_DIR="$(dirname "$ASTERISK_BIN")"
    echo "[*] Retrying with --with-asterisk=${ASTERISK_BIN_DIR}"
    ./configure --enable-conference --enable-advanced-functions \
      --with-asterisk="${ASTERISK_BIN_DIR}"
  fi
  make -j"$(nproc)"
  make install
  make reload
fi

echo "[*] Configuring TFTP"
mkdir -p "$TFTP_PATH"

if [[ "$FETCH_FIRMWARE" -eq 1 ]]; then
  echo "[*] Fetching Cisco 7945 firmware"
  BASE="https://raw.githubusercontent.com/InputObject2/provision_sccp/master/tftpboot/firmware/7945"
  cd "$TFTP_PATH"
  for f in \
    SCCP45.9-4-2SR4-3S.loads \
    apps45.9-4-2SR4-3.sbn \
    cnu45.9-4-2SR4-3.sbn \
    cvm45sccp.9-4-2SR4-3.sbn \
    dsp45.9-4-2SR4-3.sbn \
    jar45sccp.9-4-2SR4-3.sbn \
    term45.default.loads; do
    curl -fSL "${BASE}/${f}" -o "$f"
  done
fi

chown -R asterisk:asterisk "$TFTP_PATH"

# Disable skinny channel driver so it doesn't conflict with SCCP
echo "noload => chan_skinny.so" >> /etc/asterisk/modules.conf

# Load additional Asterisk modules
echo "load => app_voicemail.so" >> /etc/asterisk/modules.conf
echo "load => bridge_simple.so" >> /etc/asterisk/modules.conf
echo "load => bridge_native_rtp.so" >> /etc/asterisk/modules.conf
echo "load => bridge_softmix.so" >> /etc/asterisk/modules.conf
echo "load => bridge_holding.so" >> /etc/asterisk/modules.conf
echo "load => res_stasis.so" >> /etc/asterisk/modules.conf
echo "load => res_stasis_device_state.so" >> /etc/asterisk/modules.conf
echo "load => chan_sccp.so" >> /etc/asterisk/modules.conf

fwconsole ma install pm2

chown -R asterisk:asterisk \
  /etc/asterisk /var/lib/asterisk /var/log/asterisk \
  /var/spool/asterisk /usr/lib/asterisk

echo "[*] Install complete"

echo "To access FreePBX GUI, navigate to http://<server-ip>/admin and complete the web-based setup wizard."
echo "To download sccp_manager: https://github.com/timspb/sccp_manager/archive/refs/tags/v17.0.1.1.tar.gz"

#cd /usr/src
#wget -q "https://github.com/timspb/sccp_manager/archive/refs/tags/v17.0.1.1.tar.gz" \
#  -O sccp_manager-17.0.1.1.tar.gz
#mkdir -p /var/www/html/admin/modules/sccp_manager
#tar -xzf sccp_manager-17.0.1.1.tar.gz \
#  --strip-components=1 \
#  -C /var/www/html/admin/modules/sccp_manager
#fwconsole ma install sccp_manager
#fwconsole reload
