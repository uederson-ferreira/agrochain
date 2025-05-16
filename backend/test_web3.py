import web3
import inspect

print(f"Web3 version: {web3.__version__}")

# Listar todos os módulos e submódulos disponíveis
print("\nMódulos disponíveis em web3:")
for item in dir(web3):
    if not item.startswith('_'):
        print(f"  - {item}")

print("\nSubmódulos em web3.middleware:")
for item in dir(web3.middleware):
    if not item.startswith('_'):
        print(f"  - {item}")

# Procurar por qualquer coisa relacionada a 'poa' ou 'geth'
print("\nProcurando por 'poa' ou 'geth' em todos os submódulos:")
for module_name in dir(web3):
    if not module_name.startswith('_'):
        module = getattr(web3, module_name)
        if inspect.ismodule(module):
            for submodule_name in dir(module):
                if ('poa' in submodule_name.lower() or 'geth' in submodule_name.lower()) and not submodule_name.startswith('_'):
                    print(f"  - web3.{module_name}.{submodule_name}")