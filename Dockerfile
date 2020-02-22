# JLINK is provided by Segger (usage of this tools requires agreement with its
# licence)

# root image, build from LTS ubuntu in Docker Hub
FROM ubuntu:18.04

MAINTAINER Juan Solano "jsm@jsolano.com"

# update this variable to force a refresh of all base images and make sure
# subsequent commands do not use old cache versions
ENV REFRESHED_AT 2019-06-14

ARG USERNAME="docker"
ARG USERGROUP="dckrgroup"
ARG DEBIAN_FRONTEND=noninteractive
# these can be overriden with a command line option when the image is built,
# e.g. --build-arg UID=$(id -u) --build-arg GID=$(id -g)
ARG UID=1000
ARG GID=1000
ARG GCC_ARM_TOOLCHAIN_VER="gcc-arm-none-eabi-8-2018-q4-major"
ARG GCC_ARM_TOOLCHAIN_URL="https://developer.arm.com/-/media/Files/downloads/gnu-rm/7-2018q2/"$GCC_ARM_TOOLCHAIN_VER-linux.tar.bz2
ARG XMC_LIB_VER="XMC_Peripheral_Library_v2.1.22"
ARG XMC_LIB_URL="http://dave.infineon.com/Libraries/XMCLib/"$XMC_LIB_VER.zip
ARG JLINK_VER="JLink_Linux_V634g_x86_64"

# set up the compiler path and toolchain global variables
ENV PATH $PATH:/home/$USERNAME/opt/$GCC_ARM_TOOLCHAIN_VER/bin
ENV GCC_ARM_TOOLCHAIN_VER $GCC_ARM_TOOLCHAIN_VER
ENV GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"
ENV USB_SCRIPT="usbdev_allow.sh"
ENV TZ=Europe/Berlin

RUN apt-get update -q \
    && apt-get install --no-install-recommends -y apt-utils \
    && apt-get install --no-install-recommends -y vim make sudo tzdata \
    libncurses5 ca-certificates unzip bzip2 libtool ccache \
    usbutils libusb-1.0-0-dev libusb-dev \
    && rm -rf /var/lib/apt/lists/*

# set timezone and standard user
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && groupadd --gid $GID $USERGROUP \
    && useradd -m -u $UID -g $GID -o -s /bin/bash $USERNAME \
    && echo "root:root" | chpasswd \
    && echo "$USERNAME:$USERNAME" | chpasswd \
    && usermod -a -G 20 $USERNAME \
    && adduser $USERNAME sudo \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# set up an external tools directory
RUN mkdir -p /home/$USERNAME/opt
WORKDIR /home/$USERNAME/opt
RUN chown $USERNAME /home/$USERNAME/opt \
    && cd /home/$USERNAME/opt

# install JLink as root, before changing to standard user
COPY $JLINK_VER.deb /home/$USERNAME/opt
RUN dpkg -i $JLINK_VER.deb \
    && rm $JLINK_VER.deb
COPY $USB_SCRIPT /home/$USERNAME/opt
RUN chmod +x /home/$USERNAME/opt/$USER_SCRIPT

# further operations as standard user
USER $USERNAME

# install XMC library
COPY $XMC_LIB_VER.zip /home/$USERNAME/opt
RUN unzip $XMC_LIB_VER.zip \
    && rm $XMC_LIB_VER.zip

# install cross-compilation toolchain
COPY $GCC_ARM_TOOLCHAIN_VER-linux.tar.bz2 /home/$USERNAME/opt
RUN bunzip2 $GCC_ARM_TOOLCHAIN_VER-linux.tar.bz2 \
    && tar xvf $GCC_ARM_TOOLCHAIN_VER-linux.tar \
    && rm $GCC_ARM_TOOLCHAIN_VER-linux.tar

# required by ccache
RUN cd /usr/lib/ccache \
    && sudo ln -s ../../bin/ccache arm-none-eabi-gcc
ENV PATH /usr/lib/ccache:$PATH

# create a directory for our project and setup a shared workfolder
RUN mkdir -p /home/$USERNAME/project
WORKDIR /home/$USERNAME/project
VOLUME /home/$USERNAME/project
RUN cd /home/$USERNAME/project \
    && mkdir -p $HOME/.ccache \
    && echo "cache_dir = $HOME/project/.ccache" >> $HOME/.ccache/ccache.conf
