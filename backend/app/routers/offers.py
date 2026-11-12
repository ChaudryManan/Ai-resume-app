import logging

from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import firestore

from app.dependencies.auth import require_admin
from app.schemas.offer_schema import GenerateOfferRequest
from app.services.offer_service import create_offer, approve_and_send_offer

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/offers", tags=["job offers"])


@router.post("/generate")
def generate_offer(payload: GenerateOfferRequest, admin: dict = Depends(require_admin)):
    try:
        return create_offer(
            firestore.client(), admin["uid"], payload.model_dump()
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except Exception as error:
        logger.exception("Could not generate job offer draft")
        raise HTTPException(status_code=500, detail="Could not generate offer draft.") from error


@router.post("/{offer_id}/approve-and-send")
def approve_and_send(offer_id: str, admin: dict = Depends(require_admin)):
    try:
        return approve_and_send_offer(firestore.client(), offer_id, admin["uid"])
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    except Exception as error:
        logger.exception("Could not send approved offer %s", offer_id)
        raise HTTPException(status_code=502, detail="Offer email could not be sent.") from error
