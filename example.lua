package.cpath = package.cpath .. ';/Users/kartben/Repositories/liblwm2m/?.so;/Users/kartben/Repositories/luasocket/src/?.so'
package.path = package.path .. ';/Users/kartben/Repositories/liblwm2m/?.lua;/Users/kartben/Repositories/luasocket/src/?.lua'

local lwm2m = require 'lwm2m'
local socket = require 'socket'
local modbus = require 'modbus'
local utils = require 'utils'

udp = socket.udp()
udp:setsockname('*', 5683)

local MODBUS_DATA_ADDRESSES = {
	temperature = 1,
	luminosity  = 2,
	humidity    = 3,
	light       = 7,
	open        = 8
}

local MODBUS_DATA_PROCESS = {
	temperature = utils.processTemperature,
	luminosity  = utils.processLuminosity,
	humidity    = utils.processHumidity,
	light  = utils.numberToBoolean,
	open  = utils.numberToBoolean,
}

device_object = {
    id = 3,
    resources = {
        [0] = "Open Mobile Alliance",    -- manufacturer
        [1] = "Lightweight M2M Client",  -- model number
        [2] = "345000123",               -- serial number
        [3] = "1.0",                     -- firmware version
        [6] = 1,
        [7] = 5,
        [9] = 100,
        [10] = 15,
        [11] = 0,
        [13] = function() return os.time() end,
        [15] = "U"
    }     
}

application_object = {
	id = 2048,
	resources = {
		{ [0] = "ECLO",
		  [1] = "v1.0",
		  [2] = '</4096/0/1>;title="Temperature",</4096/0/2>;title="Luminosity"',
		  [3] = 0 },
		{ [0] = "appname2",
		  [1] = "v2.0",
		  [2] = "**datamodel**",
		  [3] = 1 },
	}
}

eclo_modbus_values = {}
application_data_object = {
	id = 4096,
	resources = {
		eclo_modbus_values,
		-- { another app data model }, { and another } , ...
	}
}

objects = { [3] = device_object , 
			[4] = { id = 4, resources = { [0] = 'salut' } },
			[2048] = application_object, 
			[4096] = application_data_object}

client = lwm2m.init(udp:getfd(), 'testlua', objects)
mt = { __index = lwm2m }
setmetatable (client, mt)

local modbus_client = modbus.new('dummy', 'dummy')

repeat
    data, ip, port, msg = udp:receivefrom()
    print(ip)
    print(port)
    print (data)
    if data then
        client:handle(data, ip, port)
    end
    
    -- read Modbus
    local values,err = modbus_client:readHoldingRegisters(1,0,9)
    local sval, val    -- value from sensor, data value computed from the sensor value
    for data, address in pairs(MODBUS_DATA_ADDRESSES) do
		sval = utils.convertRegister(values, address)
		val = MODBUS_DATA_PROCESS[data](sval)
		eclo_modbus_values[address] = val
	end
    

until not data
