from pydantic import BaseModel
from typing import Optional


class CallNotifyRequest(BaseModel):
    callee_uid: str
    call_id: str
    caller_name: str
    caller_photo_url: Optional[str] = None
    call_type: str = "audio"  # "audio" or "video"
