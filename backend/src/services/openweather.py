import requests
import os
from dotenv import load_dotenv
import logging

# Configurar logging
logger = logging.getLogger(__name__)

# Carregar variáveis de ambiente
load_dotenv()
OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY")
OPENWEATHER_BASE_URL = "https://api.openweathermap.org/data/2.5/weather"

# Tipos de parâmetros suportados e seus mapeamentos para a API OpenWeather
PARAMETER_MAPPINGS = {
    "rainfall": {"source": "rain", "field": "1h", "multiplier": 1000, "default": 0},
    "temperature": {"source": "main", "field": "temp", "multiplier": 1000, "default": 0},
    "humidity": {"source": "main", "field": "humidity", "multiplier": 100, "default": 0},
    "wind_speed": {"source": "wind", "field": "speed", "multiplier": 1000, "default": 0},
    "pressure": {"source": "main", "field": "pressure", "multiplier": 10, "default": 0},
    "clouds": {"source": "clouds", "field": "all", "multiplier": 100, "default": 0}
}

def fetch_climate_data(region: str, parameter_type: str) -> int:
    """
    Busca dados climáticos da API OpenWeather.
    
    Args:
        region: A região para buscar os dados (cidade, país)
        parameter_type: O tipo de parâmetro climático a ser buscado
        
    Returns:
        O valor do parâmetro climático, convertido para inteiro (multiplicado pelo fator de conversão)
        
    Raises:
        ValueError: Se o tipo de parâmetro não for suportado
        requests.RequestException: Se ocorrer um erro na requisição para a API
    """
    # Validar o tipo de parâmetro
    if parameter_type not in PARAMETER_MAPPINGS:
        supported_types = ", ".join(PARAMETER_MAPPINGS.keys())
        error_msg = f"Unsupported parameter type: '{parameter_type}'. Supported types are: {supported_types}"
        logger.error(error_msg)
        raise ValueError(error_msg)
    
    # Verificar se a chave da API está configurada
    if not OPENWEATHER_API_KEY:
        error_msg = "OPENWEATHER_API_KEY is not set in environment variables"
        logger.error(error_msg)
        raise ValueError(error_msg)
    
    # Preparar parâmetros da requisição
    params = {
        "q": region,
        "appid": OPENWEATHER_API_KEY,
        "units": "metric"  # Usar unidades métricas (°C, mm, etc.)
    }
    
    try:
        logger.info(f"Fetching {parameter_type} data for region: {region}")
        response = requests.get(OPENWEATHER_BASE_URL, params=params)
        response.raise_for_status()  # Verificar se a requisição foi bem-sucedida
        data = response.json()
        
        # Obter a configuração de mapeamento para o tipo de parâmetro
        mapping = PARAMETER_MAPPINGS[parameter_type]
        
        # Extrair o valor do parâmetro da resposta
        source_data = data.get(mapping["source"], {})
        
        # Para alguns parâmetros como "rain", o valor pode estar em um subcampo
        if isinstance(source_data, dict):
            value = source_data.get(mapping["field"], mapping["default"])
        else:
            value = mapping["default"]
        
        # Converter para inteiro (multiplicado pelo fator de conversão)
        int_value = int(float(value) * mapping["multiplier"])
        
        logger.info(f"Fetched {parameter_type} value for {region}: {value} (raw), {int_value} (converted)")
        return int_value
    
    except requests.exceptions.RequestException as e:
        error_msg = f"Error fetching data from OpenWeather API: {str(e)}"
        logger.error(error_msg)
        raise
    
    except (ValueError, TypeError, KeyError) as e:
        error_msg = f"Error processing OpenWeather API response: {str(e)}"
        logger.error(error_msg)
        raise ValueError(error_msg)

# Função adicional para obter dados mais detalhados (opcional)
def fetch_detailed_climate_data(region: str):
    """
    Busca dados climáticos detalhados da API OpenWeather.
    
    Args:
        region: A região para buscar os dados (cidade, país)
        
    Returns:
        Um dicionário com todos os dados climáticos disponíveis
    """
    if not OPENWEATHER_API_KEY:
        raise ValueError("OPENWEATHER_API_KEY is not set in environment variables")
    
    params = {
        "q": region,
        "appid": OPENWEATHER_API_KEY,
        "units": "metric"
    }
    
    response = requests.get(OPENWEATHER_BASE_URL, params=params)
    response.raise_for_status()
    
    return response.json()