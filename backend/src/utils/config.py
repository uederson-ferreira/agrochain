import os
import json
from dotenv import load_dotenv
from web3 import Web3

current_dir = os.getcwd()
env_path = os.path.join(current_dir, '.env')

load_dotenv(env_path)

# Configuração de Web3
WEB3_PROVIDER_URL = os.getenv("WEB3_PROVIDER_URL", "http://127.0.0.1:8545")
w3 = Web3(Web3.HTTPProvider(WEB3_PROVIDER_URL))

# Removido o middleware geth_poa_middleware, pois o Anvil não requer PoA
# Se necessário para Sepolia, adicione com: w3.middleware_onion.add(construct_geth_poa_middleware())

# Verifica a conexão com a blockchain
if not w3.is_connected():
    raise ConnectionError(f"Não foi possível conectar à blockchain em {WEB3_PROVIDER_URL}. Verifique o WEB3_PROVIDER_URL no arquivo .env")

# Configura a conta de admin
admin_private_key = os.getenv("ADMIN_PRIVATE_KEY")
admin_address = w3.eth.account.from_key(admin_private_key).address

# Endereços dos contratos
INSURANCE_CONTRACT_ADDRESS = os.getenv("INSURANCE_CONTRACT_ADDRESS")
ORACLE_CONTRACT_ADDRESS = os.getenv("ORACLE_CONTRACT_ADDRESS")
TREASURY_CONTRACT_ADDRESS = os.getenv("TREASURY_CONTRACT_ADDRESS")
GOVERNANCE_CONTRACT_ADDRESS = os.getenv("GOVERNANCE_CONTRACT_ADDRESS")
TOKEN_CONTRACT_ADDRESS = os.getenv("TOKEN_CONTRACT_ADDRESS")
POLICY_NFT_ADDRESS = os.getenv("NFT_ADDRESS")  # Alinhado com o .env original

# Função para validar endereços
def validate_ethereum_address(address, name):
    """Valida um endereço Ethereum"""
    if not address or not isinstance(address, str) or not address.startswith('0x') or len(address) != 42:
        raise ValueError(f"Endereço inválido para {name}: {address}")
    return address

# Validar todos os endereços
validate_ethereum_address(INSURANCE_CONTRACT_ADDRESS, "Insurance Contract")
validate_ethereum_address(ORACLE_CONTRACT_ADDRESS, "Oracle Contract")
validate_ethereum_address(TREASURY_CONTRACT_ADDRESS, "Treasury Contract")
validate_ethereum_address(GOVERNANCE_CONTRACT_ADDRESS, "Governance Contract")
validate_ethereum_address(TOKEN_CONTRACT_ADDRESS, "Token Contract")
validate_ethereum_address(POLICY_NFT_ADDRESS, "PolicyNFT Contract")

# Função para carregar ABIs
def load_contract_abi(file_path):
    """Carrega o ABI do contrato do arquivo JSON gerado pela compilação"""
    possible_paths = [
        f"../../smart-contracts/seguroagrochain/out/{file_path}.sol/{file_path}.json",
        f"../smart-contracts/seguroagrochain/out/{file_path}.sol/{file_path}.json",
        f"../../smart-contracts/out/{file_path}.sol/{file_path}.json",
        f"../smart-contracts/out/{file_path}.sol/{file_path}.json"
    ]
    
    base_dir = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    absolute_paths = [
        os.path.join(base_dir, "smart-contracts", "seguroagrochain", "out", f"{file_path}.sol", f"{file_path}.json"),
        os.path.join(base_dir, "smart-contracts", "out", f"{file_path}.sol", f"{file_path}.json")
    ]
    possible_paths.extend(absolute_paths)
    
    for path in possible_paths:
        try:
            with open(path) as f:
                abi = json.load(f)
                if "abi" in abi:
                    return abi["abi"]
                raise KeyError("Chave 'abi' não encontrada no JSON")
        except (FileNotFoundError, json.JSONDecodeError, KeyError):
            continue
    
    raise FileNotFoundError(f"Não foi possível encontrar ou carregar o ABI para {file_path}. Caminhos tentados: {possible_paths}")

# Inicializa os contratos
try:
    insurance_contract = w3.eth.contract(
        address=INSURANCE_CONTRACT_ADDRESS,
        abi=load_contract_abi("AgroChainInsurance")
    )
    oracle_contract = w3.eth.contract(
        address=ORACLE_CONTRACT_ADDRESS,
        abi=load_contract_abi("AgroChainOracle")
    )
    treasury_contract = w3.eth.contract(
        address=TREASURY_CONTRACT_ADDRESS,
        abi=load_contract_abi("AgroChainTreasury")
    )
    governance_contract = w3.eth.contract(
        address=GOVERNANCE_CONTRACT_ADDRESS,
        abi=load_contract_abi("ConcreteAgroChainGovernance")
    )
    token_contract = w3.eth.contract(
        address=TOKEN_CONTRACT_ADDRESS,
        abi=load_contract_abi("AgroChainToken")
    )
    nft_contract = w3.eth.contract(
        address=POLICY_NFT_ADDRESS,
        abi=load_contract_abi("PolicyNFT")
    )
    
    print(f"Conectado à blockchain em {WEB3_PROVIDER_URL}")
    print(f"Conta de admin: {admin_address}")
    print("Contratos inicializados com sucesso!")
except Exception as e:
    print(f"Erro ao inicializar contratos: {e}")
    raise