$LOAD_PATH << File.expand_path(File.dirname(__FILE__)) 

require 'couchdbfs_lib'

if (File.basename($0) == File.basename(__FILE__))
  if (ARGV.size < 1)
    puts "Usage: #{$0} <directory> <options>"
    exit
  end

  dirname, yamlfile = ARGV.shift, ARGV.shift

  unless File.directory?(dirname)
    puts "Usage: #{dirname} is not a directory."
    exit
  end

  root = CouchdbDir.new()

  # Set the root FuseFS
  FuseFS.set_root(root)

  FuseFS.mount_under(dirname, *ARGV)

  FuseFS.run # This doesn't return until we're unmounted.
end
