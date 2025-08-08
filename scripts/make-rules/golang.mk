# ==============================================================================
# 用来进行编译的 Makefile
#

GO := go

GO_BUILD_FLAGS += -ldflags "$(GO_LDFLAGS)"

ifeq ($(GOOS),windows)
	GO_OUT_EXT := .exe
endif

ifeq ($(ROOT_PACKAGE),)
	$(error the variable ROOT_PACKAGE must be set prior to including golang.mk)
endif

GOPATH := $(shell go env GOPATH)
ifeq ($(origin GOBIN), undefined)
	GOBIN := $(GOPATH)/bin
endif

# 获取项目 cmd/ 目录下的所有子目录（排除.md文件）：/path/to/project/cmd/miniblog /path/to/project/cmd/miniblogctl
COMMANDS ?= $(filter-out %.md, $(wildcard $(PROJ_ROOT_DIR)/cmd/*))
# 将完整路径列表转换为可执行文件名列表：miniblog miniblogctl
BINS ?= $(foreach cmd,${COMMANDS},$(notdir $(cmd)))

ifeq ($(COMMANDS),)
  $(error Could not determine COMMANDS, set PROJ_ROOT_DIR or run in source dir)
endif
ifeq ($(BINS),)
  $(error Could not determine BINS, set PROJ_ROOT_DIR or run in source dir)
endif

# 检查系统是否安装了 Go 工具链
go.build.verify:
	@if ! which go &>/dev/null; then echo "Cannot found go compile tool. Please install go tool first."; exit 1; fi

# go.build.%目标定义是 Makefile 中非常强大的模式规则（Pattern Rule），用于实现多平台交叉编译的自动化。
# 例如：当目标为 go.build.linux_amd64.miniblog时：
# 		%匹配 linux_amd64.miniblog，后续通过字符串处理提取平台和命令名

## 目标 go.build.linux_amd64.miniblog→ $*= linux_amd64.miniblog
## 将点号替换为空格：linux_amd64 miniblog
go.build.%: ## 编译 Go 源码.
	$(eval COMMAND := $(word 2,$(subst ., ,$*)))
	$(eval PLATFORM := $(word 1,$(subst ., ,$*)))
	$(eval OS := $(word 1,$(subst _, ,$(PLATFORM))))
	$(eval ARCH := $(word 2,$(subst _, ,$(PLATFORM))))
	@echo "===========> Building binary $(COMMAND) $(VERSION) for $(OS) $(ARCH)"
	@mkdir -p $(OUTPUT_DIR)/platforms/$(OS)/$(ARCH)
	@CGO_ENABLED=1 GOOS=$(OS) GOARCH=$(ARCH) $(GO) build $(GO_BUILD_FLAGS) \
		-o $(OUTPUT_DIR)/platforms/$(OS)/$(ARCH)/$(COMMAND)$(GO_OUT_EXT) \
		$(ROOT_PACKAGE)/cmd/$(COMMAND)

# 内层 addprefix 将 BINS 列表中的每个元素添加平台前缀：linux_amd64.miniblog linux_amd64.miniblogctl
# 外层 addprefix 为每个平台+命令组合添加 go.build.前缀：go.build.linux_amd64.miniblog go.build.linux_amd64.miniblogctl
go.build: go.build.verify $(addprefix go.build., $(addprefix $(PLATFORM)., $(BINS))) # 根据指定的平台编译源码.

# -type f：只搜索文件（不包括目录）
# gofmt是 Go 语言官方提供的格式化工具​​：-s：简化代码（去除冗余结构）-w：直接修改文件（而不是输出到终端）
# goimports是比 gofmt 更强大的格式化工具（需额外安装）：自动添加缺失的 import，删除未使用的 import
# -local 此选项使导入分组时区分项目内部包和第三方包，例如下面所示：
# import (
# 	"fmt"
# 	"strings"
	
# 	"github.com/onexstack/miniblog/pkg/util" // 项目内部包分组
# )
go.format: tools.verify.goimports ## 格式化 Go 源码.
	@echo "===========> Running formaters to format codes"
	@$(FIND) -type f -name '*.go' | $(XARGS) gofmt -s -w
	@$(FIND) -type f -name '*.go' | $(XARGS) goimports -w -local $(ROOT_PACKAGE)
	@$(GO) mod edit -fmt

go.tidy: ## 自动添加/移除依赖包.
	@echo "===========> Running 'go mod tidy'..."
	@$(GO) mod tidy

go.test: ## 执行单元测试.
	@echo "===========> Running unit tests"
	@mkdir -p $(OUTPUT_DIR)
	@$(GO) test -race -cover \
		-coverprofile=$(OUTPUT_DIR)/coverage.out \
		-timeout=10m -shuffle=on -short \
		-v `go list ./...|egrep -v 'tools|vendor|third_party'`

go.cover: go.test ## 执行单元测试，并校验覆盖率阈值.
	@echo "===========> Running code coverage tests"
	@$(GO) tool cover -func=$(OUTPUT_DIR)/coverage.out | awk -v target=$(COVERAGE) -f $(PROJ_ROOT_DIR)/scripts/coverage.awk

go.lint: tools.verify.golangci-lint ## 执行静态代码检查.
	@echo "===========> Running golangci to lint source codes"
	@golangci-lint run -c $(PROJ_ROOT_DIR)/.golangci.yaml $(PROJ_ROOT_DIR)/...

# 伪目标（防止文件与目标名称冲突）
.PHONY: go.build.verify go.build.% go.build go.format go.tidy go.test go.cover go.lint
