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

    updateData(contract)

    DOM.elid('registerAirlineBtn').addEventListener('click', () =>
      handleRegisterAirline(contract),
    )
    DOM.elid('fundAirlineBtn').addEventListener('click', () =>
      handleFundAirline(contract),
    )

    DOM.elid('BuyInsuranceBtn').addEventListener('click', () =>
      handleBuyInsurance(contract),
    )

    DOM.elid('withdrawBtn').addEventListener('click', () =>
      handleWithdraw(contract),
    )

    // User-submitted transaction
    DOM.elid('submit-oracle').addEventListener('click', () => {
      let flight = DOM.elid('flight-number').value
      // Write transaction
      contract.fetchFlightStatus(flight, (error, result) => {
        console.log(result)
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

async function populateAirlineForm(contract) {
  const select = DOM.elid('registerAirlineFormAirlineSelect')
  const airlines = contract.getAirlines()

  while (select.childElementCount > 1) {
    const lastChild = select.lastChild
    select.removeChild(lastChild)
  }

  const options = []

  for (const address of airlines) {
    const isAirlineRegistered = await contract.isAirlineRegistered(address)

    if (!isAirlineRegistered) {
      options.push(DOM.option(address, { value: address }))
    }
  }

  DOM.appendArray(select, options)
}

async function populateFundAirlineForm(contract) {
  const select = DOM.elid('fundAirlineFormAirlineSelect')

  while (select.childElementCount > 1) {
    const lastChild = select.lastChild
    select.removeChild(lastChild)
  }

  const airlines = await getRegisteredAirlines(contract)
  const options = []

  airlines.forEach((address) => {
    options.push(DOM.option(address, { value: address }))
  })

  DOM.appendArray(select, options)
}

async function populateRegisteredArlines(contract) {
  const tableBody = DOM.elid('registeredAirlineTableBody')
  tableBody.innerHTML = ''
  // while(select.childElementCount > 0) {
  //   const lastChild = select.lastChild
  //   select.removeChild(lastChild)
  // }

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

async function populateBuyInsuranceForm(contract) {
  const select = DOM.elid('buyFlightInsuranceAirlineSelect')
  const timestampInput = DOM.elid('timestampInput')

  timestampInput.value = new Date().toISOString().slice(0, 10)

  while (select.childElementCount > 1) {
    const lastChild = select.lastChild
    select.removeChild(lastChild)
  }

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
  updateData(contract)
}

async function handleFundAirline(contract) {
  const select = DOM.elid('fundAirlineFormAirlineSelect')
  const address = select.value

  await contract.fundAirline(address)
  updateData(contract)
}

async function handleBuyInsurance(contract) {
  const amountInput = DOM.elid('amountInput').value
  const amount = parseInt(amountInput)
  const selectedAirline = DOM.elid('buyFlightInsuranceAirlineSelect').value
  const selectedFlight = DOM.elid('flightSelect').value
  const timestamp = new Date(DOM.elid('timestampInput').value).getTime()

  console.log(amount)
  await contract.buyInsurance(
    selectedAirline,
    selectedFlight,
    timestamp,
    amount,
  )
}

async function handleWithdraw(contract) {
  try {
    const amount = await contract.withdraw()

    console.log(amount)

    alert(`You have been credited with ${amount} `)
  } catch (e) {
    console.log(e)
    alert(e)
  }
}

function updateData(contract) {
  populateRegisteredArlines(contract)
  populateAirlineForm(contract)
  populateFundAirlineForm(contract)
  populateBuyInsuranceForm(contract)
}
