from ..utils.config import w3, admin_address, admin_private_key, insurance_contract, oracle_contract, treasury_contract, governance_contract, token_contract, nft_contract
import logging

logger = logging.getLogger(__name__)

def send_transaction(contract_function, value=0, sender_address=None, private_key=None):
    """
    Envia uma transação para a blockchain.
    
    Args:
        contract_function: A função do contrato a ser chamada
        value: O valor em wei a ser enviado com a transação (opcional)
        sender_address: O endereço do remetente (opcional, padrão: admin_address)
        private_key: A chave privada do remetente (opcional, padrão: admin_private_key)
    
    Returns:
        O recibo da transação
    """
    try:
        if sender_address is None:
            sender_address = admin_address
        if private_key is None:
            private_key = admin_private_key

        logger.debug(f"Sending transaction with value: {value}")
        
        tx = contract_function.build_transaction({
            "from": sender_address,
            "nonce": w3.eth.get_transaction_count(sender_address),
            "gas": 2000000,
            "gasPrice": w3.eth.gas_price,
            "chainId": w3.eth.chain_id,
            "value": value
        })
        
        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        logger.debug(f"Signed transaction: {signed_tx}")
        
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        logger.debug(f"Transaction successful: {tx_hash.hex()}")
        return receipt
    except Exception as e:
        logger.error(f"Error in send_transaction: {str(e)}", exc_info=True)
        raise Exception(f"Transaction failed: {str(e)}")

def send_transaction_with_args(contract, function_name, *args, value=0, sender_address=None, private_key=None):
    """
    Versão alternativa que aceita o contrato, nome da função e argumentos separadamente.
    Útil para chamadas dinâmicas de funções.
    """
    try:
        function = getattr(contract.functions, function_name)(*args)
        return send_transaction(function, value, sender_address, private_key)
    except Exception as e:
        logger.error(f"Error in send_transaction_with_args: {str(e)}", exc_info=True)
        raise Exception(f"Transaction with args failed: {str(e)}")

def get_event_data(contract, event_name, receipt):
    """
    Obtém dados de eventos de um recibo de transação.
    
    Args:
        contract: O contrato que emite o evento
        event_name: O nome do evento a ser buscado
        receipt: O recibo da transação
    
    Returns:
        Uma lista de eventos processados
    """
    try:
        event = getattr(contract.events, event_name)
        events = event().process_receipt(receipt)
        logger.debug(f"Events found: {events}")
        return events  # Retorna uma lista de eventos
    except Exception as e:
        logger.error(f"Error in get_event_data: {str(e)}", exc_info=True)
        return None  # Retorna None em caso de erro