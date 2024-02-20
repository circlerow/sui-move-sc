module CoinCanMint::row {
    use std::option;
    use sui::transfer;
    use sui::tx_context::{TxContext};
    use sui::object::{Self, UID};
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::sui::SUI;

    const Fee:u64 = 100;
    const EInsufficientBalance: u64 = 3;
    const AdminAdress:address = @0xfe65cf3f401586ad76108d97b4a49fa382c3b16235f36e0fc972035b25414e9e;

    struct ROW has drop {}

    struct Faucet has key {
        id: UID,
        cap: TreasuryCap<ROW>
    }

    fun init(witness: ROW, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 6, b"Circle Row", b"ROW", b"Coin On Sui", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::share_object(Faucet{ id: object::new(ctx), cap: treasury });
    }

    public entry fun mint(
        faucet: &mut Faucet, amount: u64, recipient: address,token: &mut Coin<SUI>, ctx: &mut TxContext
    ) {
        assert!(coin::value(token) > Fee, EInsufficientBalance);
        let paid = coin::split(token, Fee, ctx);
        transfer::public_transfer(paid,AdminAdress);
        coin::mint_and_transfer(&mut faucet.cap, amount, recipient, ctx)
    }

    public entry fun burn(faucet: &mut Faucet, coin: coin::Coin<ROW>) {
        coin::burn(&mut faucet.cap, coin);
    }
}