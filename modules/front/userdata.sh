#!/bin/bash
yum -y install epel-release
yum -y install docker ruby python-pip unzip
cat <<EOF > /etc/docker/daemon.json
{
 "insecure-registries" : [ "registry.local:5000" ]
}
EOF
systemctl enable docker
systemctl start docker
curl https://aws-codedeploy-ap-south-1.s3.amazonaws.com/latest/install -o /tmp/code-deploy-install
ruby /tmp/code-deploy-install auto
systemctl start codedeploy-agent
systemctl enable codedeploy-agent
pip install awscli
aws s3 cp s3://deploy-lab/last-successful-deploy.txt /tmp/
LAST_REV=$(cat /tmp/last-successful-deploy.txt)
aws s3 cp s3://deploy-lab/$LAST_REV /tmp
unzip -o /tmp/$LAST_REV -d /
/bin/bash /wp-start.sh

