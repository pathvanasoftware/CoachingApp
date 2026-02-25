"""
Tests for Dynamic Prompt Generation System

Tests all 7 generation scenarios:
1. First-time user (role-based)
2. Based on conversation history (follow-up)
3. Based on emotion detection
4. Based on time context
5. Based on goal progress
6. Re-engagement (inactive users)
7. Smart recommendations (profile-based)
"""

import pytest
from datetime import datetime
from unittest.mock import Mock, patch
from app.services.prompt_generator import PromptGenerator


class TestScenario1_FirstTimeUser:
    """Test prompts for first-time users based on role"""
    
    def setup_method(self):
        self.generator = PromptGenerator()
    
    @patch('app.services.prompt_generator.load_profile')
    def test_new_manager_gets_management_prompts(self, mock_load_profile):
        """Manager role should get team management prompts"""
        mock_load_profile.return_value = {
            "role": "Manager",
            "team_size": 8,
            "experience_years": 5,
            "total_sessions": 0,
        }
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="new_manager",
            current_input=None,
            conversation_history=[],
        )
        
        # Should have management-related prompts (check for keywords)
        assert len(prompts) >= 3
        # Check for any management/leadership/team related content
        all_text = " ".join(prompts)
        assert "管理" in all_text or "领导" in all_text or "团队" in all_text
    
    @patch('app.services.prompt_generator.load_profile')
    def test_new_engineer_gets_technical_prompts(self, mock_load_profile):
        """Engineer role should get technical/IC prompts"""
        mock_load_profile.return_value = {
            "role": "Engineer",
            "team_size": 0,
            "experience_years": 3,
        }
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="new_engineer",
            current_input=None,
            conversation_history=None,
        )
        
        # Should have technical/IC prompts
        assert len(prompts) >= 3
        assert any("技术" in p or "影响力" in p or "职业" in p for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    def test_new_director_gets_leadership_prompts(self, mock_load_profile):
        """Director role should get leadership prompts"""
        mock_load_profile.return_value = {
            "role": "Director",
            "team_size": 15,
            "experience_years": 10,
        }
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="new_director",
            current_input=None,
            conversation_history=None,
        )
        
        # Should have leadership prompts
        assert len(prompts) >= 3
        assert any("领导" in p or "影响力" in p or "团队" in p for p in prompts)


class TestScenario2_ConversationHistory:
    """Test prompts based on conversation history (follow-up)"""
    
    def setup_method(self):
        self.generator = PromptGenerator()
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_user_discussed_delegation_gets_followup(self, mock_emotion, mock_load_profile):
        """User who discussed delegation should get delegation follow-up prompts"""
        mock_load_profile.return_value = {"role": "Manager"}
        mock_emotion.return_value = "neutral"
        
        # Simulate conversation about delegation
        history = [
            {"role": "user", "content": "我很难授权给团队"},
            {"role": "assistant", "content": "让我们聊聊授权..."},
            {"role": "user", "content": "我尝试了授权，但还是担心"},
        ]
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=history,
        )
        
        # Should have delegation follow-up prompts
        assert any("授权" in p for p in prompts)
        assert len(prompts) >= 3
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_user_discussed_feedback_gets_followup(self, mock_emotion, mock_load_profile):
        """User who discussed feedback should get feedback follow-up prompts"""
        mock_load_profile.return_value = {"role": "Manager"}
        mock_emotion.return_value = "neutral"
        
        history = [
            {"role": "user", "content": "我需要给团队成员反馈"},
            {"role": "assistant", "content": "让我们聊聊反馈..."},
        ]
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_456",
            current_input=None,
            conversation_history=history,
        )
        
        # Should have feedback follow-up prompts
        assert any("反馈" in p for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_user_discussed_career_gets_followup(self, mock_emotion, mock_load_profile):
        """User who discussed career should get career follow-up prompts"""
        mock_load_profile.return_value = {"role": "Engineer"}
        mock_emotion.return_value = "neutral"
        
        history = [
            {"role": "user", "content": "我在职业发展方向上有些迷茫"},
            {"role": "assistant", "content": "让我们聊聊你的职业目标..."},
        ]
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_789",
            current_input=None,
            conversation_history=history,
        )
        
        # Should have career follow-up prompts
        assert any("职业" in p or "目标" in p for p in prompts)


class TestScenario3_EmotionDetection:
    """Test prompts based on emotional state"""
    
    def setup_method(self):
        self.generator = PromptGenerator()
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_stressed_user_gets_stress_management_prompts(self, mock_emotion, mock_load_profile):
        """Stressed user should get stress management prompts"""
        mock_load_profile.return_value = {"role": "Engineer"}
        mock_emotion.return_value = "stressed"
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="stressed_user",
            current_input="我最近压力很大",
            conversation_history=[],
        )
        
        # Should have stress management prompts
        assert any("压力" in p or "焦虑" in p for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_anxious_user_gets_anxiety_prompts(self, mock_emotion, mock_load_profile):
        """Anxious user should get anxiety-related prompts"""
        mock_load_profile.return_value = {"role": "Manager"}
        mock_emotion.return_value = "anxious"
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="anxious_user",
            current_input="我很担心",
            conversation_history=[],
        )
        
        # Should have anxiety/stress prompts
        assert any("压力" in p or "焦虑" in p or "担心" in p for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_excited_user_gets_opportunity_prompts(self, mock_emotion, mock_load_profile):
        """Excited user should get opportunity analysis prompts"""
        mock_load_profile.return_value = {"role": "Engineer"}
        mock_emotion.return_value = "excited"
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="excited_user",
            current_input="我有个新机会！",
            conversation_history=[],
        )
        
        # Should have opportunity prompts
        assert any("机会" in p or "计划" in p for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_confident_user_gets_growth_prompts(self, mock_emotion, mock_load_profile):
        """Confident user should get growth planning prompts"""
        mock_load_profile.return_value = {"role": "Manager"}
        mock_emotion.return_value = "confident"
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="confident_user",
            current_input="我感觉很棒",
            conversation_history=[],
        )
        
        # Should have growth/plan prompts
        assert any("计划" in p or "机会" in p for p in prompts)


class TestScenario4_TimeContext:
    """Test prompts based on time context"""
    
    def setup_method(self):
        self.generator = PromptGenerator()
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.datetime')
    def test_monday_morning_gets_weekly_planning_prompts(self, mock_datetime, mock_load_profile):
        """Monday morning should trigger weekly planning prompts"""
        mock_load_profile.return_value = {"role": "Manager"}
        
        # Mock Monday morning (9am)
        mock_now = Mock()
        mock_now.strftime.return_value = "Monday"
        mock_now.hour = 9
        mock_now.day = 15
        mock_now.month = 2
        mock_datetime.now.return_value = mock_now
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=[{"role": "user", "content": "hi"}],
        )
        
        # Should have weekly planning prompts
        assert any("一周" in p or "本周" in p for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.datetime')
    def test_friday_afternoon_gets_reflection_prompts(self, mock_datetime, mock_load_profile):
        """Friday afternoon should trigger reflection prompts"""
        mock_load_profile.return_value = {"role": "Manager"}
        
        # Mock Friday afternoon (5pm)
        mock_now = Mock()
        mock_now.strftime.return_value = "Friday"
        mock_now.hour = 17
        mock_now.day = 19
        mock_now.month = 2
        mock_datetime.now.return_value = mock_now
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=[{"role": "user", "content": "hi"}],
        )
        
        # Should have reflection prompts
        assert any("本周" in p or "复盘" in p or "反思" in p for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.datetime')
    def test_month_end_gets_monthly_review_prompts(self, mock_datetime, mock_load_profile):
        """Month end should trigger monthly review prompts"""
        mock_load_profile.return_value = {"role": "Manager"}
        
        # Mock month end (28th)
        mock_now = Mock()
        mock_now.strftime.return_value = "Wednesday"
        mock_now.hour = 14
        mock_now.day = 28
        mock_now.month = 2
        mock_datetime.now.return_value = mock_now
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=[{"role": "user", "content": "hi"}],
        )
        
        # Should have monthly review prompts
        assert any("月" in p or "个月" in p for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.datetime')
    def test_quarter_end_gets_quarterly_planning_prompts(self, mock_datetime, mock_load_profile):
        """Quarter end should trigger quarterly planning prompts"""
        mock_load_profile.return_value = {"role": "Manager"}
        
        # Mock quarter end (March 28th)
        mock_now = Mock()
        mock_now.strftime.return_value = "Wednesday"
        mock_now.hour = 14
        mock_now.day = 28
        mock_now.month = 3
        mock_datetime.now.return_value = mock_now
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=[{"role": "user", "content": "hi"}],
        )
        
        # Should have quarterly prompts
        assert any("季度" in p or "年" in p for p in prompts)


class TestScenario5_GoalProgress:
    """Test prompts based on goal progress"""
    
    def setup_method(self):
        self.generator = PromptGenerator()
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_goal_7_days_old_gets_checkin_prompt(self, mock_emotion, mock_load_profile):
        """Goal not mentioned in 7 days should trigger check-in"""
        mock_load_profile.return_value = {
            "role": "Manager",
            "active_goal": "提升领导力",
        }
        mock_emotion.return_value = "neutral"
        
        # Mock _days_since_goal_mention to return 7
        with patch.object(self.generator, '_days_since_goal_mention', return_value=7):
            prompts = self.generator.generate_suggested_prompts(
                user_id="user_with_goal",
                current_input=None,
                conversation_history=[],
            )
        
        # Should have goal check-in prompts
        assert any("目标" in p or "提升领导力" in p for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_goal_near_deadline_gets_urgency_prompt(self, mock_emotion, mock_load_profile):
        """Goal near deadline should trigger urgency prompt"""
        mock_load_profile.return_value = {
            "role": "Manager",
            "active_goal": "完成项目",
            "goal_deadline": "2026-02-28",
        }
        mock_emotion.return_value = "neutral"
        
        # Mock _days_until_deadline to return 3
        with patch.object(self.generator, '_days_until_deadline', return_value=3):
            prompts = self.generator.generate_suggested_prompts(
                user_id="user_with_deadline",
                current_input=None,
                conversation_history=[],
            )
        
        # Should have deadline urgency prompts
        assert any("3天" in p or "完成项目" in p for p in prompts)


class TestScenario6_Reengagement:
    """Test prompts for re-engaging inactive users"""
    
    def setup_method(self):
        self.generator = PromptGenerator()
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_user_inactive_7_days_gets_reengagement_prompts(self, mock_emotion, mock_load_profile):
        """User inactive for 7+ days should get re-engagement prompts"""
        mock_load_profile.return_value = {"role": "Manager"}
        mock_emotion.return_value = "neutral"
        
        # Mock _days_since_last_use to return 7
        with patch.object(self.generator, '_days_since_last_use', return_value=7):
            prompts = self.generator.generate_suggested_prompts(
                user_id="inactive_user",
                current_input=None,
                conversation_history=[],
            )
        
        # Should have re-engagement prompts
        assert any("好久不见" in p or "最近" in p for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_inactive_user_with_last_topic_gets_continue_prompt(self, mock_emotion, mock_load_profile):
        """Inactive user should get prompt to continue last topic"""
        mock_load_profile.return_value = {"role": "Manager"}
        mock_emotion.return_value = "neutral"
        
        history = [
            {"role": "user", "content": "我很难授权"},
            {"role": "assistant", "content": "让我们聊聊授权..."},
        ]
        
        with patch.object(self.generator, '_days_since_last_use', return_value=7):
            prompts = self.generator.generate_suggested_prompts(
                user_id="inactive_user",
                current_input=None,
                conversation_history=history,
            )
        
        # Should have continue topic prompt
        assert any("继续" in p or "授权" in p for p in prompts)


class TestScenario7_SmartRecommendations:
    """Test smart recommendations based on user profile"""
    
    def setup_method(self):
        self.generator = PromptGenerator()
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_manager_with_large_team_never_discussed_management(self, mock_emotion, mock_load_profile):
        """Manager with team>5, never discussed management should get recommendation"""
        mock_load_profile.return_value = {
            "role": "Manager",
            "team_size": 8,
            "experience_years": 5,
        }
        mock_emotion.return_value = "neutral"
        
        # User has talked about other topics but not team management
        history = [
            {"role": "user", "content": "我想提升演讲能力"},
            {"role": "assistant", "content": "..."},
        ] * 3  # Multiple sessions
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="manager_123",
            current_input=None,
            conversation_history=history,
        )
        
        # Should have team management prompts
        assert any("团队" in p or "管理" in p for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_mid_career_never_discussed_career_development(self, mock_emotion, mock_load_profile):
        """3-5 years experience, never discussed career should get recommendation"""
        mock_load_profile.return_value = {
            "role": "Engineer",
            "experience_years": 4,
        }
        mock_emotion.return_value = "neutral"
        
        # User has talked about other topics but not career
        history = [
            {"role": "user", "content": "我想提升技术能力"},
            {"role": "assistant", "content": "..."},
        ] * 3  # Multiple sessions
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="engineer_456",
            current_input=None,
            conversation_history=history,
        )
        
        # Should have career development prompts
        assert any("职业" in p or "发展" in p or "方向" in p for p in prompts)


class TestPromptQuality:
    """Test overall prompt quality and constraints"""
    
    def setup_method(self):
        self.generator = PromptGenerator()
    
    @patch('app.services.prompt_generator.load_profile')
    def test_always_returns_3_to_5_prompts(self, mock_load_profile):
        """Should always return 3-5 prompts"""
        mock_load_profile.return_value = {"role": "Manager"}
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=[],
        )
        
        assert 3 <= len(prompts) <= 5
    
    @patch('app.services.prompt_generator.load_profile')
    def test_no_duplicate_prompts(self, mock_load_profile):
        """Should not return duplicate prompts"""
        mock_load_profile.return_value = {"role": "Manager"}
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=[],
        )
        
        # Check no duplicates
        assert len(prompts) == len(set(prompts))
    
    @patch('app.services.prompt_generator.load_profile')
    def test_prompts_are_strings(self, mock_load_profile):
        """All prompts should be strings"""
        mock_load_profile.return_value = {"role": "Manager"}
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=[],
        )
        
        assert all(isinstance(p, str) for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    def test_prompts_are_not_empty(self, mock_load_profile):
        """All prompts should be non-empty"""
        mock_load_profile.return_value = {"role": "Manager"}
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=[],
        )
        
        assert all(len(p) > 0 for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    def test_prompts_are_reasonable_length(self, mock_load_profile):
        """Prompts should be reasonable length (not too short/long)"""
        mock_load_profile.return_value = {"role": "Manager"}
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=[],
        )
        
        # Each prompt should be 10-100 characters
        assert all(10 <= len(p) <= 100 for p in prompts)


class TestEdgeCases:
    """Test edge cases and error handling"""
    
    def setup_method(self):
        self.generator = PromptGenerator()
    
    @patch('app.services.prompt_generator.load_profile')
    def test_handles_missing_profile(self, mock_load_profile):
        """Should handle missing/None profile gracefully"""
        mock_load_profile.return_value = None
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=None,
        )
        
        # Should still return valid prompts
        assert 3 <= len(prompts) <= 5
        assert all(isinstance(p, str) for p in prompts)
    
    @patch('app.services.prompt_generator.load_profile')
    def test_handles_empty_history(self, mock_load_profile):
        """Should handle empty conversation history"""
        mock_load_profile.return_value = {"role": "Manager"}
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=[],
        )
        
        # Should return first-time user prompts
        assert len(prompts) >= 3
    
    @patch('app.services.prompt_generator.load_profile')
    @patch('app.services.prompt_generator.detect_emotion')
    def test_handles_unknown_emotion(self, mock_emotion, mock_load_profile):
        """Should handle unknown emotional state"""
        mock_load_profile.return_value = {"role": "Manager"}
        mock_emotion.return_value = "unknown_emotion"
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input="test",
            conversation_history=[],
        )
        
        # Should still return valid prompts (just no emotion-based ones)
        assert len(prompts) >= 3
    
    @patch('app.services.prompt_generator.load_profile')
    def test_handles_missing_profile_fields(self, mock_load_profile):
        """Should handle missing optional profile fields"""
        mock_load_profile.return_value = {"role": "Manager"}  # Missing other fields
        
        prompts = self.generator.generate_suggested_prompts(
            user_id="user_123",
            current_input=None,
            conversation_history=[],
        )
        
        # Should still return valid prompts
        assert len(prompts) >= 3
