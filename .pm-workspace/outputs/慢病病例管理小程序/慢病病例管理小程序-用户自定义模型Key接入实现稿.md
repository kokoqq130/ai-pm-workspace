# 慢病病例管理小程序用户自定义模型 Key 接入实现稿

## 1. 结论先说

本项目中，LLM 不是默认能力，而是用户主动启用的可选高级能力。

明确规则：

- 未配置或未启用自定义模型 Key 时，系统不调用任何 LLM
- 默认只保留 `OCR 原文 + 人工修正 + 手工补录`
- 小程序前端不直接调用第三方模型
- 只有后端云函数可以使用用户填写的 Key 代调用模型
- 用户启用前必须看到单独授权提示

一句话版本：

`LLM 是用户自选增强能力，不是平台默认兜底能力。`

## 2. 为什么这样设计

### 2.1 成本原因

- 医疗 OCR 文本通常很长
- 一份资料可能是多页 PDF 或长段病历文本
- 如果平台默认帮所有用户调用模型，成本和调用量很快失控

### 2.2 隐私原因

- 资料里包含高敏感健康信息
- 不应在用户未明确选择时，把文本发送到第三方模型服务商

### 2.3 产品闭环原因

- 首版核心闭环应先保证 `上传 -> OCR -> 原文确认 -> 手工修正/补录`
- LLM 应该是“减少整理工作量”的增强项，而不是基础功能前置门槛

## 3. 用户侧产品形态

## 3.1 设置页增加 AI 高级设置区

建议放在：

- `设置与隐私页`

模块名称建议：

- `AI 高级设置`
- `自定义模型服务`

展示内容建议：

- 当前状态：未启用 / 已启用
- 当前 provider
- 当前 model
- API Key 掩码
- 开启/关闭开关
- 授权说明入口

## 3.2 设置页字段

建议字段如下：

| 字段 | 必填 | 说明 |
|---|---|---|
| `providerCode` | 是 | 服务商标识，如 `deepseek`、`kimi`、`openai_compatible` |
| `baseUrl` | 否 | 自定义接口地址；兼容 OpenAI 网关时可填 |
| `modelName` | 是 | 模型名，如 `deepseek-chat` |
| `apiKey` | 是 | 用户自己的模型 Key |
| `enabledForExtraction` | 是 | 是否用于 OCR 结构化提取 |

首版建议：

- 不做“用于问答”的额外开关
- 先只支持 `enabledForExtraction`

## 3.3 设置页交互流程

建议流程：

1. 用户进入 `设置与隐私页`
2. 点击 `AI 高级设置`
3. 查看能力说明
4. 点击 `启用自定义模型服务`
5. 先弹出授权提示
6. 用户同意后进入配置表单
7. 填写 provider / model / apiKey
8. 点击 `保存并验证`
9. 后端保存加密配置
10. 返回“已启用”状态

## 3.4 表单校验建议

- `providerCode` 必填
- `modelName` 必填
- `apiKey` 必填
- `baseUrl` 在 `openai_compatible` 模式下必填
- 输入框对首尾空格自动 trim
- 禁止把完整 Key 再次回显到页面

## 3.5 已保存后的展示规则

前端只展示：

- provider 名称
- model 名称
- `****` + 最后 4 位
- 开关状态
- 最近更新时间

前端不展示：

- 完整 Key
- 加密后的 Key
- 服务端密钥

## 4. 授权与提示文案

## 4.1 启用前弹窗目标

必须让用户清楚知道：

- 这不是默认能力
- 启用后，资料文本会发送给其指定的第三方模型服务商
- 模型结果可能不准确
- 费用由用户自己的模型服务承担

## 4.2 启用前弹窗建议文案

标题：

- `启用自定义模型服务`

正文：

- 你正在启用自定义模型服务。启用后，你选择处理的 OCR 文本可能会发送到你填写的第三方模型服务商，用于结构化提取。
- 该能力仅在你主动启用后生效。
- 模型输出可能存在误差，请以原始资料和医生判断为准。
- 相关模型调用费用将由你填写的服务商账户承担。

按钮：

- 次按钮：`暂不开启`
- 主按钮：`我已了解并继续`

## 4.3 保存成功提示

- `已保存 AI 配置，后续可用于资料结构化提取`

## 4.4 关闭能力提示

- `关闭后，系统将不再调用你配置的第三方模型服务`

## 5. 云函数与接口设计

## 5.1 saveUserAiSettings

用途：

- 保存当前用户的自定义模型配置

输入示例：

```json
{
  "providerCode": "deepseek",
  "baseUrl": "https://api.deepseek.com/v1",
  "modelName": "deepseek-chat",
  "apiKey": "sk-xxxx",
  "enabledForExtraction": true
}
```

后端要求：

- 必须从登录上下文获取 `openid`
- 只能保存到当前用户自己的配置
- `apiKey` 必须服务端加密后再入库
- 数据库中仅保存密文和后 4 位
- 保存成功后只返回脱敏信息

输出示例：

```json
{
  "enabledForExtraction": true,
  "providerCode": "deepseek",
  "modelName": "deepseek-chat",
  "apiKeyMasked": "****abcd"
}
```

## 5.2 getUserAiSettings

用途：

- 获取当前用户配置的脱敏信息

输出示例：

```json
{
  "enabledForExtraction": true,
  "providerCode": "deepseek",
  "modelName": "deepseek-chat",
  "apiKeyMasked": "****abcd",
  "updatedAt": "2026-03-31T12:00:00.000Z"
}
```

## 5.3 disableUserAiSettings

用途：

- 关闭当前用户的模型调用能力

建议行为：

- 保留配置记录
- 仅把 `enabled_for_extraction` 改成 `false`

这样做的原因：

- 用户下次重新开启更方便
- 便于保留授权与操作留痕

## 5.4 deleteUserAiSettings

用途：

- 删除当前用户保存的模型配置

建议行为：

- 清空密文字段
- 清空最后 4 位
- 关闭开关
- 写操作日志

## 5.5 testUserAiSettings

用途：

- 测试当前 Key 是否可用

建议方式：

- 不要发送真实病历文本
- 发送一个固定的轻量测试 prompt
- 例如要求模型返回一个极小 JSON：`{"ok":true}`

建议返回：

```json
{
  "success": true,
  "providerReachable": true,
  "modelAccepted": true
}
```

## 5.6 parseMedicalDocument

这是关键改造点。

执行规则建议固定为：

1. 云函数从上下文获取当前 `openid`
2. 校验当前用户是否有权访问 `documentId`
3. 读取 OCR 原文
4. 查询 `user_ai_provider_settings`
5. 若不存在配置，或 `enabled_for_extraction != true`
6. 则直接返回“未启用 AI 结构化提取”，不调用模型
7. 前端继续停留在 `OCR 原文确认 + 手工修正` 流程
8. 若已启用，则解密 Key
9. 调用第三方模型
10. 对返回结果做 JSON Schema 校验
11. 校验通过后再写入 `structured_json`

未启用时建议返回：

```json
{
  "status": "manual_review_required",
  "reason": "AI extraction not enabled"
}
```

## 6. 数据库与存储设计

## 6.1 推荐集合

- `user_ai_provider_settings`

## 6.2 推荐字段

| 字段 | 说明 |
|---|---|
| `_id` | 主键 |
| `owner_openid` | 用户归属 |
| `provider_code` | 服务商标识 |
| `base_url` | 接口地址 |
| `model_name` | 模型名 |
| `api_key_ciphertext` | 加密后的 Key |
| `api_key_last4` | Key 后 4 位 |
| `enabled_for_extraction` | 是否启用 OCR 结构化提取 |
| `consent_version` | 授权版本 |
| `created_at` | 创建时间 |
| `updated_at` | 更新时间 |

## 6.3 数据库安全规则

必须满足：

- 用户只能读写自己的配置

原则示意：

```text
allow read, write: if auth != null && auth.openid == doc.owner_openid
```

## 7. 加密实现建议

## 7.1 基本要求

- 不允许明文保存 API Key
- 不允许前端参与加密逻辑
- 不允许日志打印完整 Key

## 7.2 推荐方案

由云函数使用服务端环境变量中的密钥做加密。

例如环境变量：

- `USER_AI_SETTINGS_ENCRYPTION_KEY`

建议做法：

- 使用 Node.js 服务端加密库
- 存储 `ciphertext + iv + tag`
- 解密动作只发生在真正调用模型前

## 7.3 日志脱敏要求

以下内容不能进入普通日志：

- 完整 API Key
- 完整请求头 Authorization
- 完整病历原文

允许进入日志的内容：

- provider 名称
- model 名称
- 掩码后的 Key
- 请求是否成功
- 状态码
- 错误类型

## 8. 前端页面详细建议

## 8.1 设置页结构

```text
设置与隐私页
  账户信息区
  隐私说明区
  数据保留区
  AI 高级设置区
    状态：未启用 / 已启用
    provider
    model
    apiKey 掩码
    [启用]
    [编辑]
    [关闭]
    [删除配置]
```

## 8.2 启用表单页

```text
顶部栏
  返回
  标题：自定义模型服务

说明区
  说明这是可选高级能力
  说明会把资料文本发送到用户指定的模型服务商

表单区
  provider 下拉
  baseUrl 输入框
  modelName 输入框
  apiKey 密码框
  用于 OCR 结构化提取 开关

底部按钮
  [保存并验证]
```

## 8.3 失败态建议

保存失败：

- `保存失败，请检查配置后重试`

验证失败：

- `模型配置不可用，请检查 provider、model 或 API Key`

未启用 AI 时进入 OCR 确认页：

- `你尚未启用 AI 结构化提取，当前可先根据 OCR 原文手工整理关键信息`

## 9. 处理链路建议

## 9.1 未启用 AI 时

```text
上传资料
  -> OCR
  -> 保存 raw_text
  -> 进入 OCR 确认页
  -> 用户手工修正
  -> 更新时间线/摘要
```

## 9.2 已启用 AI 时

```text
上传资料
  -> OCR
  -> 查询当前用户 AI 配置
  -> 调用第三方模型
  -> JSON Schema 校验
  -> 写入 structured_json
  -> 用户确认与修正
  -> 更新时间线/摘要
```

## 10. Prompt 与返回格式建议

## 10.1 Prompt 目标

- 不让模型自由发挥
- 明确只返回 JSON
- 明确不确定就留空
- 不允许编造医院、诊断、药品

## 10.2 返回结构建议

```json
{
  "docType": null,
  "docDate": null,
  "hospitalName": null,
  "departmentName": null,
  "diagnosisKeywords": [],
  "medications": [],
  "examItems": [],
  "summary": null
}
```

## 10.3 校验规则

- 非法 JSON 直接失败
- 字段类型不匹配直接失败
- 允许字段为空
- 不允许附带额外解释性自然语言

## 11. 安全与审计要求

至少记录以下操作日志：

- 用户保存模型配置
- 用户启用模型配置
- 用户关闭模型配置
- 用户删除模型配置
- `parseMedicalDocument` 是否调用了第三方模型
- 第三方模型调用成功或失败

日志中必须避免记录：

- 完整 Key
- 完整病历文本
- 完整请求报文

## 12. 首版上线建议

建议分两阶段：

### 阶段 1

- 不开放 AI 高级设置
- 先只做 `OCR 原文 + 手工修正/补录`

### 阶段 2

- 对少量测试用户开放 `自定义模型服务`
- 先验证：
  - 用户是否真的愿意自己填 Key
  - 实际文本长度是否可控
  - 模型解析质量是否稳定
  - 用户是否能理解授权风险

## 13. 最终建议

如果你现在就要定开发边界，我建议直接按下面这句话执行：

`没配置 Key 就不跑 LLM；配了 Key 也只能后端代调用；任何时候都保留人工修正权。`
