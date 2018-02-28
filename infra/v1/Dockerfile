FROM debian:stretch

RUN apt-get update && apt-get install -y wget curl git unzip jq python python-pip python-boto3 awscli ansible docker uuid-runtime \
    vim iproute2 net-tools nano

RUN curl https://releases.hashicorp.com/terraform/0.11.3/terraform_0.11.3_linux_amd64.zip -o /tmp/terraform_0.11.3_linux_amd64.zip

WORKDIR /usr/local/bin/
RUN unzip /tmp/terraform_0.11.3_linux_amd64.zip

RUN mkdir -p /root/.ssh
RUN chmod 700 /root/.ssh
RUN /bin/echo -e "Host *\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config

WORKDIR /deploy
ADD main.tf config ./
ADD scripts scripts/
ADD ansible ansible/
# ADD terraform .terraform

ENTRYPOINT [ "/deploy/scripts/run.sh" ]
