-- Set the path for the libraries
dofile('../../include.lua')
-- Set the Debugging mode
local debug = true;

-- Require the right modules
local simple_ipc = require 'simple_ipc'
local mp = require 'MessagePack'
require 'unix'
require 'cjpeg'

-- Set up the UDP channel for broadcasting
require 'Comm'
Comm.init('192.168.123.255', 54321);

-- Setup IPC Channels
local omap_channel   = simple_ipc.new_subscriber('omap');
local camera_channel = simple_ipc.new_subscriber('img');
local oct_channel    = simple_ipc.new_subscriber('oct');

-- Send the Occupmancy Map
-- JPEG compressed
local omap_callback = function()
  local omap_data, has_more = omap_channel:receive()
  local jimg = cjpeg.compress( omap_data );
  local nsent = Comm.send( jimg );
  print("OMAP | Sent ", nsent )
end
omap_channel.callback = omap_callback

-- Send image over UDP
-- JPEG compress it
local camera_callback = function()
  local camera_ts, has_more = camera_channel:receive()
  -- TODO: Get timestamp
  --[[
  if not has_more then
  print( 'Bad Camera | ', type(camera_ts), type(has_more) )
  return;
  end
  local camera_data, has_more = camera_channel:receive()
  local jimg = cjpeg.compress( camera_data );
  local nsent = Comm.send( jimg );
  --]]

  -- In the current form, gazebo does the compression for us
  -- This is probably not the best way to pipeline things at present..
  local nsent = Comm.send( camera_ts, #camera_ts );
  print("Camera | Sent ", nsent )
end
camera_channel.callback = camera_callback

-- Send the Oct Tree data over UDP
local oct_callback = function()
  local oct_data, has_more = oct_channel:receive()
  local nsent = Comm.send( oct_data );
  print("Oct | Sent ", nsent )
end
oct_channel.callback = oct_callback

-- Poll multiple sockets
local wait_channels = {omap_channel, camera_channel, oct_channel}
local channel_poll = simple_ipc.wait_on_channels( wait_channels );
local channel_timeout = 100; -- 100ms timeout

-- Start the timing
local t = unix.time();
local t_last = t;
local t_debug = 1; -- Print debug output every second

-- No debugging messages
-- Only the callback will be made
if not debug then
  channel_poll:start()
end

local cnt = 0;
while true do
  channel_poll:poll(channel_timeout) 
  t = unix.time()
  cnt = cnt+1;
  if t-t_last>t_debug then
    local msg = string.format("%.2f FPS", cnt/t_debug);
    print("Perception Network Manager | "..msg)
    t_last = t;
    cnt = 0;
  end
end
