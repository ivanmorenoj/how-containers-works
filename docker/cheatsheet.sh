#!/bin/sh

# Install docker
curl -fsSL https://get.docker.com -o install_docker.sh
sh install_docker.sh
usermod -aG docker ${USER}
apt install docker-compose -y

# Command syntax
docker help

# print version and info
docker version
docker info

# run Hello world
#   default registry: docker.io aka hub.docker.com
docker container run -it --rm hello-world
# run web server
docker container run --publish 8080:80 nginx
# check web server
curl localhost:8080
# stop container C-c
docker container ps -a
# delete
docker container rm <Container-ID>


# Getting shell inside containres

# start a new container interactively
docker container run --interactive --tty --rm debian
# [...] execute commands within container

# run additional command in existing container
docker container exec -it <container_name> bash
# [...] execute commands within container

# Inspect containers
# process list in one container
docker container top <container_name>

# details of one container
docker container inspect <container_name>

# Performance stats for all containers
docker container stats


# Logs
# Run a container in detach mode
docker container run --detach --name nginx_logs --rm --publish 8080:80 nginx
# See container logs
docker container logs nginx_logs
# Follow container logs
docker container logs --follow nginx_logs
# generate some traffic
for i in {1..60}; do 
  echo "HTTP Request Number $i";
  curl localhost:8080 &> /dev/null; 
  sleep 0.1;
done


# Docker network

# List port mapping from container
docker container run -it --rm --name mynginx -p 8080:80 nginx
docker container port mynginx

# create a network
docker network create --driver bridge mynet

# delete network
docker network rm mynet

# list networks
docker network list

# inspect Network
docker network inspect <net_name>

# Attach network to existing container
# Create a container in default network
docker container run -it --rm --name mydebian debian
ip a show # within mydebian

# attach mynet to mydebian
docker network connect mynet mydebian
ip a show # within mydebian

# detach mynet to mydebian
docker network disconnect mynet mydebian
ip a show # within mydebian

# Create a container for every net
# default net
docker container run -it --rm --name nginx_net_default -p 8000:80 nginx
curl localhost:8000
docker container exec -it nginx_net_default sh -c 'curl localhost:80'
iptables -t nat -nvL
# none net
docker container run -it --rm --net none --name nginx_net_none nginx
docker container exec -it nginx_net_none sh -c 'curl localhost:80'
docker container inspect nginx_net_none
# host net
docker container run -it --rm --net host --name nginx_net_host nginx
curl localhost:80
docker container exec -it nginx_net_host sh -c 'curl localhost:80'
ss -tpln4 # see process by port in host
# mynet net
docker container run -it --rm --net mynet --name nginx_net_mynet -p 8001:80 nginx
curl localhost:8001
docker container exec -it nginx_net_mynet sh -c 'curl localhost:80'
iptables -t nat -nvL


# Docker Network DNS

docker network create --driver bridge mynet
# Create 2 containers with mynet network
docker container run -d --rm --name dns_test1 --network mynet debian sleep 600
docker container run -d --rm --name dns_test2 --network mynet debian sleep 600

# exec ping to another container
docker container exec -it dns_test1 ping -c 3 dns_test2
docker container exec -it dns_test2 ping -c 3 dns_test1


# Docker Volumes

# List volumes
docker volume ls
# Create volumes
docker volume create --driver local myvol
# Delete volume
docker volume rm <volume_name>
# inspect volumes
docker volume inspect myvol
# Run a container with volume, if myvol doesn't exists docker create it
docker container run -d --rm -v mmyvol:/usr/share/nginx/html -p 8080:80 --name nginx_vol nginx
# change default index file
docker container exec -it nginx_vol sh -c 'echo "Persistent volume created" > /usr/share/nginx/html/index.html'
# stop container
docker cotnainer stop nginx_vol
# Create another container with the same volume 
docker container run -d --rm -v mmyvol:/usr/local/apache2/htdocs -p 8080:80 --name httpd_vol httpd
# stop container
docker cotnainer stop httpd_vol

# Mount Volumes
# create directory for html content
mkdir nginx_html
echo "Bind Mount file" > nginx_html/index.html
# Run a container with bind mount
docker container run -d --rm --name nginx_bind \
  --mount type=bind,source=$PWD/nginx_html,target=/usr/share/nginx/html \
  -p 8080:80 nginx
# Run another container from the same bind mount
docker container run -d --rm --name httpd_bind \
  -v $PWD/nginx_html:/usr/local/apache2/htdocs -p 8090:80 httpd
# check file
curl localhost:8080
curl localhost:8090


# Environment variables in docker
# create env file
cat <<EOF > env.file
TEST2=ENV_VAR_TEST_2
TEST3=ENV_VAR_TEST_3
TEST4=ENV_VAR_TEST_4
EOF
# Run container with environment variables
docker container run -d --rm --name env_test \
  -e TEST1="ENV_VAR_TEST_1" --env-file ./env.file debian sleep 300
# check env variables within container
docker container exec -it env_test env


# Create wordpress server
# create network
docker network create --driver bridge wordpress_net
# create volumes
docker volume create --driver local wordpress_vol
docker volume create --driver local mysql_vol
# Create environment variables for wordpress
cat <<EOF > wordpress.env
WORDPRESS_DB_HOST=mysqldb
WORDPRESS_DB_USER=exampleuser
WORDPRESS_DB_PASSWORD=examplepass
WORDPRESS_DB_NAME=exampledb
EOF
# Create environment variables for mysql
cat <<EOF > mysql.env
MYSQL_DATABASE=exampledb
MYSQL_USER=exampleuser
MYSQL_PASSWORD=examplepass
MYSQL_RANDOM_ROOT_PASSWORD='1'
EOF
# create mysql database container
docker container run -d --rm --name mysqldb --env-file mysql.env \
  --net wordpress_net -v mysql_vol:/var/lib/mysql mysql:5.7
# Create wordpress container
docker container run -d --rm --name wordpress --env-file wordpress.env \
  --net wordpress_net -v wordpress_vol:/var/www/html -p 8000:80 wordpress
# check wordpress installation on http://<Host-IP>:8000
ip adrr show | head -n 15
# Clean all
docker container stop wordpress
docker container stop mysqldb
docker volume rm mysql_vol
docker volume rm wordpress_vol
docker network rm wordpress_net


# Docker base images

# Create a network
docker network create --driver bridge my_net
# debian
docker container run -it --rm --name my_debian --net my_net debian
cat /etc/os-release
apt update && apt install -y iperf3
iperf3 --version
iperf3 -s
# ubuntu
docker container run -it --rm --name my_ubuntu --net my_net ubuntu
cat /etc/os-release
iperf3 --version
apt update && apt install -y iperf3
iperf3 -c my_debian
# centos
docker container run -it --rm --name my_centos --net my_net centos
cat /etc/os-release
yum install -y iperf3
iperf3 --version
iperf3 -c my_debian
# amazonlinux
docker container run -it --rm --name my_amazonlinux --net my_net amazonlinux
cat /etc/os-release
yum install -y iperf3
iperf3 --version
iperf3 -c my_debian
# alpine
docker container run -it --rm --name my_alpine --net my_net alpine
cat /etc/os-release
apk add iperf3
iperf3 --version
iperf3 -c my_debian
# busybox
docker container run -it --rm --name my_busybox --net my_net busybox
cat /etc/os-release
telenet -p 5201 my_debian


# Build iperf3 for different base images
cd iperf3
# debian
docker build --rm -f Dockerfile.debian -t myiperf:debian .
# ubuntu
docker build --rm -f Dockerfile.ubuntu -t myiperf:ubuntu .
# centos
docker build --rm -f Dockerfile.centos -t myiperf:centos .
# amazonlinux
docker build --rm -f Dockerfile.amazonlinux -t myiperf:amazonlinux .
# alpine
docker build --rm -f Dockerfile.alpine -t myiperf:alpine .
# busybox multistage
docker build --rm -t myiperf:latest .

# See build images
docker image ls | grep myiperf
# inspect images
docker inspect myiperf:debian
# see image history
docker image history myiperf:alpine

# Push images to docker registry
# login to docker.io, enter user an password
docker login docker.io
# create repository tag image: <registry>/username/reponame:tag
docker tag myiperf:debian docker.io/ivanmorenoj/myiperf:debian
docker tag myiperf:ubuntu docker.io/ivanmorenoj/myiperf:ubuntu
docker tag myiperf:centos docker.io/ivanmorenoj/myiperf:centos
docker tag myiperf:amazonlinux docker.io/ivanmorenoj/myiperf:amazonlinux
docker tag myiperf:alpine docker.io/ivanmorenoj/myiperf:alpine
docker tag myiperf:latest docker.io/ivanmorenoj/myiperf:latest
# push image
docker push docker.io/ivanmorenoj/myiperf:debian
docker push docker.io/ivanmorenoj/myiperf:ubuntu
docker push docker.io/ivanmorenoj/myiperf:centos
docker push docker.io/ivanmorenoj/myiperf:amazonlinux
docker push docker.io/ivanmorenoj/myiperf:alpine
docker push docker.io/ivanmorenoj/myiperf:latest

# Clean Images
docker system prune --volumes --all -f

# Create network
docker network create --driver bridge iperf_net
# Execute iperf server from debian image
docker container run -it --rm --name iperf_server -e IPERF_MODE=server \
  --net iperf_net docker.io/ivanmorenoj/myiperf:debian
# Execute clients
docker container run -it --rm -e IPERF_MODE=client -e SERVER_HOST=iperf_server \
  --net iperf_net docker.io/ivanmorenoj/myiperf:debian
docker container run -it --rm -e IPERF_MODE=client -e SERVER_HOST=iperf_server \
  --net iperf_net docker.io/ivanmorenoj/myiperf:ubuntu
docker container run -it --rm -e IPERF_MODE=client -e SERVER_HOST=iperf_server \
  --net iperf_net docker.io/ivanmorenoj/myiperf:centos
docker container run -it --rm -e IPERF_MODE=client -e SERVER_HOST=iperf_server \
  --net iperf_net docker.io/ivanmorenoj/myiperf:amazonlinux
docker container run -it --rm -e IPERF_MODE=client -e SERVER_HOST=iperf_server \
  --net iperf_net docker.io/ivanmorenoj/myiperf:alpine
docker container run -it --rm --net iperf_net docker.io/ivanmorenoj/myiperf -c iperf_server


