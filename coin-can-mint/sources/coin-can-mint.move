module CoinCanMint::row {
    use std::option;
    use sui::coin::{Self, TreasuryCap};
    use sui::transfer;
    use sui::tx_context::{TxContext};
    use sui::object::{Self, UID};

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
        faucet: &mut Faucet, amount: u64, recipient: address, ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(&mut faucet.cap, amount, recipient, ctx)
    }

    public entry fun burn(faucet: &mut Faucet, coin: coin::Coin<ROW>) {
        coin::burn(&mut faucet.cap, coin);
    }
}