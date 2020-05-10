var Test = require('../config/testConfig.js')
var BigNumber = require('bignumber.js')

contract('Flight Surety Tests', async (accounts) => {
  var config
  before('setup contract', async () => {
    config = await Test.Config(accounts)
    await config.flightSuretyData.authorizeCaller(
      config.flightSuretyApp.address,
    )
  })

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {
    // Get operating status
    let status = await config.flightSuretyData.isOperational.call()
    assert.equal(status, true, 'Incorrect initial operating status value')
  })

  //   it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

  //       // Ensure that access is denied for non-Contract Owner account
  //       let accessDenied = false;
  //       try
  //       {
  //           await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
  //       }
  //       catch(e) {
  //           accessDenied = true;
  //       }
  //       assert.equal(accessDenied, true, "Access not restricted to Contract Owner");

  //   });

  //   it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

  //       // Ensure that access is allowed for Contract Owner account
  //       let accessDenied = false;
  //       try
  //       {
  //           await config.flightSuretyData.setOperatingStatus(false);
  //       }
  //       catch(e) {
  //           accessDenied = true;
  //       }
  //       assert.equal(accessDenied, false, "Access not restricted to Contract Owner");

  //   });

  //   it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

  //       await config.flightSuretyData.setOperatingStatus(false);

  //       let reverted = false;
  //       try
  //       {
  //           await config.flightSurety.setTestingMode(true);
  //       }
  //       catch(e) {
  //           reverted = true;
  //       }
  //       assert.equal(reverted, true, "Access not blocked for requireIsOperational");

  //       // Set it back for other tests to work
  //       await config.flightSuretyData.setOperatingStatus(true);

  //   });

  // it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {

  //   // ARRANGE
  //   let newAirline = accounts[2];

  //   // ACT
  //   try {
  //       await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
  //   }
  //   catch(e) {

  //   }
  //   let result = await config.flightSuretyData.isAirline.call(newAirline);

  //   // ASSERT
  //   assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  // });

  it('should register first airline when contract is deployed', async () => {
    const isAirlineRegistered = await config.flightSuretyData.isAirline.call(
      accounts[0],
    )
    assert.equal(isAirlineRegistered, true, 'First Airline is not registered')
  })

  it('should fail if a non registered airline tries to register a new airline', async () => {
    // ARRANGE
    let newAirline = accounts[2]
    let reverted = false

    // ACT
    try {
      await config.flightSuretyApp.registerAirline(newAirline, {
        from: newAirline,
      })
    } catch (e) {
      reverted = true
    }

    // ASSERT
    assert.equal(reverted, true)
  })

  it('should only allow existing airlines to register new arline', async () => {
    // ARRANGE
    let newAirline = accounts[2]

    // ACT
    try {
      await config.flightSuretyData.registerAirline(newAirline, {
        from: accounts[0],
      })
    } catch (e) {}
    let result = await config.flightSuretyData.isAirline.call(newAirline)

    await config.flightSuretyData.unregisterAirline(newAirline, {
      from: accounts[0],
    })

    // ASSERT
    assert.equal(result, true)
  })

  it('should only register fifth or subsequent airlines with consensus of 50% of registered airlines', async () => {
    // ARRANGE
    const firstAirline = accounts[0]
    const airline2 = accounts[2]
    const airline3 = accounts[3]
    const airline4 = accounts[4]
    const airline5 = accounts[5]

    await config.flightSuretyData.registerAirline(airline2, {
      from: firstAirline,
    })
    await config.flightSuretyData.registerAirline(airline3, {
      from: firstAirline,
    })
    await config.flightSuretyData.registerAirline(airline4, {
      from: firstAirline,
    })

    // ACT
    try {
      await config.flightSuretyData.registerAirline(airline5, {
        from: firstAirline,
      })
      await config.flightSuretyData.registerAirline(airline5, {
        from: airline2,
      })
      await config.flightSuretyData.registerAirline(airline5, {
        from: airline3,
      })
    } catch (e) {}

    const wasRegistered = await config.flightSuretyData.isAirline.call(airline5)

    // ASSERT
    assert.equal(wasRegistered, true, 'Multi-party call failed')
  })
})
