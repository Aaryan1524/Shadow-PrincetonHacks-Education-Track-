import os
import base64
import httpx
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

KNOT_CLIENT_ID = os.environ.get("KNOT_CLIENT_ID", "")
KNOT_SECRET_KEY = os.environ.get("KNOT_SECRET_KEY", "")
KNOT_BASE_URL = "https://production.knotapi.com"


def _basic_auth_header() -> str:
    token = base64.b64encode(f"{KNOT_CLIENT_ID}:{KNOT_SECRET_KEY}".encode()).decode()
    return f"Basic {token}"


class CreateSessionRequest(BaseModel):
    external_user_id: str


@app.post("/knot/session")
async def create_knot_session(body: CreateSessionRequest):
    if not KNOT_SECRET_KEY or not KNOT_CLIENT_ID:
        raise HTTPException(status_code=500, detail="KNOT credentials not set")

    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{KNOT_BASE_URL}/session/create",
            headers={
                "Authorization": _basic_auth_header(),
                "Content-Type": "application/json",
            },
            json={
                "type": "transaction_link",
                "external_user_id": body.external_user_id,
                "merchant_ids": [41],
            },
        )

    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail=response.text)

    data = response.json()
    return {"session_id": data.get("session")}


@app.post("/knot/webhook")
async def knot_webhook(request: Request):
    payload = await request.json()
    print("Knot webhook received:", payload)
    return {"status": "received"}


@app.get("/knot/transactions/{external_user_id}")
async def get_transactions(external_user_id: str):
    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{KNOT_BASE_URL}/transactions",
            headers={"Authorization": _basic_auth_header()},
            params={"external_user_id": external_user_id},
        )

    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail=response.text)

    return response.json()


@app.get("/knot/merchants")
async def list_merchants(type: str = "transaction_link", platform: str = "ios", search: str = None):
    params = {"type": type, "platform": platform}
    if search:
        params["search"] = search
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{KNOT_BASE_URL}/merchants/list",
            headers={
                "Authorization": _basic_auth_header(),
                "Content-Type": "application/json",
            },
            json=params,
        )
    if response.status_code != 200:
        raise HTTPException(status_code=response.status_code, detail=response.text)
    return response.json()


@app.get("/health")
async def health():
    return {"status": "ok"}
