require 'test/unit'
require 'hashdiff'
require_relative '../data_util'


$base_dir = File.expand_path(File.dirname(__FILE__))


class TC_MyTest < Test::Unit::TestCase

  def test_merge_add
    h1 = {
      1 => 2,
      3 => 4,
    }
    h2 = {
      1 => 12,
      3 => 14,
      4 => 3,
    }
    expected = {1=>14, 3=>18, 4=>3}
    final = combine_hashes(h1, h2)
    diff = HashDiff.diff(final, expected)
    assert(diff == [], "did not match: #{diff}")
  end

end
