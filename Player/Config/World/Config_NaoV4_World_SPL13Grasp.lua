module(..., package.seeall);
require('vector')

--Localization parameters for Testing in Grasp
--The field is shrinked to 85% of its real size
--But the size of the boxes and the distance between the goal posts are unchanged

world={};
world.n = 200;
world.xLineBoundary = 3.825;
world.yLineBoundary = 2.55;
world.xMax = 4;
world.yMax = 2.75;
world.goalWidth = 1.40;
world.goalHeight= 0.85;
world.goalDiameter=0.10; -- diameter of a post
world.ballYellow= {{4.5,0.0}};
world.ballCyan= {{-4.6,0.0}};
world.postYellow = {};
world.postYellow[1] = {3.825, 0.70};
world.postYellow[2] = {3.825, -0.70};
world.postCyan = {};
world.postCyan[1] = {-3.825, -0.70};
world.postCyan[2] = {-3.825, 0.70};
world.spot = {};
world.spot[1] = {-2.295, 0};
world.spot[2] = {2.295, 0};
world.cResample = 10; --Resampling interval

--They are SPL 2013 values
world.Lcorner={};
--Field edge
world.Lcorner[1]={3.825,2.55};
world.Lcorner[2]={3.825,-2.55};
world.Lcorner[3]={-3.825,2.55};
world.Lcorner[4]={-3.825,-2.55};
--Center T edge
world.Lcorner[5]={0,2.55};
world.Lcorner[6]={0,-2.55};
--Penalty box edge
world.Lcorner[7]={-3.225,1.1};
world.Lcorner[8]={-3.225,-1.1};
world.Lcorner[9]={3.225,1.1};
world.Lcorner[10]={3.225,-1.1};
--Penalty box T edge
world.Lcorner[11]={3.825,1.1};
world.Lcorner[12]={3.825,-1.1};
world.Lcorner[13]={-3.825,1.1};
world.Lcorner[14]={-3.825,-1.1};
--Center circle junction
world.Lcorner[15]={0,0.6375};
world.Lcorner[16]={0,-0.6375};
world.Lcorner[17]={0.6375,0};
world.Lcorner[18]={-0.6375,0};

--same-colored goalposts
world.use_same_colored_goal=1;

--should we use new triangulation?
world.use_new_goalposts=1;



--Two post observation
--world.rGoalFilter = 0.02;
world.rGoalFilter = 0.06;
world.aGoalFilter = 0.15;

--Single post observation
world.rPostFilter = 0.02;
world.aPostFilter = 0.05;

--Single known post observation
world.rPostFilter2 = 0.05;
world.aPostFilter2 = 0.10;

--Corner observation
world.rCornerFilter = 0.01;
world.aCornerFilter = 0.02;

--Line observation
world.aLineFilter = 0.02;

--Single landmark determing param
world.rSigmaSingle1 = .15;
world.rSigmaSingle2 = .10;
world.aSigmaSingle = 5*math.pi/180; --Original value

--Two post determining param
world.rSigmaDouble1 = .25;
world.rSigmaDouble2 = .20;
world.aSigmaDouble = 30*math.pi/180;

-- default positions for our kickoff
world.initPosition1={
  {3.5,0},   --Goalie
  {0.5, 0}, --Attacker
  {1.2,-1}, --Defender
  {1.2, 1}, --Supporter
  {2.2, 0}, --Defender2
}
-- default positions for opponents' kickoff
-- Penalty mark : {1.2,0}
world.initPosition2={
  {3.5,0},   --Goalie
  {2.0, 0}, --Attacker
  {2.5, -1}, --Defender
  {2.5,1}, --Supporter
  {2.5, 0}, --Defender2
}

-- use sound localization
world.enable_sound_localization = 0;

--Trying yaw odometry data [x, y, angle]
world.odomScale = {1, 1, 1.03};

world.triangulation_threshold = 4.0;
world.position_update_threshold = 6.0;

world.triangulation_threshold = 6.0;
world.position_update_threshold = 7.0;

--should we use new triangulation?
world.use_new_goalposts=1;
