# merges "flat/simple" hashes. Values of the same key
# are added together in the resultant hash.
def combine_hashes(*hashes)
  final_hash = {}
  hashes.each do |this_hash|
    # where matching, add the values.
    final_hash = final_hash.merge(this_hash) {
      |_key, oldval, newval| newval + oldval 
    }
  end
  return final_hash
end

# Combines result sets.  This will combine the distribution
# hashes and sum the simple metric values.
def combine_results(*hashes)
  final_hash = {
    'http_code_distribution' => {},
    'latency_distribution' => {}
  }
  to_add = ['errors', 'latency_sum', 'requests']
  to_combine = ['latency_distribution', 'http_code_distribution']

  to_add.each do |item|
    final_hash[item] = 0
  end

  hashes.each do |this_hash|
    next if this_hash == nil
    to_add.each do |key|
      final_hash[key] += this_hash[key] if this_hash.has_key?(key)
    end
    to_combine.each do |key|
      final_hash[key] = combine_hashes(final_hash[key], this_hash[key])
    end
  end
  return final_hash
end

# determine the starting and ending epoch for the 'peak' period
# of the load test (where the peak thread level was attained)
def get_peak_period_by_threads(intervals_data, thread_threshold)
  intervals = intervals_data.keys.sort
  start_epoch = nil
  last_epoch = nil
  prev_epoch = nil
  intervals.each do |epoch|
    batch = intervals_data[epoch]
    threads = batch['ALL']['threads']
    if threads >= thread_threshold && start_epoch == nil
      start_epoch = epoch
    end
    if start_epoch && threads <= (thread_threshold * 0.75) && last_epoch == nil
      # ramp down detected, omitting this epoch.
      last_epoch = prev_epoch
      break
    end
    prev_epoch = epoch
  end
  last_epoch = prev_epoch if last_epoch == nil
  return start_epoch, last_epoch
end

# combine the interval windows into one long window of peak load
# returns the final result hash and the total runtime.
def get_peak_result_set(intervals_data, thread_threshold, interval_s)
  start_epoch, last_epoch = get_peak_period_by_threads(
    intervals_data, thread_threshold)
  max_threads = 0
  peak_data_batches = []
  labels = []
  intervals = intervals_data.keys.sort
  intervals.each do |epoch|
    batch = intervals_data[epoch]
    labels = (labels + batch.keys).uniq
    if epoch >= start_epoch && epoch <= last_epoch
      peak_data_batches << batch
      threads = batch['ALL']['threads']
      max_threads = threads unless max_threads > threads
    end
  end
  final_result_set = {}
  peak_data_batches.each do |batch|
    labels.each do |label|
      next unless batch[label]
      if final_result_set[label]
        final_result_set[label] = combine_results(
          final_result_set[label], batch[label]
        )
      else
        final_result_set[label] = batch[label]
      end
    end
  end
  final_result_set['ALL']['threads'] = max_threads
  # since the epochs mark the end 
  runtime = last_epoch - start_epoch + interval_s
  return final_result_set, runtime
end
