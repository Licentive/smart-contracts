pragma solidity ^0.4.25;

import "github.com/OpenZeppelin/zeppelin-solidity/contracts/token/ERC20/ERC20.sol";
import "github.com/OpenZeppelin/zeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";

/**
 * @title LCTV ERC20 token 
 * @author mierzwik
 * @dev Implementation of standard ERC20 Licentive (LCTV) token
 *      includes payAndCall function for licentive platform transactions
 * Note: Initial suply set to 1mil tokens, no additional minting allowed
 */
contract LCTV is ERC20, ERC20Detailed {
    
    address public licentive;
    Dispatcher public dispatcher; 
    
    /**
     * @dev Token constructor with initial minting
     * Note: Calling address is assumed to be Licentive and becomes the owner
     */
    constructor()
        ERC20Detailed("Licentive token", "LCTV", 18)
        ERC20()
        public
    {
        licentive = msg.sender;
        _mint(licentive, 1000000 * (10 ** uint256(decimals())));    
    }
    
    /**
     * @dev Public function setting the Dispather contract _address
     * @param _address The new Dispatcher address
     * Note: This function can be called only by Licentive
     * Note: This function MUST be called after token creation
     */
    function setDispatcher(address _address) public {
        
        require (msg.sender == licentive);
        dispatcher = Dispatcher(_address);
    }
    
    /**
     * @dev Public function for paying the fee and calling Dispatcher onApproval
     * @param _value The amount that is approved for the payment
     * @param _value Extra data passed to onApproval call 
     * @return Returns True only if everything was executed properly
     * Note: This function can be called by anyone
     */
    function payAndCall(uint256 _value, bytes _data) public returns (bool) {
    
        require(super.approve(dispatcher, _value));
        require(dispatcher.onApproval(msg.sender, _data));

        return true;
    }
}


/**
 * @title Dispatcher contract
 * @author mierzwik
 * @dev Implementation of dispatcher responsible for license contracts maintenance
 * Note: Should be called with LCTV token contract address
 */
contract Dispatcher {
    
    address private licentive;
    
    LCTV public token;
    uint256 public create_price;
    uint256 public update_price;
    
    /**
     * @dev mapping from license contract address to licensor address
     * Note: can be used to validate if the contract is legitimate 
     *       i.e. has a licensor assigned (this can be done by Dispatcher only)
     */
    mapping (address => address) public licensors;
    
    /**
    * @dev Constructor setting the administrative adresses
    * @param _address The address of the LCTV token contract
    * Note: Licentive address is extracted form LCTV token contract
    */
    constructor(address _address) public {
 
        token = LCTV(_address);
        licentive = token.licentive();
    }
    
    /**
     * @dev Public function setting the fees
     * @param _create_price The fee for license contract creation
     * @param _update_price The fee for license contract modification
     * Note: This function can be called only by Licentive
     * Note: This function MUST be called after Dispatcher creation
     */
    function setPrices(uint _create_price, uint _update_price) public {
        
        require (msg.sender == licentive);
        create_price = _create_price;
        update_price = _update_price;
    }
    
    /**
     * @dev Public function called by LCTV token contract after payment approval 
     * @param _operator The user calling and paying for transaction
     * @param _data Extra data passed by the user
     * @return Returns True only if everything was executed properly
     * Note: This function can be called only by LCTV token contract 
     */
    function onApproval(address _operator, bytes _data) public returns (bool) {
    
        require(msg.sender == address(token));
        require(createContract(string(_data), _operator));
        
        return true;
    }
    
    /**
     * @dev Event emited after sucessful License Contract creation
     * @param _name The name of newly created contract
     * @param _address The address of newly created contract 
     * @param _licensor The adress of licensor (i.e. the original caller)
     */
    event ContractCreated(string _name, address _address, address _licensor);
    
    /**
     * @dev Private function creating the new License Contract
     * @param _name The name of the new contract
     * @param _licensor The adress of licensor (i.e. the original caller)
     * @return Returns True only if everything was executed properly
     * Note: This function is called by onApproval only
     */
    function createContract(string _name, address _licensor) private returns (bool) {
        
        License_contract lc;

        require(token.transferFrom(_licensor, licentive, create_price));
        lc = new License_contract(_name, 0, _licensor);
        licensors[lc] = _licensor;
        
        emit ContractCreated(_name, lc, _licensor); 
        
        return true;
    }
}


/**
 * @title License Contract
 * @author mierzwik
 * @dev Implementation of the main license contract
 * Note: Each software product is assumed to use only one License Contract
 */
contract License_contract {
    
    address private licentive;
    Dispatcher private dispatcher;
    
    string public name;
    uint256 public hash;
    address public licensor;
    
    /**
    * @dev Constructor setting the main product parameters
    * @param _name The name of the software Product
    * @param _hash The code hash of the software Product
    * @param _licensor The addres of the software Product Licensor
    * Note: Dispatcher is set to the address of contract creator
    * Note: Licentive address is extracted form LCTV token contract
    */
    constructor(string _name, uint256 _hash, address _licensor) public {
        
        dispatcher = Dispatcher(msg.sender);
        licentive = dispatcher.token().licentive();
        
        name = _name;
        hash = _hash;
        licensor = _licensor;
    }
    
    /**
     * @dev Public function modifying the License Contract
     * @param _name The new name of the  contract
     * @return Returns True only if everything was executed properly
     * Note: This function can be called by Dispatcher or directly by Licentive
     */
    function modifyContract(string _name) public returns (bool) {
        
        require(msg.sender == address(dispatcher) || msg.sender == licentive);
        name = _name;
        
        return true;
    }
}
