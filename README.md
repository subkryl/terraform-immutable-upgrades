## Example terraform immutable infrastructure and rolling upgrades of stateful services

For a detailed explanation see [this](https://sgotti.me/post/terraform-immutable-infrastructure-stateful-rolling-upgrades/) or [this](https://www.sorint.it/osblog/-/blogs/immutable-infrastructure-with-terraform-and-rolling-upgrades-of-stateful-services) posts.

This is an immutable infrastructure example. It demonstrates how to handle an immutable infrastructure creation, rolling upgrade, testing on an IaaS (in this case AWS in the us-east-1 region) on a service using persistent data. It uses [packer](https://www.packer.io/) and [terraform](https://www.terraform.io/) to respectively create the AMIs and to create/upgrade the infrastructure (and test all of this before doing it on the real environment).

In this case we are creating/upgrading an infrastructure made by a consul cluster on 3 instances. Each instance has an EBS volume used for consul data. This volume is persisted across instance recreation (to avoid the need to remove a member from the cluster leaving it in a partial 2 node cluster and to avoid data resynchronization that will take some time

Then we are going to upgrade the instances image with a new consul version and do a rolling upgrade of an instance at a time testing every step to ensure that the consul cluster remains healthy.

We used consul just as a common example but this can be applied to any stateful application that achieves high availability using replication (like an etcd/mongodb/cassandra/postgresql etc...) and supports rolling upgrades (in case where rolling upgrade isn't supported, like a major version upgrade of postgresql the additional upgrade steps are needed but the base remains the same).

In a real development workflow there'll be two repos: one for the image and one for the infrastructure and all of the below steps will be done with a continuous integration/deployment process.

To make this as simple as possible using an unique repository we split the various repositories and their versions inside different directories (**images/consul/vX** and **infra/vX**).

These are the steps that we are going to do below:

### Creation
* Build an AMI with packer for the consul instances (images/consul/v1)
* Build the infra/v1 project. Its build artifact is a docker image called infra:v1.
* With this docker image we can test the infrastructure and then deploy (create) the production infrastructure

### Rolling upgrade
* Build an updated AMI (images/consul/v2)
* Build the infra/v2 project. Its build artifact is a docker image called infra:v2.
* Use this build artifact to test the rolling upgrade and then do this on the production environment.


## Prerequisites

You'll need:

* Docker installed and running on your machine (with docker socket available under `/var/run/docker.sock`).
* [Packer](https://www.packer.io/)
* An aws access and secret key. Everything will be created inside a new vpc but we suggest to not use a "production" account.
* Since the created aws instances have to call the aws APIs, an instance profile is needed. The terraform `main.tf` file requires this instance profile to be named `default_instance_profile`
Inside the `setup` directory there's a terraform definition to create it (just execute a `terraform apply` inside this directory).
* An ssh key pair configured in your AWS account. Additionally the ssh private key needs to be added to your ssh agent before executing the next steps. These are needed since the various tests use ssh to connect to the instances. The SSH_AUTH_SOCK path is bind mounted to the executed docker containers.
* An S3 bucket to save terraform state files. The created files will start with `terraform/`


### Export the required environment variables

``` bash
export AWS_ACCESS_KEY_ID=                # The aws access key
export AWS_SECRET_ACCESS_KEY=            # The aws secret key
export AWS_DEFAULT_REGION=us-east-1
export S3_BUCKET=                        # The s3 bucket for saving terraform state files
export SSH_KEYPAIR=                      # The ssh keypair name created in your aws account
```

## Immutable infrastructure creation
### Build consul v1 ami

``` bash
cd images/consul/v1
VERSION=v1 ./build.sh
```

### Build infra v1 docker image

This image will be used to manage the infrastructure. It contains all the needed tools and scripts.

``` bash
cd ../../../infra/v1
```

* Edit the `config` file and put in the `CONSUL_AMI_ID` variable the ami id generated from the previous step.

``` bash
docker build -t infra:v1 .
```

### Test the v1 infrastructure creation

We can test the infrastructure creation in a temporary environment.

Since the docker command exports different environment variables and two volumes (`/var/run/docker.sock` for letting the container execute another docker container and the ssh authentications socket), there an helper script called `run-docker.sh` to simplify this:

``` bash
VERSION=v1 ./run-docker.sh test-create
```

### Create the real v1 infrastructure
If all goes ok we can create the "real" environment:

``` bash
ENV=prod VERSION=v1 ./run-docker.sh create
```

## Immutable infrastructure rolling upgrade
Now that we have our infrastructure at v1 ready we can do a rolling upgrade.

### Build consul v2 ami

``` bash
cd ../../images/consul/v2
VERSION=v2 ./build.sh
```

### Build infra v2 docker image

``` bash
cd ../../../infra/v2
```

* Edit the `config` file and put in the `CONSUL_AMI_ID` variable the ami id generated from the previous step.

``` bash
docker build -t infra:v2 .
```

### Test the v2 infrastructure creation

``` bash
VERSION=v2 ./run-docker.sh test-create
```

### Test the v1 -> v2 infrastructure upgrade

``` bash
VERSION=v2 ./run-docker.sh test-upgrade
```


### Upgrade the real infrastructure from v1 -> v2
If all goes ok we can upgrade the "real" environment:

``` bash
ENV=prod VERSION=v2 ./run-docker.sh upgrade
```


## Cleanup

If you want to remove the real infrastructure you can do it with:

``` bash
ENV=prod VERSION=v2 ./run-docker.sh destroy
```
