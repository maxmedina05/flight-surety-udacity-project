var Test = require('../config/testConfig.js')
var BigNumber = require('bignumber.js')

contract('Flight Surety Tests', async (accounts) => {
  var config

  before('setup contract', async () => {
    try {
      config = await Test.Config(accounts)
      await config.flightSuretyData.authorizeCaller(
        config.flightSuretyApp.address,
      )
    } catch (e) {
      console.log(e)
    }
  })

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/
  it('should register first airline when contract is deployed', async () => {
    let result = false

    try {
      result = await config.flightSuretyApp.isAirline.call(config.owner)
    } catch (e) {
      console.log(e)
    }

    assert.equal(result, true, 'First Airline is not registered')
  })

  it('should fail if a non registered airline tries to register a new airline', async () => {
    // ARRANGE
    const newAirline = accounts[2]
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

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    // ARRANGE
    const firstAirline = accounts[1]
    const newAirline = accounts[2]

    // ACT
    try {
      await config.flightSuretyApp.registerAirline(firstAirline, {
        from: config.owner,
      })

      await config.flightSuretyApp.registerAirline(newAirline, {
        from: firstAirline,
      })
    } catch (e) {}

    const result = await config.flightSuretyApp.isAirline.call(newAirline)

    // ASSERT
    assert.equal(
      result,
      false,
      "Airline should not be able to register another airline if it hasn't provided funding",
    )
  })

  it('should only register fifth or subsequent airlines with consensus of 50% of registered airlines', async () => {
    // ARRANGE
    const airline2 = accounts[1]
    const airline3 = accounts[2]
    const airline4 = accounts[3]
    const airline5 = accounts[4]
    const fee = web3.utils.toWei('10', 'ether')

    // ACT
    try {
      // await config.flightSuretyApp.fund({
      //   from: config.owner,
      //   value: fee,
      // })

      await config.flightSuretyData.registerAirline(airline2, {
        from: config.owner,
      })

      await config.flightSuretyApp.registerAirline(airline3, {
        from: config.owner,
      })

      await config.flightSuretyApp.registerAirline(airline4, {
        from: config.owner,
      })

      await config.flightSuretyApp.fund({
        from: airline2,
        value: fee,
      })

      await config.flightSuretyApp.fund({
        from: airline3,
        value: fee,
      })

      await config.flightSuretyApp.fund({
        from: airline4,
        value: fee,
      })

      await config.flightSuretyApp.registerAirline(airline5, {
        from: config.owner,
      })
      await config.flightSuretyApp.registerAirline(airline5, {
        from: airline2,
      })
    } catch (e) {
      console.log('e:', e)
    }

    const wasRegistered = await config.flightSuretyApp.isAirline.call(airline5)

    // ASSERT
    assert.equal(wasRegistered, true, 'Airline was not registered')
  })

  it(`(multiparty) has correct initial isOperational() value`, async function () {
    // Get operating status
    let status = await config.flightSuretyData.isOperational.call()
    assert.equal(status, true, 'Incorrect initial operating status value')
  })

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
    // Ensure that access is denied for non-Contract Owner account
    let accessDenied = false
    try {
      await config.flightSuretyData.setOperatingStatus(false, {
        from: config.testAddresses[2],
      })
    } catch (e) {
      accessDenied = true
    }
    assert.equal(accessDenied, true, 'Access not restricted to Contract Owner')
  })

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
    // Ensure that access is allowed for Contract Owner account
    let accessDenied = false
    try {
      await config.flightSuretyData.setOperatingStatus(false)
    } catch (e) {
      accessDenied = true
    }
    assert.equal(accessDenied, false, 'Access not restricted to Contract Owner')
  })

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {
    await config.flightSuretyData.setOperatingStatus(false)

    let reverted = false
    try {
      await config.flightSurety.setTestingMode(true)
    } catch (e) {
      reverted = true
    }
    assert.equal(reverted, true, 'Access not blocked for requireIsOperational')

    // Set it back for other tests to work
    await config.flightSuretyData.setOperatingStatus(true)
  })

  it('should allow passengers to pay up to 1 ether for purchasing insurance', async () => {
    const price = web3.utils.toWei('5', 'ether')
    const airline1 = accounts[0]
    const insuree = accounts[5]
    // const timestamp = new Date('2020-05-10').getTime()
    let reverted = false

    try {
      await config.flightSuretyApp.buy(airline1, {
        from: insuree,
        value: price,
      })
    } catch (e) {
      reverted = true
    }

    assert.equal(
      reverted,
      true,
      'Access not blocked for requireNoMoreThanOneEther',
    )
  })
})
