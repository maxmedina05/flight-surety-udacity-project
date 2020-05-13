pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    uint256 private participantCounter = 0; // No of participants for consensus
    uint256 private airlineCounter = 0;

    struct Flight {
        bool isRegistered;
        bool isDelay;
        uint8 statusCode;
        address airline;
        uint256 updatedTimestamp;
    }

    struct Airline {
        bool isRegistered;
        bool isParticipant;
    }

    struct Insurance {
        uint256 value;
        address airline;
        bytes32 flight;
    }

    mapping(address => bool) private authorizedCallers;
    mapping(address => Airline) private airlines;
    mapping(bytes32 => Flight) private flights;
    mapping(address => Insurance) private insurances; // insurance using passanger address as key
    mapping(address => uint256) private funds; // Airlines funds
    mapping(address => uint256) private balances; // Passengers available balance for withdraw

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

    function getParticipantCounter() external view returns (uint256) {
        return participantCounter;
    }

    function getAirlineCounter() external view returns (uint256) {
        return airlineCounter;
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

    function isAirlineRegistered(address _address)
        external
        view
        returns (bool)
    {
        return airlines[_address].isRegistered;
    }

    function isFunded(address _address) external view returns (bool) {
        return airlines[_address].isParticipant;
    }

    function registerAirline(address _address) external {
        airlines[_address] = Airline({
            isRegistered: true,
            isParticipant: false
        });

        airlineCounter++;
    }

    function isFlightRegistered(bytes32 key) external view returns (bool) {
        return flights[key].isRegistered;
    }

    function registerFlight(bytes32 key, address airline, uint256 timestamp)
        external
    {
        flights[key] = Flight({
            isRegistered: true,
            isDelay: true,
            statusCode: 10,
            airline: airline,
            updatedTimestamp: timestamp
        });
    }

    function getFlight(bytes32 key)
        external
        returns (
            bool isRegistered,
            uint256 statusCode,
            address airline,
            uint256 timestamp
        )
    {
        isRegistered = flights[key].isRegistered;
        statusCode = flights[key].statusCode;
        airline = flights[key].airline;
        timestamp = flights[key].updatedTimestamp;

        return (isRegistered, statusCode, airline, timestamp);
    }

    /**
     * @dev add funds to airline
     *
     */
    function fund(address _address, uint256 amount)
        external
        requireIsOperational
    {
        airlines[_address].isParticipant = true;
        funds[_address] = amount;

        participantCounter++;
    }

    function getFunds(address _address) external view returns (uint256) {
        return funds[_address];
    }

    function buyInsurance(address insuree, address airline, string flight, uint256 timestamp, uint256 amount)
        external
        requireIsOperational
    {

        bytes32 key = keccak256(abi.encodePacked(airline, flight, timestamp));
        insurances[insuree] = Insurance({value: amount, airline: airline, flight: key});
        funds[airline] = funds[airline].add(amount);
    }

    function creditInsurees(bytes32 key) external requireIsOperational {
        flights[key].isDelay = true;
    }

    function getBalance(address insuree)
        external
        view
        requireIsOperational
        returns (uint256)
    {
        return balances[insuree];
    }

    function withdraw(address insuree)
        external
        requireIsOperational
        returns (uint256)
    {
        bytes32 flightKey = insurances[insuree].flight;
        require(flights[flightKey].isDelay, "Flight is not delay");

        address airline = insurances[insuree].airline;
        uint256 expectedAmount = insurances[insuree].value.mul(3).div(2);
        balances[insuree].add(expectedAmount);
        funds[airline].sub(expectedAmount);

        uint256 amount = balances[insuree];

        delete balances[insuree];

        return amount;
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {
        // fund();
    }
}
