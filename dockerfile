# ==========================================================
# 📦 Base Image
# ==========================================================
FROM nvcr.io/nvidia/cuda:12.8.0-cudnn-runtime-ubuntu24.04

LABEL maintainer="91mrqiao <91mrqiao@mail.nwpu.edu.cn>"
LABEL description="basic_env"

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /root

# ==========================================================
# ⚙️ Clean NVIDIA driver libraries (to avoid NVML mismatch)
# ==========================================================
RUN rm -f /usr/lib/x86_64-linux-gnu/libnvidia-ml.so* \
    && rm -f /usr/lib/x86_64-linux-gnu/libcuda.so* \
    && rm -f /usr/lib/x86_64-linux-gnu/libnvcuvid.so* \
    && rm -f /usr/lib/x86_64-linux-gnu/libnvidia-encode.so* \
    && rm -f /usr/lib/x86_64-linux-gnu/libnvidia-opticalflow.so* \
    && rm -f /usr/lib/x86_64-linux-gnu/libnvidia-ptxjitcompiler.so* \
    && rm -f /usr/local/cuda/lib64/stubs/libcuda.so* || true

# ==========================================================
# 🌏 APT Mirror & Base Packages
# ==========================================================
RUN sed -i 's|http://archive.ubuntu.com/ubuntu/|https://mirrors.tuna.tsinghua.edu.cn/ubuntu/|g' /etc/apt/sources.list && \
    sed -i 's|http://security.ubuntu.com/ubuntu/|https://mirrors.tuna.tsinghua.edu.cn/ubuntu/|g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y --no-install-recommends \
        openssh-server sudo curl wget git vim nano htop tmux \
        build-essential cmake tzdata rsync unzip ffmpeg neofetch \
        net-tools inetutils-ping && \
    rm -rf /var/lib/apt/lists/*

# ==========================================================
# 🔐 SSH Preconfiguration (Root-level)
# ==========================================================
RUN mkdir -p /var/run/sshd && \
    ssh-keygen -A && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config && \
    echo "UsePAM no" >> /etc/ssh/sshd_config && \
    echo "ClientAliveInterval 60" >> /etc/ssh/sshd_config && \
    echo "ClientAliveCountMax 3" >> /etc/ssh/sshd_config && \
    echo "root:root" | chpasswd

EXPOSE 22 8888

# ==========================================================
# 👤 Create Non-root User
# ==========================================================
ARG USERNAME=qiaohansheng
ARG USER_UID=30011
ARG USER_GID=1010

RUN groupadd --gid $USER_GID npucvr && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash && \
    echo "$USERNAME:$USERNAME" | chpasswd && \
    usermod -aG sudo $USERNAME && \
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME && \
    mkdir -p /home/$USERNAME/.ssh && chmod 700 /home/$USERNAME/.ssh

USER $USERNAME
WORKDIR /home/$USERNAME

# ==========================================================
# 🧩 Miniconda Installation
# ==========================================================
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-py312_24.7.1-0-Linux-x86_64.sh -O ~/miniconda.sh && \
    bash ~/miniconda.sh -b -p /home/$USERNAME/miniconda && \
    rm ~/miniconda.sh && \
    echo "export PATH=/home/$USERNAME/miniconda/bin:\$PATH" >> ~/.bashrc && \
    echo "source /home/$USERNAME/miniconda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> /home/$USERNAME/.bashrc && \
    /home/$USERNAME/miniconda/bin/conda config --set auto_activate_base false && \
    /home/$USERNAME/miniconda/bin/conda clean -afy

ENV PATH=/home/$USERNAME/miniconda/bin:$PATH

# ==========================================================
# 🧠 Python Environment
# ==========================================================
RUN pip install -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple --upgrade pip setuptools wheel && \
    pip install -i https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple \
        numpy scipy scikit-learn scikit-image pandas matplotlib seaborn \
        opencv-python-headless pillow tqdm \
        h5py einops tensorboard wandb \
        lightning hydra-core omegaconf \
        transformers diffusers accelerate timm \
        torchmetrics lpips \
        imageio imageio[ffmpeg] \
        pyyaml ipython jupyterlab notebook && \
    conda clean -afy

# ==========================================================
# 🚀 Entrypoint
# ==========================================================
USER $USERNAME
CMD ["sudo", "/usr/sbin/sshd", "-D"]
