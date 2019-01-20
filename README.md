# Jmeter distributed reporter
WIP. This was mostly a thought experiment around processing jmeter load test result data. TODO: The code is functional. I took a break from it and never got around to doing the nice bits: i.e. creating some nice html reports using flot or google's chart api's.

I was running large scale distributed jmeter tests using https://github.com/flood-io/ruby-jmeter. Jmeter outputs csv files. So to merge the results of many jmeter workers in a single thread is slow and can push the limits of physical memory when you're talking about billions of requests. The basic strategy here is to reduce each report file into essentially a histogram of latencies. Then you just need to merge them and report based on those much smaller files.

Examples:

Output a report from a single jmeter csv file. Report stats for the peak period (where threads were at or above 10):
```
$ ruby jmeter_reporter.rb example.jtl -t 10
[SUMMARY] runtime: 120s samples: 372 threads: 10
+--------------+-----+---------------+------+--------+------+------+------+
| label        | tps | error_percent | mean | median | 75th | 95th | 99th |
+--------------+-----+---------------+------+--------+------+------+------+
| confirm_user | 1.3 | 0.0           | 37.0 | 32     | 54   | 101  | 121  |
| create_user  | 1.3 | 0.0           | 86.0 | 89     | 105  | 177  | 289  |
| login        | 0.3 | 0.0           | 84.0 | 88     | 102  | 174  | 180  |
| user_info    | 0.2 | 100.0         |      |        |      |      |      |
| ALL          | 3.1 | 7.796         | 63.0 | 54     | 95   | 131  | 244  |
+--------------+-----+---------------+------+--------+------+------+------+
```

Process the same jmeter, but output a intermediate binary/marshal file. The output file represents the intervals of histogram data (i.e. each 60 second (default) window of time with a hash representing all the data collected in that time period)
```
$ ruby jmeter_reporter.rb example.jtl -f
```

Process the merged output of 2 intermediate binary files, from the previous output. note: I just give it the same file twice for expediency. This script is essentially merging the data from two different jmeter output files,  aligning them by the time windows, then outputting the overall results (notice how we increase threshold of threads we want to report on to 20 threads, since this scenario has to jmeter workers that each peaked at 10 threads).
```
$ ruby merged_data_reporter.rb intervals.marshal intervals.marshal -t 20
[SUMMARY] runtime: 120s samples: 744 threads: 20
+--------------+-----+---------------+------+--------+------+------+------+
| label        | tps | error_percent | mean | median | 75th | 95th | 99th |
+--------------+-----+---------------+------+--------+------+------+------+
| confirm_user | 2.6 | 0.0           | 37.0 | 32     | 54   | 101  | 121  |
| create_user  | 2.6 | 0.0           | 86.0 | 89     | 105  | 177  | 289  |
| login        | 0.5 | 0.0           | 84.0 | 88     | 102  | 174  | 180  |
| user_info    | 0.5 | 100.0         |      |        |      |      |      |
| ALL          | 6.2 | 7.796         | 63.0 | 54     | 95   | 131  | 244  |
+--------------+-----+---------------+------+--------+------+------+------+
```

Output json files suitable for generating charts (e.g. flot, google charts):
```
$ ruby merged_data_reporter.rb intervals.marshal intervals.marshal -t 20 -s
intervals_summary.json and peak_summary.json have been saved to disk.
```