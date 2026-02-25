# Dynamic Prompt Generation System

**App根据用户上下文自动生成个性化prompt建议**

---

## 系统架构

### 输入信号
1. **用户Profile** - 职位、行业、经验
2. **历史对话** - 之前聊过什么
3. **当前情绪** - 检测到的情绪状态
4. **时间上下文** - 早上/晚上/工作日/周末
5. **目标进度** - 设定目标的完成情况

### 输出
- 3-5个个性化prompt建议
- 快速回复按钮
- 动态更新

---

## 场景1：首次使用（无历史）

### 检测：新用户，无对话历史

**生成策略：** 基于用户onboarding信息

### 如果用户填写了职位

#### 检测到："Manager" / "Lead" / "Director"
```
生成prompts:
1. "我刚当上经理，团队管理上遇到了一些挑战"
2. "我想提升我的领导力和影响力"
3. "我的团队最近士气不高，不知道怎么激励他们"
```

#### 检测到："Engineer" / "Developer" / "IC"
```
生成prompts:
1. "我在考虑从技术转管理，不知道是否适合"
2. "我想在当前岗位上更有影响力"
3. "我在职业发展方向上有些迷茫"
```

#### 检测到："VP" / "C-Level" / "Executive"
```
生成prompts:
1. "作为高管，我在团队文化建设上遇到了挑战"
2. "我想提升我的战略思维能力"
3. "我在处理高管团队的政治关系上需要指导"
```

---

## 场景2：基于历史对话

### 检测：用户之前聊过某个话题

#### 之前聊过：授权/Delegation
```
分析：
- 上次对话：讨论了授权困难
- 未完成：用户说会尝试某个方法

生成follow-up prompts:
1. "上次你建议我尝试[方法]，我试了，结果是..."
2. "我在授权上还是有困难，特别是[具体方面]"
3. "授权后我发现新问题：[问题]"
```

#### 之前聊过：职业发展
```
分析：
- 上次对话：讨论了职业选择
- 目标：用户设定了3个月目标

生成check-in prompts:
1. "我朝着上次的目标[目标]努力了，进展是..."
2. "我发现实现目标有个新障碍：[障碍]"
3. "我想调整一下我的职业目标，因为..."
```

---

## 场景3：基于情绪检测

### 检测：用户输入显示焦虑/压力

#### 关键词：stressed, overwhelmed, anxious, worried
```
生成prompts:
1. "我最近压力很大，主要是[原因]"
2. "我感觉事情太多做不完，很焦虑"
3. "我想聊聊如何管理工作压力"
```

### 检测：用户输入显示自信/积极

#### 关键词：excited, confident, ready, opportunity
```
生成prompts:
1. "我有个新机会，想分析一下利弊"
2. "我想制定一个[时间]的成长计划"
3. "我想聊聊如何最大化这个机会的价值"
```

---

## 场景4：基于时间上下文

### 检测：周一早上（8-10am）
```
生成prompts:
1. "新的一周开始了，我想规划一下本周的重点"
2. "本周我有几个重要会议，想准备一下"
3. "我想设定本周的个人成长目标"
```

### 检测：周五下午（4-6pm）
```
生成prompts:
1. "本周结束了，我想反思一下收获和挑战"
2. "我为下周准备了什么，想聊聊"
3. "本周有个情况我想复盘一下"
```

### 检测：月底（25-31号）
```
生成prompts:
1. "这个月结束了，我想回顾一下职业进展"
2. "下个月我想重点关注[方面]"
3. "我需要制定下个月的工作计划"
```

### 检测：季度末（3/6/9/12月最后一周）
```
生成prompts:
1. "这个季度结束了，我想做个职业盘点"
2. "下季度我想达成[目标]，需要规划"
3. "我在思考今年的职业目标完成情况"
```

---

## 场景5：基于目标进度

### 检测：用户设定了目标，7天未提及
```
生成prompts:
1. "你7天前设定了[目标]，进展如何？"
2. "在实现[目标]的过程中遇到了什么障碍吗？"
3. "需要调整[目标]吗？"
```

### 检测：目标即将到期（还剩3天）
```
生成prompts:
1. "你的目标[目标]还有3天到期，进展如何？"
2. "需要延长或调整[目标]的deadline吗？"
3. "有什么阻碍你完成[目标]？"
```

---

## 场景6：对话中断后继续

### 检测：用户3天未使用app
```
生成prompts:
1. "好久不见！最近有什么新挑战吗？"
2. "上次我们聊到[话题]，想继续吗？"
3. "最近工作怎么样？有什么想聊的？"
```

### 检测：用户上次对话突然中断
```
分析：
- 上次对话到一半停止
- 最后一个问题是[问题]

生成prompts:
1. "上次你问我[问题]，我们继续聊吧"
2. "上次聊到一半，你还想继续那个话题吗？"
3. "上次我们讨论的[话题]，你有新的想法吗？"
```

---

## 场景7：智能推荐

### 检测：用户是Manager + 团队规模>5人 + 从未聊过团队管理
```
生成prompts:
1. "作为管理者，你的团队管理风格是什么？"
2. "你的团队最近有什么挑战吗？"
3. "你想提升哪些管理技能？"
```

### 检测：用户工作3-5年 + 从未聊过职业发展
```
生成prompts:
1. "你在这个岗位3-5年了，未来的方向是什么？"
2. "你考虑过下一步的职业发展吗？"
3. "现在的工作还让你有成长感吗？"
```

---

## 实现逻辑

### Python Backend

```python
from typing import List, Dict
from datetime import datetime, timedelta
from app.services.memory_store import load_profile
from app.services.emotion_analyzer import detect_emotion

class PromptGenerator:
    """Dynamic prompt generation based on user context"""
    
    def generate_suggested_prompts(
        self,
        user_id: str,
        current_input: str = None,
        conversation_history: List[Dict] = None,
    ) -> List[str]:
        """Generate 3-5 personalized prompts for user"""
        
        signals = self._collect_signals(user_id, current_input, conversation_history)
        prompts = []
        
        # Priority 1: Follow-up from last conversation
        if signals.get("last_topic") and not signals.get("topic_completed"):
            prompts.extend(self._generate_followup_prompts(signals))
        
        # Priority 2: Goal check-in
        if signals.get("active_goal"):
            prompts.extend(self._generate_goal_prompts(signals))
        
        # Priority 3: Time-based
        prompts.extend(self._generate_time_based_prompts(signals))
        
        # Priority 4: Emotion-based
        if signals.get("current_emotion"):
            prompts.extend(self._generate_emotion_prompts(signals))
        
        # Priority 5: Smart recommendations
        prompts.extend(self._generate_smart_prompts(signals))
        
        # Deduplicate and return top 5
        return self._rank_and_dedupe(prompts, signals)[:5]
    
    def _collect_signals(self, user_id, current_input, history):
        """Collect all context signals"""
        profile = load_profile(user_id)
        
        return {
            # User profile
            "role": profile.get("role"),
            "industry": profile.get("industry"),
            "experience_years": profile.get("experience_years"),
            "team_size": profile.get("team_size"),
            
            # Conversation history
            "last_topic": self._extract_last_topic(history),
            "topic_completed": self._check_topic_completed(history),
            "mentioned_topics": self._extract_all_topics(history),
            
            # Current state
            "current_emotion": detect_emotion(current_input) if current_input else None,
            
            # Time context
            "time_of_day": self._get_time_category(),
            "day_of_week": datetime.now().strftime("%A"),
            "is_month_end": datetime.now().day >= 25,
            "is_quarter_end": self._is_quarter_end(),
            
            # Goals
            "active_goal": profile.get("active_goal"),
            "goal_days_since_mention": self._days_since_goal_mention(history),
            "goal_deadline": profile.get("goal_deadline"),
            
            # Usage pattern
            "days_since_last_use": self._days_since_last_use(history),
            "total_sessions": len(history) if history else 0,
        }
    
    def _generate_followup_prompts(self, signals):
        """Generate prompts based on last conversation"""
        last_topic = signals["last_topic"]
        
        topic_prompts = {
            "delegation": [
                "上次你建议我尝试[方法]，我试了，结果是...",
                "我在授权上还是有困难，特别是[具体方面]",
                "授权后我发现新问题：[问题]",
            ],
            "feedback": [
                "上次聊的反馈对话，我进行了，结果是...",
                "我还想聊聊如何给[类型]的人反馈",
                "反馈后发现新问题：[问题]",
            ],
            "career_development": [
                "我朝着上次的目标努力了，进展是...",
                "我发现实现目标有个新障碍",
                "我想调整一下职业目标",
            ],
            # ... 更多话题
        }
        
        return topic_prompts.get(last_topic, [])
    
    def _generate_time_based_prompts(self, signals):
        """Generate prompts based on time context"""
        prompts = []
        
        # Monday morning
        if signals["day_of_week"] == "Monday" and signals["time_of_day"] == "morning":
            prompts.extend([
                "新的一周开始了，我想规划一下本周的重点",
                "本周我有几个重要会议，想准备一下",
            ])
        
        # Friday afternoon
        if signals["day_of_week"] == "Friday" and signals["time_of_day"] == "afternoon":
            prompts.extend([
                "本周结束了，我想反思一下收获和挑战",
                "本周有个情况我想复盘一下",
            ])
        
        # Month end
        if signals["is_month_end"]:
            prompts.extend([
                "这个月结束了，我想回顾一下职业进展",
                "下个月我想重点关注[方面]",
            ])
        
        # Quarter end
        if signals["is_quarter_end"]:
            prompts.extend([
                "这个季度结束了，我想做个职业盘点",
                "下季度我想达成[目标]，需要规划",
            ])
        
        return prompts
    
    def _generate_emotion_prompts(self, signals):
        """Generate prompts based on detected emotion"""
        emotion = signals["current_emotion"]
        
        if emotion in ["stressed", "overwhelmed", "anxious"]:
            return [
                "我最近压力很大，主要是[原因]",
                "我感觉事情太多做不完，很焦虑",
                "我想聊聊如何管理工作压力",
            ]
        
        if emotion in ["excited", "confident", "motivated"]:
            return [
                "我有个新机会，想分析一下利弊",
                "我想制定一个成长计划",
                "我想聊聊如何最大化这个机会",
            ]
        
        return []
    
    def _generate_smart_prompts(self, signals):
        """Generate intelligent recommendations"""
        prompts = []
        
        # Manager with team > 5, never discussed team management
        if (signals["role"] in ["Manager", "Lead", "Director"] and 
            signals.get("team_size", 0) > 5 and 
            "team_management" not in signals["mentioned_topics"]):
            prompts.extend([
                "作为管理者，你的团队管理风格是什么？",
                "你的团队最近有什么挑战吗？",
            ])
        
        # 3-5 years experience, never discussed career development
        if (3 <= signals.get("experience_years", 0) <= 5 and 
            "career_development" not in signals["mentioned_topics"]):
            prompts.extend([
                "你在这个岗位3-5年了，未来的方向是什么？",
                "你考虑过下一步的职业发展吗？",
            ])
        
        # Inactive user (7+ days)
        if signals["days_since_last_use"] >= 7:
            prompts.extend([
                "好久不见！最近有什么新挑战吗？",
                "最近工作怎么样？有什么想聊的？",
            ])
        
        return prompts
    
    def _generate_goal_prompts(self, signals):
        """Generate prompts related to active goals"""
        goal = signals["active_goal"]
        
        if not goal:
            return []
        
        days_since = signals["goal_days_since_mention"]
        deadline = signals.get("goal_deadline")
        
        prompts = []
        
        # 7 days since mention
        if days_since >= 7:
            prompts.append(f"你7天前设定了{goal}，进展如何？")
        
        # Near deadline
        if deadline and self._days_until_deadline(deadline) <= 3:
            prompts.append(f"你的目标{goal}还有3天到期，进展如何？")
        
        return prompts
    
    def _rank_and_dedupe(self, prompts, signals):
        """Rank and deduplicate prompts"""
        # Remove duplicates
        unique = list(dict.fromkeys(prompts))
        
        # Rank by relevance (simplified)
        # In production, could use ML model
        return unique
    
    # Helper methods
    def _get_time_category(self):
        hour = datetime.now().hour
        if 6 <= hour < 12:
            return "morning"
        elif 12 <= hour < 18:
            return "afternoon"
        else:
            return "evening"
    
    def _is_quarter_end(self):
        month = datetime.now().month
        day = datetime.now().day
        return (month in [3, 6, 9, 12]) and (day >= 25)
    
    def _extract_last_topic(self, history):
        if not history:
            return None
        # Use NLP to extract topic from last conversation
        # Simplified version
        return "delegation"  # placeholder
    
    def _check_topic_completed(self, history):
        # Check if last topic was fully discussed
        return False  # placeholder
    
    def _extract_all_topics(self, history):
        if not history:
            return []
        # Extract all topics ever discussed
        return ["delegation", "feedback"]  # placeholder
    
    def _days_since_goal_mention(self, history):
        # Calculate days since goal was last mentioned
        return 0  # placeholder
    
    def _days_since_last_use(self, history):
        if not history:
            return 999
        # Calculate days since last message
        return 0  # placeholder
    
    def _days_until_deadline(self, deadline):
        # Calculate days until goal deadline
        return 0  # placeholder
```

---

### API Endpoint

```python
# backend/app/routers/prompts.py

from fastapi import APIRouter
from app.services.prompt_generator import PromptGenerator

router = APIRouter()
generator = PromptGenerator()

@router.get("/suggested-prompts/{user_id}")
async def get_suggested_prompts(user_id: str, current_input: str = None):
    """Get personalized prompts for user"""
    prompts = generator.generate_suggested_prompts(
        user_id=user_id,
        current_input=current_input,
        conversation_history=get_history(user_id),
    )
    return {"prompts": prompts}
```

---

### iOS Integration

```swift
// iOS/Services/PromptService.swift

class PromptService {
    func getSuggestedPrompts(userId: String, currentInput: String? = nil) async -> [String] {
        let endpoint = "/api/v1/suggested-prompts/\(userId)"
        var params = [String: String]()
        
        if let input = currentInput {
            params["current_input"] = input
        }
        
        let response = try await apiClient.get(endpoint, params: params)
        return response["prompts"] as? [String] ?? []
    }
}

// In ChatView
Task {
    let prompts = await promptService.getSuggestedPrompts(
        userId: currentUserId,
        currentInput: userMessage
    )
    
    // Display as quick reply buttons
    self.suggestedPrompts = prompts
}
```

---

## Prompt Template Library

### Topic-Specific Templates

```python
TOPIC_TEMPLATES = {
    "delegation": {
        "follow_up": [
            "上次你建议我尝试{method}，我试了，结果是{result}",
            "我在授权上还是有困难，特别是{aspect}",
            "授权后我发现新问题：{problem}",
        ],
        "new": [
            "我很难授权给团队，总担心{worry}",
            "我想学习如何更有效地授权",
            "我的团队{situation}，需要授权但不知道怎么开始",
        ],
    },
    
    "feedback": {
        "follow_up": [
            "上次聊的反馈对话，我进行了，{result}",
            "我还想聊聊如何给{person_type}的人反馈",
            "反馈后发现{insight}",
        ],
        "new": [
            "我需要给{person}反馈，关于{topic}",
            "我害怕给反馈，因为{fear}",
            "我想提升反馈技巧，特别是{aspect}",
        ],
    },
    
    "career_development": {
        "follow_up": [
            "我朝着{goal}努力了，进展是{progress}",
            "我发现实现{goal}有个新障碍",
            "我想调整职业目标，因为{reason}",
        ],
        "new": [
            "我在考虑{option_a}还是{option_b}",
            "我想转行做{new_role}，但{concern}",
            "我在职业发展方向上有些迷茫",
        ],
    },
    
    # ... 更多话题模板
}
```

---

## 测试示例

### 测试1：新用户 + Manager角色
```python
signals = {
    "role": "Manager",
    "team_size": 8,
    "total_sessions": 0,
    "mentioned_topics": [],
}

prompts = generator.generate_suggested_prompts(user_id="new_manager", signals=signals)
# 预期:
# - "作为管理者，你的团队管理风格是什么？"
# - "你的团队最近有什么挑战吗？"
# - "我想提升我的领导力和影响力"
```

### 测试2：用户3天前聊过授权
```python
signals = {
    "last_topic": "delegation",
    "topic_completed": False,
    "days_since_last_use": 3,
}

prompts = generator.generate_suggested_prompts(user_id="user_123", signals=signals)
# 预期:
# - "上次你建议我尝试[方法]，我试了，结果是..."
# - "我在授权上还是有困难，特别是[具体方面]"
```

### 测试3：周一早上
```python
signals = {
    "day_of_week": "Monday",
    "time_of_day": "morning",
}

prompts = generator.generate_suggested_prompts(user_id="user_456", signals=signals)
# 预期:
# - "新的一周开始了，我想规划一下本周的重点"
# - "本周我有几个重要会议，想准备一下"
```

---

## 高级功能

### A/B Testing
```python
# Test different prompt phrasings
VARIANTS = {
    "A": "我最近压力很大，主要是[原因]",
    "B": "最近工作压力大吗？聊聊你的压力源",
    "C": "压力管理：让我们一起找到缓解方法",
}

# Track which variant leads to more engagement
```

### Personalization Learning
```python
# Learn user preferences over time
- Which prompts user clicks
- Which prompts lead to long conversations
- Which topics user engages with most

# Adjust future suggestions based on learning
```

---

## 监控指标

- **Click-through rate** - 用户点击建议prompt的比例
- **Conversation length** - 使用建议prompt后的对话长度
- **User satisfaction** - 对话后的满意度评分
- **Return rate** - 使用建议prompt后的回访率

---

**这个系统让app能够：**
✅ 主动了解用户需求
✅ 个性化每个用户的体验
✅ 减少用户思考负担
✅ 提升对话质量
✅ 增加用户粘性
