# 签名证书配置说明

## 目录结构

```
signing/
├── merchant/           # 商家版签名文件
│   ├── merchant.p12    # 密钥库文件
│   ├── merchant.cer    # 证书文件
│   └── merchant.p7b    # Profile文件
│
├── customer/           # 顾客版签名文件
│   ├── customer.p12    # 密钥库文件
│   ├── customer.cer    # 证书文件
│   └── customer.p7b    # Profile文件
│
└── README.md           # 本说明文件
```

## 生成签名证书步骤

### 方法一：使用 DevEco Studio（推荐）

1. **打开项目签名配置**
   - 菜单：`Build` → `Generate Key and CSR`
   - 或：`File` → `Project Structure` → `Signing Configs`

2. **生成密钥库(.p12文件)**
   - Key store path: 选择保存路径（如 `signing/merchant/merchant.p12`）
   - Password: 设置密码（记住这个密码）
   - Alias: 设置别名（如 `merchant_key`）
   - Key password: 设置密钥密码

3. **申请证书和Profile**
   - 登录 [华为开发者联盟](https://developer.huawei.com/consumer/cn/)
   - 进入 AppGallery Connect
   - 创建应用并配置证书

4. **配置自动签名**
   - `File` → `Project Structure` → `Signing Configs`
   - 勾选 `Automatically generate signing`
   - DevEco Studio 会自动申请调试证书

### 方法二：命令行生成密钥库

```bash
# 生成商家版密钥库
keytool -genkeypair -alias merchant_key -keyalg EC -sigalg SHA256withECDSA \
  -dname "CN=Merchant,O=Restaurant,C=CN" -keystore signing/merchant/merchant.p12 \
  -storetype PKCS12 -storepass your_password -keypass your_password -validity 365

# 生成顾客版密钥库
keytool -genkeypair -alias customer_key -keyalg EC -sigalg SHA256withECDSA \
  -dname "CN=Customer,O=Restaurant,C=CN" -keystore signing/customer/customer.p12 \
  -storetype PKCS12 -storepass your_password -keypass your_password -validity 365
```

## 配置密码

在 `build-profile.json5` 中填入密码：

```json5
{
  "name": "merchant_signing",
  "material": {
    "storePassword": "你的密钥库密码",
    "keyPassword": "你的密钥密码",
    ...
  }
}
```

⚠️ **安全提示**：不要将密码提交到版本控制！

建议使用环境变量或 `local.properties`：

```properties
# local.properties (不要提交到Git)
MERCHANT_STORE_PASSWORD=xxx
MERCHANT_KEY_PASSWORD=xxx
CUSTOMER_STORE_PASSWORD=xxx
CUSTOMER_KEY_PASSWORD=xxx
```

## 调试签名（开发阶段）

开发调试时，可以使用 DevEco Studio 的自动签名功能：

1. `File` → `Project Structure` → `Signing Configs`
2. 选择对应的 Product
3. 勾选 `Automatically generate signing`
4. 点击 `Apply` 和 `OK`

DevEco Studio 会自动申请华为调试证书。

## 发布签名（上架阶段）

上架应用市场需要正式证书：

1. 登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html)
2. 创建项目和应用
3. 申请发布证书和Profile
4. 下载证书文件到对应目录
5. 更新 `build-profile.json5` 中的路径和密码

## 常见问题

### Q: 提示"签名失败"
A: 检查密码是否正确，证书文件路径是否存在

### Q: 元服务签名要求
A: 元服务需要申请专门的元服务Profile，bundleType需为"atomicService"

### Q: 如何申请元服务Profile
A: 在AGC控制台创建应用时选择"元服务"类型

