module(..., package.seeall);

-- Vision Parameters

color = {};
color.orange = 1;
color.yellow = 2;
color.cyan = 4;
color.field = 8;
color.white = 16;

vision = {};
vision.ballColor = color.orange;
vision.goal1Color = color.yellow;
vision.goal2Color = color.cyan;
vision.maxFPS = 30;
vision.scaleB = 4;

-- use this to enable line detection
vision.enable_line_detection = 0;
-- use this to enable spot detection
vision.enable_spot_detection = 0;
-- use this to enable midfield landmark detection
vision.enable_midfield_landmark_detection = 0;
-- use this to enable copying images to shm (for colortables, testing)
vision.copy_image_to_shm = 1;
-- use this to enable storing all images
vision.store_all_images = 1;
-- use this to enable storing images where the goal was detected
vision.store_goal_detections = 0;
-- use this to enable storing images where the ball was detected
vision.store_ball_detections = 0;
-- use this to substitute goal check with blue/yellow ball check
vision.use_point_goal = 0;

--vision.enable_robot_detection = 1;
vision.enable_robot_detection = 0;

----------------------------
--OP specific
----------------------------
-- Use tilted bounding box?
vision.use_tilted_bbox = 1;
-- Subsample main image for monitor?
vision.subsampling = 1;  --1/2 sized image
vision.subsampling2 = 1; --1/4 sized image

--Vision parameter values

vision.ball={};
vision.ball.diameter = 0.065;
vision.ball.th_min_color = 6;
vision.ball.th_min_color2 = 6;
vision.ball.th_min_fill_rate = 0.35;
vision.ball.th_height_max  = 0.20;
vision.ball.th_ground_boundingbox = {-30,30,0,20};
vision.ball.th_min_green1 = 400;
vision.ball.th_min_green2 = 150;

vision.ball.check_for_ground = 1;

vision.goal={};
vision.goal.th_min_color_count=100;
vision.goal.th_nPostB = 5;
vision.goal.th_min_area = 40;
vision.goal.th_min_orientation = 60*math.pi/180;
vision.goal.th_min_fill_extent=0.35;
vision.goal.th_aspect_ratio={2.5,15};
vision.goal.th_edge_margin= 5;
vision.goal.th_bottom_boundingbox=0.9;
vision.goal.th_ground_boundingbox={-15,15,-15,10}; 
vision.goal.th_min_green_ratio = 0.2;
vision.goal.th_min_bad_color_ratio = 0.5;
vision.goal.th_goal_separation = {0.35,2.0};
vision.goal.th_goal_separation = {0.35,3.0}; --FOR OP
vision.goal.th_min_area_unknown_post = 200;

vision.goal.use_centerpost = 1;
vision.goal.check_for_ground = 1;

vision.line={};
vision.line.max_width = 16;
vision.line.connect_th = 1.4;
vision.line.max_gap=0;
vision.line.min_length=20;

vision.corner={};
vision.corner.dist_threshold = 100; --10 pixel
vision.corner.length_threshold = 15;
vision.corner.min_center_dist = 1.5;
