#!/usr/local/bin/luajit
dofile'../../include.lua'
local vector = require'vector'
local K = require'THOROPKinematics'
local T = require'Transform'
local K2 = require'K_ffi'
local torch = require'torch'
local util = require'util'
local ok, ffi = pcall(require, 'ffi')

print()
print('================')
print()

print'Kinematics Functions and variables'
for k,v in pairs(K) do print(k,v) end

print()
print('================')
print()

-- Test forward left
-- 6 DOF arm, with angles given in qLArm
local qLArm = vector.new({0,0,0, 0, 0,0,0})*DEG_TO_RAD
local qRArm = vector.new({0,0,0, 0, 0,0,0})*DEG_TO_RAD
local qWaist = vector.new({0, 0})*DEG_TO_RAD

-- Correctness
fL = vector.new(K.l_arm_torso_7(qLArm, 0, qWaist, 0.125, 0,0))
fkL2 = K2.forward_larm(qLArm, qWaist)
fL2 = vector.new(T.position6D(fkL2))
print('Forward Left')
print(fL)
print(fL2)

fR = vector.new(K.r_arm_torso_7(qRArm, 0, qWaist, 0.125, 0,0))
fR2 = vector.new(T.position6D(K2.forward_rarm(qRArm, qWaist)))
print('Forward Right')
print(fR)
print(fR2)

local qs = {}
for i=1,1e3 do
		qs[i] = vector.new({90*math.random(),-90*math.random(),90*math.random(), -90*math.random(), 0,90*math.random(),0})*DEG_TO_RAD
end

local fkLs, fkRs = {}, {}
dt_all = vector.zeros(2)
for i, q in ipairs(qs) do
	t0 = unix.time()
	fL = vector.new(K.l_arm_torso_7(q, 0, qWaist, 0.125,0,0))
	fR = vector.new(K.r_arm_torso_7(q, 0, qWaist, 0.125,0,0))
	t1 = unix.time()
	fL2 = vector.new(T.position6D(K2.forward_larm(q, qWaist)))
	fR2 = vector.new(T.position6D(K2.forward_rarm(q, qWaist)))
	t2 = unix.time()
	assert(vector.norm(fL2-fL)<0.001)
	assert(vector.norm(fR2-fR)<0.001)
	dt = vector.new{t1-t0, t2-t1}
	dt_all = dt_all + dt
	fkLs[i] = K2.forward_larm(q, qWaist)
	fkRs[i] = K2.forward_rarm(q, qWaist)
end
print('FK all good! Times:', dt_all, n)
print()

qLArm = qs[10]
fkL = fkLs[10]
fL = T.position6D(fkL)

print('FK:', vector.new(fL))
iqLArm = K.inverse_l_arm_7(fL, qLArm, 0, 0, qWaist, 0.125,0,0, 0)
iqLArm1 = K2.inverse_larm(fkL, qLArm, 0, 0)

print('IK left')
print('iqLArm',vector.new(iqLArm))
print('iqLArm1',vector.new(iqLArm1))

dt_all = vector.zeros(4)
for i, fk in ipairs(fkLs) do
	t0 = unix.time()
	iqLArm = K.inverse_l_arm_7(fL, qLArm, 0, 0, {0,0}, 0,0,0, 0)
	t1 = unix.time()
	iqLArm1 = K2.inverse_larm(fkL2, qLArm, 0)
	t2 = unix.time()
	dt_all = vector.new{t1-t0, t2-t1} + dt_all
end
print('Time:', dt_all)
print('New/Old', dt_all[2] / dt_all[1])


local qArm = vector.zeros(7)
--local qArm = vector.new({180,0,0, 0, 0,0,0})*DEG_TO_RAD
--local qArm = vector.new({90,0,0, -45, 0,0,0})*DEG_TO_RAD
--local qArm = vector.new({90,0,90*math.random(), -45, 0,0,0})*DEG_TO_RAD
--local qArm = vector.new({90*math.random(),-90*math.random(),90*math.random(), -90*math.random(), 0,90*math.random(),0})*DEG_TO_RAD
local qWaist = vector.new{45,0} * DEG_TO_RAD

local JacArm = K.calculate_arm_jacobian(
qArm,
qWaist,
{0,0,0}, --rpy angle
0, --isLeft,
0,--Config.arm.handoffset.gripper3[1],
0,--handOffsetY,
0 --Config.arm.handoffset.gripper3[3]
)  --tool xyz

local J = torch.Tensor(JacArm):resize(6,7)  
local JT = torch.Tensor(J):transpose(1,2)

--print('JacArm', unpack(JacArm))
print('Jacobian')
util.ptorch(J, 5, 3)
--print('Jacobian Transpose')
--util.ptorch(JT, 5, 3)

print()
local J2 = torch.Tensor(K2.jacobian(qArm))
print('Jacobian 2')
util.ptorch(J2, 5, 3)
--print('Jacobian Transpose 2')
--util.ptorch(J2:t(), 5, 3)
--print('COM')
--print(com)
--com = torch.Tensor(com)
--util.ptorch(com, 5, 3)

print()
print('Jacobian Waist')
local J3 = torch.Tensor(K2.jacobian_waist({qWaist[1], unpack(qArm)}))
util.ptorch(J3, 5, 3)


print('qArm', qArm)


--[[
local t0 = unix.time()
for i,q in ipairs(qs) do
	local JT3 = torch.Tensor(K2.jac(q))
end
local t1 = unix.time()
local d2 = t1-t0
--]]

local t0 = unix.time()
for i,q in ipairs(qs) do
	local JacArm = K.calculate_arm_jacobian(
	q,
	{0,0},
	{0,0,0}, --rpy angle
	0, --isLeft,
	0,--Config.arm.handoffset.gripper3[1],
	0,--handOffsetY,
	0 --Config.arm.handoffset.gripper3[3]
	)  --tool xyz
	local J = torch.Tensor(JacArm):resize(6,7)  
	--local JT = torch.Tensor(J):transpose(1,2)
end
local t1 = unix.time()
local d0 = t1-t0


local t0 = unix.time()
for i,q in ipairs(qs) do
	local JT2 = torch.Tensor(K2.jacobian(q))
end
local t1 = unix.time()
local d1 = t1-t0

print('Method0',d0)
print('Method1',d1)
print('Method2',d2)


print('Speedup1',d0/d1)
print('Speedup2',d2 and d0/d2)
--]]
--[[
print()
print('Check diff')
local dJ = J2 - J
print('Sum', torch.sum(dJ))
--]]

util.ptorch(J2, 5, 2)
util.ptorch(J, 5, 2)

for i,q in ipairs(qs) do
		local JacArm = K.calculate_arm_jacobian(
	q,
	{0,0},
	{0,0,0}, --rpy angle
	0, --isLeft,
	0,--Config.arm.handoffset.gripper3[1],
	0,--handOffsetY,
	0 --Config.arm.handoffset.gripper3[3]
	)  --tool xyz
	local J = torch.Tensor(JacArm):resize(6,7)
	local JT = torch.Tensor(J):transpose(1,2)
	local d = (torch.Tensor(K2.jacobian(q)) - J):sum()
	--print(d)
	assert( d < 1e-10, 'BAD '..d)
end
print('OK!')
