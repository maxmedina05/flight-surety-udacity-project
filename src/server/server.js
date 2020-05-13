import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json'
import Config from './config.json'
import Web3 from 'web3'
import express from 'express'

const REGISTRATION_FEE = Web3.utils.toWei('1', 'ether')

const config = Config['localhost']
const web3 = new Web3(
  new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')),
)
const flightSuretyApp = new web3.eth.Contract(
  FlightSuretyApp.abi,
  config.appAddress,
)

web3.eth.defaultAccount = web3.eth.accounts[0]

let oracles = []
// mapping
const oraclesMap = {}

async function registerOracles(accounts) {
  oracles = accounts.slice(10, 30)
  for (let i = 0; i < oracles.length; i++) {
    const address = oracles[i]

    const estimateGas = await flightSuretyApp.methods
      .registerOracle()
      .estimateGas({ from: address, value: REGISTRATION_FEE })

    await flightSuretyApp.methods
      .registerOracle()
      .send({ from: address, value: REGISTRATION_FEE, gas: estimateGas })

    const index = await flightSuretyApp.methods
      .getMyIndexes()
      .call({ from: address })
    oraclesMap[address] = index
  }
}

async function main() {
  console.log('main')
  const accounts = await web3.eth.getAccounts()
  try {
    await registerOracles(accounts)
  } catch (e) {
    console.log(e)
  }

  flightSuretyApp.events.OracleRequest(
    {
      fromBlock: 0,
    },
    (error, event) => {
      if (error) {
        console.log(error)
      } else {
        console.log(event)
      }

      // flight is delay or not
      const flightStatus = Math.ceil(Math.random() * 5) * 10

      for (let i = 0; i < oracles.length; i++) {
        const index = oraclesMap[oracles[i]]

        flightSuretyApp.methods
          .submitOracleResponse(
            index,
            event.returnValues.airline,
            event.returnValues.flight,
            event.returnValues.timestamp,
            flightStatus,
          )
          .send({
            from: oracles[i],
          })
          .then((res) => {
            console.log(`Oracle ${oracles[i]} with status: ${flightStatus}`)
          })
          .catch((err) => {
            console.log(`Oracle ${oracles[i]} fail: ${err}`)
          })
      }
    },
  )
}

main()

const app = express()
app.get('/api', (req, res) => {
  res.send({
    message: 'An API for use with your Dapp!',
  })
})

export default app
