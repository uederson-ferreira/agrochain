import pytest
from fastapi.testclient import TestClient
from backend.src.main import app

client = TestClient(app)

@pytest.mark.asyncio
async def test_create_policy():
    response = client.post("/api/policies", json={
        "farmer": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "coverageAmount": 10000000000000000000,
        "startDate": 1742140800,
        "endDate": 1757817600,
        "region": "Bahia,BR",
        "cropType": "Soja",
        "parameters": [
            {
                "parameterType": "rainfall",
                "thresholdValue": 50000,
                "periodInDays": 180,
                "triggerAbove": false,
                "payoutPercentage": 5000
            }
        ]
    })
    assert response.status_code == 200
    assert "policyId" in response.json()