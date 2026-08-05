# 幻兽帕鲁服务器崩溃日志分析报告

**分析时间**: 2026-08-05
**崩溃日志目录**: Crashes/
**崩溃报告数量**: 9 份

---

## 一、环境信息(所有崩溃一致)

| 项目 | 值 |
|------|-----|
| 游戏版本 | Pal 1.0.2.101103 |
| 引擎版本 | UE 5.1.1 |
| 可执行文件 | PalServer-Win64-Shipping |
| 构建配置 | Shipping |
| 服务器类型 | Community(社区服务器) |
| 运行环境 | **Docker 容器**(路径 Z:/home/container/) |
| CPU | i9-13900K(8 核 16 线程) |
| 内存 | 126 GB |
| GPU | llvmpipe(LLVM 15.0.6,软件渲染,即 Linux 容器内通过 Wine 运行 Windows 服务器) |
| 操作系统 | Windows 10 19045(容器内) |

---

## 二、崩溃清单

| # | CrashGUID 前缀 | 崩溃类型 | 错误信息 | 运行时长 | 客户端数 | 使用 MOD | 崩溃线程 |
|---|----------------|---------|---------|---------|---------|---------|---------|
| 1 | 4AA0D5DF | Crash | EXCEPTION_ACCESS_VIOLATION reading 0x0000020000000003 | 6.4 小时 | 12 | 否 | Foreground Worker #0 |
| 2 | 0C4A3B11 | Crash | EXCEPTION_ACCESS_VIOLATION writing 0x0000000143270513 | 15.8 小时 | 11 | 否 | Foreground Worker #0 |
| 3 | 43C8EDF0 | Crash | EXCEPTION_ACCESS_VIOLATION writing 0x00000001467fc554 | 80 分钟 | 17 | 否 | GameThread |
| 4 | 19E2FE0E | Crash | 0xc0000008(STATUS_INVALID_HANDLE) | 45 分钟 | 11 | 否 | GameThread |
| 5 | 3F4D4887 | Crash | EXCEPTION_ACCESS_VIOLATION reading 0x000072e9fda92000 | **10 秒** | — | **是** | GameThread |
| 6 | 6892F9FE | Assert | Foliage 序列化大小不匹配(Got 244711, Expected 11522180) | 15 分钟 | **32** | **是** | GameThread |
| 7 | 93168A49 | Assert | PakFile Retry was NOT successful | 3.2 小时 | 14 | 否 | Background Worker #5 |
| 8 | 9F34DBA9 | Assert | TArray resize to invalid size 2733883615 | **39 秒** | 11 | 否 | GameThread |
| 9 | C0251540 | Assert | TArray resize to invalid size 2801804177 | 4.2 小时 | 23 | **是** | GameThread |

---

## 三、崩溃分类统计

| 崩溃类别 | 次数 | 占比 | 严重程度 |
|---------|------|------|---------|
| EXCEPTION_ACCESS_VIOLATION(内存访问违规) | 4 | 44% | 高 |
| Assert - TArray 无效大小 | 2 | 22% | 高 |
| Assert - 植被序列化不匹配 | 1 | 11% | 中 |
| Assert - PakFile 读取失败 | 1 | 11% | 中 |
| STATUS_INVALID_HANDLE(无效句柄) | 1 | 11% | 中 |

---

## 四、根本原因分析

### 原因 1:MOD 兼容性问题(3 次,占 33%)

涉及崩溃:#3F4D4887、#6892F9FE、#C0251540

- **#3F4D4887**:使用 MOD,启动仅 **10 秒** 即崩溃(访问违规),典型的 MOD 加载冲突。
- **#6892F9FE**:使用 MOD,32 客户端满载时,植被组件(`PalFoliageISMComponent`)序列化大小不匹配(期望 11 MB,实际 244 KB),MOD 可能修改了地图植被数据。
- **#C0251540**:使用 MOD,运行 4.2 小时后 TArray 尝试调整为 2.8 GB 的无效大小。

**结论**:MOD 与服务器版本(1.0.2.101103)不完全兼容,导致数据结构不一致。

### 原因 2:存档/数据损坏(2 次,占 22%)

涉及崩溃:#9F34DBA9、#C0251540

- 两次崩溃都是 `TArray resize to invalid size`,大小分别为 **2,733,883,615** 和 **2,801,804,177**(约 2.7~2.8 GB)。
- 两个数值非常接近,疑为相同类型的损坏数据被反序列化时读入了垃圾值。
- **#9F34DBA9** 在启动 **39 秒** 即崩溃,符合加载存档时触发损坏数据的现象。

**结论**:存档文件可能已损坏,反序列化时读取到非法数据。

### 原因 3:高玩家负载(3 次,占 33%)

涉及崩溃:#6892F9FE(32)、#C0251540(23)、#43C8EDF0(17)

- 32 客户端(服务器满载)时触发植被序列化崩溃。
- 23 客户端时触发 TArray 损坏。
- 17 客户端时触发访问违规。
- 玩家数越高,崩溃概率越大,且崩溃类型越严重。

**结论**:服务器在高负载下存在并发问题或资源竞争。

### 原因 4:容器磁盘 I/O 问题(1 次,占 11%)

涉及崩溃:#93168A49

- `PakFile Retry was NOT successful` 表明 `.pak` 文件读取重试失败。
- 服务器运行在 Docker 容器中,容器存储层可能存在 I/O 性能问题或文件锁定。

**结论**:容器环境的磁盘 I/O 不稳定。

### 原因 5:启动期崩溃(2 次,占 22%)

- #3F4D4887(10 秒)+ #9F34DBA9(39 秒)均在启动阶段崩溃。
- 通过 TimeOfCrash 时间戳分析,这两个崩溃分别与其他运行较久的崩溃时间接近,说明服务器崩溃后重启时再次失败。

---

## 五、关键发现

### 5.1 服务器多次重启

通过 TimeOfCrash 时间戳对比:
- **#3F4D4887**(运行 10 秒)与 **#C0251540**(运行 4.2 小时)的崩溃时间仅相差 19 秒 → 服务器崩溃后立即重启,又因 MOD 问题启动失败。
- **#9F34DBA9**(运行 39 秒)与 **#93168A49**(运行 3.2 小时)的崩溃时间相差约 8 分钟 → 同样是崩溃后重启失败。

**结论**:服务器存在"崩溃-重启-再崩溃"的循环。

### 5.2 MOD 使用情况不稳定

- 9 次崩溃中,3 次标记 `is_use_mods=true`,6 次为 `false`。
- MOD 状态在不同崩溃间变化,说明运维人员曾尝试启用/禁用 MOD 排查问题,但问题未解决。

### 5.3 内存使用情况

- 崩溃时内存使用范围:3.8 GB ~ 10.7 GB(服务器总内存 126 GB)。
- `bIsOOM=0`,所有崩溃**均非内存不足导致**。
- 但部分崩溃的 `AvailablePhysical=0`,疑为容器内存限制(cgroup)导致统计异常。

### 5.4 PCallStack 模式

- #3F4D4887 与 #C0251540 的调用栈高度相似(都包含 `+3bed539`、`+3aecb2c`、`+3ac6f21`、`+5068d55`、`+508765a`),是同一代码路径的崩溃。
- #9F34DBA9 与 #6892F9FE 的调用栈也相似(都包含 `+33f7109`、`+33e52cd`、`+33f64c7`、`+33fd2a7`、`+33fc595`)。

---

## 六、处理建议

### 🔴 立即处理

1. **禁用所有 MOD 并清理 MOD 残留**
   - 3 次崩溃与 MOD 直接相关,包括启动失败和数据损坏。
   - 建议逐个排查 MOD,找出引发问题的具体 MOD。

2. **验证并修复存档**
   - 2 次启动崩溃疑似存档损坏。
   - 建议从最近的正常备份恢复存档,或使用官方存档修复工具。

3. **限制最大玩家数**
   - 32 客户端满载时必崩溃。
   - 建议暂时将 `ServerMaxPlayers` 限制为 16~20,观察稳定性。

### 🟡 中期改进

4. **检查容器磁盘 I/O**
   - PakFile 读取失败可能与容器存储层有关。
   - 建议将存档目录挂载到宿主机本地磁盘(非 overlay 存储层)。

5. **升级服务器版本**
   - 当前版本 1.0.2.101103,UE 5.1.1。
   - 检查 Palworld 官方是否有更新版本修复了这些已知崩溃。

6. **配置自动重启与存档备份**
   - 部分崩溃无法避免(引擎 Bug),配置崩溃自动重启 + 定时备份可降低影响。

### 🟢 长期优化

7. **监控服务器资源**
   - 部署内存/CPU/磁盘 I/O 监控,在崩溃前预警。

8. **考虑迁移到原生 Windows 服务器**
   - 当前为 Linux 容器 + Wine 运行 Windows 服务器,可能存在兼容性问题。
   - 若条件允许,迁移到原生 Windows 服务器可消除容器相关崩溃。

---

## 七、附录:原始崩溃证据

### 最严重的崩溃(32 客户端)
```
#6892F9FE
LowLevelFatalError [File:C:\works\Pal-UE-EngineSource\Engine\Source\Runtime\CoreUObject\Private\Serialization\AsyncLoading.cpp] [Line: 3558]
PalFoliageISMComponent /Game/Pal/Maps/MainWorld_5/PL_MainWorld5/_Generated_/Foliage_L0_X-8_Y15_DL0.PL_MainWorld5:PersistentLevel.InstancedFoliageActor_25600_-8_15_0.PalFoliageISMComponent_7:
Serial size mismatch: Got 244711, Expected 11522180
```

### 启动崩溃(MOD 相关)
```
#3F4D4887 (运行 10 秒, is_use_mods=true)
Unhandled Exception: EXCEPTION_ACCESS_VIOLATION reading address 0x000072e9fda92000
```

### 存档损坏崩溃
```
#9F34DBA9 (运行 39 秒)
LowLevelFatalError [File:C:\works\Pal-UE-EngineSource\Engine\Source\Runtime\Core\Private\Containers\Array.cpp] [Line: 8]
Trying to resize TArray to an invalid size of 2733883615

#C0251540 (运行 4.2 小时, is_use_mods=true)
LowLevelFatalError [File:C:\works\Pal-UE-EngineSource\Engine\Source\Runtime\Core\Private\Containers\Array.cpp] [Line: 8]
Trying to resize TArray to an invalid size of 2801804177
```

### PakFile 读取失败
```
#93168A49
LowLevelFatalError [File:C:\works\Pal-UE-EngineSource\Engine\Source\Runtime\PakFile\Private\IPlatformFilePak.cpp] [Line: 4210]
Retry was NOT sucessful.
```
