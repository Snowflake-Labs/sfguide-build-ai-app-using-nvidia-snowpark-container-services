FROM nvidia/cuda:12.1.0-base-ubuntu22.04

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TZ=America/New_York

# hadolint ignore=DL3008
RUN set -x && \
    apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends \
        bzip2 \
        ca-certificates \
        git \
        libglib2.0-0 \
        libsm6 \
        libxcomposite1 \
        libxcursor1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxinerama1 \
        libxrandr2 \
        libxrender1 \
        mercurial \
        openssh-client \
        procps \
        subversion \
        wget \
        curl \
        sudo \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* && \
    UNAME_M="$(uname -m)" && \
    if [ "${UNAME_M}" = "x86_64" ]; then \
        ANACONDA_URL="https://repo.anaconda.com/archive/Anaconda3-2023.09-0-Linux-x86_64.sh"; \
        SHA256SUM="6c8a4abb36fbb711dc055b7049a23bbfd61d356de9468b41c5140f8a11abd851"; \
    elif [ "${UNAME_M}" = "aarch64" ]; then \
        ANACONDA_URL="https://repo.anaconda.com/archive/Anaconda3-2023.09-0-Linux-aarch64.sh"; \
        SHA256SUM="69ee26361c1ec974199bce5c0369e3e9a71541de7979d2b9cfa4af556d1ae0ea"; \
    fi && \
    wget "${ANACONDA_URL}" -O anaconda.sh -q && \
    echo "${SHA256SUM} anaconda.sh" > shasum && \
    sha256sum --check --status shasum && \
    /bin/bash anaconda.sh -b -p /opt/conda && \
    rm anaconda.sh shasum && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    /opt/conda/bin/conda clean -afy
RUN . /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    conda update -n base -c defaults --yes conda && \
    conda install nb_conda_kernels jupyterlab -y --quiet 
RUN useradd --user-group --create-home --no-log-init --shell /usr/bin/bash jupyter
RUN adduser jupyter sudo && \
    sed -i 's/sudo\tALL=(ALL:ALL) ALL/sudo\tALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
USER jupyter
WORKDIR /home/jupyter
ENV ENV /home/jupyter/.shrc
RUN echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc
RUN echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.shrc
RUN mkdir -p /home/jupyter/notebooks
RUN . /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    conda create --name py311_sfc --override-channels -c https://repo.anaconda.com/pkgs/snowflake python=3.11 numpy pandas ipython -y && \
    conda activate py311_sfc && \
    conda install snowflake-snowpark-python ipykernel -y --quiet && \
    python -m ipykernel install --user --name py311_sfc --display-name "Python 3.11 (Snowpark)" 
RUN . /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    conda create --name py311_nemo python=3.11 numpy pandas ipython -y && \
    conda activate py311_nemo && \
    conda install ipykernel -y --quiet && \
    pip install -q nemollm langchain langchain_openai "openai~=1.9.0" tritonclient[all] && \
    pip install -q python-dotenv && \
    python -m ipykernel install --user --name py311_nemo --display-name "Python 3.11 (Nemo)" 
RUN . /opt/conda/etc/profile.d/conda.sh && \
    conda activate base && \
    conda create --name py311_openai python=3.11 numpy pandas ipython -y && \
    conda activate py311_openai && \
    conda install ipykernel openai -y --quiet && \
    python -m ipykernel install --user --name py311_openai --display-name "Python 3.11 (OpenAI)" 
COPY --chown=jupyter:jupyter inference_nemo.ipynb ./notebooks/inference_nemo.ipynb
COPY --chown=jupyter:jupyter inference_openai.ipynb ./notebooks/inference_openai.ipynb
COPY --chown=jupyter:jupyter completions.py ./notebooks/completions.py
COPY --chown=jupyter:jupyter completions.py .conda/envs/py311_nemo/lib/python3.11/site-packages/openai/resources/completions.py
