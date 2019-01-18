require 'test/unit'
require_relative '../merged_data_reporter'
require 'hash_diff'
require 'json'

SAVE_TEST_DATA = false
$base_dir = File.expand_path(File.dirname(__FILE__))


class TC_MyTest < Test::Unit::TestCase

  # basic test with some diverse sample data to ensure that
  # things like percentile calculations and handling errors
  # are still working.
  def test_sample_input
    options = {
      :interval_seconds => 10,
      :thread_threshold => 20
    }
    Dir.chdir('/tmp')
    # just uses the same file twice.
    file_paths = [$base_dir + '/intervals.marshal.expected', $base_dir + '/intervals.marshal.expected']
    intervals_hash, peak_hash = create_reports(options, file_paths)
    if SAVE_TEST_DATA
      # save raw data to disk
      File.write('/tmp/intervals.marshal', Marshal.dump(intervals_hash))
      File.write('/tmp/peak.marshal', Marshal.dump(peak_hash))
      return
    end

    ihash = Marshal.load(File.read($base_dir + '/merged_intervals.marshal.expected'))
    diff = HashDiff.diff(intervals_hash, ihash)
    assert(diff == {}, "intervals.marshal.expected did not match: #{diff}")

    phash = Marshal.load(File.read($base_dir + '/merged_peak.marshal.expected'))
    diff = HashDiff.diff(peak_hash, phash)
    assert(diff == {}, "peak.marshal.expected did not match: #{diff}")
  end

end
