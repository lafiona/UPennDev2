module(..., package.seeall);

require('Config');	-- For Ball and Goal Size
require('ImageProc');
require('HeadTransform');	-- For Projection
require('Vision');
require ('vcm')
-- Dependency
require('Detection');

-- Define Color
colorOrange = 1;
colorYellow = 2;
colorCyan = 4;
colorField = 8;
colorWhite = 16;

min_white_pixel = Config.vision.line.min_white_pixel or 200;
min_green_pixel = Config.vision.line.min_green_pixel or 5000;

--min_width=Config.vision.line.min_width or 4;
max_width=Config.vision.line.max_width or 8;
connect_th=Config.vision.line.connect_th or 1.4;
max_gap=Config.vision.line.max_gap or 1;
min_length=Config.vision.line.min_length or 3;

headZ = Config.head.camOffsetZ;

min_angle_diff = Config.vision.line.min_angle_diff or 15;
max_angle_diff = Config.vision.line.max_angle_diff or 70;



--copied from corner detection. Will make it more organized after Robocup.
--get the cross point of two line segements. 
--(x1, y1) (x2, y2) are endpoints for the first line, (x3, y3) (x4, y4) are endpoints for the other line
function get_crosspoint(x1,y1,x2,y2,x3,y3,x4,y4)
  k1 = (y2 - y1)/(x2 - x1);
  k2 = (y4 - y3)/(x4 - x3);
  if (k1 == k2) then
    return {0,0}
  end
  local x = (y3 - y1 + k1*x1 -k2*x3)/(k1 - k2);
  local y = k1*(x - x2) + y2;
  return {x,y};
end




function detect()
   --TODO: test line detection
  line = {};
  line.detect = 0;
  line_second = {};
  line_second.detect  = 0;
  if (Vision.colorCount[colorWhite] < min_white_pixel) then 
    --print('under 200 white pixels');
    return line;
  end
  if (Vision.colorCount[colorField] < min_green_pixel) then 
    --print('under 5000 green pixels');
    return line; 
  end

  linePropsB = ImageProc.field_lines(Vision.labelB.data, Vision.labelB.m,
		 Vision.labelB.n, max_width,connect_th,max_gap,min_length);

  if #linePropsB==0 then 
    --print('linePropsB nil')
    return line; 
  end

  line.propsB=linePropsB;
  nLines=0;

  nLines=#line.propsB;
  horizonA = vcm.get_image_horizonA();
  horizonB = vcm.get_image_horizonB(); 
  
  vcm.add_debug_message(string.format(
    "Total %d lines detected\n HorizonA: %d, HorizonB: %d\n" ,nLines, horizonA, horizonB));

  if (nLines==0) then
    return line; 
  end

  line.v={};
  line.endpoint={};
  line.angle={};
  line.length={}

  for i = 1,6 do
    line.endpoint[i] = vector.zeros(4);
    line.v[i]={};
    line.v[i][1]=vector.zeros(4);
    line.v[i][2]=vector.zeros(4);
    line.angle[i] = 0;
  end


  bestindex = 1;
  bestlength = 0;
  linecount = 0;
  second_linecount = 0;
  
  

-- first round check, check on sigle line

  for i=1,nLines do
    local length = math.sqrt(
	(line.propsB[i].endpoint[1]-line.propsB[i].endpoint[2])^2+
	(line.propsB[i].endpoint[3]-line.propsB[i].endpoint[4])^2);

    local vendpoint_old = {};
    vendpoint_old[1] = HeadTransform.coordinatesB(
  vector.new({line.propsB[i].endpoint[1], line.propsB[i].endpoint[3]}));
    vendpoint_old[2] = HeadTransform.coordinatesB(
	vector.new({line.propsB[i].endpoint[2], line.propsB[i].endpoint[4]}));

    local vendpoint = {};
    vendpoint[1] = HeadTransform.projectGround(vendpoint_old[1],0);
    vendpoint[2] = HeadTransform.projectGround(vendpoint_old[2],0);
 
    local goal1 = vcm.get_goal_v1();
    local goal2 = vcm.get_goal_v2();
    local goal_posX = 0;
    local lineX = 0.5*(vendpoint[1][1]+vendpoint[2][1])
    if (goal1[1] > 0 or goal2[1] > 0) then
      goal_posX = math.max (goal1[1], goal2[1]);
    else
      goal_posX = math.min (goal1[1], goal2[1]);
    end
    --print ('goal_posX: '..goal_posX)
    local LWratio = length/line.propsB[i].max_width;
    
    if length > min_length and linecount < 6 
  -- lines should be on the ground
  and vendpoint_old[1][3] < 0.3 and vendpoint_old[2][3] < 0.3 
  -- lines should not be too wide
  and LWratio > 2.5 
  -- lines should be below horizon
  and line.propsB[i].endpoint[3] > horizonB and line.propsB[i].endpoint[4] > horizonB  
  -- lines should be in the court, nothing behind the goal posts can be considered as line.
  and (goal_posX >= 0.15 or (goal_posX < 0.15 and lineX > goal_posX)) 
--vendpoint[1][1] > goal_posX and vendpoint[2][1] > goal_posX
  then
      linecount=linecount+1;
      line.length[linecount]=length;
      line.endpoint[linecount]= line.propsB[i].endpoint;
            line.v[linecount]={};
      line.v[linecount][1]=vendpoint[1];
      line.v[linecount][2]=vendpoint[2];
      line.angle[linecount]=math.abs(math.atan2(vendpoint[1][2]-vendpoint[2][2], vendpoint[1][1]-vendpoint[2][1]));
      --print (util.ptable(line.v[linecount]))
     
     -- print(string.format(
--[[		"Line %d: endpoint1: (%f, %f), endpoint2: (%f, %f), \n endpoint1 in labelB: (%f, %f), endpoint2 in labelB: (%f, %f), horizonB: %f,\n length %d, angle %d, max_width %d\n",
		linecount,line.v[linecount][1][1], line.v[linecount][1][2],
    line.v[linecount][2][1], line.v[linecount][2][2],
    line.propsB[i].endpoint[1], line.propsB[i].endpoint[3], line.propsB[i].endpoint[2], line.propsB[i].endpoint[4], horizonB,
    line.length[linecount],
		line.angle[linecount]*180/math.pi, line.propsB[i].max_width));
  --]]
    end
  end

  local line_valid = {};
  for i = 1, linecount do
    line_valid[i] = 1;
  end
-- second round check, check pairs of lines
  
  for i = 1, linecount do
    for j = 1, linecount do
      local angle_diff = util.mod_angle(line.angle[i] - line.angle[j]);
      angle_diff = math.abs (angle_diff) * 180 / math.pi;
      angle_diff = math.min (angle_diff, 180 - angle_diff);
      local Cross = get_crosspoint (line.v[i][1][1], line.v[i][1][2], line.v[i][2][1], line.v[i][2][2],line.v[j][1][1], line.v[j][1][2], line.v[j][2][1], line.v[j][2][2])
-- in all checks on line pairs, always kill the shorter one. 
      if ( line.length[i] < line.length[j] and line_valid[i]*line_valid[j] ==1 ) then
-- angle check
        if (angle_diff > min_angle_diff and angle_diff < max_angle_diff) then
--          print ('angle check failed. angle_diff: '..angle_diff..', line'..i..' and line '..j)
          line_valid[i] = 0;
        end
-- cross check
        if ((Cross[1] - line.v[i][1][1])*(Cross[1] - line.v[i][2][1]) < 0 and (Cross[1] -  line.v[j][1][1])*(Cross[1] - line.v[j][2][1]) < 0 ) then
--          print ('cross check failed. line '..i..' and line '..j..' are crossed')
          line_valid[i] = 0;
        end
      end
    end 
  end



-- copy the remaining lines in a new array that will be returned.
  line_second.v={};
  line_second.endpoint={};
  line_second.angle={};
  line_second.length={}

  for i = 1,6 do
    line_second.endpoint[i] = vector.zeros(4);
    line_second.v[i]={};
    line_second.v[i][1]=vector.zeros(4);
    line_second.v[i][2]=vector.zeros(4);
    line_second.angle[i] = 0;
  end


  for i = 1, linecount do
    --print ('valid: '..line_valid[i])
    if (line_valid[i] == 1) then
      second_linecount = second_linecount + 1;
      line_second.angle[second_linecount] = line.angle[i];
      line_second.v[second_linecount] = line.v[i];
      line_second.endpoint[second_linecount] = line.endpoint[i];
      line_second.length[second_linecount] = line.length[i];
    end
  end

  nLines = second_linecount;
  line_second.nLines = nLines;

  --TODO::::find distribution of v
  --[[
  sumx=0;
  sumxx=0;
  for i=1,nLines do 
    --angle: -pi to pi
    sumx=sumx+line.angle[i];
    sumxx=sumxx+line.angle[i]*line.angle[i];

  --]]
  if nLines>0 then
    line_second.detect = 1;
  end
  return line_second;
end
