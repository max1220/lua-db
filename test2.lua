local lanes = require("lanes").configure()



local work_linda = lanes.linda()
local worker_function = lanes.gen("*",function(threadnum, maxthreads)
	local time = require("time")
	print(("Thread %d/%d started!"):format(threadnum, maxthreads))
	while true do
		work_linda:receive("")
		print(("Thread %d working..."):format(threadnum))
		time.sleep(10)
	end
end)


local worker_lanes = {}
print("Starting the workers...")
for _=1, #worker_lanes do
	table.insert(worker_lanes, worker_function())
end
