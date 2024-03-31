module fresh_loan_contract::flash_loan {
    use sui::balance::{Self as BalanceModule, Balance};
    use sui::coin::{Self as CoinModule, Coin};
    use sui::event::{Self as EventModule};
    use sui::object::{Self as ObjectModule, ID, UID};
    use sui::transfer;
    use sui::address;
    use sui::tx_context::{Self as TxContextModule, TxContext};

    //-----------Exception--------------------
    const EBalanceNotEnough: u64 = 0;

    //-----------Event--------------------
    struct FlashLoanEvent has copy, drop {
        flash_loan_id: ID,
        balance: u64,
        action: u8, // operator：1=create，2=loan，3=repay
        lender: address,
    }

    struct FlashLoan<phantom T> has key, store {
        id: UID,
        lender: address,
        balance: Balance<T>,
        fee: u64,
    }


    struct LoanRecord<phantom T>  {
        flash_loan_id: ID,
        repay_amount: u64,
    }

    public entry fun create_loan<T>(token_to_loan: Coin<T>, fee: u64, ctx: &mut TxContext) {
        let id = ObjectModule::new(ctx);
        let lender = TxContextModule::sender(ctx);
        let loan_inner_id = ObjectModule::uid_to_inner(&id);
        let balance = CoinModule::into_balance(token_to_loan);

        let loan = FlashLoan {
            id,
            lender,
            balance,
            fee,
        };

        EventModule::emit(FlashLoanEvent {
            flash_loan_id: loan_inner_id,
            balance: CoinModule::value(&token_to_loan),
            action: 1,
            lender,
        });

        transfer::share_object(loan);
    }
    
    public fun apply_loan<T>(loan: &mut FlashLoan<T>, amount: u64, ctx: &mut TxContext): LoanRecord<T> {
        let balance = &mut loan.balance;
        assert!(BalanceModule::value(balance) >= amount, EBalanceNotEnough);
        let loan = CoinModule::take(balance, amount, ctx);
        let repay_amount = amount + loan.fee;

        LoanRecord {
            flash_loan_id: ObjectModule::id(loan),
            repay_amount: repay_amount,
        }
    }

    // todo
    // public fun repay_loan<T>(token: LoanRecord<T>) {
        
    // }
}
