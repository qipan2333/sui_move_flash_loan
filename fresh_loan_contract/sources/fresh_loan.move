module FlashLoan {
    use sui::balance::{Self as BalanceModule, Balance};
    use sui::coin::{Self as CoinModule, Coin};
    use sui::event::{Self as EventModule, EventHandle};
    use sui::object::{Self as ObjectModule, ID, UID};
    use sui::public_key::PublicKey;
    use sui::transfer;
    use sui::tx_context::{Self as TxContextModule, TxContext};

    //-----------Exception--------------------

    //-----------Event--------------------
    struct FlashLoanEvent {
        flash_loan_id: ID,
        balance: u64,
        action: u8, // operator：1=creat，2=loan，3=repay
        initiator: PublicKey,
    }

    struct FlashLoan<phantom T> has key store {
        id: UID,
        total: BalanceModule<T>,
        fee: u64,
    }

    struct FlashLoanToken<phantom T>  {
        flash_loan_id: ID,
        repay_amount: u64,
    }

    public fun repay_loan<T>(token: FlashLoanToken<T>) {
    
    }
}
