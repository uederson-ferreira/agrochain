import sys
import os
import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

@pytest.fixture
def mock_nft_contract(monkeypatch):
    # Criar um mock para a função getMetadata
    class MockFunction:
        def __call__(self, *args, **kwargs):
            return self
        
        def call(self, *args, **kwargs):
            return "Metadata for NFT"
    
    # Criar um mock para nft_contract com um atributo functions
    class MockNFTContract:
        class functions:
            pass

    nft_contract = MockNFTContract()

    # Aplicar o mock
    monkeypatch.setattr(nft_contract.functions, "getMetadata", MockFunction())
    monkeypatch.setattr(nft_contract.functions, "tokenURI", MockFunction())
    
    return nft_contract