require('lcm')
require('lcm_rpc_request_t')

local msg = {
  client_id = "uuid",
  request_id = 456,
  eval_string = "walk.stop",
  synchronous = true
}

rpc_client = lcm.new()
rpc_client:rpc_request_t_publish("EXAMPLE", msg)
