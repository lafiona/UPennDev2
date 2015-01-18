#!/usr/bin/env luajit
dofile'../include.lua'
local LOG_DATE = '01.09.2015.16.42.40'

local libLog = require'libLog'
local replay_depth = libLog.open(HOME..'/Data/', LOG_DATE, 'k2_depth')
local replay_rgb = libLog.open(HOME..'/Data/', LOG_DATE, 'k2_rgb')
local metadata = replay_depth:unroll_meta()
local metadata_rgb = replay_rgb:unroll_meta()
print('Unlogging', #metadata, 'images from', LOG_DATE)

local util = require'util'
local si = require'simple_ipc'
local mp = require'msgpack.MessagePack'
local depth_ch = si.new_publisher'kinect2_depth'
local color_ch = si.new_publisher'kinect2_color'

local logged_depth = replay_depth:log_iter()
local logged_rgb = replay_rgb:log_iter()

local get_time = unix.time
local metadata_t0 = metadata[1].t
local t0

for i, metadata_depth, payload_depth in logged_depth do
	local i_rgb, metadata_rgb, payload_rgb = logged_rgb()
  metadata_rgb.c = 'jpeg'

--	if i%10==0 then
		io.write('Count ', i, '\n')
--	end

	local t = get_time()
	t0 = t0 or t
	local dt = t - t0

	local metadata_dt = metadata_depth.t - metadata_t0
	local t_sleep = metadata_dt - dt
	if t_sleep>0 then unix.usleep(1e6*t_sleep) end

  -- Assume real kinect
  metadata_depth.width = metadata_depth.width or 512
  metadata_depth.height = metadata_depth.height or 424

	depth_ch:send({mp.pack(metadata_depth), payload_depth})
  if payload_rgb then
    --metadata_rgb.rsz = #payload_rgb
    --if metadata_rgb.sz==metadata_rgb.rsz then
    	if color_ch:send({mp.pack(metadata_rgb), payload_rgb}) then
        unix.usleep(5e5)
        --if i>2 then return end
      end
    --end
  end
  
end
