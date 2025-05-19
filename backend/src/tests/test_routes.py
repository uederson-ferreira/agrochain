import pytest
import httpx
from datetime import datetime
import time
from web3 import Web3
import pytest_asyncio

# Configurações básicas
BASE_URL = "https://agrochain-jsvb.onrender.com"
VALID_FARMER_ADDRESS = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"  # Primeira conta do Anvil
INVALID_FARMER_ADDRESS = "0xInvalidAddress"
REGION = "Bahia,BR"
CROP_TYPE = "Soja"
AMOUNT = 10000000000000000000  # 10 ETH em wei
CURRENT_TIME = int(time.time())
START_DATE = CURRENT_TIME + 3600  # 1 hora no futuro
END_DATE = START_DATE + 86400 * 30  # 30 dias depois

# Fixture para inicializar o cliente HTTP assíncrono
@pytest_asyncio.fixture
async def client():
    client = httpx.AsyncClient(base_url=BASE_URL, timeout=10.0)
    try:
        yield client
    finally:
        await client.aclose()

# Fixture para dados de exemplo
@pytest.fixture
def sample_policy_data():
    return {
        "farmer": VALID_FARMER_ADDRESS,
        "coverageAmount": AMOUNT,
        "startDate": START_DATE,
        "endDate": END_DATE,
        "region": REGION,
        "cropType": CROP_TYPE,
        "parameters": [
            {
                "parameterType": "rainfall",
                "thresholdValue": 50000,
                "periodInDays": 180,
                "triggerAbove": False,
                "payoutPercentage": 5000
            }
        ]
    }

# Fixture para garantir que uma apólice seja criada antes dos testes
@pytest_asyncio.fixture
async def setup_policy(client, sample_policy_data):
    response = await client.post("/api/policies", json=sample_policy_data)
    assert response.status_code == 200
    data = response.json()
    assert "policyId" in data
    global POLICY_ID
    POLICY_ID = data["policyId"]
    return POLICY_ID

# 1. Teste para criar apólice
@pytest.mark.asyncio
async def test_create_policy(client, sample_policy_data):
    response = await client.post("/api/policies", json=sample_policy_data)
    assert response.status_code == 200
    data = response.json()
    assert "policyId" in data
    assert "transactionHash" in data
    assert "blockNumber" in data
    assert isinstance(data["policyId"], int)
    assert data.get("warning") is None or isinstance(data.get("warning"), str)

@pytest.mark.asyncio
async def test_create_policy_invalid_farmer(client, sample_policy_data):
    invalid_data = sample_policy_data.copy()
    invalid_data["farmer"] = INVALID_FARMER_ADDRESS
    response = await client.post("/api/policies", json=invalid_data)
    assert response.status_code == 400
    data = response.json()
    assert "detail" in data
    assert "Invalid farmer address" in data["detail"]

@pytest.mark.asyncio
async def test_create_policy_past_start_date(client, sample_policy_data):
    invalid_data = sample_policy_data.copy()
    invalid_data["startDate"] = CURRENT_TIME - 86400  # Ontem
    response = await client.post("/api/policies", json=invalid_data)
    assert response.status_code == 400
    data = response.json()
    assert "detail" in data
    assert "Start date must be in the future" in data["detail"]

# 2. Teste para ativar apólice
@pytest.mark.asyncio
async def test_activate_policy(client, setup_policy):
    # Enviar premium (ajustado para o valor calculado pela apólice)
    response = await client.post(f"/api/policies/{POLICY_ID}/activate", json={"premium": AMOUNT})
    assert response.status_code == 200
    data = response.json()
    assert "success" in data
    assert data["success"] is True
    assert "transactionHash" in data

# 3. Teste para consultar detalhes da apólice
@pytest.mark.asyncio
async def test_get_policy_details(client, setup_policy):
    response = await client.get(f"/api/policies/{POLICY_ID}")
    assert response.status_code == 200
    data = response.json()
    assert "id" in data
    assert "farmer" in data
    assert "coverageAmount" in data
    assert "parameters" in data

@pytest.mark.asyncio
async def test_get_policy_details_not_found(client):
    response = await client.get("/api/policies/9999")
    assert response.status_code == 404
    data = response.json()
    assert "detail" in data

# 4. Teste para cancelar apólice
@pytest.mark.asyncio
async def test_cancel_policy(client, setup_policy):
    response = await client.post(f"/api/policies/{POLICY_ID}/cancel")
    assert response.status_code == 200
    data = response.json()
    assert "success" in data or "refundAmount" in data
    if "transactionHash" in data:
        assert isinstance(data["transactionHash"], str)

# 5. Teste para buscar dados climáticos
@pytest.mark.asyncio
async def test_fetch_openweather_data(client, setup_policy, mocker):
    mocker.patch("services.openweather.fetch_climate_data", return_value=100)  # Mock da API
    response = await client.post(f"/api/policies/{POLICY_ID}/openweather-data", json={"region": REGION, "parameterType": "rainfall"})
    assert response.status_code == 200
    data = response.json()
    assert "policyId" in data
    assert "region" in data
    assert "parameterType" in data
    assert "currentValue" in data

@pytest.mark.asyncio
async def test_fetch_openweather_data_invalid_region(client, setup_policy):
    response = await client.post(f"/api/policies/{POLICY_ID}/openweather-data", json={"region": "InvalidRegion", "parameterType": "rainfall"})
    assert response.status_code == 502 or response.status_code == 200  # Pode falhar ou continuar com aviso

# 6. Teste para obter metadados do NFT
@pytest.mark.asyncio
async def test_get_nft_metadata(client, setup_policy):  # Remova o parâmetro mock_nft_contract
    response = await client.get(f"/api/policies/{POLICY_ID}/nft")
    assert response.status_code == 200
    data = response.json()
    assert "policyId" in data
    assert "metadata" in data

@pytest.mark.asyncio
async def test_get_nft_metadata_not_found(client):
    response = await client.get("/api/policies/9999/nft")
    assert response.status_code == 404
    data = response.json()
    assert "detail" in data

# 7. Teste para obter URI do token NFT
@pytest.mark.asyncio
async def test_get_nft_token_uri(client, setup_policy):
    response = await client.get(f"/api/policies/{POLICY_ID}/nft/token-uri")
    assert response.status_code == 200
    data = response.json()
    assert "policyId" in data
    assert "tokenUri" in data

# 8. Teste para consultar saldo da tesouraria
@pytest.mark.asyncio
async def test_get_treasury_balance(client):
    response = await client.get("/api/treasury/balance")
    assert response.status_code == 200
    data = response.json()
    assert "balance" in data
    assert "balanceInEther" in data

# 9. Teste para consultar saúde financeira
@pytest.mark.asyncio
async def test_get_treasury_health(client):
    response = await client.get("/api/treasury/health")
    assert response.status_code == 200
    data = response.json()
    assert "reserveRatio" in data
    assert "insurancePool" in data
    assert "capitalPool" in data

# 10. Teste para adicionar capital à tesouraria
@pytest.mark.asyncio
async def test_add_capital(client):
    response = await client.post("/api/treasury/capital", json={"amount": AMOUNT})
    assert response.status_code == 200
    data = response.json()
    assert "success" in data
    assert data["success"] is True
    assert "transactionHash" in data

# 11. Teste para criar proposta de governança
# @pytest.mark.asyncio
# async def test_create_proposal(client):
#     response = await client.post("/api/governance/proposals", json={
#         "description": "Test Proposal",
#         "targetContract": VALID_FARMER_ADDRESS,
#         "callData": "0x"
#     })
#     assert response.status_code == 200
#     data = response.json()
#     assert "proposalId" in data or "success" in data
#     if "transactionHash" in data:
#         assert isinstance(data["transactionHash"], str)

# 12. Teste para votar em proposta
@pytest.mark.asyncio
async def test_vote_proposal(client):
    response = await client.post("/api/governance/proposals/1/vote", json={"support": True})
    assert response.status_code == 200
    data = response.json()
    assert "success" in data
    assert data["success"] is True
    assert "transactionHash" in data

# 13. Teste para consultar proposta
@pytest.mark.asyncio
async def test_get_proposal_details(client):
    response = await client.get("/api/governance/proposals/1")
    assert response.status_code == 200
    data = response.json()
    assert "id" in data
    assert "proposer" in data
    assert "description" in data

@pytest.mark.asyncio
async def test_get_proposal_details_not_found(client):
    response = await client.get("/api/governance/proposals/9999")
    assert response.status_code == 404
    data = response.json()
    assert "detail" in data

# 14. Teste para executar proposta
@pytest.mark.asyncio
async def test_execute_proposal(client):
    response = await client.post("/api/governance/proposals/1/execute")
    assert response.status_code == 200
    data = response.json()
    assert "success" in data
    assert data["success"] is True
    assert "transactionHash" in data

# 15. Teste para consultar saldo de tokens
@pytest.mark.asyncio
async def test_get_token_balance(client):
    response = await client.get(f"/api/users/{VALID_FARMER_ADDRESS}/tokens")
    assert response.status_code == 200
    data = response.json()
    assert "balance" in data
    assert "formattedBalance" in data
    assert "tokenName" in data
    assert "tokenSymbol" in data

@pytest.mark.asyncio
async def test_get_token_balance_invalid_address(client):
    response = await client.get(f"/api/users/{INVALID_FARMER_ADDRESS}/tokens")
    assert response.status_code == 400
    data = response.json()
    assert "detail" in data

# 16. Teste para adicionar região suportada
@pytest.mark.asyncio
async def test_add_region(client):
    response = await client.post("/api/admin/regions", json={"region": REGION})
    assert response.status_code == 200
    data = response.json()
    assert "success" in data
    assert data["success"] is True
    assert "transactionHash" in data

# 17. Teste para adicionar cultura suportada
@pytest.mark.asyncio
async def test_add_crop(client):
    response = await client.post("/api/admin/crops", json={"crop": CROP_TYPE})
    assert response.status_code == 200
    data = response.json()
    assert "success" in data
    assert data["success"] is True
    assert "transactionHash" in data

# 18. Teste para configurar oráculos regionais
@pytest.mark.asyncio
async def test_set_regional_oracle(client):
    response = await client.post("/api/admin/oracles", json={"region": REGION, "oracleAddress": VALID_FARMER_ADDRESS})
    assert response.status_code == 200
    data = response.json()
    assert "success" in data
    assert data["success"] is True
    assert "transactionHash" in data

@pytest.mark.asyncio
async def test_set_regional_oracle_invalid_address(client):
    response = await client.post("/api/admin/oracles", json={"region": REGION, "oracleAddress": INVALID_FARMER_ADDRESS})
    assert response.status_code == 400
    data = response.json()
    assert "detail" in data

# 19. Teste para consultar status da apólice
@pytest.mark.asyncio
async def test_get_policy_status(client, setup_policy):
    response = await client.get(f"/api/policies/{POLICY_ID}/status")
    assert response.status_code == 200
    data = response.json()
    assert "policyId" in data
    assert "active" in data
    assert "claimed" in data

@pytest.mark.asyncio
async def test_get_policy_status_not_found(client):
    response = await client.get("/api/policies/9999/status")
    assert response.status_code == 404
    data = response.json()
    assert "detail" in data

# 20. Teste para transferir tokens
@pytest.mark.asyncio
async def test_transfer_tokens(client):
    response = await client.post(f"/api/users/{VALID_FARMER_ADDRESS}/tokens/transfer", json={"amount": AMOUNT})
    assert response.status_code == 200
    data = response.json()
    assert "success" in data
    assert data["success"] is True
    assert "transactionHash" in data

@pytest.mark.asyncio
async def test_transfer_tokens_invalid_address(client):
    response = await client.post(f"/api/users/{INVALID_FARMER_ADDRESS}/tokens/transfer", json={"amount": AMOUNT})
    assert response.status_code == 400
    data = response.json()
    assert "detail" in data

# 21. Teste para obter todas as apólices de um fazendeiro
@pytest.mark.asyncio
async def test_get_farmer_policies(client, setup_policy):
    response = await client.get(f"/api/farmers/{VALID_FARMER_ADDRESS}/policies")
    assert response.status_code == 200
    data = response.json()
    assert "address" in data
    assert "policies" in data
    assert isinstance(data["policies"], list)

@pytest.mark.asyncio
async def test_get_farmer_policies_invalid_address(client):
    response = await client.get(f"/api/farmers/{INVALID_FARMER_ADDRESS}/policies")
    assert response.status_code == 400
    data = response.json()
    assert "detail" in data

# 22. Teste para obter regiões suportadas
@pytest.mark.asyncio
async def test_get_supported_regions(client):
    response = await client.get("/api/regions")
    assert response.status_code == 200
    data = response.json()
    assert "regions" in data
    assert isinstance(data["regions"], list)

# 23. Teste para obter culturas suportadas
@pytest.mark.asyncio
async def test_get_supported_crops(client):
    response = await client.get("/api/crops")
    assert response.status_code == 200
    data = response.json()
    assert "crops" in data
    assert isinstance(data["crops"], list)

# 24. Teste para dashboard - estatísticas do sistema
@pytest.mark.asyncio
async def test_get_system_stats(client):
    response = await client.get("/api/dashboard/stats")
    assert response.status_code == 200
    data = response.json()
    assert "totalPolicies" in data
    assert "activePolicies" in data
    assert "treasuryBalance" in data
    assert "reserveRatio" in data

# 25. Teste para obter clima atual para uma região
@pytest.mark.asyncio
async def test_get_current_weather(client, mocker):
    mocker.patch("services.openweather.fetch_climate_data", return_value={"rainfall": 100})
    response = await client.get(f"/api/weather/{REGION}")
    assert response.status_code == 200
    data = response.json()
    assert "region" in data
    assert "rainfall" in data

# 26. Teste para status geral da API e contratos
@pytest.mark.asyncio
async def test_get_api_status(client):
    response = await client.get("/api/status")
    assert response.status_code == 200
    data = response.json()
    assert "api" in data
    assert "blockchain" in data
    assert "contracts" in data
    assert data["api"]["status"] == "online"