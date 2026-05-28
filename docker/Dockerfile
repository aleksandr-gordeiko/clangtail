# syntax=docker/dockerfile:1
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN sed -i 's/archive.ubuntu.com/mirror.yandex.ru/g' /etc/apt/sources.list
RUN sed -i 's/security.ubuntu.com/mirror.yandex.ru/g' /etc/apt/sources.list

RUN apt-get update && apt-get install -y --no-install-recommends \
    # LLVM build essentials
    build-essential \
    ca-certificates \
    cmake \
    ninja-build \
    git \
    python3 \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-venv \
    pkg-config \
    ccache \
    lld \
    clang \
    makeself \
    # common LLVM optional deps
    zlib1g-dev \
    libzstd-dev \
    libxml2-dev \
    libedit-dev \
    libncurses-dev \
    libffi-dev \
    libssl-dev \
    swig \
    # debugging/dev tools
    gdb \
    lldb \
    strace \
    file \
    wget \
    curl \
    xz-utils \
    unzip \
    rsync \
    sudo \
    # non-root image mounting / inspection
    fuse3 \
    libfuse3-dev \
    squashfuse \
    squashfs-tools \
    erofs-utils \
    e2fsprogs \
    btrfs-progs \
    xfsprogs \
    dosfstools \
    mtools \
    guestmount \
    libguestfs-tools \
    qemu-utils \
    udisks2 \
    linux-image-generic \
    && rm -rf /var/lib/apt/lists/*

# Useful for libguestfs inside containers
ENV LIBGUESTFS_BACKEND=direct

# Configure user
ARG USERNAME=ubuntu

RUN usermod -aG sudo ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

USER ${USERNAME}
WORKDIR /home/${USERNAME}
ENV HOME=/home/${USERNAME}
