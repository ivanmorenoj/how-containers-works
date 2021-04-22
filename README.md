# Understand how linux containers works with practical examples

![containres](img/containers.jpg)

Nowadays a bast majority of server workloads run using linux containers because of his flexibility and lightweight but have you ever think how does linux containers works. In this tutorial we will demystify how does linux containers works with some practical examples. Linux containers works thanks two kernel features: `namespaces` and `cgroups`.

# Table of contents
* [Understand how linux containers works with practical examples](#understand-how-linux-containers-works-with-practical-examples)
* [Table of contents](#table-of-contents)
* [Linux Namespaces](#linux-namespaces)
* [Linux control groups (cgroups)](#linux-control-groups-cgroups)
* [Container Fundamentals (key technologies)](#container-fundamentals-key-technologies)
   * [Process namespace fundamentals](#process-namespace-fundamentals)
   * [Filesystem Overlay FS fundamentals](#filesystem-overlay-fs-fundamentals)
   * [Networking Linux bridge fundamentals](#networking-linux-bridge-fundamentals)
   * [Control groups (cgroups) fundamentals](#control-groups-cgroups-fundamentals)
* [Create a container from scratch](#create-a-container-from-scratch)
* [Inspect Namespaces within a docker container](#inspect-namespaces-within-a-docker-container)
   * [Install docker CE](#install-docker-ce)
   * [Inspect Docker Network](#inspect-docker-network)
   * [Inspect cgroups in a docker container](#inspect-cgroups-in-a-docker-container)
   * [Inspect overlay fs in a docker container](#inspect-overlay-fs-in-a-docker-container)
   * [Inspect docker process namespace](#inspect-docker-process-namespace)
* [Conclusion](#conclusion)

# Linux Namespaces
A namespace wraps a global system resource in an abstraction that makes it appear to the processes within the namespace that they have their own isolated instance of the global resource.  Changes to the global resource are visible to other processes that are members of the namespace, but are invisible to other processes. One use of namespaces is to implement containers. \[[1](https://man7.org/linux/man-pages/man7/namespaces.7.html)\]

Currently the linux kernel have 8 types of namespaces:

|Namespace | Isolates |
| :------: | :------: | 
| cgroup   | Cgroup root directory |
| IPC      | System V IPC, POSIX message queues |
| Network  | Network devices, stacks, ports, etc.|
| Mount    | Mount points |
| PID      | Process IDs |
| Time     | Boot and monotonic clocks |
| User     | User and group IDs |
| UTS      | Hostname and NIS domain name |

# Linux control groups (cgroups)

Cgroups allow you to allocate resources — such as CPU time, system memory, network bandwidth, or combinations of these resources — among user-defined groups of tasks (processes) running on a system. You can monitor the cgroups you configure, deny cgroups access to certain resources, and even reconfigure your cgroups dynamically on a running system. \[[2](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/resource_management_guide/ch01)\]

# Container Fundamentals (key technologies)

In this section we gonna make some practices with the following key technologies that make possible the usage of containers in linux:
* [Process namespace fundamentals](#process-namespace-fundamentals)
* [Filesystem Overlay FS fundamentals](#filesystem-overlay-fs-fundamentals)
* [Networking Linux bridge fundamentals](#networking-linux-bridge-fundamentals)
* [Control groups (cgroups) fundamentals](#control-groups-cgroups-fundamentals)

NOTE: ***This tutorial was made using a VM with 1GB of ram and 1vCPU using debian 10 buster with kernel `4.19.0-16-amd64`. All commands were executed using `root` privileges***

## Process namespace fundamentals
A process namespace isolate a running command from the host. Let's see how to implement a process namespace in linux.

List  process namespaces
```sh
$ lsns -t pid
```
Get the PID of the current terminal
```sh
$ echo $$ # parent PID
```
Launch a new zsh terminal using namespaces
```sh
$ unshare --fork --pid --mount-proc zsh
$ sleep 300 &
$ sleep 300 &
$ sleep 300 &
$ sleep 300 &
$ sleep 300 &
$ top
```
See the process tree from the parent
```sh
$ ps f -g <PPID>
```
List namespaces
```sh
$ lsns -t pid
```

## Filesystem Overlay FS fundamentals
Containers need tohave a filesystem, one of the most used filesystem for containers is `overlay` who can mount with `layers` and merge in a single directory, the lower layers are read only and all changes are made on the upper layer. Let's see how does overlay fs works.

Create directories
```sh
$ cd /tmp
$ mkdir {lower1,lower2,upper,work,merged}
```
Create some files in lower directories
```sh
$ echo "Lower 1 - original" > lower1/file1.txt
$ echo "Lower 2 - original" > lower2/file2.txt
```
Create overlay FS
```sh
$ mount -t overlay -o lowerdir=/tmp/lower1:/tmp/lower2,upperdir=/tmp/upper,workdir=/tmp/work none /tmp/merged
```
Create, modify files
```sh
$ cd /tmp/merged
$ echo "file created in merged directory" > file_created.txt
$ echo "file 1 modified" > file1.txt
```
Umount overlay fs
```sh
$ cd /tmp
$ umount /tmp/merged
```
Inspect lower and upper dirs 
```sh
$ find -name '*.txt' -type f 2>/dev/null | while read fn; do echo ">> cat $fn"; cat $fn; done
```

## Networking Linux bridge fundamentals
Linux container uses network namespaces to isolate the network from the host, this is possible implementing a bridge interface that acts like network switch, and every container connect to that interface with his own ip address. Let's see how does linux bridge and network namespaces works.

Create a Network Virtual bridge
```sh
$ ip link add br-net type bridge
```
List Network Interfaces
```sh
$ ip link
```
Assign an IP Address to bridge interface
```sh
$ ip addr add 192.168.55.1/24 brd + dev br-net
```
Bring UP the bridge interface
```sh
$ ip link set br-net up
```

Create 2 Network Namespaces
```sh
$ ip netns add ns1
$ ip netns add ns2
```
Create a Virtual Ethernet cable pair
```sh
$ ip link add veth-ns1 type veth peer name br-ns1
$ ip link add veth-ns2 type veth peer name br-ns2
```
Assign veth to namespaces
```sh
$ ip link set veth-ns1 netns ns1
$ ip link set veth-ns2 netns ns2
$ ip link set br-ns1 master br-net
$ ip link set br-ns2 master br-net
```
Assign IP address to veth within namespaces
```sh
$ ip -n ns1 addr add 192.168.55.2/24 dev veth-ns1
$ ip -n ns2 addr add 192.168.55.3/24 dev veth-ns2
```
Bring UP veth interfaces within Namespaces
```sh
$ ip -n ns1 link set lo up
$ ip -n ns2 link set lo up
$ ip -n ns1 link set veth-ns1 up
$ ip -n ns2 link set veth-ns2 up
```
Bring UP bridge veth in the local host
```sh
$ ip link set br-ns1 up
$ ip link set br-ns2 up
```

Configure default route within namespaces
```sh
$ ip -n ns1 route add default via 192.168.55.1 dev veth-ns1 
$ ip -n ns2 route add default via 192.168.55.1 dev veth-ns2 
```
Enable IP forward in the host
```sh
$ sysctl -w net.ipv4.ip_forward=1
```
Configure `MASQUERADE` in the host for `192.168.55.0/24` subnet
```sh
$ iptables -t nat -A POSTROUTING -s 192.168.55.0/24 ! -o br-net -j MASQUERADE
```
Check connectivity within namespaces
```sh
$ ip netns exec ns1 ping -c 3 192.168.55.3 # ping ns2
$ ip netns exec ns2 ping -c 3 192.168.55.2 # ping ns1
$ ip netns exec ns1 ping -c 3 192.168.55.1 # ping br-net gateway
$ ip netns exec ns2 ping -c 3 192.168.55.1 # ping br-net gateway
$ ip netns exec ns1 ping -c 3 1.1.1.1 # ping internet
$ ip netns exec ns2 ping -c 3 1.1.1.1 # ping internet
```
## Control groups (cgroups) fundamentals
Control groups or cgroups are used by containers to limit the usage of resource in the host machine. Let's see how does cgroups works.

Create cgroups directory
```sh
$ mkdir -p /mycg/{memory,cpusets,cpu}
```

Mount cgroups directory
```sh
$ mount -t cgroup -o memory none /mycg/memory
$ mount -t cgroup -o cpu,cpuacct none /mycg/cpu
$ mount -t cgroup -o cpuset none /mycg/cpusets
```
Create new directories under CPU controller
```sh
mkdir -p /mycg/cpu/user{1..3}
```

Assign CPU shares to every user (This example uses 1vCPU)
```sh
# 2048 / (2048 + 512 + 80) = 77%
$ echo 2048 > /mycg/cpu/user1/cpu.shares
# 512 / (2048 + 512 + 80) = 19%
$ echo 512 > /mycg/cpu/user2/cpu.shares
# 80 / (2048 + 512 + 80) = 3%
$ echo 80 > /mycg/cpu/user3/cpu.shares
```

Create artificial load
```sh
$ cat /dev/urandom &> /dev/null &
$ PID1=$!
$ cat /dev/urandom &> /dev/null &
$ PID2=$!
$ cat /dev/urandom &> /dev/null &
$ PID3=$!
```

Assign process to every user
```sh
$ echo $PID1 > /mycg/cpu/user1/tasks
$ echo $PID2 > /mycg/cpu/user2/tasks
$ echo $PID3 > /mycg/cpu/user3/tasks
```
Monitoring process
```sh
$ top
```

# Create a container from scratch
So far we know how does linux namespaces works, now lets create a container using overlayfs, network namespaces, cgroups and process namespaces from scratch. Let's see how a linux container is created. 

Download and extract debian container fs from docker
```sh
$ docker pull debian
$ docker save debian -o debian.tar
$ mkdir debian_layer
$ mkdir -p fs/{lower,upper,work,merged}
$ tar xf debian.tar -C debian_layer
$ find debian_layer -name 'layer.tar' -exec tar xf {} -C fs/lower \;
```
Create bridge interface
```sh
$ ip netns add cnt
$ ip link add br-cnt type bridge
$ ip addr add 192.168.22.1/24 brd + dev br-cnt
$ ip link set br-cnt up
$ sysctl -w net.ipv4.ip_forward=1
$ iptables -t nat -I POSTROUTING 1 -s 192.168.22.0/24 ! -o br-cnt -j MASQUERADE
```
Create overlay Filesystem from debian container fs
```sh
$ mount -vt overlay -o lowerdir=./fs/lower,upperdir=./fs/upper,workdir=./fs/work none ./fs/merged
```
Mounting Virtual File Systems 
```sh
$ mount -v --bind /dev ./fs/merged/dev
```
Launch process namespace within `fs/merged` fs
```sh
$ unshare --fork --pid --net=/var/run/netns/cnt chroot ./fs/merged \
    /usr/bin/env -i PATH=/bin:/usr/bin:/sbin:/usr/sbin TERM="$TERM" \
    /bin/bash --login +h
# Mount proc within container
$ mount -vt proc proc /proc
```
Connect the container with `br-cnt`
```sh
$ ip link add veth-cnt type veth peer name br-veth-cnt
$ ip link set veth-cnt netns cnt
$ ip link set br-veth-cnt master br-cnt
$ ip link set br-veth-cnt up
$ ip -n cnt addr add 192.168.22.2/24 dev veth-cnt
$ ip -n cnt link set lo up
$ ip -n cnt link set veth-cnt up
$ ip -n cnt route add default via 192.168.22.1 dev veth-cnt
$ ip netns exec cnt ping -c 3 1.1.1.1
```
Mount cgroup
```sh
$ mkdir /sys/fs/cgroup/memory/cnt
$ echo 10000000 > /sys/fs/cgroup/memory/cnt/memory.limit_in_bytes
$ echo 0 > /sys/fs/cgroup/memory/cnt/memory.swappiness
$ CHILD_PID=$(lsns -t pid | grep "[/]bin/bash --login +h" | awk '{print $4}')
$ echo $CHILD_PID > /sys/fs/cgroup/memory/cnt/tasks
```
Run commands within container
```sh
$ apt update
$ apt install nginx procps curl -y
$ nginx
$ curl 127.0.0.1:80
$ curl 192.168.22.2:80 # from host
$ cat <( </dev/zero head -c 15m) <(sleep 15) | tail
```
Clean all
```sh
$ umount /proc # within container
$ exit # within container
$ umount -R ./fs/merged
$ ip link del br-veth-cnt
$ ip link del br-cnt
$ ip netns del cnt # grep cnt /proc/mounts
```

# Inspect Namespaces within a docker container
Fortunately for us there is a program that simplifies the usage of containers, for us this program is `docker` who manage the life-cycle of running a container. Let's see how does `docker` implement the namespaces running a container.

## Install docker CE
Install docker community edition from official script in [get.docker.com](https://get.docker.com)
```sh
$ curl -fsSL https://get.docker.com -o install_docker.sh
$ less install_docker.sh # optional
$ sh install_docker.sh
$ usermod -aG docker $USER
$ newgrp docker # Or logout and login
```

## Inspect Docker Network

Create a bridge network using docker
```sh
$ docker network create mynet
```
Inspect bridge network, see subnet using IP
```sh
$ BR_NAME=$(ip link | grep -v '@' | awk '/br-/{gsub(":",""); print $2}')
$ ip addr show ${BR_NAME}
```
Inspect Docker bridge network, see subnet using docker
```sh
$ docker network inspect mynet | grep Subnet
```
Run an nginx web server
```sh
$ docker run --name nginx --net mynet -d --rm -p 8080:80 nginx
```
Inspect network namespace from `nginx` container

Create symlink from `/proc` to `/var/run/netns`
```sh
$ CONTAINER_ID=$(docker container ps | awk '/nginx/{print $1}')
$ CONTAINER_PID=$(docker inspect -f '{{.State.Pid}}' ${CONTAINER_ID})
$ mkdir -p /var/run/netns/
$ ln -sfT /proc/${CONTAINER_PID}/ns/net /var/run/netns/${CONTAINER_ID}
```
Check network interface within namespace
```sh
$ ip netns list
$ ip -n ${CONTAINER_ID} link show eth0
```
Check IP address of nginx container
```sh
$ ip -n ${CONTAINER_ID} addr show eth0
$ docker container inspect nginx | grep IPAddress
```

Check port forwarding from 8080 to 80
```sh
$ iptables -t nat -nvL
```
## Inspect cgroups in a docker container

Run a Ubuntu container with limited resources
```sh
$ docker run --name test_cg --memory=10m --cpus=.1 -it --rm ubuntu
```
See cgroup fs hierarchy
```sh
$ CONTAINER_ID=$(docker container ps --no-trunc | awk '/test_cg/{print $1}')
$ tree /sys/fs/cgroup/{memory,cpu}/docker/${CONTAINER_ID}
```
See attached task to container cgroup
```sh
$ docker container top test_cg | tail -n 1 | awk '{print $2}' # container parent PID
$ cat /sys/fs/cgroup/{memory,cpu}/docker/${CONTAINER_ID}/tasks # the same as container parent PID
```
Monitoring the container
```sh
$ docker container stats test_cg
```
Generate CPU load
```sh
$ cat /dev/urandom &> /dev/null
```
Generate Memory load
```sh
$ cat <( </dev/zero head -c 50m) <(sleep 30) | tail
```
## Inspect overlay fs in a docker container

Run a ubuntu container with limited resources
```sh
$ docker run --name test_overlayfs -it --rm debian
```

NOTE: ***The merged layer is the actual container Filesystem***

Inspect lower layers with tree and less
```sh
$ docker container inspect test_overlayfs -f '{{.GraphDriver.Data.LowerDir}}' | awk 'BEGIN{FS=":"}{for (i=1; i<= NF; i++) print $i}' | while read low; do tree -L 2 $low; done | less
```
Inspect upper layer (It's empty)
```sh
$ docker container inspect test_overlayfs -f '{{.GraphDriver.Data.UpperDir}}' | while read upper; do tree $upper; done | less
```
Run command withing the container
```sh
$ apt update && apt install nmap -y
```
Inspect (again) upper layer (now it's not empty)
```sh
$ docker container inspect test_overlayfs -f '{{.GraphDriver.Data.UpperDir}}' | while read upper; do tree $upper; done | less
```
## Inspect docker process namespace
Run docker container
```sh
$ docker run --name test_ps -it --rm ubuntu
```

Launch process within container
```sh
$ sleep 600 &
$ sleep 600 &
$ sleep 600 &
$ sleep 600 &
$ sleep 600 &
$ top
```
See container tree process from container
```sh
$ CONTAINER_PID=$(docker container top test_ps | sed -n '2p' | awk '{print $2}')
$ ps f -g ${CONTAINER_PID}
```
List PID namespaces
```sh
$ lsns -t pid
```
See process using docker
```sh
$ docker container top test_ps
```

# Conclusion

In this tutorial we create our first container from scratch understanding what happen behind the scenes when we run a container. I hope this tutorial helps you to understand the technologies behind the linux containers.

[Source code](https://github.com/ivanmorenoj/how-containers-works)
