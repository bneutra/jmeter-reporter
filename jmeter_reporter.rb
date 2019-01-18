require 'csv'
require_relative 'reporter'
require 'json'
require 'optparse'

def options_parser
  options = {
    :interval_seconds => 60,
    :thread_threshold => 0,
    :output_full_data => false,
    :output_summary_data => false
  }
  OptionParser.new do |opts|
    opts.banner = 'Usage: jmeter_reporter.rb [options] jmeter_csv_file'
    msg = 'threshold in worker threads for peak period start.'
    opts.on('-t', '--thread-threshold 0', msg) do |t|
      options[:thread_threshold] = t.to_i
    end
    msg = 'interval window of samples in seconds.'
    opts.on('-i', '--interval-seconds 60', msg) do |t|
      options[:interval_seconds] = t.to_i
    end
    msg = 'Output raw data a to marshal file.'
    opts.on('-f', '--output-full-data', msg) do |f|
      options[:output_full_data] = f
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
  file_path = ARGV[0]
  return file_path, options
end

# Analyzes a standard jmeter csv/jtl file.
class JmeterReporter < CsvReporter

  # extract csv data from the jmeter jtl/csv file line, per ruby-jmeter
  # returns an array with the extracted values
  # [timestamp, label, latency_ms, error?, num_threads, http_code]
  def extract_line_metrics(ln)
    # Note: we don't bother counting request or response bytes as we
    # would expect errors before expected sizes were to vary.
    ln_array  = ln.parse_csv
    return unless ln_array[0] =~ /\d+/
    epoch_seconds = ln_array[0].to_i / 1000
    # the field is elapsed (time to last byte received)
    latency = ln_array[1].to_i
    label = ln_array[2].tr(' ', '_')
    http_code = ln_array[3]

    # example: "jp@gc - Stepping Thread Group 1-1"
    # we just want the thread group first integer
    group = ln_array[5].sub(/\D+/, '').sub(/-\d+/, '').to_i

    # boolean will be 'false' for either a 4xx, 5xx or a
    # user defined assertion error.
    error = 0
    error = 1 if ln_array[7] == 'false'
    label = group.to_s + '-' + label if group.to_i > 1
    threads = ln_array[10].to_i
    return [epoch_seconds, label, latency, error, threads, http_code]
  end
end

if __FILE__ == $0
  file_path, options = options_parser
  JmeterReporter.new(file_path, options).parse_log
end
