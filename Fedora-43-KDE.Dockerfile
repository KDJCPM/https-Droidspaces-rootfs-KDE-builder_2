ARG TARGETPLATFORM
FROM fedora:43 AS customizer

#######################################################
ARG BUILD_KDE
ARG CUSTOM_UID
ARG BUILD_KDE_plus
ARG PulseAudio
ARG ENABLE_zh_tz_ARG
ARG ENABLE_binfmt_ARG
ARG ENABLE_yj_ARG
ARG ENABLE_mesa_ARG
ARG ENABLE_kfgj_ARG
ARG ENABLE_zip_ARG
ARG ENABLE_docker_ARG
ARG ENABLE_srf_ARG
ARG ENABLE_tmoe_ARG
ARG ENABLE_anland_kde_ARG
ARG ENABLE_8gen2_wayland_ARG
ARG ENABLE_systemd257_ARG
ARG USERNAME
ARG ANLAND_KDE_RELEASE_REPOSITORY=Goldzxcbug/Droidspaces-rootfs-KDE-builder
ARG ANLAND_KDE_RELEASE_TAG
ARG ANLAND_KDE_PACKAGE_REVISION=unknown
######################################################

ENV DEBIAN_FRONTEND=noninteractive

# 通用 Droidspaces USB Manager 安装器
COPY scripts/install-usb-manager.sh /usr/local/sbin/install-droidspaces-usb-manager
COPY scripts/systemd257.sh /usr/local/sbin/systemd257
COPY scripts/install-anland-kde.sh /usr/local/sbin/install-anland-kde

# 加速下载
RUN echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf && \
    echo "fastestmirror=True" >> /etc/dnf/dnf.conf && \
    echo "defaultyes=True" >> /etc/dnf/dnf.conf

RUN chmod +x /usr/local/sbin/install-anland-kde && \
    dnf install -y --setopt=install_weak_deps=False \
    # 核心工具组件 
    bash jq dialog coreutils file findutils grep sed gawk curl wget ca-certificates bash-completion systemd-udev dbus-daemon systemd systemd-pam systemd-resolved fastfetch \
    # 用户请求的基础开发/编辑工具
    git nano sudo \
    # 网络与 SSH 工具（包含 DHCP 客户端）
    openssh-server net-tools iptables iptables-legacy iputils iproute bind-utils dhcp-client \
    # 用于系统监控的 procps 进程工具
    procps-ng \
    # 核心内核模块支持及语言包
    kmod tzdata tar glibc-locale-source glibc-langpack-en glibc-langpack-zh && \
    ############################################## KDE支持 ################################################
    # 最小化KDE
    echo "%_install_langs all" > /etc/rpm/macros.image-language-conf && \
    if [ "$BUILD_KDE" = "min" ]; then \
        dnf install -y --setopt=install_weak_deps=False \
        dbus-x11 xrandr xset xrdb xhost google-noto-cjk-fonts google-noto-emoji-color-fonts plasma-desktop pipewire pipewire-pulseaudio wireplumber powerdevil kscreen plasma-pa ark kwin upower konsole \
        dolphin kate kinfocenter glx-utils pulseaudio-utils vulkan-tools fedora-logos plasma-milou plasma-workspace plasma-workspace-x11 kwin-x11; \
    fi && \
    # 精简KDE
    if [ "$BUILD_KDE" = "conc" ]; then \
        dnf install -y --setopt=install_weak_deps=False \
        dbus-x11 xrandr xset xrdb xhost google-noto-cjk-fonts google-noto-emoji-color-fonts plasma-desktop pipewire pipewire-pulseaudio wireplumber powerdevil kscreen plasma-pa ark kwin upower konsole \
        dolphin kate kinfocenter glx-utils pulseaudio-utils vulkan-tools fedora-logos aha clinfo dmidecode libdisplay-info wayland-utils xorg-x11-server-Xorg \
        kfind plasma-systemmonitor filelight glmark2 vkmark systemsettings kscreenlocker kio-extras xdg-user-dirs dolphin-plugins ffmpegthumbs kdegraphics-thumbnailers \
        kf6-kimageformats plasma-browser-integration libcanberra-gtk3 gstreamer1-plugins-base gstreamer1-plugins-good sound-theme-freedesktop chromium plasma-milou plasma-workspace plasma-workspace-x11 kwin-x11; \
    fi && \
    # mobile版KDE
    if [ "$BUILD_KDE" = "mobile" ]; then \
        dnf install -y --setopt=install_weak_deps=False \
        dbus-x11 xrandr xset xrdb xhost google-noto-cjk-fonts google-noto-emoji-color-fonts xorg-x11-server-Xorg wayland-utils \
        plasma-nano plasma-mobile maliit-keyboard maliit-framework \
        kwin pipewire pipewire-pulseaudio wireplumber powerdevil plasma-pa upower pulseaudio-utils \
        konsole dolphin kate kinfocenter glx-utils vulkan-tools \
        systemsettings plasma-systemmonitor kscreenlocker kio-extras xdg-user-dirs \
        dolphin-plugins ffmpegthumbs kdegraphics-thumbnailers kf6-kimageformats plasma-settings angelfish \
        gstreamer1-plugins-base gstreamer1-plugins-good sound-theme-freedesktop libcanberra-gtk3 \
        polkit-kde-agent-1 plasma-workspace \
        breeze-icon-theme plasma-breeze qt6-qtsvg \
        kf6-kirigami qt6-qtquickcontrols2 qt6-qtdeclarative \
        glibc-langpack-zh && \
        echo "--> [mobile] 正在移除 ModemManager (容器内无真实 modem 硬件，会导致开机卡住)..." && \
        dnf remove -y ModemManager || true; \
    fi && \
    ######################################################################################################
    # 输入法 fcitx5 (可选)
    if [ "$ENABLE_srf_ARG" = "true" ]; then \
        dnf install -y  fcitx5 fcitx5-qt fcitx5-gtk ; \
    fi && \
    if [ "$ENABLE_srf_ARG" = "true" ] && [ "$ENABLE_zh_tz_ARG" = "true" ]; then \
        dnf install -y --setopt=install_weak_deps=False fcitx5-chinese-addons; \
    fi && \
    ## 开发工具集成 (可选)
    if [ "$ENABLE_kfgj_ARG" = "true" ]; then \
        dnf install -y --setopt=install_weak_deps=False \
        gcc gcc-c++ make cmake autoconf automake libtool pkgconf clang llvm python3 python3-pip python3-devel; \
    fi && \
    ## 压缩工具扩展 (可选)
    if [ "$ENABLE_zip_ARG" = "true" ]; then \
        dnf install -y --setopt=install_weak_deps=False \
        zip unzip p7zip p7zip-plugins bzip2 xz tar gzip; \
    fi && \
    ## docker (可选) 
    if [ "$ENABLE_docker_ARG" = "true" ]; then \
        dnf install -y --setopt=install_weak_deps=False \
        moby-engine docker-compose docker-cli; \
    fi && \
    ## 集成tmoe (可选)
    if [ "$ENABLE_tmoe_ARG" = "true" ]; then \
        git clone --depth=1 https://github.com/2moe/tmoe-linux.git /usr/local/etc/tmoe-linux/git && \
        ln -sf /usr/local/etc/tmoe-linux/git/debian.sh /usr/local/bin/tmoe && \
        chmod -R 755 /usr/local/etc/tmoe-linux; \
    fi && \
    for desktop_file in /usr/share/applications/*chromium*.desktop; do \
        if [ -f "$desktop_file" ]; then \
            sed -i 's/^Exec=\([^ ]*chromium[^ ]*\)/Exec=\1 --no-sandbox --test-type --password-store=basic/g' "$desktop_file"; \
        fi; \
    done && \
    echo '#!/bin/bash' > /usr/local/bin/chromium-browser && \
    echo 'exec /usr/bin/chromium-browser --no-sandbox --test-type --password-store=basic "$@"' >> /usr/local/bin/chromium-browser && \
    chmod +x /usr/local/bin/chromium-browser && \
    echo '#!/bin/bash' > /usr/local/bin/chromium && \
    echo 'exec /usr/bin/chromium --no-sandbox --test-type --password-store=basic "$@"' >> /usr/local/bin/chromium && \
    chmod +x /usr/local/bin/chromium && \
    dnf upgrade -y && \
    dnf clean all && \
    rm -rf /var/cache/dnf

############################################## anland_kde(wayland) 支持 ################################################
RUN if [ "$ENABLE_anland_kde_ARG" = "true" ] && ([ "$BUILD_KDE" = "min" ] || [ "$BUILD_KDE" = "conc" ] || [ "$BUILD_KDE" = "mobile" ]); then \
        if [ -z "$ANLAND_KDE_RELEASE_TAG" ]; then \
            echo "错误：Docker 构建必须传入固定的 ANLAND_KDE_RELEASE_TAG。" >&2; \
            exit 1; \
        fi && \
        echo "--> [开启] 正在安装 anland_kde..." && \
        echo "--> [开启] 从固定滚动 Release 下载预编译包 (${ANLAND_KDE_PACKAGE_REVISION})..." && \
        ANLAND_KDE_RELEASE_REPOSITORY="$ANLAND_KDE_RELEASE_REPOSITORY" \
        ANLAND_KDE_RELEASE_TAG="$ANLAND_KDE_RELEASE_TAG" \
        /usr/local/sbin/install-anland-kde && \
        echo "--> [开启] anland_kde 支持已安装"; \
    fi

# 强制配置使用 iptables-legacy（兼容 Android 内核的硬性要求）
RUN ln -sf /usr/sbin/iptables-legacy /usr/sbin/iptables && \
    ln -sf /usr/sbin/ip6tables-legacy /usr/sbin/ip6tables && \
    ln -sf /usr/sbin/iptables-legacy-save /usr/sbin/iptables-save && \
    ln -sf /usr/sbin/iptables-legacy-restore /usr/sbin/iptables-restore && \
    ln -sf /usr/sbin/ip6tables-legacy-save /usr/sbin/ip6tables-save && \
    ln -sf /usr/sbin/ip6tables-legacy-restore /usr/sbin/ip6tables-restore

RUN if [ "$ENABLE_zh_tz_ARG" = "true" ]; then \
        ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
        echo "Asia/Shanghai" > /etc/timezone && \
        echo "LANG=zh_CN.UTF-8" > /etc/locale.conf && \
        echo "LC_ALL=zh_CN.UTF-8" >> /etc/locale.conf; \
    else \
        echo "LANG=en_US.UTF-8" > /etc/locale.conf && \
        echo "LC_ALL=en_US.UTF-8" >> /etc/locale.conf; \
    fi && \
    # 配置 SSH 服务
    mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    # 删除默认可能存在的用户并创建新用户
    (userdel -r debian 2>/dev/null || true) && \
    if [ "${CUSTOM_UID:-}" = "0" ]; then useradd -m -s /bin/bash "${USERNAME}"; else useradd -m -s /bin/bash -o -u "${CUSTOM_UID}" "${USERNAME}"; fi && echo "${USERNAME}:1234" | chpasswd 

# 为所有 Fedora RootFS 安装 Droidspaces USB Manager
RUN /usr/local/sbin/install-droidspaces-usb-manager --user "${USERNAME}"

# 添加环境变量
RUN cat <<'EOF' > /etc/environment
XCURSOR_SIZE=48
EOF
RUN if [ "$ENABLE_anland_kde_ARG" != "true" ]; then \
        echo "DISPLAY=:5" >> /etc/environment; \
    else \
        echo "WAYLAND_DISPLAY=wayland-0" >> /etc/environment; \
        echo "QT_QPA_PLATFORM=wayland" >> /etc/environment; \
        echo "ANLAND=1" >> /etc/environment; \
        echo "ANLAND_SOCKET=/run/display.sock" >> /etc/environment; \
        echo "ANLAND_DRM_DEVICE=/dev/dri/renderD128" >> /etc/environment; \
        if [ "$ENABLE_mesa_ARG" = "true" ]; then \
            echo "MESA_LOADER_DRIVER_OVERRIDE=kgsl" >> /etc/environment; \
            echo "GALLIUM_DRIVER=kgsl" >> /etc/environment; \
            echo "FD_FORCE_KGSL=1" >> /etc/environment; \
        fi; \
    fi

# 修复骁龙8 Gen 2 设备在 Wayland 下的花屏问题
RUN if [ "$ENABLE_8gen2_wayland_ARG" = "true" ]; then \
        echo "FD_DEV_FEATURES=enable_tp_ubwc_flag_hint=1" >> /etc/environment; \
    fi
# 音频选择
RUN if [ "$PulseAudio" = "socket" ]; then \
        echo "PULSE_SERVER=unix:/tmp/.pulse-socket" >> /etc/environment; \
    elif [ "$PulseAudio" = "tcp" ]; then \
        echo "PULSE_SERVER=tcp:127.0.0.1:4713" >> /etc/environment; \
    fi

# 输入法开机自启动
COPY scripts/start/ /tmp/droidspaces-start/
RUN sed -i "s/^.*User=1000.*$/User=$CUSTOM_UID/" /tmp/droidspaces-start/*
RUN <<'EOF_RUN'
    if [ "$ENABLE_srf_ARG" = "true" ]; then
    mkdir -p /home/${USERNAME}/.config/autostart
    cat <<'EOF' > /home/${USERNAME}/.config/autostart/fcitx5.desktop
[Desktop Entry]
Name=Fcitx5
GenericName=Input Method
Comment=Start Input Method
Exec=fcitx5 -d
Icon=fcitx
Terminal=false
Type=Application
Categories=System;Utility;
StartupNotify=false
NoDisplay=true
EOF
    cat <<'EOF' >> /etc/environment
XMODIFIERS=@im=fcitx5
GTK_IM_MODULE=fcitx5
QT_IM_MODULE=fcitx5
SDL_IM_MODULE=fcitx5
GLFW_IM_MODULE=fcitx
EOF
    fi

    if [ "$ENABLE_mesa_ARG" = "true" ] && [ "$ENABLE_anland_kde_ARG" != "true" ] ; then
        cat <<'EOF' >> /etc/environment
MESA_LOADER_DRIVER_OVERRIDE=kgsl
TU_DEBUG=noconform
EOF
    fi

    echo 'export XDG_RUNTIME_DIR=/run/user/$(id -u)' >> /home/${USERNAME}/.bashrc
    if [ "$BUILD_KDE" = "min" ] || [ "$BUILD_KDE" = "conc" ] ; then
    mkdir -p /home/${USERNAME}/.config
    cat <<'EOF' > /home/${USERNAME}/.config/kwinrc
[Compositing]
Enabled=false
EOF
    fi
    chown -R ${USERNAME}:${USERNAME} /home/${USERNAME}
    if [ "$BUILD_KDE_plus" = "true" ] && [ "$BUILD_KDE" = "mobile" ] ; then
    install -Dm644 /tmp/droidspaces-start/plasma-mobile.service /etc/systemd/system/plasma-mobile.service
    mkdir -p /etc/systemd/system/multi-user.target.wants
    ln -sf /etc/systemd/system/plasma-mobile.service /etc/systemd/system/multi-user.target.wants/plasma-mobile.service
    fi
    if [ "$BUILD_KDE_plus" = "true" ] && [ "$ENABLE_anland_kde_ARG" != "true" ] && [ "$BUILD_KDE" != "mobile" ] ; then
    install -Dm644 /tmp/droidspaces-start/plasma-x11.service /etc/systemd/system/plasma-x11.service
    mkdir -p /etc/systemd/system/multi-user.target.wants
    ln -sf /etc/systemd/system/plasma-x11.service /etc/systemd/system/multi-user.target.wants/plasma-x11.service
    fi
    # KDE wayland 自启动
    if [ "$BUILD_KDE_plus" = "true" ] && [ "$ENABLE_anland_kde_ARG" = "true" ] && [ "$BUILD_KDE" != "mobile" ] ; then
    install -Dm644 /tmp/droidspaces-start/plasma-wayland.service /etc/systemd/system/plasma-wayland.service
    mkdir -p /etc/systemd/system/multi-user.target.wants
    ln -sf /etc/systemd/system/plasma-wayland.service /etc/systemd/system/multi-user.target.wants/plasma-wayland.service
    fi
    rm -rf /tmp/droidspaces-start
EOF_RUN

RUN if [ "$ENABLE_mesa_ARG" = "true" ]; then \
        echo "--> [开启] 正在下载并安装最新版 Mesa 驱动..." && \
        URL=$(curl -s https://api.github.com/repos/lfdevs/mesa-for-android-container/releases/latest | \
        jq -r '.assets[] | select(.name | test("mesa-for-android-container_.*_fedora_43_arm64\\.tar\\.gz")) | .browser_download_url' | head -1) && \
        if [ -z "$URL" ] || [ "$URL" = "null" ]; then echo "获取下载链接失败，可能触发了 GitHub API 限制，或不存在适用于 fedora_43 的包"; exit 1; fi && \
        wget -q --tries=5 --waitretry=3 -O /tmp/mesa.tar.gz "$URL" && \
        tar -zxf /tmp/mesa.tar.gz -C / && \
        rm /tmp/mesa.tar.gz && \
        ldconfig; \
    else \
        echo "--> [跳过] 未开启 Mesa 驱动安装"; \
    fi

# 修复容器内的 DHCP 网络服务配置
RUN mkdir -p /etc/systemd/network && \
    cat <<'EOF' > /etc/systemd/network/10-eth-dhcp.network
[Match]
Name=eth*

[Network]
DHCP=yes
IPv6AcceptRA=yes

[DHCPv4]
UseDNS=yes
UseDomains=yes
RouteMetric=100
EOF

# 应用 Android 运行环境兼容性修复（重点针对 Systemd 和 Udev）
RUN <<'EOF_RUN'

# --- 1. 常规兼容性修复 ---
grep -q '^aid_inet:' /etc/group     || echo 'aid_inet:x:3003:'    >> /etc/group
grep -q '^aid_net_raw:' /etc/group || echo 'aid_net_raw:x:3004:' >> /etc/group
grep -q '^aid_net_admin:' /etc/group || echo 'aid_net_admin:x:3005:' >> /etc/group

getent group droidspaces-gpu >/dev/null || groupadd -g 786 -r droidspaces-gpu

usermod -a -G aid_inet,aid_net_raw,input,video,tty,droidspaces-gpu root || true
usermod -a -G aid_inet,aid_net_raw,input,video,tty,wheel,droidspaces-gpu ${USERNAME} || true

# 确保未来通过 useradd 创建的新用户也会进入附加组 (Fedora 通过 /etc/default/useradd 处理)
if [ -f /etc/default/useradd ]; then
    sed -i '/^GROUPS=/d' /etc/default/useradd
    echo 'GROUPS="aid_inet,aid_net_raw,input,video,tty"' >> /etc/default/useradd
fi

# --- 2. 针对 Systemd 的特定修复 ---
ln -sf /dev/null /etc/systemd/system/systemd-networkd-wait-online.service
ln -sf /dev/null /etc/systemd/system/systemd-journald-audit.socket

cat >> /etc/systemd/journald.conf << 'EOT'
[Journal]
ReadKMsg=no
Audit=no
Storage=volatile
EOT

mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/ds-logging.conf << 'EOT'
[Journal]
SystemMaxUse=200M
RuntimeMaxUse=200M
MaxRetentionSec=7day
MaxLevelStore=info
EOT

mkdir -p /etc/systemd/system/multi-user.target.wants
GUEST_SYSTEMD_PATH="/usr/lib/systemd/system"

if [ -f "$GUEST_SYSTEMD_PATH/dbus.service" ]; then
    ln -sf "$GUEST_SYSTEMD_PATH/dbus.service" "/etc/systemd/system/multi-user.target.wants/dbus.service"
fi

if [ "$ENABLE_yj_ARG" = "true" ]; then
    for service in systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do
        if [ -f "$GUEST_SYSTEMD_PATH/$service" ]; then
            ln -sf "$GUEST_SYSTEMD_PATH/$service" "/etc/systemd/system/multi-user.target.wants/$service"
        fi
    done
else
    # 未启用硬件支持时，屏蔽容器内不需要的系统服务
    for service in systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do
        ln -sf /dev/null "/etc/systemd/system/$service"
    done
fi

mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/99-power-key.conf << 'EOF'
[Login]
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandlePowerKeyLongPress=ignore
HandlePowerKeyLongPressHibernate=ignore
EOF

# 应用 udev 覆盖配置
mkdir -p /etc/systemd/system/systemd-udev-trigger.service.d
cat > /etc/systemd/system/systemd-udev-trigger.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/udevadm trigger --subsystem-match=usb --subsystem-match=block --subsystem-match=input --subsystem-match=tty --subsystem-match=net
EOF

for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service systemd-udevd-kernel.socket systemd-udevd-control.socket; do
    mkdir -p "/etc/systemd/system/${unit}.d"
    printf "[Unit]\nConditionPathIsReadWrite=\n" > "/etc/systemd/system/${unit}.d/99-readonly-fix.conf"
done

# 仅在 NAT 或网关网络模式下启动网络服务
for unit in NetworkManager.service dhcpcd.service systemd-resolved.service systemd-networkd.service; do
    if [ -f "$GUEST_SYSTEMD_PATH/$unit" ] || [ -f "/etc/systemd/system/multi-user.target.wants/$unit" ]; then
        mkdir -p "/etc/systemd/system/${unit}.d"
        cat > "/etc/systemd/system/${unit}.d/99-netmode-limit.conf" << 'EOF'
[Service]
ExecCondition=
ExecCondition=/bin/sh -c "grep -qE 'net_mode=(nat|gateway)' /run/droidspaces/container.config"
EOF
    fi
done

for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service; do
    if [ -f "$GUEST_SYSTEMD_PATH/$unit" ] || [ -f "/etc/systemd/system/multi-user.target.wants/$unit" ]; then
        mkdir -p "/etc/systemd/system/${unit}.d"
        cat > "/etc/systemd/system/${unit}.d/99-hwaccess-limit.conf" << 'EOF'
[Service]
ExecCondition=
ExecCondition=/bin/sh -c "grep -q 'enable_hw_access=1' /run/droidspaces/container.config"
EOF
    fi
done

# --- 3. Droidspaces NAT 与 DNS 兼容修复 ---
# 使用标准 glibc 域名解析，/etc/resolv.conf 由 Droidspaces 或 DHCP 解析器管理
sed -i 's/^hosts:.*/hosts: files dns myhostname/' /etc/nsswitch.conf

# 为 NAT 模式创建以 root 权限运行的 DHCP 服务
cat > /etc/systemd/system/ds-dhcp.service << 'EOF_DHCP'
[Unit]
Description=Droidspaces NAT DHCP (Root Bypass)
After=network.target

[Service]
Type=forking
ExecCondition=/bin/sh -c "grep -qE 'net_mode=(nat|gateway)' /run/droidspaces/container.config"
ExecStart=/usr/sbin/dhclient
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF_DHCP
ln -sf /etc/systemd/system/ds-dhcp.service /etc/systemd/system/multi-user.target.wants/ds-dhcp.service

if [ -f /etc/logrotate.conf ]; then
    sed -i 's/^#maxsize.*/maxsize 50M/' /etc/logrotate.conf
    if ! grep -q "maxsize 50M" /etc/logrotate.conf; then
        echo "maxsize 50M" >> /etc/logrotate.conf
    fi
fi

echo "Post-extraction fixes applied on $(date)" > /etc/droidspaces
EOF_RUN


COPY scripts/binfmt/qemu-binfmt-register.sh /usr/local/bin/
COPY scripts/binfmt/qemu-binfmt-register.service /etc/systemd/system/
RUN if [ "$ENABLE_binfmt_ARG" = "false" ]; then \
        rm -rf /usr/local/bin/qemu-binfmt-register.sh && \
        rm -rf /etc/systemd/system/qemu-binfmt-register.service ; \
    fi

# 注意：Fedora 无法像 Debian 的 dpkg 那样直接添加 amd64 异构架构
RUN if [ "$ENABLE_binfmt_ARG" = "true" ]; then \
        chmod +x /usr/local/bin/qemu-binfmt-register.sh && \
        chmod 644 /etc/systemd/system/qemu-binfmt-register.service && \
        mkdir -p /etc/systemd/system/multi-user.target.wants && \
        ln -sf /etc/systemd/system/qemu-binfmt-register.service /etc/systemd/system/multi-user.target.wants/qemu-binfmt-register.service && \
        dnf install -y --setopt=install_weak_deps=False qemu-user-static; \
    else \
        rm -f /usr/local/bin/qemu-binfmt-register.sh /etc/systemd/system/qemu-binfmt-register.service; \
    fi

# 可选：为 systemd 258+ 发行版构建 systemd 257 旧内核兼容运行时。
RUN if [ "$ENABLE_systemd257_ARG" = "true" ]; then \
        bash /usr/local/sbin/systemd257; \
    else \
        echo "--> [跳过] 未启用 systemd 257 旧内核兼容"; \
    fi && \
    rm -f /usr/local/sbin/systemd257

# 最终清理 DNF 缓存以缩减镜像体积
RUN dnf clean all && \
    rm -rf /var/cache/dnf/* /tmp/* /var/tmp/*

# 阶段 2：将完整的根文件系统导出到 scratch
FROM scratch AS export

COPY --from=customizer / /
