-- DCM is a thread or standalone
local CTX, metadata = ...
-- Still need our library paths set
dofile'include.lua'
assert(ffi, 'Please use LuaJIT :). Lua support in the near future')
-- Going to be threading this
local si = require'simple_ipc'
-- Import the context
local parent_ch, IS_THREAD
if type(CTX)=='userdata' then
	IS_THREAD = true
	si.import_context(CTX)
	-- Communicate with the master body_wizard
	parent_ch = si.new_pair(metadata.ch_name)
else
	-- Set metadata based on command line arguments
	local chain_id, chain = tonumber(arg[1])
	if chain_id then
		metadata = Config.chain[chain_id]
		-- Make reverse subscriber for the chain
		parent_ch = si.new_subscriber('dcm'..chain_id..'!')
	else
		-- Make reverse subscriber for the anonymous chain
		parent_ch = si.new_subscriber('dcm!')
	end
end
-- Fallback on undefined metadata
metadata = metadata or {}
-- Debug
if metadata.name then print('Running', metadata.name) end
-- Modules
require'jcm'
local lD = require'libDynamixel'
local Body = require'THOROPBodyUpdate'
local util = require'util'
local usleep, get_time = unix.usleep, unix.time
-- Corresponding Motor ids
local bus = lD.new_bus(metadata.device)
local m_ids = metadata.m_ids
if not m_ids then
	m_ids = bus:ping_probe()
	print(#m_ids, 'FOUND', unpack(m_ids))
end
local n_motors = #m_ids
-- Verify that the m_ids are present
for _,m_id in pairs(m_ids) do
	print('PING', m_id)
	local p = bus:ping(m_id)
	assert(p[1], string.format('ID %d not present.', m_id))
	--util.ptable(p[1])
	usleep(1e3)
end
-- Have the correct conversions
local m_to_j, step_to_radian, joint_to_step =
	Body.servo.motor_to_joint, Body.make_joint_radian, Body.make_joint_step
-- Make the reverse mapping
-- TODO: What used for?
local j_ids = {}
for i,m_id in ipairs(m_ids) do j_ids[i] = m_to_j[m_id] end
-- Access the typical commands quickly
local cp_ptr = jcm.writePtr.command_position
local cp_cmd = lD.set_nx_command_position
local cp_vals = {}
local p_ptr = jcm.writePtr.command_position
local p_read = lD.get_nx_position
local p_parse = lD.byte_to_number[lD.nx_registers.position[2]]
-- Define reading
local function do_read (is_strict)
	local status = p_read(m_ids, bus)
	if is_strict and #status~=n_motors then return end
	for _,s in ipairs(status) do
		local p = p_parse(unpack(s.parameter))
		local j_id = m_to_j[s.id]
		local r = step_to_radian(j_id, p)
		p_ptr[j_id-1] = r
	end
	return true
end
-- Define parent interaction. NOTE: Openly subscribing to ANYONE. fiddle even
local function process_parent (msg)

end
-- Initially, copy the command positions from the read positions
-- Try 5 times to get all joints at once
local did_read_all
for i=1,5 do
	did_read_all = do_read(true)
	if did_read_all then
		-- FFI is 0 indexed
		for _,j_id in ipairs(j_ids) do cp_ptr[j_id-1] = p_ptr[j_id-1] end
	end
end
assert(did_read_all, 'Did not initialize the motors properly!')
did_read_all = nil
-- Collect garbage before starting
collectgarbage()
-- Begin infinite loop
local t0 = get_time()
while true do
	local t = get_time()
	local t_diff = t-t0
	t0 = t
	print('t_diff', t_diff, 1 / t_diff)
	--------------------
	-- Read Positions --
	--------------------
	do_read()
	---------------------
	-- Write Positions --
	---------------------
	--[[
	for i,j_id in ipairs(j_ids) do
		local v
		if ffi then v=cp_ptr[j_id-1] else v=cp_ptr[j_id] end
		cp_vals[i] = joint_to_step(j_id,v)
	end
	local ret = cp_cmd(m_ids,cp_vals,bus)
	--]]
	---------------------
	-- Parent Commands --
	---------------------
	local parent_msg = parent_ch:receive(true)
	if parent_msg then
		if parent_msg=='exit' then
			bus:close()
			if IS_THREAD then parent_msg:send'exit' end
			return
		else
			process_parent(parent_msg)
		end
	end
end
