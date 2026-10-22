# Установка Arch Linux на хост `ambb`

Хост: **MAIBENBEN Smart S14B-R560UM** — AMD Ryzen 5 6600H (6c/12t),
Radeon 660M, 16 ГБ DDR5, дисплей 3072×1920@120, Wi-Fi 5 + BT 5.0.

Загрузчик **systemd-boot**, ФС **ext4**, без LUKS, `resume=` для гибернации.

> **ВНИМАНИЕ: вся таблица разделов `/dev/nvme0n1` будет стёрта.**

Порядок: загрузка (флешка или сеть) → разметка → pacstrap → chroot →
systemd-boot → сеть → `install/install.sh` из этого репо.

---

## 0. Сверка диска

Проверить, что диск — тот самый (KINGSTON OM8SEP4512N-A0, 476.94 GiB):

```bash
lsblk -o NAME,SIZE,MODEL,PTTYPE
blkid
```

Эталонная разметка из `install/instructions/ambb-disks`:

| раздел          | секторы                   | размер   | тип GPT          | ФС   | точка        |
|-----------------|---------------------------|----------|------------------|------|--------------|
| `/dev/nvme0n1p1`| 2048 – 1050623            | 512 MiB  | EFI System (`ef00`) | FAT32| `/boot`   |
| `/dev/nvme0n1p2`| 1050624 – 966660095       | 460.4 GiB| Linux filesystem (`8300`) | ext4 | `/` |
| `/dev/nvme0n1p3`| 966660096 – 1000214527    | 16 GiB   | Linux swap (`8200`)   | swap | —     |

Диск: 1000215216 секторов по 512 B = 476.94 GiB.

---

## Вариант A. Загрузка с флешки

Записать ISO (на машине с Linux; `of=` — именно весь диск флешки, не раздел):

```bash
sudo dd if=archlinux-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Windows: Rufus (режим DD) или balenaEtcher.

Прошивка (MAIBENBEN: **F2** вход в Setup, **F7** Boot Menu, **Del** Setup):
- отключить **Secure Boot**;
- Boot Mode = **UEFI**;
- выбрать USB в Boot Menu → Arch ISO.

В live-среде проверить UEFI и сеть:

```bash
cat /sys/firmware/efi/fw_platform_size   # ожидается 64
ping -c1 archlinux.org
timedatectl set-ntp true
```

---

## Вариант B. Установка по локальной сети (PXE + HTTP)

Нужен сервер (напр. `adesk`) в той же L2-сети. Отдаём TFTP (загрузчик +
ядро) и HTTP (корень archiso). Роутер не трогаем — dnsmasq в proxy-DHCP.

### B1. Сервер: образ и дерево

```bash
sudo pacman -S dnsmasq
sudo mkdir -p /srv/tftp /srv/http/arch
# монтируем ISO и копируем содержимое в HTTP-корень
sudo mount -o loop archlinux-x86_64.iso /mnt/iso
sudo cp -a /mnt/iso/. /srv/http/arch/
sudo umount /mnt/iso
```

Структура, которую ждёт initramfs archiso:
`/srv/http/arch/arch/boot/x86_64/vmlinuz-linux`,
`.../initramfs-linux.img`, `/srv/http/arch/arch/x86_64/airootfs.sfs`.

### B2. Сервер: dnsmasq (proxy-DHCP + TFTP + iPXE)

Сначала узнать **реальное имя интерфейса** и IP сервера в LAN (на Arch это почти
никогда не `eth0`):

```bash
ip -br addr
# напр. enp3s0  192.168.1.10/24
```

По умолчанию Arch-шный `/etc/dnsmasq.conf` **не** читает `/etc/dnsmasq.d/`
(строка `conf-dir` там закомментирована). Включить каталог (иначе `pxe.conf`
молча игнорируется, и `dnsmasq --test` тоже его не увидит):

```bash
grep -q '^conf-dir=' /etc/dnsmasq.conf \
  || echo 'conf-dir=/etc/dnsmasq.d/,*.conf' | sudo tee -a /etc/dnsmasq.conf
grep '^conf-dir' /etc/dnsmasq.conf     # должно вывести conf-dir=/etc/dnsmasq.d/,*.conf
```

`/etc/dnsmasq.d/pxe.conf` (подставить имя интерфейса и адрес сервера):

```ini
interface=enp3s0
bind-interfaces
port=0                     # DNS не нужен; снимает конфликт за порт :53

# proxy-DHCP: IP раздаёт основной роутер, dnsmasq — только boot-опции.
# Первый аргумент — адрес самого сервера (не 0.0.0.0), имя интерфейса
# в dhcp-range не пишется.
dhcp-range=192.168.1.10,proxy

enable-tftp
tftp-root=/srv/tftp
log-dhcp

# UEFI x86-64. ВАЖНО: arch у клиента бывает 7 (EFI BC) и 9 (EFI x86-64) —
# матчить оба. pxe-service тут НЕ использовать: у UEFI-клиентов CSA часто
# не совпадает, и тогда boot-файл не отдаётся (клиент "не видит" PXE).
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-match=set:efi-x86_64,option:client-arch,9
dhcp-boot=tag:efi-x86_64,tag:!ipxe,ipxe.efi        # 1-й шаг: грузим iPXE

# старые BIOS-клиенты (опционально)
dhcp-match=set:bios,option:client-arch,0
dhcp-boot=tag:bios,tag:!ipxe,undionly.kpxe

# 2-й шаг: iPXE (option 175) получает URL скрипта
dhcp-match=set:ipxe,175
dhcp-boot=tag:ipxe,http://192.168.1.10/boot.ipxe
```

```bash
sudo mkdir -p /srv/tftp
sudo curl -L https://boot.ipxe.org/ipxe.efi -o /srv/tftp/ipxe.efi

sudo dnsmasq --test                 # проверка синтаксиса (уже видит pxe.conf)
sudo systemctl enable --now dnsmasq
systemctl status dnsmasq --no-pager
```

Проверить, что каталог реально подключён:

```bash
grep '^conf-dir' /etc/dnsmasq.conf           # директива раскомментирована
# доказательство, что pxe.conf читается: впиши заведомо битую строку --
echo 'bogus-option=1' | sudo tee -a /etc/dnsmasq.d/pxe.conf
sudo dnsmasq --test                          # должен упасть -> файл читается
sudo sed -i '/bogus-option/d' /etc/dnsmasq.d/pxe.conf
```

`/srv/http/boot.ipxe` (подставить IP сервера):

```
#!ipxe
dhcp
kernel http://192.168.1.10/arch/arch/boot/x86_64/vmlinuz-linux \
  ip=dhcp archisobasedir=arch archiso_http_srv=http://192.168.1.10/arch/ \
  copytoram=auto
initrd http://192.168.1.10/arch/arch/boot/x86_64/initramfs-linux.img
boot
```

Клиент (ambb): Boot Menu → PXE/UEFI Network Boot.
`copytoram=auto` копирует airootfs в ОЗУ (на 16 ГБ ОЗУ ок; при нехватке убрать).

Типичные причины, по которым dnsmasq не стартует или клиент не видит PXE:

- **`conf-dir` не раскомментирован** в `/etc/dnsmasq.conf` — файлы в
  `/etc/dnsmasq.d/` вообще не читаются, а `--test` при этом «проходит»;
- **архитектура не совпадает**: `pxe-service=X86-64_EFI` (arch 9) не срабатывает
  для клиента с `PXEClient:Arch:00007` (EFI BC) — меню пустое, dnsmasq отдаёт
  только опцию 60. Лечится `dhcp-match`+`dhcp-boot` по `option:client-arch`
  (матчить **и 7, и 9**);
- `dhcp-range` с именем интерфейса (`eth0,...`) или `0.0.0.0` — неверный синтаксис;
- `interface=` указывает на несуществующий NIC (`eth0` вместо `enp5s0`) —
  юнит падает с `unknown interface` / `no interfaces available`;
- занят порт `:53` (если рядом `systemd-resolved`) — лечится `port=0`;
- не создан `tftp-root` (`/srv/tftp`) — TFTP-сервер не поднимается.

Диагностика:

```bash
sudo dnsmasq --test                               # ошибки конфига
systemctl status dnsmasq ; journalctl -xeu dnsmasq -n 50
# ключевое: видеть в логе boot-файл/URL, а не одну опцию 60
journalctl -u dnsmasq | grep -iE 'PXE|client-arch|boot|tftp|proxy'
# в логе PXE-запрос клиента:
#   vendor class: PXEClient:Arch:00007:UNDI:003016   <- arch 7 = EFI BC
#   sent ... option: 60 vendor-class ...             <- БЕЗ boot-файла => мимо
ss -lunp | grep -E ':(53|67|69|4011)'             # занятость портов
ip -br addr show                                  # имя/адрес интерфейса
curl -s tftp://<IP-сервера>/ipxe.efi -o /dev/null && echo "TFTP OK"   # TFTP
```

---

## 1. Разметка диска (полная)

```bash
# стереть старую таблицу
sgdisk --zap-all /dev/nvme0n1

# p1: EFI System, 512 MiB
sgdisk -n 1:2048:1050623 -t 1:ef00 -c 1:"EFI system partition" /dev/nvme0n1

# p2: Linux root, 460.4 GiB
sgdisk -n 2:1050624:966660095 -t 2:8300 -c 2:"Linux filesystem" /dev/nvme0n1

# p3: Linux swap, 16 GiB
sgdisk -n 3:966660096:1000214527 -t 3:8200 -c 3:"Linux swap" /dev/nvme0n1

# применить и обновить узлы устройств
partprobe /dev/nvme0n1
udevadm settle
```

Форматирование:

```bash
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 /dev/nvme0n1p2
mkswap /dev/nvme0n1p3
```

Проверка совпадения с `ambb-disks`:

```bash
sgdisk -p /dev/nvme0n1
lsblk -f /dev/nvme0n1
```

---

## 2. Монтирование и pacstrap

```bash
mount /dev/nvme0n1p2 /mnt
# ESP: маски 0077 — иначе bootctl предупреждает про world-accessible random-seed.
# FAT не хранит права: они задаются при монтировании (fmask — файлы, dmask — каталоги).
mount --mkdir -o fmask=0177,dmask=0077 /dev/nvme0n1p1 /mnt/boot
swapon /dev/nvme0n1p3

pacstrap -K /mnt base base-devel linux linux-firmware amd-ucode \
  git networkmanager vim terminus-font

genfstab -U /mnt >> /mnt/etc/fstab
```

- `amd-ucode` — микрокод CPU AMD (Ryzen 5 6600H).
- `base-devel` даёт `sudo` и `makepkg` (нужны `install.sh` для сборки `yay`).
- `git` обязателен для бутстрапа `yay` в `install.sh`.
- `networkmanager` — Wi-Fi/провод после установки.
- `terminus-font` — крупный консольный шрифт с **кириллицей** (см. раздел 3).

`genfstab` переносит маски ESP в `/etc/fstab` (в строке — `fmask=0177,dmask=0077`).
Проверить, что swap и маски попали в fstab:

```bash
grep -E 'swap|fmask' /mnt/etc/fstab
```

> Если маски в fstab не оказались, впиши их вручную позже — иначе `bootctl`
> будет ругаться на world-accessible `random-seed` (см. раздел 4).

---

## 3. chroot и базовая настройка

```bash
arch-chroot /mnt
```

> `-S` (systemd-режим): `arch-chroot -S /mnt` запускает shell без pid-namespace,
> и тогда `bootctl install` сам создаст запись в NVRAM (не будет сообщения
> про контейнер, см. раздел 4). Но `-S` требует работающего systemd в live-среде
> (в archiso он есть) — если сомневаешься, заходим обычным `arch-chroot` и делаем
> `efibootmgr --create` вручную.

```bash
# время
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc

# локали
sed -i 's/^#\(en_US.UTF-8\)/\1/; s/^#\(ru_RU.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

# консоль: раскладка + крупный шрифт с кириллицей (HiDPI, 3072×1920)
# ВНИМАНИЕ: FONT=ter-132b кириллицу НЕ содержит (только latin1; это отдельная
# «комбинированная» раскладка, а не Unicode). Кириллица есть в ter-v*.
echo 'KEYMAP=us' > /etc/vconsole.conf
# echo 'KEYMAP=ru' >> /etc/vconsole.conf
echo 'FONT=ter-v32b' >> /etc/vconsole.conf
# Фолбэк без terminus-font (то же 8x16, кириллица есть, но мельче):
#   echo 'FONT=cyr-sun16' >> /etc/vconsole.conf

# hostname
echo ambb > /etc/hostname
cat > /etc/hosts <<'EOF'
127.0.0.1  localhost
::1        localhost
127.0.1.1  ambb.localdomain ambb
EOF

# root
passwd

# пользователь (wheel — для sudo; логин согласовать с install.sh/репо)
useradd -m -G wheel -s /bin/bash artems
passwd artems
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# initramfs (дефолтные хуки содержат microcode)
mkinitcpio -P
```

Проверить шрифт прямо сейчас (не выходя из chroot): `setfont ter-v32b`.
Кириллица появится сразу; `-m 8859-5` **не нужен** — консоль Arch работает в
UTF-8, а `ter-v*` содержит встроенную Unicode-таблицу (проверено:
`psfgettable /usr/share/kbd/consolefonts/ter-v32b.psf.gz` даёт 146 кириллических
кодовых точек, `ter-132b` — ноль). `-m <кодовая страница>` нужен только для
не-UTF-8 режима.

Если хочется крупный шрифт уже **на этапе загрузки ядра** (надпись tty до
загрузки `vconsole.conf`), добавь в boot-опции `fbcon=font:TER16x32` — это
встроенный в ядро шрифт (16×32, на базе Terminus), кириллицу показывает без
пакета `terminus-font`.

Выход по желанию позже; далее загрузчик.

---

## 4. Загрузчик systemd-boot

```bash
bootctl --path=/boot install
```

`bootctl install` штампует три «пугающих» сообщения — **все три безобидны**
(подтверждено по исходникам systemd, `bootctl-random-seed.c` / `bootctl-install.c`):

1. `Mount point '/boot' which backs the random seed file is world accessible` —
   предупреждение: у каталога/файла `random-seed` на ESP стоят мировые биты
   (права FAT берутся из опций монтирования). Лечится монтированием ESP с
   `fmask=0177,dmask=0077` (см. раздел 2) — тогда предупреждения нет.
2. `Random seed file '/boot/loader/random-seed' is world accessible` — то же
   самое, из-за мировых бит; `bootctl` создаёт файл `0600`, но FAT эти права не
   хранит. Тоже снимается `fmask=0177`.
3. `Not booted with EFI or running in a container, skipping EFI variable
   modifications` — `bootctl` не трогает EFI-переменные (не создаёт запись в
   Boot-меню). Причина: `arch-chroot` запускает shell **в pid-namespace**, и
   `bootctl` считает это контейнером. Установка НЕ падает, boot-файлы на ESP
   копируются; запись в NVRAM делаем вручную (см. ниже) или входим через
   `arch-chroot -S` (systemd-режим, тогда `bootctl` сам создаст запись).

Проверка, что всё скопировалось на ESP, несмотря на предупреждения:

```bash
ls -l /boot/EFI/systemd/systemd-bootx64.efi /boot/EFI/BOOT/BOOTX64.EFI /boot/loader/loader.conf
```

Запись в Boot-меню вручную (`p1` = номер раздела, здесь `1`; `--part` — это
**номер раздела**, не PARTUUID):

```bash
efibootmgr --create --disk /dev/nvme0n1 --part 1 \
  --loader '\EFI\systemd\systemd-bootx64.efi' --label "Linux Boot Manager" --unicode
```

`/boot/loader/loader.conf`:

```
default  arch.conf
timeout  4
console-mode max
editor   no
```

`/boot/loader/entries/arch.conf` — подставить PARTUUID из `blkid`:

```bash
blkid -s PARTUUID -o value /dev/nvme0n1p2   # root
blkid -s PARTUUID -o value /dev/nvme0n1p3   # swap (resume)
```

```
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=PARTUUID=<PARTUUID-p2> resume=PARTUUID=<PARTUUID-p3> rw quiet
```

- Хук `microcode` уже в дефолтном `mkinitcpio.conf`, поэтому отдельная строка
  `initrd /amd-ucode.img` **не нужна** (микрокод упакован в основной initramfs).
- ESP смонтирован в `/boot` → ядро/initramfs обновляются автоматически.

---

## 5. Гибернация (опционально)

`resume=PARTUUID=<p3>` уже прописан в boot-опции выше — этого достаточно,
чтобы ядро находило swap для resume.

Автоматический «suspend, затем hibernate» после простоя:

```bash
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/idle-action.conf <<'EOF'
[Login]
IdleAction=suspend-then-hibernate
IdleActionSec=15min
EOF
```

Ограничения на этом ноутбуке:
- **16 ГБ swap ровно под 16 ГБ ОЗУ** — гибернация возможна, только если занятая
  память помещается в swap; при нехватке — увеличить p3.
- swap **не зашифрован**: в дампе ОЗУ остаются ключи и пароли. Для ноутбука это
  аргумент за LUKS (см. отдельную задачу).
- Включённый kernel lockdown/Secure Boot отключает гибернацию.
- При чёрном экране после resume — убрать раннюю инициализацию GPU (`kms`/`MODULES`).

---

## 6. Сеть и первый запуск

```bash
systemctl enable NetworkManager
systemctl enable bluetooth

exit                 # выйти из chroot
umount -R /mnt
swapoff --all
reboot
```

---

## 7. Пост-установка: конфиги этого репо

После перезагрузки, под пользователем `artems`:

```bash
# ключи SSH нужны для приватного remote (github.com:rastaclaus/config_files)
git clone git@github.com:rastaclaus/config_files.git ~/config_files
cd ~/config_files

./install/install.sh --dry-run      # проверка
./install/install.sh                # пакеты + npm/uv + fisher + симлинки
```

`install.sh` сам определит хост: hostname `ambb` → `hosts/ambb`, профиль `gui`
(см. `install/hosts.conf`). Дальше раскомментировать нужное в
`hosts/ambb/packages.txt` (напр. `linux-headers`) и перезапустить
`./install/install.sh --no-links`.

Установщик сам делает fish login shell (`sudo chsh`; `--no-shell`, если не
нужно) — без этого шага вход на tty1 уходил в bash, а композитор так и не
поднимался.

Композитор на tty1 (это делает `fish/config.fish`):

```bash
cat ~/.local/state/dotfiles/compositor   # записан установщиком: sway|niri|none
wm niri      # или: wm sway / wm none  (применится при следующем входе)
```

VPN-профиль (по необходимости):

```bash
cp vpn/local.env.example vpn/local.env   # заполнить
./install/install_vpn.sh
```

---

## 8. Wi-Fi RTL8822CE: обязательная настройка

Карта: **Realtek RTL8822CE** (PCIe `01:00.0`, 2×2 VHT, 80 МГц, до 867 Мбит PHY),
драйвер `rtw88_8822ce` (mainline), прошивка `9.9.15`.

```bash
lspci -nnk | grep -A3 -i 'network controller'
# Kernel driver in use: rtw88_8822ce
ls /lib/firmware/rtw88/rtw8822c_fw.bin.zst    # нужен linux-firmware-realtek
```

> В новых Arch `linux-firmware` — метапакет. Если ставили не его, а только
> `linux-firmware-*` по частям, для этой карты обязателен `linux-firmware-realtek`.

Сразу после чистой установки Wi-Fi работает, но **медленно и с лагами**. Причин
четыре, все воспроизводимые.

### 8.1. Regdomain (страна) — базы нет вообще

Симптом в журнале и `iw reg get`:

```
cfg80211: failed to load regulatory.db
global
country 00: DFS-UNSET
```

Пакет `wireless-regdb` не входит в `base`, поэтому ядро работает с «мировым»
доменом: урезанный EIRP, `PASSIVE-SCAN` на всех 5 ГГц.

```bash
sudo pacman -S --needed wireless-regdb iw

# раскомментировать строку с RU (файл содержит полный список стран)
sudo sed -i 's/^#WIRELESS_REGDOM="RU"$/WIRELESS_REGDOM="RU"/' /etc/conf.d/wireless-regdom
grep '^WIRELESS_REGDOM' /etc/conf.d/wireless-regdom      # WIRELESS_REGDOM="RU"
```

**Ловушка:** `iw reg set RU` (и `/usr/bin/set-wireless-regdom`, который дёргает
udev-правило `85-regulatory.rules`) **молча ничего не делает**, если
`regulatory.db` не была загружена при инициализации `cfg80211` — вернёт код 0, а
`iw reg get` останется `country 00`. База читается только при загрузке модуля.
Поэтому после установки пакета — **перезагрузка** (или перезагрузка стека):

```bash
sudo modprobe -r rtw88_8822ce rtw88_8822c rtw88_pci rtw88_core mac80211 cfg80211
sudo modprobe rtw88_8822ce
iw reg get | head -3      # country RU: ...
```

Проверка, что домен применился к каналам:

```bash
iw phy phy0 info | sed -n '/Band 2:/,/Band 3:/p' | grep -E '\* 5[0-9]{3}\.'
# 5745..5825 МГц (149-165) должны быть без (disabled), 23 dBm
```

### 8.2. Энергосбережение — включено по умолчанию

NetworkManager ставит `802-11-wireless.powersave = 0 (default)`, что включает
power save. На `rtw88` это даёт пинг до собственного роутера в десятки мс:

```
до:    ping <IP-роутера> → avg 35.7 мс, max 123 мс, mdev 34.6
после: ping <IP-роутера> → avg  5.4 мс, max  14 мс, mdev  3.5
```

```bash
printf '[connection]\nwifi.powersave = 2\n' | sudo tee /etc/NetworkManager/conf.d/wifi-powersave-off.conf
sudo systemctl restart NetworkManager
iw dev wlp1s0 get power_save        # Power save: off
```

### 8.3. PCIe ASPM — известная проблема rtw88

`rtw88_pci` по умолчанию оставляет ASPM включённым; на Realtek это даёт просадки
throughput и «залипания».

```bash
printf 'options rtw88_pci disable_aspm=1\n' | sudo tee /etc/modprobe.d/rtw88.conf
sudo mkinitcpio -P
# reboot; проверить:
cat /sys/module/rtw88_pci/parameters/disable_aspm    # Y
```

### 8.4. bgscan — главная причина «пачек» лагов

NetworkManager добавляет в конфиг supplicant:

```
Config: added 'bgscan' value 'simple:30:-70:86400'
```

Это значит: сканировать каждые 30 с, **если сигнал ниже -70 dBm**. Наш AP в
рабочей точке даёт ровно -68…-70, то есть порог срабатывает постоянно. Замер
`iw event -t` показал **скан каждые 10–11 с**, каждый занимает ~1.8 с и уводит
радио с канала:

```
до:    8 сканов / 90 с, пинг avg 37 мс, выбросы 65→78→106→138 мс пачками
после: 0 сканов / 90 с, пинг avg 5.4 мс, max 9.4 мс, mdev 1.26
```

Опции отключить bgscan в NM нет, но bgscan не запускается, если клиент привязан
к конкретному BSSID (роуминг бессмыслен). Фиксируем BSSID в профиле:

```bash
# BSSID своего AP взять из: nmcli -f SSID,BSSID,CHAN device wifi list
sudo nmcli connection modify <SSID> 802-11-wireless.bssid <BSSID>
sudo nmcli connection down <SSID>; sudo nmcli connection up <SSID>
nmcli -f 802-11-wireless.bssid connection show <SSID>
```

Проверка, что сканы прекратились:

```bash
sudo timeout 60 iw event -t | grep -c 'scan started'    # ожидается 0
```

> Побочный эффект: ноут привязан к этому BSSID. При переезде/замене роутера —
> `sudo nmcli connection modify <SSID> 802-11-wireless.bssid ""`.

### 8.5. Роутер — канал и ширина

> Плейсхолдеры: `<SSID>` — имя сети в профиле NetworkManager (`nmcli connection
> show`), `<BSSID>` — MAC точки доступа (`nmcli -f SSID,BSSID,CHAN device wifi
> list`), `<IP-роутера>` — шлюз (`ip route | awk '/default/{print $3}'`).
> Ниже — замеры на конкретном бытовом AP оператора (2×2 VHT, 80 МГц); на другом
> оборудовании цифры будут иными, но закономерности по диапазонам те же.

Замеры в рабочей точке (за столом, через стены) и у роутера:

| Настройка AP | За столом | У роутера |
|---|---|---|
| 5 ГГц, канал **44** (5220), 80 МГц | **-68 dBm**, MCS3-4 NSS1, 63 Мбит, пинг 5.4 мс | ~150 Мбит |
| 5 ГГц, канал **149** (5745), 80 МГц | -75…-76 dBm, MCS0-1 NSS1, **4–15 Мбит** | **184–300 Мбит** |
| 5 ГГц, канал 44, **40 МГц** | ~-58 dBm, MCS6 NSS2, хуже в пике | 111 Мбит |
| 2,4 ГГц, канал 1, 20 МГц | -73 dBm, 5.5/6 Мбит, **пинг 1159 мс** | — |

Выводы:
- верхний диапазон (149–165) на 6–10 dB хуже проходит стены → за столом
  не годится, у роутера наоборот лучший (эфир пуст, 23 dBm);
- **2,4 ГГц в этом месте непригоден**: канал 1 забит, legacy-скорости, пинг
  больше секунды;
- 40 МГц **не** спасает при нормальном сигнале — 80 МГц выигрывает за счёт
  вдвое большего числа поднесущих. Сужать имеет смысл только при MCS1-2.

В веб-интерфейсе роутера (`http://<IP-роутера>`, обычно basic-auth)
менять только: **Канал** и **Полоса пропускания**. `Полоса = Авто 20+40+80`,
`Уровень сигнала = Высокий`. Смена канала применяется **только после
Save + Reboot**; дважды в этой сессии настройка не вступала в силу без ребута.

### 8.6. Ожидаемые цифры и потолок

```
у роутера: -50 dBm  → rx 585 Мбит (MCS7 NSS2), 184–300 Мбит TCP
за столом : -68 dBm  → rx 175 Мбит (MCS4 NSS1),  63 Мбит TCP
```

За столом rate-control честно отключает второй поток (`NSS1`), потому что вторая
антенна приходит на 5–9 dB слабее первой. Это физика, не настройка: софтом
больше не выжать. Если нужны 200+, единственный путь — AP/репитер ближе к
рабочему месту.

Проверить, что обе антенны живы (второе число в скобках — вторая цепь):

```bash
sudo iw dev wlp1s0 station dump | grep '^\s*signal'
# signal: -68 [-68, -69] dBm   ← разница цепей должна быть 0-3 dB
```

Если разница стабильно 5+ dB и вблизи роутера — смотреть антенные пигтейлы
(они рядом с M.2-слотом, легко задеть при замене SSD).

### 8.7. Диагностика Wi-Fi

```bash
iw dev wlp1s0 link                     # SSID, freq, signal, rx/tx bitrate, NSS
iw dev wlp1s0 info                     # канал, ширина, txpower
iw dev wlp1s0 get power_save
iw reg get | head -3                   # country RU
sudo iw dev wlp1s0 station dump | grep -E 'signal|bitrate|retries|failed|loss'
sudo iw dev wlp1s0 survey dump         # noise / busy time по каналам
sudo iw event -t                       # scan started / deauth в реальном времени
nmcli -f SSID,BSSID,CHAN,FREQ,SIGNAL device wifi list
sudo dmesg | grep -iE 'rtw|wlp1s0|regulatory'
```

Полезно знать:
- `MCS`/`NSS` в `link` — главный индикатор: `NSS1` при 2×2 = потерян второй поток
  (слабый сигнал или антенна);
- `/sys/class/net/wlp1s0/speed` для Wi-Fi **не имеет смысла** (`Invalid argument`);
- `tx retries`/`failed` у rtw88 показывает 0 даже при проблемах — ориентируйтесь
  на `signal`, `MCS/NSS` и пинг до шлюза;
- `ping` до шлюза — самый быстрый тест радио: 2–5 мс норма, >20 мс — power save,
  сканы или забитый эфир.

### 8.8. Откат

```bash
sudo rm /etc/NetworkManager/conf.d/wifi-powersave-off.conf
sudo rm /etc/modprobe.d/rtw88.conf
sudo sed -i 's/^WIRELESS_REGDOM=/WIRELESS_REGDOM=/' /etc/conf.d/wireless-regdom  # или вернуть "#"
sudo nmcli connection modify <SSID> 802-11-wireless.bssid ""
sudo mkinitcpio -P && sudo reboot
```

---

## 9. Чек-лист проверки

```bash
lsblk -f /dev/nvme0n1          # p1 vfat /boot, p2 ext4 /, p3 swap
sgdisk -p /dev/nvme0n1         # разметка = ambb-disks
efibootmgr -v                  # запись Arch / systemd-boot
bootctl status                 # entries: arch.conf
systemctl is-enabled NetworkManager
ip -brief addr                 # сеть поднялась
cat /proc/swaps                # swap активен
getent passwd artems | cut -d: -f7   # /usr/bin/fish
cat ~/.local/state/dotfiles/compositor
niri-session                   # или sway: рабочий стол стартует

# Wi-Fi (см. раздел 8)
iw reg get | head -2                                   # country RU
iw dev wlp1s0 get power_save                           # Power save: off
cat /sys/module/rtw88_pci/parameters/disable_aspm      # Y
nmcli -f 802-11-wireless.bssid connection show <SSID>   # привязан BSSID
ping -c 20 -i 0.2 <IP-роутера> | tail -1              # avg 2-10 мс
iw dev wlp1s0 link | grep -E 'signal|bitrate'          # MCS/NSS + сигнал
```
