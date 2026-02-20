# Agent Teams 最小可复现验证用例

**日期:** 2026-02-20
**状态:** 已完成测试
**目的:** 验证 Agent Teams 模式集成的完备性（设计文档 + 运行时行为）

---

## 测试目标

验证 Agent Teams 集成的以下关键点：

1. **能力门控** - Team Mode 只在相关工具可用时才出现
2. **并行执行** - 独立任务能并行分配给不同 teammates
3. **评审门控** - spec review 必须先于 code quality review
4. **回退机制** - Team 不可用时自动回退到标准 Task 模式
5. **生命周期** - Team 正确创建、复用、删除

---

## 测试场景：微型计算器模块

### 项目结构

```
calculator-test/
├── docs/
│   └── plans/
│       └── calculator-implementation.md  # 实现计划（3个任务）
├── src/          # 待实现：add.js, multiply.js, index.js
├── test/         # 待实现：add.test.js, multiply.test.js
└── package.json
```

### 任务定义

| 任务 | 描述 | 依赖 | 独立性 |
|------|------|------|--------|
| Task 1 | 实现 `add(a, b)` 函数及测试 | 无 | 完全独立 |
| Task 2 | 实现 `multiply(a, b)` 函数及测试 | 无 | 完全独立 |
| Task 3 | 创建统一导出文件 `index.js` | Task 1, 2 | 依赖前两者 |

### 预期并行模式

```
[开始]
   │
   ├─► TeamCreate
   │
   ├─► [并行阶段] ──► Teammate A: Task 1 (add.js)
   │               └─► Teammate B: Task 2 (multiply.js)
   │
   ├─► [评审门控 1] ──► Spec Reviewer (验证符合要求)
   │
   ├─► [评审门控 2] ──► Code Quality Reviewer (代码质量)
   │
   ├─► [串行阶段] ──► Teammate C: Task 3 (index.js)
   │
   └─► TeamDelete
```

---

## 验证清单

### 阶段 1：静态文档验证

| 检查项 | 文件 | 预期内容 |
|--------|------|----------|
| Team Mode 选项 | `skills/writing-plans/SKILL.md` | "If available, offer Team-Based mode as Option 3" |
| 能力门控 | `skills/writing-plans/SKILL.md` | "Capability gate before offering options" |
| Team Mode 分支 | `skills/subagent-driven-development/SKILL.md` | "Team Mode" 章节存在 |
| 评审顺序 | `skills/subagent-driven-development/SKILL.md` | "Only after spec pass, dispatch code quality reviewer" |
| 回退规则 | `skills/subagent-driven-development/SKILL.md` | "Fallback rule" 存在 |
| TaskList 源 | `skills/executing-plans/SKILL.md` | "Team mode: TaskList is the source of truth" |

### 阶段 2：运行时行为验证

| 检查项 | 验证方法 | 预期结果 |
|--------|----------|----------|
| 能力检测 | 观察 `subagent-driven-development` 执行 | 先检查 TeamCreate 工具可用性 |
| Team 创建 | 检查工具调用 | `TeamCreate` 被调用 |
| 并行分配 | 检查任务分配日志 | Task 1 和 Task 2 分配给不同 teammates |
| Spec 先行 | 检查评审顺序 | Spec review 在 code quality review 之前 |
| 回退路径 | （可选）模拟 Team 不可用 | 回退到标准 Task 模式 |
| Team 清理 | 检查工具调用 | `TeamDelete` 被调用 |

---

## 执行步骤

### 准备阶段

```bash
# 1. 创建测试项目
cd /tmp
mkdir calculator-test && cd calculator-test

# 2. 创建项目结构
mkdir -p docs/plans src test

# 3. 创建 package.json
cat > package.json << 'EOF'
{
  "name": "calculator-test",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "node --test"
  }
}
EOF

# 4. 创建实现计划（见下方完整内容）
# 5. 初始化 git
git init && git add . && git commit -m "Initial commit"
```

### 实现计划内容（calculator-implementation.md）

```markdown
# Calculator Module Implementation Plan

## Task 1: Add Function

Create `src/add.js` exporting a function `add(a, b)` that returns the sum of `a` and `b`.

Requirements:
- Must validate both inputs are numbers
- Must throw TypeError if validation fails
- Must return the numeric sum

Create `test/add.test.js` with tests for:
- add(2, 3) returns 5
- add(-1, 1) returns 0
- add(0, 0) returns 0
- add("2", 3) throws TypeError
- add(2, "3") throws TypeError

Verification: `npm test`

## Task 2: Multiply Function

Create `src/multiply.js` exporting a function `multiply(a, b)` that returns the product of `a` and `b`.

Requirements:
- Must validate both inputs are numbers
- Must throw TypeError if validation fails
- Must return the numeric product

Create `test/multiply.test.js` with tests for:
- multiply(2, 3) returns 6
- multiply(-2, 3) returns -6
- multiply(0, 5) returns 0
- multiply("2", 3) throws TypeError
- multiply(2, "3") throws TypeError

Verification: `npm test`

## Task 3: Index Export

Create `src/index.js` that re-exports `add` and `multiply` from their respective modules.

Requirements:
- Named export `add` from `./add.js`
- Named export `multiply` from `./multiply.js`
- No additional logic or validation

Verification: Import from `src/index.js` and verify both functions are available.
```

### 测试执行提示

```
请使用 subagent-driven-development skill 执行 docs/plans/calculator-implementation.md。

如果 Team Mode 可用，请使用 Team Mode。
验证：
1. Team 正确创建
2. 独立任务 (Task 1, 2) 并行执行
3. 评审门控按顺序执行（spec → quality）
4. Team 正确清理
```

---

## 预期输出示例

### 成功的 Team Mode 执行

```
[assistant] Creating team for calculator implementation...
[tool] TeamCreate: "calculator-team" created
[assistant] Assigning Task 1 to teammate-1...
[tool] SendMessage: recipient="teammate-1", content="Implement add function"
[assistant] Assigning Task 2 to teammate-2...
[tool] SendMessage: recipient="teammate-2", content="Implement multiply function"
[teammate-1] add.js implemented, tests written
[teammate-2] multiply.js implemented, tests written
[assistant] Dispatching spec compliance reviewer...
[tool] SendMessage: recipient="reviewer", content="Review spec compliance"
[reviewer] Both tasks pass spec review
[assistant] Dispatching code quality reviewer...
[tool] SendMessage: recipient="reviewer", content="Review code quality"
[reviewer] Code quality review passed
[assistant] Assigning Task 3...
[tool] SendMessage: recipient="teammate-3", content="Create index.js"
[teammate-3] index.js created
[assistant] All tests passing: npm test ✓
[tool] TeamDelete
```

### 回退到标准模式（当 Team 不可用时）

```
[assistant] Checking Team Mode capabilities...
[assistant] TeamCreate tool not available, falling back to standard Task mode
[tool] Task: subagent_type="general-purpose", prompt="Implement Task 1: Add Function"
[subagent] Task 1 complete
[tool] Task: subagent_type="general-purpose", prompt="Implement Task 2: Multiply Function"
[subagent] Task 2 complete
[tool] Task: subagent_type="general-purpose", prompt="Implement Task 3: Index Export"
[subagent] Task 3 complete
[assistant] All tests passing: npm test ✓
```

---

## 测试执行记录（2026-02-20）

### 测试环境

| 项目 | 值 |
|------|-----|
| 平台 | Windows (MSYS_NT-10.0-22631) |
| Agent Teams | 已启用 (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) |
| 显示模式 | in-process（默认） |

### 静态文档验证结果

| 测试 | 结果 |
|------|------|
| Capability gates are documented | ✅ PASS (3/3) |
| Team Mode is conditional | ✅ PASS (2/2) |
| Review gate ordering is explicit | ✅ PASS (2/2) |
| Fallback rules are present | ✅ PASS (4/4) |
| TaskList source of truth | ✅ PASS (3/3) |
| **总计** | **✅ 14/14 通过** |

### 运行时行为验证结果

| 验证项 | 结果 | 说明 |
|--------|------|------|
| 环境配置 | ✅ 通过 | `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` 已设置 |
| TeamCreate 工具可用 | ✅ 通过 | 成功创建 `calculator-team` |
| 团队配置文件生成 | ✅ 通过 | `~/.claude/teams/calculator-team/config.json` 正确创建 |
| 多成员加入 | ✅ 通过 | team-lead + add-implementer + multiply-implementer (3 成员) |
| TaskList 生成 | ✅ 通过 | `~/.claude/tasks/calculator-team/` 包含任务文件 |
| 任务状态跟踪 | ✅ 通过 | 任务状态正确记录为 `in_progress` |
| SendMessage 工具可用 | ✅ 通过 | 成功发送 shutdown 请求 |
| TeamDelete 工具可用 | ✅ 通过 | 工具响应正确（提示需先关闭 teammates） |
| **Teammates 并行执行** | ⚠️ 部分 | teammates 创建成功但 in-process 模式下未产生输出 |

### 发现的问题

#### 1. in-process 模式限制

在 **in-process 模式**下（VS Code 扩展环境的默认模式）：
- Teammates 可以成功创建和加入团队
- 任务文件正确生成 (`~/.claude/tasks/calculator-team/1.json`, `2.json`)
- Teammates 没有产生预期的文件输出（代码未实现）
- Shutdown 请求发送成功但 teammates 未响应关闭

**可能原因：**
- in-process 模式下所有 teammates 在同一终端交织运行，输出可能被覆盖
- 工作目录配置可能不正确
- VS Code 集成终端可能对 teammates 的文件操作有限制

#### 2. 推荐解决方案

使用 **tmux 分屏模式**可以解决以上问题：
- 每个 teammate 有独立的终端面板
- 输出清晰分离，便于监控
- 文件操作不受限制

### 显示模式对比

| 特性 | In-process 模式 | tmux 分屏模式 |
|------|-----------------|---------------|
| 显示方式 | 所有 teammates 在同一终端交织输出 | 每个 teammate 有独立窗口面板 |
| 查看方式 | `Shift+Up/Down` 切换查看 | 同时看到所有队友工作 |
| 适用场景 | 简单任务、快速原型 | 复杂任务、需要监控多并行工作 |
| 配置要求 | 无额外要求 | 需安装 tmux 并配置 |
| 终端要求 | 任何终端 | 原生终端（不支持 VS Code 集成终端） |

### 结论

**Agent Teams 模式集成已基本完成：**

1. ✅ **设计文档完备** - 所有 skill 文件包含 Team Mode 指令
2. ✅ **工具集成正确** - TeamCreate、SendMessage、TeamDelete 均可调用
3. ✅ **团队生命周期** - 创建、配置、任务分配流程正常
4. ⚠️ **in-process 模式限制** - 存在一些限制，推荐使用 tmux 模式完整测试

**下一步：** 配置 tmux 模式进行完整的并行执行测试。

---

## tmux 模式配置指南

### 1. 安装 tmux

```bash
# macOS
brew install tmux

# Ubuntu/Debian
sudo apt install tmux

# Windows (Git Bash / MSYS2)
# tmux 通常不可用，建议使用 WSL 或原生 Linux/macOS 环境
```

### 2. 验证安装

```bash
tmux -V
# 预期输出: tmux x.x (例如 tmux 3.3)
```

### 3. 配置 Claude Code

编辑 `~/.claude/settings.json`：

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "teammateMode": "tmux"
}
```

或者在启动时指定：
```bash
claude --teammate-mode tmux
```

### 4. 使用 tmux 模式测试

```bash
# 启动 tmux 会话
tmux new -s claude-test

# 在 tmux 会话内启动 Claude Code
cd /path/to/project
claude

# Claude Code 会自动使用 tmux 分屏模式
# 创建团队后会自动分割窗口
```

### 5. tmux 基本操作

| 操作 | 快捷键 |
|------|--------|
| 切换面板 | `Ctrl+B` 然后 `方向键` |
| 滚动查看历史 | `Ctrl+B` 然后 `[`，用 `q` 退出 |
| 放大/缩小面板 | `Ctrl+B` 然后 `z` |
| 分离会话 | `Ctrl+B` 然后 `d` |
| 重新连接 | `tmux attach -t claude-test` |

---

## 成功标准（更新）

- [x] 所有静态文档检查通过
- [x] Team Mode 能正确检测和初始化
- [x] 独立任务能够创建和分配
- [ ] 独立任务能够并行执行完成（需 tmux 模式）
- [ ] 评审门控顺序正确（spec → quality）（需 tmux 模式）
- [ ] 最终项目能通过 `npm test`（需 tmux 模式）
- [x] Team 工具响应正确

---

## 附录：手动验证命令

```bash
# 验证项目结构
ls -la /tmp/calculator-test/

# 验证团队配置
cat ~/.claude/teams/calculator-team/config.json

# 验证任务状态
cat ~/.claude/tasks/calculator-team/*.json

# 验证测试通过（实现完成后）
cd /tmp/calculator-test && npm test

# 验证模块导出
node -e "import('./src/index.js').then(m => console.log(Object.keys(m)))"
# 预期输出: [ 'add', 'multiply' ]
```
