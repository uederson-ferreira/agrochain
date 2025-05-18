pragma circom 2.1.0;

// Template IsZero reescrito com restrições quadráticas
template IsZero() {
    signal input in;
    signal output out;
    
    signal inv;
    
    // Se in for 0, out será 1
    // Se in não for 0, out será 0
    inv <-- in != 0 ? 1/in : 0;
    out <-- in == 0 ? 1 : 0;
    
    // Restrição 1: out é binário (0 ou1)
    out * (1 - out) === 0;
    
    // Restrição 2: in * out = 0 (ou in = 0 ou out = 0)
    in * out === 0;
    
    // Restrição 3: (1 - out) * in * inv = (1 - out)
    // Reformulado para evitar multiplicação tripla
    signal temp;
    temp <== in * inv;
    (1 - out) * temp === (1 - out);
}

template PolicyValidation() {
    // Inputs
    signal input farmer_hash; // Hash do endereço do farmer (keccak256)
    signal input coverage_amount;
    signal input start_date;
    signal input end_date;
    signal input region_hash; // Hash da região (keccak256)
    signal input crop_type_hash; // Hash do tipo de cultura (keccak256)
    signal input parameter_type_hash; // Hash do tipo de parâmetro (keccak256)
    signal input threshold_value;
    signal input period_in_days;
    signal input trigger_above; // 0 (false) ou 1 (true)
    signal input payout_percentage;
    signal input current_timestamp; // Para validar datas

    // Output
    signal output is_valid;

    // Validações
    // 1. farmer não pode ser nulo (hash != 0)
    component isZeroFarmer = IsZero();
    isZeroFarmer.in <== farmer_hash;
    signal farmer_valid;
    farmer_valid <== 1 - isZeroFarmer.out; // Se farmer_hash != 0, então farmer_valid = 1

    // 2. region não pode ser vazio (hash != 0)
    component isZeroRegion = IsZero();
    isZeroRegion.in <== region_hash;
    signal region_valid;
    region_valid <== 1 - isZeroRegion.out;

    // 3. crop_type não pode ser vazio (hash != 0)
    component isZeroCropType = IsZero();
    isZeroCropType.in <== crop_type_hash;
    signal crop_type_valid;
    crop_type_valid <== 1 - isZeroCropType.out;

    // 4. parameter_type não pode ser vazio (hash != 0)
    component isZeroParamType = IsZero();
    isZeroParamType.in <== parameter_type_hash;
    signal parameter_type_valid;
    parameter_type_valid <== 1 - isZeroParamType.out;

    // 5. trigger_above deve ser 0 ou 1
    // Verificamos se trigger_above * (trigger_above - 1) = 0
    // Isso é verdadeiro apenas para 0 e 1
    signal trigger_check;
    trigger_check <== trigger_above * (trigger_above - 1);
    component isZeroTrigger = IsZero();
    isZeroTrigger.in <== trigger_check;
    signal trigger_valid;
    trigger_valid <== isZeroTrigger.out;

    // Combina as validações usando sinais intermediários
    // para evitar multiplicações não quadráticas
    signal temp1;
    signal temp2;
    signal temp3;
    
    // Combinando dois a dois
    temp1 <== farmer_valid * region_valid;
    temp2 <== crop_type_valid * parameter_type_valid;
    temp3 <== temp1 * temp2;
    is_valid <== temp3 * trigger_valid;
}

component main { public [current_timestamp] } = PolicyValidation();