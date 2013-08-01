-- THOR OP Body
print('webots?',_G['IS_WEBOTS'])
-- Dynamixel definitions
local libDynamixel = require'libDynamixel'

-- Shared memory for the joints
require'jcm'

-- Utilities
require'unix'
require'vector'
local function mod_angle(a)
	-- Reduce angle to [-pi, pi)
	local b = a % (2*math.pi)
	if b >= math.pi then return (b - 2*math.pi) end
	return b
end

local DEG_TO_RAD = math.pi/180
local RAD_TO_DEG = 180/math.pi

local Body = {}

--------------------------------
-- Shared memory layout

-- Real THOR-OP (Cenatur uses ankles for wheels, maybe?)
local indexHead = 1   -- Head: 1 2
local nJointHead = 2
local indexLArm = 3   --LArm: 3 4 5 6 7 8
local nJointLArm = 6 		
local indexLLeg = 9  --LLeg: 9 10 11 12 13 14
local nJointLLeg = 6
local indexRLeg = 15  --RLeg: 15 16 17 18 19 20
local nJointRLeg = 6
local indexRArm = 21  --RArm: 21 22 23 24 25 26
local nJointRArm = 6
local indexWaist = 27  --Waist: 27 28
local nJointWaist = 2
-- Auxiliary servos
-- 6 Fingers for gripping
-- 1 servo for lidar panning
local indexLGrip = 29
local nJointLGrip = 3
local indexRGrip = 32
local nJointRGrip = 3
local indexAux = 35
local nJointAux = 1
local nJoint = 35

assert(nJoint==(indexAux+nJointAux)-indexHead,'Bad joint counting!')

local jointNames = {
	"Neck","Head", -- Head
	-- Left Arm
	"ShoulderL", "ArmUpperL", "LeftShoulderYaw",
	"ArmLowerL","LeftWristYaw","LeftWristRoll",
	-- Left leg
	"PelvYL","PelvL","LegUpperL","LegLowerL","AnkleL","FootL",
	-- Right leg
	"PelvYR","PelvR","LegUpperR","LegLowerR","AnkleR","FootR",
	--Right arm
	"ShoulderR", "ArmUpperR", "RightShoulderYaw","ArmLowerR",
	"RightWristYaw","RightWristRoll",
	-- Waist
	"TorsoPitch","TorsoYaw",
	-- Gripper
	"l_wrist_grip1","l_wrist_grip2","l_wrist_grip3",
	"r_wrist_grip1","r_wrist_grip2","r_wrist_grip3",
	-- lidar movement
	"ChestLidar",
}
assert(nJoint==#jointNames,'bad jointNames!')
local parts = {
	['Head']=vector.count(indexHead,nJointHead),
	['LArm']=vector.count(indexLArm,nJointLArm),
	['LLeg']=vector.count(indexLLeg,nJointLLeg),
	['RLeg']=vector.count(indexRLeg,nJointRLeg),
	['RArm']=vector.count(indexRArm,nJointRArm),
	['Waist']=vector.count(indexWaist,nJointWaist),
	['LGrip']=vector.count(indexLGrip,nJointLGrip),
  ['RGrip']=vector.count(indexRGrip,nJointRGrip),
  ['Aux']=vector.count(indexAux,nJointAux)
}
local inv_parts = {}
for name,list in pairs(parts) do
	for _,idx in ipairs(list) do inv_parts[idx] = name end
end

--------------------------------
-- Servo parameters
local servo = {}

-- shm joint id to dynamixel motor id
servo.joint_to_motor={
	27,28,  --Head
	1,3,5,7,9,11, --LArm
	-- TODO: No legs!  Using fake id numbers for now
	20,51,52,53,54,55, -- left wheel
	19,61,62,63,64,65, -- right wheel
	2,4,6,8,10,12,  --RArm
	25,26,  -- Waist
	14,16,18, -- left gripper
	13,15,17, -- right gripper
	36, -- Lidar pan
}
assert(#servo.joint_to_motor==nJoint,'Bad servo id map!')

local motor_parts = {}
for name,list in pairs(parts) do
	motor_parts[name] = vector.zeros(#list)
	for i,idx in ipairs(list) do
		motor_parts[name][i] = servo.joint_to_motor[idx]
	end
end

-- Make the reverse map
servo.motor_to_joint={}
for j,m in ipairs(servo.joint_to_motor) do
	servo.motor_to_joint[m] = j
end

--http://support.robotis.com/en/product/dynamixel_pro/control_table.htm#Actuator_Address_611
-- TODO: Use some loop based upon MX/NX
-- TODO: some pros are different
servo.steps = 2 * vector.new({
	151875,151875, -- Head
	251000,251000,251000,251000,151875,151875, --LArm
	251000,251000,251000,251000,251000,251000, --LLeg
	251000,251000,251000,251000,251000,251000, --RLeg
	251000,251000,251000,251000,151875,151875, --RArm
	251000,251000, -- Waist
	2048,2048,2048, -- Left gripper
	2048,2048,2048, -- Right gripper
	2048, -- Lidar pan
})
assert(#servo.steps==nJoint,'Bad servo steps!')

-- NOTE: Servo direction is webots/real robot specific
servo.direction = vector.new({
	1,1, -- Head
  1,1,1,-1,1,1, --LArm
	-- TODO: No legs yet! Using fake directions for now
	1, 1,1,1,1,1, --LLeg
	1, 1,1,1,1,1, --RLeg
	-1,1,1,1, 1,1, --RArm
	1,1, -- Waist
	-- TODO: Check the gripper
	1,-1,1, -- left gripper
	1,-1,1, -- right gripper
	1, -- Lidar pan
})
assert(#servo.direction==nJoint,'Bad servo direction!')

-- TODO: Offset in addition to bias?
servo.rad_bias = vector.new({
	0,0, -- Head
	-90,-90,-90,-45,90,0, --LArm
	0,0,0,0,0,0, --LLeg
	0,0,0,0,0,0, --RLeg
	90,90,90,45,-90,0, --RArm
	0,0, -- Waist
	0,0,0, -- left gripper
	0,-80,0, -- right gripper -- TODO: Remount the finger...
	0, -- Lidar pan
})*DEG_TO_RAD
assert(#servo.rad_bias==nJoint,'Bad servo rad_bias!')

servo.min_rad = vector.new({
	-60,-80, -- Head
	-90,-5,-90,-140,-100,-80, --LArm
	-175,-175,-175,-175,-175,-175, --LLeg
	-175,-175,-175,-175,-175,-175, --RLeg
	-175,-150,-180,-140,-100,-80, --RArm
	-175,-175, -- Waist
	-20,-20,-20, -- left gripper
	-10,-10,-10, -- right gripper
	-45, -- Lidar pan
})*DEG_TO_RAD
assert(#servo.min_rad==nJoint,'Bad servo min_rad!')

servo.max_rad = vector.new({
	60,80, -- Head
	160,150,180,0,100,80, --LArm
	175,175,175,175,175,175, --LLeg
	175,175,175,175,175,175, --RLeg
	160,5,90,0,100,80, --RArm
	175,175, -- Waist
	10,10,10, -- left gripper
	20,25,25, -- right gripper
	45, -- Lidar pan
})*DEG_TO_RAD
assert(#servo.max_rad==nJoint,'Bad servo max_rad!')

-- Convienence tables to go between steps and radians
servo.moveRange = 360 * DEG_TO_RAD * vector.ones(nJoint)
-- Step<-->Radian ratios
servo.to_radians = vector.zeros(nJoint)
servo.to_steps = vector.zeros(nJoint)
for i,nsteps in ipairs(servo.steps) do
  servo.to_steps[i] = nsteps / servo.moveRange[i]
  servo.to_radians[i] = servo.moveRange[i] / nsteps
end
-- Set the step zero
-- NOTE: rad zero is always zero
servo.step_zero = vector.new(servo.steps) / 2
for i,nsteps in ipairs(servo.steps) do
  -- MX is halfway, while NX is 0 and goes positive/negative
  if nsteps~=4096 then servo.step_zero[i] = 0 end
end

-- TODO: How is direction used?
-- Add the bias in to the min/max helper tables
servo.step_bias = vector.zeros(nJoint)
servo.min_step  = vector.zeros(nJoint)
servo.max_step  = vector.zeros(nJoint)
for i, bias in ipairs(servo.rad_bias) do
  servo.step_bias[i] = bias * servo.to_steps[i]
end

-- Clamp the radian within the min and max
-- Used when sending packets and working with actuator commands
local radian_clamp = function( idx, radian )
  return math.min(math.max(radian, servo.min_rad[idx]), servo.max_rad[idx])
end

-- Radian to step, using offsets and biases
local make_joint_step = function( idx, radian )
  radian = radian_clamp( idx, radian )
	local step = math.floor(servo.direction[idx] * radian * servo.to_steps[idx]
	+ servo.step_zero[idx] + servo.step_bias[idx])
	return step
end

-- Step to radian
local make_joint_radian = function( idx, step )
	local radian = servo.direction[idx] * servo.to_radians[idx] * 
	(step - servo.step_zero[idx] - servo.step_bias[idx])
	return radian
end

--------------------------------
-- Legacy API
Body.set_syncread_enable = function()
end

----------------------
-- Body sensor commands
-- jcm should be the API compliance test
for sensor, pointer in pairs(jcm.sensorPtr) do
	Body['set_sensor_'..sensor] = function(val,idx)
    if type(val)=='number' then
      if type(idx)=='number' then
        pointer[idx] = val
      else
        for _,i in ipairs(idx) do pointer[i] = val end
      end
    else
      if not idx then
        for i,v in ipairs(val) do pointer[i] = v end
      elseif type(idx)=='number' then
        for i,v in ipairs(val) do pointer[idx+i-1] = v end
      else
        -- ji: joint index. vi: value index
        for vi,ji in ipairs(idx) do pointer[ji] = val[vi] end
      end
    end
	end
	Body['get_sensor_'..sensor] = function(idx,idx2)
		if idx then
      -- Return the values from idx to idx2
      if idx2 then return pointer:table(idx,idx2) end 
      return pointer[idx]
    end
    -- If no idx is supplied, then return the values of all joints
    -- TODO: return as a table or carray?
		return pointer:table()
	end
  --------------------------------
  -- Antropomorphic access to jcm
  -- TODO: Do not use string concatenation to call the get/set methods of Body
  for part,jlist in pairs( parts ) do
  	local a = jlist[1]
  	local b = jlist[#jlist]
  	Body['get_'..part:lower()..'_'..sensor] = function(idx)
  		if idx then return Body['get_sensor_'..sensor](jlist[idx]) end
  		return Body['get_sensor_'..sensor](a,b)
  	end -- Get
  	Body['set_'..part:lower()..'_'..sensor] = function(val,idx)
  		if idx then return Body['set_sensor_'..sensor](val,jlist[idx]) end
      -- Ensure that the parameters are proper
      assert(type(val)=='number' or #val==b-a+1 )
  		return Body['set_sensor_'..sensor](val,a,b)
  	end -- Set
  end -- anthropomorphic
  --------------------------------
end


----------------------
-- Body actuator commands
-- jcm should be the API compliance test
for actuator, pointer in pairs(jcm.actuatorPtr) do
	Body['set_actuator_'..actuator] = function(val,idx)
    if type(val)=='number' then
      if type(idx)=='number' then
        pointer[idx] = val
      else
        for _,i in ipairs(idx) do pointer[i] = val end
      end
    else
      if not idx then
        for i,v in ipairs(val) do pointer[i] = v end
      elseif type(idx)=='number' then
        for i,v in ipairs(val) do pointer[idx+i-1] = v end
      else
        -- ji: joint index. vi: value index
        for vi,ji in ipairs(idx) do pointer[ji] = val[vi] end
      end
    end
	end
	Body['get_actuator_'..actuator] = function(idx,idx2)
		if idx then
      -- Return the values from idx to idx2
      if idx2 then return pointer:table(idx,idx2) end 
      return pointer[idx]
    end
    -- If no idx is supplied, then return the values of all joints
    -- TODO: return as a table or carray?
		return pointer:table()
	end
  --------------------------------
  -- Antropomorphic access to jcm
  -- TODO: Do not use string concatenation to call the get/set methods of Body
  for part,jlist in pairs( parts ) do
  	local a = jlist[1]
  	local b = jlist[#jlist]
  	Body['get_'..part:lower()..'_'..actuator] = function(idx)
  		if idx then return Body['get_actuator_'..actuator](jlist[idx]) end
  		return Body['get_actuator_'..actuator](a,b)
  	end -- Get
  	Body['set_'..part:lower()..'_'..actuator] = function(val,idx)
  		if idx then
        -- idx is only allowed to be a number
        assert(type(idx)=='number','body limb idx must be a number!')
        val = radian_clamp(idx,val)
        return Body['set_actuator_'..actuator](val,jlist[idx])
      end
      -- With no idx, val is number or table
      -- Make sure to clamp this value
      -- If val is a number to set all limb joints
      if type(val)=='number' then
        local values = {}
        for i,idx in ipairs(jlist) do values[i] = radian_clamp(idx,val) end
        return Body['set_actuator_'..actuator](values,a,b)
      end
      -- If val is a set of values for each limb joints
      assert(#val==b-a+1,'Must set the exact number of limb joints!')
      for i,idx in ipairs(jlist) do
        val[i] = radian_clamp(idx,val[i])
      end
  		return Body['set_actuator_'..actuator](val,a,b)
  	end -- Set
  end -- anthropomorphic
  --------------------------------
end

--------------------------------
-- Packet generators
-- NX packet generators
-- TODO: Use anthropomorphic get/set functions
for k,v in pairs(libDynamixel.nx_registers) do
  local get_func = libDynamixel['get_nx_'..k]
  local set_func = libDynamixel['set_nx_'..k]
  
  for part,jlist in pairs(parts) do
    --print(part,'nx jlist',jlist)
    local mlist = motor_parts[part]
    --local jlist = parts[part]
    local a = jlist[1]
    local b = jlist[#jlist]
    Body['get_'..part:lower()..'_'..k..'_packet'] = function()
      return get_func(mlist)
    end
    Body['set_'..part:lower()..'_'..k..'_packet'] = function()
      local vals = jcm.actuatorPtr[k]:table( a, b )
      return set_func( mlist, vals )
    end
    -- Add protection for command_position
    if k=='command_position' then
      --print'overwriting command'
      Body['set_'..part:lower()..'_'..k..'_packet'] = function()
        -- Shm has radians
        local vals = jcm.actuatorPtr.command_position:table( a, b )
        -- Convert to steps
        for i,idx in ipairs(jlist) do vals[i]=make_joint_step(idx,vals[i]) end
        return set_func( mlist, vals )
      end
    end
  end--jlist
end
  
-- Gripper and lidar actuator are MX
-- TODO: make general somehow
for k,v in pairs(libDynamixel.mx_registers) do
	local get_func = libDynamixel['get_mx_'..k]
	local set_func = libDynamixel['set_mx_'..k]
  
  for _,part in pairs({'LGrip','RGrip','Aux'}) do
    local mlist = motor_parts[part]
    local jlist = parts[part]
    local a = jlist[1]
    local b = jlist[#jlist]
    
    -- Getter setters
    Body['get_'..part:lower()..'_'..k..'_packet'] = function()
      return get_func(mlist)
    end
    Body['set_'..part:lower()..'_'..k..'_packet'] = function()
      local vals = jcm.actuatorPtr[k]:table( a, b )
      return set_func( mlist, vals )
    end

    -- Add protection for command_position
  	if k=='command_position' then
  		--print'overwriting command'
  		Body['set_'..part:lower()..'_'..k..'_packet'] = function()
  			-- Shm has radians
  			local vals = jcm.actuatorPtr.command_position:table( a, b )
  			-- Convert to steps
  			for i,idx in ipairs(jlist) do vals[i]=make_joint_step(idx,vals[i]) end
  			return set_func( mlist, vals )
  		end
  	end
  
  end
end

-- TODO: should be in body or a Grip module?
-- Grip module may have more advanced techniques...
-- More gripper functions
-- TODO: Use body actuator access to JCM
Body.set_lgrip_percent = function( percent )
	percent = math.min(math.max(percent,0),1)
	-- Convex combo
	for idx=indexLGrip,indexLGrip+nLGrip-1 do
		local radian = percent*servo.min_rad[idx] + (1-percent)*servo.max_rad[idx]
		jcm.actuatorPtr.command_position[idx] = radian
	end
end
Body.set_rgrip_percent = function( percent )
	percent = math.min(math.max(percent,0),1)
	-- Convex combo
	for idx=indexRGrip,indexRGrip+nRGrip-1 do
		local radian = percent * servo.min_rad[idx] + (1-percent)*servo.max_rad[idx]
		jcm.actuatorPtr.command_position[idx] = radian
	end
end

----------------------
-- Inverse Kinematics
local Kinematics = require'THOROPKinematics'

-- Check the error from a desired transform tr
-- to a forwards kinematics of in IK solution q
-- Tolerate a 1mm error in distance
local IK_TOLERANCE = 0.001
local function check_ik_error( q, tr )
	-- Transform from q (joint angles)
	local tr_q = Kinematics.r_arm_torso( q, tr )

	local position_error = math.sqrt(
	( tr_q[1]-tr[1] )^2 +
	( tr_q[2]-tr[2] )^2 +
	( tr_q[3]-tr[3] )^2 )

	local angle_error = math.sqrt(
	mod_angle( trRArm_target[4]-tr[4] )^2 +
	mod_angle( trRArm_target[5]-tr[5] )^2 +
	mod_angle( trRArm_target[6]-tr[6] )^2 )

	-- If within tolerance, return true
	if dist_pos<IK_TOLERANCE then return true end

	-- By default, return false, that we are out of tolerance
	return false

end

-- Take in a transform and output joint angles
Body.get_inverse_larm = function( tr )
	local qLArm = Body.get_larm_position()
	local qLArm_target = Kinematics.inverse_l_arm(tr, qLArm)
	--if not check_ik_error( qLArm_target, tr ) then return nil end
  return qLArm_target
end
Body.get_inverse_rarm = function( tr )
	local qRArm = Body.get_rarm_position()
	local qRArm_target = Kinematics.inverse_r_arm(tr, qRArm)
	--if not check_ik_error( qRArm_target, tr ) then return nil end
  return qRArm_target
end

-- Take in joint angles and output an {x,y,z,r,p,yaw} table
Body.get_forward_larm = function()
	local qLArm = Body.get_larm_position()
	local pLArm = Kinematics.l_arm_torso( qLArm )
  return pLArm
end
Body.get_forward_rarm = function()
	local qRArm = Body.get_rarm_position()
	local pRArm = Kinematics.r_arm_torso( qRArm )
  return pRArm
end

-- TODO: Write functions to modify transform in directions

----------------------
-- More standard api functions
Body.get_time = unix.time
Body.entry = function()
  -- Zero all joint requests
  for i=1,nJoint do Body.set_actuator_command(0,i) end
  for i=1,nJoint do Body.set_sensor_position(0,i) end
  for i=1,nJoint do Body.set_sensor_load(0,i) end
  for i=1,nJoint do Body.set_actuator_torque_enable(0,i) end
end
Body.update = function()
end
Body.exit = function()
end

----------------------
-- Webots compatibility
if IS_WEBOTS then
	local webots = require'webots'
	Body.get_time = webots.wb_robot_get_time

	servo.direction = vector.new({
		1,-1, -- Head
		1,-1,-1,1,-1,1, --LArm
		-- TODO: No legs yet!
		-1,-1,-1,-1,1,1, --LLeg
		-1,-1,1,1,-1,1, --LArm
		-1,-1,-1,-1,-1,1, --RArm
		-- TODO: Check the gripper
		1,1, -- Waist
		1,1,1, -- left gripper
		1,1,1, -- right gripper
		1, -- Lidar pan
	})
	servo.rad_bias = vector.new({
		0,0, -- head
		-90,-10,0,45,0,0,
		0,0,0,0,0,0,
		0,0,0,0,0,0,
		-90,10,0,45,0,0,
		0,0,
		0,0,0,
		0,0,0,
		0,
	})*math.pi/180


	-- Setup the webots tags
	local tags = {}

	Body.entry = function()
    
    -- Zero all joint requests
    for i=1,nJoint do Body.set_actuator_command_position(0,i) end
    for i=1,nJoint do Body.set_sensor_position(0,i) end

		-- Initialize the webots system
		webots.wb_robot_init()

		-- Grab the update time
		local timeStep = webots.wb_robot_get_basic_time_step()

		-- Grab the tags from the joint names
		tags.joints = {}
		for i,v in ipairs(jointNames) do
			tags.joints[i] = webots.wb_robot_get_device(v)
			if tags.joints[i]>0 then
				webots.wb_servo_enable_position(tags.joints[i], timeStep)
			else
				print(v,'not found')
			end
		end
		-- Add Sensor Tags
		-- Accelerometer
		tags.accelerometer = webots.wb_robot_get_device("Accelerometer")
		webots.wb_accelerometer_enable(tags.accelerometer, timeStep)
		-- Gyro
		tags.gyro = webots.wb_robot_get_device("Gyro")
		webots.wb_gyro_enable(tags.gyro, timeStep)
		-- TODO: Gps, compass, kinect
		--[[
		tags.gps = webots.wb_robot_get_device("zero")
		webots.wb_gps_enable(tags.gps, timeStep)
		-- Compass
		tags.compass = webots.wb_robot_get_device("compass")
		webots.wb_compass_enable(tags.compass, timeStep)
		-- Kinect
		tags.kinect = webots.wb_robot_get_device("kinect")
		webots.wb_camera_enable(tags.kinect, timeStep)
		--]]

		-- Take a step to get some values
		webots.wb_robot_step(timeStep)
		Body.timeStep = timeStep
		-- Filter the IMU a bit?
		-- TODO: Should use Yida's IMU filter
		--imuAngle = {0, 0, 0}
		--aImuFilter = 1 - math.exp(-tDelta/0.5)

	end
	Body.update = function()

		local tDelta = .001 * Body.timeStep
		-- Set actuator commands from shared memory
		for i, jtag in ipairs(tags.joints) do
			local cmd = Body.get_actuator_command_position(i)
			local pos = Body.get_sensor_position(i)
			-- TODO: What is velocity?
			local vel = 0 or Body.get_actuator_command_velocity(i)
			local en = 1 or Body.get_actuator_torque_enable(i)
			local deltaMax = tDelta * vel
			-- Only update the joint if the motor is torqued on

			-- If the joint is moving
			-- Clamp the difference between commanded and actuated
			-- so that we don't have huge jumped
			-- NOTE: This *should* be handled by the simulator?
			local new_pos = cmd
			if vel > 0 then
				local delta = cmd - pos
				if delta > deltaMax then
					delta = deltaMax
				elseif delta < -deltaMax then
					delta = -deltaMax
				end
				new_pos = pos + delta
			end

			-- Only set in webots if Torque Enabled
			if en > 0 and jtag>0 then
        webots.wb_servo_set_position(jtag, servo.direction[i] * (new_pos + servo.rad_bias[i]) )
      end
		end



		-- Step the simulation, and shutdown if the update fails
		if webots.wb_robot_step(Body.timeStep) < 0 then os.exit() end

		-- Update the sensor readings
		-- TODO: Verify the compass
		--[[
		local compass = webots.wb_compass_get_values(tags.compass)
		-- Swap webots coordinates into our coordinates
		Body.set_sensor_compass( {compass[1],-compass[2],compass[3]} )
		--]]

		-- Accelerometer data (verified)
		local accel = webots.wb_accelerometer_get_values(tags.accelerometer)
		Body.set_sensor_accelerometer( 
		{(accel[1]-512)/128,(accel[2]-512)/128,-(accel[3]-512)/128}
		)
		-- Gyro data (verified)
		local gyro = webots.wb_gyro_get_values(tags.gyro)
		Body.set_sensor_gyro( 
		{(gyro[1]-512)/0.273, (gyro[2]-512)/0.273,(gyro[3]-512)/0.273}
		)

		-- Update the sensor readings of the joint positions
		-- TODO: If a joint is not found?
		for idx, jtag in ipairs(tags.joints) do
			if jtag>0 then
				local val = webots.wb_servo_get_position( jtag )
				local rad = servo.direction[idx] * val - servo.rad_bias[idx]
				Body.set_sensor_position( rad, idx )
			end
		end

	end

	Body.exit = function()
	end

	Body.tags = tags

end -- webots check

-- Exports for use in other functions

-- Real THOR-OP (Cenatur uses ankles for wheels, maybe?)
Body.indexHead = 1   -- Head: 1 2
Body.nJointHead = 2
Body.indexLArm = 3   --LArm: 5 6 7 8 9 10
Body.nJointLArm = 6 		
Body.indexLLeg = 9  --LLeg: 11 12 13 14 15 16
Body.nJointLLeg = 6
Body.indexRLeg = 15  --RLeg: 17 18 19 20 21 22
Body.nJointRLeg = 6
Body.indexRArm = 21  --RArm: 23 24 25 26 27 28
Body.nJointRArm = 6
Body.indexWaist = 27  --Waist: 3 4
Body.nJointWaist = 2
-- Auxiliary servos
-- 6 Fingers for gripping
-- 1 servo for lidar panning
Body.indexAux = 29
Body.nJointAux = 7
Body.indexLGrip = 29
Body.nLGrip = 3
Body.indexRGrip = 32
Body.nRGrip = 3

Body.nJoint = nJoint
Body.jointNames = jointNames
Body.parts = parts
Body.inv_parts = inv_parts
Body.motor_parts = motor_parts
Body.servo = servo
Body.make_joint_step = make_joint_step
Body.make_joint_radian = make_joint_radian

return Body
