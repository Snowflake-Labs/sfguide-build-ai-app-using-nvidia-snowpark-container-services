FROM nvcr.io/ohlfw0olaadg/ea-participants/nemollm-inference-ms:24.02

USER root
RUN apt-get update && \
    apt-get -y install sudo

RUN VER=$( curl --silent "https://api.github.com/repos/tsl0922/ttyd/releases/latest"| grep '"tag_name"'|sed -E 's/.*"([^"]+)".*/\1/') \
    && curl -LO https://github.com/tsl0922/ttyd/releases/download/$VER/ttyd.x86_64 \
    && mv ttyd.* /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd

ENV user ubuntu

RUN useradd -m -d /home/${user} ${user} && \
    chown -R ${user} /home/${user} && \
    adduser ${user} sudo && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER ${user}

WORKDIR /home/${user}

RUN sudo apt-get -y install curl && \
    sudo apt-get -y install git-lfs


RUN curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash

COPY --chown=ubuntu:ubuntu instruct.yaml /home/ubuntu/instruct.yaml
COPY --chown=ubuntu:ubuntu modelgenerator.sh /home/ubuntu/modelgenerator.sh

RUN sudo chmod 777 /model-store