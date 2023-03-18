#!/usr/bin/env bash
#
# Bootstrap script to install nexus.
#
# This script is intended to be used for install nexus server for offline env.

# 后续优化
HOST_IP=`cat k8senv.yaml |grep "^local_ip"|cut -d "=" -f2|sed 's/"//g'`
MIRROR_REPO=`cat k8senv.yaml |grep "^mirrors_repo"|cut -d "=" -f2|sed 's/"//g'`
REGISTRY_REPO=`cat k8senv.yaml |grep "^regis_repos"|cut -d "=" -f2|sed 's/"//g'`

function prep_work() {
    # TODO: 补充前置检查
    grep -q "$MIRROR_REPO" /etc/hosts || echo "$HOST_IP $MIRROR_REPO" >> /etc/hosts
    grep -q "$REGISTRY_REPO" /etc/hosts || echo "$HOST_IP $REGISTRY_REPO" >> /etc/hosts
}

function setup_nexus() {
    if [ ! -d "/data" ]; then
        mkdir /data
    fi

    if [ ! -d "/data/nexus" ]; then
        if [ ! -e "./nexus.tar.gz" ]; then
            echo "当前目录中未发现 nexus.tar.gz，无法进行 nexus 的安装" 1>&2
            exit 1
        fi
        tar -zxvf ./nexus.tar.gz -C /data
    fi

     # 启动 nexus.sh
     cd /data/nexus && sh nexus.sh start

     yum clean all
     echo "nexus 安装成功"
}

# TODO: 通过 docker 命令行 来推送镜像，临时解决方法，后续移除仓库对 docker 的依赖
function install_docker() {
    yum install -y docker-ce
    if [ ! -e "/etc/docker/daemon.json" ]; then
        cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": ["https://hdi5v8p1.mirror.aliyuncs.com"],
  "insecure-registries": ["0.0.0.0/0"],
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  }
}
EOF
    fi
    systemctl daemon-reload
    systemctl restart docker
}

function push_images() {
    if [ ! -d "./k8soffimage" ]; then
        tar -zxvf k8soffimage.tar.gz
    fi
    cd k8soffimage && sh k8simage.sh load
    sleep 1
}

prep_work

setup_nexus

install_docker
push_images
