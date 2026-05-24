# Debian VM — Portable Docker Dev Environment

Debian Bookworm 容器，主机网络直通，SSH + tmux 开箱即用。双击 BAT 创建或进入。

## 架构

```
Windows (E:\debian-vm\)
  └─ WSL Kali
       └─ Docker
            ├─ debian-vm  (host 网络, SSH :2222)
            ├─ another-vm (host 网络, SSH :2223)
            └─ ...
```

## 文件

| 文件 | 作用 |
|------|------|
| `Dockerfile` | 镜像定义：Debian Bookworm + SSH + tmux + curl/git/vim |
| `docker-compose.yml` | `network_mode: host`，`${VM_NAME}` 变量注入 |
| `setup.bat` | 交互式创建容器（名称、端口） |
| `shell.bat` | 列出所有运行容器，手动选择进入 |

## 快速开始

1. 双击 **`setup.bat`**
2. 输入容器名（默认 `debian-vm`）
3. 输入 SSH 端口（默认 `2222`）
4. 构建完成 → 双击 **`shell.bat`** 进入

## 容器详情

| 项目 | 值 |
|------|-----|
| 基础镜像 | `debian:bookworm-slim` |
| root 密码 | `debian123` |
| 普通用户 | `vm` / `vm123` |
| 已装工具 | tmux, curl, wget, git, vim, lsof, net-tools, procps, locales |
| 网络模式 | host（与 WSL 共享 IP 和端口） |

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
```

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
