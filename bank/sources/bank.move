module bank::bank{
    use sui::transfer;
    use sui::sui::SUI;
    use sui::object::{Self, UID};
    use sui::vec_map::{Self, VecMap};
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::event;

    const EInvalidAmount: u64 = 1;
    const ENotExistedSender: u64 = 2;
    const EInsufficientBalance: u64 = 3;

    struct SimpleBank has key {
        id: UID,
        balances: VecMap<address, Balance<SUI>>,
    }

    struct EventDeposit has copy, drop {
        sender: address,
        amount: u64,
        balance: u64
    }

    struct EventWithdraw has copy, drop {
        sender: address,
        amount: u64,
        balance: u64
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            SimpleBank {
                id: object::new(ctx),
                balances: vec_map::empty()
            }
        );
    }

    public entry fun deposit (
        simpleBank: &mut SimpleBank, 
        amount: &mut Coin<SUI>, 
        ctx: &mut TxContext) {

        assert!(coin::value(amount) > 0, EInvalidAmount);

        let value = coin::value(amount);
        let paid = coin::split(amount, value, ctx);

        let sender = tx_context::sender(ctx);

        let totalBalance;

        if ( vec_map::contains(&simpleBank.balances, &sender) ) {
            let myBalance = vec_map::get_mut(&mut simpleBank.balances, &sender);
            totalBalance = balance::join(myBalance, coin::into_balance(paid));
        } else {
            vec_map::insert(&mut simpleBank.balances, sender, coin::into_balance(paid));
            totalBalance = value;
        };


        event::emit(EventDeposit{
            sender,
            amount: value,
            balance: totalBalance
        });
    }

    public entry fun withdraw (
        simpleBank: &mut SimpleBank, 
        amount: u64, 
        ctx: &mut TxContext) {

        assert!(amount > 0, EInvalidAmount);

        let sender = tx_context::sender(ctx);
        assert!(vec_map::contains(&simpleBank.balances, &sender), ENotExistedSender);

        let myBalance = vec_map::get(&simpleBank.balances, &sender);
        assert!(balance::value(myBalance) >= amount, EInsufficientBalance);

        let myBalance = vec_map::get_mut(&mut simpleBank.balances, &sender);

        let withdrawBalance = balance::split(myBalance, amount);

        let takeCoin = coin::from_balance(withdrawBalance, ctx);
        transfer::public_transfer(takeCoin, sender);

        event::emit(EventWithdraw{
            sender,
            amount,
            balance: balance::value(myBalance) 
        });
    }
}