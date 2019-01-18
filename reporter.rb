
require 'json'
require 'csv'
require_relative 'ascii_report'
require_relative 'stats_util'
require_relative 'data_util'


# processes request metrics collected from many requests
# The "batch" object has various counters including a latency histogram
# for each class of http request found in the log.
# returns a hash of list of lists, each row:
# label, tps, %error,  mean, median, 75th, 95th, 99th, max, requests, errors
# where the hash keys are the request labels (categories)
def get_batch_stats(batch, interval_s)
  summary_stats = {}
  labels = batch.keys.sort
  labels.each do |label|
    value = batch[label]
    latency_distribution = value['latency_distribution']
    http_code_distribution = value['http_code_distribution']
    latency_sum = value['latency_sum']
    requests = value['requests']
    errors = value['errors']
    threads = value['threads']
    good_requests = requests - errors
    stats = get_percentiles(latency_distribution, good_requests)
    summary_stats[label] = {
      'interval_s' => interval_s,
      'tps' => (requests / interval_s.to_f).round(1),
      'error_percent' => ((errors / requests.to_f) * 100).round(3),
      'mean' => good_requests > 0 ? (latency_sum / good_requests).round(1) : nil,
      'median' => stats[0],
      '75th' => stats[1],
      '95th' => stats[2],
      '99th' => stats[3],
      'max' => stats[4],
      'requests' => requests,
      'threads' => threads,
      'http_code_distribution' => http_code_distribution,
      'errors' => errors
    }
  end
  return summary_stats
end


# Base class for analyzing a load test csv file.
class CsvReporter
  def initialize(file_path, options)
    @file_path = file_path
    puts options
    @peak_thread_threshold = options[:thread_threshold]
    @output_full_data = options[:output_full_data]
    @output_summary_data = options[:output_summary_data]
    @interval_s = options[:interval_seconds]
    @intervals_data = {} # summary data for each interval of the entire test
  end

  # Your subclass must define this method.
  # Given a line in a load test results csv file, this method should parse
  # the line, determine whether the request was an error or not and return
  # an array e,g,:
  # return [epoch_seconds, label, latency_ms, error, threads, http_code]
  #
  # epoch_seconds, int: the requests time stamp in seconds epoch time
  # label, string: a label identifiying the request e.g. '/login'
  # latency_ms, int: response latency in milliseconds
  # error, bool: whether or not the requests should be counted as an error
  # threads, int: active threads/workers in load tester runtime
  # http_code, string: http code returned
  #
  # See the JmeterReporter sublcass as an example
  def extract_line_metrics(ln)
    raise('Subclass must define extract_line_metrics method')
  end

  # record metrics from a single request (modifies batch hash inline)
  # increments the 'ALL' label for your convenience.
  def set_metrics(metrics, batch)
    _this_ts, label, latency, error, threads, http_code = metrics
    ['ALL', label].each do |key|
      # load test worker threads are recorded at the start of the interval
      batch[key]['threads'] = threads unless batch[key]['threads']
      batch[key]['requests'] += 1
      batch[key]['errors'] += error
      batch[key]['http_code_distribution'][http_code] += 1
      # latency samples are not counted for failed requests
      unless error == 1
        batch[key]['latency_distribution'][latency] += 1
        batch[key]['latency_sum'] += latency
      end
    end
  end

  # inits and returns a hash used for storing metrics for a given interval
  # and a given 'label' or class of load test request
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

  def create_reports
    summary_intervals_report = {}
    intervals = @intervals_data.keys.sort
    intervals.each do |interval|
      batch = @intervals_data[interval]
      summary_intervals_report[interval] = get_batch_stats(batch, @interval_s)
    end
    if @output_full_data
      # save raw data to disk
      open('intervals.marshal', 'w').puts(Marshal.dump(@intervals_data))
      open('peak.marshal', 'w').puts(Marshal.dump(peak_data))
      return
    end

    peak_data, runtime = get_peak_result_set(@intervals_data, @peak_thread_threshold, @interval_s)
    summary_peak_report = get_batch_stats(peak_data, runtime)
    # print peak period summary to stdout
    samples = peak_data['ALL']['requests']
    table_header(runtime, samples, @peak_thread_threshold)
    table_summary(summary_peak_report)
    if @output_summary_data
      # save summary data to disk (for use in reports)
      open('intervals_summary.json', 'w').puts(summary_intervals_report.to_json)
      open('peak_summary.json', 'w').puts(summary_peak_report.to_json)
    end
    return peak_data
  end

  # Parse and analyze csv load test result file.
  def parse_log
    # We save data for the current interval, by request type,
    # as well as all requests ('ALL')
    # Data is recorded for each interval, as well as for the
    # entire period of 'peak' load

    fl = open(@file_path)
    batch = {}
    interval_start_ts = nil
    interval_end_ts = nil
    until fl.eof?
      ln = fl.readline
      metrics = extract_line_metrics(ln)
      next unless metrics
      this_ts = metrics[0]
      label = metrics[1]

      # init interval_end_ts on very first line that we see but
      # align it in epoch time, to make alignment with
      # data from other load generator nodes easy
      unless interval_end_ts
        interval_start_ts = this_ts - this_ts.modulo(@interval_s)
        interval_end_ts = interval_start_ts + @interval_s
      end

     # initialize results object
      unless batch.key?(label)
        # init the batch for this time window
        batch[label] = get_batch_hash(interval_start_ts, interval_end_ts)
        unless batch.key?('ALL')
          # init the batch for all requests in this window
          batch['ALL'] = get_batch_hash(interval_start_ts, interval_end_ts)
        end
      end
      # record this request to @intervals_data
      set_metrics(metrics, batch)

      if this_ts >= interval_end_ts || fl.eof
        # intervals are keyed by the epoch time at the start of the interval
        @intervals_data[interval_start_ts] = batch
        # set the next interval window, init the next batch of data
        interval_start_ts = interval_end_ts
        interval_end_ts += @interval_s
        batch = {}
      end
    end
    peak_data = create_reports
    return @intervals_data, peak_data
  end
end


