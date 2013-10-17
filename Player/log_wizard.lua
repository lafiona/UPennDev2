---------------------------------
-- Logging manager for Team THOR
-- (c) Qin He, 2013
---------------------------------

-- Set the path for the libraries
dofile'../include.lua'
local Config = require'Config'
local Body = require'Body'
require 'unix'

---------------------------------
-- Libraries
local simple_ipc = require'simple_ipc'
local carray = require'carray'
local mp = require'msgpack'
local jpeg = require'jpeg'
local zlib = require'zlib'
local util = require'util'
local vector = require'vector'
local libLaser = require'libLaser'
---------------------------------

-- TODO: use args to decide which data we want to log
---------------------------------
-- Set up listeners
local head_lidar_ch = simple_ipc.new_subscriber'head_lidar'
--local chest_lidar_ch = simple_ipc.new_subscriber'chest_lidar'
--
--local mesh_ch = simple_ipc.new_subscriber'mesh'
--
--local camera_ch = simple_ipc.new_subscriber'camera'

-- TODO: contact sensor
-- TODO: hcm inputs

---------------------------------
-- Shared Memory
require'jcm'
require'hcm'
---------------------------------

---------------------------------
-- Logging and Replaying set up
-- Flag for logging
local logfile = ''
filetime = os.date('%m.%d.%Y.%H.%M.%S')
logfile = io.open('logfiles/'..filetime..'.log','w')
---------------------------------

-- Input Channels
local channel_polls
local channel_timeout = 100 -- ms

-- Lidar objects
local hlidar -- head
local clidar -- chest

---------------------------------
-- Filter Parameters
-- TODO: the following should be put in vcm 
local l0minFOV = -135*Body.DEG_TO_RAD
local l0maxFOV =  135*Body.DEG_TO_RAD
local l1minFOV = -45*Body.DEG_TO_RAD 
local l1maxFOV =  45*Body.DEG_TO_RAD 
local l0minHeight = -0.6 -- meters
local l0maxHeight = 1.2
-- We don't need height limits for chest lidar
local minRange = 0.15 -- meters
local maxRange = 28
if IS_WEBOTS then
  maxRange = 9.5
end


---------------------------------
-- Callbacks for receiving lidar readings
local function head_callback()
  --print('HEAD CALLBACK')
  -- Grab the data  
  local meta, has_more = head_lidar_ch:receive()
  local metadata = mp.unpack(meta)
   	
  -- Get raw data from shared memory
  -- TODO: May try to put into the lidar message itself
  -- which is useful for a separate computer to perform slam
  local ranges = Body.get_head_lidar()
  --print('lidar sizes',#ranges,hlidar.ranges:size(1))
  -- Copy of ranges for use in libLaser
  ranges:tensor( hlidar.ranges )

  -- Take log
	-- torch is easier to be logged...
	metadata.name = 'headlidar'
	metadata.ranges = hlidar.ranges
	logfile:write( mp.pack(metadata) )
 
end



------------------------------------------------------
-- Chest lidar callback
------------------------------------------------------
local function chest_callback()

  -- Grab the data
  local meta, has_more = chest_lidar_ch:receive()
  local metadata = mp.unpack(meta)

	-- Get raw data from shared memory
	local ranges = Body.get_chest_lidar()
	--print('Lidar1 range size:', clidar.ranges:size(1))
	-- Copy of ranges for use in libLaser
	ranges:tensor( clidar.ranges )
  
  -- Take log
	-- torch is easier to be logged...
	metadata.name = 'chestlidar'
	metadata.ranges = clidar.ranges
	logfile:write( mp.pack(metadata) )
  
end

------------------------------------------------------
-- Mesh callback
------------------------------------------------------
local function mesh_callback()
	--print('logging mesh!!')
	-- Grab the data
	local meta, has_more = mesh_ch:receive()

  -- Write log file
  logfile:write( meta )
end

------------------------------------------------------
-- Camera callback
------------------------------------------------------
local function camera_callback()
	-- Grab the data
	local meta, has_more = camera_ch:receive()

  -- Write log file
  logfile:write( meta )
end

------------------------------------------------------
-- Logger for imu
------------------------------------------------------
local function imu_logger()
	-- Grab the data
	local imu = {}
	imu.name = 'imu'
  imu.t = Body.get_time()
  -- TODO: use shm instead of body?
  imu.rpy = Body.get_sensor_rpy()
  imu.gyro = Body.get_sensor_gyro()

  -- Write log file
  logfile:write( mp.pack(imu) )
end

------------------------------------------------------
-- Logger for sensed joint position and velocity
------------------------------------------------------
local function joint_sensor_logger()
	-- Grab the data
	local joint = {}
	joint.name = 'sensor'
  joint.t = Body.get_time()
  joint.pos = jcm.get_sensor_position()
  joint.vel = jcm.get_sensor_velocity()

  -- Write log file
  logfile:write( mp.pack(joint) )
end

------------------------------------------------------
-- Logger for commanded joint position and velocity
------------------------------------------------------
local function joint_actuator_logger()
	-- Grab the data
	local joint = {}
	joint.name = 'actuator'
  joint.t = Body.get_time()
  joint.pos = jcm.get_actuator_command_position()
  joint.vel = jcm.get_actuator_command_velocity()

  -- Write log file
  logfile:write( mp.pack(joint) )
end


local log = {}

function log.entry()

  -- Poll lidar readings
  local wait_channels = {}
  if head_lidar_ch then
    head_lidar_ch.callback = head_callback
    table.insert( wait_channels, head_lidar_ch )
    hlidar = libLaser.new_lidar(
      'head', 
      minRange, maxRange, 
      l0minHeight, l0maxHeight, 
      l0minFOV, l0maxFOV )
  end
  if chest_lidar_ch then
    chest_lidar_ch.callback = chest_callback
    table.insert( wait_channels, chest_lidar_ch )
    clidar = libLaser.new_lidar(
      'chest', 
      minRange, maxRange, 
      l1minHeight, l1maxHeight, 
      l1minFOV, l1maxFOV )
  end

  if mesh_ch then
    mesh_ch.callback = mesh_callback
    table.insert( wait_channels, mesh_ch )
  end

  if camera_ch then
    camera_ch.callback = camera_callback
    table.insert( wait_channels, camera_ch )
  end
  
  --Set up the channels
  channel_polls = simple_ipc.wait_on_channels( wait_channels )
end

function log.update()
  
  ------------------
  -- Perform the poll
  local npoll = channel_polls:poll(channel_timeout)
  ------------------

  imu_logger()
  joint_sensor_logger()
  joint_actuator_logger()
  --hcm_logger()
end

function log.exit()
	logfile:close()
end

-- Main loop
log.entry()
while true do log.update() end
log.exit()

logfile:close()
return log
