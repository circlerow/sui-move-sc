module bank::bank {
    use sui::transfer;
    use sui::vec_set::{Self, VecSet};
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::bag::{Self, Bag};
    use sui::balance::{Self, Balance};
    use sui::ed25519;

    const EInvalidAmount: u64 = 1;
    const EInvalidSignature: u64 = 2;
    const EInsufficientBalance: u64 = 3;
    const EExistCurrency: u64 = 4;
    const ENotExistCurrency: u64 = 5;

    struct SimpleBank has key {
        id: UID,
        balances: Bag,
    }

    struct AllowCurrency has key {
        id: UID,
        typeCurrency: VecSet<address>,
    }

    struct AdminCap has key, store {
        id: UID,
        admin: address,
    }

    struct EventDeposit has copy, drop {
        depositor: address,
        token: address,
        amount: u64,
        fee: u64,
    }

    struct EventWithdraw has copy, drop {
        user: address,
        token: address,
        amount: u64,
        requestId: u64,
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            SimpleBank {
                id: object::new(ctx),
                balances: bag::new(ctx),
            },
        );
        transfer::share_object(
            AllowCurrency {
                id: object::new(ctx),
                typeCurrency: vec_set::empty(),
            },
        );
        transfer::public_transfer(
            AdminCap {
                id: object::new(ctx),
                admin: tx_context::sender(ctx),
            },
            tx_context::sender(ctx),
        )
    }

    public entry fun addAllowCurrency(
        _ : &AdminCap,
        allowCurrency: &mut AllowCurrency,
        typeCurrency: address,
    ) {
        assert!(
            !vec_set::contains(&allowCurrency.typeCurrency, &typeCurrency),
            EExistCurrency,
        );
        vec_set::insert(&mut allowCurrency.typeCurrency, typeCurrency);
    }

    public entry fun removeAllowCurrency(
        _ : &AdminCap,
        allowCurrency: &mut AllowCurrency,
        typeCurrency: address,
    ) {
        assert!(
            vec_set::contains(&allowCurrency.typeCurrency, &typeCurrency),
            ENotExistCurrency,
        );
        vec_set::remove(&mut allowCurrency.typeCurrency, &typeCurrency);
    }

    public entry fun deposit<T: drop>(
        allowCurrency: &AllowCurrency,
        simpleBank: &mut SimpleBank,
        token: &mut Coin<T>,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        let depositor = tx_context::sender(ctx);
        let currency = object::id_address(token);
        assert!(
            vec_set::contains(&allowCurrency.typeCurrency, &currency),
            ENotExistCurrency,
        );
        let value = coin::value(token);
        assert!(value >= amount, EInvalidAmount);

        let paid = coin::split(token, amount, ctx);
        let amountAfterFee;

        if (bag::contains(&simpleBank.balances, currency)) {
            let balance = bag::borrow_mut(&mut simpleBank.balances, currency);
            let balanceBefore = balance::value(balance);
            balance::join(balance, coin::into_balance(paid));
            let balanceAfter = balance::value(balance);
            amountAfterFee = balanceAfter - balanceBefore;
        } else {
            bag::add(&mut simpleBank.balances, currency, coin::into_balance(paid));
            let balance: &Balance<T> = bag::borrow(&simpleBank.balances, currency);
            let balanceAfter = balance::value(balance);
            amountAfterFee = balanceAfter;
        };
        let fee = amount - amountAfterFee;

        event::emit(EventDeposit {
            depositor,
            token: currency,
            amount,
            fee,
        });
    }

    public entry fun withdraw<T: drop>(
        simpleBank: &mut SimpleBank,
        amount: u64,
        currency: address,
        signature: vector<u8>,
        message: vector<u8>,
        public_key: vector<u8>,
        requestId: u64,
        ctx: &mut TxContext,
    ) {
        assert!(
            ed25519::ed25519_verify(&signature, &public_key, &message),
            EInvalidSignature,
        );
        assert!(amount > 0, EInvalidAmount);
        let sender = tx_context::sender(ctx);

        let balance: &mut Balance<T> = bag::borrow_mut(&mut simpleBank.balances, currency);
        assert!(balance::value(balance) >= amount, EInsufficientBalance);

        let withdrawBalance = balance::split(balance, amount);

        let takeCoin = coin::from_balance(withdrawBalance, ctx);
        transfer::public_transfer(takeCoin, sender);

        event::emit(EventWithdraw {
            user: sender,
            token: currency,
            amount,
            requestId,
        });
    }
}