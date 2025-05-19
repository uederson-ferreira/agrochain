#!/bin/bash

# Recebe o nome da rede como argumento (ex: moonbase ou sepolia)
ENV_FILE=".env.${1:-moonbase}"

if [ ! -f "$ENV_FILE" ]; then
  echo "Arquivo $ENV_FILE não encontrado."
  exit 1
fi

# Carrega as variáveis
set -a
source "$ENV_FILE"
set +a

# Executa o deploy com as variáveis carregadas
forge script script/Deploy.s.sol \
  --rpc-url $MOONBASE_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --chain 1287
