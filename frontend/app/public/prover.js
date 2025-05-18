
import wcBuilder from './witness_calculator.js';

// Function to show notifications
function showNotification(message, type = 'success') {
  const notification = document.getElementById('notification');
  notification.textContent = message;
  notification.className = `notification ${type} show`;

  setTimeout(() => {
    notification.className = 'notification';
  }, 5000);
}

// Function to show/hide the loader
function toggleLoader(show) {
  const loader = document.getElementById('proofLoader');
  const generateBtn = document.getElementById('generateBtn');

  if (show) {
    loader.style.display = 'flex';
    generateBtn.disabled = true;
    generateBtn.textContent = 'Gerando...';
  } else {
    loader.style.display = 'none';
    generateBtn.disabled = false;
    generateBtn.textContent = 'Gerar Prova';
  }
}

// Function to reset the form
window.resetForm = function() {
  document.getElementById('zkForm').reset();
  document.getElementById('resultCard').style.display = 'none';
}

// Function to validate form inputs
function validateForm() {
  const requiredFields = [
    'farmer_hash', 'coverage_amount', 'start_date', 'end_date',
    'region_hash', 'crop_type_hash', 'parameter_type_hash',
    'threshold_value', 'period_in_days', 'payout_percentage'
  ];

  for (const field of requiredFields) {
    const value = document.getElementById(field).value.trim();
    if (!value) {
      showNotification(`Campo obrigatório: ${field}`, 'error');
      return false;
    }
  }

  return true;
}

function textoParaHashDecimal(texto) {
  const hashHex = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(texto));
  return BigInt(hashHex).toString();
}

// Function to format the input data for the ZK proof
function formatInputData() {
  return {
    farmer_hash: document.getElementById('farmer_hash').value,
    coverage_amount: document.getElementById('coverage_amount').value,
    start_date: document.getElementById('start_date').value,
    end_date: document.getElementById('end_date').value,

    // Convertendo os campos de texto para hash decimal
    region_hash: textoParaHashDecimal(document.getElementById('region_hash').value),
    crop_type_hash: textoParaHashDecimal(document.getElementById('crop_type_hash').value),
    parameter_type_hash: textoParaHashDecimal(document.getElementById('parameter_type_hash').value),

    threshold_value: document.getElementById('threshold_value').value,
    period_in_days: document.getElementById('period_in_days').value,
    trigger_above: document.getElementById('trigger_above').value,
    payout_percentage: document.getElementById('payout_percentage').value,
    current_timestamp: document.getElementById('current_timestamp').value || Math.floor(Date.now() / 1000)
  };
}

// Main function to generate the ZK proof
window.gerarProva = async function() {
  if (!validateForm()) return;

  document.getElementById('resultCard').style.display = 'block';
  toggleLoader(true);

  try {
    const input = formatInputData();
    console.log('Input data:', input);

    const wasmPath = './policy_validation.wasm';
    const zkeyPath = './policy_validation_0001.zkey';

    const wasmResponse = await fetch(wasmPath);
    if (!wasmResponse.ok) throw new Error(`Failed to fetch WASM file: ${wasmResponse.statusText}`);
    const wasm = await wasmResponse.arrayBuffer();

    const wc = await wcBuilder(wasm);
    console.log('Calculating witness...');
    const witness = await wc.calculateWTNSBin(input, 0);
    console.log('Witness calculated successfully');

    console.log('Generating proof...');
    const { proof, publicSignals } = await snarkjs.groth16.prove(zkeyPath, witness);
    console.log('Proof generated successfully');

    const resultado = { proof, publicSignals, input };
    document.getElementById('proofResult').textContent = JSON.stringify(resultado, null, 2);
    showNotification('Prova gerada com sucesso!');

    // Mock policy data
    const mockPolicy = {
      farmer: "0xD1BE6aEEbB4c08624730B912Def3Af2d9CdC807B",
      coverageAmount: 50000,
      startDate: 1750000000,
      endDate: 1750600000,
      region: "NORTE",
      cropType: "SOJA",
      parameters: [
        {
          parameterType: "chuva",
          thresholdValue: 120,       // ✅ corrigido
          periodInDays: 30,          // ✅ corrigido
          triggerAbove: true,
          payoutPercentage: 80
        }
      ],
      zkProofHash: "0x2e5a8d7c4b1e9a2f5d8c7b4a1e9d2c5b8a7f4e1d9c67a3d9f5b2c1e8a4d6b9c0f"
    };

    try {
      const policyResponse = await fetch('http://localhost:8000/api/policies', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(mockPolicy)
      });

      const policyResult = await policyResponse.json();
      console.log("Resposta da API:", policyResult);
      showNotification(`Apólice criada com sucesso! ID: ${policyResult.policyId}`);
    } catch (apiError) {
      console.error("Erro ao enviar apólice:", apiError);
      showNotification("Erro ao enviar apólice para a API", "error");
    }

  } catch (error) {
    console.error('Erro ao gerar prova:', error);
    document.getElementById('proofResult').textContent = `Erro: ${error.message}`;
    showNotification(`Erro ao gerar prova: ${error.message}`, 'error');
  } finally {
    toggleLoader(false);
  }
};

document.addEventListener('DOMContentLoaded', () => {
  const currentTimestampField = document.getElementById('current_timestamp');
  if (currentTimestampField && !currentTimestampField.value) {
    currentTimestampField.value = Math.floor(Date.now() / 1000);
  }
});
