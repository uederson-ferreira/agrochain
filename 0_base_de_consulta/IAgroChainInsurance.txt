// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IAgroChainInsurance
 * @dev Interface principal para o contrato de seguro AgroChain
 */
interface IAgroChainInsurance {
    /**
     * @dev Estrutura que define uma apólice de seguro
     */
    struct Policy {
        uint256 id;                 // ID único da apólice
        address payable farmer;     // Endereço do produtor rural
        uint256 coverageAmount;     // Valor total da cobertura
        uint256 premium;            // Valor do prêmio
        uint256 startDate;          // Data de início da cobertura
        uint256 endDate;            // Data de término da cobertura
        bool active;                // Status de atividade da apólice
        bool claimed;               // Se já houve reivindicação/pagamento
        uint256 claimPaid;          // Valor já pago em sinistros
        uint256 lastClaimDate;      // Data do último pagamento
        bytes32 policyDataHash;     // Hash dos dados completos da apólice
        string region;              // Região geográfica
        string cropType;            // Tipo de cultura
    }

    /**
     * @dev Estrutura para parâmetros climáticos
     */
    struct ClimateParameter {
        string parameterType;      // Tipo (chuva, temperatura, etc)
        uint256 thresholdValue;    // Valor limite para ativação
        uint256 periodInDays;      // Período para verificação
        bool triggerAbove;         // Ativar quando acima do limite?
        uint256 payoutPercentage;  // % do valor a ser pago quando ativado
    }

    /**
     * @dev Estrutura para dados de medições climáticas
     */
    struct ClimateData {
        bytes32 requestId;          // ID da solicitação
        string parameterType;       // Tipo de parâmetro
        uint256 measuredValue;      // Valor medido
        uint256 timestamp;          // Momento da medição
        string dataSource;          // Fonte dos dados
        bytes signature;            // Assinatura para verificação
    }

    // Eventos principais
    event PolicyCreated(uint256 indexed policyId, address indexed farmer, uint256 coverageAmount, string cropType);
    event PolicyActivated(uint256 indexed policyId, uint256 premium);
    event ClimateDataRequested(uint256 indexed policyId, bytes32 requestId, string parameterType);
    event ClaimTriggered(uint256 indexed policyId, address indexed farmer, uint256 payoutAmount);
    event PolicyExpired(uint256 indexed policyId);
    event PolicyCancelled(uint256 indexed policyId, uint256 refundAmount);

    // Funções principais
    function createPolicy(
        address payable _farmer,
        uint256 _coverageAmount,
        uint256 _startDate,
        uint256 _endDate,
        string calldata _region,
        string calldata _cropType,
        ClimateParameter[] calldata _parameters
    ) external returns (uint256 policyId);

    function activatePolicy(uint256 _policyId) external payable;
    
    function requestClimateData(uint256 _policyId, string calldata _parameterType) external returns (bytes32);
    
    function processClaim(uint256 _policyId, ClimateData calldata _climateData) external returns (bool success, uint256 amount);
    
    function cancelPolicy(uint256 _policyId) external returns (uint256 refundAmount);
    
    function getPolicyDetails(uint256 _policyId) external view returns (Policy memory, ClimateParameter[] memory);
    
    function getPolicyStatus(uint256 _policyId) external view returns (
        bool active,
        bool claimed,
        uint256 claimPaid,
        uint256 remainingCoverage,
        uint256 timeRemaining
    );
}