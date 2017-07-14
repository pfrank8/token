# Wolk Protocol Token - Decentralized Data Exchange

Digital advertising is dominated by Facebook and Google. This centralized oligopoly is sharing consumer data
with no one, causing publishers and advertisers to lose revenue and targeting capabilities outside of Facebook
and Google, while consumers and businesses are earning nothing despite their direct participation in their
network effects. Existing avenues for owners of data to benefit from data have become very limited due to privacy
and trust considerations. Ethereum-based smart tokens in conjunction with decentralized data storage, however,
can help solve these limitations. The Wolk Protocol supports decentralized data exchange using decentralized
virtual currency keyed in by IDs, enabling data buyers and data sellers to obtain information about IDs such as
mobile device IDs, emails and phone numbers. Wolk APIs use a new Ethereum-based token called "WOLK". In
the Wolk Protocol, data buyers spend WOLK tokens to acquire data about specific IDs via APIs and data
suppliers earn WOLK for data delivered to buyers using those APIs.  

The WOLK smart token contract (in this repository in `contracts`) enables:
* `tokenGenerationEvent`: contributors to help evolve the Wolk Protocol by sending ETH to the contract in exchange for WOLK during a crowdsale conducted between August 28, 2017 and September 28, 2017
* `purchaseWolk`: for data buyers to buy WOLK using ETH 
* `sellWolk`: for data suppliers to sell WOLK in exchange for ETH
and uses the Bancor formula to automatically compute exchange rates in conjunction with a 20% ETH reserve.  

In ordinary operations between API service providers and API users, several functions are essential:
* `authorizeProvider`, `deauthorizeProvider`, `grantService`, `removeService`: API users call these to authorize/deauthorize API service providers
* `settleBuyer`, `settleSeller`: API service providers record usage of their service as data is transmitted between buyers and sellers

## More Information
* Wolk White Paper: http://wolk.com/whitepaper/WolkTokenCrowdsale-20170712.pdf
* Wolk API Docs: http://docs.wolk.apiary.io/
* Wolk Web Site: https://wolk.com
