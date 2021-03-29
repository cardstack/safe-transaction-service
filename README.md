![Build Status](https://github.com/gnosis/safe-transaction-service/workflows/Python%20CI/badge.svg?branch=master)
[![Coverage Status](https://coveralls.io/repos/github/gnosis/safe-transaction-service/badge.svg?branch=master)](https://coveralls.io/github/gnosis/safe-transaction-service?branch=master)
![Python 3.9](https://img.shields.io/badge/Python-3.9-blue.svg)
![Django 3](https://img.shields.io/badge/Django-3-blue.svg)

# Gnosis Transaction Service
Keeps track of transactions sent via Gnosis Safe contracts. It uses events and
[tracing](https://openethereum.github.io/JSONRPC-trace-module) to index the txs.

Transactions are detected in an automatic way, so there is no need of informing the service about the transactions as in
previous versions of the *Transaction Service*.

Transactions can also be sent to the service to allow offchain collecting of signatures or informing the owners about
a transaction that is pending to be sent to the blockchain.

[Swagger (Mainnet version)](https://safe-transaction.gnosis.io/)
[Swagger (Rinkeby version)](https://safe-transaction.rinkeby.gnosis.io/)

## Index of contents

- [Docs](https://docs.gnosis.io/safe/docs/services_transactions/)

## Setup for production
This is the recommended configuration for running a production Transaction service. `docker-compose` is required
for running the project.

Configure the parameters needed on `.env`. These parameters **need to be changed**:
- `ETHEREUM_NODE_URL`: Http/s address of a ethereum node. It can be the same than `ETHEREUM_TRACING_NODE_URL`.
- `ETHEREUM_TRACING_NODE_URL`: Http/s address of an OpenEthereum node with
[tracing enabled](https://openethereum.github.io/JSONRPC-trace-module).

If you don't want to use `trace_filter` for the internal tx indexing and just rely on `trace_block`, set:
- `ETH_INTERNAL_NO_FILTER=1`

For more parameters check `base.py` file.

Then:
```bash
docker-compose build --force-rm
docker-compose up
```

The service should be running in `localhost:8000`. You can test everything is set up:

```bash
curl 'http://localhost:8000/api/v1/about/'
```

For example, to set up a Göerli node:

Run an OpenEthereum node in your local computer:
```bash
openethereum --chain goerli --tracing on --db-path=/media/ethereum/openethereum --unsafe-expose
```

Edit `.env` so docker points to the host OpenEthereum node:
```
ETHEREUM_NODE_URL=http://172.17.0.1:8545
ETHEREUM_TRACING_NODE_URL=http://172.17.0.1:8545
```

Then:
```bash
docker-compose build --force-rm
docker-compose up
```

## Setup for private network
Instructions for production still apply, but some additional steps are required:
- Deploy the last version of the [Safe Contracts](https://github.com/gnosis/safe-contracts) on your private network.
- Add their addresses and the number of the block they were deployed (to optimize initial indexing) to
`safe_transaction_service/history/management/commands/setup_service.py`. Service is currently configured to support
_Mainnet_, _Rinkeby_, _Goerli_ and _Kovan_.
- If you have a custom `network id` you can change this line
`ethereum_network = ethereum_client.get_network()` to `ethereum_network_id = ethereum_client.w3.net.version` and use
the `network id` instead of the `Enum`.
- Only contracts that need to be configured are the **ProxyFactory** that will be used to deploy the contracts and
the **GnosisSafe**.


Add a new method using the addresses and block numbers for your network.
```python
def setup_my_network(self):
    SafeMasterCopy.objects.get_or_create(address='0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F',
                                             defaults={
                                                 'initial_block_number': 9084503,
                                                 'tx_block_number': 9084503,
                                             })
    ProxyFactory.objects.get_or_create(address='0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B',
                                           defaults={
                                               'initial_block_number': 9084508,
                                               'tx_block_number': 9084508,
                                           })
```

Replace `handle` method for:
```python
    def handle(self, *args, **options):
        for task in self.tasks:
            _, created = task.create_task()
            if created:
                self.stdout.write(self.style.SUCCESS('Created Periodic Task %s' % task.name))
            else:
                self.stdout.write(self.style.SUCCESS('Task %s was already created' % task.name))

        self.stdout.write(self.style.SUCCESS('Setting up Safe Contract Addresses'))
        self.setup_my_network()
```

## Use admin interface
Services come with a basic administration web ui (provided by Django). A user must be created first to
get access:
```bash
docker exec -it safe-transaction-service_web_1 bash
python manage.py createsuperuser
```

Then go to the web browser and navigate to http://localhost:8000/admin/

## Cardstack Deployment
Cardstack hosts this fork of the transaction service to provide capability to the Sokol network (checkout the 'sokol' branch). This is hosted at: https://transactions-staging.stack.cards. In production we leverage the xDai transaction service hosted at: # services at https://safe-transaction.xdai.gnosis.io

## API
Below are some examples of how to use this API for gnosis safes.

### Getting Safes by Owner (aka Fetching Prepaid Cards)
To get all the safes for a particular owner's wallet address (or in other words, to get all the prepaid cards held by a particular individual), use the `/safes` API:

```js
let { safes } = await (await fetch(`https://safe-transaction.xdai.gnosis.io/owners/${myWalletAddress}`)).json();
// 'safes' is an array of ethereum addresses that are gnosis safe addresses, aka prepaid card ID's.
```

To confirm the safe is a prepaid card safe you can query the PrepaidCardManager contract to see if it knows about this safe:
```js
let web3 = new Web3(provider);
let prepaidCardManagerContract = web3.eth.Contract(/*contractABI, prepaidCardContractAddress*/);
let cardDetail = await prepaidCardManagerContract.methods.cardDetails(safeAddress).call();
// if the response is falsy then the safe address is not a prepaid card address.
// otherwise the response is an object that has 2 properties:
// {
//   issuer: '0x123...', the address of the entity that created the prepaid card
//   issuerToken: '0x456..' the address of the L2 token used to create the prepaid card
// }
```

The L2 token will be held by the gnosis safe, such that, if you want to see the token balance for the safe, you can query the token contract using the safe address (aka prepaid card ID).
```js
let l2TokenContract = web3.eth.Contract(/*contractABI, l2TokenContractAddress*/);
let decimals18Balance = await l2TokenContract.methods.balanceOf(safeAddress).call();
let humanFriendlyBalance = web3.utils.fromWei(decimals18Balance); // this is a convenient util for decimals=18 tokens
```

## Contributors
- Denís Graña (denis@gnosis.pm)
- Giacomo Licari (giacomo.licari@gnosis.pm)
- Uxío Fuentefría (uxio@gnosis.pm)
