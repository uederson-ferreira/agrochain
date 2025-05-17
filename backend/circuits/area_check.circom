// backend/circuits/area_check.circom pragma circom 2.0.0;

template AreaCheck() { signal input insured_area; signal input min_area; signal input max_area; signal output is_valid; is_valid <== (insured_area >= min_area) && (insured_area <= max_area); }

component main { public [min_area, max_area] } = AreaCheck();