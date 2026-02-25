"""
Dynamic Prompt Generation Service

Generates personalized prompts based on user context:
- User profile (role, experience, team size)
- Conversation history (last topics discussed)
- Emotional state (detected from input)
- Time context (day, month, quarter)
- Goal progress (active goals and deadlines)
"""

from typing import List, Dict, Optional
from datetime import datetime, timedelta
from app.services.memory_store import load_profile
from app.services.emotion_analyzer import detect_emotion


class PromptGenerator:
    """Dynamic prompt generation based on user context"""
    
    # Topic templates for follow-up prompts
    TOPIC_TEMPLATES = {
        "delegation": {
            "follow_up": [
                "上次我们聊了授权，你尝试了什么方法？结果如何？",
                "我在授权上还是有困难，特别是不知道怎么放手",
                "授权后我发现新问题：下属做的不够好，我该怎么办？",
            ],
            "new": [
                "我很难授权给团队，总担心他们做不好",
                "我想学习如何更有效地授权",
                "我什么事都想自己把控，不知道怎么改变",
            ],
        },
        
        "feedback": {
            "follow_up": [
                "上次聊的反馈对话，你进行得怎么样？",
                "我还想聊聊如何给不同性格的人反馈",
                "反馈后发现对方很防御，怎么处理？",
            ],
            "new": [
                "我需要给一个表现不佳的团队成员反馈，但不知道怎么说",
                "我害怕给负面反馈，担心伤害关系",
                "我想提升反馈技巧，特别是建设性反馈",
            ],
        },
        
        "career_development": {
            "follow_up": [
                "你朝着上次设定的职业目标努力了，进展如何？",
                "我发现实现职业目标有个新障碍",
                "我想调整一下职业发展方向",
            ],
            "new": [
                "我在职业发展方向上有些迷茫",
                "我在考虑转行，但不确定是否合适",
                "我想制定一个清晰的职业发展计划",
            ],
        },
        
        "team_management": {
            "follow_up": [
                "上次聊的团队管理问题，现在情况如何？",
                "我尝试了你建议的方法，但效果不明显",
                "团队管理上出现了新挑战",
            ],
            "new": [
                "我的团队最近士气不高，不知道怎么激励他们",
                "团队里有冲突，影响了工作氛围",
                "我刚接手一个新团队，第一个月应该做什么？",
            ],
        },
        
        "confidence": {
            "follow_up": [
                "上次我们聊了自信心的问题，现在感觉如何？",
                "我尝试了挑战自己的方法，有些进展但也遇到困难",
                "自信心上还是有反复，这正常吗？",
            ],
            "new": [
                "我经常怀疑自己，觉得不够好",
                "我在重要场合总是不敢发言，怎么克服？",
                "即使成功了也觉得是运气，不是实力",
            ],
        },
    }
    
    def generate_suggested_prompts(
        self,
        user_id: str,
        current_input: Optional[str] = None,
        conversation_history: Optional[List[Dict]] = None,
    ) -> List[str]:
        """
        Generate 3-5 personalized prompts for user
        
        Args:
            user_id: User identifier
            current_input: User's current message (if any)
            conversation_history: List of previous messages
            
        Returns:
            List of 3-5 personalized prompt suggestions
        """
        
        # Collect all context signals
        signals = self._collect_signals(user_id, current_input, conversation_history)
        
        prompts = []
        
        # Priority 1: Re-engagement if inactive (HIGHEST PRIORITY)
        if signals.get("days_since_last_use", 0) >= 7:
            prompts.extend(self._generate_reengagement_prompts(signals))
        
        # Priority 2: Follow-up from last conversation
        if signals.get("last_topic") and not signals.get("topic_completed"):
            prompts.extend(self._generate_followup_prompts(signals))
        
        # Priority 3: Goal check-in
        if signals.get("active_goal"):
            prompts.extend(self._generate_goal_prompts(signals))
        
        # Priority 4: Time-based
        prompts.extend(self._generate_time_based_prompts(signals))
        
        # Priority 5: Emotion-based
        if signals.get("current_emotion"):
            prompts.extend(self._generate_emotion_prompts(signals))
        
        # Priority 6: Smart recommendations based on profile
        prompts.extend(self._generate_smart_prompts(signals))
        
        # Deduplicate and return top 5
        return self._rank_and_dedupe(prompts, signals)[:5]
    
    def _collect_signals(
        self,
        user_id: str,
        current_input: Optional[str],
        history: Optional[List[Dict]]
    ) -> Dict:
        """Collect all context signals for prompt generation"""
        
        profile = load_profile(user_id) or {}
        
        return {
            # User profile
            "role": profile.get("role"),
            "industry": profile.get("industry"),
            "experience_years": profile.get("experience_years", 0),
            "team_size": profile.get("team_size", 0),
            
            # Conversation history
            "last_topic": self._extract_last_topic(history),
            "topic_completed": self._check_topic_completed(history),
            "mentioned_topics": self._extract_all_topics(history),
            "total_sessions": len(history) if history else 0,
            
            # Current state
            "current_emotion": detect_emotion(current_input) if current_input else None,
            "current_input": current_input,
            
            # Time context
            "time_of_day": self._get_time_category(),
            "day_of_week": datetime.now().strftime("%A"),
            "is_month_end": datetime.now().day >= 25,
            "is_quarter_end": self._is_quarter_end(),
            
            # Goals
            "active_goal": profile.get("active_goal"),
            "goal_days_since_mention": self._days_since_goal_mention(history, profile),
            "goal_deadline": profile.get("goal_deadline"),
            
            # Usage pattern
            "days_since_last_use": self._days_since_last_use(history),
        }
    
    def _generate_followup_prompts(self, signals: Dict) -> List[str]:
        """Generate prompts based on last conversation topic"""
        last_topic = signals.get("last_topic")
        
        if not last_topic or last_topic not in self.TOPIC_TEMPLATES:
            return []
        
        return self.TOPIC_TEMPLATES[last_topic].get("follow_up", [])
    
    def _generate_time_based_prompts(self, signals: Dict) -> List[str]:
        """Generate prompts based on time context"""
        prompts = []
        
        day = signals.get("day_of_week", "")
        time = signals.get("time_of_day", "")
        
        # Monday morning - weekly planning
        if day == "Monday" and time == "morning":
            prompts.extend([
                "新的一周开始了，我想规划一下本周的重点",
                "本周我有几个重要会议，想准备一下",
                "我想设定本周的个人成长目标",
            ])
        
        # Friday afternoon - weekly reflection
        if day == "Friday" and time == "afternoon":
            prompts.extend([
                "本周结束了，我想反思一下收获和挑战",
                "我为下周准备了什么，想聊聊",
                "本周有个情况我想复盘一下",
            ])
        
        # Month end
        if signals.get("is_month_end"):
            prompts.extend([
                "这个月结束了，我想回顾一下职业进展",
                "下个月我想重点关注哪些方面",
                "我需要制定下个月的工作计划",
            ])
        
        # Quarter end
        if signals.get("is_quarter_end"):
            prompts.extend([
                "这个季度结束了，我想做个职业盘点",
                "下季度我想达成什么目标，需要规划",
                "我在思考今年的职业目标完成情况",
            ])
        
        return prompts
    
    def _generate_emotion_prompts(self, signals: Dict) -> List[str]:
        """Generate prompts based on detected emotional state"""
        emotion = signals.get("current_emotion")
        
        if not emotion:
            return []
        
        stress_emotions = ["stressed", "overwhelmed", "anxious", "worried"]
        positive_emotions = ["excited", "confident", "motivated", "happy"]
        
        if emotion in stress_emotions:
            return [
                "我最近压力很大，主要是工作上的事情",
                "我感觉事情太多做不完，很焦虑",
                "我想聊聊如何管理工作压力",
            ]
        
        if emotion in positive_emotions:
            return [
                "我有个新机会，想分析一下利弊",
                "我想制定一个成长计划",
                "我想聊聊如何最大化这个机会的价值",
            ]
        
        return []
    
    def _generate_smart_prompts(self, signals: Dict) -> List[str]:
        """Generate intelligent recommendations based on user profile"""
        prompts = []
        
        role = signals.get("role", "")
        team_size = signals.get("team_size", 0)
        experience = signals.get("experience_years", 0)
        mentioned = signals.get("mentioned_topics", [])
        total_sessions = signals.get("total_sessions", 0)
        
        # First-time user - role-based prompts
        if total_sessions == 0:
            if role in ["Manager", "Lead", "Director", "VP"]:
                prompts.extend([
                    "我刚当上经理/领导，团队管理上遇到了一些挑战",
                    "我想提升我的领导力和影响力",
                    "我的团队最近士气不高，不知道怎么激励他们",
                ])
            
            elif role in ["Engineer", "Developer", "Designer", "IC"]:
                prompts.extend([
                    "我在考虑从技术转管理，不知道是否适合",
                    "我想在当前岗位上更有影响力",
                    "我在职业发展方向上有些迷茫",
                ])
            
            else:
                # Generic first-time prompts
                prompts.extend([
                    "我在工作上遇到了一个挑战，想找人聊聊",
                    "我想提升某个职业技能",
                    "我在职业发展上有些困惑",
                ])
        
        # Manager with team > 5, never discussed team management
        if (role in ["Manager", "Lead", "Director"] and 
            team_size > 5 and 
            "team_management" not in mentioned):
            prompts.extend([
                "作为管理者，你的团队管理风格是什么？",
                "你的团队最近有什么挑战吗？",
            ])
        
        # 3-5 years experience, never discussed career
        if (3 <= experience <= 5 and 
            "career_development" not in mentioned and 
            total_sessions > 2):
            prompts.extend([
                "你在这个岗位3-5年了，未来的方向是什么？",
                "你考虑过下一步的职业发展吗？",
            ])
        
        return prompts
    
    def _generate_goal_prompts(self, signals: Dict) -> List[str]:
        """Generate prompts related to active goals"""
        goal = signals.get("active_goal")
        
        if not goal:
            return []
        
        days_since = signals.get("goal_days_since_mention", 0)
        deadline = signals.get("goal_deadline")
        
        prompts = []
        
        # 7 days since mention - check in
        if days_since >= 7:
            prompts.append(f"你之前设定的目标'{goal}'，进展如何？")
            prompts.append(f"在实现'{goal}'的过程中遇到了什么障碍吗？")
        
        # Near deadline - urgency
        if deadline and self._days_until_deadline(deadline) <= 3:
            prompts.append(f"你的目标'{goal}'还有3天到期，进展如何？")
            prompts.append(f"有什么阻碍你完成'{goal}'？")
        
        return prompts
    
    def _generate_reengagement_prompts(self, signals: Dict) -> List[str]:
        """Generate prompts to re-engage inactive users"""
        days = signals.get("days_since_last_use", 0)
        last_topic = signals.get("last_topic")
        
        prompts = []
        
        if days >= 7:
            prompts.extend([
                "好久不见！最近有什么新挑战吗？",
                "最近工作怎么样？有什么想聊的？",
            ])
        
        if last_topic:
            prompts.append(f"上次我们聊到{last_topic}，想继续吗？")
        
        return prompts
    
    def _rank_and_dedupe(self, prompts: List[str], signals: Dict) -> List[str]:
        """Remove duplicates and rank prompts by relevance"""
        # Remove duplicates while preserving order
        unique = list(dict.fromkeys(prompts))
        
        # In production, could use ML to rank by relevance
        # For now, return in priority order
        return unique
    
    # Helper methods
    
    def _get_time_category(self) -> str:
        """Get time of day category"""
        hour = datetime.now().hour
        if 6 <= hour < 12:
            return "morning"
        elif 12 <= hour < 18:
            return "afternoon"
        else:
            return "evening"
    
    def _is_quarter_end(self) -> bool:
        """Check if current date is quarter end"""
        month = datetime.now().month
        day = datetime.now().day
        return (month in [3, 6, 9, 12]) and (day >= 25)
    
    def _extract_last_topic(self, history: Optional[List[Dict]]) -> Optional[str]:
        """Extract main topic from last conversation"""
        if not history or len(history) == 0:
            return None
        
        # Simplified: check last few messages for topic keywords
        # In production, use NLP for topic extraction
        last_messages = " ".join([
            msg.get("content", "") 
            for msg in history[-3:] 
            if msg.get("role") == "user"
        ]).lower()
        
        # Keyword matching for topics
        topic_keywords = {
            "delegation": ["授权", "delegate", "放手", "委派"],
            "feedback": ["反馈", "feedback", "评价"],
            "career_development": ["职业", "career", "发展", "promotion"],
            "team_management": ["团队", "team", "管理", "management"],
            "confidence": ["自信", "confidence", "怀疑", "imposter"],
        }
        
        for topic, keywords in topic_keywords.items():
            if any(kw in last_messages for kw in keywords):
                return topic
        
        return None
    
    def _check_topic_completed(self, history: Optional[List[Dict]]) -> bool:
        """Check if last topic was fully discussed"""
        # Simplified: assume not completed if < 10 messages
        if not history:
            return True
        return len(history) >= 10
    
    def _extract_all_topics(self, history: Optional[List[Dict]]) -> List[str]:
        """Extract all topics ever discussed"""
        if not history:
            return []
        
        # Simplified: return unique topics from all history
        all_text = " ".join([
            msg.get("content", "") 
            for msg in history 
            if msg.get("role") == "user"
        ]).lower()
        
        topics = []
        topic_keywords = {
            "delegation": ["授权", "delegate"],
            "feedback": ["反馈", "feedback"],
            "career_development": ["职业", "career"],
            "team_management": ["团队", "team"],
            "confidence": ["自信", "confidence"],
        }
        
        for topic, keywords in topic_keywords.items():
            if any(kw in all_text for kw in keywords):
                topics.append(topic)
        
        return list(set(topics))
    
    def _days_since_goal_mention(self, history: Optional[List[Dict]], profile: Dict) -> int:
        """Calculate days since goal was last mentioned"""
        # Simplified: return 0
        # In production, parse history for goal mentions
        return 0
    
    def _days_since_last_use(self, history: Optional[List[Dict]]) -> int:
        """Calculate days since last app use"""
        if not history:
            return 999
        
        # Simplified: return 0
        # In production, parse timestamps from history
        return 0
    
    def _days_until_deadline(self, deadline: str) -> int:
        """Calculate days until goal deadline"""
        # Simplified: return 10
        # In production, parse deadline date
        return 10
