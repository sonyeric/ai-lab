# nvidia/cuda
# https://hub.docker.com/r/nvidia/cuda
FROM nvidia/cuda:10.0-devel-ubuntu18.04 

LABEL maintainer="Timothy Liu <timothyl@nvidia.com>"

USER root

ENV DEBIAN_FRONTEND noninteractive

# Install all OS dependencies

RUN apt-get update && \
    apt-get install -yq --no-install-recommends --no-upgrade \
    apt-utils && \
    apt-get install -yq --no-install-recommends --no-upgrade \
    curl \
    wget \
    bzip2 \
    ca-certificates \
    locales \
    fonts-liberation \
    build-essential \
    cmake \
    inkscape \
    jed \
    libsm6 \
    libxext-dev \
    libxrender1 \
    lmodern \
    netcat \
    pandoc \
    #texlive-fonts-extra \
    texlive-fonts-recommended \
    texlive-generic-recommended \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-xetex \
    ffmpeg \
    graphviz\
    git \
    nano \
    htop \
    zip \
    unzip \
    libncurses5-dev \
    libncursesw5-dev \
    libopenmpi-dev \
    libopenblas-base \
    libopenblas-dev \
    libomp-dev \
    libjpeg-dev \
    libpng-dev \
    openssh-client \
    openssh-server \
    mecab \
    mecab-ipadic-utf8 \
    libmecab-dev \
    swig \
    pkg-config \
    g++ \
    zlib1g-dev \
    protobuf-compiler \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN apt-get update && \
    apt-get install --allow-change-held-packages -yq \
    python3 \
    libcudnn7 \
    libcudnn7-dev \
    libnccl2 \
    libnccl-dev && \
    apt-get clean && \
    ldconfig && \
    rm -rf /var/lib/apt/lists/*

# Configure environment

ENV CONDA_DIR=/opt/conda \
    SHELL=/bin/bash \
    NB_USER=jovyan \
    NB_UID=1000 \
    NB_GID=100 \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

ENV PATH=$CONDA_DIR/bin:$PATH \
    HOME=/home/$NB_USER

# script used to restore permissions after each step as root

ADD fix-permissions /usr/local/bin/fix-permissions

# Create jovyan user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.

RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \  
    groupadd wheel -g 11 && \
    echo "auth required pam_wheel.so use_uid" >> /etc/pam.d/su && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    mkdir -p $CONDA_DIR && \
    chown $NB_USER:$NB_GID $CONDA_DIR && \
    chmod g+w /etc/passwd && \
    fix-permissions /home/$NB_USER && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /opt

USER $NB_UID

RUN fix-permissions /home/$NB_USER

# Install conda as jovyan

ENV MINICONDA_VERSION 4.5.12

RUN cd /tmp && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    /bin/bash Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -f -b -p $CONDA_DIR && \
    rm Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh && \
    $CONDA_DIR/bin/conda config --system --prepend channels conda-forge && \
    $CONDA_DIR/bin/conda config --system --set auto_update_conda false && \
    $CONDA_DIR/bin/conda config --system --set show_channel_urls true && \
    $CONDA_DIR/bin/conda install --quiet --yes conda="${MINICONDA_VERSION%.*}.*" && \
    $CONDA_DIR/bin/conda update --all --quiet --yes && \
    conda install -n root conda-build && \
    conda install -c nvidia -c numba -c pytorch -c conda-forge -c rapidsai -c defaults  --quiet --yes \
    'python=3.6' \
    'cudatoolkit=10.0' \
    'tk' \
    'pytest' \
    'numpy>=1.16.1' \
    'numba>=0.41.0dev' \
    'pandas' \
    'blas=*=openblas' \
    'cython>=0.29' && \
    pip install --no-cache-dir tensorflow-gpu==2.0.0-alpha0 && \
    pip install --ignore-installed --no-cache-dir 'pyyaml>=4.2b4' && \
    cd /home/$NB_USER && \
    wget https://raw.githubusercontent.com/NVAITC/ai-lab/master/requirements.txt && \
    pip install --no-cache-dir -r /home/$NB_USER/requirements.txt && \
    pip uninstall pillow -y && \
    CC="cc -mavx2" pip install -U --force-reinstall --no-cache-dir pillow-simd && \
    rm /home/$NB_USER/requirements.txt && \
    pip install --ignore-installed --no-cache-dir 'msgpack>=0.6.0' && \
    conda clean -tipsy && \
    conda build purge-all && \
    rm -rf /home/$NB_USER/.cache && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# if you don't run this you could get:
# BlockingIOError(11, 'write could not complete without blocking', 69632)
RUN python -c 'import os,sys,fcntl; flags = fcntl.fcntl(sys.stdout, fcntl.F_GETFL); fcntl.fcntl(sys.stdout, fcntl.F_SETFL, flags&~os.O_NONBLOCK);'

# Install Jupyter Notebook, Lab, and Hub

RUN conda install -c conda-forge --quiet --yes \
    'notebook=5.7.*' \
    'jupyterhub=0.9.*' \
    'jupyterlab=0.35.*' \
    'jupyter_contrib_nbextensions' \
    'ipywidgets=7.2*' && \
    pip install --no-cache-dir jupyterlab==1.0.0a1 && \
    jupyter notebook --generate-config && \
    # Activate ipywidgets extension in the environment that runs the notebook server
    jupyter nbextension enable --py widgetsnbextension --sys-prefix && \
    jupyter contrib nbextension install --sys-prefix && \
    # Also activate ipywidgets extension for JupyterLab
    jupyter labextension install @jupyter-widgets/jupyterlab-manager && \
    jupyter labextension install jupyterlab_bokeh && \
    pip install --no-cache-dir jupyter-tensorboard && \
    jupyter tensorboard enable --sys-prefix && \
    conda install --quiet --yes 'tini=0.18.0' && \
    conda list tini | grep tini | tr -s ' ' | cut -d ' ' -f 1,2 >> $CONDA_DIR/conda-meta/pinned && \
    conda clean -tipsy && \
    conda build purge-all && \
    npm cache clean --force && \
    rm -rf $CONDA_DIR/share/jupyter/lab/staging && \
    rm -rf /home/$NB_USER/.cache && \
    rm -rf /home/$NB_USER/.node-gyp && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Import matplotlib the first time to build the font cache

USER root

ENV XDG_CACHE_HOME /home/$NB_USER/.cache/

RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot" && \
    fix-permissions /home/$NB_USER

# end extras

EXPOSE 8888
EXPOSE 8787
EXPOSE 8786
EXPOSE 6006

WORKDIR $HOME

# Configure container startup

ENTRYPOINT ["tini", "-g", "--"]
CMD ["start-notebook.sh"]

# Add local files as late as possible to avoid cache busting

COPY start.sh /usr/local/bin/
COPY start-notebook.sh /usr/local/bin/
COPY start-singleuser.sh /usr/local/bin/
COPY jupyter_notebook_config.py /etc/jupyter/
RUN fix-permissions /etc/jupyter/

RUN usermod -s /bin/bash $NB_USER

# Switch back to jovyan to avoid accidental container runs as root

USER $NB_UID
