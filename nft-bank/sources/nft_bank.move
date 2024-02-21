module nft_bank::nft_bank {
    use sui::transfer::{Self};
    use sui::object::{Self,ID};
    use sui::tx_context::{Self,TxContext};
    use sui::bag::{Bag, Self};

    const ENotExistedSender: u64 = 2;
    
    struct NftBank has key {
        id: object::UID,
        nft: Bag,
    }

    struct NftInfo<T: key+ store> has store {
        owner: address,
        nft: T
    }   

    fun init(ctx: &mut TxContext) {
        transfer::share_object( NftBank {
            id: object::new(ctx),
            nft: bag::new(ctx),
        });
    }

    public entry fun depositNFT<T: key + store>(
        nft_bank: &mut NftBank,
        nft: T,
        ctx: &mut TxContext
    ){
        let nft_id = object::id(&nft);
        let nft_info = NftInfo {
            owner: tx_context::sender(ctx),
            nft: nft
        };
        bag::add(&mut nft_bank.nft, nft_id, nft_info);
    }

    public entry fun withdrawNFT<T: key+ store>(
        nft_bank: &mut NftBank,
        nft_id: ID,
        ctx: &mut TxContext
    ) {
        let NftInfo<T> {
            owner,
            nft
            } = bag::remove(&mut nft_bank.nft, nft_id);
        let sender = tx_context::sender(ctx);
        assert!(owner==sender, ENotExistedSender);
        transfer::public_transfer(nft, sender);
    }    
}