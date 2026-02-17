from fastapi import APIRouter
from app.services.llm import CoachingRequest, CoachingResponse, get_coaching_response

router = APIRouter()

@router.post("/", response_model=CoachingResponse)
async def chat(request: CoachingRequest) -> CoachingResponse:
    """Handle coaching chat messages"""
    return await get_coaching_response(request)

@router.post("/quick-replies")
async def get_quick_replies(message: str, response: str = "") -> dict:
    """Get suggested quick replies for a message"""
    from app.services.llm import generate_quick_replies
    return {"quick_replies": generate_quick_replies(message, response)}
