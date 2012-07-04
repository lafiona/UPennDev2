module(..., package.seeall);

require('carray');
require('vector');
require('Config');
-- Enable Webots specific
if (string.find(Config.platform.name,'Webots')) then
  webots = 1;
end

require('ImageProc');
require('HeadTransform');

require('vcm');
require('mcm');
require('Body')

--Added for webots fast simulation
use_gps_only = Config.use_gps_only or 0;

obs_challenge_enable = Config.obs_challenge or 0;
enable_lut_for_obstacle = Config.vision.enable_lut_for_obstacle or 0;

if use_gps_only==0 then
  require('Camera');
  require('Detection');
  
  if (Config.camera.width ~= Camera.get_width()
      or Config.camera.height ~= Camera.get_height()) then
    print('Camera width/height mismatch');
    print('Config width/height = ('..Config.camera.width..', '..Config.camera.height..')');
    print('Camera width/height = ('..Camera.get_width()..', '..Camera.get_height()..')');
    error('Config file is not set correctly for this camera. Ensure the camera width and height are correct.');
  end
  vcm.set_image_width(Config.camera.width);
  vcm.set_image_height(Config.camera.height);
  
  camera = {};
  
  camera.width = Camera.get_width();
  camera.height = Camera.get_height();
  camera.npixel = camera.width*camera.height;
  camera.image = Camera.get_image();
  camera.status = Camera.get_camera_status();
  camera.switchFreq = Config.camera.switchFreq;
  camera.ncamera = Config.camera.ncamera;
  -- Initialize the Labeling
  labelA = {};
  -- labeled image is 1/4 the size of the original
  labelA.m = camera.width/2;
  labelA.n = camera.height/2;
  labelA.npixel = labelA.m*labelA.n;
  if  webots == 1 then
    labelA.m = camera.width;
    labelA.n = camera.height;
    labelA.npixel = labelA.m*labelA.n;
  end
  scaleB = Config.vision.scaleB;
  labelB = {};
  labelB.m = labelA.m/scaleB;
  labelB.n = labelA.n/scaleB;
  labelB.npixel = labelB.m*labelB.n;
  vcm.set_image_scaleB(Config.vision.scaleB);
  print('Vision LabelA size: ('..labelA.m..', '..labelA.n..')');
  print('Vision LabelB size: ('..labelB.m..', '..labelB.n..')');
else
  require('GPSVision');
end

colorOrange = Config.color.orange;
colorYellow = Config.color.yellow;
colorCyan = Config.color.cyan;
colorField = Config.color.field;
colorWhite = Config.color.white;

yellowGoalCountThres = Config.vision.yellow_goal_count_thres;

saveCount = 0;

use_point_goal = Config.vision.use_point_goal or 0;
subsampling = Config.vision.subsampling or 0;
subsampling2 = Config.vision.subsampling2 or 0;

-- debugging settings
vcm.set_debug_enable_shm_copy(Config.vision.copy_image_to_shm);
vcm.set_debug_store_goal_detections(Config.vision.store_goal_detections);
vcm.set_debug_store_ball_detections(Config.vision.store_ball_detections);
vcm.set_debug_store_all_images(Config.vision.store_all_images);

-- Timing
count = 0;
lastImageCount = {0,0};
t0 = unix.time()

function entry()
  --Temporary value.. updated at body FSM at next frame
  vcm.set_camera_bodyHeight(Config.walk.bodyHeight);
  vcm.set_camera_bodyTilt(0);
  vcm.set_camera_height(Config.walk.bodyHeight+Config.head.neckZ);
	vcm.set_camera_ncamera(Config.camera.ncamera);

  -- Start the HeadTransform machine
  HeadTransform.entry();

  --If we are only using gps info, skip camera init 	
  if use_gps_only>0 then
    return;
  end

  -- Initiate Detection
  Detection.entry();
  
  --set to switch cameras. 
  -- Load the lookup table
  print('loading lut: '..Config.camera.lut_file);
  camera.lut = carray.new('c', 262144);
  load_lut(Config.camera.lut_file);

  --ADDED to prevent crashing with old camera config
  if Config.camera.lut_file_obs == null then
    Config.camera.lut_file_obs = Config.camera.lut_file;
  end

  -- Load the obstacle LUT as well
  if enable_lut_for_obstacle == 1 then
    print('loading obs lut: '..Config.camera.lut_file_obs);
    camera.lut_obs = carray.new('c', 262144);
    load_lut_obs(Config.camera.lut_file_obs);
  end

  if Config.platform.name=="NaoV4" then
    camera_init_naov4();
  else
    camera_init();
  end 

  -- in default, use prelearned colortable
  vcm.set_image_learn_lut(0);
end

function camera_init()
  for c=1,Config.camera.ncamera do 
    Camera.select_camera(c-1);
    for i,auto_param in ipairs(Config.camera.auto_param) do
      print('Camera '..c..': setting '..auto_param.key..': '..auto_param.val[c]);
      Camera.set_param(auto_param.key, auto_param.val[c]);
      unix.usleep(100000);
      print('Camera '..c..': set to '..auto_param.key..': '..Camera.get_param(auto_param.key));
    end   
    for i,param in ipairs(Config.camera.param) do
      print('Camera '..c..': setting '..param.key..': '..param.val[c]);
      Camera.set_param(param.key, param.val[c]);
      unix.usleep(10000);
      print('Camera '..c..': set to '..param.key..': '..Camera.get_param(param.key));
    end
  end
end

function camera_init_naov4()
  for c=1,Config.camera.ncamera do
    Camera.select_camera(c-1);   
    Camera.set_param('Brightness', Config.camera.brightness);     
    Camera.set_param('White Balance, Automatic', 1); 
    Camera.set_param('Auto Exposure',0);
    for i,param in ipairs(Config.camera.param) do
      Camera.set_param(param.key, param.val[c]);
      unix.usleep (100);
    end
    Camera.set_param('White Balance, Automatic', 0);
    Camera.set_param('Auto Exposure',0);
    local expo = Camera.get_param('Exposure');
    local gain = Camera.get_param('Gain');
    Camera.set_param('Auto Exposure',1);   
    Camera.set_param('Auto Exposure',0);
    --Camera.set_param ('Exposure', 255);
    Camera.set_param ('Exposure', expo);
    Camera.set_param ('Gain', gain);
    print('Camera #'..c..' set');
  end
end


function update()
  --If we are only using gps info, skip whole vision update 	
  if use_gps_only>0 then
    update_gps_only();
    return true;
  end

  tstart = unix.time();

  -- get image from camera
  camera.image = Camera.get_image();

  local status = Camera.get_camera_status();
  if status.count ~= lastImageCount[status.select+1] then
    lastImageCount[status.select+1] = status.count;
  else
    return false; 
  end

--SJ: Camera image keeps changing
--So copy it here to shm, and use it for all vision process
  vcm.set_image_yuyv(camera.image);

  -- Add timer measurements
  count = count + 1;

  headAngles = Body.get_head_position();
  HeadTransform.update(status.select, headAngles);

  if camera.image == -2 then
    print "Re-enqueuing of a buffer error...";
    exit()
  end



  -- perform the initial labeling
  if webots == 1 then
    labelA.data = Camera.get_labelA( carray.pointer(camera.lut) );
  else

    labelA.data  = ImageProc.yuyv_to_label(vcm.get_image_yuyv(),
                                          carray.pointer(camera.lut),
                                          camera.width/2,
                                          camera.height);
  end

  -- determine total number of pixels of each color/label
  colorCount = ImageProc.color_count(labelA.data, labelA.npixel);


  -- bit-or the segmented image
  labelB.data = ImageProc.block_bitor(labelA.data, labelA.m, labelA.n, scaleB, scaleB);

  -- perform label process for obstacle specific lut
  if enable_lut_for_obstacle == 1 then
    -- label A
    if webots == 1 then
      labelA.data_obs = Camera.get_labelA_obs( carray.pointer(camera.lut_obs) );
    else
      labelA.data_obs  = ImageProc.yuyv_to_label_obs(vcm.get_image_yuyv(),
                                    carray.pointer(camera.lut_obs), camera.width/2, camera.height);
    end
    -- count color pixels
    colorCount_obs = ImageProc.color_count_obs(labelA.data_obs, labelA.npixel);
    -- label B
    labelB.data_obs = ImageProc.block_bitor_obs(labelA.data_obs, labelA.m, labelA.n, scaleB, scaleB);
  end

  update_shm(status, headAngles)

  -- Learn ball color from mask and rebuild colortable
  if obs_challenge_enable == 1 then
--    print('enable obs challenge')
    if vcm.get_image_learn_lut() == 1 then
      print("learn new colortable for random ball from mask");
      vcm.set_image_learn_lut(0);
      mask = ImageProc.label_to_mask(labelA.data_obs, labelA.m, labelA.n);
      if webots == 1 then
        print("learn in webots")
        lut_update = Camera.get_lut_update(mask, carray.pointer(camera.lut_obs));
--        lut_update = Camera.get_lut_update(mask, carray.pointer(camera.lut));
      else
        print("learn in op")
        lut_update = ImageProc.yuyv_mask_to_lut(vcm.get_image_yuyv(), mask, camera.lut, 
                                                labelA.m, labelA.n);
      end
      print(type(mask),type(labelB.data))
    end
  end

  vcm.refresh_debug_message();

  Detection.update();
  vcm.refresh_debug_message();

  -- switch camera
  local cmd = vcm.get_camera_command();
  if (cmd == -1) then
    if (count % camera.switchFreq == 0) then
       Camera.select_camera(1-Camera.get_select()); 
    end
  else
    if (cmd >= 0 and cmd < camera.ncamera) then
      Camera.select_camera(cmd);
    else
      print('WARNING: attempting to switch to unkown camera select = '..cmd);
    end
  end

  return true;
end

function update_shm_fov()
  --This function projects the boundary of current labeled image

  local fovC={Config.camera.width/2,Config.camera.height/2};
  local fovBL={0,Config.camera.height};
  local fovBR={Config.camera.width,Config.camera.height};
  local fovTL={0,0};
  local fovTR={Config.camera.width,0};

  vcm.set_image_fovC(vector.slice(HeadTransform.projectGround(
 	  HeadTransform.coordinatesA(fovC,0.1)),1,2));
  vcm.set_image_fovTL(vector.slice(HeadTransform.projectGround(
 	  HeadTransform.coordinatesA(fovTL,0.1)),1,2));
  vcm.set_image_fovTR(vector.slice(HeadTransform.projectGround(
 	  HeadTransform.coordinatesA(fovTR,0.1)),1,2));
  vcm.set_image_fovBL(vector.slice(HeadTransform.projectGround(
 	  HeadTransform.coordinatesA(fovBL,0.1)),1,2));
  vcm.set_image_fovBR(vector.slice(HeadTransform.projectGround(
 	  HeadTransform.coordinatesA(fovBR,0.1)),1,2));
end

function update_shm(status, headAngles)
  -- Update the shared memory
  -- Shared memory size argument is in number of bytes

  if vcm.get_debug_enable_shm_copy() == 1 then
    if ((vcm.get_debug_store_all_images() == 1)
        or (ball.detect == 1
            and vcm.get_debug_store_ball_detections() == 1)
        or ((goalCyan.detect == 1 or goalYellow.detect == 1) 
            and vcm.get_debug_store_goal_detections() == 1)) then

	if webots == 1  then
          vcm.set_camera_yuyvType(1);
          vcm.set_image_labelA(labelA.data);
          vcm.set_image_labelB(labelB.data);
--          vcm.set_image_labelA_obs(labelA.data_obs);
--          vcm.set_image_labelB_obs(labelB.data_obs);
	end
        if vcm.get_camera_broadcast() > 0 then --Wired monitor broadcasting
	  if vcm.get_camera_broadcast() == 1 then
	    --Level 1: 1/4 yuyv, labelB
            vcm.set_image_yuyv3(ImageProc.subsample_yuyv2yuyv(
  	    vcm.get_image_yuyv(),
	    camera.width/2, camera.height,4));
            vcm.set_image_labelB(labelB.data);
	  elseif vcm.get_camera_broadcast() == 2 then
	    --Level 2: 1/2 yuyv, labelA, labelB
            vcm.set_image_yuyv2(ImageProc.subsample_yuyv2yuyv(
  	      vcm.get_image_yuyv(),
  	      camera.width/2, camera.height,2));
            vcm.set_image_labelA(labelA.data);
            vcm.set_image_labelB(labelB.data);
	  else
	    --Level 3: 1/2 yuyv
            vcm.set_image_yuyv2(ImageProc.subsample_yuyv2yuyv(
  	    vcm.get_image_yuyv(),
  	    camera.width/2, camera.height,2));
	  end

	elseif vcm.get_camera_teambroadcast() > 0 then --Wireless Team broadcasting
          --Only copy labelB
          vcm.set_image_labelB(labelB.data);
        end
    end
  end

  vcm.set_image_select(status.select);
  vcm.set_image_count(status.count);
  vcm.set_image_time(status.time);
  vcm.set_image_headAngles(headAngles);
  vcm.set_image_horizonA(HeadTransform.get_horizonA());
  vcm.set_image_horizonB(HeadTransform.get_horizonB());
  vcm.set_image_horizonDir(HeadTransform.get_horizonDir())

  update_shm_fov();
end

function exit()
  HeadTransform.exit();
end

function bboxStats(color, bboxB, rollAngle, scale)
  scale = scale or scaleB;
  bboxA = {};
  bboxA[1] = scale*bboxB[1];
  bboxA[2] = scale*bboxB[2] + scale - 1;
  bboxA[3] = scale*bboxB[3];
  bboxA[4] = scale*bboxB[4] + scale - 1;
  if rollAngle then
 --hack: shift boundingbox 1 pix helps goal detection
 --not sure why this thing is happening...

--    bboxA[1]=bboxA[1]+1;
      bboxA[2]=bboxA[2]+1;

    return ImageProc.tilted_color_stats(
	labelA.data, labelA.m, labelA.n, color, bboxA,rollAngle);
  else
    return ImageProc.color_stats(labelA.data, labelA.m, labelA.n, color, bboxA);
  end
end

function bboxB2A(bboxB)
  bboxA = {};
  bboxA[1] = scaleB*bboxB[1];
  bboxA[2] = scaleB*bboxB[2] + scaleB - 1;
  bboxA[3] = scaleB*bboxB[3];
  bboxA[4] = scaleB*bboxB[4] + scaleB - 1;
  return bboxA;
end

function bboxArea(bbox)
  return (bbox[2] - bbox[1] + 1) * (bbox[4] - bbox[3] + 1);
end

function load_lut(fname)
  if not string.find(fname,'.raw') then
    fname = fname..'.raw';
  end
  local cwd = unix.getcwd();
  if string.find(cwd, "WebotsController") then
    cwd = cwd.."/Player";
  end
  cwd = cwd.."/Data/";
  local f = io.open(cwd..fname, "r");
  assert(f, "Could not open lut file");
  local s = f:read("*a");
  for i = 1,string.len(s) do
    camera.lut[i] = string.byte(s,i,i);
  end
end

function load_lut_obs(fname)
  if not string.find(fname,'.raw') then
    fname = fname..'.raw';
  end
  local cwd = unix.getcwd();
  if string.find(cwd, "WebotsController") then
    cwd = cwd.."/Player";
  end
  cwd = cwd.."/Data/";
  local f = io.open(cwd..fname, "r");
  assert(f, "Could not open lut file");
  local s = f:read("*a");
  for i = 1,string.len(s) do
    camera.lut_obs[i] = string.byte(s,i,i);
  end
end

function save_rgb(rgb)
  saveCount = saveCount + 1;
  local filename = string.format("/tmp/rgb_%03d.raw", saveCount);
  local f = io.open(filename, "w+");
  assert(f, "Could not open save image file");
  for i = 1,3*camera.width*camera.height do
    local c = rgb[i];
    if (c < 0) then
      c = 256+c;
    end
    f:write(string.char(c));
  end
  f:close();
end
