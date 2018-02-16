require 'json'
require 'open3'

class CommonConfSniffer

  CONF_PATH = "C:/dev/_conf/".freeze

  @common_conf_files
  @common_conf

  def initialize
  end

  def fetch_common_conf
    pull_all_script = "#{CONF_PATH}pull.rb".freeze
    clone_all_script = "#{CONF_PATH}clone.bat".freeze

    # Pull all the conf, and output to a stream.
    run_command_script(pull_all_script)

    # Clone all the conf, and output to a stream.
    run_command_script(clone_all_script)

    # Inside the conf repo.
    folders = Dir.glob("*/")
    folders.each do |client_conf|
      calculate_common_conf_files(Dir.glob("#{client_conf}**/*.json"))
    end
  end

  def run_command_script(pull_all_script)
    Open3.popen3("ruby #{pull_all_script}") do |stdout, stderr, status, thread|
      stdout.each { |line|
        puts line }
    end
  end

  def calculate_common_json(folders)

    folders.each do |client_conf_folder_left|
      # Only compare files that are regarded as common
      @common_conf_files.each do |common_conf_file|
        # Only look for the common files in the client conf folder.
        Dir.glob("#{client_conf_folder_left}**/#{common_conf_file}").each do |client_conf_left|
          puts "\nLeft : #{client_conf_left}"

          # Some json clean up.
          file_left = sanitise_json(client_conf_left)

          folders.each do |client_conf_folder_right|
            # Don't compare files if it exists in the same dfirectory.
            if (client_conf_folder_left != client_conf_folder_right)
              Dir.glob("#{client_conf_folder_right}**/#{common_conf_file}").each do |client_conf_right|
                puts "Right : #{client_conf_right}"

                # Some json clean up.
                file_right = sanitise_json(client_conf_right)

                fetch_intersection(file_left, file_right)
              end
            end
          end
        end
      end
    end
  end

  def fetch_intersection(file_left, file_right)
    # Array inter section
    if (file_right.kind_of?(Array))
      file_left = file_left & file_right
    else
      #Recursive intersection
      file_left.intersection(file_right)
    end

    puts "Common file name : #{file_left}"
  end

  def sanitise_json(client_conf_right)
    file_right = JSON.parse(File.read(client_conf_right))
    if (file_right.kind_of?(Array))
      if (file_right.length <= 1)
        file_right = file_right[0]
      end
    end
    return file_right
  end

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
end

class Hash
  def intersection(another_hash)
    _intersection(another_hash)
  end

  private
  def _intersection(another_hash)
    begin
      keys_intersection = self.keys & another_hash.keys
      merged = self.dup.update(another_hash)

      intersection = {}
      keys_intersection.each do |k|
        if merged[k].kind_of? Hash
          if self[k].kind_of? Hash
            intersection[k] = self[k].intersection(merged[k])
          else
            puts "JSON formatting has changed : #{merged[k]} and \n #{self[k]} \n}"
          end
        else
          intersection[k] = merged[k]
        end
      end
      return intersection
    end
  rescue StandardError => error
    puts "Error : #{error}"
  end
end

if __FILE__ == $PROGRAM_NAME
  CommonConfSniffer.new.fetch_common_conf
end