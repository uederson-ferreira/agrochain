## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

# Começando com AgroChain

Este guia irá ajudar você a configurar o ambiente de desenvolvimento, compilar e testar os contratos do AgroChain - um sistema de seguro paramétrico descentralizado para produtores rurais.

## Pré-requisitos

Antes de começar, você precisa ter instalado:

- [Git](https://git-scm.com/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (opcional, para scripts adicionais)

## Instalação

1. Clone o repositório:

```bash
git clone https://github.com/uederson-ferreira/agrochain.git
cd agrochain
```

2. Instale as dependências do Foundry:

```bash
forge install
```

## Estrutura do Projeto

O projeto está organizado da seguinte forma:

```
agrochain/
├── smart-contracts/
│   └── seguroagrochain/
│       ├── src/                # Código fonte dos contratos
│       ├── test/               # Testes dos contratos
│       └── script/             # Scripts de implantação
├── docs/                       # Documentação
└── README.md                   # Arquivo README principal
```

## Contratos Principais

O sistema AgroChain consiste em vários contratos inteligentes que trabalham juntos:

1. **AgroChainInsurance.sol**: O contrato principal que gerencia as apólices de seguro
2. **AgroChainOracle.sol**: Sistema de oráculos para obter dados climáticos
3. **AgroChainTreasury.sol**: Gestão financeira das reservas do sistema
4. **AgroChainGovernance.sol**: Sistema de governança para o protocolo
5. **AgroChainToken.sol**: Token de governança (AGRO)
6. **PolicyNFT.sol**: Representação de apólices como NFTs

## Compilação

Para compilar os contratos:

```bash
cd smart-contracts/seguroagrochain
forge build
```

## Testes

Para executar os testes:

```bash
forge test
```

Para testes com cobertura de código:

```bash
forge coverage
```

Para testes verbosos (mostrando mais detalhes):

```bash
forge test -vvv
```

## Implantação

### Testnet (Sepolia)

Para implantar na testnet Sepolia:

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

Substitua `$SEPOLIA_RPC_URL` pela URL do seu nó RPC e `$PRIVATE_KEY` pela sua chave privada (nunca compartilhe essa chave).

### Mainnet

Para implantar na mainnet Ethereum:

```bash
forge script script/Deploy.s.sol:DeployScript --rpc-url $MAINNET_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify
```

## Funcionalidades Principais

### Criação de Apólice

Uma apólice de seguro paramétrico pode ser criada com os seguintes parâmetros:

- **Produtor rural**: Endereço do produtor
- **Valor de cobertura**: Quanto será pago em caso de sinistro
- **Datas**: Início e fim da cobertura
- **Região**: Localização geográfica
- **Cultura**: Tipo de cultura (soja, milho, etc.)
- **Parâmetros climáticos**: Condições que acionam o pagamento

### Parâmetros Climáticos

Cada apólice pode ter múltiplos parâmetros climáticos, como:

- **Precipitação**: Pagamento acionado quando chove menos que X mm
- **Temperatura**: Pagamento acionado quando temperatura excede Y graus
- **Dias de seca**: Pagamento acionado quando há mais de Z dias consecutivos sem chuva

### Ativação de Apólice

Uma vez criada, a apólice precisa ser ativada através do pagamento do prêmio.

### Solicitação de Dados Climáticos

Durante o período de cobertura, o produtor pode solicitar verificação de dados climáticos.

### Pagamento Automático

Se os dados climáticos confirmarem que as condições de gatilho foram atingidas, o pagamento é realizado automaticamente.

## Licença

Este projeto está licenciado sob a [MIT License](LICENSE).

## Contribuição

Contribuições são bem-vindas! Por favor, leia o [guia de contribuição](CONTRIBUTING.md) antes de enviar pull requests.

## Contato

Para dúvidas ou sugestões, entre em contato com [uederson.ferreira@exemplo.com](mailto:seu-email@exemplo.com).