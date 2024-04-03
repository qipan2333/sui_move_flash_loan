module fresh_loan_contract::flash_loan {
    use sui::balance::{Self as BalanceModule, Balance};
    use sui::coin::{Self as CoinModule, Coin};
    use sui::event::{Self as EventModule};
    use sui::object::{Self as ObjectModule, ID, UID};
    use sui::transfer;
    use sui::tx_context::{Self as TxContextModule, TxContext};

 
    #[test_only] use sui::sui::SUI;
    #[test_only] use sui::test_scenario;

    //-----------Exception--------------------
    const EBalanceNotEnough: u64 = 0;
    const EIncorrectLoan: u64 = 1;
    const EIncorrectRepayAmound: u64 = 2;
    const EIncorrectLender: u64 = 3;

    //-----------Event--------------------
    struct FlashLoanEvent has copy, drop {
        flash_loan_id: ID,
        balance: u64,
        action: u8, // operator：1=create，2=loan，3=repay
        lender: address,
        borrower: address,
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

    // Function to create a new flash loan
    public entry fun create_loan<T>(token_to_loan: Coin<T>, fee: u64, ctx: &mut TxContext) {
        let id = ObjectModule::new(ctx);
        let lender = TxContextModule::sender(ctx);
        let loan_inner_id = ObjectModule::uid_to_inner(&id);
        let balance_amount = CoinModule::value(&token_to_loan);
        let balance = CoinModule::into_balance(token_to_loan);

        let loan = FlashLoan {
            id,
            lender,
            balance,
            fee,
        };

        // Emit an event for loan creation
        EventModule::emit(FlashLoanEvent {
            flash_loan_id: loan_inner_id,
            balance: balance_amount,
            action: 1, //create
            lender,
            borrower: lender,
        });

        transfer::share_object(loan);
    }
    
    public fun apply_loan<T>(loan: &mut FlashLoan<T>, amount: u64, ctx: &mut TxContext): (Coin<T>, LoanRecord<T>) {
        let balance = &mut loan.balance;
        assert!(BalanceModule::value(balance) >= amount, EBalanceNotEnough);
        let loan_coin = CoinModule::take(balance, amount, ctx);
        let repay_amount = amount + loan.fee;

        // Emit an event for loan apply
        EventModule::emit(FlashLoanEvent {
            flash_loan_id: ObjectModule::id(loan),
            balance: BalanceModule::value(&loan.balance),
            action: 2, //loan
            lender: loan.lender,
            borrower: TxContextModule::sender(ctx),
        });

        (loan_coin, LoanRecord {
            flash_loan_id: ObjectModule::id(loan),
            repay_amount: repay_amount,
        })
    }

    // Function to apply for a flash loan
    public fun repay_loan<T>(loan: &mut FlashLoan<T>, loan_record: LoanRecord<T>, repay_coin: Coin<T>, ctx: &mut TxContext) {
        let LoanRecord { flash_loan_id, repay_amount } = loan_record;
        assert!(flash_loan_id ==  ObjectModule::id(loan), EIncorrectLoan);
        assert!(CoinModule::value(&repay_coin) == repay_amount, EIncorrectRepayAmound);
        CoinModule::put(&mut loan.balance, repay_coin);

        // Emit an event for loan repay
        EventModule::emit(FlashLoanEvent {
            flash_loan_id: ObjectModule::id(loan),
            balance: BalanceModule::value(&loan.balance),
            action: 3, //repay
            lender: loan.lender,
            borrower: TxContextModule::sender(ctx),
        });
    }

    // Function to withdraw funds from the flash loan contract
    public fun withdraw<T>(loan: &mut FlashLoan<T>, withdraw_amount: u64, ctx: &mut TxContext): Coin<T> {
        check_lender(loan, ctx);
        let balance = &mut loan.balance;
        assert!(BalanceModule::value(balance) >= withdraw_amount, EBalanceNotEnough);
        CoinModule::take(balance, withdraw_amount, ctx)
    }

    // Function to deposit funds into the flash loan contract
    public entry fun deposit<T>(loan: &mut FlashLoan<T>, deposit_coin: Coin<T>, ctx: &mut TxContext) {
        check_lender(loan, ctx);
        CoinModule::put(&mut loan.balance, deposit_coin);
    } 

    fun check_lender<T>(loan: &FlashLoan<T>, ctx: &TxContext) {
        let  lender = TxContextModule::sender(ctx);
        assert!(lender == loan.lender, EIncorrectLender);
    }

    public entry fun update_fee<T>(loan: &mut FlashLoan<T>, fee: u64, ctx: &mut TxContext) {
        check_lender(loan, ctx);
        loan.fee = fee;
    }

    public fun get_fee<T>(loan: &FlashLoan<T>): u64 {
        loan.fee
    }

    public fun get_balance<T>(loan: &FlashLoan<T>): u64 {
        BalanceModule::value(&(loan.balance))
    }

    // Test scenario for the flash loan contract
    #[test]
    fun test() {
        let (lender, borrower) = (@0x1, @0x2);
        let scenario = test_scenario::begin(lender);

        // Lender creates a loan
        {
            let ctx = test_scenario::ctx(&mut scenario);
            let coin = CoinModule::mint_for_testing<SUI>(100, ctx);
            create_loan(coin, 1, ctx);
        };

        // Borrower applies for, uses, and repays the loan
        test_scenario::next_tx(&mut scenario, borrower);
        {
            let loan = test_scenario::take_shared<FlashLoan<SUI>>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            let (loan_coin, loan_record) = apply_loan(&mut loan, 10, ctx);
            let repay_coin = CoinModule::mint_for_testing<SUI>(1, ctx);
            CoinModule::join(&mut repay_coin, loan_coin);
            repay_loan(&mut loan, loan_record, repay_coin, ctx);
            assert!(BalanceModule::value(&(loan.balance)) == 101, 0);

            test_scenario::return_shared(loan);
        };

        // Lender checks and manages the loan
        test_scenario::next_tx(&mut scenario, lender);
        {
            let loan = test_scenario::take_shared<FlashLoan<SUI>>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            
            assert!(get_balance(&loan) == 101, 0);

            let coin = withdraw(&mut loan, 10, ctx);
            assert!(get_balance(&loan) == 91, 0);
            
            deposit(&mut loan, coin, ctx);
            assert!(get_balance(&loan) == 101, 0);

            update_fee(&mut loan, 2, ctx);
            assert!(get_fee(&loan) == 2, 0);
            
            test_scenario::return_shared(loan);
        };
        test_scenario::end(scenario);
    }
}
