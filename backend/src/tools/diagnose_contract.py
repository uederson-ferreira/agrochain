#!/usr/bin/env python
"""
Script de diagnóstico para analisar e testar os contratos do AgroChain.
Execute com: python -m src.tools.diagnose_contract
"""

import sys
import os
import json
from web3 import Web3

# Garantir que o diretório do projeto esteja no path
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

# Importar as configurações
from src.utils.config import (
    w3, admin_address, insurance_contract, oracle_contract, 
    treasury_contract, governance_contract, token_contract, nft_contract
)

def print_header(title):
    print("\n" + "=" * 60)
    print(f" {title}")
    print("=" * 60 + "\n")

def print_section(title):
    print("\n" + "-" * 40)
    print(f" {title}")
    print("-" * 40)

def diagnose_contracts():
    """Diagnóstico detalhado dos contratos"""
    print_header("DIAGNÓSTICO DE CONTRATOS")
    
    contracts = {
        "insurance_contract": insurance_contract,
        "oracle_contract": oracle_contract,
        "treasury_contract": treasury_contract,
        "governance_contract": governance_contract,
        "token_contract": token_contract,
        "nft_contract": nft_contract
    }
    
    for name, contract in contracts.items():
        print_section(f"Contrato: {name.upper()}")
        print(f"Endereço: {contract.address}")
        
        # Listar funções disponíveis
        functions = []
        for fn in dir(contract.functions):
            if not fn.startswith('__') and callable(getattr(contract.functions, fn)):
                functions.append(fn)
        
        print(f"Funções disponíveis ({len(functions)}):")
        for func in sorted(functions):
            try:
                # Tentar obter a assinatura da função
                signature = getattr(contract.functions, func).abi['signature']
                print(f"  - {signature}")
            except:
                print(f"  - {func}")
        
        # Listar eventos disponíveis
        events = []
        for event in dir(contract.events):
            if not event.startswith('__'):
                events.append(event)
        
        print(f"\nEventos disponíveis ({len(events)}):")
        for event in sorted(events):
            try:
                # Tentar obter a assinatura do evento
                signature = getattr(contract.events, event).abi['signature']
                print(f"  - {signature}")
            except:
                print(f"  - {event}")

def test_create_policy():
    """Testa a criação de uma política e analisa o retorno"""
    print_header("TESTE DE CRIAÇÃO DE POLÍTICA")
    
    # Verificar se a função createPolicy existe
    if not hasattr(insurance_contract.functions, 'createPolicy'):
        print("ERRO: Função 'createPolicy' não encontrada no contrato!")
        return
    
    # Dados de exemplo para a criação da política
    farmer = admin_address  # Usar o endereço do admin como farmer
    coverage_amount = Web3.to_wei(1, 'ether')  # 1 ETH de cobertura
    current_time = w3.eth.get_block('latest').timestamp
    start_date = current_time + (24 * 60 * 60)  # 1 dia no futuro
    end_date = current_time + (30 * 24 * 60 * 60)  # 30 dias depois
    region = "Belem"
    crop_type = "Acai"
    
    # Parâmetros climáticos
    parameters = [
        ("temperature", 30000, 7, True, 5000),  # 30°C, 7 dias, acima, 50% de pagamento
    ]
    
    print("Dados da política de teste:")
    print(f"  Farmer: {farmer}")
    print(f"  Valor de cobertura: {coverage_amount} wei")
    print(f"  Data inicial: {start_date}")
    print(f"  Data final: {end_date}")
    print(f"  Região: {region}")
    print(f"  Tipo de cultura: {crop_type}")
    print(f"  Parâmetros: {parameters}")
    
    try:
        # Construir a transação
        func = insurance_contract.functions.createPolicy(
            farmer, coverage_amount, start_date, end_date, region, crop_type, parameters
        )
        
        # Estimar o gas (para verificar se a função é válida)
        try:
            gas_estimate = func.estimate_gas({'from': admin_address})
            print(f"\nEstimativa de gas: {gas_estimate}")
        except Exception as e:
            print(f"\nERRO ao estimar gas: {str(e)}")
            print("Isso pode indicar que a assinatura da função está incorreta ou os parâmetros são inválidos.")
            return
        
        # Construir a transação
        tx = func.build_transaction({
            'from': admin_address,
            'nonce': w3.eth.get_transaction_count(admin_address),
            'gas': gas_estimate * 2,  # Dobro do gas estimado para segurança
            'gasPrice': w3.eth.gas_price
        })
        
        # Perguntar se deseja enviar a transação
        response = input("\nDeseja enviar a transação? (s/n): ")
        if response.lower() != 's':
            print("Operação cancelada pelo usuário.")
            return
        
        # Enviar a transação
        from src.utils.config import admin_private_key
        signed_tx = w3.eth.account.sign_transaction(tx, admin_private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        
        print(f"\nTransação enviada!")
        print(f"Hash: {tx_hash.hex()}")
        
        # Aguardar o recibo
        print("\nAguardando confirmação...")
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        print(f"\nTransação confirmada no bloco {receipt['blockNumber']}")
        print(f"Status: {'Sucesso' if receipt['status'] == 1 else 'Falha'}")
        print(f"Gas usado: {receipt['gasUsed']}")
        
        # Analisar logs
        print("\nLogs:")
        if len(receipt.get('logs', [])) == 0:
            print("  Nenhum log encontrado (não foram emitidos eventos).")
        else:
            for i, log in enumerate(receipt.get('logs', [])):
                print(f"\nLog #{i+1}:")
                print(f"  Contrato: {log['address']}")
                print(f"  Tópicos: {[t.hex() for t in log['topics']]}")
                data_hex = log['data']
                print(f"  Dados (hex): {data_hex}")
                
                # Tentar interpretar dados básicos
                if data_hex and len(data_hex) > 2:  # Mais que apenas '0x'
                    data = data_hex[2:]  # Remove '0x'
                    # Tenta interpretar como uint256 (comum para IDs)
                    if len(data) >= 64:
                        chunks = [data[i:i+64] for i in range(0, len(data), 64)]
                        print("  Dados (interpretados como uint256):")
                        for j, chunk in enumerate(chunks):
                            try:
                                value = int(chunk, 16)
                                print(f"    Valor {j+1}: {value}")
                            except:
                                pass
        
        # Tentar verificar o resultado
        try:
            # Tentar várias funções que podem retornar informações sobre políticas
            for func_name in ['getPolicyDetails', 'getPolicy', 'getPolicyById', 'policies']:
                if hasattr(insurance_contract.functions, func_name):
                    print(f"\nTentando obter detalhes via {func_name}...")
                    # Para a maioria das funções, o ID é geralmente 0 para a primeira política
                    for policy_id in range(3):  # Tenta IDs 0, 1 e 2
                        try:
                            result = getattr(insurance_contract.functions, func_name)(policy_id).call()
                            print(f"Política ID {policy_id}:")
                            print(f"  Resultado: {result}")
                            break
                        except Exception as e:
                            print(f"  Erro ao consultar ID {policy_id}: {str(e)}")
        except Exception as e:
            print(f"\nErro ao verificar resultado: {str(e)}")
        
        print("\nTeste concluído!")
        
    except Exception as e:
        print(f"\nERRO durante o teste: {str(e)}")

def show_abi(contract_name):
    """Mostra o ABI completo de um contrato específico"""
    contracts = {
        "insurance": insurance_contract,
        "oracle": oracle_contract,
        "treasury": treasury_contract,
        "governance": governance_contract,
        "token": token_contract,
        "nft": nft_contract
    }
    
    if contract_name not in contracts:
        print(f"Contrato '{contract_name}' não encontrado.")
        print(f"Opções disponíveis: {', '.join(contracts.keys())}")
        return
    
    contract = contracts[contract_name]
    print_header(f"ABI DO CONTRATO {contract_name.upper()}")
    print(json.dumps(contract.abi, indent=2))

def show_help():
    """Mostra o menu de ajuda"""
    print_header("AJUDA - FERRAMENTA DE DIAGNÓSTICO DE CONTRATOS")
    print("Este script ajuda a diagnosticar problemas nos contratos do AgroChain.")
    print("\nComandos disponíveis:")
    print("  diagnose           - Mostra informações detalhadas sobre todos os contratos")
    print("  test_create_policy - Testa a criação de uma política")
    print("  show_abi [contrato] - Mostra o ABI completo de um contrato específico")
    print("                       (opções: insurance, oracle, treasury, governance, token, nft)")
    print("  help              - Mostra esta ajuda")
    print("  exit              - Sai do programa")

def main():
    print_header("FERRAMENTA DE DIAGNÓSTICO DE CONTRATOS AGROCHAIN")
    print("Digite 'help' para ver os comandos disponíveis.")
    
    while True:
        try:
            command = input("\n> ").strip()
            
            if command == "exit":
                break
            elif command == "help":
                show_help()
            elif command == "diagnose":
                diagnose_contracts()
            elif command == "test_create_policy":
                test_create_policy()
            elif command.startswith("show_abi "):
                contract_name = command.split(" ")[1]
                show_abi(contract_name)
            else:
                print(f"Comando desconhecido: {command}")
                print("Digite 'help' para ver os comandos disponíveis.")
        except KeyboardInterrupt:
            print("\nPrograma interrompido.")
            break
        except Exception as e:
            print(f"Erro: {str(e)}")
    
    print("\nPrograma finalizado.")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nPrograma interrompido pelo usuário.")
    except Exception as e:
        print(f"\nErro fatal: {str(e)}")