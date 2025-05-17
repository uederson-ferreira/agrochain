// backend/circuits/balance_check.circom
pragma circom 2.0.0;

template BalanceCheck() {
    signal input balance;
    signal input min_balance;
    signal output is_valid;
    is_valid <== balance >= min_balance;
}

component main { public [min_balance] } = BalanceCheck();