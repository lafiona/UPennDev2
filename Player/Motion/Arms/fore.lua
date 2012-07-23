module(..., package.seeall);

myplayer = 0;
function init(forPlayer)
  myplayer = forPlayer;
  primecm = require('primecm'..forPlayer)
  boxercm = require('boxercm'..forPlayer)
end

function entry()
  print("Boxer ".._NAME.." entry");
  t0 = unix.time();

  -- Upon entry to the fore state,
  -- a punch should be executed
  boxercm.set_body_punchR(1);

end

function update()
  t = unix.time();

  -- TODO: Need to check the confidence values!
  --[[
  e2hL = primecm.get_position_ElbowL() - primecm.get_position_HandL();
  s2eL = primecm.get_position_ShoulderL() - primecm.get_position_ElbowL();
  s2hL = primecm.get_position_ShoulderL() - primecm.get_position_HandL();
  --]]
  local e2hR = primecm.get_position_ElbowR() - primecm.get_position_HandR();
  local s2eR = primecm.get_position_ShoulderR() - primecm.get_position_ElbowR();
  local s2hR = primecm.get_position_ShoulderR() - primecm.get_position_HandR();

  -- Change to OP coordinates
  --[[
  local arm_lenL = vector.norm( e2hL ) + vector.norm( s2eL );
  local left_hand  = vector.new({s2hL[3],s2hL[1],s2hL[2]}) / arm_lenL; -- z is OP x, x is OP y, y is OP z
  --]]
  local arm_lenR = vector.norm( e2hR ) + vector.norm( s2eR );
  local right_hand = vector.new({s2hR[3],s2hR[1],-1*s2hR[2]}) / arm_lenR;

  -- Debug
  --print('F Right hand:',right_hand)

  -- Check if the hand extends beyond a certain point
  if( right_hand[3]>.6 ) then
    return 'up'
  elseif(right_hand[1]<.4) then
    return 'down';
  end

end

function exit()
  print("Boxer ".._NAME.." exit");  
end
