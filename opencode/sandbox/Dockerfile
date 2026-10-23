# Образ песочницы ocbox: Arch Linux + инструменты, которые нужны OpenCode
# внутри контейнера.
#
# ВАЖНО: glibc образа должна быть НЕ СТАРЕЕ glibc хоста. Хостовые тулчейны
# (~/.pyenv/versions/*/bin/python, uv-tools, ~/.local/bin) собраны под glibc
# хоста и монтируются в контейнер; если образ отстал — они падают с
# "GLIBC_2.xx not found". Поэтому здесь pacman -Syu, и образ надо пересобирать
# после каждого крупного обновления хоста: ocbox build && ocbox doctor.
FROM archlinux:base

RUN pacman -Syu --noconfirm --needed \
      opencode nodejs npm git git-lfs \
      go rustup pyenv uv python \
      base-devel ripgrep fd openssh which jq less file procps-ng \
 && pacman -Scc --noconfirm

# Пользователь должен совпадать с хостовым по UID/GID: проект и хостовые
# тулчейны монтируются как есть, и файлы внутри должны быть "своими".
ARG OCBOX_UID=1000
ARG OCBOX_GID=1000
ARG OCBOX_USER=ashestopalov

RUN groupadd -g "$OCBOX_GID" "$OCBOX_USER" 2>/dev/null || true \
 && useradd -u "$OCBOX_UID" -g "$OCBOX_GID" -m -s /bin/bash "$OCBOX_USER" \
 && install -d -o "$OCBOX_UID" -g "$OCBOX_GID" "/home/$OCBOX_USER"

ENV LANG=C.UTF-8
ENV HOME="/home/$OCBOX_USER"
WORKDIR "/home/$OCBOX_USER"

# Никакого CMD по умолчанию: ocbox всегда передаёт команду явно.
CMD ["bash"]
