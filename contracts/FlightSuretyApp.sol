pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA CONSTANTS                                     */
    /********************************************************************************************/

    uint256 public constant PARTICIPATION_FEE = 10 ether;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
    FlightSuretyData flightSuretyData;
    address[] multiCalls = new address[](0);

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner; // Account used to deploy contract

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
        // Modify to call data contract's status
        require(
            flightSuretyData.isOperational(),
            "Contract is currently not operational"
        );
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
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address dataContract) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
        flightSuretyData.registerAirline(msg.sender);
        flightSuretyData.fund(msg.sender, 10 ether);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() public view returns (bool) {
        return flightSuretyData.isOperational();
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    function isAirline(address _address) public view returns (bool) {
        return flightSuretyData.isAirlineRegistered(_address);
    }

    function isFlightRegistered(bytes32 key) public view returns (bool) {
        return flightSuretyData.isFlightRegistered(key);
    }

    function registerAirline(address _address) external {
        require(!isAirline(_address), "Airline is already registered.");

        if (flightSuretyData.getAirlineCounter() == 0) {
            flightSuretyData.registerAirline(_address);
        } else {
            require(
                isAirline(msg.sender),
                "Only existing airline may register new airlines"
            );
            require(
                flightSuretyData.isFunded(msg.sender),
                "Airline has not paid participation fee"
            );

            if (flightSuretyData.getParticipantCounter() < 4) {
                flightSuretyData.registerAirline(_address);
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
                uint256 M = flightSuretyData.getParticipantCounter() / 2;
                if (multiCalls.length >= M) {
                    flightSuretyData.registerAirline(_address);
                    multiCalls = new address[](0);
                }
            }
        }
    }

    function fund() public payable requireIsOperational {
        require(
            !flightSuretyData.isFunded(msg.sender),
            "Airline already paid participation fees"
        );
        require(msg.value == PARTICIPATION_FEE, "Participant Fee is 10 ether");

        contractOwner.transfer(msg.value);
        flightSuretyData.fund(msg.sender, msg.value);
    }

    function getFunds() public view requireIsOperational returns (uint256) {
        return flightSuretyData.getFunds(msg.sender);
    }

    function buy(address airline, string flight, uint256 timestamp)
        public
        payable
        requireIsOperational
    {
        require(msg.value > 0, "Value must be greater than 0.");
        require(msg.value <= 1 ether, "Value must at least 1 ether.");

        // not working
        // airline.transfer(msg.value);
        flightSuretyData.buyInsurance(
            msg.sender,
            airline,
            flight,
            timestamp,
            msg.value
        );
    }

    function airlineCounter() public view returns (uint256) {
        return flightSuretyData.getAirlineCounter();
    }

    function withdraw() public returns (uint256) {
        return flightSuretyData.withdraw(msg.sender);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(string flight, uint256 timestamp, address airline)
        external
    {
        bytes32 key = keccak256(abi.encodePacked(airline, flight, timestamp));

        require(
            !flightSuretyData.isFlightRegistered(key),
            "Flight is already registered"
        );

        flightSuretyData.registerFlight(key, airline, timestamp);
    }

    function getInsureeBalance() public view returns (uint256) {
        return flightSuretyData.getBalance(msg.sender);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function processFlightStatus(
        address airline,
        string memory flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal {
        bytes32 flightKey = keccak256(
            abi.encodePacked(airline, flight, timestamp)
        );
        flightSuretyData.creditInsurees(flightKey);
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string flight,
        uint256 timestamp
    ) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester; // Account that requested status
        bool isOpen; // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses; // Mapping key is the status code reported
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() external view returns (uint8[3]) {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    ) external {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp do not match oracle request"
        );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (
            oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES
        ) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(address airline, string flight, uint256 timestamp)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns (uint8[3]) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

    // endregion
}


contract FlightSuretyData {
    function registerAirline(address _address) external;

    function isAirlineRegistered(address _address) external view returns (bool);

    function isFunded(address _address) external view returns (bool);

    function isOperational() public view returns (bool);

    function isFlightRegistered(bytes32 key) public view returns (bool);

    function registerFlight(bytes32 key, address airline, uint256 timestamp)
        external;

    function fund(address _address, uint256 amount) external;

    function getFunds(address _address) external view returns (uint256);

    function buyInsurance(
        address insuree,
        address airline,
        string flight,
        uint256 timestamp,
        uint256 amount
    ) external;

    function creditInsurees(bytes32 key) external;

    function getBalance(address insuree) external view returns (uint256);

    function withdraw(address insuree) external returns (uint256);

    function getParticipantCounter() public view returns (uint256);

    function getAirlineCounter() external view returns (uint256);
}
