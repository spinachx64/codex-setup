@echo off & setlocal EnableExtensions DisableDelayedExpansion
rem codex-setup.bat - 一键配置 Codex (ChatGPT app) 模型提供方
rem 双击即可运行。也可以先设置以下环境变量来预填内容：
rem   set CODEX_NAME=wahaha & set CODEX_BASE_URL=https://api.example.com/v1 & set CODEX_KEY=sk-xxx
rem   codex-setup.bat
chcp 65001 >nul 2>&1
title Codex Setup
where powershell >nul 2>&1 || (
  echo.
  echo PowerShell was not found. Windows 10 or newer is required.
  echo.
  pause
  set "EXITCODE=1"
  goto :BATCH_END
)
set "CODEX_SETUP_SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $s=[IO.File]::ReadAllText($env:CODEX_SETUP_SELF); $i=$s.LastIndexOf('#PSSTART'); $j=$s.LastIndexOf('#PSEND'); if ($i -lt 0 -or $j -le $i) { throw 'Embedded setup boundaries were not found.' }; Invoke-Expression $s.Substring($i+8, $j-($i+8)) } catch { Write-Host ''; Write-Host ('Setup failed: ' + $_.Exception.Message) -ForegroundColor Red; Write-Host ''; [void](Read-Host 'Press Enter to close this window'); exit 1 }"
set "EXITCODE=%ERRORLEVEL%"
goto :BATCH_END

#PSSTART
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Pause-Exit($code) {
  Write-Host ''
  Write-Host '按回车键关闭窗口...' -ForegroundColor DarkGray
  [void](Read-Host)
  exit $code
}

function Mask($value) {
  if ($value.Length -le 10) { return ('*' * $value.Length) }
  return $value.Substring(0, 6) + ('*' * 6) + $value.Substring($value.Length - 4)
}

function Ask($label, $hint, $example, $rule, $errmsg) {
  while ($true) {
    Write-Host ''
    Write-Host ('  ' + $label) -ForegroundColor White
    if ($hint)    { Write-Host ('    ' + $hint) -ForegroundColor DarkGray }
    if ($example) { Write-Host ('    例如：' + $example) -ForegroundColor DarkGray }
    $value = Read-Host '  请输入'
    if (-not $value) {
      Write-Host '  这一项不能空着，请重新填。' -ForegroundColor Red
      continue
    }
    if ($rule -and ($value -notmatch $rule)) {
      Write-Host ('  ' + $errmsg) -ForegroundColor Red
      continue
    }
    return $value
  }
}

function ConvertTo-TomlString($value) {
  return $value.Replace('\', '\\').Replace('"', '\"').Replace("`b", '\b').Replace("`t", '\t').Replace("`n", '\n').Replace("`f", '\f').Replace("`r", '\r')
}

function Test-TopKey($line, $key) {
  $escaped = [Regex]::Escape($key)
  $singleQuote = [char]39
  $pattern = '^\s*(?:' + $escaped + '|"' + $escaped + '"|' + $singleQuote + $escaped + $singleQuote + ')\s*='
  return [Regex]::IsMatch($line, $pattern)
}

function Get-HeaderName($line) {
  $match = [Regex]::Match($line, '^\s*\[\[?(.*?)\]\]?\s*(?:#.*)?$')
  if (-not $match.Success) { return $null }
  return (($match.Groups[1].Value -replace '\s', '').Replace('"', '').Replace("'", ''))
}

# --- 欢迎页 ---
Clear-Host
Write-Host ''
Write-Host '  Codex 一键配置工具' -ForegroundColor Cyan
Write-Host '  ==================' -ForegroundColor Cyan
Write-Host ''
Write-Host '  这个工具会帮你把模型服务商的配置写入 Codex 配置文件，'
Write-Host '  接下来需要你填 3 项内容，照着提示粘贴就行。'
Write-Host ''
$dir = $env:CODEX_HOME
if (-not $dir) { $dir = Join-Path $env:USERPROFILE '.codex' }
$cfg = Join-Path $dir 'config.toml'
Write-Host '  配置文件位置：' -NoNewline
Write-Host $cfg -ForegroundColor Yellow
Write-Host '  修改现有配置前会自动备份，出问题可以还原。' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  提示：在窗口里按 Ctrl+V 或点右键可以粘贴。' -ForegroundColor DarkGray
Write-Host ''

# --- 引导输入：填错当场重填，不退出 ---
$name = $env:CODEX_NAME
if (-not $name) {
  $name = Ask '第 1 / 3 项：给这个服务商起个名字' `
    '只能用英文字母和数字，不超过 15 个字符。这个名字会显示在软件左下角，自己认得就行。' `
    'wahaha' `
    '^[A-Za-z0-9]{1,15}$' `
    '只能用英文字母和数字，且不超过 15 个字符，请重新填。'
}

$url = $env:CODEX_BASE_URL
if (-not $url) {
  $url = Ask '第 2 / 3 项：服务商给你的网址 (base_url)' `
    '一般在服务商的页面上能复制到，要以 http:// 或 https:// 开头。' `
    'https://api.example.com/v1' `
    '^https?://\S+$' `
    '这不像一个网址，要以 http:// 或 https:// 开头，请重新填。'
}

$key = $env:CODEX_KEY
if (-not $key) {
  $key = Ask '第 3 / 3 项：服务商给你的密钥 (key)' `
    '通常是很长的一串。粘贴后会在屏幕上显示，方便你核对有没有粘全。' `
    'sk-xxxxxxxxxxxxxxxx' `
    $null `
    $null
}

$name = $name.Trim()
$url = $url.Trim()

# 环境变量传进来的值也要校验，不能绕过检查。
if ($name -notmatch '^[A-Za-z0-9]{1,15}$') {
  Write-Host ''
  Write-Host ("  错误：名字只能用英文字母和数字且不超过 15 个字符（当前：'$name'）") -ForegroundColor Red
  Pause-Exit 1
}
if ($name -in @('openai', 'ollama', 'lmstudio')) {
  Write-Host ''
  Write-Host ("  错误：'$name' 是 Codex 保留名称，请换一个名字。") -ForegroundColor Red
  Pause-Exit 1
}

$parsedUri = $null
$validUri = [Uri]::TryCreate($url, [UriKind]::Absolute, [ref]$parsedUri)
if (-not $validUri -or $parsedUri.Scheme -notin @('http', 'https') -or -not $parsedUri.Host -or $url.Contains('\')) {
  Write-Host ''
  Write-Host ("  错误：网址必须是完整的 http:// 或 https:// 地址（当前：'$url'）") -ForegroundColor Red
  Pause-Exit 1
}
if (-not $key) {
  Write-Host ''
  Write-Host '  错误：密钥不能为空。' -ForegroundColor Red
  Pause-Exit 1
}

# --- 写入前确认 ---
Write-Host ''
Write-Host '  ------------------------------------' -ForegroundColor Cyan
Write-Host '  请核对一下：' -ForegroundColor Cyan
Write-Host ''
Write-Host '    名字    : ' -NoNewline; Write-Host $name -ForegroundColor Yellow
Write-Host '    网址    : ' -NoNewline; Write-Host $url -ForegroundColor Yellow
Write-Host '    密钥    : ' -NoNewline; Write-Host (Mask $key) -ForegroundColor Yellow
Write-Host ''
Write-Host '  写入位置: ' -NoNewline; Write-Host $cfg -ForegroundColor Yellow
Write-Host '  ------------------------------------' -ForegroundColor Cyan
Write-Host ''
$answer = Read-Host '  没问题就按回车开始写入，输入 n 放弃'
if ($answer -match '^\s*[nN]') {
  Write-Host ''
  Write-Host '  已放弃，没有改动任何文件。' -ForegroundColor DarkGray
  Pause-Exit 0
}

$tmp = $null
try {
  $hadConfig = Test-Path -LiteralPath $cfg -PathType Leaf
  if ($hadConfig) {
    $original = [IO.File]::ReadAllText($cfg)
  } else {
    $original = ''
  }

  # 行级更新无法可靠区分跨行结构中的表头，因此遇到它时宁可停止，也不冒险损坏配置。
  $hasMultilineArray = [Regex]::IsMatch($original, '(?m)^[ \t]*[^#\s][^=\r\n]*=[ \t]*\[[^\]\r\n]*$')
  if ($original.Contains('"""') -or $original.Contains("'''") -or $hasMultilineArray) {
    throw '现有 config.toml 含有 TOML 多行字符串或多行数组。为避免损坏文件，脚本已停止，文件没有改动。'
  }

  if ($original.Contains("`r`n")) { $newline = "`r`n" } else { $newline = [Environment]::NewLine }
  if ($original.Length -eq 0) {
    $lines = @()
  } else {
    $lines = [Regex]::Split($original, "`r`n|`n|`r")
  }

  $modelLine = $null
  $effortLine = $null
  $modelCount = 0
  $effortCount = 0
  $providerCount = 0
  foreach ($line in $lines) {
    if ($null -ne (Get-HeaderName $line)) { break }
    if (Test-TopKey $line 'model') {
      $modelCount++
      if ($null -eq $modelLine) { $modelLine = $line }
    }
    if (Test-TopKey $line 'model_reasoning_effort') {
      $effortCount++
      if ($null -eq $effortLine) { $effortLine = $line }
    }
    if (Test-TopKey $line 'model_provider') { $providerCount++ }
  }
  if ($modelCount -gt 1) { throw '现有配置含有重复的顶层 model。请先修复 config.toml，再重新运行。' }
  if ($effortCount -gt 1) { throw '现有配置含有重复的顶层 model_reasoning_effort。请先修复 config.toml，再重新运行。' }
  if ($providerCount -gt 1) { throw '现有配置含有重复的顶层 model_provider。请先修复 config.toml，再重新运行。' }

  $targetHeader = 'model_providers.' + $name
  $body = New-Object 'System.Collections.Generic.List[string]'
  $pastTop = $false
  $skipProvider = $false
  foreach ($line in $lines) {
    $header = Get-HeaderName $line
    $isHeader = $null -ne $header
    if (-not $pastTop -and $isHeader) { $pastTop = $true }
    if (-not $pastTop -and ((Test-TopKey $line 'model') -or
                            (Test-TopKey $line 'model_reasoning_effort') -or
                            (Test-TopKey $line 'model_provider'))) {
      continue
    }

    if ($isHeader) {
      if ($header -eq $targetHeader -or ($header -and $header.StartsWith($targetHeader + '.', [StringComparison]::Ordinal))) {
        $skipProvider = $true
        continue
      }
      if ($skipProvider) { $skipProvider = $false }
    }
    if (-not $skipProvider) { [void]$body.Add($line) }
  }

  while ($body.Count -gt 0 -and [String]::IsNullOrWhiteSpace($body[0])) { $body.RemoveAt(0) }
  while ($body.Count -gt 0 -and [String]::IsNullOrWhiteSpace($body[$body.Count - 1])) { $body.RemoveAt($body.Count - 1) }

  $escapedName = ConvertTo-TomlString $name
  $escapedUrl = ConvertTo-TomlString $url
  $escapedKey = ConvertTo-TomlString $key
  $result = New-Object 'System.Collections.Generic.List[string]'
  if ($null -ne $modelLine) { [void]$result.Add($modelLine) } else { [void]$result.Add('model = "gpt-6.1-sol"') }
  if ($null -ne $effortLine) { [void]$result.Add($effortLine) } else { [void]$result.Add('model_reasoning_effort = "high"') }
  [void]$result.Add('model_provider = "' + $escapedName + '"')
  [void]$result.Add('')
  foreach ($line in $body) { [void]$result.Add($line) }
  if ($body.Count -gt 0) { [void]$result.Add('') }
  [void]$result.Add('[model_providers.' + $name + ']')
  [void]$result.Add('name = "' + $escapedName + '"')
  [void]$result.Add('base_url = "' + $escapedUrl + '"')
  [void]$result.Add('wire_api = "responses"')
  [void]$result.Add('experimental_bearer_token = "' + $escapedKey + '"')

  [IO.Directory]::CreateDirectory($dir) | Out-Null
  $tmp = Join-Path $dir ('.config.toml.tmp.' + [Guid]::NewGuid().ToString('N'))
  $utf8NoBom = New-Object Text.UTF8Encoding($false)
  [IO.File]::WriteAllText($tmp, ([String]::Join($newline, $result) + $newline), $utf8NoBom)

  $backup = $null
  if ($hadConfig) {
    $stamp = Get-Date -Format 'yyyyMMddHHmmssfff'
    $suffix = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $backup = $cfg + '.bak.' + $stamp + '.' + $suffix
    Copy-Item -LiteralPath $cfg -Destination $backup
  }

  Move-Item -LiteralPath $tmp -Destination $cfg -Force
  $tmp = $null

  Write-Host ''
  Write-Host '  配置完成！' -ForegroundColor Green
  Write-Host ''
  Write-Host '  配置文件：' -NoNewline; Write-Host $cfg -ForegroundColor Yellow
  if ($backup) {
    Write-Host '  备份文件：' -NoNewline; Write-Host $backup -ForegroundColor Yellow
  }
  if ($modelCount -eq 1) {
    Write-Host '  已保留原来的 model，没有修改。' -ForegroundColor DarkGray
  }
  if ($effortCount -eq 1) {
    Write-Host '  已保留原来的 model_reasoning_effort，没有修改。' -ForegroundColor DarkGray
  }
  Write-Host ''
  Write-Host '  请完全退出并重新打开 ChatGPT / Codex app。' -ForegroundColor Cyan
  Pause-Exit 0
} catch {
  if ($tmp -and (Test-Path -LiteralPath $tmp)) {
    Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
  }
  Write-Host ''
  Write-Host '  配置失败，没有替换原配置文件。' -ForegroundColor Red
  Write-Host ('  原因：' + $_.Exception.Message) -ForegroundColor Red
  Pause-Exit 1
}
#PSEND

:BATCH_END
exit /b %EXITCODE%
