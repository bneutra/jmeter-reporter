require_relative 'reporter'
require 'json'
require 'optparse'
require 'colorize'
require_relative 'ascii_report'
require_relative 'data_util'

def load_raw_data_files(file_paths)
  hashes = []
  file_paths.each do |file_path|
    hashes << Marshal.load(File.read(file_path))
  end
  return hashes
end

# given a list of output files from multiple
# load generators, align them by epoch and
# merge the results into one master result hash.
def merge_raw_data(hashes)
  all_epochs = []
  final_hash = {}
  hashes.each do |this_hash|
    all_epochs += this_hash.keys
  end
  all_epochs = all_epochs.uniq.sort
  all_epochs.each do |epoch|
    labels = []
    total_threads = 0
    hashes.each do |this_hash|
      next unless this_hash[epoch]
      final_hash[epoch] = {} unless final_hash[epoch]
      batch = this_hash[epoch]
      total_threads += batch['ALL']['threads']
      labels = (labels + batch.keys).uniq
      labels.each do |label|
        if final_hash[epoch][label]
          final_hash[epoch][label] = combine_results(
            final_hash[epoch][label], batch[label]
          )
        else
          final_hash[epoch][label] = batch[label]
        end
      end
    end
    final_hash[epoch]['ALL']['threads'] = total_threads
  end
  return final_hash
end

def create_reports(options, file_paths)
  hashes = load_raw_data_files(file_paths)
  intervals_data = merge_raw_data(hashes)
  summary_intervals_report = {}
  intervals = intervals_data.keys.sort
  interval_s = options[:interval_seconds]
  peak_thread_threshold = options[:thread_threshold]
  intervals.each do |interval|
    batch = intervals_data[interval]
    summary_intervals_report[interval] = get_batch_stats(batch, interval_s)
  end

  peak_data, runtime = get_peak_result_set(intervals_data,
                                  peak_thread_threshold,
                                  interval_s)
  summary_peak_report = get_batch_stats(peak_data, runtime)
  # print peak period summary to stdout
  threads = peak_data['ALL']['threads']
  samples = peak_data['ALL']['requests']
  table_header(runtime, samples, threads)
  table_summary(summary_peak_report)

  if options[:output_summary_data]
    # save summary data to disk (for use in reports)
    open('intervals_summary.json', 'w').puts(summary_intervals_report.to_json)
    open('peak_summary.json', 'w').puts(summary_peak_report.to_json)
    puts "intervals_summary.json and peak_summary.json have been saved to disk."
  end

  return intervals_data, peak_data

end


if __FILE__ == $0
  options = {
    :interval_seconds => 60,
    :thread_threshold => 0,
    :output_summary_data => false
  }
  OptionParser.new do |opts|
    opts.banner = 'Usage: <script> [options] marshal_data_files'
    msg = 'threshold in worker threads for peak period start.'
    opts.on('-t', '--thread-threshold 0', msg) do |t|
      options[:thread_threshold] = t.to_i
    end
    msg = 'interval window of samples in seconds.'
    opts.on('-i', '--interval-seconds 60', msg) do |t|
      options[:interval_seconds] = t.to_i
    end
    msg = 'Output summary data to json files.'
    opts.on('-s', '--output-summary-data', msg) do |s|
      options[:output_summary_data] = s
    end
    opts.on( '-h', '--help', 'Display this screen' ) do
     puts opts
     puts 'current options:'
     puts "#{options}"
     exit
   end
  end.parse!

  raise('use --help to see valid options') unless ARGV.length > 0
  file_paths = ARGV
  create_reports(options, file_paths)
end
