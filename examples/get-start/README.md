## 目的
一个基于docker的consul集群demo（多数据中心），目的不是为了在docker中使用consul（这个以后会写），而是借助docker作为承载consul的容器来实现集群搭建，因为consul需要使用的端口比较多。这里有最简单和最基本的（我认为）consul集群配置，旨在解决初学者一开始不知道怎么下手搭建集群的问题。


## 集群架构
* 两个数据中心dc1, dc2
* dc1中有4个节点, 三个server agent组成的server集群，和一个client agent作为客户端使用示例, dc1座位单个数据中示例
* dc2中有2个节点, 一个server, 一个agnet, dc2主要用于测试多数据中心

## 基础环境

### 操作系统
macOS 10.12.2

### docker
`docker version`
```shell
Client:
  Version:      1.12.0
  API version:  1.24
  Go version:   go1.6.3
  Git commit:   8eab29e
  Built:        Thu Jul 28 21:15:28 2016
  OS/Arch:      darwin/amd64

Server:
  Version:      1.12.0
  API version:  1.24
  Go version:   go1.6.3
  Git commit:   8eab29e
  Built:        Thu Jul 28 23:54:00 2016
  OS/Arch:      linux/amd64
```
`docker-compose version`
```shell
docker-compose version 1.8.0, build f3628c7
docker-py version: 1.9.0
CPython version: 2.7.9
OpenSSL version: OpenSSL 1.0.2h  3 May 2016
```

docker版本稍微有点老，不过docker并不是本文的重点

<!--more -->

## 分分钟造火箭

### 启动

[以下所有代码地址](https://github.com/CocaCola183/docker-consul/tree/master/examples/get-start)

集群启动命令:
```shell
docker network create consul
./run.sh
```

### 说明

#### consul下载和安装

因为这里使用的是docker，所以直接pull镜像就可以了，但是还是提一下不使用docker的情况。consul下载地址在[这里](https://www.consul.io/downloads.html)，选择你最喜欢（最新）的版本下载就行了。下载完成之后就只有一个二进制文件（如果你是windows，那就一个exe，双击就能运行），直接执行就可以了。映射到path里面就是安装了，非常的方便。

#### 一个最简单的server配置

dc1-server1
```json
{
  "ui": true,                                     # 开启ui
  "ui_dir": "/consul/ui",                         # ui绝对路径，可以官网下载最新的
  "data_dir": "/consul/data",                     # consul数据存放目录
  "bind_addr": "0.0.0.0",                         # 这个在后面做详细解释
  "bootstrap_expect": 3,                          # 集群预期server节点数量
  "retry_join": ["dc1-server2", "dc1-server3"],   # 组成集群的另外两个节点

  "encrypt": "HSDVV9epQyQ3wYIla5R2hA==",          # gossip密钥，后面说明
  "server": true,                                 # 是否是server
  "retry_interval": "30s",                        # retry_interval和retry_max都是配合retry_join的
  "retry_max": 10,
  "log_level": "INFO",                            # 日志级别(trace, debug, info, warn, err)
  "datacenter": "dc1",                            # 数据中心名称
  "rejoin_after_leave": true,                     # leave之后是否重新加入，这个在这边文章中不重要
  "leave_on_terminate": true                      # 进程关闭后leave
}
```

dc1-server1启动成功输出结果
```shell
==> WARNING: Expect Mode enabled, expecting 3 servers
==> Starting Consul agent...
==> Starting Consul agent RPC...
==> Consul agent running!
           Version: 'v0.7.5'
           Node ID: '6a6f4d95-fdd1-4663-8017-34e3ce6abe68'
         Node name: 'af5238a133cd'
        Datacenter: 'dc1'
            Server: true (bootstrap: false)
       Client Addr: 127.0.0.1 (HTTP: 8500, HTTPS: -1, DNS: 8600, RPC: 8400)
      Cluster Addr: 172.19.0.5 (LAN: 8301, WAN: 8302)
    Gossip encrypt: true, RPC-TLS: false, TLS-Incoming: false
             Atlas: <disabled>
```

这里选择三点进行重点说明:

> bootstrap_expect

因为我这里有三个容器作为consul server，所以这里设定bootstrap_expect为3，任一台启动后都retry_join另外两个节点。server一般推荐3～5个。另外，这里直接写了容器名，是因为docker自建bridge网络下，可以互相解析主机名。如果你是在服务器下使用，那直接写bind_addr的ip好了。

> bind_addr

server agent，这个是consul服务绑定ip，还有一个配置叫advertise_addr，这个是用于和集群中其他节点通信的addr。如果不设置advertise_addr，默认bind_addr就是advertise_addr。还有一个配置叫做client_addr，这个是程序调用的地址，例如，通过http api获取集群信息，或者访问集群web ui，等等。

server agent一般选用public ip作为advertise_addr，private作为client_addr，这样public ip用于多数据中心通信，内网用于调用http api。

这里写0.0.0.0是为了让consul自己去获取ip，因为docker容器的ip不固定，我没法在一开始进行配置。设定0.0.0.0会自动bind机器上的所有ip，advertise第一个ipv4 address，容器起来就两个ip，一个127.0.0.1，一个就是局域网ip，这样就解决了ip问题

> encrypt

这个值可以由consul生成，命令是`consul keygen`，使用这个值进行gossip encrypt。这里其实有一个简单的安全策略, server agent暴露集群ip为内网ip(前提是内网是值得信任的)，如果想要访问只能通过内网实现，如果是要添加client agent，则需要encrypt值。当然除了多数据中心无法实现（如果多个数据中心也组了一个内网也是可以实现的），这个策略提供了一个最基本的安全性保障

### 一个简单的client的配置

dc1-client1
```json
{
  "bind_addr": "0.0.0.0",
  "retry_join": ["dc1-server1"],

  "encrypt": "HSDVV9epQyQ3wYIla5R2hA==",
  "server": false,
  "retry_interval": "30s",
  "retry_max": 10,
  "log_level": "INFO",
  "datacenter": "dc1",
  "rejoin_after_leave": true,
  "leave_on_terminate": true
}
```

启动成功后输出
```shell
==> Starting Consul agent...
==> Starting Consul agent RPC...
==> Consul agent running!
           Version: 'v0.7.5'
           Node ID: '6a6f4d95-fdd1-4663-8017-34e3ce6abe68'
         Node name: '849f9a9af9e4'
        Datacenter: 'dc1'
            Server: false (bootstrap: false)
       Client Addr: 127.0.0.1 (HTTP: 8500, HTTPS: -1, DNS: 8600, RPC: 8400)
      Cluster Addr: 172.19.0.6 (LAN: 8301, WAN: 8302)
    Gossip encrypt: true, RPC-TLS: false, TLS-Incoming: false
             Atlas: <disabled>

==> Log data will now stream in as it occurs:

    2017/03/16 02:06:55 [INFO] serf: EventMemberJoin: 849f9a9af9e4 172.19.0.6
    2017/03/16 02:06:55 [WARN] manager: No servers available
    2017/03/16 02:06:55 [ERR] agent: failed to sync remote state: No known Consul servers
    2017/03/16 02:06:55 [INFO] agent: Joining cluster...
    2017/03/16 02:06:55 [INFO] agent: (LAN) joining: [dc1-server1]
    2017/03/16 02:06:55 [INFO] serf: EventMemberJoin: b54d8793677a 172.19.0.4
    2017/03/16 02:06:55 [INFO] serf: EventMemberJoin: fa4d82838664 172.19.0.3
    2017/03/16 02:06:55 [INFO] serf: EventMemberJoin: 0d816b9e0c1e 172.19.0.2
    2017/03/16 02:06:55 [INFO] agent: (LAN) joined: 1 Err: <nil>
    2017/03/16 02:06:55 [INFO] agent: Join completed. Synced with 1 initial agents
    2017/03/16 02:06:55 [INFO] consul: adding server b54d8793677a (Addr: tcp/172.19.0.4:8300) (DC: dc1)
    2017/03/16 02:06:55 [INFO] consul: adding server fa4d82838664 (Addr: tcp/172.19.0.3:8300) (DC: dc1)
    2017/03/16 02:06:55 [INFO] consul: adding server 0d816b9e0c1e (Addr: tcp/172.19.0.2:8300) (DC: dc1)
    2017/03/16 02:07:01 [INFO] consul: New leader elected: 0d816b9e0c1e
    2017/03/16 02:07:01 [INFO] agent: Synced node info
```

配置基本上和上面一样的，这里只说一点，retry-join这个参数的配置，只需要配置任一server即可，因为其他的server会自动被发现。

#### ui的配置

ui的配置还是很有必要的，这个能非常直观的看到consul集群的信息，[demo](http://demo.consul.io/?_ga=1.9587189.1947061243.1483414531)

配置很简单，只需要把[这里](https://releases.hashicorp.com/consul/0.7.5/consul_0.7.5_web_ui.zip?_ga=1.1614321.1947061243.1483414531)下载下来的静态文件放到配置文件指定的目录即可。

#### 多数据中心

dc2-server1配置中有这么一个配置: `"retry_join_wan": ["dc1-server1"]`

#### 集群搭建完成之后集群成员查看

dc1
```shell
/ # consul members
Node          Address          Status  Type    Build  Protocol  DC
0d816b9e0c1e  172.19.0.2:8301  alive   server  0.7.5  2         dc1
849f9a9af9e4  172.19.0.6:8301  alive   client  0.7.5  2         dc1
b54d8793677a  172.19.0.4:8301  alive   server  0.7.5  2         dc1
fa4d82838664  172.19.0.3:8301  alive   server  0.7.5  2         dc1
```

dc2
```shell
/ # consul members
Node          Address          Status  Type    Build  Protocol  DC
be5a88e5badb  172.19.0.7:8301  alive   client  0.7.5  2         dc2
db92c7930efb  172.19.0.5:8301  alive   server  0.7.5  2         dc2
```

> 注意

这里只是提及了部分配置，所有的配置都写在项目的consul文件夹下，可以参考下不同，理解集群的原理。（很简单）

## 使用

这里介绍集群搭建完成之后最简单的使用方法，以及一些相关的库

### 简单的消除配置文件的方法

服务启动的时候，调用consul api将服务注册到consul集群中，这样其他依赖这个服务的服务就可以获取到前者的ip和port了。其他的一些配置，例如数据库连接数，可以提前注册在key-value store中，这样也能通过api调用获取。一般情况下，配置文件也就基本是这些信息

### 开发过程中正确的使用姿势

本地启动一个agent，加入到consul集群中，然后所有的信息，都从本地consul去获取。这里要强调的是开发过程中不要直接去使用集群中server节点，或者是使用其他client节点。所以任何时候应用需要调用consul api的时候，连接的都是localhost

### 推荐三方库

[node-consul](https://github.com/silas/node-consul) 已经实践过，简单的需求都能满足
[ansible-consul](https://github.com/savagegus/ansible-consul) 如果想使用ansbile部署使用consul，推荐使用这个库，也经过实践验证（可能需要改写）