# Jmeter distributed reporter
WIP. This was mostly a thought experiment around processing jmeter load test result data.

I was running large scale distributed jmeter tests using https://github.com/flood-io/ruby-jmeter. Jmeter outputs csv files. So to merge the results of many jmeter workers can push the limits of physical memory when you're talking about billions of requests. The basic strategy here is to reduce each report file into essentially a histogram of latencies. Then you just need to merge them and report based on those much smaller files.