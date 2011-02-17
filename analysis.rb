require 'ostruct'
require 'base'

significance_by_degrees_of_freedom = []
significance_by_degrees_of_freedom[198] = 1.972

files = `ls output/`.split("\n")
hdtt_all_files = []
(4..8).to_a.each do |i|
  short = "a"
  hdtt_files = files.grep(/^.*#{i}\.txt$/)
  hdtt_files.map! do |file|
    file_data = OpenStruct.new
    file_data.name = file
    
    content = File.read("output/" + file).split("\n")
    data = []
    content.each_with_index do |line, index|
      next unless line.include?("finished")
      d = OpenStruct.new
      if content[index - 1].include?("Evaluations")
        content[index - 1].scan(/^(?:Iterations: \d*), Evaluations: (\d*), Collisions: (\d*), Time: (\d*\.\d*), Diversity: (\d*\.\d*)$/) do |i, c, t, div|
          d.iterations, d.collisions, d.time, d.diversity = [i.to_i, c.to_i, t.to_f, div.to_f]
        end
      else
        content[index - 1].scan(/^Iterations: (\d*), Collisions: (\d*), Time: (\d*\.\d*), Diversity: (\d*\.\d*)$/) do |i, c, t, div|
          d.iterations, d.collisions, d.time, d.diversity = [i.to_i, c.to_i, t.to_f, div.to_f]
        end
      end
      data << d
    end
    
    file_data.time_score = 0
    file_data.collisions_score = 0
    file_data.short = short.dup
    short.succ!
    file_data.samples = content.grep(/finished/).length
    file_data.percentage_finished = content.grep("=== finished").length.to_f / file_data.samples.to_f
    
    file_data.time_expected = data.collect(&:time).mean
    file_data.time_variance = 1 / (data.length - 1).to_f * data.inject(0.0) do |sum, d|
       sum += (d.time.to_f - file_data.time_expected.to_f) ** 2
    end
    
    file_data.collisions_expected = data.collect{|x| x.collisions.to_f}.mean
    file_data.collisions_variance = 1 / (data.length - 1).to_f * data.inject(0.0) do |sum, d|
       sum += (d.collisions.to_f - file_data.collisions_expected.to_f) ** 2
    end
    
    puts file_data.percentage_finished.to_s[0..6] << "\t" << file_data.collisions_expected.to_s[0..6] << "\t" << file_data.collisions_variance.to_s[0..6] << "\t" << file_data.name
    puts file_data.percentage_finished.to_s[0..6] << "\t" << file_data.time_expected.to_s[0..6] << "\t" << file_data.time_variance.to_s[0..6] << "\t" << file_data.name
    file_data
  end
  hdtt_all_files << hdtt_files
  puts ""
end

hdtt_all_files.each do |files|
  files.each do |file1|
    files.each do |file2|
      next if file1 == file2
      raise ArgumentError, "No Significance Value found" if significance_by_degrees_of_freedom[file1.samples + file2.samples - 2].nil?
      
      if file1.time_expected < file2.time_expected # fewer is better (collisions, time, evaluations)
        delta = 1
      elsif file1.time_expected == file2.time_expected
        delta = 0
      else
        delta = -1
      end
      
      s = ((file1.samples - 1) * file1.time_variance + (file2.samples - 1) * file2.time_variance) / (file1.samples + file2.samples - 2).to_f
      t_value = ((file1.time_expected - file2.time_expected).to_f / Math.sqrt(s)) * Math.sqrt((file1.samples * file2.samples).to_f / (file1.samples + file2.samples).to_f)      
      t_value = 0.0 if t_value.nan?
      file1.time_score += delta if t_value.abs > significance_by_degrees_of_freedom[file1.samples + file2.samples - 2]
      
      if file1.collisions_expected < file2.collisions_expected # fewer is better (collisions, time, evaluations)
        delta = 1
      elsif file1.collisions_expected == file2.collisions_expected
        delta = 0
      else
        delta = -1
      end
      
      s = ((file1.samples - 1) * file1.collisions_variance + (file2.samples - 1) * file2.collisions_variance) / (file1.samples + file2.samples - 2).to_f
      t_value = ((file1.collisions_expected - file2.collisions_expected).to_f / Math.sqrt(s)) * Math.sqrt((file1.samples * file2.samples).to_f / (file1.samples + file2.samples).to_f)
      t_value = 0.0 if t_value.nan?
      file1.collisions_score += delta if t_value.abs > significance_by_degrees_of_freedom[file1.samples + file2.samples - 2]
    end
    # puts file1.score.to_s << "\t" << file1.short << " - " << file1.name
  end
  sorted_files = files.sort_by do |file|
    [file.collisions_score, file.time_score]
  end.reverse
  sorted_files.each_index do |i|
    if i == 0
      print sorted_files[i].name.sub(/\d\.txt/, "").gsub(/[a-z]/, "")
      # print sorted_files[i].short
      next
    end
    
    if sorted_files[i].collisions_score == sorted_files[i - 1].collisions_score && sorted_files[i].time_score == sorted_files[i - 1].time_score
      print " = " << sorted_files[i].name.sub(/\d\.txt/, "").gsub(/[a-z]/, "")
      # print " = " << sorted_files[i].short
    else
      print " > " << sorted_files[i].name.sub(/\d\.txt/, "").gsub(/[a-z]/, "")
      # print " > " << sorted_files[i].short
    end
  end
  puts ""
end