![Image](https://github.com/user-attachments/assets/7245710b-05d3-44dc-8ba8-38fac28ee0bc)
# AgroChain – Plataforma de Seguro Agrícola Paramétrico
#### Teach Lead: Patrícia Sirvarolli ####
https://github.com/psirvarolli
#### Front-end: Felipe ####
https://github.com/Felipe-WillianV
#### Back-enc: Uederson Ferreira####
https://github.com/uederson-ferreira
#### Product Manager: José Franco####
https://github.com/josemvfranco

**AgroChain** é uma plataforma **descentralizada** de seguros agrícolas paramétricos, construída com **contratos inteligentes em Solidity**, utilizando provas geradas em **ZK Proof**, e uma **API em Python**. Utiliza **dados climáticos em tempo real** (OpenWeather API + Chainlink Oracle), a aplicação automatiza **apólices, pagamentos e governança baseada em tokens**.

> 🚀 Transparente. Rápido. Sem burocracia.

---

## 🧭 Visão Geral

Buscamos solucionar dores como: 

 Proteger o investimento feito em cada safra; 
 Obter pagamentos imediatos quando há eventos climáticos adversos;
 Reduzir burocracia e tempo para recebimento de indenizações;
 Ter previsibilidade sobre quando e quanto receberá em caso de sinistro;
 Garantir sustentabilidade financeira do negócio a longo prazo.

#### A AgroChain é composta por:

* 🧠 **Contratos Inteligentes**:
  `AgroChainInsurance`, `PolicyNFT`, `AgroChainOracle`, `AgroChainTreasury`, `AgroChainGovernance`, `AgroChainToken`.

* 🖥️ **Backend**:
  API FastAPI localizada em `src/main.py`.

* ✅ **Testes Automatizados**:
  Arquivos em `src/tests/test_routes.py`.

---

## ⚙️ Pré-requisitos

Tenha os seguintes componentes instalados:

* 📦 Node.js `v16+` & `npm` (para o Anvil)

* 🐍 Python `v3.10+` & `pip`

* 🧱 Foundry
  Instale com:

  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

* 🔁 Anvil

  ```bash
  npm install -g @foundry-rs/foundry
  ```

* 🧬 Git

* ☁️ **Chave da API OpenWeather**
  → Crie sua conta em [openweathermap.org](https://openweathermap.org/)

---

## 📁 Estrutura do Projeto

```bash
agrochain/
├── backend/
│   └── src/
│       ├── main.py
│       ├── tests/test_routes.py
│       ├── utils/config.py
│       └── services/openweather.py
├── smart-contracts/
│   └── seguroagrochain/
│       ├── contracts/
│       │   ├── AgroChain*.sol
│       └── script/Deploy.s.sol
└── README.md
```

---

## 🚀 Instalação

### 1️⃣ Clone o Repositório

```bash
git clone https://github.com/seu-usuario/agrochain.git
cd agrochain
```

### 2️⃣ Configure o Ambiente Python (Backend)

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

> 🔧 Se necessário, crie `requirements.txt` com:

```txt
fastapi==0.110.0
uvicorn==0.29.0
web3==6.15.0
python-dotenv==1.0.1
httpx==0.27.0
pytest==8.2.2
pytest-asyncio==0.24.0
pytest-mock==3.14.0
```

---

### 3️⃣ Configure o `.env`

No diretório `backend/`, crie um arquivo `.env` com:

```env
WEB3_PROVIDER_URL=http://127.0.0.1:8545
ADMIN_PRIVATE_KEY=0xSEU_PRIVATE_KEY
OPENWEATHER_API_KEY=sua-chave-openweather
INSURANCE_CONTRACT_ADDRESS=
ORACLE_CONTRACT_ADDRESS=
TREASURY_CONTRACT_ADDRESS=
GOVERNANCE_CONTRACT_ADDRESS=
TOKEN_CONTRACT_ADDRESS=
NFT_ADDRESS=
```

---

### 4️⃣ Compile e Implante os Contratos

```bash
cd smart-contracts/seguroagrochain
forge build
anvil
```

Depois, em outro terminal:

```bash
forge script script/Deploy.s.sol \
--rpc-url http://127.0.0.1:8545 \
--private-key 0xSEU_PRIVATE_KEY \
--broadcast
```

📌 Copie os endereços dos contratos e atualize o `.env`.

---

### 5️⃣ Inicie o Backend

```bash
cd ../../backend
uvicorn src.main:app --reload
```

🔗 Acesse: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

---

## 🧪 Testes Automatizados

Certifique-se de que:

* Anvil está rodando ✅
* Contratos foram implantados ✅

Então execute:

```bash
pytest src/tests/test_routes.py -v
```

---

## 🔌 Uso da API – Endpoints Principais

📚 Acesse a documentação interativa:
[http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

### 📝 Criar Apólice

```http
POST /api/policies
```

#### Corpo

```json
{
  "farmer": "0x...",
  "coverageAmount": 10000000000000000000,
  "startDate": 1747488000,
  "endDate": 1747747200,
  "region": "marabá",
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
}
```

---

### 🌦️ Consultar Dados Climáticos

```http
GET /api/weather/marabá
```

---

### 💰 Consultar Saldo da Tesouraria

```http
GET /treasury/balance
```

---

### Outros

* `/api/policies/{id}/nft` → Metadados do NFT da apólice
* `/governance/proposals` → Criação de propostas
* `/admin/regions` → Adicionar regiões

---

## 🔧 Configuração Avançada

### 🔗 Chainlink (Sepolia)

Atualize `Deploy.s.sol`:

```solidity
chainlinkToken = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
chainlinkOracle = "0xSEU_ORACLE_ADDRESS";
chainlinkJobId = "SEU_JOB_ID";
chainlinkFee = 0.1 ether;
```

---

### 🌍 Adicionar Regiões e Culturas

```bash
curl -X POST http://127.0.0.1:8000/admin/regions \
-H "Content-Type: application/json" \
-d '{"region": "marabá"}'
```

---

## 🛠️ Solução de Problemas

### ❌ 404 nas Rotas

* Verifique os endereços no `.env`
* Verifique se a compilação gerou arquivos em `out/`

### 🧪 Falha nos Testes?

```bash
pip install pytest-mock
forge build
```

---

## 🤝 Contribuição

1. Fork 🍴
2. Crie uma branch

```bash
git checkout -b feature/sua-funcionalidade
```

3. Commit

```bash
git commit -m "feat: nova funcionalidade"
```

4. Envie um PR 🚀

---

## 📜 Licença

MIT License – veja [LICENSE](./LICENSE) para detalhes.
