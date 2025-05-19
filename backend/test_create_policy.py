#!/usr/bin/env python
"""
Script de teste para a API AgroChain.
Execute com: python test_create_policy.py
"""

import requests
import json
import time

# URL base da API
BASE_URL = "https://agrochain-jsvb.onrender.com/api"

def test_create_policy():
    """Testa a criação de uma apólice via API"""
    print("Testando criação de política via API...")
    
    # Dados para a criação da apólice
    current_time = int(time.time())
    data = {
        "farmer": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",  # Endereço de exemplo
        "coverageAmount": 1000000000000000000,  # 1 ETH em wei
        "startDate": current_time + (24 * 60 * 60),  # 1 dia no futuro
        "endDate": current_time + (30 * 24 * 60 * 60),  # 30 dias no futuro
        "region": "Belem",
        "cropType": "Acai",
        "parameters": [
            {
                "parameterType": "temperature",
                "thresholdValue": 30000,  # 30°C (em milésimos)
                "periodInDays": 7,
                "triggerAbove": True,
                "payoutPercentage": 5000  # 50% (em centésimos)
            }
        ]
    }
    
    print(f"Enviando dados: {json.dumps(data, indent=2)}")
    
    # Envia a requisição
    try:
        response = requests.post(f"{BASE_URL}/policies", json=data)
        
        # Imprime a resposta
        print(f"\nStatus da resposta: {response.status_code}")
        print(f"Cabeçalhos: {dict(response.headers)}")
        
        # Se a resposta é JSON, imprime-a formatada
        if response.headers.get('Content-Type', '').startswith('application/json'):
            print(f"Resposta JSON: {json.dumps(response.json(), indent=2)}")
        else:
            print(f"Resposta: {response.text}")
        
        # Verifica se a requisição foi bem-sucedida
        response.raise_for_status()
        print("\nTeste concluído com sucesso!")
        
    except requests.exceptions.RequestException as e:
        print(f"\nErro na requisição: {str(e)}")
        if hasattr(e, 'response') and e.response is not None:
            if hasattr(e.response, 'text'):
                print(f"Detalhes do erro: {e.response.text}")

if __name__ == "__main__":
    test_create_policy()