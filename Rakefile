require 'open-uri'
require 'yaml'

PRE_RELEASE = ENV['PRE_RELEASE'] == 'true'
PTB_VERSION = YAML.load_file('./build_files/version.yaml')

FILESHARE_SERVER = '//guest@int-resources.ops.puppetlabs.net/Resources'

##############################################################
#                                                            #
# Methods to abstract the environment variable CL interface. #
#                                                            #
##############################################################

def pe_family
  if !ENV['PE_VERSION'] || ENV['PE_VERSION'] == 'latest'
    if ENV['PE_FAMILY']
      return ENV['PE_FAMILY']
    elsif !PRE_RELEASE
      return nil
    else
      puts "You must set the PE_VERSION or PE_FAMILY environment variable to build a pre-release version"
      exit 1
    end
  else
    ENV["PE_VERSION"].split('.')[0 .. 1].join('.')
  end
end

def pe_version
  if !ENV['PE_VERSION'] || ENV['PE_VERSION'] == 'latest'
    PRE_RELEASE ? latest_pre_version(pe_family) : latest_release_version
  else
    ENV['PE_VERSION']
  end
end

########################################
#                                      #
# Helper methods for installer caching #
#                                      #             
########################################

# At some point we might modify this method to specify dist, release, and arch
def installer_filename
  if PRE_RELEASE
    "puppet-enterprise-#{pe_version}-el-7-x86_64.tar"
  else
    "puppet-enterprise-#{pe_version}-el-7-x86_64.tar.gz"
  end
end

# Note that because we gzip the pre-release installer, this is always .tar.gz
def cached_installer_path
  "./file_cache/installers/puppet-enterprise-#{pe_version}-el-7-x86_64.tar.gz"
end

# Get the latest pre-release version string for a given PE Version family.
def latest_pre_version(pe_family)
  open("http://getpe.delivery.puppetlabs.net/latest/#{pe_family}").read
end

def latest_release_version
  redirect_response = Net::HTTP.get_response(URI.parse("https://pm.puppetlabs.com/cgi-bin/download.cgi\?dist\=el\&rel\=7\&arch\=x86_64\&ver\=latest"))
    .header['location']
  return redirect_response.match(/(?<version>\d{4}\.\d+\.\d+)/).to_s
end

# Public releases are .tar.gz, while internal releases are just tar.
# When cacheing a pre-release, gzip it.
def pe_installer_url
  if PRE_RELEASE
    "http://enterprise.delivery.puppetlabs.net/#{pe_family}/ci-ready/#{installer_filename}"
  else
    "https://s3.amazonaws.com/pe-builds/released/#{pe_family}/#{installer_filename}"
  end
end

# Check if the installer exists and the file isn't empty.
def already_cached?
  File.exist?(cached_installer_path) and File.zero?(cached_installer_path) == false
end

def gzip_installer
  `gzip ./file_cache/installers/#{installer_filename}`
end

# Download the installer. Curl is nicer than re-inventing the wheel with ruby.
def download_installer
  unless `curl #{pe_installer_url} -o ./file_cache/installers/#{installer_filename}`
    fail "Error downloading the PE installer"
  end
  gzip_installer if PRE_RELEASE
end

def cache_directories
  ["./file_cache/gems", "./file_cache/installers", "./output", "./packer_cache"]
end

def cache_directories_exist?
  cache_directories.each{ |dir| return false unless File.exist?(dir) }
  true
end

def create_cache_directories
  FileUtils.mkdir_p(cache_directories)
end

###################################
#                                 #
# Helper methods for building VMs #
#                                 #             
###################################

def subprocess_trap(io)
  trap('INT') do
    Process.kill('INT', io.pid)
    while (line = io.gets) do
      puts line
    end
    exit
  end
end

def call_packer(template, args={}, var_file=nil)
  arg_string = ""
  args.each do |k, v|
    arg_string << " -var '#{k}=#{v}' "
  end
  arg_string << " -var-file=#{var_file} " if var_file
  # Call packer with a -f flag to remove any existing builds.
  # Pass everything through to STDOUT live and pass SIGINT through
  packer_io = IO.popen("packer build -force #{arg_string} #{template}") do |io|
    subprocess_trap(io)
    while (line = io.gets) do
      puts line
    end
  end
end

def template_dir
  './templates'
end

def template_file(build_type)
  case build_type
  when 'base'
    File.join(template_dir, 'educationbase.json')
  when 'build'
    File.join(template_dir, 'educationbuild.json')
  when 'student'
    File.join(template_dir, 'student.json')
  else
    fail "ERROR: Invalid build type: #{build_type}"
  end
end

def var_file(vm_name)
  if vm_name == "student"
    nil
  else
    File.join(template_dir, "#{vm_name}.json")
  end
end

# This method isn't currently used.
def output_dir(vm_name, build_type)
  unless build_type == 'base'
    File.join('./output/', "#{vm_name}-virtualbox")
  else
    File.join('./output/', "#{vm_name}-base-virtualbox")
  end
end

def packer_args
  {
    'pe_version' => pe_version,
    'ptb_version' => "#{PTB_VERSION[:major]}.#{PTB_VERSION[:minor]}"
  }
end

def build_vm(build_type, vm_name)
  call_packer(template_file(build_type), packer_args, var_file(vm_name))
end

############################################
#                                          #
# Helper methods for Learning VM packaging #
#                                          #             
############################################

def ova_name
  "puppet-#{pe_version}-learning-#{PTB_VERSION[:major]}.#{PTB_VERSION[:minor]}.ova"
end

def make_learning_vm_dir
  `rm -rf /tmp/learning_puppet_vm && mkdir /tmp/learning_puppet_vm`
end

def copy_ova_to_dir
  `cp ./output/#{ova_name} /tmp/learning_puppet_vm/#{ova_name}`
end

def strip_version_include(string)
  string.split("\n")[1..-1].join("\n")
end

def troubleshooting_string
  open('https://raw.githubusercontent.com/puppetlabs/puppet-quest-guide/master/troubleshooting.md')
    .read
end

def setup_string
  open('https://raw.githubusercontent.com/puppetlabs/puppet-quest-guide/master/SETUP.md')
    .read
end

def readme_markdown
  strip_version_include(setup_string) + "\n" + strip_version_include(troubleshooting_string)
end

def readme_rtf
  PandocRuby.new(readme_markdown, :standalone).to_rtf
end

def write_readme
  File.write('/tmp/learning_puppet_vm/readme.rtf', readme_rtf)
end

def learning_vm_archive_path
  './output/learning_puppet_vm.zip'
end

def zip_learning_vm
  puts "Compressing Learning VM..."
  `zip -jrds 100  #{learning_vm_archive_path} /tmp/learning_puppet_vm/`
end

def create_md5
  `md5 #{learning_vm_archive_path} > #{learning_vm_archive_path + ".md5"}`
end

def bundle_learning_vm
  make_learning_vm_dir
  copy_ova_to_dir
  write_readme
  zip_learning_vm
  create_md5
end

def mount_fileshare
  begin
    `mkdir -p /tmp/fileshare && mount_smbfs #{FILESHARE_SERVER} /tmp/fileshare`
  rescue
    puts "There was an error mounting the #{FILESHARE_SERVER} to /tmp/fileshare"
    puts "Pleause check that this server isn't already mounted"
    exit 1
  end
end

def unmount_fileshare
  `umount /tmp/fileshare`
end

def ship_to_fileshare(path, destination)
  FileUtils.cp(path, destination)
  FileUtils.chmod(0644, File.join(destination, File.basename(path)))
end

def ship_directory
  "/tmp/fileshare/EducationVMs/learning/puppet-#{pe_version}-learning-#{PTB_VERSION[:major]}.#{PTB_VERSION[:minor]}/"
end



def update_symlink
  if PRE_RELEASE
    `ln -sf #{File.join(ship_directory, "learning_puppet_vm.zip")} /tmp/fileshare/EducationVMs/learning/learning_beta.zip`
    `ln -sf #{File.join(ship_directory, "learning_puppet_vm.zip.md5")} /tmp/fileshare/EducationVMs/learning/learning_beta.zip.md5`
  else
    `ln -sf #{File.join(ship_directory, "learning_puppet_vm.zip")} /tmp/fileshare/EducationVMs/learning/learning_latest.zip`
    `ln -sf #{File.join(ship_directory, "learning_puppet_vm.zip.md5")} /tmp/fileshare/EducationVMs/learning/learning_latest.zip.md5`
  end 
end

def ship_learning_vm_files
  mount_fileshare
  `mkdir -p #{ship_directory}`
  #ship_to_fileshare(learning_vm_archive_path, ship_directory)
  #ship_to_fileshare(learning_vm_archive_path + ".md5", ship_directory)
  update_symlink
  unmount_fileshare
end

#################################################
#                                               #
# Rake tasks for prepping the local environment #
#                                               #             
#################################################

desc "Set up default cache dirctories"
task :set_up_cache_dirs do
  create_cache_directories unless cache_directories_exist?
end

# TODO Add a task to set up symlinks for file_cache, output, and packer_cache
# then mkdir_p for file_cache/gems and file_cache/installers
# Environment variables for FILE_CACHE_SRC, OUTPUT_SRC, PACKER_CACHE_SRC

desc "Cache the PE Installer"
task :cache_pe_installer do
  cached_installer_path = "./file_cache/installers/#{installer_filename}"
  if not already_cached? 
    puts "Downloading PE installer for #{pe_version}"
    download_installer
  else
    puts "PE Installer for #{pe_version} is already cached. Moving on..."
  end
end

##################
#                #
# VM Build tasks #
#                #             
##################

desc "Training VM base build"
task :training_base => [:cache_pe_installer]do
  build_vm('base', 'training', {'pe_version' => pe_version})
end

desc "Training VM build"
task :training_build do
  build_vm('build', 'training')
end

desc "Master VM base build"
task :master_base => [:cache_pe_installer] do
  build_vm('base', 'master')
end

desc "Master VM build"
task :master_build do
  build_vm('build', 'master')
end

desc "Learning VM base build"
task :learning_base => [:cache_pe_installer] do
  build_vm('base', 'learning')
end

desc "Learning VM build"
task :learning_build do
  build_vm('build', 'learning')
end

desc "Student VM build"
task :student_build do
  build_vm('student', 'student')
end

desc "Package learning VM"
task :package_learning do
  begin
    require 'pandoc-ruby'
  rescue LoadError
    puts "You must have pandoc installed for the package Learning VM task!"
    exit 1
  end
  bundle_learning_vm
end

desc "Ship Learning VM"
task :ship_learning do
  ship_learning_vm_files
end
