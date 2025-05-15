### Visão Geral do Sistema AgroChain

O AgroChain é uma plataforma de seguro paramétrico agrícola com as seguintes funcionalidades principais:

- **Criação e gerenciamento de apólices**: Usuários (agricultores) criam, ativam, cancelam apólices e solicitam sinistros baseados em dados climáticos.
- **Integração com oráculos**: Dados climáticos são obtidos via `AgroChainOracle` (integrado com Chainlink).
- **Tesouraria**: Gerencia prêmios, sinistros, reembolsos e indicadores financeiros.
- **Governança**: Permite propostas e votação para alterações de parâmetros (ex.: taxas de reserva).
- **NFTs**: Apólices são representadas como tokens ERC721 (`PolicyNFT`), permitindo negociação em mercados secundários.

Com base nisso, o backend deve expor APIs para interagir com os contratos, enquanto o frontend deve oferecer uma interface amigável para agricultores, investidores e administradores.

---

### 1. **Interfaces do Backend (APIs)**

O backend em Python será responsável por:

- Interagir com os contratos na blockchain usando **Web3.py**.
- Assinar transações (ex.: para criar apólices ou votar em propostas).
- Escutar eventos dos contratos (ex.: `PolicyCreated`, `ClaimTriggered`) para atualizar o estado.
- Fornecer APIs REST para o frontend (usando um framework como **FastAPI**).
- Opcionalmente, armazenar dados off-chain (ex.: detalhes de apólices, históricos de eventos) em um banco de dados como **PostgreSQL** para consultas rápidas.

Abaixo, listo as APIs recomendadas com base nas funções dos contratos. Cada API corresponde a uma interação com os contratos ou a uma funcionalidade de suporte.

#### **APIs do Backend**

##### **a) Apólices de Seguro (AgroChainInsurance.sol)**

1. **POST /policies**
   - **Descrição**: Criar uma nova apólice de seguro.
   - **Contrato**: `AgroChainInsurance.createPolicy`
   - **Parâmetros**:
     - `farmer` (string): Endereço do agricultor.
     - `coverageAmount` (number): Valor da cobertura (em wei).
     - `startDate` (number): Timestamp de início.
     - `endDate` (number): Timestamp de término.
     - `region` (string): Região geográfica (ex.: "Bahia").
     - `cropType` (string): Tipo de cultura (ex.: "Soja").
     - `parameters` (array): Lista de parâmetros climáticos (ex.: `{parameterType: "rainfall", thresholdValue: 50000, periodInDays: 180, triggerAbove: false, payoutPercentage: 5000}`).
   - **Retorno**: `{ policyId: number }`
   - **Eventos Monitorados**: `PolicyCreated`

2. **POST /policies/:policyId/activate**
   - **Descrição**: Ativar uma apólice enviando o prêmio.
   - **Contrato**: `AgroChainInsurance.activatePolicy`
   - **Parâmetros**:
     - `policyId` (number): ID da apólice.
     - `premium` (number): Valor do prêmio (em wei).
   - **Retorno**: `{ success: boolean, transactionHash: string }`
   - **Eventos Monitorados**: `PolicyActivated`

3. **POST /policies/:policyId/climate-data**
   - **Descrição**: Solicitar dados climáticos para uma apólice.
   - **Contrato**: `AgroChainInsurance.requestClimateData`
   - **Parâmetros**:
     - `policyId` (number): ID da apólice.
     - `parameterType` (string): Tipo de parâmetro (ex.: "rainfall").
   - **Retorno**: `{ requestId: string }`
   - **Eventos Monitorados**: `ClimateDataRequested`

4. **GET /policies/:policyId**
   - **Descrição**: Obter detalhes de uma apólice.
   - **Contrato**: `AgroChainInsurance.getPolicyDetails`
   - **Parâmetros**:
     - `policyId` (number): ID da apólice.
   - **Retorno**: `{ id: number, farmer: string, coverageAmount: number, premium: number, startDate: number, endDate: number, active: boolean, claimed: boolean, claimPaid: number, region: string, cropType: string, parameters: array }`

5. **GET /policies/:policyId/status**
   - **Descrição**: Obter o status de uma apólice.
   - **Contrato**: `AgroChainInsurance.getPolicyStatus`
   - **Parâmetros**:
     - `policyId` (number): ID da apólice.
   - **Retorno**: `{ active: boolean, claimed: boolean, claimPaid: number, remainingCoverage: number, timeRemaining: number }`

6. **POST /policies/:policyId/cancel**
   - **Descrição**: Cancelar uma apólice e obter reembolso.
   - **Contrato**: `AgroChainInsurance.cancelPolicy`
   - **Parâmetros**:
     - `policyId` (number): ID da apólice.
   - **Retorno**: `{ refundAmount: number }`
   - **Eventos Monitorados**: `PolicyCancelled`

##### **b) NFTs (PolicyNFT.sol)**

7. **GET /policies/:policyId/nft**
   - **Descrição**: Obter metadados do NFT associado a uma apólice.
   - **Contrato**: `PolicyNFT.getMetadata`
   - **Parâmetros**:
     - `policyId` (number): ID da apólice.
   - **Retorno**: `{ region: string, cropType: string, coverageAmount: number, startDate: number, endDate: number, premium: number, climateParameters: string }`

8. **GET /policies/:policyId/nft/token-uri**
   - **Descrição**: Obter o URI do token NFT (metadados em JSON).
   - **Contrato**: `PolicyNFT.tokenURI`
   - **Parâmetros**:
     - `policyId` (number): ID da apólice.
   - **Retorno**: `{ tokenUri: string }`

##### **c) Oráculo (AgroChainOracle.sol)**

9. **GET /oracle/requests/:requestId**
   - **Descrição**: Obter o status de uma solicitação de dados climáticos.
   - **Contrato**: `AgroChainOracle.getRequestStatus`
   - **Parâmetros**:
     - `requestId` (string): ID da solicitação.
   - **Retorno**: `{ fulfilled: boolean, value: number, responseCount: number }`

10. **GET /oracle/historical-data**
    - **Descrição**: Obter dados climáticos históricos.
    - **Contrato**: `AgroChainOracle.getHistoricalData`
    - **Parâmetros**:
      - `region` (string): Região.
      - `parameterType` (string): Tipo de parâmetro.
      - `timestamp` (number): Timestamp.
    - **Retorno**: `{ value: number }`

##### **d) Tesouraria (AgroChainTreasury.sol)**

11. **GET /treasury/balance**
    - **Descrição**: Obter informações de saldo da tesouraria.
    - **Contrato**: `AgroChainTreasury.getBalanceInfo`
    - **Retorno**: `{ premiumPool: number, claimPool: number, yieldPool: number, totalBalance: number, totalClaims: number }`

12. **GET /treasury/health**
    - **Descrição**: Obter indicadores financeiros da tesouraria.
    - **Contrato**: `AgroChainTreasury.getFinancialHealth`
    - **Retorno**: `{ solvencyRatio: number, reserveRatio: number, liquidityRatio: number }`

13. **POST /treasury/capital**
    - **Descrição**: Adicionar capital à tesouraria (para investidores ou administradores).
    - **Contrato**: `AgroChainTreasury.addCapital`
    - **Parâmetros**:
      - `amount` (number): Valor em wei.
    - **Retorno**: `{ success: boolean, transactionHash: string }`
    - **Eventos Monitorados**: `CapitalAdded`

##### **e) Governança (ConcreteAgroChainGovernance.sol, AgroChainToken.sol)**

14. **POST /governance/proposals**
    - **Descrição**: Criar uma nova proposta de governança.
    - **Contrato**: `ConcreteAgroChainGovernance.createProposal`
    - **Parâmetros**:
      - `title` (string): Título da proposta.
      - `description` (string): Descrição.
      - `target` (string): Endereço do contrato alvo.
      - `value` (number): Valor em wei (se aplicável).
      - `data` (string): Dados codificados da chamada (ex.: `abi.encodeWithSignature`).
    - **Retorno**: `{ proposalId: number }`

15. **POST /governance/proposals/:proposalId/vote**
    - **Descrição**: Votar em uma proposta.
    - **Contrato**: `ConcreteAgroChainGovernance.castVote`
    - **Parâmetros**:
      - `proposalId` (number): ID da proposta.
      - `support` (boolean): Voto a favor (`true`) ou contra (`false`).
    - **Retorno**: `{ success: boolean, transactionHash: string }`

16. **GET /governance/proposals/:proposalId**
    - **Descrição**: Obter detalhes de uma proposta.
    - **Contrato**: `ConcreteAgroChainGovernance.getProposalDetails`
    - **Parâmetros**:
      - `proposalId` (number): ID da proposta.
    - **Retorno**: `{ title: string, description: string, proposer: string, createdAt: number, votingEndsAt: number, executed: boolean, canceled: boolean, forVotes: number, againstVotes: number, status: string }`

17. **POST /governance/proposals/:proposalId/execute**
    - **Descrição**: Executar uma proposta aprovada após o timelock.
    - **Contrato**: `ConcreteAgroChainGovernance.executeProposal`
    - **Parâmetros**:
      - `proposalId` (number): ID da proposta.
    - **Retorno**: `{ success: boolean, transactionHash: string }`

18. **GET /users/:address/tokens**
    - **Descrição**: Obter o saldo de tokens de governança de um usuário.
    - **Contrato**: `AgroChainToken.balanceOf`
    - **Parâmetros**:
      - `address` (string): Endereço do usuário.
    - **Retorno**: `{ balance: number }`

##### **f) Configurações Administrativas**

19. **POST /admin/regions**
    - **Descrição**: Adicionar uma região suportada (apenas administrador).
    - **Contrato**: `AgroChainInsurance.addSupportedRegion`
    - **Parâmetros**:
      - `region` (string): Nome da região.
    - **Retorno**: `{ success: boolean, transactionHash: string }`

20. **POST /admin/crops**
    - **Descrição**: Adicionar uma cultura suportada (apenas administrador).
    - **Contrato**: `AgroChainInsurance.addSupportedCrop`
    - **Parâmetros**:
      - `crop` (string): Nome da cultura.
    - **Retorno**: `{ success: boolean, transactionHash: string }`

21. **POST /admin/oracles**
    - **Descrição**: Configurar oráculos para uma região (apenas administrador).
    - **Contrato**: `AgroChainInsurance.setRegionalOracles`
    - **Parâmetros**:
      - `region` (string): Região.
      - `oracles` (array): Lista de endereços de oráculos.
    - **Retorno**: `{ success: boolean, transactionHash: string }`

#### **Exemplo de Código do Backend (Python com FastAPI e Web3.py)**

Abaixo, um exemplo de implementação de algumas APIs usando **FastAPI** e **Web3.py**, rodando em uma blockchain local (ex.: Anvil).

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from web3 import Web3
import json
from typing import List

app = FastAPI()

# Configuração do Web3
w3 = Web3(Web3.HTTPProvider("http://127.0.0.1:8545"))
admin_private_key = "sua-chave-privada-do-anvil"  # Substitua pela chave do Anvil
admin_address = w3.eth.account.from_key(admin_private_key).address

# Carregar ABI dos contratos (gerado por `forge build`)
with open("out/AgroChainInsurance.sol/AgroChainInsurance.json") as f:
    insurance_abi = json.load(f)["abi"]
insurance_contract = w3.eth.contract(address="endereço-do-contrato", abi=insurance_abi)

# Modelos Pydantic para validação
class ClimateParameter(BaseModel):
    parameterType: str
    thresholdValue: int
    periodInDays: int
    triggerAbove: bool
    payoutPercentage: int

class CreatePolicyRequest(BaseModel):
    farmer: str
    coverageAmount: int
    startDate: int
    endDate: int
    region: str
    cropType: str
    parameters: List[ClimateParameter]

# API para criar apólice
@app.post("/policies")
async def create_policy(request: CreatePolicyRequest):
    try:
        # Validar endereço
        if not w3.is_address(request.farmer):
            raise HTTPException(status_code=400, detail="Invalid farmer address")

        # Preparar parâmetros climáticos
        parameters = [
            {
                "parameterType": p.parameterType,
                "thresholdValue": p.thresholdValue,
                "periodInDays": p.periodInDays,
                "triggerAbove": p.triggerAbove,
                "payoutPercentage": p.payoutPercentage
            } for p in request.parameters
        ]

        # Construir transação
        tx = insurance_contract.functions.createPolicy(
            request.farmer,
            request.coverageAmount,
            request.startDate,
            request.endDate,
            request.region,
            request.cropType,
            parameters
        ).build_transaction({
            "from": admin_address,
            "nonce": w3.eth.get_transaction_count(admin_address),
            "gas": 2000000,
            "gasPrice": w3.to_wei("20", "gwei")
        })

        # Assinar e enviar transação
        signed_tx = w3.eth.account.sign_transaction(tx, admin_private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

        # Encontrar evento PolicyCreated
        for event in receipt["logs"]:
            if event["topics"][0].hex() == w3.keccak(text="PolicyCreated(uint256,address,uint256,string)").hex():
                policy_id = int(event["data"][:66], 16)
                return {"policyId": policy_id}

        raise HTTPException(status_code=500, detail="PolicyCreated event not found")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# API para obter detalhes da apólice
@app.get("/policies/{policy_id}")
async def get_policy_details(policy_id: int):
    try:
        policy, parameters = insurance_contract.functions.getPolicyDetails(policy_id).call()
        return {
            "id": policy[0],
            "farmer": policy[1],
            "coverageAmount": policy[2],
            "premium": policy[3],
            "startDate": policy[4],
            "endDate": policy[5],
            "active": policy[6],
            "claimed": policy[7],
            "claimPaid": policy[8],
            "region": policy[11],
            "cropType": policy[12],
            "parameters": [
                {
                    "parameterType": p[0],
                    "thresholdValue": p[1],
                    "periodInDays": p[2],
                    "triggerAbove": p[3],
                    "payoutPercentage": p[4]
                } for p in parameters
            ]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

**Pré-requisitos**:

- Instale as dependências:

  ```bash
  pip install fastapi uvicorn web3 pydantic
  ```

- Rode uma blockchain local com Anvil:

  ```bash
  anvil
  ```

- Implante os contratos localmente com `forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --private-key <chave-do-anvil> --broadcast`.
- Atualize o endereço do contrato e a chave privada no código.

**Executar o Backend**:

```bash
uvicorn main:app --reload
```

Acesse `http://127.0.0.1:8000/docs` para testar as APIs.

---

### 2. **Interfaces do Frontend**

O frontend será a interface para os usuários (agricultores, investidores, administradores) interagirem com o sistema AgroChain. Ele deve:

- Conectar-se a uma carteira Ethereum (ex.: MetaMask) para assinar transações.
- Fazer chamadas HTTP às APIs do backend.
- Exibir informações como detalhes de apólices, status de sinistros, propostas de governança, e metadados de NFTs.
- Opcionalmente, integrar com mercados NFT (ex.: OpenSea) para negociar apólices.

#### **Interfaces do Frontend**

##### **a) Para Agricultores**

1. **Criar Apólice**
   - **Descrição**: Formulário para criar uma apólice.
   - **API**: `POST /policies`
   - **Componentes**:
     - Campos: Endereço do agricultor (pré-preenchido com MetaMask), valor da cobertura, datas de início/término, região, tipo de cultura, parâmetros climáticos.
     - Botão para submeter (assina transação via MetaMask).
   - **Exibição**: Confirmação com ID da apólice.

2. **Ativar Apólice**
   - **Descrição**: Interface para pagar o prêmio e ativar a apólice.
   - **API**: `POST /policies/:policyId/activate`
   - **Componentes**:
     - Seleção da apólice (lista de apólices do usuário).
     - Campo para confirmar o valor do prêmio.
     - Botão para ativar (envia ETH via MetaMask).
   - **Exibição**: Status de ativação.

3. **Solicitar Dados Climáticos**
   - **Descrição**: Solicitar dados climáticos para verificar sinistros.
   - **API**: `POST /policies/:policyId/climate-data`
   - **Componentes**:
     - Seleção da apólice e tipo de parâmetro (ex.: "rainfall").
     - Botão para solicitar.
   - **Exibição**: ID da solicitação e status.

4. **Consultar Apólice**
   - **Descrição**: Visualizar detalhes e status de uma apólice.
   - **APIs**: `GET /policies/:policyId`, `GET /policies/:policyId/status`
   - **Componentes**:
     - Lista de apólices do usuário (filtrável por status: ativa, expirada, etc.).
     - Detalhes: Cobertura, prêmio, datas, região, cultura, status (ativo, reivindicado, etc.).
   - **Exibição**: Tabela ou cartão com informações.

5. **Cancelar Apólice**
   - **Descrição**: Cancelar uma apólice e receber reembolso.
   - **API**: `POST /policies/:policyId/cancel`
   - **Componentes**:
     - Seleção da apólice.
     - Botão para cancelar (assina transação via MetaMask).
   - **Exibição**: Valor do reembolso.

6. **Visualizar NFT**
   - **Descrição**: Exibir o NFT associado à apólice.
   - **APIs**: `GET /policies/:policyId/nft`, `GET /policies/:policyId/nft/token-uri`
   - **Componentes**:
     - Visualização dos metadados (região, cultura, cobertura, etc.).
     - Link para mercado NFT (ex.: OpenSea, se na testnet/mainnet).
   - **Exibição**: Cartão com imagem/metadados do NFT.

##### **b) Para Investidores**

7. **Adicionar Capital**
   - **Descrição**: Contribuir com capital para a tesouraria.
   - **API**: `POST /treasury/capital`
   - **Componentes**:
     - Campo para valor do capital (em ETH).
     - Botão para contribuir (envia ETH via MetaMask).
   - **Exibição**: Confirmação da transação.

8. **Consultar Tesouraria**
   - **Descrição**: Visualizar saldos e saúde financeira da tesouraria.
   - **APIs**: `GET /treasury/balance`, `GET /treasury/health`
   - **Componentes**:
     - Gráficos ou tabelas com pools (prêmios, sinistros, rendimentos), ratios financeiros (solvência, reserva, liquidez).
   - **Exibição**: Painel financeiro.

##### **c) Para Governança**

9. **Criar Proposta**
   - **Descrição**: Criar uma proposta de governança.
   - **API**: `POST /governance/proposals`
   - **Componentes**:
     - Campos: Título, descrição, contrato alvo, valor, dados codificados.
     - Botão para submeter (assina transação via MetaMask).
   - **Exibição**: ID da proposta.

10. **Votar em Proposta**
    - **Descrição**: Votar a favor ou contra uma proposta.
    - **API**: `POST /governance/proposals/:proposalId/vote`
    - **Componentes**:
      - Lista de propostas ativas (com título, descrição, status).
      - Botões para votar "a favor" ou "contra" (assina transação).
    - **Exibição**: Confirmação do voto.

11. **Consultar Propostas**
    - **Descrição**: Visualizar detalhes de propostas.
    - **API**: `GET /governance/proposals/:proposalId`
    - **Componentes**:
      - Lista de propostas (filtrável por status: ativa, aprovada, executada, etc.).
      - Detalhes: Título, descrição, votos, status.
    - **Exibição**: Tabela ou cartões.

12. **Executar Proposta**
    - **Descrição**: Executar uma proposta aprovada após o timelock.
    - **API**: `POST /governance/proposals/:proposalId/execute`
    - **Componentes**:
      - Botão para executar (aparece apenas para propostas prontas).
    - **Exibição**: Confirmação da execução.

13. **Consultar Saldo de Tokens**
    - **Descrição**: Verificar o saldo de tokens de governança.
    - **API**: `GET /users/:address/tokens`
    - **Componentes**:
      - Exibição do saldo na interface do usuário.
    - **Exibição**: Campo com saldo.

##### **d) Para Administradores**

14. **Gerenciar Regiões**
    - **Descrição**: Adicionar regiões suportadas.
    - **API**: `POST /admin/regions`
    - **Componentes**:
      - Campo para nome da região.
      - Botão para adicionar (assina transação via MetaMask).
    - **Exibição**: Lista de regiões suportadas.

15. **Gerenciar Culturas**
    - **Descrição**: Adicionar culturas suportadas.
    - **API**: `POST /admin/crops`
    - **Componentes**:
      - Campo para nome da cultura.
      - Botão para adicionar (assina transação).
    - **Exibição**: Lista de culturas suportadas.

16. **Configurar Oráculos**
    - **Descrição**: Definir oráculos para uma região.
    - **API**: `POST /admin/oracles`
    - **Componentes**:
      - Campos para região e lista de endereços de oráculos.
      - Botão para configurar (assina transação).
    - **Exibição**: Lista de oráculos por região.

##### **e) Gerais**

17. **Dashboard**
    - **Descrição**: Visão geral do sistema.
    - **APIs**: `GET /policies/:policyId/status`, `GET /treasury/balance`, `GET /treasury/health`, `GET /governance/proposals/:proposalId`
    - **Componentes**:
      - Resumo de apólices ativas, saldo da tesouraria, propostas recentes.
      - Gráficos de saúde financeira e exposição a riscos.
    - **Exibição**: Painel com widgets.

18. **Histórico de Dados Climáticos**
    - **Descrição**: Visualizar dados climáticos históricos.
    - **API**: `GET /oracle/historical-data`
    - **Componentes**:
      - Filtros para região, parâmetro e período.
      - Gráfico ou tabela com valores históricos.
    - **Exibição**: Visualização de dados.

#### **Tecnologias Sugeridas para o Frontend**

- **Framework**: React, Vue.js ou Angular.
- **Biblioteca Web3**: **Ethers.js** ou **Web3.js** para conectar ao MetaMask e assinar transações.
- **HTTP Client**: Axios ou Fetch para chamar as APIs do backend.
- **UI Library**: Material-UI, Ant Design ou Chakra UI para componentes visuais.
- **Gráficos**: Chart.js ou D3.js para visualizações (ex.: saúde financeira, dados climáticos).
- **Integração com NFT**: Use APIs de mercados como OpenSea (na testnet/mainnet) para exibir/traduzir NFTs.

**Exemplo de Conexão com MetaMask (React)**:

```javascript
import { ethers } from "ethers";
import { useState } from "react";

function CreatePolicy() {
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);

  const connectWallet = async () => {
    if (window.ethereum) {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      setProvider(provider);
      setSigner(signer);
    } else {
      alert("Please install MetaMask!");
    }
  };

  const createPolicy = async () => {
    const response = await fetch("http://127.0.0.1:8000/policies", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        farmer: await signer.getAddress(),
        coverageAmount: ethers.parseEther("10").toString(),
        startDate: Math.floor(Date.now() / 1000) + 86400,
        endDate: Math.floor(Date.now() / 1000) + 86400 * 180,
        region: "Bahia",
        cropType: "Soja",
        parameters: [
          {
            parameterType: "rainfall",
            thresholdValue: 50000,
            periodInDays: 180,
            triggerAbove: false,
            payoutPercentage: 5000
          }
        ]
      })
    });
    const { policyId } = await response.json();
    alert(`Policy created with ID: ${policyId}`);
  };

  return (
    <div>
      <button onClick={connectWallet}>Connect Wallet</button>
      <button onClick={createPolicy}>Create Policy</button>
    </div>
  );
}
```

---

### 3. **Plano de Desenvolvimento**

1. **Configurar o Backend**:
   - Instale **FastAPI**, **Web3.py**, e outras dependências.
   - Configure uma blockchain local com **Anvil** e implante os contratos com `Deploy.s.sol`.
   - Implemente as APIs sugeridas, começando com as de apólices (`/policies`, `/policies/:policyId`, etc.).
   - Use um banco de dados (ex.: PostgreSQL) para armazenar eventos e estados off-chain.

2. **Desenvolver o Frontend**:
   - Configure um projeto React/Vue.js com Ethers.js.
   - Crie páginas para:
     - Dashboard (resumo do sistema).
     - Gerenciamento de apólices (criar, ativar, cancelar).
     - Visualização de NFTs.
     - Governança (criar/votar em propostas).
     - Administração (gerenciar regiões, culturas, oráculos).
   - Integre com MetaMask para assinar transações.

3. **Testar Localmente**:
   - Teste o backend com ferramentas como **Postman** ou a interface do FastAPI (`/docs`).
   - Teste o frontend conectando-o ao backend local e à blockchain Anvil.
   - Simule fluxos completos (ex.: criar apólice → ativar → solicitar dados → processar sinistro).

4. **Implantar em Testnet**:
   - Quando o backend e frontend estiverem funcionais, implante os contratos em uma testnet (ex.: Sepolia) usando `Deploy.s.sol`.
   - Atualize o backend para usar o `RPC_URL` da testnet e configure a integração com Chainlink.
   - Teste o frontend com carteiras reais (MetaMask) na testnet.

---

### 4. **Respostas Diretas**

- **Quais interfaces do backend devo precisar?** As 21 APIs listadas cobrem todas as funcionalidades dos contratos: gerenciamento de apólices, NFTs, oráculos, tesouraria, governança, e administração.
- **Quais interfaces do frontend devo precisar?** As 18 interfaces sugeridas incluem criação/gerenciamento de apólices, visualização de NFTs, interação com governança, consulta de tesouraria, e administração, com integração com MetaMask.
- **Como fazer o backend em Python?** Use **FastAPI** e **Web3.py**, como no exemplo fornecido. Comece com APIs de apólices e expanda para outras funcionalidades.
