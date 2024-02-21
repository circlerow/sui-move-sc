module nft::nft {

    use std::string;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    const Fee:u64 = 100;
    const EInsufficientBalance: u64 = 3;
    const AdminAdress:address = @0xfe65cf3f401586ad76108d97b4a49fa382c3b16235f36e0fc972035b25414e9e;
 
    struct NFT has key, store {
        id: UID, 
        name: string::String, 
        description: string::String
    }

    public entry fun mint(name: vector<u8>, description: vector<u8>, token: &mut Coin<SUI>, ctx: &mut TxContext) {
        assert!(coin::value(token) > Fee, EInsufficientBalance);
        let paid = coin::split(token, Fee, ctx);
        transfer::public_transfer(paid,AdminAdress);

        let nft = NFT {
            id: object::new(ctx),
            name: string::utf8(name),
            description: string::utf8(description),
        };

        let sender = tx_context::sender(ctx);
        transfer::public_transfer(nft, sender);
    }

    #[allow(lint(custom_state_change))]
    public entry fun transfer(nft: NFT, recipient: address) {
        transfer::transfer(nft, recipient);
    }
}
