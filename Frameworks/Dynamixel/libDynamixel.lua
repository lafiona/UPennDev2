-- Dynamixel Library
-- (c) 2013 Stephen McGill
-- (c) 2013 Daniel D. Lee

local libDynamixel = {}
local DP1 = require('DynamixelPacket1'); -- 1.0 protocol
local DP2 = require('DynamixelPacket2'); -- 2.0 protocol

-- RX (uses 1.0)
local rx_ram_addr = {
	['id'] = 3,
  ['baud'] = 4,
	['delay'] = 5,
	['led'] = 25,
	['command'] = 30,
	['position'] = 36,
	['battery'] = 42,
	['temperature'] = 43,
	['torque_enable'] = 24,
}
local rx_ram_sz = {
	['id'] = 1,
  ['baud'] = 1,
	['delay'] = 1,
	['led'] = 1,
	['command'] = 2,
	['hardness'] = 2,
	['position'] = 2,
	['battery'] = 2,
	['temperature'] = 1,
	['torque_enable'] = 1,
}

-- MX
local mx_ram_addr = {
	['id'] = string.char(3,0),
  ['baud'] = string.char(4,0),
	['delay'] = string.char(5,0),
	['led'] = string.char(25,0),
	['command'] = string.char(30,0),
	['torque_enable'] = string.char(24,0),
	-- Position PID Gains (position control mode)
	['position_p'] = string.char(28,0),
	['position_i'] = string.char(27,0),
	['position_d'] = string.char(26,0),
	-- Present information
	['velocity'] = string.char(32,0),
	['position'] = string.char(36,0),
	['battery'] = string.char(42,0),
	['temperature'] = string.char(43,0),
  ['status_return_level'] = string.char(16,0);
}
local mx_ram_sz = {
	['id'] = 1,
  ['baud'] = 1,
	['led'] = 1,
	['delay'] = 1,
	['torque_enable'] = 1,
	['command'] = 2,
	['hardness'] = 2,
	['velocity'] = 2,
	['position'] = 2,
	['position_p'] = 1,
	['position_i'] = 1,
	['position_d'] = 1,
	['battery'] = 2,
	['temperature'] = 1,
  ['status_return_level'] = 1,
}

-- Dynamixel PRO
-- English to Hex Addresses of various commands/information
-- Convention: string.char( LOW_BYTE, HIGH_BYTE )
local nx_ram_addr = {
	
	-- Legacy API Convention --
	-- TODO: Manually write legacy functions
	-- Comments adjacent gives the corresponding New API key
	--['led'] = string.char(0x33,0x02), -- Red Led
	--['battery'] = string.char(0x6F,0x02), -- Voltage
	--['command'] = string.char(0x54,0x02), -- command_position
	
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
	--[[
	0: 2400 ,1: 57600, 2: 115200, 3: 1Mbps, 4: 2Mbps
	5: 3Mbps, 6: 4Mbps, 7: 4.5Mbps, 8: 10.5Mbps
	--]]
	-- Limits
	['max_temperature'] = string.char(0x15,0x00),
	['max_voltage'] = string.char(0x16,0x00),
	['min_voltage'] = string.char(0x18,0x00),
	['max_acceleration'] = string.char(0x1A,0x00),
	['max_torque'] = string.char(0x1E,0x00),
	['max_velocity'] = string.char(0x20,0x00),
	['max_position'] = string.char(0x24,0x00),
	['min_position'] = string.char(0x28,0x00),
	['shutdown'] = string.char(0x30,0x00),
	
	-- ENTER RAM AREA
	['torque_enable'] = string.char(0x32,0x02), -- Same in new API
	-- Position Options --
	-- Position Commands (position control mode)
	['command_position'] = string.char(0x54,0x02),
	['command_velocity'] = string.char(0x58,0x02),
	['command_acceleration'] = string.char(0x5E,0x02),
	-- Position PID Gains (position control mode)
	['position_p'] = string.char(0x52,0x02),
	['position_i'] = string.char(0x50,0x02),
	['position_d'] = string.char(0x4E,0x02),
	-- Velocity PID Gains (position control mode)
	['velocity_p'] = string.char(0x46,0x02),
	['velocity_i'] = string.char(0x4A,0x02),
	['velocity_d'] = string.char(0x4C,0x02),
	-- Low Pass Fitler settings
	['position_lpf'] = string.char(0x42,0x02),
	['velocity_lpf'] = string.char(0x46,0x02),
	-- Feed Forward mechanism
	['acceleration_ff'] = string.char(0x3A,0x02),
	['velocity_ff'] = string.char(0x3E,0x02),
	
	-- Torque options --
	-- Commanded Torque (torque control mode)
	['command_torque'] = string.char(0x5C,0x02),
	-- Current (V=iR) PI Gains (torque control mode)
	['current_p'] = string.char(0x38,0x02),
	['current_i'] = string.char(0x36,0x02),

	-- LED lighting
	['led_red'] = string.char(0x33,0x02),
	['led_green'] = string.char(0x34,0x02),
	['led_blue'] = string.char(0x35,0x02),
	
	-- Present information
	['position'] = string.char(0x63,0x02), -- Same in new API
	['velocity'] = string.char(0x67,0x02), -- Same in new API
	['current'] = string.char(0x6D,0x02),
	['load'] = string.char(0x6B,0x02),
	['voltage'] = string.char(0x6F,0x02),
	['temperature'] = string.char(0x71,0x02), -- Same in new API
}
-- Size on RAM/EEPROM in bytes
local nx_ram_sz = {
	-- Legacy API --
	['led'] = 1,
	['battery'] = 2,
	['command'] = 4,
	-- Same in legacy and new
	['velocity'] = 4,
	['position'] = 4,
	['temperature'] = 1,
	['torque_enable'] = 1,
	-- New API --
	['model_num']  = 2,
	['model_info'] = 4,
	['firmware'] = 1,
	['id'] = 1,
	['baud'] = 1,
	['mode'] = 1,
	-- Limits
	['max_temperature'] = 1,
	['max_voltage'] = 2,
	['min_voltage'] = 2,
	['max_acceleration'] = 4,
	['max_torque'] = 2,
	['max_velocity'] = 4,
	['max_position'] = 4,
	['min_position'] = 4,
	['shutdown'] = 1,
	-- Position Control
	['command_position'] = 4,
	['command_velocity'] = 4,
	['command_acceleration'] = 4,
	-- Gains
	['position_p'] = 2,
	['position_i'] = 2,
	['position_d'] = 2,
	['velocity_p'] = 2,
	['velocity_i'] = 2,
	['velocity_d'] = 2,
	-- Advanced Position Control
	['position_lpf'] = 4,
	['velocity_lpf'] = 4,
	['acceleration_ff'] = 4,
	['velocity_ff'] = 4,
	-- Torque Control
	['command_torque'] = 4,
	-- Current PI Gains
	['current_p'] = 2,
	['current_i'] = 2,
	-- Indicators
	['led_red'] = 1,
	['led_green'] = 1,
	['led_blue'] = 1,
	-- Present information
	['current'] = 2,
	['load'] = 2,
	['voltage'] = 2,
}

-- Add a poor man's unix library
local unix2 = {}
unix2.write = function(fd,msg)
	local str = string.format('\n%s fd:(%d) sz:(%d)',type(msg),fd,#msg)
	local str2 = 'Dec:\t'
	local str3 = 'Hex:\t'
	for i=1,#msg do
		str2 = str2..string.format('%3d ', msg:byte(i))
		str3 = str3..string.format(' %.2X ', msg:byte(i))
	end
	io.write(str,'\n',str2,'\n',str3,'\n')
	return #msg
end
unix2.time = function()
	return os.clock()
end
unix2.read = function(fd)
	return nil
end
unix2.usleep = function(n_usec)
	--os.execute('sleep '..n_usec/1e6)
end
unix2.close = function( fd )
	io.write('Closed fd ',fd)
end
local unix = unix2

------------------------------------------------
------------------------------------------------
-- 1.0 stuff!!
function libDynamixel.set_ram1(fd,id,addr,value,sz)
	local inst = nil
	if type(id) == 'number' then
		if sz==1 then
			inst = DP1.write_byte(id, addr, value)
		elseif sz==2 then
			inst = DP1.write_word(id, addr, value)
		elseif sz==4 then
			inst = DP1.write_dword(id, addr, value)
		end
		local clear = unix.read(fd); -- clear old status packets
		local ret = unix.write(fd, inst)
		local statuses = libDynamixel.get_status1(fd,1);
		if not statuses then
			print('No status packet from the write')
			return nil
		end
		local err_msg  = DP1.strerr(statuses.error)
		if err_msg then
			return err_msg
		end
	elseif type(id)=='table' then
		-- Sync write
		if sz==1 then
			libDynamixel.sync_write_byte1(fd, id, addr, value)
		elseif sz==2 then
			libDynamixel.sync_write_word1(fd, id, addr, value)
		elseif sz==4 then
			error('NO SIR!')
			libDynamixel.sync_write_dword(fd, id, addr, value)
		end
	end
end

-- Get a single element
function libDynamixel.get_ram1(fd, id, addr, sz)
	local inst = nil
	local nids = 1
	if type(id) == 'number' then
		inst = DP1.read_data(id, addr, sz);
		local clear = unix.read(fd); -- clear old status packets
		local ret = unix.write(fd, inst)
		local status = libDynamixel.get_status1(fd,nids);
		if not status then
			return nil
		end
		if sz==1 then
			return status.parameter,DP1.strerr(status.error)
		elseif sz==2 then
			return DP1.byte_to_word(unpack(status.parameter,1,2)),DP1.strerr(status.error)
		elseif sz==4 then
			return DP1.byte_to_dword(unpack(status.parameter,1,4)),DP1.strerr(status.error)
		end
	elseif type(id)=='table' then -- does not exist!!!!!!
		error('NO SIR DOES DEOS EXIST IN 1.0!')
		inst = DP1.sync_read(string.char(unpack(id)), addr, sz)
		nids = #id
	else
		return nil
	end
	local clear = unix.read(fd); -- clear old status packets
	local ret = unix.write(fd, inst)
	local statuses = libDynamixel.get_status1(fd,nids);
	if not statuses then
		return nil
	end
	-- Make a return table
	local status_return = {}
	local error_return = {}
	for s,status in ipairs(statuses) do
		table.insert(error_return, DP1.strerr(status.error) )
		if sz==1 then
			table.insert(status_return,status.parameter[1])
		elseif sz==2 then
			table.insert(status_return,
			DP1.byte_to_word(unpack(status.parameter,1,2)) )
		elseif sz==4 then
			table.insert(status_return,
			DP1.byte_to_dword(unpack(status.parameter,1,4)) )
		end
	end
	return status_return, error_return
end
-- 1.0 stuff done!!
------------------------------------------------
------------------------------------------------

function libDynamixel.set_ram(fd,id,addr,value,sz)
	local inst = nil
	if type(id) == 'number' then
		if sz==1 then
			inst = DP2.write_byte(id, addr, value)
		elseif sz==2 then
			inst = DP2.write_word(id, addr, value)
		elseif sz==4 then
			inst = DP2.write_dword(id, addr, value)
		end
		local clear = unix.read(fd); -- clear old status packets
		local ret = unix.write(fd, inst)
		local statuses = libDynamixel.get_status(fd,1);
		local err_msg  = DP2.strerr(statuses[1].error)
		if err_msg then
			return err_msg
		end
	elseif type(id)=='table' then
		-- Sync write
		if sz==1 then
			libDynamixel.sync_write_byte(fd, id, addr, value)
		elseif sz==2 then
			libDynamixel.sync_write_word(fd, id, addr, value)
		elseif sz==4 then
			libDynamixel.sync_write_dword(fd, id, addr, value)
		end
	end
end

-- Get a single element
-- TODO: Grab neighboring RAM segments of different meaningful data
function libDynamixel.get_ram(fd, id, addr, sz)
	local inst = nil
	local nids = 1
	if type(id) == 'number' then
		inst = DP2.read_data(id, addr, sz);
		local clear = unix.read(fd); -- clear old status packets
		local ret = unix.write(fd, inst)
		local statuses = libDynamixel.get_status(fd,nids);
		if not statuses then
			return nil
		end
		local status = statuses[1]
		if sz==1 then
			return status.parameter,DP2.strerr(status.error)
		elseif sz==2 then
			return DP2.byte_to_word(unpack(status.parameter,1,2)),DP2.strerr(status.error)
		elseif sz==4 then
			return DP2.byte_to_dword(unpack(status.parameter,1,4)),DP2.strerr(status.error)
		end
	elseif type(id)=='table' then
		inst = DP2.sync_read(string.char(unpack(id)), addr, sz)
		nids = #id
	else
		return nil
	end
	local clear = unix.read(fd); -- clear old status packets
	local ret = unix.write(fd, inst)
	local statuses = libDynamixel.get_status(fd,nids);
	if not statuses then
		return nil
	end
	-- Make a return table
	local status_return = {}
	local error_return = {}
	for s,status in ipairs(statuses) do
		table.insert(error_return, DP2.strerr(status.error) )
		if sz==1 then
			table.insert(status_return,status.parameter[1])
		elseif sz==2 then
			table.insert(status_return,
			DP2.byte_to_word(unpack(status.parameter,1,2)) )
		elseif sz==4 then
			table.insert(status_return,
			DP2.byte_to_dword(unpack(status.parameter,1,4)) )
		end
	end
	return status_return, error_return
end

function init_device_handle(obj)
	-- MX Series Calls
	for key,addr in pairs(mx_ram_addr) do
		obj['set_mx_'..key] = function(self,id,val)
			return libDynamixel.set_ram(self.fd, id, addr, val, mx_ram_sz[key])
		end
		obj['get_mx_'..key] = function(self,id)
			return libDynamixel.get_ram(self.fd, id, addr, mx_ram_sz[key])
		end
	end
	-- NX Series Calls
	for key,addr in pairs(nx_ram_addr) do
		obj['set_nx_'..key] = function(self,id,val)
			return libDynamixel.set_ram(self.fd, id, addr, val, nx_ram_sz[key])
		end
		obj['get_nx_'..key] = function(self,id)
			return libDynamixel.get_ram(self.fd, id, addr, nx_ram_sz[key])
		end
	end
	-- RX Series Calls
	for key,addr in pairs(rx_ram_addr) do
		obj['set_rx_'..key] = function(self,id,val)
			return libDynamixel.set_ram1(self.fd, id, addr, val, rx_ram_sz[key])
		end
		obj['get_rx_'..key] = function(self,id)
			return libDynamixel.get_ram1(self.fd, id, addr, rx_ram_sz[key])
		end
	end
	return obj
end


function libDynamixel.parse_status_packet1(pkt)
   local t = {};
   t.id = pkt:byte(3);
   t.length = pkt:byte(4);
   t.error = pkt:byte(5);
   t.parameter = {pkt:byte(6,t.length+3)};
   t.checksum = pkt:byte(t.length+4);
   return t;
end

function libDynamixel.get_status1( fd, npkt, timeout )
	timeout = timeout or 0.010;
	local t0 = unix.time();
	local str = "";
	while (unix.time()-t0 < timeout) do
		local s = unix.read(fd);
		if (type(s) == "string") then
			str = str..s;
			pkt = DP1.input(str);
			if pkt then
				local status = libDynamixel.parse_status_packet1(pkt);
				--print(string.format("Status: id=%d error=%d",status.id,status.error));
				return status
			end
		end
		-- TODO: adjust the sleep time
		unix.usleep(100);
	end
	return nil;
end



-- TODO: Is the status packet the same in Dynamixel 2.0?
libDynamixel.parse_status_packet = function(pkt)
	local t = {}
	t.id = pkt:byte(5)
	t.length = pkt:byte(6)+2^8*pkt:byte(7)
	t.instruction = pkt:byte(8)
	t.error = pkt:byte(9)
	t.parameter = {pkt:byte(10,t.length+5)}
	t.checksum = string.char( pkt:byte(t.length+6), pkt:byte(t.length+7) );
	return t;
end

-- Old get status method
libDynamixel.get_status = function( fd, npkt, timeout )
	-- TODO: Is this the best default timeout for the new PRO series?
	timeout = timeout or 0.1;

timeout = .5

	local t0 = unix.time();
	local str = "";
	local pkt_cnt = 0;
	while unix.time()-t0 < timeout do
		local s = unix.read(fd);
		if type(s) == "string" then
			str = str..s;
			local pkt, done = DP2.input(str);
			if done and #pkt>=npkt then
				local statuses = {}
				for pp=1,#pkt do
					local status = libDynamixel.parse_status_packet(pkt[pp]);
					table.insert(statuses,status)
				end
				return statuses;
			end
		else
		end
		-- TODO: tune the sleep amount
		unix.usleep(100);
	end
	print('BAD STATUSES',#str,str)
	return nil;
end



libDynamixel.send_ping1 = function( self, id )
	local inst = DP1.ping(id);
	return unix.write(self.fd, inst);
end

libDynamixel.ping_probe1 = function(self, twait)
	twait = twait or 0.010;
	for id = 0,253 do
		libDynamixel.send_ping1( self, id );
		local status = libDynamixel.get_status1(self.fd,1,twait);
		if status then
			io.write('FOUND 1.0: ',status.id,'\n')
		end
	end
end

libDynamixel.send_ping = function( self, id )
	local inst = DP2.ping(id);
	return unix.write(self.fd, inst);
end

libDynamixel.ping_probe = function(self, twait)
	twait = twait or 0.010;
	for id = 0,253 do
		libDynamixel.send_ping( self, id );
		local statuses = libDynamixel.get_status(self.fd,1,twait);
		if statuses and #statuses==1 then
			io.write('FOUND 2.0: ',statuses[1].id,'\n')
		end
	end
end

libDynamixel.sync_read = function(fd, ids, addr, len, twait)
	twait = twait or 0.100;
	len  = len or 2;
	local inst = DP2.sync_read( addr, len,
	string.char(unpack(ids)) );
	unix.read(fd); -- clear old status packets
	unix.write(fd, inst)
	local status = libDynamixel.get_status(fd, #ids);
	if status then
		return status.parameter;
	end
end





function libDynamixel.sync_write_byte1(fd, ids, addr, data)
   local nid = #ids
   local len = 1
	 local all_data = nil
	 if type(data)=='number' then
		 -- All get the same value
		 all_data = data
	 end

   local t = {};
   local n = 1;
   for i = 1,nid do
      t[n] = ids[i];
      t[n+1] = all_data or data[i];
      n = n + len + 1;
   end
   local inst = DP1.sync_write(addr, len, string.char(unpack(t)))
   unix.write(fd, inst);
end

function libDynamixel.sync_write_word1(fd, ids, addr, data)
   local nid = #ids
   local len = 2
	 local all_data = nil
	 if type(data)=='number' then
		 -- All get the same value
		 all_data = data
	 end

   local t = {}
   local n = 1
   for i = 1,nid do
      t[n] = ids[i]
      t[n+1],t[n+2] = DP1.word_to_byte(all_data or data[i])
      n = n + len + 1
   end
   local inst = DP1.sync_write(addr, len, string.char(unpack(t)))
   unix.write(fd, inst);
end




-- TODO: Reorganize the sync_write commands
libDynamixel.sync_write_byte = function(fd, ids, addr, data)
	local nid = #ids;
	local len = 1;
	local all_data = nil
	if type(data)=='number' then
		-- All get the same value
		all_data = data
	end
	local t = {};
	local n = 1;
	for i = 1,nid do
		t[n] = ids[i];
		t[n+1] = all_data or data[i];
		n = n + len + 1;
	end
	local inst = DP2.sync_write(addr, len, string.char(unpack(t)));
	unix.write(fd, inst);
end

libDynamixel.sync_write_word = function(fd, ids, addr, data)
	local nid = #ids;
	local len = 2;
	local all_data = nil
	if type(data)=='number' then
		--print('data type is number!')
		-- All get the same value
		all_data = data
	end

	local t = {};
	local n = 1;
	for i = 1,nid do
		t[n] = ids[i];
		local val = all_data or data[i]
		t[n+1],t[n+2] = DP2.word_to_byte(val)
		--print("Sync word",t[n],val,t[n+1],t[n+2])
		n = n + len + 1;
	end
	local inst = DP2.sync_write(addr, len,
	string.char(unpack(t)));
	unix.write(fd, inst);
end

libDynamixel.sync_write_dword = function(fd, ids, addr, data)
	local nid = #ids;
	local len = 4;
	local all_data = nil
	if type(data)=='number' then
		-- All get the same value
		all_data = data
	end
	local t = {};
	local n = 1;
	for i = 1,nid do
		t[n] = ids[i];
		local val = all_data or data[i]
		t[n+1],t[n+2],t[n+3],t[n+4] = 
			DP2.dword_to_byte(val)
		n = n + len + 1;
	end
	local inst = DP2.sync_write(addr, len,
	string.char(unpack(t)));
	unix.write(fd, inst);
end

function libDynamixel.new_bus( ttyname, ttybaud )
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
		assert(fd > 2, string.format("Could not open port %s, (%d)", ttyname, fd) );
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
	-- Close out the device
	obj.close = function (self)
		if self.fd < 3 then
			return false
		end
		return unix.close( self.fd )==0
	end
	-- Reset the device
	obj.reset = function(self)
		self:close()
		unix.usleep( 1e5 )
		self.fd = libDynamixel.open( self.ttyname )
	end
	obj.ping = libDynamixel.send_ping
	obj.ping_probe = libDynamixel.ping_probe
	obj.ping1 = libDynamixel.send_ping1
	obj.ping_probe1 = libDynamixel.ping_probe1
	return obj;
end

return libDynamixel
