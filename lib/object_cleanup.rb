# BE CAREFUL!!!
# This script deletes objects using an input file to load pids and accession numbers.
# The MARC record that needs to be re-ingested is found and copied and the image and work objects are deleted.
# THE DELETES ARE COMMENTED OUT 
# Make sure to set the config variables.
# To run this script from app root: rails runner -e lib/environment object_cleanup.rb

require 'fileutils'

# Configs
pids_file_path = 'path_to_pid_file'
xml_dir_path = 'path_to_xml_file_dir'
rerun_dir_path = 'path_to_copy_files_to'
log_file = File.new('log_file_path', 'w')
error_file = File.new('error_file_path', 'w')

#For each line in file, get the pid, find the MARC xml file, delete the Fedora objects and Solr
#documents
begin
  File.readlines(pids_file_path).each do |line|
    begin
      
      `mkdir -p #{rerun_dir_path}`
      
      #remove newline
      line.gsub!(/\n/,'')
      
      #trim whitespace
      line.strip!
    
      #tokenize string (it's stored as: pid|accession_nbr)
      line_tokens = line.split("|")
      
      #both tokens are required
      if line_tokens[0].blank? or line_tokens[1].blank?
        raise "Could not tokenize line"
      end
      
      # find MARC XML file that needs to be run again by searching for the accession number in the directory
      # of MARC XML files
      if !line_tokens[1].include? " "
        files = `grep -rl \.cgi\/#{line_tokens[1]} #{xml_dir_path}`
      else
        raise "Could not extract accession nbr|#{line_tokens[1]}"
      end
      
      # if grep returns nothing
      if files.blank?
        raise "Could not find XML file|#{line_tokens[1]}"
      end
       
      files_tokens = files.split("\n")
      
      if files_tokens.size > 1
        raise "More than one XML file|#{line_tokens[1]}"
      elsif files_tokens.size == 1
        #move xml file to re-run directory
        log_file.write("#{files_tokens.first}\n")
        `cp #{files_tokens.first} #{rerun_dir_path}`
      end
      
      # load the Fedora object
      fedora_object = ActiveFedora::Base.find(line_tokens[0], :cast=>:true)
      if fedora_object.is_a? Multiresimage
        #find it's work object and delete
        work = fedora_object.vraworks.first
        log_file.write("delete #{fedora_object.pid}|#{work.pid}\n")
        #work.delete
        #fedora_object.delete
      elsif fedora_object.is_a? Vrawork
        image = fedora_object.multiresimage.first
        log_file.write("delete #{fedora_object.pid}|#{image.pid}\n")
        #image.delete
        #fedora_object.delete
      end
      
    rescue StandardError => s
      error_file.write "StandardError: #{s.message}\n"
  
    rescue Exception => e
      error_file.write "Exception: #{e.message}\n"
    
    end #end exception handling for loop
  end

rescue StandardError => s
  log_file.write("StandardError: #{s.message}\n")
  
rescue Exception => e
  log_file.write("Exception: #{e.message}\n")

ensure
  log_file.close
  error_file.close

end
