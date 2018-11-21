'use strict';
const shim = require('fabric-shim');
const util = require('util');

let Chaincode = class {
  async Init(stub) {
    console.info('=========== Instantiated events chaincode ===========');
    return shim.success();
  }

  async Invoke(stub) {
    let ret = stub.getFunctionAndParameters();
    console.info(ret);

    let method = this[ret.fcn];
    if (!method) {
      console.error('no function of name:' + ret.fcn + ' found');
      throw new Error('Received unknown function ' + ret.fcn + ' invocation');
    }
    try {
      let payload = await method(stub, ret.params);
      return shim.success(payload);
    } catch (err) {
      console.log(err);
      return shim.error(err);
    }
  }

  async initLedger(stub, args) {
  }

  async queryEvents(stub, args) {
    if (args.length != 1) {
      throw new Error('Incorrect number of arguments. Expecting Id ex: 11111');
    }
    let id = args[0];

    let eventAsBytes = await stub.getState(id); 
    if (!eventAsBytes || eventAsBytes.toString().length <= 0) {
      throw new Error(carNumber + ' does not exist: ');
    }
    console.log(eventAsBytes.toString());
    return eventAsBytes;
  }

  async recordEvents(stub, args) {
    if (args.length != 5) {
      throw new Error('Incorrect number of arguments. Expecting 5');
    }
    var events = {
      docType: 'events',
      category: args[1],
      name: args[2],
      timestamp: args[3],
      data: args[4]
    };

    await stub.putState(args[0], Buffer.from(JSON.stringify(events)));
  }

  async queryAllEvents(stub, args) {

    let startKey = '0';
    let endKey = '999';

    let iterator = await stub.getStateByRange(startKey, endKey);

    let allResults = [];
    while (true) {
      let res = await iterator.next();

      if (res.value && res.value.value.toString()) {
        let jsonRes = {};
        console.log(res.value.value.toString('utf8'));

        jsonRes.Key = res.value.key;
        try {
          jsonRes.Record = JSON.parse(res.value.value.toString('utf8'));
        } catch (err) {
          console.log(err);
          jsonRes.Record = res.value.value.toString('utf8');
        }
        allResults.push(jsonRes);
      }
      if (res.done) {
        console.log('end of data');
        await iterator.close();
        console.info(allResults);
        return Buffer.from(JSON.stringify(allResults));
      }
    }
  }

  async getHistory(stub, args) {
    if (args.length != 1) {
      throw new Error('Incorrect number of arguments. Expecting Id ex: 11111');
    }
    let id = args[0];
    let iterator = await stub.getHistoryForKey(id);

    let allResults = [];
    while (true) {
      let res = await iterator.next();
      if (res.value && res.value.value.toString()) {
        console.log(res.value.value.toString('utf8'));
        let jsonRes = {};
        jsonRes.TxId = res.value.tx_id;
        try {
          jsonRes.Value = JSON.parse(res.value.value.toString('utf8'));
        } catch (err) {
          console.log(err);
          jsonRes.Value = res.value.value.toString('utf8');
        }
        allResults.push(jsonRes);
      }
      if (res.done) {
        console.log('end of data');
        await iterator.close();
        console.info(allResults);
        return Buffer.from(JSON.stringify(allResults));
      }
    }
  }
};

shim.start(new Chaincode());
