
# Returns: a list of 5 integers, [median, 75th, 95th, 99th, max]
# representing the latency distribution.
def get_percentiles(distro, samples)
  # Some details on how we store and calculate percentiles...
  # The brute-force approach would be to save all our latency samples in
  # memory. In a large sample set, that could be GB's of memory.
  # So, instead, we use a histogram where each possible latency value
  # has its own counter/bin.
  # At any samples size, the work involves iterating through a hash
  # no larger than the number of unique millisecond latency values.
  #
  # Assume that latency only has 10 possible values (0ms-9ms)
  # the distribution input data might look like:
  #               #
  #           # # #
  #         # # # # #
  #       # # # # # #
  #       2 3 4 6 7 9
  #
  # (the Y axis is the counter value and the X axis is millisecond value)
  # Knowing the expected number of samples, we walk through the distribution
  # finding each percentile (and we grab the max while we're at it)
  #
  # Args:
  #   - samples, integer, sample size
  #   - distro, hash of integers, where the key represents a latency in ms.
  # Returns: an array of integers [median, 75th, 95th, 99th, max]

  thresholds = [
    0.50 * samples, # median
    0.75 * samples, # 75th percentile
    0.95 * samples, # 95th percentile
    0.99 * samples  # 99th percentile
  ]
  stats = []

  # request_counter is the running counter of how many requests we've
  # counted, which figures into our percentile calculation.
  request_counter = 0
  max = nil
  keys = distro.keys.sort
  keys.each do |key|
    val = distro[key]
    next if val.zero?
    request_counter += val
    max = key # the last no-zero entry will be our max

    # it is possible that more than one percentile is represented
    # here, thus the while loop!
    while thresholds.length > 0
      # as each new threshold is reached, we record the key
      # at which that threshold was crossed, which is the millisecond
      # value, in other words: the given percentile value.
      if request_counter >= thresholds[0]
        stats << key
        thresholds.shift
      else
        break
      end
    end
  end
  stats << max
end
