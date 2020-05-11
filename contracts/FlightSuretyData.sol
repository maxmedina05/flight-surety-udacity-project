pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA CONSTANTS                                     */
    /********************************************************************************************/

    uint256 public constant PARTICIPATION_FEE = 10 ether;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    uint256 public airlineCounter = 0;
    address[] multiCalls = new address[](0);

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    struct Airline {
        bool isRegistered;
        bool isParticipant;
    }

    struct Insuree {
        uint256 value;
        bytes32 key;
    }

    mapping(address => bool) private authorizedCallers;
    mapping(address => Airline) private airlines;
    mapping(bytes32 => Flight) private flights;
    mapping(address => Insuree) private insurees;
    mapping(address => address[]) registrationVotes;
    mapping(address => uint256) internal funds;
    mapping(address => uint256) internal balances;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor() public {
        contractOwner = msg.sender;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireNoMoreThanOneEther() {
        require(msg.value <= 1 ether, "Value exceeds the limit of 1 Ether");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */

    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */

    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    function authorizeCaller(address _address) external requireContractOwner {
        authorizedCallers[_address] = true;
    }

    function deauthorizeCaller(address contractAddress)
        external
        requireContractOwner
    {
        delete authorizedCallers[contractAddress];
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function isAirline(address _address) external view returns (bool) {
        return airlines[_address].isRegistered;
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(address _address) external {
        require(
            !airlines[_address].isRegistered,
            "Airline is already registered."
        );

        if (airlineCounter == 0) {
            airlines[_address] = Airline({
                isRegistered: true,
                isParticipant: true
            });
            airlineCounter++;
        } else {
            require(
                airlines[msg.sender].isRegistered,
                "Only existing airline may register new airlines"
            );
            require(
                airlines[msg.sender].isParticipant,
                "Airline has not paid participation fee"
            );

            if (airlineCounter < 4) {
                airlines[_address] = Airline({
                    isRegistered: true,
                    isParticipant: false
                });
                // airlineCounter++;
            } else {
                bool isDuplicate = false;
                for (uint256 c = 0; c < multiCalls.length; c++) {
                    if (multiCalls[c] == msg.sender) {
                        isDuplicate = true;
                        break;
                    }
                }
                require(
                    !isDuplicate,
                    "Caller has already called this function."
                );

                multiCalls.push(msg.sender);
                uint256 M = airlineCounter / 2;
                if (multiCalls.length >= M) {
                    airlines[_address] = Airline({
                        isRegistered: true,
                        isParticipant: false
                    });
                    multiCalls = new address[](0);
                    // airlineCounter++;
                }
            }
        }
    }

    function unregisterAirline(address _address)
        external
        requireContractOwner
        requireIsOperational
    {
        airlines[_address].isRegistered = false;
        airlines[_address].isParticipant = false;
        airlineCounter--;
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(
        string flight,
        uint8 status,
        uint256 timestamp,
        address airline
    ) external {
        bytes32 key = keccak256(abi.encodePacked(airline, flight, timestamp));

        require(!flights[key].isRegistered, "Flight is already registered");

        flights[key] = Flight({
            isRegistered: true,
            statusCode: 10,
            updatedTimestamp: timestamp,
            airline: airline
        });
    }

    function getPassengerAvailableCredit(address passenger)
        external
        returns (uint256)
    {
        return balances[passenger];
    }

    function fund() public payable requireIsOperational {
        require(airlines[msg.sender].isRegistered, "Airline is not registered");
        require(
            !airlines[msg.sender].isParticipant,
            "Airline already paid participation fee"
        );
        require(msg.value >= PARTICIPATION_FEE, "Insufficient balance");

        airlines[msg.sender].isParticipant = true;
        funds[msg.sender] = msg.value;
        airlineCounter++;
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */

    /**
     * @dev Buy insurance for a flight
     *
     */

    function buy(string flight, uint256 timestamp, address airline)
        external
        payable
        requireIsOperational
    {
        require(msg.value > 0 ether, "Value must be greater than 0");
        require(msg.value <= 1 ether, "Value exceeds the limit of 1 Ether");

        bytes32 key = keccak256(abi.encodePacked(airline, flight, timestamp));
        insurees[msg.sender] = Insuree({value: msg.value, key: key});

        airline.transfer(msg.value);
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees() external pure {
        
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay() external pure {}

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {
        fund();
    }
}
