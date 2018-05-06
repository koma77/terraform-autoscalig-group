#!/bin/bash
yum -y install epel-release
yum -y install docker ruby
cat <<EOF > /etc/docker/daemon.json
{
 "insecure-registries" : [ "registry.local:5000" ]
}
EOF
systemctl enable docker
systemctl start docker
yum -y install ruby; curl https://aws-codedeploy-ap-south-1.s3.amazonaws.com/latest/install -o /tmp/code-deploy-install
ruby /tmp/code-deploy-install auto
systemctl start codedeploy-agent
systemctl enable codedeploy-agent
