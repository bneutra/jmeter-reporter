# Jmeter distributed reporter
Here you have some ruby scripts to parallelize the processing of jmeter .csv files. The code is functional. I never got around to doing the nice bits: i.e. adding more tests, creating some nice html reports using flot or google's chart api's.

I was running large scale distributed jmeter tests using https://github.com/flood-io/ruby-jmeter. Jmeter outputs .csv files. So to merge the results of many jmeter workers in a single thread is slow and can push the limits of physical memory when you're talking about billions of requests. The basic strategy here is to reduce each report file into essentially a histogram of latencies. Then you just need to merge them and report based on those much smaller files.

## Examples:

Output a report from a single jmeter .csv file. Report stats for the peak period (where threads were at or above 10):
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
Output intervals.marshal and peak.marshal binary files
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

## More detail on the code

reporter.rb does the work of parsing the .csv file. The initialization function below gives you a picture of the key data structure (which captures result metrics). This data is organized in a larger hash keyed by interval window (e.g. 60 seconds) and request type (e.g. a /login http request) . The key optimization is in storing latencies as a distribution/histogram. This is what allows this code to preserve the fidelity of the statistics while serializing all the work we did (counting all the data points of a huge file).
```
def get_batch_hash(start_ts, end_ts)
return {
    'errors' => 0,
    'http_code_distribution' => Hash.new(0),
    'latency_distribution' => Hash.new(0),
    'latency_sum' => 0,
    'requests' => 0,
    'start_ts' => start_ts,
    'end_ts' => end_ts,
    'threads' => nil
}
end
  ```

The final report includes statistical information on the "peak" period of load. This is predicated on the idea that *most* load tests concern themselves with the ability of the system to sustain a certain amount of load for a certain amount of time. These tests also usually involve a ramp up and ramp down period. So, the scripts allow you to filter out the ramp up and ramp down if you provide the script n active "thread threshold". See: data_util:get_peak_period_by_threads. The peak period statistics are compiled by combining the data from all the peak intervals. See: data_util:get_peak_result_set. An ascii "peak" report or a .json output is provided.

The report provides the same detailed statistical data for each interval in a .json output report file. This is suitable for charting the load tests results to help you visualize, for example, exactly when a system started performing poorly.

The merging of multiple jmeter report files is just that: it's a process of combining the contents of the hashes, preserving the intervals across the report files. It assumes you report files actually come from the same time period! Once data is merged, the new data structure looks exactly like the data from a single test and reports can be generated using the same functions described above.
