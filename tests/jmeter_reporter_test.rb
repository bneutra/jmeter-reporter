require 'test/unit'
require_relative '../jmeter_reporter'
require 'hash_diff'
require 'json'


$base_dir = File.expand_path(File.dirname(__FILE__))


class TC_MyTest < Test::Unit::TestCase

  # basic test with some diverse sample data to ensure that
  # things like percentile calculations and handling errors
  # are still working.
  def test_sample_input
    options = {
      :interval_seconds => 10,
      :thread_threshold => 10,
      :output_full_data => false,
      :output_summary_data => false
    }
    Dir.chdir('/tmp')
    intervals_hash, peak_hash = JmeterReporter.new($base_dir + '/sample.jtl', options).parse_log

    ihash = Marshal.load(File.read($base_dir + '/intervals.marshal.expected'))
    diff = HashDiff.diff(intervals_hash, ihash)
    assert(diff == {}, "intervals.marshal.expected did not match: #{diff}")

    phash = Marshal.load(File.read($base_dir + '/peak.marshal.expected'))
    diff = HashDiff.diff(peak_hash, phash)
    assert(diff == {}, "peak.marshal.expected did not match: #{diff}")
  end

end
