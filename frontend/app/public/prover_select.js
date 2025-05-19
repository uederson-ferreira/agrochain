import wcBuilder from './witness_calculator.js';

let provaGerada = null;

function showNotification(message, type = 'success') {
  const notification = document.getElementById('notification');
  notification.textContent = message;
  notification.className = `notification ${type} show`;

  setTimeout(() => {
    notification.className = 'notification';
  }, 5000);
}

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

window.resetForm = function() {
  document.getElementById('zkForm').reset();
  document.getElementById('resultCard').style.display = 'none';
  provaGerada = null;
  document.getElementById('proofResult').textContent = '';
}

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

function formatInputData() {
  return {
    farmer_hash: document.getElementById('farmer_hash').value,
    coverage_amount: document.getElementById('coverage_amount').value,
    start_date: document.getElementById('start_date').value,
    end_date: document.getElementById('end_date').value,
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

window.gerarProva = async function() {

  if (!validateForm()) return;
  document.getElementById('resultCard').style.display = 'block';
  toggleLoader(true);

  try {
    const input = formatInputData();
    const wasmResponse = await fetch('./policy_validation.wasm');
    const wasm = await wasmResponse.arrayBuffer();
    const wc = await wcBuilder(wasm);
    const witness = await wc.calculateWTNSBin(input, 0);
    const { proof, publicSignals } = await snarkjs.groth16.prove('./policy_validation_0001.zkey', witness);

    const resultado = { proof, publicSignals, input };

    // 🔥 Expondo para o Angular acessar:
    window.provaGerada = resultado;
    
    provaGerada = { proof, publicSignals, input };
    document.getElementById('proofResult').textContent = JSON.stringify(provaGerada, null, 2);
    showNotification('✅ Prova gerada com sucesso!');
  } catch (err) {
    showNotification('Erro ao gerar prova: ' + err.message, 'error');
  } finally {
    toggleLoader(false);
  }
};

function atualizarStatusLocal(ok) {
  const el = document.getElementById('zkStatusLocal');
  if (!el) return;
  el.textContent = ok ? '✅ Verificada com sucesso' : '❌ Prova inválida';
  el.style.color = ok ? 'green' : 'red';
}

function atualizarStatusApi(ok) {
  const el = document.getElementById('zkStatusApi');
  if (!el) return;
  el.textContent = ok ? '✅ Aceita pela API' : '❌ Rejeitada pela API';
  el.style.color = ok ? 'green' : 'red';
}

// Verifica se a prova foi gerada e se o snarkjs está disponível
window.verificarComSnarkjs = async function() {
  try {
    if (!provaGerada) throw new Error("Gere a prova primeiro.");
    const vKey = await fetch('./verification_key.json').then(res => res.json());
    const verified = await snarkjs.groth16.verify(vKey, provaGerada.publicSignals, provaGerada.proof);
    if (verified) {
      showNotification("✅ Prova válida com snarkjs!");
      atualizarStatusLocal(true);
    } else {
      showNotification("❌ Prova inválida com snarkjs!", "error");
      atualizarStatusLocal(false);
    }
  } catch (err) {
    showNotification("Erro na verificação com snarkjs: " + err.message, "error");
    atualizarStatusLocal(false);
  }
};

// window.verificarComZkVerify = async function() {
//   try {
//     if (!provaGerada) throw new Error("Gere a prova primeiro.");
//     const result = await zkverify({
//       protocol: 'groth16',
//       curve: 'bn128',
//       proof: provaGerada.proof,
//       publicSignals: provaGerada.publicSignals,
//       verificationKey: {
//         protocol: 'groth16',
//         curve: 'bn128',
//         nPublic: provaGerada.publicSignals.length
//       }
//     });
//     if (result.verified) {
//       showNotification("✅ Prova validada com sucesso com zkVerify!");
//     } else {
//       showNotification("❌ Prova inválida segundo zkVerify!", "error");
//     }
//   } catch (err) {
//     showNotification("Erro na verificação com zkVerify: " + err.message, "error");
//   }
// };

// window.enviarParaAPI = async function() {
//   try {
//     if (!provaGerada) throw new Error("Gere a prova primeiro.");

//     const payload = {
//       proof: provaGerada.proof,
//       publicSignals: provaGerada.publicSignals
//     };

//     const res = await fetch("https://agrochain-jsvb.onrender.com/api/verify-proof", {
//       method: 'POST',
//       headers: { 'Content-Type': 'application/json' },
//       body: JSON.stringify(payload)
//     });
//     const data = await res.json();
//     console.log("🔍 Resposta completa da API:", data);
    
//     if (data.status === 'verified' && data.policyResponse) {
//       const policy = data.policyResponse;
//       const hash = policy.transactionHash || 'hash não disponível';
//       const id = policy.policyId ?? 'ID não encontrado';

//       showNotification(`✅ Apólice criada com sucesso! ID: ${id}`, 'success');

//       const extraStatus = document.getElementById('verificationStatusExtra');
//       if (extraStatus) {
//         extraStatus.innerHTML = `
//           <div style="margin-top: 10px; color: #2e7d32;">
//             <p><strong>ID da Apólice:</strong> ${id}</p>
//             <p><strong>Tx Hash:</strong> <code>${hash}</code></p>
//           </div>
//         `;
//       }
//     } else {
//       showNotification("⚠️ Prova verificada, mas a apólice não foi criada", "error");
//     }
    
//     //const data = await res.json();
//     showNotification(`🚀 Prova enviada com sucesso ao backend! Status: ${data.status}`);
//     // ✅ Aqui vem a novidade:
//     if (data.status === 'verified' || data.status === true) {
//       atualizarStatusApi(true);
//     } else {
//       atualizarStatusApi(false);
//     }
//   } catch (err) {
//     showNotification("Erro ao enviar para API: " + err.message, "error");
//     atualizarStatusApi(false);
//   }
// };

// Verifica se a prova foi gerada e se o zkVerify está disponível
window.enviarParaAPI = async function() {
  try {
    if (!provaGerada) throw new Error("Gere a prova primeiro.");

    const payload = {
      proof: provaGerada.proof,
      publicSignals: provaGerada.publicSignals
    };

    const res = await fetch("https://agrochain-jsvb.onrender.com/api/verify-proof", {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    const data = await res.json();
    console.log("🔍 Resposta completa da API:", data);
    
    if (data.status === 'verified' && data.policyResponse) {
      let policy = data.policyResponse;

      // Caso policyResponse venha como string
      if (typeof policy === 'string') {
        try {
          policy = JSON.parse(policy);
        } catch (e) {
          console.error("Erro ao parsear policyResponse:", e);
          policy = {};
        }
      }

      const hash = policy.transactionHash || 'hash não disponível';
      const id = policy.policyId ?? 'ID não encontrado';
      const block = policy.blockNumber ?? 'bloco não encontrado';

      showNotification(`✅ Apólice criada com sucesso! ID: ${id}`, 'success');

      const extraStatus = document.getElementById('verificationStatusExtra');
      if (extraStatus) {
        extraStatus.innerHTML = `
          <div style="margin-top: 10px; color: #2e7d32;">
            <p><strong>ID da Apólice:</strong> ${id}</p>
            <p><strong>Tx Hash:</strong> <code>${hash}</code></p>
            <p><strong>Nº do Bloco:</strong> ${block}</p>
          </div>
        `;
      }
    } else {
      showNotification("⚠️ Prova verificada, mas a apólice não foi criada", "error");
    }

    showNotification(`🚀 Prova enviada com sucesso ao backend! Status: ${data.status}`);

    if (data.status === 'verified' || data.status === true) {
      atualizarStatusApi(true);
    } else {
      atualizarStatusApi(false);
    }
  } catch (err) {
    showNotification("Erro ao enviar para API: " + err.message, "error");
    atualizarStatusApi(false);
  }
};


document.addEventListener('DOMContentLoaded', () => {
  const currentTimestampField = document.getElementById('current_timestamp');
  if (currentTimestampField && !currentTimestampField.value) {
    currentTimestampField.value = Math.floor(Date.now() / 1000);
  }

  const btnZkVerify = document.getElementById('btnVerifyZkVerify');

  if (btnZkVerify) {
    btnZkVerify.disabled = true;
    btnZkVerify.textContent = "3️⃣ Carregando zkVerify...";

    const esperarAngular = setInterval(() => {
      if (typeof window.verificarComZkVerify === 'function') {
        btnZkVerify.disabled = false;
        btnZkVerify.textContent = "3️⃣ Verificar com zkVerify ✅";

        btnZkVerify.addEventListener('click', () => {
          window.verificarComZkVerify();
        });

        clearInterval(esperarAngular);
      }
    }, 300);
  }

  // ✅ Aqui você sinaliza para o Angular que a página da prova está pronta
  window.dispatchEvent(new CustomEvent('provaPageReady'));
});

const btnZkVerify = document.getElementById('btnVerifyZkVerify');

const esperarAngular = setInterval(() => {
  if (typeof window.verificarComZkVerify === 'function') {
    // Substitui o alerta por chamada real
    btnZkVerify.disabled = false;
    btnZkVerify.textContent = "3️⃣ Verificar com zkVerify (pronto)";
    btnZkVerify.addEventListener('click', () => {
      window.verificarComZkVerify();
    });
    clearInterval(esperarAngular); // Para o loop
  }
}, 300);

// Opcional: desativa o botão enquanto Angular carrega
btnZkVerify.disabled = true;
btnZkVerify.textContent = "3️⃣ Carregando Angular...";


