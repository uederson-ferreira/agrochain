
![Image](https://github.com/user-attachments/assets/7245710b-05d3-44dc-8ba8-38fac28ee0bc)
# AgroChain – Parametric Agricultural Insurance Platform
#### Teach Lead: Patrícia Sirvarolli
https://github.com/psirvarolli
#### Front-end: Felipe Vieira
https://github.com/Felipe-WillianV
#### Back-enc: Uederson Ferreira
https://github.com/uederson-ferreira
#### Product Manager: José Franco
https://github.com/josemvfranco

**AgroChain** is a **decentralized** parametric agricultural insurance platform, built with **smart contracts in Solidity**, using proofs generated in **Zero-Knowledge Proof** by **ZK Verify**, and a **Python API**. Using **real-time weather data** (OpenWeather API + Chainlink Oracle), the application automates **policies, payments and token-based governance**.

> 🚀 Transparent. Fast. No bureaucracy.

---

## 🧭 Overview

We seek to solve the problem as: 

- Protect the investment made in each harvest; 
- Get immediate payments when there are adverse weather events;
- Reduce bureaucracy and time to receive compensation;
- Have predictability about when and how much you will receive in the event of a claim;
- Ensure long-term financial sustainability of the business.

#### A AgroChain is composed of:

* 🧠 **Smart Contracts**:
  `AgroChainInsurance`, `PolicyNFT`, `AgroChainOracle`, `AgroChainTreasury`, `AgroChainGovernance`, `AgroChainToken`.

* 🖥️ **Backend**:
  API FastAPI localizada em `src/main.py`.

* ✅ **Automated Tests**:
  Arquivos em `src/tests/test_routes.py`.

---

## ⚙️ Prerequisites

Have the following components installed:

* 📦 Node.js `v16+` & `npm` (for Anvil)

* 🐍 Python `v3.10+` & `pip`

* 🧱 Foundry
  Instal with:

  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

* 🔁 Anvil

  ```bash
  npm install -g @foundry-rs/foundry
  ```

* 🧬 Git

* ☁️ **API OpenWeather Key**
  → Create your account at [openweathermap.org](https://openweathermap.org/)

---

## 📁 Project Structure

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
└── README_en.md
```

---

## 🚀 Installation

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/seu-usuario/agrochain.git
cd agrochain
```

### 2️⃣ Configure the Python Environment (Backend)

```bash
cd backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

> 🔧 If necessary, create `requirements.txt` with:

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

### 3️⃣ Configure the `.env`

In the `backend/` directory, create a `.env` file with:

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

### 4️⃣ Compile and Deploy Contracts

```bash
cd smart-contracts/seguroagrochain
forge build
anvil
```

Then, in another terminal:

```bash
forge script script/Deploy.s.sol \
--rpc-url http://127.0.0.1:8545 \
--private-key 0xSEU_PRIVATE_KEY \
--broadcast
```

📌 Copy the addresses of the contracts and update the `.env`.

---

### 5️⃣ Start the Backend

```bash
cd ../../backend
uvicorn src.main:app --reload
```

🔗 Access: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

---

## 🧪 Automated Tests

Make sure:

* Anvil is running ✅
* Contracts have been deployed ✅

Then run:

```bash
pytest src/tests/test_routes.py -v
```

---

## 🔌 Using the API – Main Endpoints

📚 Access the interactive documentation:
[http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)

### 📝 Create Policy

```http
POST /api/policies
```

#### Body

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

### 🌦️ Consult Climate Data

```http
GET /api/weather/marabá
```

---

### 💰 Check Treasury Balance

```http
GET /treasury/balance
```

---

### Others

* `/api/policies/{id}/nft` → Policy NFT Metadata
* `/governance/proposals` → Proposal creation
* `/admin/regions` → Add regions
---

## 🔧 Advanced Configuration

### 🔗 Chainlink (Sepolia)

Update `Deploy.s.sol`:

```solidity
chainlinkToken = "0x514910771AF9Ca656af840dff83E8264EcF986CA";
chainlinkOracle = "0xSEU_ORACLE_ADDRESS";
chainlinkJobId = "SEU_JOB_ID";
chainlinkFee = 0.1 ether;
```

---

### 🌍 Add Regions and Cultures

```bash
curl -X POST http://127.0.0.1:8000/admin/regions \
-H "Content-Type: application/json" \
-d '{"region": "marabá"}'
```

---

## 🛠️ Troubleshooting

### ❌ 404 Routes

* Check the addresses in `.env`
* Check if the compilation generated files in `out/`

### 🧪 Tests Failed??

```bash
pip install pytest-mock
forge build
```

---

## 🤝 Contribute

1. Fork 🍴
2. Create a branch

```bash
git checkout -b feature/sua-funcionalidade
```

3. Commit

```bash
git commit -m "feat: nova funcionalidade"
```

4. Submit a PR 🚀

---

## 📜 License

MIT License – read [LICENSE](./LICENSE) for details.
