FROM ubuntu:20.04
RUN apt-get update \
    && apt-get install -y \
          wget \
          unzip \
          curl \
          sudo

# Install ttyd
RUN VER=$( curl --silent "https://api.github.com/repos/tsl0922/ttyd/releases/latest"| grep '"tag_name"'|sed -E 's/.*"([^"]+)".*/\1/') \
    && curl -LO https://github.com/tsl0922/ttyd/releases/download/$VER/ttyd.x86_64 \
    && mv ttyd.* /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd

RUN useradd --user-group --create-home --no-log-init --shell /bin/bash snowflake
RUN adduser snowflake sudo && \
    sed -i 's/sudo\tALL=(ALL:ALL) ALL/sudo\tALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers

RUN mkdir -p /model/store \
    && mkdir -p /model/temp \
    && mkdir /model-store \
    && chmod -R 777 /model-store \
    && chmod -R 777 /model

USER snowflake
WORKDIR /home/snowflake

RUN wget --content-disposition https://api.ngc.nvidia.com/v2/resources/nvidia/ngc-apps/ngc_cli/versions/3.35.0/files/ngccli_linux.zip -O ngccli_linux.zip \
    && unzip ngccli_linux.zip \
    && chmod u+x ngc-cli/ngc \
    && echo "export PATH=\"\$PATH:$(pwd)/ngc-cli\"" >> ~/.bashrc \
    && rm ngccli_linux.zip

WORKDIR /model/temp

