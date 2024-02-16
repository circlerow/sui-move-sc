module coin::row {
    use std::option;
    use sui::coin;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct ROW has drop {}

    fun init(witness: ROW, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 6, b"Circle Row", b"ROW", b"Coin On Sui", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx))
    }

    public entry fun mint(
        treasury: &mut coin::TreasuryCap<ROW>, amount: u64, recipient: address, ctx: &mut TxContext
    ) {
        coin::mint_and_transfer(treasury, amount, recipient, ctx)
    }

    public entry fun burn(treasury: &mut coin::TreasuryCap<ROW>, coin: coin::Coin<ROW>) {
        coin::burn(treasury, coin);
    }
}