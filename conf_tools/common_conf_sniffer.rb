require 'json'
require 'open3'

##
# Will calculate the common configurations that exists in json files.
# sniffer_config.json
class CommonConfSniffer
  CONF_PATH = 'C:/dev/_conf/'.freeze
  @common_conf_files = []

  def initialize
    # TODO: selective pull
    pull_all_script = "#{CONF_PATH}pull.rb".freeze
    clone_all_script = "#{CONF_PATH}clone.bat".freeze

    # Pull all the latest files in the repo.
    #run_command_script(pull_all_script)

    # Clone all the latest repos if there are any.
    # run_command_script(clone_all_script)
  end

  # Find the folder that we need to compare
  def fetch_common_conf
    folders = fetch_whitelist_from_configuration
    folders.each do |client_conf|
      calculate_common_conf_files(Dir.glob("../#{client_conf}**/*.json"))
    end

    compare_common_files(folders)
  end

  private

  # The json (in a folder) of a file will be intersected with the next,
  # the result of that intersection will be compared with the next etc.
  # To summerise, json = json & (next_item)
  # @param folders : The entire list of folders to iterate through.
  def compare_common_files(folders)
    @common_conf_files.each do |common_conf_name|
      common_json = fetch_common_json(common_conf_name, folders)
      # Print common file with json here.
      output_common_json(common_json, common_conf_name)
    end
  end

  # Fetches the common json files.
  # @param common conf name
  # @param folders : the entire list of folders to iterate through.
  # @return common json
  def fetch_common_json(common_conf_name, folders)
    common_json = {}
    folders.each_with_index do |client_conf_folder, index|
      next_conf_folder = folders.to_a[index + 1].nil? ? 0 : folders.to_a[index + 1]
      puts "for file : #{common_conf_name} : client : #{client_conf_folder}"
      common_json = compare_and_intersect(client_conf_folder, next_conf_folder, common_conf_name, common_json)
    end

    return common_json
  end

  # Compares and intersects.
  # @param : A directory containing config files, will be compared with
  # @param : a second directory containing conf.
  # @return : the result of the intersection.
  def compare_and_intersect(conf_folder_a, conf_folder_b, conf_name, common_json)
    Dir.glob("../#{conf_folder_a}**/#{conf_name}").each do |config_file|
      Dir.glob("../#{conf_folder_b}**/#{conf_name}").each do |next_config_file|
        json_file = sanitise_json(config_file)
        next_json_file = sanitise_json(next_config_file)
        common_json = fetch_intersection(common_json.empty? ? json_file : common_json, next_json_file)
      end
    end

    return common_json
  end

  # Creates a directory, named common_json one level up, that contains the common json.
  # @param : The common conf json to be written to applicable file.
  # @param : The applicable file.
  def output_common_json(common_conf, common_conf_file)
    output = 'common_json'.freeze
    Dir.mkdir(output) unless Dir.exist?(output)
    File.open("#{output}/#{common_conf_file}", 'w') { |f| f.write(JSON.pretty_generate(common_conf)) }
  end

  # Does an intersection to determine the common files existing in all the conf folders
  # @param : A list of all the client folder to be compared.
  def calculate_common_conf_files(conf_dir)
    conf_files = []

    # Get the actual name of the config file.
    conf_dir.each do |element|
      arr = element.split("/")
      conf_file_name = arr[arr.length - 1]
      conf_files.push(conf_file_name)
    end

    # Do an intersection to determine which files exists in all of the client folders
    @common_conf_files = @common_conf_files.nil? ? conf_files : conf_files & @common_conf_files
  end

  # Returns a list of searchable paths.
  # If a common_conf.json file exists. It will use paths specified in the 'whitelist' array.
  # Whatever is specified in the "blacklist" will be ignored at all times.
  # Example of the structure : "whitelist" : ["bcm-prod/", "bcmasset-prod/"].
  # If none specified or the file does not exist, include all folders.
  def fetch_whitelist_from_configuration
    conf_file = 'sniffer_config.json'.freeze
    if File.file?(conf_file)
      common_conf_sniffer_conf = JSON.parse(File.read(conf_file))
      searchable_folders = common_conf_sniffer_conf['whitelist'] - common_conf_sniffer_conf['blacklist']
      whitelist = F! searchable_folders.empty? ? searchable_folders : Dir.glob('../*/')
      return whitelist
    end

    puts "No sniffer config found, Missing file, sniffer_conf.json"
    return Dir.glob('../*/')
  end

  # Does the intersection based on the type Array or JSON
  # @param : A json object to be compared and intersected.
  # @param : A json object to be compared and intersected.
  def fetch_intersection(json_a, json_b)
    return json_b.kind_of?(Array) ? json_a & json_b : json_a.intersection(json_b)
  end

  # Runs and outputs a windows command.
  # @param : the windows command line script to be run.
  def run_command_script(command)
    Open3.popen2e("ruby #{command}") do |stdin, stdout_err|
      while line = stdout_err.gets
        puts line
      end
    end
  end

  # Cleans up json files and checks if valid. The script will exit with an error if incorrect.
  def sanitise_json(client_conf_right)
    begin
      file_right = JSON.parse(File.read(client_conf_right))
      file_right = file_right[0] if (file_right.length <= 1) && (file_right.kind_of?(Array))
      return file_right
    end
  rescue JSON::ParserError => error
    puts "Error parsing json in conf, Fix invalid json and run the script again. #{client_conf_right} : See #{error}"
    exit (1)
  end
end

# An extention of the hash object.
class Hash
  # To intersect a hash (self) with another hash
  # @param : The hash to be intersected with.
  def intersection(another_hash)
    intersection = {}
    keys_intersection = self.keys & another_hash.keys
    merged = self.dup.merge!(another_hash)
    keys_intersection.each do |k|
      # Check if type has changed
      if merged[k].kind_of? Hash
        intersection[k] = (self[k].kind_of? Hash) ? self[k].intersection(merged[k]) : (puts "has changed : #{merged[k]} and \n #{self[k]} \n}")
      elsif (merged[k].kind_of? Array) && (self[k].kind_of? Array)
        # TODO: Need to to iterate and recurse.
        intersection[k] = (merged[k][0].kind_of? Hash) && (self[k][0].kind_of? Hash) ? hash_array_intersection(k, merged) : merged[k] & self[k]
        intersection.delete(k) if intersection[k].empty?
      else
        intersection[k] = merged[k] if self[k] == another_hash[k]
      end
    end
    return intersection
  end

  private

  # converts all hash objects in an array to string,
  # does an intersection
  # then converts all of them back to hash objects
  # @param : key
  # @param : array containing hash objects
  def hash_array_intersection(k, merged)
    merged_str = merged[k].map(&:to_s)
    _self_str = self[k].map(&:to_s)
    intersection_str_arr = merged_str & _self_str
    return intersection_str_arr.map { |a| eval(a) }
  end

  # Cleans up json files and checks if valid. The script will exit with an error if incorrect.
  def sanitise_json(client_conf_right)
    begin
      file_right = JSON.parse(File.read(client_conf_right))
      file_right = file_right[0] if (file_right.length <= 1) && (file_right.kind_of?(Array))
      return file_right
    end
  rescue JSON::ParserError => error
    puts "Error parsing json in conf, Fix invalid json and run the script again. #{client_conf_right} : See #{error}"
    exit (1)
  end
end

if __FILE__ == $PROGRAM_NAME
  if ((ARGV[0] == "--help") ||(ARGV[0] == "-h"))
    puts "Lorem ipsum dolar sit amet amon shita a shiz toz prook la dosh pookah"
  elsif !ARGV[0].nil?
    puts "Please use --help or -h for help. To run the script, dont add any arguments."
  else
      CommonConfSniffer.new.fetch_common_conf
  end
end