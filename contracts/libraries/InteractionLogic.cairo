%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.cairo_builtins import BitwiseBuiltin
from starkware.cairo.common.uint256 import Uint256, uint256_not
from starkware.cairo.common.cairo_keccak.keccak import keccak_uint256s, keccak_felts, finalize_keccak
from starkware.cairo.common.math import assert_not_zero, assert_nn, split_felt
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address, get_block_timestamp

from libraries.DataTypes import DataTypes
from interfaces.IFollowModule import IFollowModule
from interfaces.IFollowNFT import IFollowNFT

from libraries.PublishingLogic import get_profile_by_id, get_profile_by_hh

#to be refactored. For MVP/Demo purposes we are about to use Only Dust Stream library 
#from onlydust.stream.default_implementation import stream

#
# Events
#


#  * @dev Emitted upon a successful follow action.
#  *
#  follower The address following the given profiles.
#  profileIds The token ID array of the profiles being followed.
#  followModuleDatas The array of data parameters passed to each follow module.
#  timestamp The current block timestamp.

@event
func Followed(
    follower : felt,
    profile_ids : Uint256*,
    folow_module_datas : felt*,
    timestamp : felt
end

#  * @dev Emitted upon a successful collect action.
#  *
#  collector The address collecting the publication.
#  profileId The token ID of the profile that the collect was initiated towards, useful to differentiate mirrors.
#  pubId The publication ID that the collect was initiated towards, useful to differentiate mirrors.
#  rootProfileId The profile token ID of the profile whose publication is being collected.
#  rootPubId The publication ID of the publication being collected.
#  collectModuleData The data passed to the collect module.
#  timestamp The current block timestamp.

# @event
# func Collected(
#     collector : felt,
#     profile_id : Uint256,
#     pub_id : Uint256,
#     root_profile_id : Uint256,
#     root_pub_id : Uint256,
#     collect_module_data : felt,
#     timestamp : felt
# end

# * @dev Emitted when a followNFT clone is deployed using a lazy deployment pattern.
# *
# profileId The token ID of the profile to which this followNFT is associated.
# followNFT The address of the newly deployed followNFT clone.
# timestamp The current block timestamp.

@event
func FollowNFTDeployed(
    profile_id : felt,
    follow_nft : felt,
    timestamp : felt
end

#  * @dev Emitted when a collectNFT clone is deployed using a lazy deployment pattern.
#  *
#  profileId The publisher's profile token ID.
#  pubId The publication associated with the newly deployed collectNFT clone's ID.
#  collectNFT The address of the newly deployed collectNFT clone.
#  timestamp The current block timestamp.

# @event
# func CollectNFTDeployed(
#     profile_id : Uint256,
#     pub_id : Uint256,
#     collect_nft : felt,
#     timestamp : felt
# end

# 
# Storage
#

@storage_var
func profile_id_by_hh_storage(handle : Uint256) -> (profile_id_by_hh_storage : Uint256):
end

@storage_var
func profile_by_id(profile_id : Uint256) -> (profileStruct : DataTypes.ProfileStruct):
end


#
# Internal
#
func get_keccak_hash{
    syscall_ptr : felt*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    bitwise_ptr : BitwiseBuiltin*
    }(value_to_hash : felt) -> (hashed_value : Uint256):
    alloc_locals
    let (local keccak_ptr_start) = alloc()
    let keccak_ptr = keccak_ptr_start
    let (local arr : felt*) = alloc()
    assert arr[0] = value_to_hash
    let (hashed_value) = keccak_felts{keccak_ptr=keccak_ptr}(1, arr)
    finalize_keccak(keccak_ptr_start=keccak_ptr_start, keccak_ptr_end=keccak_ptr)
    return (hashed_value)
end


#to be refactored. For MVP/Demo purposes we are about to use Only Dust Stream library  

func follow{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, bitwise_ptr : BitwiseBuiltin*
    }(follower : felt, profile_id : Uint256, follow_module_data : felt) -> (retval : Uint256*):
    alloc_locals

    # with_attr error_message("Profile IDs and Follow Module Array lengths mismatch"):
    #     assert profile_ids_lengths = follow_module_datas_lengths
    # end

    # keccak256 - Ilyas knows ;)
    let (profile : DataTypes.ProfileStruct) = get_profile_by_id(profile_id)

    let (handle : felt) = profile.handle
    
    let (handle_hash : felt) = get_keccak_hash(handle)
    let (profile_id_by_hh : Uint256) = get_profile_by_hh(handle_hash)
    

    with_attr error_message("Profile ID by Handle Hash != 0"):
	    assert profile_id = profile_id_by_hh
    end

    let (follow_module : felt) = profile.follow_module

    let (follow_nft : felt) = profile.follow_nft

    #     # we cannot use following approach as we need to write whole structure
    #     # ideally deploy Follow NFT with Profile NFT
    # if follow_nft == 0:
    #     let (follow_nft : felt) = _deploy_follow_nft(profile_id)

    #     # we cannot use following approach as we need to write whole structure
    #     # ideally deploy Follow NFT with Profile NFT
    #     # profile_by_id.write(profile_id, follow_nft)
    # end

    let (follow_token_id : Uint256) = IFollowNFT.mint(follower)

    if follow_module != 0:
        IFollowModule.process_follow(follower, profile_id, follow_module_data)
    end

    let (timestamp : felt) = get_block_timestamp()
    # Emit

    Followed.emit(follower, profile_id, follow_module_data, timestamp)

    # Return

    return (follow_token_id)

end

# func _deploy_follow_nft(
