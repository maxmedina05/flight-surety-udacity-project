import DOM from './dom'
import Contract from './contract'
import './flightsurety.css'
;(async () => {
  let result = null

  let contract = new Contract('localhost', () => {
    // Read transaction
    contract.isOperational((error, result) => {
      console.log(error, result)
      display('Operational Status', 'Check if contract is operational', [
        { label: 'Operational Status', error: error, value: result },
      ])
    })

    displayRegisteredArlines(contract)

    addAirlinesToRegisterAirlineForm(contract)
    addRegisteredAirlinesToFundAirlineForm(contract)

    // DOM.elid('registerAirlineForm').addEventListener('submit', (e) =>
    //   handleRegisterAirline(e, contract),
    // )
    DOM.elid('registerAirlineBtn').addEventListener('click', () => handleRegisterAirline(contract))
    DOM.elid('fundAirlineBtn').addEventListener('click', () => handleFundAirline(contract))
    // User-submitted transaction
    DOM.elid('submit-oracle').addEventListener('click', () => {
      let flight = DOM.elid('flight-number').value
      // Write transaction
      contract.fetchFlightStatus(flight, (error, result) => {
        display('Oracles', 'Trigger oracles', [
          {
            label: 'Fetch Flight Status',
            error: error,
            value: result.flight + ' ' + result.timestamp,
          },
        ])
      })
    })
  })
})()

async function getRegisteredAirlines(contract) {
  const addresses = contract.getAirlines()
  const registeredAirlines = []

  for (const address of addresses) {
    const isRegistered = await contract.isAirlineRegistered(address)

    if (isRegistered) {
      registeredAirlines.push(address)
    }
  }

  return registeredAirlines
}

function display(title, description, results) {
  let displayDiv = DOM.elid('display-wrapper')
  let section = DOM.section()
  section.appendChild(DOM.h2(title))
  section.appendChild(DOM.h5(description))
  results.map((result) => {
    let row = section.appendChild(DOM.div({ className: 'row' }))
    row.appendChild(DOM.div({ className: 'col-sm-4 field' }, result.label))
    row.appendChild(
      DOM.div(
        { className: 'col-sm-8 field-value' },
        result.error ? String(result.error) : String(result.value),
      ),
    )
    section.appendChild(row)
  })
  displayDiv.append(section)
}

function addAirlinesToRegisterAirlineForm(contract) {
  console.log('addAirlinesToRegisterAirlineForm')
  const select = DOM.elid('registerAirlineFormAirlineSelect')
  const airlines = contract.getAirlines()

  const options = []

  airlines.forEach((address) => {
    options.push(DOM.option(address, { value: address }))
  })

  DOM.appendArray(select, options)
}

async function addRegisteredAirlinesToFundAirlineForm(contract) {
  const select = DOM.elid('fundAirlineFormAirlineSelect')
  const airlines = await getRegisteredAirlines(contract)

  const options = []

  airlines.forEach((address) => {
    options.push(DOM.option(address, { value: address }))
  })

  DOM.appendArray(select, options)
}

async function handleRegisterAirline(contract) {
  const select = DOM.elid('registerAirlineFormAirlineSelect')
  const address = select.value

  await contract.registerAirline(address)
  displayRegisteredArlines(contract)
}

async function handleFundAirline(contract) {
  const select = DOM.elid('fundAirlineFormAirlineSelect')
  const address = select.value

  await contract.fundAirline(address)
  displayRegisteredArlines(contract)
}

async function displayRegisteredArlines(contract) {
  const tableBody = DOM.elid('registeredAirlineTableBody')
  tableBody.innerHTML = ''

  const addresses = contract.getAirlines()
  const registeredAirlines = []

  for (const address of addresses) {
    const isRegistered = await contract.isAirlineRegistered(address)

    if (isRegistered) {
      const fund = await contract.getAirlineFunds(address)
      registeredAirlines.push({
        address,
        fund,
      })
    }
  }

  const rows = []

  let idx = 1
  registeredAirlines.forEach(({ address, fund }) => {
    const row = DOM.makeElement('tr')
    row.innerHTML = `<td>${idx++}</td><td>${address}</td><td>${fund} ether <td/>`
    rows.push(row)
  })

  DOM.appendArray(tableBody, rows)
}
