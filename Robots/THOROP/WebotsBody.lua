local WebotsBody = {}
local ww, cw, mw, sw, fw, rw, dw, kb
local ptable = require'util'.ptable
local ffi = require'ffi'

function WebotsBody.entry()
	
	ww = Config.wizards.world and require(Config.wizards.world)
	cw = Config.wizards.camera and require(Config.wizards.camera)
  mw = Config.wizards.mesh and require(Config.wizards.mesh)
	--kw = Config.wizards.kinect and require(Config.wizards.kinect)
	sw = Config.wizards.slam and require(Config.wizards.slam)
	fw = Config.wizards.feedback and require(Config.wizards.feedback)
	rw = Config.wizards.remote and require(Config.wizards.remote)
	kb = Config.testfile and require(Config.testfile)
  dw = Config.wizards.detect and require(Config.wizards.detect)

	WebotsBody.USING_KB = type(kb)=='table' and type(kb.update)=='function'
	
	if ww then ww.entry() end
  if fw then fw.entry() end
  if rw then rw.entry() end
end

function WebotsBody.update_head_camera(img, sz, cnt, t)
	if cw then cw.update(img, sz, cnt, t) end
end

function WebotsBody.update_head_lidar(metadata, ranges)
  if sw then sw.update(metadata, ranges) end
end

function WebotsBody.update_chest_lidar(metadata, ranges)
  if mw then mw.update(metadata, ranges) end
end

function WebotsBody.update_kinect_depth(metadata, ranges)
  if dw and hcm.get_octomap_update()==1 then 
    dw.update_kinect_depth(metadata, ranges) 
  end
end

local depth_fl = ffi.new('float[?]', 1)
local n_depth_fl = ffi.sizeof(depth_fl)
function WebotsBody.update_chest_kinect(rgb, depth)
	depth.bpp = ffi.sizeof('float')
	local n_pixels = depth.width * depth.height
	if n_pixels~=n_depth_fl then
		depth_fl = ffi.new('float[?]', n_pixels)
	end
	local byte_sz = n_pixels * depth.bpp
	ffi.copy(depth_fl, depth.data, byte_sz)
	-- Convert to mm
	for i=1,n_pixels do depth_fl[i] = 1000 * depth_fl[i] end
	depth.data = ffi.string(depth_fl, byte_sz)
	if kw then kw.update(rgb, depth) end
end

function WebotsBody.update(keycode)
	if ww then ww.update() end
  if fw then fw.update() end
  if rw then rw.update() end
  if dw then dw.update() end

	if WebotsBody.USING_KB then kb.update(keycode) end
	-- Add logging capability
end

function WebotsBody.exit()
	if ww then ww.exit() end
end

return WebotsBody
