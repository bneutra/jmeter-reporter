require 'colorize'
require 'terminal-table'

def table_header(runtime, samples, threads)
  puts "[SUMMARY] runtime: #{runtime}s samples: #{samples} threads: #{threads}".yellow
end

# prints a pretty ascii table showing summary results for
# an interval of a load test containing metrics for one or
# more class of requests (labels). See util.get_batch_stats.
def table_summary(summary_hash)
  header = [
    'label', 'tps', 'error_percent', 'mean', 'median', '75th', '95th', '99th'
  ]
  data_rows = []
  labels = summary_hash.keys
  labels.delete('ALL')
  labels << 'ALL'
  labels.each do |label|
    row = []
    header.each do |key|
      if key == 'error_percent'
        error_perc = summary_hash[label][key]
        error_perc = error_perc.to_s.red if error_perc > 0
        row << error_perc
      elsif key == 'label'
        final_label = label
        final_label = label.green if label == 'ALL'
        row << final_label
      else
        row << summary_hash[label][key]
      end
    end
    data_rows << row
  end
  puts Terminal::Table.new headings: header, rows: data_rows
  return data_rows
end


