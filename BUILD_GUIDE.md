# 打包指南

## 项目结构

本项目包含两个产品变体：

| 产品 | 包名 | 类型 | 用途 |
|------|------|------|------|
| merchant | com.example.restaurant.merchant | app | 商家版应用 |
| customer | com.example.restaurant.customer | atomicService | 顾客版元服务 |

---

## 方法一：DevEco Studio 打包（推荐）

### 步骤 1：选择产品变体

1. 打开 DevEco Studio
2. 在工具栏找到产品选择下拉框
3. 选择要打包的产品：
   - `merchant` - 商家版
   - `customer` - 顾客版

### 步骤 2：配置签名（首次需要）

1. 菜单：`File` → `Project Structure`
2. 左侧选择 `Signing Configs`
3. 选择对应的 Product（merchant 或 customer）
4. 勾选 `Automatically generate signing`（调试签名）
5. 点击 `Apply` → `OK`

### 步骤 3：构建 HAP/APP

**调试包（Debug）：**
- 菜单：`Build` → `Build Hap(s)/APP(s)` → `Build Hap(s)`
- 产出物：`{module}/build/default/outputs/default/entry-default-signed.hap`

**发布包（Release）：**
- 菜单：`Build` → `Build Hap(s)/APP(s)` → `Build APP(s)`
- 产出物：`build/outputs/{product}-release.app`

---

## 方法二：命令行打包

### 前置条件

确保 DevEco Studio 的命令行工具已加入环境变量：

```powershell
# 添加到 PATH（根据实际安装路径调整）
$env:PATH += ";C:\DevEco Studio\bin"
```

### 打包命令

```bash
# 打包商家版 HAP（调试）
hvigorw assembleHap -p product=merchant -p buildMode=debug

# 打包商家版 APP（发布）
hvigorw assembleApp -p product=merchant -p buildMode=release

# 打包顾客版 HAP（调试）
hvigorw assembleHap -p product=customer -p buildMode=debug

# 打包顾客版 APP（发布）
hvigorw assembleApp -p product=customer -p buildMode=release
```

---

## 产出物位置

| 类型 | 路径 |
|------|------|
| 商家版 HAP | `entry/build/default/outputs/default/entry-default-signed.hap` |
| 商家版 APP | `build/outputs/merchant-release.app` |
| 顾客版 HAP | `customer/build/default/outputs/default/customer-default-signed.hap` |
| 顾客版 APP | `build/outputs/customer-release.app` |

---

## 安装测试

### 模拟器安装

```bash
# 安装商家版
hdc install entry/build/default/outputs/default/entry-default-signed.hap

# 安装顾客版
hdc install customer/build/default/outputs/default/customer-default-signed.hap
```

### 真机安装

1. 开启开发者模式
2. USB 连接手机
3. 允许 USB 调试
4. 使用上述命令安装

---

## 发布到应用市场

### 商家版（普通应用）

1. 打包 Release APP
2. 登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)
3. 创建/选择应用
4. 上传 APP 包
5. 填写应用信息
6. 提交审核

### 顾客版（元服务）

1. 打包 Release APP（bundleType: atomicService）
2. 登录 AppGallery Connect
3. 创建元服务类型应用
4. 上传 APP 包
5. 配置元服务链接
6. 提交审核

---

## 常见问题

### Q: 签名失败
A: 检查 `build-profile.json5` 中签名配置是否正确

### Q: 找不到 hvigorw 命令
A: 使用 DevEco Studio 打包，或将 DevEco 工具加入环境变量

### Q: 元服务无法免安装
A: 确保 `bundleType` 为 `atomicService`，`installationFree` 为 `true`

