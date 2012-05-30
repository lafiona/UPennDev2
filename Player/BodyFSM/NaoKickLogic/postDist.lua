module(..., package.seeall);

-- goalpost distance threshold
pNear = Config.fsm.bodyApproach.pNear or 0.3;
pFar = Config.fsm.bodyApproach.pFar or 1.0;

function action()
  -- get attack goalpost positions and goal angle
  posts = {wcm.get_goal_attack_post1(), wcm.get_goal_attack_post2()}

  -- calculate the relative distance to each post, find closest
  pose = wcm.get_pose();
  p1Relative = util.pose_relative({posts[1][1], posts[1][2], 0}, {pose.x, pose.y, pose.a});
  p2Relative = util.pose_relative({posts[2][1], posts[2][2], 0}, {pose.x, pose.y, pose.a});
  p1Dist = math.sqrt(p1Relative[1]^2 + p1Relative[2]^2);
  p2Dist = math.sqrt(p2Relative[1]^2 + p2Relative[2]^2);
  pClosest = math.min(p1Dist, p2Dist);
  pFarthest = math.max(p1Dist, p2Dist);

  if ((pClosest > pNear) and (pClosest < pFar)) then
    print('kick');   
    return "kick";
  else
    print("My distance is ",pClosest,"\n");
    return "walkKick";
  end
end

