module bank::bank {
    use std::type_name::{Self, TypeName};
    use std::ascii::{ String};
    use sui::transfer;
    use sui::vec_set::{Self, VecSet};
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::bag::{Self, Bag};
    use sui::balance::{Self, Balance};
    use sui::ed25519;
    use sui::dynamic_field as df;

    const EInvalidAmount: u64 = 1;
    const EInvalidSignature: u64 = 2;
    const EInsufficientBalance: u64 = 3;
    const EExistCurrency: u64 = 4;
    const ENotExistCurrency: u64 = 5;

    struct SimpleBank has key {
        id: UID,
    }

    struct AllowCurrency has key {
        id: UID,
    }

    struct TypeCurrency<phantom T> has copy, drop, store { }


    struct EventDeposit<phantom CoinType> has copy, drop {
        depositor: address,
        token: String,
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
            },
        );
        transfer::share_object(
            AllowCurrency {
                id: object::new(ctx),
            },
        )
    }

    public entry fun addAllowCurrency<CoinType>(
        allowCurrency: &mut AllowCurrency,
    ) {
        df::add(&mut allowCurrency.id, TypeCurrency<CoinType> {}, true);
    }

    public entry fun removeAllowCurrency<CoinType>(
        allowCurrency: &mut AllowCurrency,
    ) {
        let value : bool = df::remove(&mut allowCurrency.id, TypeCurrency<CoinType> {});
    }

    public entry fun deposit<CoinType: drop>(
        allowCurrency: &AllowCurrency,
        simpleBank: &mut SimpleBank,
        token: &mut Coin<CoinType>,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        let depositor = tx_context::sender(ctx);
        assert!(
            df::exists_(&allowCurrency.id, TypeCurrency<CoinType> {}),
            ENotExistCurrency,
        );
        let value = coin::value(token);
        assert!(value >= amount, EInvalidAmount);

        let paid = coin::split(token, amount, ctx);
        let amountAfterFee;

        if (df::exists_(&simpleBank.id, TypeCurrency<CoinType> {})) {
            let balance: &mut Coin<CoinType> = df::borrow_mut(&mut simpleBank.id, TypeCurrency<CoinType> {});
            let amountBeforeDeposit = coin::value(balance);
            coin::join(balance, paid);
            let amountAfterDeposit = coin::value(balance);
            amountAfterFee = amountAfterDeposit - amountBeforeDeposit;
        } else {
            df::add(&mut simpleBank.id, TypeCurrency<CoinType> {}, paid);
            let balance: &Coin<CoinType> = df::borrow(&simpleBank.id, TypeCurrency<CoinType> {});
            amountAfterFee = coin::value(balance);
        };
        let fee = amountAfterFee - amount;

        event::emit(EventDeposit<CoinType> {
            depositor,
            token: type_name::get<CoinType>().name,
            amount,
            fee,
        });
    }

    // public entry fun withdraw<T: drop>(
    //     simpleBank: &mut SimpleBank,
    //     amount: u64,
    //     currency: address,
    //     signature: vector<u8>,
    //     message: vector<u8>,
    //     public_key: vector<u8>,
    //     requestId: u64,
    //     ctx: &mut TxContext,
    // ) {
    //     assert!(
    //         ed25519::ed25519_verify(&signature, &public_key, &message),
    //         EInvalidSignature,
    //     );
    //     assert!(amount > 0, EInvalidAmount);
    //     let sender = tx_context::sender(ctx);

    //     let balance: &mut Balance<T> = bag::borrow_mut(&mut simpleBank.balances, currency);
    //     assert!(balance::value(balance) >= amount, EInsufficientBalance);

    //     let withdrawBalance = balance::split(balance, amount);

    //     let takeCoin = coin::from_balance(withdrawBalance, ctx);
    //     transfer::public_transfer(takeCoin, sender);

    //     event::emit(EventWithdraw {
    //         user: sender,
    //         token: currency,
    //         amount,
    //         requestId,
    //     });
    // }
}