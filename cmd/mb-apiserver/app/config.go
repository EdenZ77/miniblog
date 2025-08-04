// Copyright 2024 孔令飞 <colin404@foxmail.com>. All rights reserved.
// Use of this source code is governed by a MIT style
// license that can be found in the LICENSE file. The original repo for
// this file is https://github.com/onexstack/miniblog. The professional
// version of this repository is https://github.com/onexstack/onex.

package app

import (
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/spf13/cobra"
	"github.com/spf13/viper"
)

const (
	// defaultHomeDir 定义放置 miniblog 服务配置的默认目录.
	defaultHomeDir = ".miniblog"

	// defaultConfigName 指定 miniblog 服务的默认配置文件名.
	defaultConfigName = "mb-apiserver.yaml"
)

// onInitialize 设置需要读取的配置文件名、环境变量，并将其内容读取到 viper 中.
func onInitialize() {
	if configFile != "" {
		// 从命令行选项指定的配置文件中读取
		viper.SetConfigFile(configFile)
	} else {
		// 使用默认配置文件路径和名称
		for _, dir := range searchDirs() {
			// 将 dir 目录加入到配置文件的搜索路径
			viper.AddConfigPath(dir)
		}

		// 设置配置文件格式为 YAML
		viper.SetConfigType("yaml")

		// 配置文件名称（没有文件扩展名）
		viper.SetConfigName(defaultConfigName)
	}

	// 读取环境变量并设置前缀
	setupEnvironmentVariables()

	// 读取配置文件.如果指定了配置文件名，则使用指定的配置文件，否则在注册的搜索路径中搜索
	if err := viper.ReadInConfig(); err != nil {
		log.Printf("Failed to read viper configuration file, err: %v", err)
	}

	// 打印当前使用的配置文件，方便调试
	log.Printf("Using config file: %s", viper.ConfigFileUsed())
}

// setupEnvironmentVariables 配置环境变量规则.
func setupEnvironmentVariables() {
	// 允许 viper 自动匹配环境变量
	viper.AutomaticEnv()
	// 设置环境变量前缀
	viper.SetEnvPrefix("MINIBLOG")
	// 替换环境变量 key 中的分隔符 '.' 和 '-' 为 '_'
	replacer := strings.NewReplacer(".", "_", "-", "_")
	viper.SetEnvKeyReplacer(replacer)
}

// searchDirs 返回默认的配置文件搜索目录.
func searchDirs() []string {
	// 获取用户主目录
	homeDir, err := os.UserHomeDir()
	// 如果获取用户主目录失败，则打印错误信息并退出程序
	cobra.CheckErr(err)
	return []string{filepath.Join(homeDir, defaultHomeDir), "."}
}

// filePath 获取默认配置文件的完整路径.
func filePath() string {
	home, err := os.UserHomeDir()
	// 如果不能获取用户主目录，则记录错误并返回空路径
	cobra.CheckErr(err)
	return filepath.Join(home, defaultHomeDir, defaultConfigName)
}

/*
Viper 会按照以下顺序覆盖配置值（后出现的优先级更高）：

​​默认值​​（如果 opts 结构体字段有默认值）
​​配置文件​​（通过 viper.ReadInConfig() 加载）
​​环境变量​

配置文件​​：
viper.SetConfigFile(configFile)
viper.ReadInConfig()             // 读取到 Viper 的配置存储
假设 config.yaml 内容：
server:
  port: 8080
  timeout: 10s


环境变量​​：
viper.SetEnvPrefix("FASTGO")
viper.AutomaticEnv()
假设设置了环境变量：
export FASTGO_SERVER_PORT=9090
export FASTGO_SERVER_TIMEOUT=5s


最终结果​​
viper.Unmarshal(opts)
opts.Server.Port → 9090（环境变量覆盖配置文件）
opts.Server.Timeout → 5s（环境变量覆盖配置文件）


结构体定义​​
type Options struct {
    Server struct {
        Port    int    `mapstructure:"port"`    // Viper 默认用 mapstructure 标签
        Timeout string `mapstructure:"timeout"`
    }
}

*/
