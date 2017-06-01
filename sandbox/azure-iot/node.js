/* NodeJS:    iot-node-graz-001.js

Author:    Ryan Irujo
Inception: 06.04.2016


This Script Requires NodeJS 4.x or Higher!

Communiation methods available:

- HTTP
- AMQP - Advanced Message Queuing Protocol
- MQTT - Message Queue Telemetry Protocol


Register this device with the Azure IoT Hub First! (use the iothubowner policy)

iothub-explorer create IOT-NODE-GRAZ-001 --connection-string

Make sure to replace the 'connectionString' variable with a Connection string from the Shared access policies section of where the IoT Device is registered in an 
Azure IoT Hub. i.e. - HostName=luma-azure-iot-mflr.azure-devices.net;SharedAccessKeyName=device;SharedAccessKey=H50ZGqWqnixy1QmDta3R5EEqIIrmWV74buDk3EB+X4U=

*/

//crontab configuration: */5 * * * * /usr/local/bin/node /home/pi/azure-iot-sdks/node/device/samples/iot-node-graz-001.js >> /var/log/iot-node-graz-001.log 2>&1

'use strict';

// Importing required Javascript Functions for running bash commands locally.
var util             = require('util');
var exec             = require('child_process').execSync;
var sleep            = require('sleep');

// Importing required Javascript Functions from additional Files.
var Protocol         = require('azure-iot-device-http').Http;
var Client           = require('azure-iot-device').Client;
var Message          = require('azure-iot-device').Message;
var ConnectionString = require('azure-iot-device').ConnectionString;

// String containing Hostname, Device Id & Device Key in the following formats:
var connectionString = 'HostName=luma-azure-iot-mflr.azure-devices.net;DeviceId=IOT-NODE-GRAZ-001;SharedAccessKey=RJeZl+NJP4G3jPp4eivPsxqOOU0mNpQq9gNUugddatc=';
var deviceId         = ConnectionString.parse(connectionString).DeviceId;

// Helper function for returning values from bash commands.
function puts(error, stdout, stderr) {
  util.puts(stdout)
}

// Retrieving Raspberry Pi Device information.
var machineModel        = exec("dmesg | grep 'Machine model' | cut -c31-100 | tr -d '\n'", puts);
var serialNumber        = exec("cat /proc/cpuinfo | grep -e Serial | awk '{ print $3 }' | tr -d '\n'", puts);
var processorType       = exec("cat /proc/cpuinfo | grep -e 'model name' | awk 'NR==1{ print $4 }' | tr -d '\n'", puts);
var totalMemoryMB       = exec("cat /proc/meminfo | grep MemTotal | awk '{ print $2 / 1024 }' | cut -d . -f 1 | tr -d '\n'", puts);
var hardwareRevision    = exec("cat /proc/cpuinfo | grep Revision | awk '{ print $3 }' | cut -d . -f 1 | tr -d '\n'", puts);
var operatingSystem     = exec("cat /etc/os-release | grep PRETTY_NAME | cut -d '\"' -f 2 | tr -d '\n'", puts);
var linuxKernelVersion  = exec("uname -r | tr -d '\n'", puts);

// Sensor Sample Data
var temperature         = 50;
var humidity            = 50;
var externalTemperature = 55;

// Create IoT Hub client
var client = Client.fromConnectionString(connectionString, Protocol);

// Helper function to print results for an operation
function printErrorFor(op) {
  return function printError(err) {
    if (err) console.log(op + ' error: ' + err.toString());
  };
}

// Helper function to generate random number between min and max
//function generateRandomIncrement() {
//  return ((Math.random() * 2) - 1);
//}

// Function to retrieve the current time in UTC.
function getCurrentTime() {
  return exec("date +\"%Y-%m-%dT%H:%M:%S.%NZ\" | tr -d '\n'", puts);
}

// Function to retrieve the Raspberry pi CPU Temperature (Celsius).
function getCPUTemperature() {
  return exec("cat /sys/class/thermal/thermal_zone0/temp | awk '{ print $0 / 1000 }' | cut -c 1-4 | tr -d '\n'", puts);
}

// Function to retrieve the Raspberry Pi GPU Temperature (Celsius).
function getGPUTemperature() {
  return exec("/opt/vc/bin/vcgencmd measure_temp | grep -o -P \"(?<=temp=).*(?='C)\" | tr -d '\n'", puts);
}

// Function to test the availability of the Azure Portal.
function queryAzurePortal() {
  return exec("curl -I -s -S https://portal.azure.com | grep HTTP | awk '{ print $2 }' | tr -d '\n'", puts);
}

// Function to test the response time of the Azure Portal.
function queryAzurePortalResponseTime() {
  return exec("curl https://portal.azure.com -s -o /dev/null -w %{time_total}", puts);
}

// Declaring currentTime, cpuTemperature, gpuTemperature, azurePortalResponseTime, and azurePortalStatusCode Variable(s).
var currentTime             = null;
var cpuTemperature          = null;
var gpuTemperature          = null;
var azurePortalStatusCode   = null;
var azurePortalResponseTime = null;

// Send device meta data
var deviceMetaData = {
  'ObjectType': 'DeviceInfo',
  'IsSimulatedDevice': 1,
  'Version': String(hardwareRevision),
  //'CurrentTime': String(getCurrentTime()),
  'DeviceProperties': {
    'DeviceID': deviceId,
    'HubEnabledState': 0,
    //'CurrentTime': String(getCurrentTime()),
    'CreatedTime': '2016-01-01T12:12:12.1234567Z',
    'DeviceState': 'normal',
    'UpdatedTime': null,
    'MachineModel': String(machineModel),
    'OperatingSystem': String(operatingSystem),
    'HardwareRevision': String(hardwareRevision),
    'SerialNumber': String(serialNumber),
    'FirmwareVersion': String(linuxKernelVersion),
    'Platform': 'node.js',
    'Processor': String(processorType),
    'InstalledRAM': String(totalMemoryMB) + ' MB',
    'Latitude': 48.2190,
    'Longitude': 16.4950
  },
  'Commands': [{
    'Name': 'SetTemperature',
    'Parameters': [{
      'Name': 'Temperature',
      'Type': 'double'
        }]
      },
    {
    'Name': 'SetHumidity',
    'Parameters': [{
      'Name': 'Humidity',
      'Type': 'double'
        }]
    }
  ]
};

client.open(function (err, result) {
  if (err) {
    printErrorFor('open')(err);
  } else {
    console.log('Sending device metadata:\n' + JSON.stringify(deviceMetaData));
    client.sendEvent(new Message(JSON.stringify(deviceMetaData)), printErrorFor('send metadata'));

    client.on('message', function (msg) {
      console.log('receive data: ' + msg.getData());

      try {
        var command = JSON.parse(msg.getData());
        if (command.Name === 'SetTemperature') {
          temperature = command.Parameters.Temperature;
          console.log('New temperature set to :' + temperature + 'F');
        }

        client.complete(msg, printErrorFor('complete'));
      }
      catch (err) {
        printErrorFor('parse received message')(err);
        client.reject(msg, printErrorFor('reject'));
      }
    });

    // Declaring msgcount variable outside of client.SendEvent loop so it can be incremented.
    // var message  = new Message(data)
    var msgcount = 0;

    // Start Event Data Send Routing.
    var sendInterval          = setInterval(function () {
      //temperature             += generateRandomIncrement();
      //externalTemperature     += generateRandomIncrement();
      //humidity                += generateRandomIncrement();
      cpuTemperature          = getCPUTemperature();
      gpuTemperature          = getGPUTemperature();
      azurePortalStatusCode   = queryAzurePortal();
      azurePortalResponseTime = queryAzurePortalResponseTime();
      currentTime             = getCurrentTime();

      // Converting data to a JSON String.
      var data = JSON.stringify({
        'DeviceID': deviceId,
        //'Temperature': temperature,
        //'Humidity': humidity,
        //'ExternalTemperature': externalTemperature,
        'CPUTemperature': parseFloat(cpuTemperature),
        'GPUTemperature': parseFloat(gpuTemperature),
        'AzurePortalStatusCode': parseFloat(azurePortalStatusCode),
        'AzurePortalResponseTime': parseFloat(azurePortalResponseTime),
        'CurrentTime': String(currentTime)
      });

      // Declaring msg and msgcount Variables.
      var message  = new Message(data);

        if (msgcount < 1) {
          console.log('Message Count = ' + msgcount + '. Incrementing Message Count.');
          msgcount++
        }

      // Sending Event Data to Azure IoT Hub and then exiting.
      console.log('Sending device event data:\n' + data);
      client.sendEvent(message, function(err) {
        if (msgcount == 1) {
          console.log('1 Messages Sent, exiting Script.\n');
          sleep.sleep(1);
          process.exit(0);
        }
        else if (err) {
          console.log(err.toString());
          client.close();
        }
      });
      sleep.sleep(1);
    });
  }
});
