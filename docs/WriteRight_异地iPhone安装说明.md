# WriteRight 异地 iPhone 安装说明

适用对象：开发者把 WriteRight 发给不在身边的朋友测试；对方目前使用 **iOS 18.7.7**。

核查日期：**2026 年 10 月 30 日，Asia/Shanghai**。Apple 的页面名称和分发要求可能调整，操作时以账户实际显示为准。

本文分为开发者准备、朋友安装、更新排错三部分。**本文是操作说明，不表示已开通付费会员、上传构建或取得 TestFlight 审核批准。**

## 1. 先选安装方式

**没有付费开发者会员、她有可用电脑时，可以使用 iLoader 导入 IPA，由她自己的免费 Apple 账户重新签名侧载。** 这条路线需要周期续签，详见第12节及[可单独转发的 iLoader 安装说明](WriteRight_iLoader侧载安装说明.md)。此前免费方案仅列出自己用Xcode编译，遗漏了这条路径，现补充。

如希望减少续签维护，**长期推荐 TestFlight 外部测试**。你上传构建、完成测试审核后，把邀请发给她；她在自己的 iPhone 上安装，不需要来到你身边，也不需要连接你的 Mac。[Apple：TestFlight](https://developer.apple.com/testflight/)

| 方式 | 你需要准备 | 她需要准备 | 适合当前情况吗 |
| --- | --- | --- | --- |
| iLoader 免费账户侧载 | 可供重新签名的真机 IPA，不必购买开发者会员 | 自己的电脑、数据线、Apple账户，定期续签 | **当前无会员可选，需接受7天期限** |
| TestFlight 外部测试 | Apple Developer Program 会员、可分发构建、测试审核和邀请 | iPhone、自己的 Apple 账户、TestFlight | **推荐，异地操作最方便** |
| Ad Hoc 注册设备分发 | 付费开发者会员、她的 UDID、包含该设备的分发描述文件 | 提供 UDID，并通过合适的工具或分发服务安装 | 可选，但步骤更多 |
| 免费 Personal Team 本地安装 | 她在自己的兼容 Mac 上用 Xcode 编译、签名 | Mac、数据线、自己的 Apple 账户与开发环境 | 没有付费会员时的开发测试备选 |
| 正式 App Store | 正式提交和审核、商店资料 | 从 App Store 安装 | 适合后续长期公开使用 |

当前装到你手机上的开发版，不能直接作为通用签名包转发。**把 `.app` 或当前开发签名的 `.ipa` 发到微信/网盘，不会让另一台未授权 iPhone 自动获得安装资格。** iLoader路线需要她在自己的电脑上重新签名，不能只更换文件扩展名。[Apple：分发方式](https://help.apple.com/xcode/mac/current/en.lproj/dev31de635e5.html)、[iLoader：导入IPA](https://github.com/nab138/iloader)

## 2. iOS 18.7.7 能不能装

从当前项目声明看，满足最低版本要求：

| 项目 | 当前配置/核查结果 |
| --- | --- |
| 产品名称 | WriteRight |
| 工程与模块 | EssayPilot |
| App 最低系统 | iOS 17.0，来源为 `ios/project.yml` |
| 对方系统 | iOS 18.7.7，高于最低要求 |
| 当前 Bundle ID | `com.yiyun.essaypilot.dev`，发布时需核对是否属于所选付费 Team |
| 当前项目版本 | 0.1.0，构建号 1；后续上传需要管理递增构建号 |
| 已有真机证据 | 本项目已在开发者的 iOS 27.2 手机安装、启动 |
| iOS 18.7.7 验收状态 | **尚未在这台手机完整验收，满足最低版本不等于所有功能已通过** |

使用较新 Xcode/SDK 构建，并不要求她把手机升级到同一版本；需要保持 App 的最低部署版本，并正确处理新系统 API 的可用性。不要为了上传测试包，把 Deployment Target 顺手提高到 iOS 26 或 27。

Apple 当前列出的 TestFlight iPhone 要求为 iOS 16 或更新版本，因此她的系统也满足 TestFlight 的系统要求。[Apple：TestFlight 安装与测试要求](https://testflight.apple.com/)

---

## 3. 开发者准备：先确认会员与账户

### 3.1 确认有可分发的开发者会员

1. 用你自己的 Apple 账户登录 [Apple Developer](https://developer.apple.com/account/)。
2. 查看是否已经加入 Apple Developer Program，并确认会员有效。
3. 确认能进入 [App Store Connect](https://appstoreconnect.apple.com/)，具备管理该 App 和外部测试的权限。
4. 如只有 Xcode 的 **Personal Team**，需要先开通适用的付费会员，才能走本文的 TestFlight 路线。

本项目此前使用 Personal Team 进行本机开发签名；这不证明当前账户已具备 TestFlight 分发资格。Apple Developer Program 官方标价为每会员年 99 美元，支持地区以当地货币结算，实际金额以 Apple 账户显示为准。**朋友无需购买开发者会员，也无需使用你的 Apple 账户。**[Apple：会员权益与费用](https://developer.apple.com/programs/whats-included/)

免费 Personal Team 的开发描述文件有效期为签发后 7 天，到期需重新构建、安装；它不是适合朋友长期异地使用的分发通道。[Apple：Personal Team 限制](https://developer.apple.com/help/account/basics/about-your-developer-account/)

### 3.2 不要把朋友加成后台管理员来安装

朋友应作为 **External Tester（外部测试者）** 加入。内部测试者属于具有 App Store Connect 内容访问权限的用户，不能把“加入开发后台”当普通用户的安装步骤。[Apple：内部测试者](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/)

---

## 4. 开发者准备：把项目变成可分发构建

### 4.1 确定 Bundle ID 与签名 Team

1. 在付费 Team 下确认或注册一个可用的 App ID。
2. 确保工程、签名描述文件和 App Store Connect 应用记录使用同一个 Bundle ID。
3. `com.yiyun.essaypilot.dev` 可以先核查能否由该 Team 使用；如不能，应选择属于该 Team 的新标识。
4. 如果希望开发版和远程测试版并存，可使用不同 Bundle ID；它们会成为不同 App，本地数据和登录状态不能假定自动迁移。
5. 发布配置选择付费 Team，不能继续选 Personal Team。

示例 `com.yourname.writeright` 仅表示命名形式，**不是已注册或保证可用的标识**。

本项目由 XcodeGen 生成工程，Bundle ID、版本等长期设置应维护在 `ios/project.yml` 或对应构建配置中。只在生成的 `.xcodeproj` 临时改值，下一次生成工程可能被覆盖。签名私钥和证书不写入 Git，也不发给朋友。

### 4.2 确认 Release 包连接云端

朋友的手机不能使用你的 `localhost`、`127.0.0.1` 或只在你家局域网可访问的后端。

本项目已有 Supabase HTTPS 云端配置、邮件验证码和 DeepSeek 评分服务。远程测试可以使用已经配置的开发云项目，但必须确认 **Release 成品** 仍指向你打算开放的云环境。她用自己的邮箱登录 WriteRight，形成独立账户，不要共用你的练习账号。

需要核对：

- Release 构建中的 `SUPABASE_URL` 是可公开访问的正确 HTTPS 地址。
- `SUPABASE_PUBLISHABLE_KEY` 是客户端公开 key。
- DeepSeek key、SMTP 授权码、service-role key、Worker token 只留在服务端。
- 邮箱验证码实际能送达，云函数与定时任务可用，模型账户有可用额度。
- 上传照片的用途告知、账户隔离和私有 Storage 保持有效。

`ios/Config/Release.xcconfig` 虽标记 `production`，目前也会包含本机 `Local.xcconfig`。**这个环境名称不会自动创建或切换后端。** 具体配置见同目录的 [云端配置说明](CloudSetup.md)。

只要手机连接的是正常运行的云服务，日常登录和批改不要求你的 Mac、Docker 或本地函数服务一直开着。测试产生的模型请求会使用你配置的后端和模型额度。

### 4.3 版本与兼容性检查

- 保持最低系统 iOS 17.0。
- 每次上传递增构建号，例如 `0.1.0 (2)`、`0.1.0 (3)`；不要反复上传相同版本下已使用的构建号。
- 确认 Release 配置不启用测试账号、合成报告、DEBUG 样例按钮或测试环境覆盖。
- 能运行模拟器不代表归档和 Release 都通过，需单独验证发布构建。
- 请尽量先检查 iOS 18.x 的兼容性；对方首次测试时按第 8 节验收，不先假定全部可用。

---

## 5. 开发者操作：创建 App、归档并上传

### 5.1 创建 App Store Connect 应用记录

进入 [App Store Connect](https://appstoreconnect.apple.com/) → Apps（我的 App）→ `+` → New App（新建 App），填写：

| 字段 | 填写建议 |
| --- | --- |
| 平台 | iOS |
| 名称 | WriteRight；如名称不可用，选择合适的可用名称 |
| 主要语言 | 按当前产品实际语言选择，例如简体中文 |
| Bundle ID | 第 4.1 节确认的标识 |
| SKU | 自己管理用的唯一编号，例如 `writeright-ios-beta` |
| 用户访问 | 按开发团队实际需要设置 |

先创建记录，再上传匹配的构建。账户如提示待接受的协议，由账户持有人阅读并处理，不要把账户登录信息交给朋友。[Apple：创建应用记录](https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app/)

### 5.2 使用 Xcode 归档

1. 打开 `/Users/llyy/Desktop/EssayPilot/ios/EssayPilot.xcodeproj`。
2. 选择 App Scheme：`EssayPilot`。
3. 核对 Release 的签名、Bundle ID、版本和构建号。
4. 选择通用 iOS 真机目标，例如 `Any iOS Device (arm64)`；名称随 Xcode 版本可能不同。
5. 执行 **Product → Archive**。
6. 在 **Window → Organizer → Archives** 找到本次归档。
7. 先进行可用的 Validate App 检查并修正报错。

归档是可分发构建的起点；校验通过也不等于上传成功或测试审核通过。[Apple：归档与分发](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases/)

### 5.3 上传时选对分发方式

在 Organizer 选择 **Distribute App**，使用适用于 TestFlight 外部测试的 **TestFlight & App Store**；某些界面显示为 **App Store Connect → Upload**。

**不要选择 TestFlight Internal Only。** 这种包限制为内部测试，不能用来给普通外部朋友测试。按向导使用适当的分发签名，核对后上传。[Apple：分发选项](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases?changes=_7)

上传后回到 App Store Connect 的 TestFlight 页，等待 Apple 处理。出现 Processing 时尚不能认定可安装；处理失败需按提示修复后使用新构建号重新上传。[Apple：上传构建](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)

如出现加密使用问题，按 App 的实际实现回答。不要未经核查就为了通过上传，把使用加密一律填为“不使用”。本项目的 HTTPS 和系统加密涉及什么申报材料，应按 Apple 的问答确认。[Apple：加密使用说明](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)

### 5.4 可选：用命令行生成归档

优先按上面的 Xcode 界面操作。以下是供开发者使用的模板，**本文没有执行这些发布命令**。先替换付费 Team ID、已注册 Bundle ID 和未使用的构建号：

```sh
cd /Users/llyy/Desktop/EssayPilot
npm run ios:generate
mkdir -p artifacts/distribution

xcodebuild archive \
  -project ios/EssayPilot.xcodeproj \
  -scheme EssayPilot \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath artifacts/distribution/WriteRight.xcarchive \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=YOUR_PAID_TEAM_ID \
  PRODUCT_BUNDLE_IDENTIFIER=YOUR_REGISTERED_BUNDLE_ID \
  CURRENT_PROJECT_VERSION=2
```

命令行覆盖签名参数可以避免直接改动目前用于本机开发的 Team 配置。若归档路径已存在，换一个新路径保留旧归档，不要未经检查直接删掉。

对成品进行本项目的公开云配置检查：

```sh
node scripts/check-ios-cloud.mjs \
  artifacts/distribution/WriteRight.xcarchive/Products/Applications/EssayPilot.app

plutil -extract MinimumOSVersion raw \
  artifacts/distribution/WriteRight.xcarchive/Products/Applications/EssayPilot.app/Info.plist
```

第二条用于核对最低系统，当前期望为 `17.0`。随后在 Xcode Organizer 检查并上传；完成归档不会自动生成邀请链接。

---

## 6. 开发者操作：外部测试审核与邀请

### 6.1 建立测试组并提交构建

1. 在 App Store Connect 打开该 App → TestFlight。
2. 按当前 Apple 流程先创建一个内部测试组；这不要求把朋友加入内部团队。
3. 在 External Testing（外部测试）新建组，例如“朋友体验”。
4. 向该组添加可用于外部测试的构建。
5. 填写 Beta App Description、反馈邮箱、What to Test 和测试审核所需资料。
6. 按页面提交 TestFlight 测试审核，等待状态允许外部测试。

第一份外部测试构建需要经过 Apple 的测试审核；后续构建也可能需要审查，不能保证当晚或固定几分钟内通过。确认构建已经获准给外部测试者使用，再通知她安装。[Apple：邀请外部测试者](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)

### 6.2 本项目特别要处理：审核人员如何登录

WriteRight 目前使用**邮箱动态验证码**。审核人员若不能取得验证码，就不能正常检查账号、云端批改和报告。

提交前准备能够实际工作的审核访问方案，并在 Review Notes 中写清步骤。Apple 要求账号功能提供有效访问资料，涉及验证码时也要提前说明相应信息；仅写“联系我拿验证码”不能视为已经解决审核访问。[Apple：准备完整审核资料](https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review)

对本项目而言：

- 可考虑另行实现受控的专用审核登录或完整演示流程，但它**目前不应被写成已实现**。
- 仅在 Supabase 创建一个有密码的用户，而 App 没有密码登录入口，并不能让审核人员登录。
- 如果说明允许使用审核方可收信的邮箱，需先确认实际可用，并接受审核方可能进一步要求可持续访问的演示账号；不能保证该办法一定获准。
- 不把全局固定验证码、关闭鉴权或共享真实用户账号作为解决方法。
- 不提供个人邮箱密码、SMTP 授权码、模型 key 或管理员 key。测试样例用合成作文，不使用朋友的私人作文充当审核材料。

这项是发布准备工作；**本地安装和云端批改已经跑通，不等于当前审核资料已经齐备。**

### 6.3 邀请这位朋友

优先使用邮件定向邀请：在外部测试组添加她希望接收邀请的邮箱，并通知测试。也可使用该组的公开邀请链接；链接可被转发，若只测试少数朋友，注意人数和设备/系统筛选条件，不要把她的 iOS 18.7.7 意外排除。[Apple：外部测试组与邀请](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/)

不要把 `https://testflight.apple.com/join/示例代码` 当真实链接。**只有 App Store Connect 实际生成且对应可测试构建的链接才可发送。**

---

## 7. 给朋友看的安装步骤

这一节可以单独转发。前提是开发者已经完成第 3～6 节，并发来了真实有效的邀请。

1. 在 iPhone 打开 App Store，搜索 **TestFlight**，确认是 Apple 发布的 App 并安装。也可直接打开 [TestFlight 中国区 App Store 页面](https://apps.apple.com/cn/app/testflight/id899247664)，其他地区以自己的 App Store 页面为准。
2. 使用自己的 Apple 账户；**不需要登录开发者的账户**。
3. 在这台 iPhone 上打开 WriteRight 邀请邮件或开发者发来的邀请链接。
4. 如微信内打开不顺畅，选择在 Safari 打开，然后按页面进入 TestFlight。
5. 点击接受测试，再点击安装 WriteRight。若邮件给出兑换步骤，按邮件和 TestFlight 页面操作。
6. 安装完成后，打开 WriteRight。
7. 到“我的”→ 邮箱登录，用**自己的邮箱**收取验证码并登录。
8. 点击“我的”顶部昵称旁的铅笔，可设置自己的昵称。

通过 TestFlight 正常安装不需要开启 Developer Mode，不需要连接开发者的 Mac，也不用安装企业证书或提供设备 UDID。[Apple：Developer Mode 不影响 TestFlight 安装](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device?language=objc)

TestFlight 的邀请/兑换过程与 WriteRight 的邮箱验证码登录是两套流程。**App 内的六位邮箱验证码不是 TestFlight 邀请码。**

---

## 8. 安装后做一次小验收

先使用一篇无隐私的测试作文，确认安装和在线能力都可用：

- [ ] 首页正常显示今天、考试日期和倒计时，横向没有溢出。
- [ ] 顶部「看看日落，歇一会儿」能切换夜景并关灯，可重新点灯或返回白天。
- [ ] 昵称可以保存，返回“我的”后仍显示。
- [ ] 练习 → 照片批改，能从系统相册选图；如试拍照，按需允许相机权限。
- [ ] 题目/图表和作文分别上传，页序正确，能移除或调整页面。
- [ ] 提交前能看到图片处理告知；开始后看到实际进度，退出等待页可回看任务。
- [ ] 有完整题图时报告可以显示估分；没有题图时只给能确认的语言反馈，不编造总分。
- [ ] 修改稿有中文对照、红色重点及说明，收藏后显示“已收藏”。
- [ ] 完全退出 App 再打开，确认账号、已保存记录和报告的实际恢复表现。
- [ ] 测试 Wi-Fi 和手机网络；断网时提示合理，联网后能继续。

记录她的手机型号、iOS 18.7.7、WriteRight 版本/构建号，以及问题出现在哪一步。不要把整篇私人作文、验证码或邮箱截图发到公开群。

这张清单是**待她实际执行的验收**，不是本文已完成的测试结果。

## 9. 后续更新、有效期和数据

- 开发者上传新构建后，在同一个外部测试组添加并开放；她在 TestFlight 点击更新，或启用 TestFlight 自动更新。
- 每个测试构建最多可用 90 天，到期后不能继续按原包长期使用。开发者应在到期前提供新构建；长期正式使用需规划适合的发布方式。[Apple：构建状态与到期](https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-build-statuses/)
- 正常更新优先直接覆盖安装，**不要为了更新先卸载 App**。卸载可能丢失本机草稿与陪伴小猫的成长；重要练习先同步或导出。
- 昵称随 WriteRight 账号保存；登录后陪伴小猫的名字与成长随账号云同步，两台设备各自的成长会合并（需安装 2026-11-01 第二轮之后的版本）；游客只留本机。旧版首页便笺不再显示在首页，可在「记录」收进记录后随账号同步。
- 更换 Bundle ID 会成为另一套安装，不能假定原 App 的本地数据、Keychain 登录态会迁移。
- 云端项目暂停、邮件或模型服务不可用，会影响登录/批改；重新安装通常解决不了这些后端问题。

## 10. 常见问题

| 现象 | 优先检查 |
| --- | --- |
| TestFlight 只有“兑换”，没有 WriteRight | 是否已经打开实际邀请并接受；只装 TestFlight 不会自动加入任何 App |
| “此 Beta 版已满”或邀请无效 | 开发者检查测试组、邀请状态、公开链接人数/筛选条件、构建是否可测试 |
| 提示系统不兼容 | 检查这次上传成品的最低系统，以及测试组的系统筛选；不能只看源码中的旧值 |
| 找不到外部测试可用构建 | 检查是否误传 Internal Only、构建仍在处理、审核未完成或有待补资料 |
| App 提示未受信任开发者 | 核实安装方式；正规 TestFlight 流程不应要求去信任某个陌生企业开发者 |
| App 提示登录服务未配置 | 检查 Release 包内公开云配置是否实际存在，不要发送另一份未配置的 Debug 包 |
| 收不到邮箱验证码 | 检查地址、垃圾邮件、等待页面冷却；开发者检查 SMTP 投递与认证错误，不反复高频重发 |
| 能打开首页，不能评分 | 分开检查登录、网络、云函数、模型额度与 Worker；首页可打开不等于后端可用 |
| 测试构建过期 | 在 TestFlight 更新到仍有效的新构建；开发者需要先上传并开放 |
| 新版本没有昵称或双语稿 | 确认 TestFlight 中的版本/构建号；旧报告不会自动生成新译文或重新评分 |

---

## 11. 备选：Ad Hoc 异地安装

适合你已经有付费开发者会员，希望对少量指定设备分发，并愿意维护设备注册和安装工具。

开发者步骤：

1. 通过对方可用的可信工具取得那台 iPhone 的 UDID。它不是序列号、IMEI 或手机号。
2. 在付费 Team 的设备列表注册该 UDID。
3. 为同一 App ID 创建/更新包含该设备的 Ad Hoc 描述文件，选择对应分发证书。
4. 用 Ad Hoc 方式重新导出签名正确的 `.ipa`。
5. 让她使用适当的安装方式，例如在自己能使用的 Mac 上通过 Apple Configurator 安装；若使用专门分发服务，按该服务的注册与安装流程配置。
6. 如系统要求 Developer Mode，按 Apple 对开发安装的说明由她本人处理。

注册设备后创建匹配描述文件，是 Ad Hoc 分发的关键；不是把现有 Personal Team 包改名后发送。[Apple：Ad Hoc 描述文件](https://developer.apple.com/help/account/provisioning-profiles/create-an-ad-hoc-provisioning-profile/)

付费会员按产品类别每会员年最多注册 100 台设备，停用设备不会立即恢复本年度名额。需要管理描述文件、证书有效期及重新签名，不是永久安装。[Apple：设备注册限制](https://developer.apple.com/help/account/devices/devices-overview/)

**异地不代表不能 Ad Hoc，但仅把 IPA 发到聊天窗口不等于已有可用安装通道。** 如果她只有 iPhone、不方便获取 UDID或使用安装工具，优先回到 TestFlight。

Enterprise 分发面向组织内部用户，不是给外部朋友安装的通用捷径。[Apple：分发方式](https://help.apple.com/xcode/mac/current/en.lproj/dev31de635e5.html)

## 12. 如果目前不打算购买开发者会员

**可以选择 iLoader 侧载，不要求开发者或朋友购买会员。** 开发者提供真机Release IPA，朋友在自己的Windows/Mac/Linux电脑上使用iLoader、自己的Apple账户和连接的iPhone签名安装。iLoader官方支持导入IPA；Windows按官方要求先装iTunes。[iLoader官网](https://iloader.app/)、[官方仓库](https://github.com/nab138/iloader)

具体下载、安装、信任开发者、Developer Mode、续签和排错步骤，见[WriteRight iLoader侧载安装说明](WriteRight_iLoader侧载安装说明.md)。这是在朋友账户下开发签名的测试安装，不是免签、永久安装或Apple批准的公开商店分发。

主要限制：免费开发描述文件签发后7天到期，通常每台设备最多3个开发签名App。到期需要重新签名安装；如果同时使用SideStore，它也会占用一个名额。iLoader直接安装不等于已经配置自动续签。[Apple：免费账户限制](https://developer.apple.com/help/account/basics/about-your-developer-account/)

WriteRight当前使用Supabase邮箱登录、HTTPS云函数、私有图片存储和服务端模型批改，不依赖付费Apple能力。**从当前代码和配置判断，签名有效且服务正常时，侧载不会主动减少已实现功能**；朋友使用自己的WriteRight邮箱账号。云端仍需可用额度/配额与正常发信；陪伴小猫的成长登录后随账号同步。朋友的18.7.7设备尚未实际验收，不能写成已完整通过。

另一个免费选项是她在兼容Mac的Xcode中编译本项目并自行签名，步骤更多。两种免费方式都不要交付开发者的签名私钥、服务端密钥或邮箱授权码。她只有iPhone、没有可用电脑时，不能把直接转发IPA当作已具备安装条件。

## 13. 可以直接发给她的消息

把下文中的方括号替换成真实内容后再发送；文档本身没有替你发消息。

> WriteRight 的测试版已经准备好了。你的 iOS 18.7.7 满足当前最低版本要求。  
> 请先在 App Store 安装 Apple 的 TestFlight，再用这台手机打开邀请：[真实邀请链接，或查看邀请邮件]。  
> 接受测试后安装 WriteRight，用你自己的邮箱收验证码登录，不需要我的 Apple 账户，也不用连接我的电脑。  
> 到“我的”顶部点铅笔可以修改昵称。先用一篇不含隐私的作文试一次上传和批改。遇到问题请告诉我手机型号、App 构建号和具体步骤。测试版有有效期，收到更新请在 TestFlight 更新；先不要卸载旧版。

## 14. 当前最短执行清单

**无会员、用iLoader：**开发者提供Release IPA和[侧载说明](WriteRight_iLoader侧载安装说明.md) → 她在电脑安装官方iLoader → 连接手机并用自己的Apple账户签名安装 → 设置信任/Developer Mode → 自己的邮箱登录WriteRight → 每7天周期续签并完成第8节验收。

**有会员、用TestFlight：**

**你这边：**确认付费会员 → 准备可审核登录方案 → 确定 App ID/Release 云配置 → 归档上传 → 建立外部测试组并完成测试审核 → 发送真实邀请。

**她那边：**安装 TestFlight → 接受邀请 → 安装 WriteRight → 用自己的邮箱登录 → 在 iOS 18.7.7 上完成第 8 节验收。

已另外生成供接收方重新签名的真机Release IPA；这不代表已在她的手机安装。未执行会员购买、协议接受、分发签名变更、TestFlight 上传、审核提交或邀请发送。
