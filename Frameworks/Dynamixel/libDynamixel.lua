-- Dynamixel Library
-- (c) 2013 Stephen McGill
-- (c) 2013 Daniel D. Lee

local libDynamixel = {}
local DynamixelPacket = require('DynamixelPacket');

-- Add a poor man's unix library
local unix = {}
unix.write = function(fd,msg)
	local str = string.format('%s fd:(%d) sz:(%d)',type(msg),fd,#msg)
	local str2 = 'Dec:\t'
	local str3 = 'Hex:\t'
	for i=1,#msg do
		str2 = str2..string.format('%3d ', msg:byte(i))
		str3 = str3..string.format(' %.2X ', msg:byte(i))
	end
	io.write(str,'\n',str2,'\n',str3,'\n')
	return #msg
end
unix.time = function()
	return os.clock()
end
unix.read = function(fd)
	return nil
end
unix.usleep = function(n_usec)
	--os.execute('sleep '..n_usec/1e6)
end

function libDynamixel.set_ram(fd,id,addr,value,sz)
	local inst = nil
	if sz==1 then
		inst = DynamixelPacket.write_byte(id, addr, value);
	elseif sz==2 then
		inst = DynamixelPacket.write_word(id, addr, value);
	elseif sz==4 then
		inst = DynamixelPacket.write_dword(id, addr, value);
	else
		print('BAD SZ OF WRITING')
		return nil
	end
	return unix.write(fd, inst);
end

function libDynamixel.get_ram(fd,id,addr)
	local twait = 0.100;
	local inst = DynamixelPacket.read_data(id, addr, 1);
	-- TODO: Can we eliminate the read? flush?
	unix.read(fd); -- clear old status packets
	unix.write(fd, inst)
	local status = libDynamixel.get_status(fd, twait);
	if status then
		return status.parameter[1];
	end
end

function init_device_handle(obj)
	for key,addr in pairs(mx_ram_addr) do
		--print('associate',key,addr:byte(1),addr:byte(2))
		obj['set_'..key] = function(self,id,val)
			return libDynamixel.set_ram(self.fd, id, addr, val, mx_ram_sz[key])
		end
		obj['get_'..key] = function(self,id)
			return libDynamixel.get_ram(self.fd,id,val,add)
		end
	end
	return obj
end

function libDynamixel.parse_status_packet(pkt)
	local t = {};
	t.id = pkt:byte(3);
	t.length = pkt:byte(4);
	t.error = pkt:byte(5);
	t.parameter = {pkt:byte(6,t.length+3)};
	t.checksum = pkt:byte(t.length+4);
	return t;
end

function libDynamixel.close(self)
	-- fd of 0,1,2 are stdin, stdout, sterr respectively
	if fd < 3 then
		return false
	end
	-- TODO: is there a return value here for errors/success?
	unix.close( fd );
	return true
end

libDynamixel.reset = function(self)
	--print("Reseting Dynamixel tty!");
	libDynamixel.close( self.fd );
	unix.usleep( 100000) ;
	libDynamixel.open(  self.fd, self.ttyname  );
	return true
end

libDynamixel.get_status = function( self, timeout )
	timeout = timeout or 0.010;
	local t0 = unix.time();
	local str = "";
	while unix.time()-t0 < timeout do
		local s = unix.read(fd);
		if (type(s) == "string") then
			str = str..s;
			pkt = DynamixelPacket.input(str);
			if (pkt) then
				local status = libDynamixel.parse_status_packet(pkt);
				--	    print(string.format("Status: id=%d error=%d",status.id,status.error));
				return status;
			end
		end
		unix.usleep(100);
	end
	return nil;
end

libDynamixel.send_ping = function( fd, id )
	local inst = DynamixelPacket.ping(id);
	return unix.write(fd, inst);
end

libDynamixel.ping_probe = function(fd, twait)
	twait = twait or 0.010;
	for id = 0,253 do
		io.write( string.format("Ping: Dynamixel ID %d\n",id) )
		libDynamixel.send_ping(fd, id);
		local status = libDynamixel.get_status(fd, twait);
		if status then
			io.write(status.id)
		end
	end
end

libDynamixel.set_id = function(fd, idOld, idNew)
	local addr = 3;  -- ID
	local inst = DynamixelPacket.write_byte(idOld, addr, idNew);
	return unix.write(fd, inst);
end

libDynamixel.read_data = function(fd, addr, len, twait)
	twait = twait or 0.100;
	len  = len or 2;
	local inst = DynamixelPacket.read_data(id, addr, len);
	unix.read(fd); -- clear old status packets
	unix.write(fd, inst)
	local status = libDynamixel.get_status(fd, twait);
	if (status) then
		return status.parameter;
	end
end

-- TODO: not supported yet...?
libDynamixel.bulk_read_data = function(fd, id_cm730, ids, addr, len, twait)
	twait = twait or 0.100;
	len  = len or 2;
	local inst = DynamixelPacket.bulk_read_data(
	id_cm730,string.char(unpack(ids)), addr, len, #ids);
	unix.read(fd); -- clear old status packets
	unix.write(fd, inst)
	local status = libDynamixel.get_status(fd, twait);
	if (status) then
		return status.parameter;
	end
end

libDynamixel.sync_write_byte = function(fd, ids, addr, data)
	local nid = #ids;
	local len = 1;

	local t = {};
	local n = 1;
	for i = 1,nid do
		t[n] = ids[i];
		t[n+1] =  data[i];
		n = n + len + 1;
	end
	local inst = DynamixelPacket.sync_write(addr, len,
	string.char(unpack(t)));
	unix.write(fd, inst);
end

libDynamixel.sync_write_word = function(fd, ids, addr, data)
	local nid = #ids;
	local len = 2;

	local t = {};
	local n = 1;
	for i = 1,nid do
		t[n] = ids[i];
		t[n+1],t[n+2] = DynamixelPacket.word_to_byte(data[i]);
		n = n + len + 1;
	end
	local inst = DynamixelPacket.sync_write(addr, len,
	string.char(unpack(t)));
	unix.write(fd, inst);
end

function libDynamixel.open( ttyname, ttybaud )
	-------------------------------
	-- Perform require upon an open
	local baud = ttybaud or 1000000;
	local fd = -1
	if ttyname and ttyname=='fake' then
		fd = -2; -- FAKE
	else
		unix = require('unix');
		stty = require('stty');
	end
	-------------------------------	
	if not ttyname then
		local ttys = unix.readdir("/dev");
		for i=1,#ttys do
			if (string.find(ttys[i], "tty.usb") or
			string.find(ttys[i], "ttyUSB")) then
				ttyname = "/dev/"..ttys[i];
				break;
			end
		end
	end
	assert(ttyname, "Dynamixel tty not found");

	-------------------
	if fd~=-2 then
		fd = unix.open(ttyname, unix.O_RDWR+unix.O_NOCTTY+unix.O_NONBLOCK);
		assert(fd > 2, "Could not open port");
		-- Setup serial port parameters
		stty.raw(fd);
		stty.serial(fd);
		stty.speed(fd, baud);
	end
	-------------------

	-- Object of the Dynamixel
	local obj = {}
	obj.fd = fd
	obj.ttyname = ttyname
	obj.baud = baud
	obj = init_device_handle(obj)
	return obj;
end

-- MX
local mx_ram_addr = {
	--['id'] = 3,
	['delay'] = string.char(5,0), -- Return Delay address
	['led'] = string.char(25,0),
	['torque_enable'] = string.char(24,0),
	['battery'] = string.char(42,0), -- cannot write
	['temperature'] = string.char(43,0), -- cannot write
	--['hardness'] = string.char(34,0),  -- BAD FOR for MX anyway!
	['velocity'] = string.char(32,0),
	['command'] = string.char(30,0),
	['position'] = string.char(36,0), -- cannot write
}

local mx_ram_sz = {
	['led'] = 1, --write byte
	['torque_enable'] = 1,
	['battery'] = 2,
	['temperature'] = 1,
	['velocity'] = 2,
	['command'] = 2, --write word
	['position'] = 2,
}

-- PRO
local nx_ram_addr = {
	-- Legacy API Convention --
	['led'] = string.char(0x33,0x02), -- Red Led
	['torque_enable'] = string.char(0x32,0x02), -- low, high
	['battery'] = string.char(0x6F,0x02), -- low, high
	['temperature'] = string.char(0x71,0x02), -- low, high
	['velocity'] = string.char(0x67,0x02), -- low, high
	['command'] = string.char(0x54,0x02), -- low, high
	['position'] = string.char(0x32,0x02), -- low, high
	-- New API --
	-- ENTER EEPROM AREA
	-- Operation Mode
	-- Mode 0: Torque Control
	-- Mode 1: Velocity Control
	-- Mode 2: Position Control
	-- Mode 3: position-Velocity Control
	['mode'] = string.char(0x0B,0x00),
	-- General Operation information
	['model_num']  = string.char(0x00,0x00),
	['model_info'] = string.char(0x02,0x00),
	['firmware'] =   string.char(0x06,0x00),
	['id'] =   string.char(0x07,0x00),
	['baud'] = string.char(0x08,0x00),	
	-- Limits
	['max_voltage'] = string.char(0x08,0x01),
	['max_voltage'] = string.char(0x08,0x01),
	-- ENTER RAM AREA
	-- Position Commands
	['command_velocity'] = string.char(0x58,0x02),
	['command_acceleration'] = string.char(0x58,0x02),
	-- Commanded Torque (torque control mode)
	['command_torque'] = string.char(0x5C,0x02),
	-- Position PID Gains (position control mode)
	['position_p'] = string.char(0x52,0x02),
	['position_i'] = string.char(0x50,0x02),
	['position_d'] = string.char(0x4E,0x02),
	-- Velocity PID Gains (position control mode)
	['velocity_p'] = string.char(0x46,0x02),
	['velocity_i'] = string.char(0x4A,0x02),
	['velocity_d'] = string.char(0x4C,0x02),
	-- Current PI Gains (torque control mode)
	['current_p'] = 2,
	['current_i'] = 2,
	-- Readings from the motor
	['led_red'] = string.char(0x33,0x02), -- Duplicate on purpose
	['led_green'] = string.char(0x34,0x02),
	['led_blue'] = string.char(0x35,0x02),
	['current'] = string.char(0x6D,0x02),
	['load'] = string.char(0x6B,0x02),
}

local nx_ram_sz = {
	['led'] = 1,
	['torque_enable'] = 1,
	['battery'] = 2,
	['temperature'] = 1,
	['velocity'] = 4, --write dword
	['command'] = 4,
	['position'] = 4,
	-- New 
	['command_velocity'] = 4,
	['command_acceleration'] = 4,
	['command_torque'] = 4,
	-- Position PID Gains
	['position_p'] = 2,
	['position_i'] = 2,
	['position_d'] = 2,
	-- Velocity PID Gains
	['velocity_p'] = 2,
	['velocity_i'] = 2,
	['velocity_d'] = 2,
	-- Current PI Gains
	['current_p'] = 2,
	['current_i'] = 2,
	
	['led_green'] = 1,
	['led_blue'] = 1,
	['current'] = 2,
	['load'] = 2,
}

return libDynamixel