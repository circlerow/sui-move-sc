module bank::bank {
    use std::ascii::{String};
    use std::type_name;
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::event;
    use sui::dynamic_field as df;
    use sui::ed25519;

    const EInvalidAmount: u64 = 1;
    const EInsufficientBalance: u64 = 2;
    const ENotExistCurrency: u64 = 3;
    const EInvalidSignature: u64 = 4;

    struct SimpleBank has key {
        id: UID,
    }

    struct AllowCurrency has key {
        id: UID,
    }

    struct TypeCurrency<phantom T> has copy, drop, store { }

    struct AdminCap has key, store {
        id:UID,
    }


    struct EventDeposit<phantom CoinType> has copy, drop {
        depositor: address,
        token: String,
        amount: u64,
        fee: u64,
    }

    struct EventWithdraw has copy, drop {
        user: address,
        token: String,
        amount: u64,
        requestId: vector<u8>,
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
        );
        transfer::public_transfer(
            AdminCap {
                id: object::new(ctx),
            },
            tx_context::sender(ctx),
        );
    }

    public entry fun addAllowCurrency<CoinType>(
        _ : &AdminCap,
        allowCurrency: &mut AllowCurrency,
    ) {
        df::add(&mut allowCurrency.id, TypeCurrency<CoinType> {}, true);
    }

    public entry fun removeAllowCurrency<CoinType>(
        _ : &AdminCap,
        allowCurrency: &mut AllowCurrency,
    ) {
        let _:bool = df::remove(&mut allowCurrency.id, TypeCurrency<CoinType> {});
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
            let coin: &mut Coin<CoinType> = df::borrow_mut(&mut simpleBank.id, TypeCurrency<CoinType> {});
            let amountBeforeDeposit = coin::value(coin);
            coin::join(coin, paid);
            let amountAfterDeposit = coin::value(coin);
            amountAfterFee = amountAfterDeposit - amountBeforeDeposit;
        } else {
            df::add(&mut simpleBank.id, TypeCurrency<CoinType> {}, paid);
            let balance: &Coin<CoinType> = df::borrow(&simpleBank.id, TypeCurrency<CoinType> {});
            amountAfterFee = coin::value(balance);
        };
        let fee = amountAfterFee - amount;
        let type_name = type_name::get<CoinType>();

        event::emit(EventDeposit<CoinType> {
            depositor,
            token: type_name::into_string(type_name),
            amount,
            fee,
        });
    }

    public entry fun withdraw<CoinType>(
        simpleBank: &mut SimpleBank,
        amount: u64,
        signature: vector<u8>,
        message: vector<u8>,
        public_key: vector<u8>,
        requestId: vector<u8>,
        ctx: &mut TxContext,
    ) {
        let sender = tx_context::sender(ctx);
        let coin: &mut Coin<CoinType> = df::borrow_mut(&mut simpleBank.id, TypeCurrency<CoinType> {});
        assert!(coin::value(coin) >= amount, EInsufficientBalance);

        let is_verify = ed25519::ed25519_verify(&signature, &public_key, &message );
        assert!(is_verify, EInvalidSignature);

        let withdrawCoin = coin::split(coin, amount, ctx);

        transfer::public_transfer(withdrawCoin, sender);
        let type_name = type_name::get<CoinType>();

        event::emit(EventWithdraw {
            user: sender,
            token: type_name::into_string(type_name),
            amount,
            requestId,
        });
    }
}