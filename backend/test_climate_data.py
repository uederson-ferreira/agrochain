#!/usr/bin/env python
"""
Script de teste para o endpoint de dados climáticos da API AgroChain.
Execute com: python test_climate_data.py
"""

import requests
import json
import argparse

# URL base da API
BASE_URL = "http://127.0.0.1:8000/api"

def test_climate_data(policy_id, region, parameter_type):
    """Testa a consulta de dados climáticos via API"""
    print(f"Testando busca de dados climáticos para política {policy_id}...")
    
    # Dados para a requisição
    data = {
        "region": region,
        "parameterType": parameter_type
    }
    
    print(f"Enviando dados: {json.dumps(data, indent=2)}")
    
    # Envia a requisição
    try:
        response = requests.post(f"{BASE_URL}/policies/{policy_id}/openweather-data", json=data)
        
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

def list_supported_parameters():
    """Lista os parâmetros climáticos suportados"""
    print("Parâmetros climáticos suportados:")
    print("  - temperature (temperatura)")
    print("  - rainfall (precipitação)")
    print("  - humidity (umidade)")
    print("  - wind_speed (velocidade do vento)")
    print("  - pressure (pressão atmosférica)")
    print("  - clouds (cobertura de nuvens)")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Testa o endpoint de dados climáticos da API AgroChain")
    parser.add_argument("--policy-id", type=int, default=0, help="ID da política a ser consultada")
    parser.add_argument("--region", type=str, default="Belem,BR", help="Região para consulta do clima")
    parser.add_argument("--parameter", type=str, default="temperature", 
                        help="Tipo de parâmetro climático (temperature, rainfall, humidity, wind_speed, pressure, clouds)")
    parser.add_argument("--list-parameters", action="store_true", help="Lista os parâmetros climáticos suportados")
    
    args = parser.parse_args()
    
    if args.list_parameters:
        list_supported_parameters()
    else:
        test_climate_data(args.policy_id, args.region, args.parameter)