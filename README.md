# Codex 一键配置工具

这个工具用于把第三方模型服务商写入 Codex 的用户配置文件。Windows 和 macOS 都可以使用，不需要安装额外软件。

## 使用前准备

请先从模型服务商处准备好以下三项内容：

- 服务商名称：自己起一个容易识别的名字，只能包含英文字母和数字，最多 15 个字符，例如 `wahaha`。不能使用 Codex 保留名称 `openai`、`ollama` 或 `lmstudio`。
- `base_url`：服务商提供的接口地址，必须以 `http://` 或 `https://` 开头，例如 `https://api.example.com/v1`。
- API key：服务商提供的密钥，通常以 `sk-` 开头，但具体格式以服务商说明为准。

不要把 API key 发给别人，也不要在截图中露出完整密钥。脚本会按照当前配置模板，把密钥以明文写进你的个人配置文件。

## Windows

1. 双击 `codex-setup.bat`。
2. 按窗口提示依次输入服务商名称、`base_url` 和 API key。
3. 核对信息。密钥只显示开头和末尾几位。
4. 按回车确认写入。
5. 看到“配置完成”后，按回车关闭窗口，然后完全退出并重新打开 ChatGPT / Codex app。

脚本适用于 Windows 10 或更高版本，并使用系统自带的 Windows PowerShell。普通用户不需要以管理员身份运行。

## macOS

先把从 GitHub 下载的 ZIP 完整解压，不要只单独取出其中一个脚本。最简单的用法是双击 `codex-setup.command`，然后按终端中的提示输入三项内容。输入 API key 时屏幕不会显示字符，这是正常现象；输入完成后直接按回车。

macOS 会检查从互联网下载的脚本。如果第一次双击被阻止，请在 Finder 中右键点击 `codex-setup.command`，选择“打开”，再确认一次。通常不需要进入“隐私与安全性”手动修改设置。

如果仍然提示“没有执行权限”或无法打开，可以使用系统自带的 Bash 运行，不需要修改文件权限：

1. 打开“终端”。
2. 输入 `bash `（`bash` 后保留一个空格）。
3. 把 `codex-setup.command` 从 Finder 拖到终端窗口中。
4. 按回车运行。

也可以先在终端进入解压后的目录，再运行：

```bash
bash codex-setup.command
```

自动化调用示例：

```bash
./codex-setup.sh \
  --name wahaha \
  --base-url https://api.example.com/v1 \
  --key 'sk-xxxxxxxxxxxxxxxx'
```

## 脚本会修改什么

默认配置文件位置：

- Windows：`C:\Users\你的用户名\.codex\config.toml`
- macOS：`~/.codex/config.toml`

如果设置了 `CODEX_HOME` 环境变量，脚本会改用该目录中的 `config.toml`。

脚本会执行以下操作：

- 如果原配置没有 `model`，写入 `model = "gpt-5.6-sol"`。
- 如果原配置没有 `model_reasoning_effort`，写入 `model_reasoning_effort = "high"`。
- 已存在的 `model` 和 `model_reasoning_effort` 会保留原值。
- 把 `model_provider` 切换为本次填写的服务商。
- 新增或更新对应的 `[model_providers.<名称>]` 配置。
- 重复运行同一个服务商名称时更新原配置，不会生成重复表。

现有配置会先备份为类似下面的文件：

```text
config.toml.bak.20260819123045123.a1b2c3d4
```

macOS 的备份文件名格式略有不同，但同样以 `config.toml.bak.` 开头。首次创建配置文件时没有旧内容，因此不会生成备份。

## 恢复备份

1. 完全退出 ChatGPT / Codex app。
2. 打开 `.codex` 配置目录。
3. 找到需要恢复的 `config.toml.bak.*` 文件。
4. 把当前 `config.toml` 移到其他位置留存。
5. 复制备份文件，并把副本重命名为 `config.toml`。
6. 重新打开应用。

不要直接重命名唯一的备份文件，保留一份副本更稳妥。

## 常见问题

### 运行后应用没有变化

请确认已经完全退出应用，而不只是关闭窗口，然后重新打开。也可以检查成功页面显示的配置文件路径是否和你实际使用的 `CODEX_HOME` 一致。

### 提示配置中含有 TOML 多行字符串或多行数组

脚本为了避免误改复杂的跨行配置，会停止并保持原文件不变。需要先人工处理该配置，或手动按照下面的官方配置参考完成修改。

### Windows 窗口显示乱码

请确认使用 Windows 10 或更高版本，并直接运行原始的 `codex-setup.bat`，不要把脚本内容粘贴到旧版命令提示符中执行。

### 配置失败后原文件还在吗

脚本先生成临时文件，成功后才替换 `config.toml`。如果替换前发生错误，原文件不会被覆盖；已经创建的备份也会保留。

## 配置说明

字段含义和支持状态以 [OpenAI 官方 Codex 配置参考](https://developers.openai.com/codex/config-reference/) 为准。官方文档目前仍支持 `experimental_bearer_token`，但更推荐通过环境变量类配置提供凭据；本工具为了满足一键配置模板，仍会把密钥直接写入用户配置文件。
