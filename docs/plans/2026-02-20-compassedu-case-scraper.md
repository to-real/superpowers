# 留学案例库抓取工具 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建一个 Python 工具，从指南者留学案例库 (m.compassedu.hk/offer/) 抓取留学录取案例数据，支持增量更新和数据导出。

**Architecture:** 使用 Playwright 抓取动态渲染的页面内容，解析案例卡片数据，存储为 JSON/CSV 格式，支持增量抓取（跳过已抓取的案例）。

**Tech Stack:** Python 3.10+, Playwright (浏览器自动化), pandas (数据处理), pytest (测试)

---

## Task 1: 创建项目结构和依赖配置

**Files:**
- Create: `compassedu-scraper/README.md`
- Create: `compassedu-scraper/requirements.txt`
- Create: `compassedu-scraper/.gitignore`
- Create: `compassedu-scraper/src/__init__.py`
- Create: `compassedu-scraper/data/.gitkeep`
- Create: `compassedu-scraper/tests/__init__.py`

**Step 1: 创建项目 README**

```markdown
# 指南者留学案例库抓取工具

从 m.compassedu.hk/offer/ 抓取留学录取案例数据。

## 功能
- 抓取案例列表（学生背景、录取学校/专业、GPA、语言成绩等）
- 增量更新（跳过已抓取的案例）
- 导出为 JSON/CSV 格式

## 安装
```bash
pip install -r requirements.txt
playwright install chromium
```

## 使用
```bash
python -m src.scraper
```
```

**Step 2: 创建 requirements.txt**

```txt
playwright==1.48.0
pandas==2.2.0
pytest==8.0.0
pytest-asyncio==0.23.0
```

**Step 3: 创建 .gitignore**

```
*.pyc
__pycache__/
playwright-report/
test-results/
data/*.json
data/*.csv
```

**Step 4: 初始化 Python 包文件**

创建空的 `__init__.py` 文件（上面已列出）和空的 `data/.gitkeep`。

**Step 5: 初始化 git 仓库**

```bash
cd compassedu-scraper
git init
git add .
git commit -m "chore: initialize project structure"
```

---

## Task 2: 实现数据模型

**Files:**
- Create: `compassedu-scraper/src/models.py`
- Test: `compassedu-scraper/tests/test_models.py`

**Step 1: 编写失败的测试**

```python
# tests/test_models.py
from src.models import Case, CaseList

def test_case_creation():
    case = Case(
        university="新加坡国立大学",
        major="智能产业与数字化转型理学硕士",
        student_background="吉林大学 物流管理 应届生",
        gpa="84.95",
        ielts="6.5",
        toefl=None,
        undergraduate_type="985院校",
        offer_date="2026年02月"
    )
    assert case.university == "新加坡国立大学"
    assert case.major == "智能产业与数字化转型理学硕士"
    assert case.gpa == "84.95"

def test_case_to_dict():
    case = Case(
        university="东北大学（美国）",
        major="分析学硕士",
        student_background="海外本科",
        gpa="2.78",
        ielts=None,
        toefl=None,
        undergraduate_type="海外本科",
        offer_date="2026年02月"
    )
    data = case.to_dict()
    assert data["university"] == "东北大学（美国）"
    assert data["gpa"] == "2.78"
    assert "ielts" not in data or data["ielats"] is None

def test_case_list_add():
    case_list = CaseList()
    case = Case(
        university="香港中文大学",
        major="机器人学硕士",
        student_background="汕头大学 机械设计",
        gpa="85",
        ielts="6.5",
        toefl=None,
        undergraduate_type="普通本科",
        offer_date="2026年02月"
    )
    case_list.add(case)
    assert len(case_list.cases) == 1
```

**Step 2: 运行测试验证失败**

```bash
cd compassedu-scraper
pytest tests/test_models.py -v
```
Expected: FAIL - ModuleNotFoundError

**Step 3: 实现数据模型**

```python
# src/models.py
from dataclasses import dataclass, field
from typing import Optional, List
from datetime import datetime

@dataclass
class Case:
    """单个留学案例数据"""
    university: str          # 录取学校
    major: str               # 录取专业
    student_background: str  # 学生背景（本科学校+专业+毕业状态）
    gpa: str                 # GPA
    ielts: Optional[str] = None    # 雅思成绩
    toefl: Optional[str] = None    # 托福成绩
    gre: Optional[str] = None      # GRE成绩
    undergraduate_type: str = ""   # 本科院校类型（985/211/普通本科/海外本科）
    offer_date: str = ""           # 录取时间
    scraped_at: str = field(default_factory=lambda: datetime.now().isoformat())

    def to_dict(self) -> dict:
        """转换为字典，过滤空值"""
        data = {
            "university": self.university,
            "major": self.major,
            "student_background": self.student_background,
            "gpa": self.gpa,
            "undergraduate_type": self.undergraduate_type,
            "offer_date": self.offer_date,
            "scraped_at": self.scraped_at
        }
        if self.ielts:
            data["ielats"] = self.ielts
        if self.toefl:
            data["toefl"] = self.toefl
        if self.gre:
            data["gre"] = self.gre
        return data


@dataclass
class CaseList:
    """案例列表"""
    cases: List[Case] = field(default_factory=list)

    def add(self, case: Case) -> None:
        self.cases.append(case)

    def to_dicts(self) -> List[dict]:
        return [case.to_dict() for case in self.cases]

    def __len__(self) -> int:
        return len(self.cases)
```

**Step 4: 运行测试验证通过**

```bash
pytest tests/test_models.py -v
```
Expected: PASS

**Step 5: 提交**

```bash
git add src/models.py tests/test_models.py
git commit -m "feat: add Case and CaseList data models"
```

---

## Task 3: 实现 Playwright 页面抓取器

**Files:**
- Create: `compassedu-scraper/src/scraper.py`
- Test: `compassedu-scraper/tests/test_scraper.py`

**Step 1: 编写失败的测试**

```python
# tests/test_scraper.py
import pytest
from src.scraper import CompassEduscraper

@pytest.mark.asyncio
async def test_scraper_initialization():
    scraper = CompassEduscraper(headless=True)
    assert scraper.base_url == "https://m.compassedu.hk/offer/"
    await scraper.close()

@pytest.mark.asyncio
async def test_fetch_cases():
    scraper = CompassEduscraper(headless=True)
    cases = await scraper.fetch_cases(max_cases=5)
    assert len(cases) > 0
    assert len(cases) <= 5

    first_case = cases.cases[0]
    assert first_case.university
    assert first_case.major
    assert first_case.gpa

    await scraper.close()
```

**Step 2: 运行测试验证失败**

```bash
pytest tests/test_scraper.py -v
```
Expected: FAIL - ModuleNotFoundError

**Step 3: 实现抓取器核心逻辑**

```python
# src/scraper.py
import re
from playwright.async_api import async_playwright, Page, Browser
from .models import Case, CaseList


class CompassEduscraper:
    """指南者留学案例库抓取器"""

    BASE_URL = "https://m.compassedu.hk/offer/"

    def __init__(self, headless: bool = True):
        self.headless = headless
        self.browser: Browser = None
        self.page: Page = None

    async def _parse_case_from_card(self, card_element) -> Case | None:
        """从案例卡片元素解析数据"""
        try:
            # 获取卡片文本内容
            text = await card_element.inner_text()

            # 提取大学和专业（格式：XX大学XX专业硕士研究生offer一枚）
            title_match = re.search(r'(.*?)（.*?）(.*?)(硕士研究生|博士研究生)offer一枚', text)
            if not title_match:
                return None

            university = title_match.group(1).strip()
            major = title_match.group(2).strip() + title_match.group(3)

            # 提取学生背景和GPA（格式：XX大学 XX专业 应届生/其他，GPA X.XX）
            background_match = re.search(r'(.*?) (.*?) (.*?)，GPA([\d.]+)', text)
            if background_match:
                bg_university = background_match.group(1).strip()
                bg_major = background_match.group(2).strip()
                status = background_match.group(3).strip()
                gpa = background_match.group(4)
                student_background = f"{bg_university} {bg_major} {status}"
            else:
                student_background = ""
                gpa = ""

            # 提取雅思成绩
            ielts_match = re.search(r'雅思([\d.]+)', text)
            ielts = ielts_match.group(1) if ielts_match else None

            # 提取托福成绩
            toefl_match = re.search(r'托福([\d.]+)', text)
            toefl = toefl_match.group(1) if toefl_match else None

            # 提取本科类型
            undergraduate_type = "普通本科"  # 默认
            if "985" in text:
                undergraduate_type = "985院校"
            elif "211" in text:
                undergraduate_type = "211院校"
            elif "海外本科" in text:
                undergraduate_type = "海外本科"

            # 提取录取时间
            date_match = re.search(r'(\d{4})年(\d{2})月', text)
            if date_match:
                offer_date = f"{date_match.group(1)}年{date_match.group(2)}月"
            else:
                offer_date = ""

            return Case(
                university=university,
                major=major,
                student_background=student_background,
                gpa=gpa,
                ielts=ielats,
                toefl=toefl,
                undergraduate_type=undergraduate_type,
                offer_date=offer_date
            )
        except Exception as e:
            print(f"解析卡片失败: {e}")
            return None

    async def fetch_cases(self, max_cases: int = 50, scroll_wait: float = 1.0) -> CaseList:
        """抓取案例列表"""
        case_list = CaseList()

        async with async_playwright() as p:
            self.browser = await p.chromium.launch(headless=self.headless)
            self.page = await self.browser.new_page()

            await self.page.goto(self.BASE_URL, wait_until="networkidle")
            await self.page.wait_for_timeout(2000)  # 等待JS渲染

            last_height = 0
            scroll_attempts = 0
            max_scroll_attempts = 100  # 防止无限滚动

            while len(case_list) < max_cases and scroll_attempts < max_scroll_attempts:
                # 滚动到底部
                await self.page.evaluate("window.scrollTo(0, document.body.scrollHeight)")
                await self.page.wait_for_timeout(int(scroll_wait * 1000))

                # 获取当前页面高度
                current_height = await self.page.evaluate("document.body.scrollHeight")

                # 解析页面上的案例卡片
                case_cards = await self.page.query_selector_all(".school-item, .offer-item, .case-item")

                for card in case_cards:
                    if len(case_list) >= max_cases:
                        break

                    case = await self._parse_case_from_card(card)
                    if case:
                        # 检查是否重复（通过大学+专业+GPA判断）
                        is_duplicate = any(
                            c.university == case.university
                            and c.major == case.major
                            and c.gpa == case.gpa
                            for c in case_list.cases
                        )
                        if not is_duplicate:
                            case_list.add(case)

                # 如果页面高度没变，说明到底了
                if current_height == last_height:
                    scroll_attempts += 1
                else:
                    scroll_attempts = 0
                    last_height = current_height

        return case_list

    async def close(self):
        """关闭浏览器"""
        if self.browser:
            await self.browser.close()
```

**Step 4: 运行测试验证通过**

```bash
pytest tests/test_scraper.py -v
```
Expected: PASS

**Step 5: 提交**

```bash
git add src/scraper.py tests/test_scraper.py
git commit -m "feat: add Playwright-based scraper"
```

---

## Task 4: 实现数据存储和导出

**Files:**
- Create: `compassedu-scraper/src/storage.py`
- Test: `compassedu-scraper/tests/test_storage.py`

**Step 1: 编写失败的测试**

```python
# tests/test_storage.py
import os
import json
from src.storage import CaseStorage
from src.models import Case, CaseList

def test_storage_init(tmp_path):
    db_path = tmp_path / "cases.json"
    storage = CaseStorage(db_path=str(db_path))
    assert os.path.exists(db_path)

def test_storage_save_and_load(tmp_path):
    db_path = tmp_path / "cases.json"
    storage = CaseStorage(db_path=str(db_path))

    case_list = CaseList()
    case = Case(
        university="测试大学",
        major="测试专业",
        student_background="测试背景",
        gpa="3.5",
        undergraduate_type="985院校",
        offer_date="2026年02月"
    )
    case_list.add(case)

    storage.save(case_list)

    # 重新加载
    loaded = storage.load()
    assert len(loaded) == 1
    assert loaded[0]["university"] == "测试大学"

def test_export_csv(tmp_path):
    db_path = tmp_path / "cases.json"
    csv_path = tmp_path / "cases.csv"
    storage = CaseStorage(db_path=str(db_path))

    case_list = CaseList()
    case = Case(
        university="测试大学",
        major="测试专业",
        student_background="测试背景",
        gpa="3.5",
        ielts="7.0",
        undergraduate_type="985院校",
        offer_date="2026年02月"
    )
    case_list.add(case)
    storage.save(case_list)

    storage.export_csv(str(csv_path))
    assert os.path.exists(csv_path)

    # 验证CSV内容
    import pandas as pd
    df = pd.read_csv(csv_path)
    assert len(df) == 1
    assert df.iloc[0]["university"] == "测试大学"
```

**Step 2: 运行测试验证失败**

```bash
pytest tests/test_storage.py -v
```
Expected: FAIL - ModuleNotFoundError

**Step 3: 实现存储逻辑**

```python
# src/storage.py
import json
import os
import pandas as pd
from typing import List, Dict
from .models import CaseList


class CaseStorage:
    """案例数据存储"""

    def __init__(self, db_path: str = "data/cases.json"):
        self.db_path = db_path
        self._ensure_dir()

    def _ensure_dir(self):
        """确保数据目录存在"""
        directory = os.path.dirname(self.db_path)
        if directory and not os.path.exists(directory):
            os.makedirs(directory)

    def load(self) -> List[Dict]:
        """加载已存储的案例"""
        if not os.path.exists(self.db_path):
            return []

        with open(self.db_path, "r", encoding="utf-8") as f:
            return json.load(f)

    def save(self, case_list: CaseList) -> None:
        """保存案例数据"""
        existing = self.load()

        # 转换新案例为字典
        new_cases = case_list.to_dicts()

        # 合并去重
        existing_ids = {self._case_id(c) for c in existing}
        for case in new_cases:
            case_id = self._case_id(case)
            if case_id not in existing_ids:
                existing.append(case)

        # 保存
        with open(self.db_path, "w", encoding="utf-8") as f:
            json.dump(existing, f, ensure_ascii=False, indent=2)

    def _case_id(self, case: Dict) -> str:
        """生成案例唯一ID"""
        return f"{case['university']}|{case['major']}|{case['gpa']}"

    def export_csv(self, csv_path: str) -> None:
        """导出为 CSV"""
        data = self.load()
        if not data:
            return

        df = pd.DataFrame(data)
        df.to_csv(csv_path, index=False, encoding="utf-8-sig")
        print(f"已导出 {len(df)} 条案例到 {csv_path}")
```

**Step 4: 运行测试验证通过**

```bash
pytest tests/test_storage.py -v
```
Expected: PASS

**Step 5: 提交**

```bash
git add src/storage.py tests/test_storage.py
git commit -m "feat: add case storage with JSON and CSV export"
```

---

## Task 5: 实现命令行入口

**Files:**
- Create: `compassedu-scraper/src/__main__.py`
- Create: `compassedu-scraper/config.py`

**Step 1: 创建配置文件**

```python
# config.py
import os

BASE_URL = "https://m.compassedu.hk/offer/"
DEFAULT_DB_PATH = "data/cases.json"
DEFAULT_CSV_PATH = "data/cases.csv"
DEFAULT_MAX_CASES = 100
HEADLESS = os.getenv("HEADLESS", "true").lower() == "true"
```

**Step 2: 创建主入口**

```python
# src/__main__.py
import asyncio
import argparse
from .scraper import CompassEduscraper
from .storage import CaseStorage
from . import config


async def main():
    parser = argparse.ArgumentParser(description="指南者留学案例库抓取工具")
    parser.add_argument("-n", "--max-cases", type=int, default=config.DEFAULT_MAX_CASES,
                        help="最大抓取案例数")
    parser.add_argument("-o", "--output", type=str, default=config.DEFAULT_CSV_PATH,
                        help="CSV输出路径")
    parser.add_argument("--no-headless", action="store_true",
                        help="显示浏览器窗口")
    parser.add_argument("--export-only", action="store_true",
                        help="仅导出已有数据，不抓取")

    args = parser.parse_args()

    storage = CaseStorage(db_path=config.DEFAULT_DB_PATH)

    if args.export_only:
        print("导出已有数据...")
    else:
        print(f"开始抓取案例，目标数量: {args.max_cases}")
        scraper = CompassEduscraper(headless=not args.no_headless)
        case_list = await scraper.fetch_cases(max_cases=args.max_cases)
        await scraper.close()

        print(f"成功抓取 {len(case_list)} 条案例")
        storage.save(case_list)

    # 导出CSV
    storage.export_csv(args.output)
    print("完成！")


if __name__ == "__main__":
    asyncio.run(main())
```

**Step 3: 测试运行**

```bash
cd compassedu-scraper
python -m src --help
```
Expected: 显示帮助信息

**Step 4: 提交**

```bash
git add src/__main__.py config.py
git commit -m "feat: add CLI entry point"
```

---

## Task 6: 编写使用文档

**Files:**
- Modify: `compassedu-scraper/README.md`

**Step 1: 更新 README**

```markdown
# 指南者留学案例库抓取工具

从 m.compassedu.hk/offer/ 抓取留学录取案例数据。

## 功能特性

- 📊 抓取完整案例信息（学生背景、录取学校/专业、GPA、语言成绩等）
- 🔄 增量更新（自动跳过已抓取的案例）
- 📁 支持导出为 JSON/CSV 格式
- 🎯 可配置抓取数量

## 安装

\`\`\`bash
# 安装依赖
pip install -r requirements.txt

# 安装 Playwright 浏览器
playwright install chromium
\`\`\`

## 使用方法

### 基本用法

\`\`\`bash
# 抓取默认数量（100条）
python -m src

# 指定抓取数量
python -m src -n 50

# 显示浏览器窗口（调试用）
python -m src --no-headless

# 仅导出已有数据，不抓取
python -m src --export-only

# 自定义输出路径
python -m src -o mydata/cases.csv
\`\`\`

### 数据字段

抓取的数据包含以下字段：

| 字段 | 说明 |
|------|------|
| university | 录取学校 |
| major | 录取专业 |
| student_background | 学生背景（本科学校+专业+毕业状态） |
| gpa | GPA成绩 |
| ielts | 雅思成绩（如有） |
| toefl | 托福成绩（如有） |
| undergraduate_type | 本科院校类型（985/211/普通本科/海外本科） |
| offer_date | 录取时间 |

## 数据存储

- `data/cases.json` - 原始JSON数据（用于增量更新）
- `data/cases.csv` - 导出的CSV文件

## 测试

\`\`\`bash
pytest tests/ -v
\`\`\`
```

**Step 2: 提交**

```bash
git add README.md
git commit -m "docs: update README with usage instructions"
```

---

## Task 7: 端到端测试

**Files:**
- Test: `compassedu-scraper/tests/test_e2e.py`

**Step 1: 编写端到端测试**

```python
# tests/test_e2e.py
import pytest
import os
from src.scraper import CompassEduscraper
from src.storage import CaseStorage

@pytest.mark.e2e
@pytest.mark.asyncio
async def test_full_scrape_workflow(tmp_path):
    """测试完整的抓取工作流"""
    db_path = os.path.join(tmp_path, "test_cases.json")
    csv_path = os.path.join(tmp_path, "test_cases.csv")

    # 抓取少量案例
    scraper = CompassEduscraper(headless=True)
    case_list = await scraper.fetch_cases(max_cases=3)
    await scraper.close()

    assert len(case_list) > 0

    # 保存
    storage = CaseStorage(db_path=db_path)
    storage.save(case_list)

    # 验证保存成功
    loaded = storage.load()
    assert len(loaded) == len(case_list)

    # 导出CSV
    storage.export_csv(csv_path)
    assert os.path.exists(csv_path)

    # 验证CSV内容
    import pandas as pd
    df = pd.read_csv(csv_path)
    assert len(df) == len(case_list)
    assert "university" in df.columns
    assert "major" in df.columns
```

**Step 2: 运行测试**

```bash
pytest tests/test_e2e.py -v -m e2e
```
Expected: PASS

**Step 3: 提交**

```bash
git add tests/test_e2e.py
git commit -m "test: add end-to-end workflow test"
```

---

## 验收标准

1. ✅ 所有单元测试通过 (`pytest tests/ -v`)
2. ✅ 能成功抓取至少10条真实案例
3. ✅ 导出的CSV文件可用Excel正常打开
4. ✅ 增量更新功能正常（重复运行不会产生重复数据）
