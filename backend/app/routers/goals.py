import uuid
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, Field

from app.routers.auth import get_current_user
from app.services.goals import goal_service
from app.services.sessions import session_service


router = APIRouter()


class MilestonePayload(BaseModel):
    id: str
    title: str
    is_completed: bool = Field(default=False)
    completed_at: Optional[datetime] = None


class GoalCreateRequest(BaseModel):
    title: str
    description: str = ""
    status: str = "active"
    progress: float = 0.0
    target_date: Optional[datetime] = None
    milestones: List[MilestonePayload] = Field(default_factory=list)
    related_session_ids: List[str] = Field(default_factory=list)


class GoalUpdateRequest(BaseModel):
    title: str
    description: str = ""
    status: str = "active"
    progress: float = 0.0
    target_date: Optional[datetime] = None
    milestones: List[MilestonePayload] = Field(default_factory=list)
    related_session_ids: List[str] = Field(default_factory=list)


@router.get("/goals")
async def list_goals(user_id: str = Depends(get_current_user)):
    return goal_service.list_goals(user_id)


@router.get("/goals/{goal_id}")
async def get_goal(goal_id: str, user_id: str = Depends(get_current_user)):
    goal = goal_service.get_goal(goal_id, user_id)
    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")
    return goal


@router.post("/goals")
async def create_goal(request: GoalCreateRequest, user_id: str = Depends(get_current_user)):
    created = goal_service.create_goal(
        id=str(uuid.uuid4()),
        user_id=user_id,
        title=request.title,
        description=request.description,
        status=request.status,
        progress=request.progress,
        target_date=request.target_date,
        milestones=[milestone.dict() for milestone in request.milestones],
        related_session_ids=request.related_session_ids,
    )
    session_service.sync_goal_links(
        user_id=user_id,
        goal_id=created["id"],
        related_session_ids=created["related_session_ids"],
    )
    return created


@router.put("/goals/{goal_id}")
async def update_goal(goal_id: str, request: GoalUpdateRequest, user_id: str = Depends(get_current_user)):
    updated = goal_service.update_goal(
        goal_id,
        user_id,
        title=request.title,
        description=request.description,
        status=request.status,
        progress=request.progress,
        target_date=request.target_date,
        milestones=[milestone.dict() for milestone in request.milestones],
        related_session_ids=request.related_session_ids,
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Goal not found")
    session_service.sync_goal_links(
        user_id=user_id,
        goal_id=updated["id"],
        related_session_ids=updated["related_session_ids"],
    )
    return updated


@router.delete("/goals/{goal_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_goal(goal_id: str, user_id: str = Depends(get_current_user)):
    deleted = goal_service.delete_goal(goal_id, user_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Goal not found")
    session_service.sync_goal_links(user_id=user_id, goal_id=goal_id, related_session_ids=[])
    return Response(status_code=status.HTTP_204_NO_CONTENT)
