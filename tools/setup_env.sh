#!/usr/bin/env bash
#
# Bootstrap script to install kubernetes env.
#
# This script is intended to be used for install kubernetes env.

REPO=gopixiu-io
# 选择需要安装的分支，默认 stable/tiger 分支
BRANCH=stable/tiger

TARGET=kubez-ansible-${BRANCH//\//-}

function _ensure_lsb_release {
    if type lsb_release >/dev/null 2>&1; then
        return
    fi

    if type apt-get >/dev/null 2>&1; then
        apt-get -y install lsb-release
    elif type yum >/dev/null 2>&1; then
        yum -y install redhat-lsb-core >/dev/null 2>&1
    fi
}

function _is_distro {
    if [[ -z "$DISTRO" ]] && type lsb_release >/dev/null 2>&1; then
        _ensure_lsb_release
        DISTRO=$(lsb_release -si)
    fi
    if [[ -f /etc/.kyinfo ]];then
	    DISTRO=Kylin
    [[ "$DISTRO" == "$1" ]]
   fi
}


function is_ubuntu {
    _is_distro "Ubuntu"
}

function is_debian {
    _is_distro "Debian"
}

function is_centos {
    _is_distro "CentOS"
}
function is_Kylin {
    _is_distro "Kylin"
}

function prep_work {

        if is_centos; then
        if [[ "$(systemctl is-enabled firewalld)" == "active" ]]; then
            systemctl disable firewalld
        fi
        if [[ "$(systemctl is-active firewalld)" == "enabled" ]]; then
            systemctl stop firewalld
        fi

        configure_centos_sources
        yum -y install epel-release
        yum -y install git python2-pip unzip
   elif is_Kylin; then
        if [[ "$(systemctl is-enabled firewalld)" == "active" ]]; then
            systemctl disable firewalld
        fi
        if [[ "$(systemctl is-active firewalld)" == "enabled" ]]; then
            systemctl stop firewalld
        fi

        yum -y install git python2-pip unzip
    elif is_ubuntu || is_debian; then
        if [[ "$(systemctl is-enabled ufw)" == "active" ]]; then
            systemctl disable ufw
        fi
        if [[ "$(systemctl is-active ufw)" == "enabled" ]]; then
            systemctl stop ufw
        fi

        if is_debian; then
            configure_debian_sources
        else
            configure_ubuntu_sources
        fi
        apt-get update
        apt install -y git python-pip unzip
    else
        echo "Unsupported Distro: $DISTRO" 1>&2
        exit 1
    fi
}

function cleanup {
    if is_centos || is_Kylin; then
        yum clean all
    elif is_ubuntu || is_debian; then
        apt-get clean
    else
        echo "Unsupported Distro: $DISTRO" 1>&2
        exit 1
    fi
}

function configure_pip {
    mkdir -p ~/.pip
    cat > ~/.pip/pip.conf << EOF
[global]
trusted-host = mirrors.aliyun.com
index-url = http://mirrors.aliyun.com/pypi/simple/
EOF
}

function configure_centos_sources {
    if [ ! -f "/etc/yum.repos.d/CentOS-Base.repo.backup" ];then
         mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
    fi
    # CentOS 7
    curl http://mirrors.aliyun.com/repo/Centos-7.repo -o /etc/yum.repos.d/CentOS-Base.repo
}

function configure_debian_sources {
    if [ ! -f "/etc/apt/sources.list.backup" ];then
         mv /etc/apt/sources.list /etc/apt/sources.list.backup
    fi
    # debian 10.x (buster)
    cat > /etc/apt/sources.list << EOF
deb https://mirrors.aliyun.com/debian/ buster main non-free contrib
deb-src https://mirrors.aliyun.com/debian/ buster main non-free contrib
deb https://mirrors.aliyun.com/debian-security buster/updates main
deb-src https://mirrors.aliyun.com/debian-security buster/updates main
deb https://mirrors.aliyun.com/debian/ buster-updates main non-free contrib
deb-src https://mirrors.aliyun.com/debian/ buster-updates main non-free contrib
deb https://mirrors.aliyun.com/debian/ buster-backports main non-free contrib
deb-src https://mirrors.aliyun.com/debian/ buster-backports main non-free contrib
EOF
}

function configure_ubuntu_sources() {
    if [ ! -f "/etc/apt/sources.list.backup" ];then
        mv /etc/apt/sources.list /etc/apt/sources.list.backup
    fi
    # ubuntu 18.04(bionic)
    cat > /etc/apt/sources.list << EOF
deb https://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse

deb https://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb-src https://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
EOF
}

function install_ansible {
    if is_centos||is_Kylin; then
        yum -y install ansible
    elif is_ubuntu||is_debian; then
        apt-get -y install ansible
    else
        echo "Unsupported Distro: $DISTRO" 1>&2
        exit 1
    fi
}

function download_kubez_ansible {
    curl https://codeload.github.com/${REPO}/kubez-ansible/zip/refs/heads/${BRANCH} -o ${TARGET}.zip
    if [ $? -ne 0 ]; then
        exit 1
    fi

    unzip -q ${TARGET}.zip && mv ${TARGET} /tmp/kubez-ansible && git init /tmp/kubez-ansible
}

function install_kubez_ansible {
    if [[ ! -d /tmp/kubez-ansible ]]; then
        download_kubez_ansible
    fi
    # prepare the configuration for deploy
    cp -r /tmp/kubez-ansible/etc/kubez/ /etc/
    cp /tmp/kubez-ansible/ansible/inventory/multinode .

    install_ansible

    pip install -r /tmp/kubez-ansible/requirements.txt
    pip install /tmp/kubez-ansible/
}

# prepare and install kubernetes cluster
prep_work
configure_pip
# cleanup
install_kubez_ansible
