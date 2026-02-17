#!/usr/bin/env python3
import asyncio
from app.services.llm import CoachingRequest, get_coaching_response

TEST_MESSAGE = "I was offered a new role, but it may hurt my long-term leadership path."

async def main():
    for style in ["directive", "facilitative", "supportive", "strategic"]:
        req = CoachingRequest(
            message=TEST_MESSAGE,
            coaching_style=style,
            context="User wants VP-level growth in 18 months."
        )
        resp = await get_coaching_response(req)
        print("\n" + "=" * 80)
        print(f"STYLE: {style}")
        print(f"style_used={resp.style_used} emotion={resp.emotion_detected} goal_link={resp.goal_link}")
        print("- response:")
        print(resp.response[:600])
        print("- quick_replies:", resp.quick_replies)

if __name__ == "__main__":
    asyncio.run(main())
