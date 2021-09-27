# Copyright (C) 2015-2016 Intel Corporation
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2 as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

# Since this Dockerfile is used in multiple images, force the builder to
# specify the BASE_DISTRO. This should hopefully prevent accidentally using
# a default, when another distro was desired.
ARG BASE_DISTRO=SPECIFY_ME

FROM crops/yocto:$BASE_DISTRO-base

USER root

ADD https://raw.githubusercontent.com/crops/extsdk-container/master/restrict_useradd.sh  \
        https://raw.githubusercontent.com/crops/extsdk-container/master/restrict_groupadd.sh \
        https://raw.githubusercontent.com/crops/extsdk-container/master/usersetup.py \
        /usr/bin/
COPY distro-entry.sh poky-entry.py poky-launch.sh /usr/bin/
COPY sudoers.usersetup /etc/

# For ubuntu, do not use dash.
RUN which dash &> /dev/null && (\
    echo "dash dash/sh boolean false" | debconf-set-selections && \
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash) || \
    echo "Skipping dash reconfigure (not applicable)"

# We remove the user because we add a new one of our own.
# The usersetup user is solely for adding a new user that has the same uid,
# as the workspace. 70 is an arbitrary *low* unused uid on debian.
RUN userdel -r yoctouser && \
    mkdir /home/yoctouser && \
    groupadd -g 70 usersetup && \
    useradd -N -m -u 70 -g 70 usersetup && \
    chmod 755 /usr/bin/usersetup.py \
        /usr/bin/poky-entry.py \
        /usr/bin/poky-launch.sh \
        /usr/bin/restrict_groupadd.sh \
        /usr/bin/restrict_useradd.sh && \
    echo "#include /etc/sudoers.usersetup" >> /etc/sudoers

# CONSAT addition --START
RUN apt-get remove -y python3.8
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        software-properties-common \
#        python3.7 \
        git-lfs \
        rsync \
#        python3-pip \
        tzdata \
        net-tools \
        sqlite \
        curl \
        bc \
        linux-headers-generic \
        bison
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3.6 \
    python3-pip

RUN rm /usr/bin/python3
RUN ln -s python3.6 /usr/bin/python3

# Fix for nxp-wlan-sdk missing libraries
# https://community.nxp.com/t5/i-MX-Processors/zeus-5-4-24-2-1-0-won-t-boot-on-my-IMX8MNEVK-board/m-p/1071512
RUN ln -s /lib/modules/4.15.0-134-generic /lib/modules/4.19.128-microsoft-standard

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y libncurses5-dev

RUN curl https://storage.googleapis.com/git-repo-downloads/repo > /usr/bin/repo
RUN chmod a+x /usr/bin/repo

RUN echo 'alias yocto="DISTRO=fsl-imx-xwayland MACHINE=imx8mmcppc0701 source imx-setup-release.sh -b build-xwayland"' > /etc/skel/.bash_aliases

# FROM python:3
RUN python3 -m pip install --upgrade pip && \
    python3 -m pip install --no-cache-dir 'Django>1.8,<1.12' && \
    python3 -m pip install --no-cache-dir 'beautifulsoup4>=4.4.0' && \
    python3 -m pip install --no-cache-dir gitpython && \
    python3 -m pip install --no-cache-dir pytz

# CONSAT addition --END

USER usersetup
ENV LANG=en_US.UTF-8

ENTRYPOINT ["/usr/bin/distro-entry.sh", "/usr/bin/dumb-init", "--", "/usr/bin/poky-entry.py"]
