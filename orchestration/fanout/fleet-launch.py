#!/usr/bin/env python3
"""fleet-launch.py — pty.fork 兜底启动器 (detached tmux 不灵时用)

用法: fleet-launch.py <project-dir> <cmd> [args...]
  在 <project-dir> 里, 剥掉所有 CLAUDE_CODE_* 环境变量后, 用 pty 起 <cmd> 并 detach
  (调用者立刻返回, ccb 继续在后台跑)。

为什么这样:
  - 剥 CLAUDE_CODE_*: 父会话的 OAuth/session env 会泄漏给子 cc-* → 假 401。
  - pty.fork: ccb 要一个 tty 才肯起 agent pane。
  - fork + setsid: 脱离调用 shell 的会话, ccb 在调用者退出后存活。
  - 排空 pty: 防 ccb 写满输出缓冲阻塞。
"""
import os
import pty
import sys


def main() -> int:
    if len(sys.argv) < 3:
        sys.stderr.write("用法: fleet-launch.py <project-dir> <cmd> [args...]\n")
        return 2
    project = sys.argv[1]
    cmd = sys.argv[2:]
    if not os.path.isdir(project):
        sys.stderr.write("fleet-launch: 无目录 %s\n" % project)
        return 2

    # 1) 剥 CLAUDE_CODE_* (provider key/PATH/HOME 等保留)
    for k in [k for k in list(os.environ) if k.startswith("CLAUDE_CODE")]:
        del os.environ[k]

    # 2) daemonize: 父立刻返回; 子脱离 tty 会话
    if os.fork() > 0:
        return 0
    os.chdir(project)
    os.setsid()

    # 3) pty.fork: 孙进程在 pty 里 exec 目标命令
    pid, fd = pty.fork()
    if pid == 0:
        try:
            os.execvp(cmd[0], cmd)
        except OSError as e:
            sys.stderr.write("exec %s 失败: %s\n" % (cmd[0], e))
            os._exit(127)

    # 4) daemon 排空 pty 输出, 目标退出则结束
    try:
        while True:
            try:
                if not os.read(fd, 4096):
                    break
            except OSError:
                break
    finally:
        os._exit(0)


if __name__ == "__main__":
    sys.exit(main())
