pragma solidity ^0.4.13;

// SafeMath Taken From FirstBlood
contract SafeMath {
    function safeMul(uint a, uint b) internal returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function safeDiv(uint a, uint b) internal returns (uint) {
        assert(b > 0);
        uint c = a / b;
        assert(a == b * c + a % b);
        return c;
    }

    function safeSub(uint a, uint b) internal returns (uint) {
        assert(b <= a);
        return a - b;
    }

    function safeAdd(uint a, uint b) internal returns (uint) {
        uint c = a + b;
        assert(c>=a && c>=b);
        return c;
    }
}


contract Owned {

    address public owner;
    address public newOwner;
    modifier onlyOwner { assert(msg.sender == owner); _; }

    event OwnerUpdate(address _prevOwner, address _newOwner);

    function Owned() {
        owner = msg.sender;
    }

    function transferOwnership(address _newOwner) public onlyOwner {
        require(_newOwner != owner);
        newOwner = _newOwner;
    }

    function acceptOwnership() public {
        require(msg.sender == newOwner);
        OwnerUpdate(owner, newOwner);
        owner = newOwner;
        newOwner = 0x0;
    }
}

// ERC20 Interface
contract ERC20 {
    function totalSupply() constant returns (uint totalSupply);
    function balanceOf(address _owner) constant returns (uint balance);
    function transfer(address _to, uint _value) returns (bool success);
    function transferFrom(address _from, address _to, uint _value) returns (bool success);
    function approve(address _spender, uint _value) returns (bool success);
    function allowance(address _owner, address _spender) constant returns (uint remaining);
    event Transfer(address indexed _from, address indexed _to, uint _value);
    event Approval(address indexed _owner, address indexed _spender, uint _value);
}

// ERC20Token
contract ERC20Token is ERC20, SafeMath {

    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
    uint256 public totalTokens; 

    function transfer(address _to, uint256 _value) returns (bool success) {
        if (balances[msg.sender] >= _value && _value > 0) {
            balances[msg.sender] = safeSub(balances[msg.sender], _value);
            balances[_to] = safeAdd(balances[_to], _value);
            Transfer(msg.sender, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    function transferFrom(address _from, address _to, uint256 _value) returns (bool success) {
        var _allowance = allowed[_from][msg.sender];
        if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
            balances[_to] = safeAdd(balances[_to], _value);
            balances[_from] = safeSub(balances[_from], _value);
            allowed[_from][msg.sender] = safeSub(_allowance, _value);
            Transfer(_from, _to, _value);
            return true;
        } else {
            return false;
        }
    }

    function totalSupply() constant returns (uint256) {
        return totalTokens;
    }

    function balanceOf(address _owner) constant returns (uint256 balance) {
        return balances[_owner];
    }

    function approve(address _spender, uint256 _value) returns (bool success) {
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }
}

contract Wolk is ERC20Token, Owned {

    // TOKEN INFO
    string  public constant name = "Wolk Protocol Token";
    string  public constant symbol = "Wolk";
    uint256 public constant decimals = 18;

    // RESERVE
    uint256 public reserveBalance = 0; 
    uint8  public constant percentageETHReserve = 20;

    // CONTRACT DETAIL
    address public multisigWallet;

    // WOLK SETTLERS
    mapping (address => bool) settlers;
    modifier onlySettler { assert(settlers[msg.sender] == true); _; }

    // TOKEN GENERATIO CONTROL
    bool    public saleCompleted = false;
    modifier isTransferable { assert(saleCompleted); _; }

    // TOKEN GENERATION EVENTLOG
    event WolkCreated(address indexed _to, uint256 _tokenCreated);
    event WolkDestroyed(address indexed _from, uint256 _tokenDestroyed);
    event LogRefund(address indexed _to, uint256 _value);
}

contract WolkTGE is Wolk {

    // TOKEN GENERATION EVENT
    mapping (address => uint256) contribution;
    mapping (address => uint256) presaleLimit;
    mapping (address => bool) presaleContributor;
    uint256 public constant tokenGenerationMin = 10**3 * 10**decimals;
    uint256 public constant tokenGenerationMax = 50 * 10**3 * 10**decimals;
    uint256 public presale_start_block; 
    uint256 public start_block;
    uint256 public end_block;

    // @param _presaleStartBlock
    // @param _startBlock
    // @param _endBlock
    // @param _wolkWallet
    // @return success
    // @dev Wolk Genesis Event [only accessible by Contract Owner]
    function wolkGenesis(uint256 _presaleStartBlock, uint256 _startBlock, uint256 _endBlock, address _wolkWallet) onlyOwner returns (bool success){
        require( (totalTokens < 1) && (block.number <= _startBlock) && (_endBlock > _startBlock) && (_startBlock > _presaleStartBlock ) );
        presale_start_block = _presaleStartBlock;
        start_block = _startBlock;
        end_block = _endBlock;
        multisigWallet = _wolkWallet;
        settlers[msg.sender] = true;
        return true;
    }

    // @param _presaleParticipants
    // @return success
    // @dev Adds addresses that are allowed to take part in presale [only accessible by current Contract Owner]
    function addParticipant(address[] _presaleParticipants, uint256[] _contributionLimits) onlyOwner returns (bool success) {
        require(_presaleParticipants.length == _contributionLimits.length);         
        for (uint cnt = 0; cnt < _presaleParticipants.length; cnt++){           
            presaleContributor[_presaleParticipants[cnt]] = true;
            presaleLimit[_presaleParticipants[cnt]] =  safeMul(_contributionLimits[cnt], 10**decimals);       
        }
        return true;
    } 

    // @param _presaleParticipants
    // @return success
    // @dev Revoke designated presale contributors [only accessible by current Contract Owner]
    function removeParticipant(address[] _presaleParticipants) onlyOwner returns (bool success){         
        for (uint cnt = 0; cnt < _presaleParticipants.length; cnt++){           
            presaleContributor[_presaleParticipants[cnt]] = false;
            presaleLimit[_presaleParticipants[cnt]] = 0;      
        }
        return true;
    }

    // @dev Token Generation Event for Wolk Protocol Token. TGE Participant send Eth into this func in exchange of Wolk Protocol Token
    function tokenGenerationEvent(address _participant) payable external {

        require(!saleCompleted && (block.number <= end_block) && msg.value > 0);
        
        if (presaleContributor[_participant] && (block.number < start_block) && (block.number >= presale_start_block)) {
            //restricted to early participants. Min of 2 eth required
            require(msg.value >= 2 ether && presaleLimit[_participant] >= msg.value);
            var isPresale = true;
        }else{
            //open to all
            require( block.number >= start_block ) ;            
        }

        uint256 tokens = safeMul(msg.value, 1000); //exchange rate
        uint256 checkedSupply = safeAdd(totalTokens, tokens);
        require(checkedSupply <= tokenGenerationMax);
        if (isPresale){
            presaleLimit[_participant] = safeSub(presaleLimit[_participant], msg.value);
        }
        totalTokens = checkedSupply;
        Transfer(address(this), _participant, tokens);
        balances[_participant] = safeAdd(balances[_participant], tokens);  
        contribution[_participant] = safeAdd(contribution[_participant], msg.value);  
        WolkCreated(_participant, tokens); // logs token creation
    }

    // @dev If Token Generation Minimum is Not Met, TGE Participants can call this func and request for refund
    function refund() external {
        require( (contribution[msg.sender] > 0) && (!saleCompleted) && (totalTokens < tokenGenerationMin) && (block.number > end_block) );
        uint256 tokenBalance = balances[msg.sender];
        uint256 refundBalance = contribution[msg.sender];
        balances[msg.sender] = 0;
        contribution[msg.sender] = 0;
        totalTokens = safeSub(totalTokens, tokenBalance);
        WolkDestroyed(msg.sender, tokenBalance);
        LogRefund(msg.sender, refundBalance);
        msg.sender.transfer(refundBalance); 
    }

    // @dev Finalizing the Token Generation Event. 20% of Eth will be kept in contract to provide liquidity
    function finalize() onlyOwner {
        require( (!saleCompleted) && (totalTokens >= tokenGenerationMin) );
        saleCompleted = true;
        end_block = block.number;
        reserveBalance = safeDiv(safeMul(this.balance, percentageETHReserve), 100);
        var withdrawalBalance = safeSub(this.balance, reserveBalance);
        msg.sender.transfer(withdrawalBalance);
    }

}

contract WolkProtocol is Wolk {

    // WOLK NETWORK PROTOCOL
    uint256 public burnBasisPoints = 500;  // Burn rate (in BP) when Service Provider withdraws from data buyers’ accounts
    mapping (address => mapping (address => bool)) authorized; // holds which accounts have approved which Service Providers
    mapping (address => uint256) feeBasisPoints;   // Fee (in BP) earned by Service Provider when depositing to data seller 

    // WOLK PROTOCOL Events:
    event AuthorizeServiceProvider(address indexed _owner, address _serviceProvider);
    event DeauthorizeServiceProvider(address indexed _owner, address _serviceProvider);
    event SetServiceProviderFee(address indexed _serviceProvider, uint256 _feeBasisPoints);
    event BurnTokens(address indexed _from, address indexed _serviceProvider, uint256 _value);

    // @param  _burnBasisPoints
    // @return success
    // @dev Set BurnRate on Wolk Protocol -- only Wolk Foundation can set this, affects Service Provider settleBuyer
    function setBurnRate(uint256 _burnBasisPoints) onlyOwner returns (bool success) {
        require( (_burnBasisPoints > 0) && (_burnBasisPoints <= 1000) );
        burnBasisPoints = _burnBasisPoints;
        return true;
    }

    // @param  _serviceProvider
    // @param  _feeBasisPoints
    // @return success
    // @dev Set Service Provider fee -- only Contract Owner can do this, affects Service Provider settleSeller
    function setServiceFee(address _serviceProvider, uint256 _feeBasisPoints) onlyOwner returns (bool success) {
        if ( _feeBasisPoints <= 0 || _feeBasisPoints > 4000){
            // revoke Settler privilege
            settlers[_serviceProvider] = false;
            feeBasisPoints[_serviceProvider] = 0;
            return false;
        }else{
            feeBasisPoints[_serviceProvider] = _feeBasisPoints;
            settlers[_serviceProvider] = true;
            SetServiceProviderFee(_serviceProvider, _feeBasisPoints);
            return true;
        }
    }

    // @param  _serviceProvider
    // @return _feeBasisPoints
    // @dev Check service ee (in BP) for a given provider
    function checkServiceFee(address _serviceProvider) constant returns (uint256 _feeBasisPoints) {
        return feeBasisPoints[_serviceProvider];
    }

    // @param  _buyer
    // @param  _value
    // @return success
    // @dev Service Provider Settlement with Buyer: a small percent is burnt (set in setBurnRate, stored in burnBasisPoints) when funds are transferred from buyer to Service Provider [only accessible by settlers]
    function settleBuyer(address _buyer, uint256 _value) onlySettler returns (bool success) {
        require( (burnBasisPoints > 0) && (burnBasisPoints <= 1000) && authorized[_buyer][msg.sender] ); // Buyer must authorize Service Provider 
        if ( balances[_buyer] >= _value && _value > 0) {
            var burnCap = safeDiv(safeMul(_value, burnBasisPoints), 10000);
            var transferredToServiceProvider = safeSub(_value, burnCap);
            balances[_buyer] = safeSub(balances[_buyer], _value);
            balances[msg.sender] = safeAdd(balances[msg.sender], transferredToServiceProvider);
            totalTokens = safeSub(totalTokens, burnCap);
            Transfer(_buyer, msg.sender, transferredToServiceProvider);
            BurnTokens(_buyer, msg.sender, burnCap);
            return true;
        } else {
            return false;
        }
    } 

    // @param  _seller
    // @param  _value
    // @return success
    // @dev Service Provider Settlement with Seller: a small percent is kept by Service Provider (set in setServiceFee, stored in feeBasisPoints) when funds are transferred from Service Provider to seller [only accessible by settlers]
    function settleSeller(address _seller, uint256 _value) onlySettler returns (bool success) {
        // Service Providers have a % fee for Sellers (e.g. 20%)
        var serviceProviderBP = feeBasisPoints[msg.sender];
        require( (serviceProviderBP > 0) && (serviceProviderBP <= 4000) );
        if (balances[msg.sender] >= _value && _value > 0) {
            var fee = safeDiv(safeMul(_value, serviceProviderBP), 10000);
            var transferredToSeller = safeSub(_value, fee);
            balances[_seller] = safeAdd(balances[_seller], transferredToSeller);
            Transfer(msg.sender, _seller, transferredToSeller);
            return true;
        } else {
            return false;
        }
    }

    // @param _providerToAdd
    // @return success
    // @dev Buyer authorizes the Service Provider (to call settleBuyer). For security reason, _providerToAdd needs to be whitelisted by Wolk Foundation first
    function authorizeProvider(address _providerToAdd) returns (bool success) {
        require(settlers[_providerToAdd]);
        authorized[msg.sender][_providerToAdd] = true;
        AuthorizeServiceProvider(msg.sender, _providerToAdd);
        return true;
    }

    // @param _providerToRemove
    // @return success
    // @dev Buyer deauthorizes the Service Provider (from calling settleBuyer)
    function deauthorizeProvider(address _providerToRemove) returns (bool success) {
        authorized[msg.sender][_providerToRemove] = false;
        DeauthorizeServiceProvider(msg.sender, _providerToRemove);
        return true;
    }

    // @param _owner
    // @param _serviceProvider
    // @return authorizationStatus
    // @dev Check authorization between account and Service Provider
    function checkAuthorization(address _owner, address _serviceProvider) constant returns (bool authorizationStatus) {
        return authorized[_owner][_serviceProvider];
    }

    // @param _owner
    // @param _providerToAdd
    // @return authorizationStatus
    // @dev Grant authorization between account and Service Provider on buyers’ behalf [only accessible by Contract Owner]
    // @note Explicit permission from balance owner MUST be obtained beforehand
    function grantService(address _owner, address _providerToAdd) onlyOwner returns (bool authorizationStatus) {
        var isPreauthorized = authorized[_owner][msg.sender];
        if (isPreauthorized && settlers[_providerToAdd] ) {
            authorized[_owner][_providerToAdd] = true;
            AuthorizeServiceProvider(msg.sender, _providerToAdd);
            return true;
        }else{
            return false;
        }
    }

    // @param _owner
    // @param _providerToRemove
    // @return authorization_status
    // @dev Revoke authorization between account and Service Provider on buyers’ behalf [only accessible by Contract Owner]
    // @note Explicit permission from balance owner are NOT required for disabling ill-intent Service Provider
    function removeService(address _owner, address _providerToRemove) onlyOwner returns (bool authorizationStatus) {
        authorized[_owner][_providerToRemove] = false;
        DeauthorizeServiceProvider(_owner, _providerToRemove);
        return true;
    }
}


// Taken from https://github.com/bancorprotocol/contracts/blob/master/solidity/contracts/BancorFormula.sol

contract BancorFormula is SafeMath {

    uint256 constant ONE = 1;
    uint256 constant TWO = 2;
    uint256 constant MAX_FIXED_EXP_32 = 0x386bfdba29;
    string public version = '0.2';

    function BancorFormula() {
    }

    /**
        @dev given a token supply, reserve, CRR and a deposit amount (in the reserve token), calculates the return for a given change (in the main token)

        Formula:
        Return = _supply * ((1 + _depositAmount / _reserveBalance) ^ (_reserveRatio / 100) - 1)

        @param _supply             token total supply
        @param _reserveBalance     total reserve
        @param _reserveRatio       constant reserve ratio, 1-100
        @param _depositAmount      deposit amount, in reserve token

        @return purchase return amount
    */
    function calculatePurchaseReturn(uint256 _supply, uint256 _reserveBalance, uint8 _reserveRatio, uint256 _depositAmount) public constant returns (uint256) {
        // validate input
        require(_supply != 0 && _reserveBalance != 0 && _reserveRatio > 0 && _reserveRatio <= 100);

        // special case for 0 deposit amount
        if (_depositAmount == 0)
            return 0;

        uint256 baseN = safeAdd(_depositAmount, _reserveBalance);
        uint256 temp;

        // special case if the CRR = 100
        if (_reserveRatio == 100) {
            temp = safeMul(_supply, baseN) / _reserveBalance;
            return safeSub(temp, _supply); 
        }

        uint8 precision = calculateBestPrecision(baseN, _reserveBalance, _reserveRatio, 100);
        uint256 resN = power(baseN, _reserveBalance, _reserveRatio, 100, precision);
        temp = safeMul(_supply, resN) >> precision;
        return safeSub(temp, _supply);
     }

    /**
        @dev given a token supply, reserve, CRR and a sell amount (in the main token), calculates the return for a given change (in the reserve token)

        Formula:
        Return = _reserveBalance * (1 - (1 - _sellAmount / _supply) ^ (1 / (_reserveRatio / 100)))

        @param _supply             token total supply
        @param _reserveBalance     total reserve
        @param _reserveRatio       constant reserve ratio, 1-100
        @param _sellAmount         sell amount, in the token itself

        @return sale return amount
    */
    function calculateSaleReturn(uint256 _supply, uint256 _reserveBalance, uint8 _reserveRatio, uint256 _sellAmount) public constant returns (uint256) {
        // validate input
        require(_supply != 0 && _reserveBalance != 0 && _reserveRatio > 0 && _reserveRatio <= 100 && _sellAmount <= _supply);

        // special case for 0 sell amount
        if (_sellAmount == 0)
            return 0;

        uint256 baseD = safeSub(_supply, _sellAmount);
        uint256 temp1;
        uint256 temp2;

        // special case if the CRR = 100
        if (_reserveRatio == 100) {
            temp1 = safeMul(_reserveBalance, _supply);
            temp2 = safeMul(_reserveBalance, baseD);
            return safeSub(temp1, temp2) / _supply;
        }

        // special case for selling the entire supply
        if (_sellAmount == _supply)
            return _reserveBalance;

        uint8 precision = calculateBestPrecision(_supply, baseD, 100, _reserveRatio);
        uint256 resN = power(_supply, baseD, 100, _reserveRatio, precision);
        temp1 = safeMul(_reserveBalance, resN);
        temp2 = safeMul(_reserveBalance, ONE << precision);
        return safeSub(temp1, temp2) / resN;
    }

    /**
        calculateBestPrecision 
        Predicts the highest precision which can be used in order to compute "base^exp" without exceeding 256 bits in any of the intermediate computations.
        Instead of calculating "base ^ exp", we calculate "e ^ (ln(base) * exp)".
        The value of ln(base) is represented with an integer slightly smaller than ln(base) * 2 ^ precision.
        The larger the precision is, the more accurately this value represents the real value.
        However, function fixedExpUnsafe(x), which calculates e ^ x, is limited to a maximum value of x.
        The limit depends on the precision (e.g, for precision = 32, the maximum value of x is MAX_FIXED_EXP_32).
        Hence before calling the 'power' function, we need to estimate an upper-bound for ln(base) * exponent.
        Of course, we should later assert that the value passed to fixedExpUnsafe is not larger than MAX_FIXED_EXP(precision).
        Due to this assertion (made in function fixedExp), functions calculateBestPrecision and fixedExp are tightly coupled.
        Note that the outcome of this function only affects the accuracy of the computation of "base ^ exp".
        Therefore, there is no need to assert that no intermediate result exceeds 256 bits (nor in this function, neither in any of the functions down the calling tree).
    */
    function calculateBestPrecision(uint256 _baseN, uint256 _baseD, uint256 _expN, uint256 _expD) constant returns (uint8) {
        uint8 precision;
        uint256 maxExp = MAX_FIXED_EXP_32;
        uint256 maxVal = _expN * lnUpperBound(_baseN,_baseD);
        for (precision = 0; precision < 32; precision += 2) {
            if (maxExp < (maxVal << precision) / _expD)
                break;
            maxExp = (maxExp * 0xeb5ec5975959c565) >> (64-2);
        }
        if (precision == 0)
            return 32;
        return precision+32-2;
    }

    /**
        @dev calculates (_baseN / _baseD) ^ (_expN / _expD)
        Returns result upshifted by precision

        This method is overflow-safe
    */ 
    function power(uint256 _baseN, uint256 _baseD, uint256 _expN, uint256 _expD, uint8 _precision) constant returns (uint256) {
        uint256 logbase = ln(_baseN, _baseD, _precision);
        // Not using safeDiv here, since safeDiv protects against
        // precision loss. It's unavoidable, however
        // Both `ln` and `fixedExp` are overflow-safe. 
        return fixedExp(safeMul(logbase, _expN) / _expD, _precision);
    }
    
    /**
        input range: 
            - numerator: [1, uint256_max >> precision]    
            - denominator: [1, uint256_max >> precision]
        output range:
            [0, 0x9b43d4f8d6]

        This method asserts outside of bounds
    */
    function ln(uint256 _numerator, uint256 _denominator, uint8 _precision) public constant returns (uint256) {
        // denominator > numerator: less than one yields negative values. Unsupported
        assert(_denominator <= _numerator);

        // log(1) is the lowest we can go
        assert(_denominator != 0 && _numerator != 0);

        // Upper bits are scaled off by precision
        uint256 MAX_VAL = ONE << (256 - _precision);
        assert(_numerator < MAX_VAL);
        assert(_denominator < MAX_VAL);

        return fixedLoge( (_numerator << _precision) / _denominator, _precision);
    }

    /**
        lnUpperBound 
        Takes a rational number (baseN / baseD) as input.
        Returns an estimated upper-bound integer of the natural logarithm of the input.
        We do this by calculating the value of "ceiling(ceiling(log2(base)) * ln(2)))".
        The expression "floor(log2(base)) >= ceiling(ln(base))" does not hold for all cases of base < 8.
        We therefore cover these cases (and a few more) manually.
        Complexity is O(log(input bit-length)).
    */
    function lnUpperBound(uint256 _baseN, uint256 _baseD) constant returns (uint256) {
        assert(_baseN > _baseD);

        uint256 scaledBaseN = _baseN * 100000;
        if (scaledBaseN <= _baseD *  271828) // _baseN / _baseD < e^1 (floorLog2 will return 0 if _baseN / _baseD < 2)
            return uint256(1) << 32;
        if (scaledBaseN <= _baseD *  738905) // _baseN / _baseD < e^2 (floorLog2 will return 1 if _baseN / _baseD < 4)
            return uint256(2) << 32;
        if (scaledBaseN <= _baseD * 2008553) // _baseN / _baseD < e^3 (floorLog2 will return 2 if _baseN / _baseD < 8)
            return uint256(3) << 32;

        return (floorLog2((_baseN - 1) / _baseD) + 1) * 0xb17217f8;
    }

    /**
        input range: 
            [0x100000000, uint256_max]
        output range:
            [0, 0x9b43d4f8d6]

        This method asserts outside of bounds

        Since `fixedLog2_min` output range is max `0xdfffffffff` 
        (40 bits, or 5 bytes), we can use a very large approximation
        for `ln(2)`. This one is used since it's the max accuracy 
        of Python `ln(2)`

        0xb17217f7d1cf78 = ln(2) * (1 << 56)
    */
    function fixedLoge(uint256 _x, uint8 _precision) constant returns (uint256) {
        // cannot represent negative numbers (below 1)
        assert(_x >= ONE << _precision);

        uint256 log2 = fixedLog2(_x, _precision);
        return (log2 * 0xb17217f7d1cf78) >> 56;
    }

    /**
        Returns log2(x >> 32) << 32 [1]
        So x is assumed to be already upshifted 32 bits, and 
        the result is also upshifted 32 bits. 
        
        [1] The function returns a number which is lower than the 
        actual value

        input-range : 
            [0x100000000, uint256_max]
        output-range: 
            [0,0xdfffffffff]

        This method asserts outside of bounds

    */
    function fixedLog2(uint256 _x, uint8 _precision) constant returns (uint256) {
        uint256 fixedOne = ONE << _precision;
        uint256 fixedTwo = TWO << _precision;

        // Numbers below 1 are negative. 
        assert( _x >= fixedOne);

        uint256 hi = 0;
        while (_x >= fixedTwo) {
            _x >>= 1;
            hi += fixedOne;
        }

        for (uint8 i = 0; i < _precision; ++i) {
            _x = (_x * _x) / fixedOne;
            if (_x >= fixedTwo) {
                _x >>= 1;
                hi += ONE << (_precision - 1 - i);
            }
        }

        return hi;
    }

    /**
        floorLog2
        Takes a natural number (n) as input.
        Returns the largest integer smaller than or equal to the binary logarithm of the input.
        Complexity is O(log(input bit-length)).
    */
    function floorLog2(uint256 _n) constant returns (uint256) {
        uint8 t = 0;
        for (uint8 s = 128; s > 0; s >>= 1) {
            if (_n >= (ONE << s)) {
                _n >>= s;
                t |= s;
            }
        }

        return t;
    }

    /**
        fixedExp is a 'protected' version of `fixedExpUnsafe`, which asserts instead of overflows.
        The maximum value which can be passed to fixedExpUnsafe depends on the precision used.
        The following array maps each precision between 0 and 63 to the maximum value permitted:
        maxExpArray = {
            0xc1               ,0x17a              ,0x2e5              ,0x5ab              ,
            0xb1b              ,0x15bf             ,0x2a0c             ,0x50a2             ,
            0x9aa2             ,0x1288c            ,0x238b2            ,0x4429a            ,
            0x82b78            ,0xfaadc            ,0x1e0bb8           ,0x399e96           ,
            0x6e7f88           ,0xd3e7a3           ,0x1965fea          ,0x30b5057          ,
            0x5d681f3          ,0xb320d03          ,0x15784a40         ,0x292c5bdd         ,
            0x4ef57b9b         ,0x976bd995         ,0x122624e32        ,0x22ce03cd5        ,
            0x42beef808        ,0x7ffffffff        ,0xf577eded5        ,0x1d6bd8b2eb       ,
            0x386bfdba29       ,0x6c3390ecc8       ,0xcf8014760f       ,0x18ded91f0e7      ,
            0x2fb1d8fe082      ,0x5b771955b36      ,0xaf67a93bb50      ,0x15060c256cb2     ,
            0x285145f31ae5     ,0x4d5156639708     ,0x944620b0e70e     ,0x11c592761c666    ,
            0x2214d10d014ea    ,0x415bc6d6fb7dd    ,0x7d56e76777fc5    ,0xf05dc6b27edad    ,
            0x1ccf4b44bb4820   ,0x373fc456c53bb7   ,0x69f3d1c921891c   ,0xcb2ff529eb71e4   ,
            0x185a82b87b72e95  ,0x2eb40f9f620fda6  ,0x5990681d961a1ea  ,0xabc25204e02828d  ,
            0x14962dee9dc97640 ,0x277abdcdab07d5a7 ,0x4bb5ecca963d54ab ,0x9131271922eaa606 ,
            0x116701e6ab0cd188d,0x215f77c045fbe8856,0x3ffffffffffffffff,0x7abbf6f6abb9d087f,
        };
        Since we cannot use an array of constants, we need to approximate the maximum value dynamically.
        For a precision of 32, the maximum value permitted is MAX_FIXED_EXP_32.
        For each additional precision unit, the maximum value permitted increases by approximately 1.9.
        So in order to calculate it, we need to multiply MAX_FIXED_EXP_32 by 1.9 for every additional precision unit.
        And in order to optimize for speed, we multiply MAX_FIXED_EXP_32 by 1.9^2 for every 2 additional precision units.
        Hence the general function for mapping a given precision to the maximum value permitted is:
        - precision = [32, 34, 36, ..., 62]
        - MaxFixedExp(precision) = MAX_FIXED_EXP_32 * 3.61 ^ (precision / 2 - 16)
        Since we cannot use non-integers, we do MAX_FIXED_EXP_32 * 361 ^ (precision / 2 - 16) / 100 ^ (precision / 2 - 16).
        But there is a better approximation, because this "1.9" factor in fact extends beyond a single decimal digit.
        So instead, we use 0xeb5ec5975959c565 / 0x4000000000000000, which yields maximum values quite close to real ones:
        maxExpArray = {
            -------------------,-------------------,-------------------,-------------------,
            -------------------,-------------------,-------------------,-------------------,
            -------------------,-------------------,-------------------,-------------------,
            -------------------,-------------------,-------------------,-------------------,
            -------------------,-------------------,-------------------,-------------------,
            -------------------,-------------------,-------------------,-------------------,
            -------------------,-------------------,-------------------,-------------------,
            -------------------,-------------------,-------------------,-------------------,
            0x386bfdba29       ,-------------------,0xcf8014760e       ,-------------------,
            0x2fb1d8fe07b      ,-------------------,0xaf67a93bb37      ,-------------------,
            0x285145f31a8f     ,-------------------,0x944620b0e5ee     ,-------------------,
            0x2214d10d0112e    ,-------------------,0x7d56e7677738e    ,-------------------,
            0x1ccf4b44bb20d0   ,-------------------,0x69f3d1c9210d27   ,-------------------,
            0x185a82b87b5b294  ,-------------------,0x5990681d95d4371  ,-------------------,
            0x14962dee9dbd672b ,-------------------,0x4bb5ecca961fb9bf ,-------------------,
            0x116701e6ab0967080,-------------------,0x3fffffffffffe6652,-------------------,
        };
    */
    function fixedExp(uint256 _x, uint8 _precision) constant returns (uint256) {
        uint256 maxExp = MAX_FIXED_EXP_32;
        for (uint8 p = 32; p < _precision; p += 2)
            maxExp = (maxExp * 0xeb5ec5975959c565) >> (64-2);
        
        assert(_x <= maxExp);
        return fixedExpUnsafe(_x, _precision);
    }

    /**
        fixedExp 
        Calculates e ^ x according to maclauren summation:

        e^x = 1 + x + x ^ 2 / 2!...+ x ^ n / n!

        and returns e ^ (x >> 32) << 32, that is, upshifted for accuracy

        Input range:
            - Function ok at    <= 242329958953 
            - Function fails at >= 242329958954

        This method is is visible for testcases, but not meant for direct use. 
 
        The values in this method been generated via the following python snippet: 

        def calculateFactorials():
            """Method to print out the factorials for fixedExp"""

            ni = []
            ni.append(295232799039604140847618609643520000000) # 34!
            ITERATIONS = 34
            for n in range(1, ITERATIONS, 1) :
                ni.append(math.floor(ni[n - 1] / n))
            print( "\n        ".join(["xi = (xi * _x) >> _precision;\n        res += xi * %s;" % hex(int(x)) for x in ni]))

    */
    function fixedExpUnsafe(uint256 _x, uint8 _precision) constant returns (uint256) {
        uint256 xi = _x;
        uint256 res = uint256(0xde1bc4d19efcac82445da75b00000000) << _precision;

        res += xi * 0xde1bc4d19efcac82445da75b00000000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x6f0de268cf7e5641222ed3ad80000000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x2504a0cd9a7f7215b60f9be480000000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x9412833669fdc856d83e6f920000000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x1d9d4d714865f4de2b3fafea0000000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x4ef8ce836bba8cfb1dff2a70000000;
        xi = (xi * _x) >> _precision;
        res += xi * 0xb481d807d1aa66d04490610000000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x16903b00fa354cda08920c2000000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x281cdaac677b334ab9e732000000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x402e2aad725eb8778fd85000000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x5d5a6c9f31fe2396a2af000000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x7c7890d442a82f73839400000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x9931ed54034526b58e400000;
        xi = (xi * _x) >> _precision;
        res += xi * 0xaf147cf24ce150cf7e00000;
        xi = (xi * _x) >> _precision;
        res += xi * 0xbac08546b867cdaa200000;
        xi = (xi * _x) >> _precision;
        res += xi * 0xbac08546b867cdaa20000;
        xi = (xi * _x) >> _precision;
        res += xi * 0xafc441338061b2820000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x9c3cabbc0056d790000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x839168328705c30000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x694120286c049c000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x50319e98b3d2c000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x3a52a1e36b82000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x289286e0fce000;
        xi = (xi * _x) >> _precision;
        res += xi * 0x1b0c59eb53400;
        xi = (xi * _x) >> _precision;
        res += xi * 0x114f95b55400;
        xi = (xi * _x) >> _precision;
        res += xi * 0xaa7210d200;
        xi = (xi * _x) >> _precision;
        res += xi * 0x650139600;
        xi = (xi * _x) >> _precision;
        res += xi * 0x39b78e80;
        xi = (xi * _x) >> _precision;
        res += xi * 0x1fd8080;
        xi = (xi * _x) >> _precision;
        res += xi * 0x10fbc0;
        xi = (xi * _x) >> _precision;
        res += xi * 0x8c40;
        xi = (xi * _x) >> _precision;
        res += xi * 0x462;
        xi = (xi * _x) >> _precision;
        res += xi * 0x22;

        return res / 0xde1bc4d19efcac82445da75b00000000;
    }
}

contract WolkExchange is WolkProtocol, WolkTGE, BancorFormula {

    uint256 public maxPerExchangeBP = 50;

    // @param  _maxPerExchange
    // @return success
    // @dev Set max sell token amount per transaction -- only Wolk Foundation can set this
    function setMaxPerExchange(uint256 _maxPerExchange) onlyOwner returns (bool success) {
        require( (_maxPerExchange >= 10) && (_maxPerExchange <= 100) );
        maxPerExchangeBP = _maxPerExchange;
        return true;
    }

    // @return Estimated Liquidation Cap
    // @dev Liquidation Cap per transaction is used to ensure proper price discovery for Wolk Exchange 
    function EstLiquidationCap() public constant returns (uint256) {
        if (saleCompleted){
            var liquidationMax  = safeDiv(safeMul(totalTokens, maxPerExchangeBP), 10000);
            if (liquidationMax < 100 * 10**decimals){ 
                liquidationMax = 100 * 10**decimals;
            }
            return liquidationMax;   
        }else{
            return 0;
        }
    }

    // @param _wolkAmount
    // @return ethReceivable
    // @dev send Wolk into contract in exchange for eth, at an exchange rate based on the Bancor Protocol derivation and decrease totalSupply accordingly
    function sellWolk(uint256 _wolkAmount) isTransferable() external returns(uint256) {
        uint256 sellCap = EstLiquidationCap();
        uint256 ethReceivable = calculateSaleReturn(totalTokens, reserveBalance, percentageETHReserve, _wolkAmount);
        require( (sellCap >= _wolkAmount) && (balances[msg.sender] >= _wolkAmount) && (this.balance > ethReceivable) );
        balances[msg.sender] = safeSub(balances[msg.sender], _wolkAmount);
        totalTokens = safeSub(totalTokens, _wolkAmount);
        reserveBalance = safeSub(this.balance, ethReceivable);
        WolkDestroyed(msg.sender, _wolkAmount);
        Transfer(msg.sender, 0x00000000000000000000, _wolkAmount);
        msg.sender.transfer(ethReceivable);
        return ethReceivable;     
    }

    // @return wolkReceivable    
    // @dev send eth into contract in exchange for Wolk tokens, at an exchange rate based on the Bancor Protocol derivation and increase totalSupply accordingly
    function purchaseWolk(address _buyer) isTransferable() payable external returns(uint256){
        require(msg.value > 0);
        uint256 wolkReceivable = calculatePurchaseReturn(totalTokens, reserveBalance, percentageETHReserve, msg.value);
        totalTokens = safeAdd(totalTokens, wolkReceivable);
        balances[_buyer] = safeAdd(balances[_buyer], wolkReceivable);
        reserveBalance = safeAdd(reserveBalance, msg.value);
        WolkCreated(_buyer, wolkReceivable);
        Transfer(address(this), _buyer, wolkReceivable);
        return wolkReceivable;
    }

    function () payable {
        require(msg.value > 0);
        if(!saleCompleted){
            this.tokenGenerationEvent.value(msg.value)(msg.sender);
        }else if ( block.number >= (end_block + 6000)){
            this.purchaseWolk.value(msg.value)(msg.sender);
        }else{
            revert();
        }
    }
}
