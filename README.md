# Debian / openEuler VM — Portable Docker Dev Environment

Debian 或 openEuler 容器（均用 `latest` 基础镜像），主机网络直通，SSH + tmux 开箱即用。双击 BAT 创建或进入。

## 架构

```
Windows (任意目录，BAT 自动定位)
  └─ WSL Kali
       └─ Docker
            ├─ debian-vm  (host 网络, SSH :2222)
            ├─ euler-vm   (host 网络, SSH :2223)
            └─ ...
```

## 文件

| 文件 | 作用 |
|------|------|
| `Dockerfile` | Debian 镜像定义：SSH + tmux + curl/git/vim（base image 由 `BASE_IMAGE` 参数注入） |
| `Dockerfile.euler` | openEuler 镜像定义，结构同上 |
| `docker-compose.yml` | Debian 服务，`network_mode: host`，`${VM_NAME}` 变量注入 |
| `docker-compose.euler.yml` | openEuler 服务，结构同上，密码默认 `euler123` |
| `setup.bat` | 交互式创建容器（发行版、名称、端口） |
| `shell.bat` | 列出所有运行容器，手动选择进入 |

## 快速开始

1. 双击 **`setup.bat`**
2. 选择发行版：
   - `1` = Debian latest（默认）
   - `2` = openEuler latest
3. 输入容器名（默认按发行版 `debian-vm` / `euler-vm`）
4. 输入 SSH 端口（默认 `2222`）
5. 构建完成 → 双击 **`shell.bat`** 进入

基础镜像为 `debian:latest`（目前 Debian 13 trixie）和 `openeuler/openeuler:latest`（目前 24.03 LTS-SP4），建置时 `--pull` 确保抓最新。想固定版本就改 `.env` 的 `BASE_IMAGE`（如 `debian:bookworm-slim` / `openeuler/openeuler:24.03-lts`）。

## 容器详情

### Debian

| 项目 | 值 |
|------|-----|
| 基础镜像 | `debian:latest`（目前 13 trixie） |
| root 密码 | `debian123`（可用 `ROOT_PASS` 覆盖） |
| 普通用户 | `vm` / `vm123`（可用 `VM_PASS` 覆盖，sudo 组） |
| 已装工具 | tmux, curl, wget, git, vim, lsof, net-tools, procps, locales, sudo |

### openEuler

| 项目 | 值 |
|------|-----|
| 基础镜像 | `openeuler/openeuler:latest`（目前 24.03 LTS-SP4） |
| root 密码 | `euler123`（可用 `ROOT_PASS` 覆盖） |
| 普通用户 | `vm` / `vm123`（可用 `VM_PASS` 覆盖，wheel 组） |
| 已装工具 | tmux, curl, wget, git, vim, lsof, net-tools, shadow, sudo |

两个发行版均为 host 网络模式（与 WSL 共享 IP 和端口）。

## SSH 连接

```bash
ssh root@localhost -p 2222     # 默认端口
ssh root@localhost -p 2223     # 第二个容器
```

Windows 终端直接连即可，WSL 自动转发 localhost。

## 多实例

每个容器独立端口和卷，重复跑 `setup.bat` 即可：

```
setup.bat → 名: dev1, 端口: 2222
setup.bat → 名: dev2, 端口: 2223
setup.bat → 名: dev3, 端口: 2224
```

卷自动按项目名隔离（`dev1_debian-home`, `dev2_debian-home` ...）。

## 设计决策

### 为什么 build 总是加 `--pull`
`docker build` 默认复用本地已有的 base image，`latest` 不会自动更新；每次建置 `--pull` 强制检查 registry，避免拿到半年前的旧镜像。

### 为什么 openEuler 用独立 compose 文件
Debian 用 apt、openEuler 用 dnf，用户组、sshd_config 默认值都不同；单 Dockerfile 条件分支难维护。两个 compose 文件各 18 行，复制成本低，`.env` 保持精简（`VM_NAME` / `SSH_PORT` / `BASE_IMAGE`）。

### 为什么 `network_mode: host`
- 避免 24000 个端口逐一映射
- 避免端口冲突时的复杂排错
- 容器端口 = WSL 端口，无需额外转发

### 为什么 `VM_NAME` 而不是 `NAME`
- `NAME` 是 Windows/WSL 系统环境变量（主机名）
- Docker Compose 变量替换会被系统变量覆盖
- 用 `VM_NAME` 避免冲突

### 为什么 SSH 端口可配
- host 网络共享端口空间
- 多个容器不能同时占 22
- `ARG SSH_PORT` 在 Dockerfile 构建时注入

### 为什么不用 JSON 配置
- JSON 无注释、引号敏感、嵌套难读
- Docker Compose YAML 可注释、缩进即层级、禁用选项不报错
- 参考：Docker、K8s、Home Assistant 均采用 YAML

## 踩坑记录

### Docker credential store
WSL Docker 默认引用 `docker-credential-desktop.exe`，该二进制在 WSL 内不可用。
```bash
# 修复：清空 credsStore
echo '{}' > ~/.docker/config.json
```

### WSL2 下 `systemd` 不可用
`systemctl` 和 `systemd user services` 在 WSL2 中默认关闭。
需在 `/etc/wsl.conf` 添加 `[boot] systemd=true` 后 `wsl --shutdown` 重启。

### 端口冲突
`network_mode: host` 下所有容器共享端口。端口被占时 sshd 退出码 255。
解决：为每个容器分配不同 SSH 端口。

### Docker Compose 变量替换限制
`volumes:` 顶层 key 不支持变量：
```yaml
# 错误
volumes:
  ${NAME}-home:    # 不被解析

# 正确：用静态名 + -p 项目名前缀隔离
volumes:
  debian-home:     # docker compose -p mybox → mybox_debian-home
```

### openEuler 与 Debian 的差异

RPM 安装 `openssh-server` **不会生成 host key**（Debian 的 postinst 会），容器内必须补：
```dockerfile
RUN ssh-keygen -A
```
否则 sshd 启动即退出，容器陷入 `Restarting (255)` 循环。常见诱因还有：host 网络下端口被别的容器占用。

openEuler 的 sshd_config 默认已是 `PermitRootLogin yes` / `PasswordAuthentication yes`（Debian 是注释掉的），sed 要同时兼容 `^#?` 两种写法。

基础镜像很精简：没有 `useradd`/`chpasswd`（装 `shadow`）、没有 `sudo`（装 `sudo`）、用户组是 `wheel` 而非 `sudo`；`procps-ng`、`ca-certificates` 已预装，无需重复安装。

`chpasswd` 会打印 `BAD PASSWORD` 警告（pam_pwquality），但默认不强制，密码照常生效。
