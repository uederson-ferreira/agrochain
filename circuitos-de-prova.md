
# Circuitos de Prova

Depois de compilar o circuito e executar a calculadora testemunha com uma entrada apropriada, teremos:

- Um arquivo `.wtns` que contém todos os sinais computados
- Um arquivo `.r1cs` que contém as restrições que descrevem o circuito

Ambos os arquivos serão usados para criar nossa prova.

---

## Gerando e Validando a Prova

Vamos usar a ferramenta `snarkjs` para gerar e validar uma prova para a nossa entrada. Usando o circuito `multiplicador2`, provaremos que somos capazes de fornecer os dois fatores do número 33. Ou seja, mostraremos que conhecemos dois inteiros `a` e `b` tais que `a * b = 33`.

Usaremos o protocolo **Groth16 ZK-SNARK**, que exige uma **configuração confiável** composta por duas partes:

1. **Poderes do Tau** (independente do circuito)
2. **Fase 2** (dependente do circuito)

A seguir, os passos para criação da prova e verificação:

---

## Poderes do Tau

1. Inicie uma nova cerimônia de "Poderes da Tau":

   ```bash
   snarkjs powersoftau new bn128 12 pot12_0000.ptau -v
   ```

2. Contribua para a cerimônia:

   ```bash
   snarkjs powersoftau contribute pot12_0000.ptau pot12_0001.ptau --name="First contribution" -v
   ```

---

## Fase 2 (Específica do Circuito)

1. Prepare a Fase 2:

   ```bash
   snarkjs powersoftau prepare phase2 pot12_0001.ptau pot12_final.ptau -v
   ```

2. Gere o arquivo `.zkey` com as chaves de comprovação e verificação:

   ```bash
   snarkjs groth16 setup multiplier2.r1cs pot12_final.ptau multiplier2_0000.zkey
   ```

3. Contribua para a Fase 2:

   ```bash
   snarkjs zkey contribute multiplier2_0000.zkey multiplier2_0001.zkey --name="1st Contributor Name" -v
   ```

4. Exporte a chave de verificação:

   ```bash
   snarkjs zkey export verificationkey multiplier2_0001.zkey verification_key.json
   ```

---

## Gerando uma Prova

Com a testemunha computada e a configuração confiável pronta, gere a prova zk:

```bash
snarkjs groth16 prove multiplier2_0001.zkey witness.wtns proof.json public.json
```

Isso gera dois arquivos:

- `proof.json`: contém a prova
- `public.json`: contém as entradas/saídas públicas

---

## Verificando uma Prova

Para verificar a prova, execute:

```bash
snarkjs groth16 verify verification_key.json public.json proof.json
```

Se a prova for válida, a saída será `OK`.

---

## Verificação a partir de um Contrato Inteligente

👉 Também é possível verificar provas diretamente na **blockchain Ethereum** com um contrato inteligente Solidity.

### Gerando o Verificador Solidity

```bash
snarkjs zkey export solidityverifier multiplier2_0001.zkey verifier.sol
```

Esse comando gera o arquivo `verifier.sol`, que contém os contratos `Pairing` e `Verifier`. Você deve implantar apenas o contrato `Verifier`.

> ⚠️ Sugestão: use uma testnet como Rinkeby, Kovan ou Ropsten, ou a VM JavaScript no Remix (com cuidado em navegadores que podem travar).

### Chamando o `verifyProof`

Use:

```bash
snarkjs generatecall
```

Copie e cole os parâmetros gerados no método `verifyProof` dentro do Remix.

Se tudo estiver correto, a função retornará `TRUE`. Modificar qualquer bit causará o retorno `FALSE`, confirmando a segurança da verificação.

---
