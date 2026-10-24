# The Linux desktop test image of the e2e device round
# (e2e/stratum_e2e/round/linux_docker.py), built from the host's
# Flutter version with no third-party image. FLUTTER_VERSION is the host's
# `frameworkVersion` (a tag of github.com/flutter/flutter). The first build
# clones Flutter and precaches the Linux artifacts (several minutes); later
# rounds reuse the image, tagged stratum-e2e-linux:<version>-<hash>.
# EXTRA_APT holds the project's `[targets.<t>] apt` list (plugins' native
# packages, read out of a CMake "required packages were not found" error);
# the default list is Flutter's own Linux desktop set plus libsecret-1-dev,
# and rsync for the round's source sync into the target's work volume.
FROM ubuntu:24.04
ARG FLUTTER_VERSION
ARG EXTRA_APT=""
ARG DEBIAN_FRONTEND=noninteractive
RUN set -eu; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      git curl unzip xz-utils zip ca-certificates \
      clang cmake ninja-build pkg-config libgtk-3-dev libglu1-mesa xvfb \
      libsecret-1-dev rsync $EXTRA_APT; \
    rm -rf /var/lib/apt/lists/*
RUN set -eu; \
    git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git /opt/flutter; \
    git config --global --add safe.directory /opt/flutter; \
    git config --global --add safe.directory /work; \
    git config --global --add safe.directory '*'
ENV PATH="/opt/flutter/bin:${PATH}"
RUN set -eu; \
    flutter config --no-analytics --enable-linux-desktop; \
    flutter precache --linux; \
    flutter --version
WORKDIR /work
