#!/usr/bin/env python
#
# Copyright 2020 Caoyingjun
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# https://github.com/kubernetes-client/python/

import os

from ansible.module_utils.basic import AnsibleModule
import docker
from kubernetes import client
from kubernetes import config

KUBECONFIG = '/etc/kubernetes/admin.conf'
KUBEZIMAGE = 'jacky06/kube-nginx:v1.1'
KUBEZPATH = '/var/lib/kubez-nginx'


def template_kubez_nginx(lb_path, lb_vip, lb_port, node_port):
    ep_entries = []
    for endpoint in ['103.39.211.122']:
        ep_entry = ('        server {ep}:{np}  '
                    'max_fails=3 '
                    'fail_timeout=30s;\n'.format(ep=endpoint,
                                                 np=node_port))
        ep_entries.append(ep_entry)
    ep_entries = ''.join(ep_entries).strip()

    nginx_content = '''#NOTE(caoyingjun): Generated by kubez template.
worker_processes 1;
events {{
    worker_connections  1024;
}}
stream {{
    upstream backend {{
        hash $remote_addr consistent;
        {ep_entries}
    }}
    server {{
        listen {lb_vip}:{lb_port};
        proxy_connect_timeout 1s;
        proxy_pass backend;
    }}
}}'''.format(ep_entries=ep_entries, lb_vip=lb_vip, lb_port=lb_port)

    with open(os.path.join(lb_path, 'kubez-nginx.conf'), 'w') as f:
        f.write(nginx_content)


def get_docker_client():
    return docker.APIClient(version='auto')


class KubeService(object):

    def __init__(self):
        # Ensure the kubez path exits
        self.create_kubez_path()

        # Configs can be set in Configuration class directly or using helper utility
        config.load_kube_config()

        self.v1client = client.CoreV1Api()
        self.dc = get_docker_client()

    def create_kubez_path(self):
        if not os.path.exists(KUBEZPATH):
            os.makedirs(KUBEZPATH)

    def get_namespaced_service(self, name, namespace):
        service = self.v1client.read_namespaced_service(name, namespace)
        return service

    def update_namespaced_service(self, name, namespace, externalips):
        body = {
            'spec': {
                'externalName': 'kubez',
                'externalIPs': externalips,
                'type': 'LoadBalancer'
                }
        }
        self.v1client.patch_namespaced_service(name, namespace, body)

    def restart_container(self, name, volume):
        self.create_container(name, volume)
        self.dc.restart(name)

    def create_container(self, name, volume):
        # containers = self.dc.containers()
        # for container in containers:
        options = {
            'restart_policy': {
                'Name': 'always'
            },
            'network_mode': 'host',
            'binds': {
                volume: {
                    'bind': '/etc/kubez-nginx',
                    'mode': 'rw',
                },
            },
        }

        host_config = self.dc.create_host_config(**options)
        self.dc.create_container(
            **{'name': name, 'image': KUBEZIMAGE, 'host_config': host_config})


def main():
    # specs = dict(
    #     name=dict(required=True, type='str'),
    #     namespace=dict(required=False, type='str', default='default'),
    #     externalips=dict(required=True, type='str'),
    # )
    # module = AnsibleModule(argument_spec=specs, bypass_checks=True)
    # params = module.params

    ks = KubeService()

    externalips = ['103.39.211.122']
    try:
        ks.update_namespaced_service('ingress-nginx', 'kube-system', externalips)
    except Exception as e:
        print(e)

    service = ks.get_namespaced_service('ingress-nginx', 'kube-system')
    print(service)

    ks.restart_container('kubez-nginx', KUBEZPATH)



if __name__ == '__main__':
    main()