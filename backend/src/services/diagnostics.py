import json
import os
from web3 import Web3

# Importar configurações do seu projeto
from ..utils.config import w3, insurance_contract, oracle_contract, treasury_contract, governance_contract, token_contract, nft_contract

def diagnose_contracts():
    """Função para diagnóstico dos contratos e seus ABIs"""
    print("\n==== DIAGNÓSTICO DE CONTRATOS ====\n")
    
    contracts = {
        "insurance_contract": insurance_contract,
        "oracle_contract": oracle_contract,
        "treasury_contract": treasury_contract,
        "governance_contract": governance_contract,
        "token_contract": token_contract,
        "nft_contract": nft_contract
    }
    
    for name, contract in contracts.items():
        print(f"Diagnóstico do contrato: {name}")
        print(f"  Endereço: {contract.address}")
        
        # Listar funções disponíveis
        functions = []
        for fn in contract.functions:
            functions.append(fn)
        print(f"  Funções disponíveis ({len(functions)}): {', '.join(functions[:10])}...")
        
        # Listar eventos disponíveis
        events = []
        for event in contract.events:
            events.append(event)
        print(f"  Eventos disponíveis ({len(events)}): {', '.join(events)}")
        
        print("\n")

def analyze_transaction_receipt(receipt):
    """Analisa detalhadamente um recibo de transação"""
    print("\n==== ANÁLISE DE RECIBO DE TRANSAÇÃO ====\n")
    
    print(f"Status da transação: {'Sucesso' if receipt.get('status') == 1 else 'Falha'}")
    print(f"Hash da transação: {receipt.get('transactionHash').hex()}")
    print(f"Bloco: {receipt.get('blockNumber')}")
    print(f"Gas usado: {receipt.get('gasUsed')}")
    
    # Analisar logs
    print("\nLogs de eventos:")
    if len(receipt.get('logs', [])) == 0:
        print("  Nenhum log de evento encontrado.")
    else:
        for i, log in enumerate(receipt.get('logs', [])):
            print(f"\nLog #{i+1}:")
            print(f"  Endereço: {log.get('address')}")
            print(f"  Tópicos: {[t.hex() for t in log.get('topics', [])]}")
            print(f"  Dados: {log.get('data')}")
            
            # Tentar decodificar eventos conhecidos
            try:
                # Tentar cada contrato para ver se algum pode decodificar esse log
                for name, contract in {
                    "insurance": insurance_contract,
                    "oracle": oracle_contract,
                    "treasury": treasury_contract,
                    "governance": governance_contract,
                    "token": token_contract,
                    "nft": nft_contract
                }.items():
                    if log.get('address').lower() == contract.address.lower():
                        print(f"  Log é do contrato: {name}")
                        # Tentar decodificar com cada evento do contrato
                        for event_name in [e for e in dir(contract.events) if not e.startswith('_')]:
                            try:
                                event = getattr(contract.events, event_name)
                                decoded = event().process_log(log)
                                print(f"  Decodificado como evento {event_name}:")
                                print(f"  Argumentos: {decoded['args']}")
                                break
                            except Exception:
                                continue
            except Exception as e:
                print(f"  Erro ao tentar decodificar: {str(e)}")

def list_contract_abi(contract_name):
    """Lista o ABI completo de um contrato para debug"""
    contract_map = {
        "insurance": insurance_contract,
        "oracle": oracle_contract,
        "treasury": treasury_contract,
        "governance": governance_contract,
        "token": token_contract,
        "nft": nft_contract
    }
    
    if contract_name not in contract_map:
        print(f"Contrato {contract_name} não encontrado.")
        return
    
    contract = contract_map[contract_name]
    print(f"\n==== ABI DO CONTRATO {contract_name.upper()} ====\n")
    
    # Imprime o ABI formatado
    print(json.dumps(contract.abi, indent=2))
    
    # Analisar estatísticas
    events = [item for item in contract.abi if item.get('type') == 'event']
    functions = [item for item in contract.abi if item.get('type') == 'function']
    
    print(f"\nEventos definidos ({len(events)}):")
    for event in events:
        print(f"  {event.get('name')}")
        inputs = event.get('inputs', [])
        for input in inputs:
            print(f"    - {input.get('name')}: {input.get('type')} {'(indexed)' if input.get('indexed') else ''}")
    
    print(f"\nFunções definidas ({len(functions)}):")
    for function in functions[:10]:  # Limitar a exibição das primeiras 10 funções
        print(f"  {function.get('name')}")