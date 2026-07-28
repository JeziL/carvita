# CarVita Agent 开发指南

## 适用范围与基本原则

本文件适用于整个仓库。CarVita 是一个以 Android 为当前发布目标、离线优先的 Flutter 车辆保养管理应用。修改前先阅读受影响模块及其调用方，不要把本项目当成通用 Flutter 脚手架。

- 以现有代码、`pubspec.yaml`、`l10n.yaml` 和 Android Gradle 配置为事实来源；README 主要描述产品能力。
- 保持改动聚焦，保留工作区中与当前任务无关的用户修改。
- 不提交密钥、签名文件、Flutter/Gradle 缓存、构建产物或本地生成文件。
- 新增面向用户的行为时，要同时考虑本地数据、预测结果、通知、国际化和备份兼容性。
- 项目采用 GNU AGPLv3；引入代码或资源前确认许可证兼容。

## 项目概览

CarVita 用于：

- 管理多辆车辆及其名称、当前里程、购入日期、照片和识别信息；
- 为每辆车维护按月数和/或里程计算的保养计划；
- 记录保养日期、里程、项目、费用和备注；
- 根据购入日期、历史保养记录和估算的日均里程预测下次保养；
- 在本地展示到期项目并调度 Android 本地通知；
- 将 SQLite 数据库导出为备份，或从数据库文件恢复。

应用数据不依赖远端后端。隐私页面也向用户承诺数据保存在本机，因此不要在没有明确产品决策的情况下引入遥测、远程同步或网络上传。

## 技术栈与工具链

- CI 固定使用 Flutter `3.44.8`；当前对应 Dart `3.12.2`。
- `pubspec.yaml` 的最低工具链约束为 Dart `>=3.12.2 <4.0.0`、Flutter `>=3.44.8`，与 CI 固定版本一致。
- 状态管理同时使用：
  - `flutter_bloc` / Cubit：车辆、保养计划、保养记录、全局到期预测；
  - `provider` / `ChangeNotifier`：语言、里程单位和主题；
  - 普通 `Provider`：全局 `QuickActionService`。
- 持久化：
  - `sqflite` 保存业务数据；
  - `shared_preferences` 保存用户偏好。
- Android 构建使用 Kotlin DSL、Java 17、compile/target SDK 36、AGP 8.13.2、Kotlin 2.3.20、Gradle 8.14.3。
- 当前受支持并纳入版本控制的平台只有 Android；`ios/`、`web/`、`linux/`、`macos/`、`windows/` 均被忽略。
- Android application ID 和 namespace 均为 `com.wangjinli.carvita`。

不要随意升级 Flutter、Dart、Gradle、AGP、Kotlin 或核心插件。工具链升级应独立成改动，并至少完成静态分析和 Android APK 构建。

## 目录地图

```text
lib/
  main.dart                         应用启动、全局依赖和 MaterialApp
  application/
    ports/                          repository、Clock 与设备能力接口
    use_cases/                      车辆、计划、记录、预测和提醒编排
  core/
    constants/                     路由名和固定颜色
    failures/                      typed failure 与内部诊断边界
    services/                      偏好、预测及通知/快捷操作/设备适配器
    theme/                         ColorScheme 与 ThemeExtension
    utils/                         日均里程估算
    widgets/                       跨页面基础组件
  data/
    models/                        车辆、计划、记录、预测等值对象
    repositories/                  application repository port 的 SQLite 实现
    sources/local/database_helper.dart
                                     SQLite 建表、查询和事务
  presentation/
    failures/                      failure 到本地化用户文案的映射
    formatters/                    模型/偏好的本地化展示格式
    manager/                       Cubit、State、语言和主题 Provider
    navigation/                    typed 路由参数、路由装配和快捷导航适配器
    screens/                       页面、详情页 Tab 和局部组件
  i18n/
    app_*.arb                      12 个受版本控制的翻译源文件
    generated/                     flutter gen-l10n 生成，禁止提交
android/                           唯一受支持的平台工程
test/                              单元、数据库、Cubit、Widget 与策略回归测试
tool/                              发布元数据校验脚本
fastlane/metadata/android/         商店文案、截图和版本更新说明
.design/                           README 翻译及商店/宣传设计资源
.github/workflows/flutter.yml      PR/main 质量门禁与 tag 驱动的签名发布流程
assets/icon/                       主图标及其 Cairo 生成脚本
```

## 启动、依赖注入与导航

`lib/main.dart` 的启动顺序是：

1. 初始化 Flutter binding；
2. 初始化本地通知插件；通知权限只在用户启用提醒时请求；
3. 读取系统 locale；
4. 创建 Clock、偏好服务、数据库、repository 实现、application use case 与平台适配器；
5. 注册 Android app shortcut 监听；
6. 注入全局 Provider/Cubit 并启动 `MaterialApp`。

全局对象：

- repository、Clock 和插件实现只在 `main.dart` 组合；Screen/Cubit 不直接创建或依赖具体 repository；
- `LocaleProvider`、`ThemeProvider`、application use case、平台端口和 `QuickActionService` 由 `MultiProvider` 提供；
- `VehicleCubit` 和 `UpcomingMaintenanceCubit` 由 `MultiBlocProvider` 提供；
- `NavigationService.navigatorKey` 供 app shortcut 从应用外入口发起导航；
- `routeObserver` 主要让 Dashboard 在返回或恢复前台时重读筛选偏好。

每辆车详情页会使用全局注入的 `MaintenancePlanUseCases` 和 `ServiceLogUseCases` 创建该车辆专属的 Cubit。快捷入口直接打开记录页时也遵循同一装配方式。向编辑页传递已有 Cubit 时必须使用 `BlocProvider.value`，不要让子路由错误地关闭父页面拥有的 Cubit。

分层边界：

- Presentation 只能依赖 application use case/port，不 import `data/repositories`，也不直接调用文件选择、分享、图片、应用信息、外链或退出插件；
- application 不依赖 Flutter、生成的本地化类或 presentation；
- data model 不依赖 Flutter UI 或本地化；展示字符串放在 `presentation/formatters`；
- core service 不 import Screen/Cubit；快捷入口导航由 presentation adapter 实现；
- 新增跨层能力时先定义可替换 port，再在 `main.dart` 注入默认实现，并同步扩展 `test/architecture/dependency_rules_test.dart`。

项目使用 `MaterialApp.onGenerateRoute` 和 `Navigator` 命名路由，不使用 `go_router`。路由名集中在 `lib/core/constants/app_routes.dart`，参数解析集中在 `lib/presentation/navigation/app_router.dart`。新增或修改路由时：

- 同步更新路由常量、路由解析和所有调用点；
- 使用 `app_route_arguments.dart` 中的 typed arguments，不新增动态 Map 参数协议；
- 对必需参数做显式校验并返回可理解的错误页；
- 所有 `MaterialPageRoute` 保留传入的 `RouteSettings`；
- 注意底部导航使用 `pushNamedAndRemoveUntil(..., (_) => false)` 重建根栈。

## 数据模型与 SQLite 约束

数据库是单例 `DatabaseHelper`，固定文件名为 `carvita_v1.db`，当前 schema 版本为 1，共四张表：

- `vehicles`：车辆主表；图片以 BLOB 保存，日期以 ISO-8601 字符串保存；
- `maintenance_plan_items`：车辆保养计划；
- `service_log_entries`：保养记录主体；
- `service_log_performed_items`：记录与计划项目的关联，也可保存一次性的自定义项目名称。

关键语义：

- `Vehicle.id`、计划 ID 和记录 ID 由 SQLite 自增生成，插入前会移除 Map 中的 `id`。
- 删除计划项目是软删除：`isActive` 设为 0。这样历史保养记录仍可保留关联；不要把它轻率改为硬删除。
- 保养记录及其项目关联必须在同一事务中新增或更新。
- 一个已执行项目要么引用 `maintenancePlanItemId`，要么使用 `customItemName`。
- 仓储目前是数据库方法的薄封装；业务计算应放在 service/Cubit，而不是塞进 Widget。

修改数据库时必须：

1. 增加数据库版本；
2. 实现并测试 `onUpgrade`，兼容已有用户数据；
3. 保持导入旧备份的行为可解释；
4. 检查所有 `toMap`、`fromMap`、查询、事务和导出/恢复路径；
5. 覆盖全新安装、旧库升级和恢复备份三种场景。

当前只有 `onCreate`，没有迁移逻辑。表定义声明了外键和级联规则，但 `openDatabase` 没有在 `onConfigure` 中显式执行 `PRAGMA foreign_keys = ON`。不要假定级联删除一定生效；如果代码要依赖外键行为，应先显式启用并为已有数据制定清理/迁移策略。

设置页的“导出数据”只复制 SQLite 文件，不包含 `SharedPreferences`。语言、主题、默认车辆、通知开关等偏好不会随数据库备份恢复。恢复流程会关闭数据库、删除当前库、复制用户选择的文件并要求退出应用。不要在未校验兼容性和失败回滚策略的情况下改动这条高风险路径。

## 保养预测规则

预测逻辑位于 `PredictionService`，日均里程估算位于 `MileageEstimator`。

- 先通过 `service_log_performed_items` 找到某计划项目最近一次对应的保养记录。
- 没有历史记录时：
  - 若设置首保周期，则从购入日期/首保目标里程计算；
  - 否则从购入日期/常规目标里程计算。
- 有历史记录时，从最近保养日期和该次保养里程叠加常规周期。
- 同时存在时间和里程周期时，以预测更早到期的一项为准，但 basis 记录为组合类型。
- 日均里程使用可用记录中最早与最晚的有效里程差估算；数据不足或不递增时回退为每年 20,000 单位。
- 默认只返回未来一年范围内的项目；已经逾期的项目仍会包含在内。
- 结果按到期日期、再按项目名排序。

修改算法时优先写纯 Dart 单元测试。利用现有的 `currentDateOverride` 固定当前时间，至少覆盖：月末加月、闰年、没有历史、首保、有历史、时间优先、里程优先、已逾期、里程倒退和零日差。

里程值本身是“单位无关”的数值。设置中的 `km`/`mi` 当前只改变显示标签，不做数值换算。不要悄悄加入部分换算；如要支持真实单位转换，需要为现有数据设计明确迁移方案。

## 状态刷新与副作用

业务写操作成功后，通常不只需要刷新当前列表：

- 新增、编辑或删除车辆：
  - 刷新 `VehicleCubit`；
  - 重新加载 `UpcomingMaintenanceCubit`。
- 新增、编辑或软删除保养计划：
  - 刷新当前车辆的 `MaintenancePlanCubit`；
  - 必要时刷新 `ServiceLogCubit`，因为历史显示名依赖计划项目；
  - 重新加载全局到期预测。
- 新增、编辑或删除保养记录：
  - 刷新当前车辆的 `ServiceLogCubit`；
  - 重新加载全局到期预测；
  - 若用户同意用记录里程更新车辆，再刷新 `VehicleCubit`。
- 修改通知开关、提前天数或语言：
  - 取消或重新调度通知；
  - 通知文案应使用当前 locale。

`UpcomingMaintenanceCubit.loadAllUpcomingMaintenance` 调用 `LoadUpcomingMaintenance` 遍历所有车辆并重新查询计划、记录和关联，再由 `SynchronizeMaintenanceReminders` 按 latest-wins 协议重建通知。不要把它放入高频 build 或无意义的循环中。

通知安排在“到期日前 N 天的本地时间中午 12:00”，使用 `inexactAllowWhileIdle`。通知 ID 由车辆 ID 与计划 ID 的组合 hash 得到。变更 ID、channel、调度时间或 payload 会影响已有通知的替换和取消行为。

Vehicle/Plan/Log Cubit 的初始加载由创建方显式触发，构造函数不自动 fetch。写命令在 repository 成功后等待刷新并返回 `OperationResult`；刷新失败通过 `OperationSuccess.followUpFailure` 表达，UI 仍保留最后一次成功数据。若重构该时序，必须同步修改调用方并加测试。

repository、Cubit 和平台异常使用 `AppFailure`/`OperationFailure` 分类。内部异常与堆栈只进入开发诊断；用户文案统一通过 `AppFailureLocalizer` 映射，禁止把 `e.toString()`、SQL、文件路径或硬编码英文直接展示给用户。

所有跨 `await` 的 UI 操作都要检查 `mounted` 或 `context.mounted`。不要仅用 lint ignore 掩盖失效的 `BuildContext`。

## 国际化

`l10n.yaml` 指定：

- 模板：`lib/i18n/app_en.arb`；
- 输入目录：`lib/i18n`；
- 输出目录：`lib/i18n/generated`；
- 输出入口：`app_localizations.dart`。

当前 12 个 locale 分别为：

`ar`、`de`、`en`、`es`、`fr`、`it`、`ja`、`ko`、`pt`、`ru`、`zh`（简体）和 `zh_Hant`（繁体）。

所有 ARB 当前均有 167 个消息 key。新增用户可见文本时：

1. 先在 `app_en.arb` 添加消息和 `@message` 描述/placeholder 类型；
2. 同步补齐另外 11 个 ARB，保持 placeholder 名称和 ICU 类型一致；
3. 运行 `flutter gen-l10n`；
4. 运行 `flutter analyze`；
5. 不提交 `lib/i18n/generated/`，它已被 `.gitignore` 排除。

新增 locale 还必须同步 `appSupportedLocales` 和设置页显示名称。简体/繁体中文依赖 script code 区分，避免只比较 language code。新 UI 不要硬编码英文；内部诊断文本可以保留稳定英文，但用户可见错误应走 `AppLocalizations`。

## UI、主题与资源约定

- 主题由 `ColorScheme.fromSeed` 和 `AppTheme.getThemeData` 构建。
- 渐变及渐变上的文字颜色通过 `AppThemeExtensions` 取得。
- 渐变页面优先复用 `GradientBackground`；普通表面优先使用 `colorScheme` 的 surface/onSurface 色。
- 紧急/删除语义统一使用 `AppColors.urgentReminderText`。
- 同时检查亮色、暗色和自定义 seed color；不要假定固定背景上的文字颜色。
- 应用将系统文字缩放限制在 0.8–1.2，仍需避免固定高度导致本地化文本截断。
- 车辆图片在选择时压缩到质量 70、最大宽度 800，并直接写入数据库；增大图片尺寸会直接放大数据库和备份。
- app icon 源文件是 `assets/icon/icon.png`，可由 `assets/icon/icon_generator.py` 重新生成；launcher 资源由 `flutter_launcher_icons.yaml` 控制。
- Android app shortcut 使用 `action_log` 和 `action_upcoming_list`，图标分别来自 `ic_action_log`、`ic_action_list` 的亮/暗资源。修改类型字符串时要同步监听、动态 shortcut 和原生资源。

## Android、签名与通知

Android Manifest 注册了：

- `POST_NOTIFICATIONS`；
- `RECEIVE_BOOT_COMPLETED`；
- flutter_local_notifications 的调度和重启 receiver；
- 主 Activity 的 `singleTop` 启动模式。

应用显式设置 `android:allowBackup="false"`，并通过 Android 11- 的 `backup_rules.xml` 与 Android 12+ 的 `data_extraction_rules.xml` 排除所有云备份和设备迁移 domain。修改数据库、偏好或隐私文案时，必须继续保持这三处配置、应用内隐私页和商店 Data safety 声明一致。

精确闹钟权限当前被注释，通知使用非精确调度。新增后台、相机、存储或网络能力时，需同时检查 Manifest、运行时权限、隐私说明和 Android 版本差异。

`android/app/build.gradle.kts` 已分离 debug 和 release 签名。debug 使用标准 Android debug 身份，不读取 release secrets；release 仅在 `android/key.properties` 和 keystore 完整有效时配置签名，缺少配置的 release task 会在构建前给出明确错误。绝对不要提交：

- `android/key.properties`；
- `*.jks` / `*.keystore`；
- 密码、base64 keystore 或 CI secret。

CI 会从 GitHub secrets 生成 keystore 和 `key.properties`，并使用
`APP_CERT_SHA256` 校验产物证书指纹。该指纹 secret 必须与发布证书一致。
本地 debug 构建和 PR 质量门禁不得依赖 release secrets。如果本地只需分析 Dart 代码，不应为了绕过签名而修改已跟踪的 Gradle 配置。

## 常用命令与验证

在仓库根目录运行：

```bash
flutter pub get
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
flutter build apk --debug
```

需要实际格式化时运行：

```bash
dart format lib test tool
```

图标变更后可运行：

```bash
dart run flutter_launcher_icons
```

仓库已有覆盖第一、二阶段基础重构的单元、数据库、Cubit、Widget、架构依赖、Android 策略和发布校验测试。修改业务逻辑、状态时序、分层边界、备份或发布门禁后必须运行：

```bash
flutter test
```

验证要求按改动风险递增：

- 文档/纯文案：检查链接、拼写和受影响的 ARB；
- Dart 逻辑/UI：格式检查、`flutter gen-l10n`、`flutter analyze`；
- 预测/数据库/Cubit：补单元或集成测试并运行 `flutter test`；
- 插件、Manifest、Gradle、依赖：再构建 Android debug APK；
- 发布相关：验证 release 构建、签名、version/tag 和 changelog 对应关系。

如果命令因本机缺少 SDK、签名或设备而无法运行，要在交付说明中明确指出，不要用“应该通过”代替真实结果。

## 建议的测试落点

第一阶段已建立基础回归测试；后续新增逻辑时继续优先补齐：

- `test/core/services/prediction_service_test.dart`：纯计算和日期边界；
- `test/core/utils/mileage_estimator_test.dart`：回退值和异常历史；
- 数据库测试：四张表 CRUD、事务、软删除、迁移和备份兼容；
- Cubit 测试：loading/loaded/error 及写后刷新时序；
- Widget 测试：表单校验、路由参数、主题和关键 locale；
- Android 集成验证：通知权限、重启后通知、快捷入口、导入/导出和图片选择。

通知、文件选择、分享、图片选择和 package info 都依赖平台 channel。单元/Widget 测试中应注入或 mock 边界，不要让测试依赖真实系统弹窗。

## 发布流程

版本号位于 `pubspec.yaml`，格式为 `major.minor.patch+versionCode`。GitHub Actions 在以下情况运行：

- 手动 `workflow_dispatch`；
- pull request；
- push 到 `main`；
- push 形如 `vX.Y.Z+N` 的 tag。

pull request 和 `main` push 会运行不依赖发布密钥的 `Quality` job，包括依赖解析、本地化生成、格式检查、静态分析、测试和 debug APK 构建。`main` 的仓库规则要求 `Quality` 通过。

tag 发布会先通过 `Quality`，再运行 `Release`：

1. 使用 Flutter 3.44.8；
2. 验证 tag 与 `pubspec.yaml` version 精确一致、versionCode 单调递增，且英文和简体中文 changelog 都存在且非空；
3. 验证签名 secrets，并生成临时 keystore 和 `key.properties`；
4. 构建 release APK，使用 `APP_CERT_SHA256` 校验证书身份；
5. 生成 APK SHA-256 checksum；
6. 根据 versionCode 读取英文 changelog，创建 GitHub Release 并上传 universal APK 与 checksum。

发布版本时至少同步：

- `pubspec.yaml` 的 version；
- `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt`；
- `fastlane/metadata/android/zh-CN/changelogs/<versionCode>.txt`；
- 必要的商店文案和截图。

不要创建与 `pubspec.yaml` version 不一致、versionCode 未递增或缺少任一双语 changelog 的发布 tag，否则 CI 会在创建 GitHub Release 前主动失败。

## Agent 完成任务前检查

- 已理解受影响页面、Cubit、仓储和数据库调用链。
- Screen/Cubit 未绕过 application use case/port 直接依赖 repository 或设备插件。
- 没有提交 generated、build、缓存、签名或秘密文件。
- 所有用户可见文本已补齐 12 个 ARB。
- 用户错误文案未泄露异常、SQL 或路径，内部诊断保留在开发日志。
- 数据写入后所需的局部和全局状态均已刷新。
- 预测变更考虑了时间、里程、首保、历史和逾期。
- schema 变更包含版本升级、迁移与备份兼容处理。
- 异步 UI 代码检查了 mounted，路由参数类型保持一致。
- 已运行与改动相称的真实验证，并如实报告未能运行的检查。
- `git diff` 中只有任务所需改动，格式化没有波及无关文件。
