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

  def test_merge_hashes
    testhash = {
      1469135160=>
        {"ALL"=>
          {"errors"=>0,
          "http_code_distribution"=>{"200"=>2},
          "latency_distribution"=>{100=>1, 111=>1},
          "latency_sum"=>211,
          "requests"=>2,
          "start_ts"=>1469135160,
          "end_ts"=>1469135170,
          "threads"=>8}},
      1469135170=>
        {"ALL"=>
          {"errors"=>0,
          "http_code_distribution"=>{"200"=>3},
          "latency_distribution"=>{95=>1, 89=>1, 16=>1},
          "latency_sum"=>200,
          "requests"=>3,
          "start_ts"=>1469135170,
          "end_ts"=>1469135180,
          "threads"=>10}},
      1469135180=>
        {"ALL"=>
          {"errors"=>0,
          "http_code_distribution"=>{"200"=>3},
          "latency_distribution"=>{64=>1, 15=>1, 102=>1},
          "latency_sum"=>181,
          "requests"=>3,
          "start_ts"=>1469135180,
          "end_ts"=>1469135190,
          "threads"=>10}},
      1469135190=>
        {"ALL"=>
          {"errors"=>1,
          "http_code_distribution"=>{"200"=>2, "500"=>1},
          "latency_distribution"=>{71=>1, 118=>1},
          "latency_sum"=>188,
          "requests"=>3,
          "start_ts"=>1469135190,
          "end_ts"=>1469135200,
          "threads"=>10}},
      1469135200=>
        {"ALL"=>
          {"errors"=>0,
          "http_code_distribution"=>{"200"=>1},
          "latency_distribution"=>{106=>1},
          "latency_sum"=>106,
          "requests"=>1,
          "start_ts"=>1469135210,
          "end_ts"=>1469135220,
          "threads"=>7}
        }
      }
      merged = merge_raw_data([testhash, testhash])
      # all epochs should be there
      assert_equal(merged.keys, [1469135160, 1469135170, 1469135180 ,1469135190, 1469135200])
      # check one epoch for correctness
      epoch = merged[1469135190]['ALL']
      expected_merged_epoch = 
        {"errors"=>2,
        "http_code_distribution"=>{"200"=>4, "500"=>2},
        "latency_distribution"=>{71=>2, 118=>2},
        "latency_sum"=>376,
        "requests"=>6,
        "threads"=>20}
      diff = HashDiff.diff(epoch, expected_merged_epoch)
      assert(diff == {}, "combined epoch was not as expected: #{diff}")
    end
    
end
