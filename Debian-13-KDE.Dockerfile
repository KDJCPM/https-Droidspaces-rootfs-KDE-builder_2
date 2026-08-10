ARG TARGETPLATFORM
FROM debian:trixie AS customizer

#######################################################
ARG BUILD_KDE
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

# 启用 APT 并行连接、HTTP(S) pipeline 和下载重试
RUN printf '%s\n' \
    'Acquire::Queue-Mode "host";' \
    'Acquire::http::Pipeline-Depth "10";' \
    'Acquire::https::Pipeline-Depth "10";' \
    'Acquire::Retries "3";' \
    > /etc/apt/apt.conf.d/99parallel-downloads

# 更新基础系统并启用 non-free（非自由）和 contrib 软件源
RUN (sed -i 's/main/main contrib non-free/g' /etc/apt/sources.list 2>/dev/null || sed -i 's/Components: main/Components: main contrib non-free/g' /etc/apt/sources.list.d/debian.sources) && \
    apt-get update && \
    apt-get upgrade -y

# 优先复制自定义脚本
COPY scripts/download-firmware /usr/local/bin/

# 将自定义的 bashrc 脚本复制到根文件系统的 profile 目录
COPY scripts/bashrc.sh /etc/profile.d/ds-aliases.sh

# 通用 Droidspaces USB Manager 安装器
COPY scripts/install-usb-manager.sh /usr/local/sbin/install-droidspaces-usb-manager
COPY scripts/systemd257.sh /usr/local/sbin/systemd257
COPY scripts/install-anland-kde.sh /usr/local/sbin/install-anland-kde

# 赋予相关脚本可执行权限
RUN chmod +x /usr/local/bin/download-firmware /etc/profile.d/ds-aliases.sh /usr/local/sbin/install-anland-kde

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # 核心工具组件
    bash jq dialog coreutils file findutils grep sed gawk curl wget ca-certificates locales bash-completion udev dbus systemd-sysv systemd-resolved fastfetch \
    # 用户请求的基础开发/编辑工具
    git nano  sudo \
    # 网络与 SSH 工具
    openssh-server net-tools iptables iputils-ping iproute2 dnsutils \
    # 用于系统监控的 procps 进程工具
    procps \
    # 核心内核模块支持
    kmod tzdata tar && \
    ############################################## KDE支持 ################################################
    # 最小化KDE
    if [ "$BUILD_KDE" = "min" ]; then \
        apt-get install -y --no-install-recommends \
        dbus-x11 x11-xserver-utils fonts-noto-cjk fonts-noto-color-emoji kde-plasma-desktop pipewire pipewire-pulse wireplumber powerdevil kscreen plasma-pa ark kwin-x11 upower konsole \
        dolphin kate kinfocenter mesa-utils pulseaudio-utils vulkan-tools  desktop-base dbus-user-session; \
    fi && \
    # 精简KDE
    if [ "$BUILD_KDE" = "conc" ]; then \
        apt-get install -y --no-install-recommends \
        dbus-x11 x11-xserver-utils fonts-noto-cjk fonts-noto-color-emoji kde-plasma-desktop pipewire pipewire-pulse wireplumber powerdevil kscreen plasma-pa ark kwin-x11 upower konsole \
        dolphin kate kinfocenter mesa-utils pulseaudio-utils vulkan-tools  desktop-base dbus-user-session aha clinfo dmidecode libdisplay-info-bin wayland-utils xserver-xorg \
        kfind plasma-systemmonitor filelight glmark2 vkmark systemsettings kde-config-screenlocker kio-extras xdg-user-dirs dolphin-plugins ffmpegthumbs kdegraphics-thumbnailers \
        kimageformat6-plugins webext-plasma-browser-integration libcanberra-pulse gstreamer1.0-plugins-base gstreamer1.0-plugins-good sound-theme-freedesktop chromium chromium-l10n \
        systemsettings kde-config-screenlocker kio-extras xdg-user-dirs; \
    fi && \
    # mobile版KDE
    if [ "$BUILD_KDE" = "mobile" ]; then \
        apt-get install -y --no-install-recommends \
        dbus-x11 x11-xserver-utils fonts-noto-cjk fonts-noto-color-emoji wayland-utils xserver-xorg dbus-user-session \
        plasma-nano plasma-mobile plasma-mobile-phone maliit-keyboard maliit-framework \
        kwin-wayland pipewire pipewire-pulse wireplumber powerdevil plasma-pa upower pulseaudio-utils \
        konsole dolphin kate kinfocenter mesa-utils vulkan-tools \
        systemsettings plasma-systemmonitor kde-config-screenlocker kio-extras xdg-user-dirs \
        dolphin-plugins ffmpegthumbs kdegraphics-thumbnailers kimageformat6-plugins plasma-settings angelfish \
        gstreamer1.0-plugins-base gstreamer1.0-plugins-good sound-theme-freedesktop libcanberra-pulse \
        gstreamer1.0-plugins-base gstreamer1.0-plugins-good sound-theme-freedesktop libcanberra-pulse \
        polkit-kde-agent-1 libpam-systemd libpam-modules libpam-kwallet5 \
        breeze-icon-theme plasma-desktoptheme libqt6svg6 qt6-svg-plugins \
        qml6-module-org-kde-kirigami qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-templates && \
        echo "--> [mobile] 正在移除 ModemManager (容器内无真实 modem 硬件，会导致开机卡住)..." && \
        apt-get purge -y --auto-remove modemmanager || true; \
    fi && \
    ############################################## anland_kde(wayland) 支持 ################################################
    if [ "$ENABLE_anland_kde_ARG" = "true" ] && ([ "$BUILD_KDE" = "min" ] || [ "$BUILD_KDE" = "conc" ] || [ "$BUILD_KDE" = "mobile" ]); then \
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
    fi && \
    ######################################################################################################
    #输入法 fcitx5 (可选)
    if [ "$ENABLE_srf_ARG" = "true" ]; then \
        apt-get install -y fcitx5; \
    fi && \
    if [ "$ENABLE_srf_ARG" = "true" ] && [ "$ENABLE_zh_tz_ARG" = "true" ]; then \
        apt-get install -y  fcitx5-chinese-addons; \
    fi && \
    ## 开发工具集成 (可选)
    if [ "$ENABLE_kfgj_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends \
        build-essential gcc g++ make cmake autoconf automake libtool pkg-config clang llvm python3 python3-pip python3-dev python3-venv python-is-python3; \
    fi && \
    ## 压缩工具扩展 (可选)
    if [ "$ENABLE_zip_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends \
        zip unzip p7zip-full bzip2 xz-utils tar gzip; \
    fi && \
    ## docker (可选)
    if [ "$ENABLE_docker_ARG" = "true" ]; then \
        apt-get install -y --no-install-recommends \
        docker.io docker-compose docker-cli; \
    fi && \
    ## 集成tmoe (可选)
    if [ "$ENABLE_tmoe_ARG" = "true" ]; then \
        git clone --depth=1 https://github.com/2moe/tmoe-linux.git /usr/local/etc/tmoe-linux/git && \
        ln -sf /usr/local/etc/tmoe-linux/git/debian.sh /usr/local/bin/tmoe && \
        chmod -R 755 /usr/local/etc/tmoe-linux; \
    fi && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 强制配置使用 iptables-legacy（这是兼容 Android 内核的硬性要求）
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy && \
    update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy

RUN sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen && \
    if [ "$ENABLE_zh_tz_ARG" = "true" ]; then \
        export DEBIAN_FRONTEND=noninteractive && \
        ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
        echo "Asia/Shanghai" > /etc/timezone && \
        dpkg-reconfigure -f noninteractive tzdata && \
        sed -i '/zh_CN.UTF-8/s/^# //' /etc/locale.gen && \
        locale-gen && \
        update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8; \
    else \
        locale-gen && \
        update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8; \
    fi && \
    # 配置 SSH 服务（禁用 root 密码登录，但允许常规密码认证）
    mkdir -p /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    # 如果容器内存在默认的 debian 用户，则将其连同家目录一起删除
    deluser --remove-home debian || true && \
    useradd -m -s /bin/bash ${USERNAME} && echo "${USERNAME}:1234" | chpasswd 

# 为所有 Debian RootFS 安装 Droidspaces USB Manager
RUN /usr/local/sbin/install-droidspaces-usb-manager --user "${USERNAME}"

# 添加环境变量
RUN cat <<'EOF' > /etc/environment
XCURSOR_SIZE=48
EOF
# wayland 显示服务器环境变量配置
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

# 修复anland 音频堵塞
# RUN if [ "$ENABLE_anland_kde_ARG" = "true" ]; then \
#        mkdir -p /home/${USERNAME}/.config && \
#       echo -e "\n[Sounds]\nEnable=false" >> /home/${USERNAME}/.config/kdeglobals ; \
#     fi

# 输入法开机自启动
COPY scripts/start/ /tmp/droidspaces-start/
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
    # KDE X11 自启动
    # KDE mobile 自启动
    if [ "$BUILD_KDE_plus" = "true" ] && [ "$BUILD_KDE" = "mobile" ] ; then
    install -Dm644 /tmp/droidspaces-start/plasma-mobile.service /etc/systemd/system/plasma-mobile.service
    mkdir -p /etc/systemd/system/multi-user.target.wants
    ln -sf /etc/systemd/system/plasma-mobile.service /etc/systemd/system/multi-user.target.wants/plasma-mobile.service
    fi
    # KDE X11 自启动
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


# Mesa 驱动适配
RUN if [ "$ENABLE_mesa_ARG" = "true" ]; then \
        echo "--> [开启] 正在下载并安装最新版 Mesa 驱动..." && \
        URL=$(curl -s https://api.github.com/repos/lfdevs/mesa-for-android-container/releases/latest | \
        jq -r '.assets[] | select(.name | test("mesa-for-android-container_.*_debian_trixie_arm64\\.tar\\.gz")) | .browser_download_url' | head -1) && \
        if [ -z "$URL" ] || [ "$URL" = "null" ]; then echo "获取下载链接失败，可能是触发了 GitHub API 速率限制"; exit 1; fi && \
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
# 建立 Android 网络权限组（在 Android 内核上运行 Linux 容器时，必须有这些 GID 才能正常访问网络 socket）
grep -q '^aid_inet:' /etc/group     || echo 'aid_inet:x:3003:'    >> /etc/group
grep -q '^aid_net_raw:' /etc/group || echo 'aid_net_raw:x:3004:' >> /etc/group
grep -q '^aid_net_admin:' /etc/group || echo 'aid_net_admin:x:3005:' >> /etc/group

# 检查并创建 droidspaces-gpu 组
getent group droidspaces-gpu >/dev/null || groupadd -g 786 -r droidspaces-gpu
# 为 root 用户赋予访问 Android 硬件及网络的权限组
usermod -a -G aid_inet,aid_net_raw,input,video,tty,droidspaces-gpu root || true
usermod -a -G aid_inet,aid_net_raw,input,video,tty,sudo,droidspaces-gpu ${USERNAME} || true

# 将 _apt 的主用户组改为 aid_inet，确保 apt 包管理器在 Android 环境下可以正常联网
grep -q '^_apt:' /etc/passwd && usermod -g aid_inet _apt || true

# 确保未来通过 adduser 创建的所有新用户，都会被默认加入这些 Android 硬件与网络组
if [ -f /etc/adduser.conf ]; then
    sed -i '/^EXTRA_GROUPS=/d; /^ADD_EXTRA_GROUPS=/d' /etc/adduser.conf
    echo 'ADD_EXTRA_GROUPS=1' >> /etc/adduser.conf
    echo 'EXTRA_GROUPS="aid_inet aid_net_raw input video tty"' >> /etc/adduser.conf
fi

# --- 2. 针对 Systemd 的特定修复 ---
# 屏蔽在 Android 内核下容易引发报错或死锁的阻塞服务
ln -sf /dev/null /etc/systemd/system/systemd-networkd-wait-online.service
ln -sf /dev/null /etc/systemd/system/systemd-journald-audit.socket

# 优化 Journald 日志配置（跳过内核审计、KMsg 等 Android 内核不兼容或权限受限的日志源）
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
GUEST_SYSTEMD_PATH="/lib/systemd/system"

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
    for service in systemd-udevd.service systemd-resolved.service systemd-networkd.service NetworkManager.service; do
        ln -sf /dev/null "/etc/systemd/system/$service"
    done
fi

# 在 systemd-logind 中禁用电源键行为处理（防止容器误拦截或处理宿主机的实体电源按键事件）
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
# 1. 触发器覆盖：限制 udevadm trigger 的扫描范围（防止冷插拔时全面扫描 Android 宿主机硬件导致卡死或冲突）
mkdir -p /etc/systemd/system/systemd-udev-trigger.service.d
cat > /etc/systemd/system/systemd-udev-trigger.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/udevadm trigger --subsystem-match=usb --subsystem-match=block --subsystem-match=input --subsystem-match=tty --subsystem-match=net
EOF

# 2. 针对只读文件系统路径（ConditionPathIsReadWrite）的覆盖，防止 udev 相关服务因为路径只读而报错中断
for unit in systemd-udevd.service systemd-udev-trigger.service systemd-udev-settle.service systemd-udevd-kernel.socket systemd-udevd-control.socket; do
    mkdir -p "/etc/systemd/system/${unit}.d"
    printf "[Unit]\nConditionPathIsReadWrite=\n" > "/etc/systemd/system/${unit}.d/99-readonly-fix.conf"
done

# 限制特定的网络服务：只有当容器配置为 NAT 模式时才允许启动
# 这可以有效防止容器在“主机网络模式（Host Mode）”下运行时破坏手机原本的蜂窝移动数据网络
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
# 仅在启用硬件访问时限制 udev 服务启动
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

# 针对 Android 环境微调日志轮转（logrotate）的最大容量限制
if [ -f /etc/logrotate.conf ]; then
    sed -i 's/^#maxsize.*/maxsize 50M/' /etc/logrotate.conf
    if ! grep -q "maxsize 50M" /etc/logrotate.conf; then
        echo "maxsize 50M" >> /etc/logrotate.conf
    fi
fi



# 写入修复完成的标记和时间戳
echo "Post-extraction fixes applied on $(date)" > /etc/droidspaces
EOF_RUN


COPY scripts/binfmt/qemu-binfmt-register.sh /usr/local/bin/
COPY scripts/binfmt/qemu-binfmt-register.service /etc/systemd/system/
RUN if [ "$ENABLE_binfmt_ARG" = "false" ]; then \
        rm -rf /usr/local/bin/qemu-binfmt-register.sh && \
        rm -rf /etc/systemd/system/qemu-binfmt-register.service ; \
    fi

RUN if [ "$ENABLE_binfmt_ARG" = "true" ]; then \
        chmod +x /usr/local/bin/qemu-binfmt-register.sh && \
        chmod 644 /etc/systemd/system/qemu-binfmt-register.service && \
        mkdir -p /etc/systemd/system/multi-user.target.wants && \
        ln -sf /etc/systemd/system/qemu-binfmt-register.service /etc/systemd/system/multi-user.target.wants/qemu-binfmt-register.service && \
        (apt-get purge -y qemu-* binfmt-support || true) && \
        apt-get autoremove -y && \
        apt-get autoclean && \
        rm -rf /var/lib/binfmts/* /etc/binfmt.d/* /usr/lib/binfmt.d/qemu-* && \
        apt-get update && \
        apt-get install -y qemu-user-static binfmt-support && \
        # 显式添加 amd64 异构架构支持
        dpkg --add-architecture amd64 && \
        apt-get update && \
        apt-get install -y libc6:amd64; \
    else \
        rm -f /usr/local/bin/qemu-binfmt-register.sh /etc/systemd/system/qemu-binfmt-register.service; \
    fi

# Debian 13 当前为 systemd 257，脚本会自动检测并跳过；保留统一选项便于未来版本。
RUN if [ "$ENABLE_systemd257_ARG" = "true" ]; then \
        bash /usr/local/sbin/systemd257; \
    else \
        echo "--> [跳过] 未启用 systemd 257 旧内核兼容"; \
    fi && \
    rm -f /usr/local/sbin/systemd257

# 最终清理 APT 包管理器缓存，尽可能缩减镜像层体积
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# 阶段 2：将完整的根文件系统导出到 scratch（空白层），以便外部直接提取或打包成 tarfs
FROM scratch AS export

# 从 customizer 编译阶段将所有定制好的根文件系统内容整体拷贝出来
COPY --from=customizer / /
