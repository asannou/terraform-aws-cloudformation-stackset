'use strict';

const https = require('https');
const url = require('url');
const AWS = require('aws-sdk');

async function processRecord(record, context) {

  const message = JSON.parse(record.Sns.Message);

  try {
    await processMessage(message);
    await sendResponse(message, context, 'SUCCESS', {});
  } catch(e) {
    console.log(e);
    await sendResponse(message, context, 'FAILED', {});
  }

}

async function processMessage(message) {

  const [, , , region, accountId] = message.StackId.split(':');
  AWS.config.update({ region: region });

  switch (message.ResourceType) {
    case 'Custom::GuardDutyMember':
      switch (message.RequestType) {
        case 'Create':
        case 'Update':
          const email = message.ResourceProperties.Email;
          await createMember(accountId, email);
          break;
        case 'Delete':
          await deleteMember(accountId);
          break;
        default:
          throw Error('invalid RequestType');
      }
      break;
    default:
      throw Error('invalid ResourceType');
  }

}

async function createMember(accountId, email) {

  const guardduty = new AWS.GuardDuty();
  const detectors = await guardduty.listDetectors().promise();
  const detectorId = detectors.DetectorIds[0];

  if (!email) {
    const organizations = new AWS.Organizations({ region: 'us-east-1' });
    const account = await organizations.describeAccount({
      AccountId: accountId
    }).promise();
    email = account.Account.Email;
  }

  await guardduty.createMembers({
    DetectorId: detectorId,
    AccountDetails: [
      {
        AccountId: accountId,
        Email: email,
      }
    ],
  }).promise();

  await guardduty.inviteMembers({
    DetectorId: detectorId,
    AccountIds: [accountId],
    DisableEmailNotification: true,
  }).promise();

}

async function deleteMember(accountId) {

  const guardduty = new AWS.GuardDuty();
  const detectors = await guardduty.listDetectors().promise();
  const detectorId = detectors.DetectorIds[0];

  await guardduty.deleteMembers({
    DetectorId: detectorId,
    AccountIds: [accountId],
  }).promise();

}

function sendResponse(message, context, responseStatus, responseData, physicalResourceId, noEcho) {

  const responseBody = JSON.stringify({
    Status: responseStatus,
    Reason: 'See the details in CloudWatch Log Stream: ' + context.logStreamName,
    PhysicalResourceId: physicalResourceId || context.logStreamName,
    StackId: message.StackId,
    RequestId: message.RequestId,
    LogicalResourceId: message.LogicalResourceId,
    NoEcho: noEcho || false,
    Data: responseData
  });
  console.log('Response body:\n', responseBody);

  const parsedUrl = url.parse(message.ResponseURL);
  const options = {
    hostname: parsedUrl.hostname,
    port: 443,
    path: parsedUrl.path,
    method: 'PUT',
    headers: {
      'content-type': '',
      'content-length': responseBody.length
    }
  };

  return new Promise((resolve, reject) => {
    var request = https.request(options, (response) => {
      console.log('Status code: ' + response.statusCode);
      console.log('Status message: ' + response.statusMessage);
      resolve();
    });
    request.on('error', (error) => {
      console.log('sendResponse(..) failed executing https.request(..): ' + error);
      reject();
    });
    request.write(responseBody);
    request.end();
  });

}

exports.handler = async (event, context) => {
  console.log('Received event:', JSON.stringify(event, null, 2));
  for (const record of event.Records) {
    await processRecord(record, context);
  }
};

