为什么执行make build 命令时 common.mk 被执行两次，现象如下：
```shell
root@debian:~/golang/src/github.com/onexstack/miniblog# make build BINS=mb-apiserver
===========> 11common.mk linux_amd64
===========> 22common.mk
===========> Running 'go mod tidy'...
===========> 11common.mk linux_amd64
===========> 22common.mk
===========> Building binary mb-apiserver v0.0.1-43-g2c2fc38 for linux amd64
root@debian:~/golang/src/github.com/onexstack/miniblog# 
```
问题分析：
```makefile
build: go.tidy
     @$(MAKE) go.build  # 递归调用 make
```
当执行 make build BINS=mb-apiserver时：
- 首先执行依赖项 go.tidy（打印第一次 common.mk 日志）
- 然后执行 @$(MAKE) go.build，这会启动一个新的 make 进程重新解析 Makefile。`include scripts/make-rules/all.mk` 被再次执行，导致 common.mk再次被包含（打印第二次日志）。

解决方案：
```makefile
## 修改前：
build: go.tidy
	@$(MAKE) go.build

## 修改后：
build: go.tidy go.build  # 改为直接依赖而不是递归调用
```

对于 common.mk 文件中的 GO_LDFLAGS 变量需要注意：
```
GO_LDFLAGS += \
	-X $(VERSION_PACKAGE).gitVersion=$(VERSION) \
	-X $(VERSION_PACKAGE).gitCommit=$(GIT_COMMIT) \
	-X $(VERSION_PACKAGE).gitTreeState=$(GIT_TREE_STATE) \
	-X $(VERSION_PACKAGE).buildDate=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
```
当使用 `@$(MAKE) go.build` 执行递归调用时，它会启动一个全新的 make 进程，​​每个 make 进程都有自己独立的变量空间​​，不会继承或影响其他进程的变量值。