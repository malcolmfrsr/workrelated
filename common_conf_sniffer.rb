require 'json'
require 'open3'

class CommonConfSniffer

  CONF_PATH = "C:/dev/_conf/".freeze

  @common_conf_files

  def initialize
  end

  def fetch_common_conf
    pull_all_script = "#{CONF_PATH}pull.rb".freeze
    clone_all_script = "#{CONF_PATH}clone.bat".freeze

    # Pull all the conf, and output to a stream.
    #run_command_script(pull_all_script)

    # Clone all the conf, and output to a stream.
    # run_command_script(clone_all_script)

    # Inside the conf repo.
    folders = Dir.glob("*/") &  fetch_whitelist_configuration['whitelist']
    folders.each do |client_conf|
      calculate_common_conf_files(Dir.glob("#{client_conf}**/*.json"))
    end
    compare_common_files(folders)
  end

  private
  def compare_common_files(folders)
    @common_conf_files.each do |common_conf_name|
      common_json = {}
      folders.each_with_index do |client_conf_folder, index|
        next_conf_folder = folders.to_a[index+1].nil? ? 0 : folders.to_a[index+1]
        puts "for file : #{common_conf_name} : client : #{client_conf_folder}"
        # Don't compare files if it exists in the same directory.
        Dir.glob("#{client_conf_folder}**/#{common_conf_name}").each do |config_file|
          #puts "Compare : #{common_json.empty? ? config_file : "last intersection at #{common_json}"}"
          # Don't compare files if it exists in the same directory.
          Dir.glob("#{next_conf_folder}**/#{common_conf_name}").each do |next_config_file|
            # puts "with : #{next_config_file}"
            # Some json clean up.
            json_file = sanitise_json(config_file)
            next_json_file = sanitise_json(next_config_file)
            common_json = fetch_intersection(common_json.empty? ? json_file : common_json, next_json_file)
          end
        end
      end
      # Print common file with json here.
      output_common_json(common_json, common_conf_name)
    end
  end

  def output_common_json(common_conf, common_conf_file)
    output = "../common_json"
    Dir.mkdir(output) unless Dir.exists?(output)

    File.open("#{output}/#{common_conf_file}", "w") { |f| f.write(JSON.pretty_generate(common_conf)) }
  end

  # Does an intersection to determine the common files existing in all the conf folders
  def calculate_common_conf_files(conf_dir)
    conf_files = []

    # Get the actual name of the config file.
    conf_dir.each do |element|
      arr = element.split("/")
      conf_file_name = arr[arr.length - 1]
      conf_files.push(conf_file_name)
    end

    if (@common_conf_files.nil?)
      @common_conf_files = conf_files
    else
      @common_conf_files = conf_files & @common_conf_files
    end
  end

  def fetch_whitelist_configuration
    # do a check first to see if the file exists if not, it will go through all.
    return JSON.parse(File.read("common_conf.json".freeze))
  end

  def fetch_intersection(file_left, file_right)
    # Array intersection
    if (file_right.kind_of?(Array))
      intersection = file_left & file_right
    else
      intersection = file_left.intersection(file_right)
    end

    return intersection
  end

  def run_command_script(pull_all_script)
    Open3.popen3("ruby #{pull_all_script}") do |stdout, stderr, status, thread|
      stderr.each { |line|
        puts line }
    end
  end

  def sanitise_json(client_conf_right)
    begin
      file_right = JSON.parse(File.read(client_conf_right))
      if (file_right.kind_of?(Array))
        if (file_right.length <= 1)
          file_right = file_right[0]
        end
      end
      return file_right
    end
  rescue JSON::ParserError => error
    puts "Error parsing json in conf, Fix invalid json and run the script again. #{client_conf_right} : See #{error}"
    exit(1)
  end
end

class Hash
  def intersection(another_hash)
    keys_intersection = self.keys & another_hash.keys
    merged = self.dup.merge!(another_hash)
    intersection = {}
    keys_intersection.each do |k|

      # puts "Value at intersecting key #{k}"
      if merged[k].kind_of? Hash
        if self[k].kind_of? Hash
          intersection[k] = self[k].intersection(merged[k])
        else
          puts "has changed : #{merged[k]} and \n #{self[k]} \n}"
        end
      elsif (merged[k].kind_of? Array) && (self[k].kind_of? Array)
        # To Do : need a better way to check if all objects re a hash.
        if (merged[k][0].kind_of? Hash) && (self[k][0].kind_of? Hash)
          merged_str = merged[k].map(&:to_s)
          _self_str = self[k].map(&:to_s)
          intersection_str_arr = merged_str & _self_str
          intersection[k] = intersection_str_arr.map { |a| eval(a) }
        else
          intersection[k] = merged[k] & self[k]
        end
        intersection.delete(k) if intersection[k].empty?
      else
        intersection[k] = merged[k] if self[k] == another_hash[k]
      end
    end
    return intersection
  end

  def sanitise_json(json)
    begin
      if (json.kind_of?(Array))
        if (json.length <= 1)
          json = json[0]
        end
      end
      return json
    end
  rescue JSON::ParserError => error
    puts "Error parsing json in conf, Fix invalid json and run the script again. #{client_conf_right} : See #{error}"
    exit(1)
  end
end

if __FILE__ == $PROGRAM_NAME
  CommonConfSniffer.new.fetch_common_conf
end