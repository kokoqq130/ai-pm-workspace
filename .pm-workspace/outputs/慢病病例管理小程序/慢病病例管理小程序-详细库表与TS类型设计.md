# 慢病病例管理小程序详细库表与 TS 类型设计

## 1. 结论先说

### 1.1 前后端类型能不能共用一套

可以共用，但建议是：

- `共用一套核心领域类型`
- `不要把数据库记录类型、接口类型、页面表单类型完全混成一个`

最适合你现在这种“前后端都自己写、AI 高参与”的做法是：

```text
shared/
  types/
    common.ts
    patient.ts
    document.ts
    timeline.ts
    medication.ts
    summary.ts

miniprogram/
  types/
    view-model.ts

cloudfunctions/
  types/
    db-model.ts
    dto.ts
```

也就是说：

- `shared/types` 放前后端都认同的核心业务类型
- 小程序前端自己再补页面展示用类型
- 云函数自己再补数据库记录和接口 DTO 类型

### 1.2 为什么不建议“所有类型完全一样”

因为这三类东西本质上不是一回事：

1. 数据库记录
带 `_id`、`created_at`、`updated_at`、状态字段、内部字段。

2. 前端表单数据
可能只需要一部分字段，而且允许临时空值。

3. 接口返回数据
可能是处理过、裁剪过、聚合过的数据。

如果强行只用一个类型，后面最容易出现：

- 页面临时字段污染数据库类型
- 接口返回字段和数据库字段混淆
- AI 生成代码时到处塞 `any`

所以更好的方式是：

- 基础字段结构共享
- 不同层各自扩展

### 1.3 后端语言选型结论

当前推荐：

- 主后端使用 `Node.js`
- 共享类型使用 `TypeScript`

不推荐当前首版直接用 Python 作为主后端，原因是：

- 当前后端主要职责是业务编排，不是模型计算
- 数据流、接口流和云函数逻辑更适合 Node.js
- 与前端共享类型更自然

Python 的建议角色是：

- 后续 OCR 服务
- 后续 AI/解析服务
- 后续私有化模型推理服务

也就是说，推荐架构是：

```text
小程序前端（TypeScript）
  -> Node.js 云函数 / API
    -> 可选 Python OCR/AI 服务
```

### 1.4 结构化提取策略结论

当前推荐：

- OCR 负责把图片/PDF 转成文本
- LLM 负责把文本提取成标准化 JSON
- Node.js 后端负责：
  - 调 OCR
  - 调 LLM
  - 校验 JSON
  - 持久化数据

不推荐当前首版直接用大量正则表达式作为主解析方案。

原因：

- 医学资料版式差异极大
- 医院和文档格式不统一
- 用规则去提取药品、剂量、诊断会快速失控

### 1.5 用户自填 API Key 的策略

如果后续支持用户自填模型 API Key，推荐：

- Key 在设置页录入
- 前端不直接调用第三方模型
- 由后端拿 Key 去请求模型服务
- 仅在用户明确启用后使用

需要额外注意：

- 这意味着部分病历文本会发送到用户选择的第三方模型服务商
- 必须在隐私政策和授权文案中明确说明
- 不建议把这项能力作为首版强依赖

## 2. 推荐类型分层

## 2.1 基础公共类型

建议共用：

- ID 类型
- 时间字段类型
- 状态枚举
- 文档类型枚举
- 事件类型枚举

示例：

```ts
export type ID = string

export type TimestampString = string

export type DocumentStatus =
  | 'pending'
  | 'processing'
  | 'recognized'
  | 'parsed'
  | 'failed'

export type DocumentType =
  | 'outpatient_record'
  | 'prescription'
  | 'lab_report'
  | 'discharge_summary'
  | 'imaging_report'
  | 'other'

export type TimelineEventType =
  | 'visit'
  | 'exam'
  | 'medication'
  | 'hospitalization'
  | 'surgery'
  | 'manual_note'
```

## 2.2 数据库记录类型

数据库记录类型建议后端优先维护。

特点：

- 字段完整
- 带 `_id`
- 带审计字段
- 更接近真实存储结构

例如：

```ts
export interface PatientRecord {
  _id: ID
  owner_user_id: ID
  name: string
  gender?: 'male' | 'female' | 'unknown'
  birth_year?: number
  disease_tags: string[]
  allergy_notes?: string
  remark?: string
  created_at: TimestampString
  updated_at: TimestampString
}
```

## 2.3 接口 DTO 类型

DTO 指接口入参和出参。

例如：

- `CreatePatientInput`
- `CreatePatientResponse`
- `GenerateVisitSummaryInput`

特点：

- 面向调用
- 字段更克制
- 不需要把数据库内部字段全暴露出去

## 2.4 前端页面 ViewModel

前端页面常常需要“为了显示方便而组合后的字段”。

例如摘要页可能需要：

```ts
export interface SummaryPageViewModel {
  patientName: string
  currentDiseasesText: string
  currentMedicationsText: string
  recentExamText: string
  summaryText: string
}
```

这类类型不建议反向拿去当数据库 schema。

## 3. 现有表/集合总览

当前首版建议的集合如下：

- `users`
- `patients`
- `documents`
- `document_ocr_results`
- `timeline_events`
- `medication_records`
- `visit_summaries`
- `operation_logs`

可选扩展集合：

- `user_ai_provider_settings`

它们的关系可以先理解为：

```text
users
  -> patients
    -> documents
      -> document_ocr_results
    -> timeline_events
    -> medication_records
    -> visit_summaries

users
  -> operation_logs
```

## 4. 详细表设计

## 4.1 users

### 用途

记录小程序用户身份，用于数据隔离。

### 为什么需要这张表

虽然微信登录已经有 `openid`，但系统仍然需要一个自己的用户记录，方便后续：

- 关联患者
- 做操作日志
- 扩展手机号绑定
- 扩展多成员协作

### 字段说明

| 字段名 | 类型 | 必填 | 含义 | 备注 |
|---|---|---|---|---|
| `_id` | string | 是 | 系统内部主键 | CloudBase 自动生成或自定义 |
| `openid` | string | 是 | 微信登录标识 | 用户唯一标识 |
| `nickname` | string | 否 | 用户昵称 | 可为空 |
| `created_at` | string | 是 | 创建时间 | ISO 字符串 |
| `updated_at` | string | 是 | 更新时间 | ISO 字符串 |

### TS 示例

```ts
export interface UserRecord {
  _id: string
  openid: string
  nickname?: string
  created_at: string
  updated_at: string
}
```

## 4.2 patients

### 用途

记录某个用户管理的患者档案。

### 为什么需要这张表

一个微信用户可能管理多个患者，例如：

- 自己
- 父亲
- 母亲
- 配偶

所以患者需要独立建模。

### 字段说明

| 字段名 | 类型 | 必填 | 含义 | 备注 |
|---|---|---|---|---|
| `_id` | string | 是 | 患者主键 | |
| `owner_user_id` | string | 是 | 所属用户 ID | 指向 `users._id` |
| `owner_openid` | string | 是 | 所属用户微信标识 | 便于 CloudBase 安全规则校验 |
| `name` | string | 是 | 患者姓名或昵称 | 首版建议支持昵称 |
| `gender` | string | 否 | 性别 | `male` / `female` / `unknown` |
| `birth_year` | number | 否 | 出生年份 | 不一定要求完整生日 |
| `disease_tags` | string[] | 否 | 疾病标签 | 如高血压、糖尿病 |
| `allergy_notes` | string | 否 | 过敏史说明 | |
| `remark` | string | 否 | 其他备注 | |
| `created_at` | string | 是 | 创建时间 | |
| `updated_at` | string | 是 | 更新时间 | |
| `is_deleted` | boolean | 否 | 是否已软删除 | 默认 `false` |
| `deleted_at` | string | 否 | 软删除时间 | 未删除为空 |

### TS 示例

```ts
export interface PatientRecord {
  _id: string
  owner_user_id: string
  owner_openid: string
  name: string
  gender?: 'male' | 'female' | 'unknown'
  birth_year?: number
  disease_tags: string[]
  allergy_notes?: string
  remark?: string
  created_at: string
  updated_at: string
  is_deleted?: boolean
  deleted_at?: string | null
}
```

## 4.3 documents

### 用途

记录每一份上传的原始资料。

### 为什么需要这张表

病历图片、PDF、处方、检查单都是独立资料，需要：

- 跟患者关联
- 记录状态
- 追踪 OCR 处理流程

### 字段说明

| 字段名 | 类型 | 必填 | 含义 | 备注 |
|---|---|---|---|---|
| `_id` | string | 是 | 资料主键 | |
| `patient_id` | string | 是 | 所属患者 ID | 指向 `patients._id` |
| `owner_openid` | string | 是 | 所属用户微信标识 | 用于数据库安全规则 |
| `file_path` | string | 是 | 云存储路径 | 原始文件路径 |
| `file_type` | string | 是 | 文件格式 | 如 `image`、`pdf` |
| `source_type` | string | 是 | 资料来源 | 首版通常为 `upload` |
| `status` | string | 是 | 当前处理状态 | `pending`/`processing`/`recognized`/`parsed`/`failed` |
| `doc_type` | string | 否 | 文档类型 | 门诊病历、处方、检查单等 |
| `doc_date` | string | 否 | 文档日期 | 识别或人工修正后得到 |
| `hospital_name` | string | 否 | 医院名称 | |
| `department_name` | string | 否 | 科室名称 | |
| `created_at` | string | 是 | 创建时间 | |
| `updated_at` | string | 是 | 更新时间 | |
| `is_deleted` | boolean | 否 | 是否已软删除 | 默认 `false` |
| `deleted_at` | string | 否 | 软删除时间 | 未删除为空 |

### 备注

- `documents` 代表“原始资料”
- 识别后的详细内容不要全部堆在这张表里
- 推荐增加 `is_deleted` / `deleted_at` 实现软删除

## 4.4 document_ocr_results

### 用途

存储 OCR 原文和结构化识别结果。

### 为什么需要单独拆表

因为 OCR 结果通常较大，而且可能需要：

- 保留原始文本
- 保留结构化 JSON
- 支持人工修正

单独拆出来更清晰。

### 字段说明

| 字段名 | 类型 | 必填 | 含义 | 备注 |
|---|---|---|---|---|
| `_id` | string | 是 | OCR 结果主键 | |
| `document_id` | string | 是 | 对应资料 ID | 指向 `documents._id` |
| `owner_openid` | string | 是 | 所属用户微信标识 | 便于按用户隔离 |
| `raw_text` | string | 否 | OCR 原始全文文本 | 便于回看和调试 |
| `structured_json` | object | 否 | 结构化结果 | 诊断、药物、检查等 |
| `confidence` | number | 否 | 识别置信度 | 可选 |
| `manual_corrected` | boolean | 是 | 是否被人工修正 | 默认 `false` |
| `created_at` | string | 是 | 创建时间 | |
| `updated_at` | string | 是 | 更新时间 | |
| `is_deleted` | boolean | 否 | 是否已软删除 | 默认 `false` |
| `deleted_at` | string | 否 | 软删除时间 | 未删除为空 |

### structured_json 建议结构

```ts
export interface StructuredMedicalData {
  docType?: DocumentType
  docDate?: string
  hospitalName?: string
  departmentName?: string
  diagnosisKeywords?: string[]
  medications?: Array<{
    drugName: string
    dosage?: string
    frequency?: string
  }>
  examItems?: Array<{
    itemName: string
    resultText?: string
  }>
  summary?: string
}
```

### LLM 输出约束建议

建议后端要求模型：

- 只返回 JSON
- 不要生成解释性文字
- 不确定的字段返回 `null` 或留空
- 不允许编造医院、药名、诊断

## 4.5 timeline_events

### 用途

存储患者的时间线事件。

### 为什么需要单独建表

因为时间线不是原始资料本身，而是从资料中提炼出来的“事件层”。

例如：

- 2025-03-01 门诊复诊
- 2025-03-05 血常规检查
- 2025-03-08 开始服用某药

### 字段说明

| 字段名 | 类型 | 必填 | 含义 | 备注 |
|---|---|---|---|---|
| `_id` | string | 是 | 事件主键 | |
| `patient_id` | string | 是 | 所属患者 ID | |
| `owner_openid` | string | 是 | 所属用户微信标识 | 便于安全规则控制 |
| `event_date` | string | 是 | 事件日期 | |
| `event_type` | string | 是 | 事件类型 | `visit` / `exam` / `medication` / `hospitalization` / `surgery` / `manual_note` |
| `title` | string | 是 | 事件标题 | 如“门诊复诊” |
| `summary` | string | 否 | 简短描述 | |
| `source_document_id` | string | 否 | 来源资料 ID | 可为空，手工补录时可能没有 |
| `created_at` | string | 是 | 创建时间 | |
| `is_deleted` | boolean | 否 | 是否已软删除 | 默认 `false` |
| `deleted_at` | string | 否 | 软删除时间 | 未删除为空 |

### 备注

- 时间线是“给人看”的摘要层
- 不要把太多原始 OCR 细节直接塞进来
- 推荐增加 `is_deleted` / `deleted_at` 实现软删除

## 4.6 medication_records

### 用途

存储用药记录，便于长期追踪。

### 为什么需要单独建表

药物信息是病例管理里最重要的纵向信息之一，不能只埋在 OCR 结果里。

### 字段说明

| 字段名 | 类型 | 必填 | 含义 | 备注 |
|---|---|---|---|---|
| `_id` | string | 是 | 用药记录主键 | |
| `patient_id` | string | 是 | 所属患者 ID | |
| `owner_openid` | string | 是 | 所属用户微信标识 | |
| `drug_name` | string | 是 | 药品名称 | |
| `dosage` | string | 否 | 剂量 | 如 5mg |
| `frequency` | string | 否 | 频次 | 如 每日一次 |
| `start_date` | string | 否 | 开始时间 | |
| `end_date` | string | 否 | 结束时间 | 未停药可为空 |
| `reason` | string | 否 | 用药原因/停药原因 | |
| `source_document_id` | string | 否 | 来源资料 ID | |
| `created_at` | string | 是 | 创建时间 | |
| `updated_at` | string | 是 | 更新时间 | |
| `is_deleted` | boolean | 否 | 是否已软删除 | 默认 `false` |
| `deleted_at` | string | 否 | 软删除时间 | 未删除为空 |

### 备注

- 首版允许 OCR 自动生成后人工修正
- 后期可扩展“当前用药/历史用药”计算字段

## 4.7 visit_summaries

### 用途

存储生成过的就诊摘要。

### 为什么需要这张表

摘要不是简单页面临时拼接，后面你可能需要：

- 保存历史摘要版本
- 重新生成
- 对比不同时间点摘要

### 字段说明

| 字段名 | 类型 | 必填 | 含义 | 备注 |
|---|---|---|---|---|
| `_id` | string | 是 | 摘要主键 | |
| `patient_id` | string | 是 | 所属患者 ID | |
| `owner_openid` | string | 是 | 所属用户微信标识 | |
| `status` | string | 是 | 摘要状态 | `draft` / `generated` / `archived` |
| `summary_text` | string | 是 | 摘要正文 | 供复制使用 |
| `source_version` | string | 否 | 来源数据版本标识 | 可选 |
| `created_at` | string | 是 | 创建时间 | |
| `updated_at` | string | 是 | 更新时间 | |
| `is_deleted` | boolean | 否 | 是否已软删除 | 默认 `false` |
| `deleted_at` | string | 否 | 软删除时间 | 未删除为空 |

## 4.8 user_ai_provider_settings

### 用途

存储用户是否启用自定义模型服务，以及对应的安全配置。

### 为什么建议单独建表

因为这类配置既不是普通业务数据，也不应该直接混在 `users` 表里。

单独拆表更利于：

- 单独做加密与脱敏
- 单独做权限控制
- 后续支持多个 provider

### 字段说明

| 字段名 | 类型 | 必填 | 含义 | 备注 |
|---|---|---|---|---|
| `_id` | string | 是 | 配置主键 | |
| `owner_openid` | string | 是 | 所属用户微信标识 | 严格按本人访问 |
| `provider_code` | string | 是 | 服务商标识 | 如 `deepseek`、`kimi`、`openai_compatible` |
| `base_url` | string | 否 | 自定义接口地址 | 兼容 OpenAI 风格网关时可填 |
| `model_name` | string | 是 | 模型名称 | |
| `api_key_ciphertext` | string | 是 | 加密后的 API Key | 仅服务端可解密 |
| `api_key_last4` | string | 否 | Key 后 4 位 | 前端仅展示掩码 |
| `enabled_for_extraction` | boolean | 是 | 是否用于 OCR 结构化提取 | |
| `consent_version` | string | 否 | 用户确认的授权版本 | 用于留痕 |
| `created_at` | string | 是 | 创建时间 | |
| `updated_at` | string | 是 | 更新时间 | |

### 备注

- 前端不应拿到 `api_key_ciphertext`
- 建议由云函数用环境变量中的服务端密钥进行加密/解密
- 首版按持久化保存配置设计，更符合后续开关控制、留痕和重复使用需求

## 4.9 operation_logs

### 用途

记录关键操作日志。

### 为什么需要这张表

你的产品涉及敏感资料，至少要记录一些关键动作，方便：

- 排查问题
- 安全审计
- 溯源删除和修改行为

### 字段说明

| 字段名 | 类型 | 必填 | 含义 | 备注 |
|---|---|---|---|---|
| `_id` | string | 是 | 日志主键 | |
| `user_id` | string | 是 | 操作用户 ID | |
| `owner_openid` | string | 是 | 所属用户微信标识 | |
| `patient_id` | string | 否 | 关联患者 ID | |
| `action` | string | 是 | 操作类型 | 如 `login`、`upload_document`、`delete_document` |
| `target_id` | string | 否 | 被操作对象 ID | |
| `detail` | object | 否 | 扩展信息 | 可选 |
| `created_at` | string | 是 | 操作时间 | |

## 5. 当前建议的枚举字典

## 5.1 documents.status

| 值 | 含义 |
|---|---|
| `pending` | 已创建，尚未开始处理 |
| `processing` | 正在 OCR 或处理中 |
| `recognized` | OCR 已完成 |
| `parsed` | 结构化处理已完成 |
| `failed` | 处理失败 |

## 5.2 documents.doc_type

| 值 | 含义 |
|---|---|
| `outpatient_record` | 门诊病历 |
| `prescription` | 处方 |
| `lab_report` | 化验/检验报告 |
| `discharge_summary` | 出院小结 |
| `imaging_report` | 影像报告 |
| `other` | 其他 |

## 5.3 timeline_events.event_type

| 值 | 含义 |
|---|---|
| `visit` | 就诊事件 |
| `exam` | 检查事件 |
| `medication` | 用药事件 |
| `hospitalization` | 住院事件 |
| `surgery` | 手术事件 |
| `manual_note` | 手工补录事件 |

## 6. 索引建议

如果后续 CloudBase 支持或你需要显式配置索引，优先考虑：

- `users.openid`
- `patients.owner_user_id`
- `patients.owner_openid`
- `documents.patient_id + created_at`
- `documents.owner_openid + created_at`
- `document_ocr_results.document_id`
- `timeline_events.owner_openid + event_date`
- `timeline_events.patient_id + event_date`
- `medication_records.patient_id + start_date`
- `medication_records.owner_openid + start_date`
- `visit_summaries.patient_id + created_at`

## 7. 删除联动规则

### 删除单份资料

应联动处理：

- `documents`
- `document_ocr_results`
- `timeline_events` 中引用该 `document_id` 的记录
- `medication_records` 中引用该 `document_id` 的记录
- 必要时重建最新摘要

推荐实现：

- 先软删除
- 后续由清理任务做物理删除

### 删除患者

应联动处理：

- `patients`
- `documents`
- `document_ocr_results`
- `timeline_events`
- `medication_records`
- `visit_summaries`

## 8. CloudBase 安全规则建议

由于这是高敏感数据，推荐每张核心业务集合都带 `owner_openid` 字段。

推荐原则：

- 前端不直接决定是否有权限
- 云函数必须重新按当前登录身份鉴权
- 数据库安全规则也应限制只允许访问自己的记录

示意原则：

```text
allow read, write: if auth != null && auth.openid == doc.owner_openid
```

## 9. 你现在最适合的做法

我对你当前阶段的建议是：

- 先把这 8 张集合按当前版本建起来
- 前后端共享 `shared/types`
- 后端保留 `db-model.ts`
- 前端保留 `view-model.ts`
- 首版主后端使用 Node.js
- Python 暂不进入主流程
- 不要追求一开始把所有类型完全合一

一句话总结：

`核心领域类型共用，数据库类型和页面展示类型分层。`
