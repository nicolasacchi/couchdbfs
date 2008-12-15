require 'fusefs'
require 'rubygems'
require 'couchrest'

DEBUG = true

class FileCouch < CouchRest::Model
  use_database CouchRest.database!('http://localhost:5984/couchfs')
	def FileCouch.usedb
  	use_database CouchRest.database!('http://localhost:5984/couchfs')
	end
	view_by :name
	view_by :path,
					:map => "          function(doc) {
            if (doc['couchrest-type'] == 'FileCouch' && doc['path']) {
						if(doc['path'] == \"/\")
						{
              emit(doc['path'], null);
						}
						else
						{
              emit(doc['path'].replace(/\\/$/, \"\"), null);
            }
				}
          }"

	view_by :base_path,
					:map => "          function(doc) {
            if (doc['couchrest-type'] == 'FileCouch' && doc['base_path']) {
						if(doc['base_path'] == \"/\")
						{
              emit(doc['base_path'], null);
						}
						else
						{
              emit(doc['base_path'].replace(/\\/$/, \"\"), null);
            }
				}
          }"
	view_by :type
end


class CouchdbDir
  def initialize()
		@db = FileCouch.usedb()
		@cache = {}
  end

  def contents(path)
		p "call:contents?(#{path})" if DEBUG
		@cache = {}
		files = FileCouch.by_path :key => path
		ret = []
		files.each do |fil|
			ret += fil["files"].map {|t| t.sub(/^[D|F]/, "") }
		end
		@cache[path] = files
		return ret
  end
  def directory?(path)
		p "call:directory?(#{path})" if DEBUG
		name = File.basename(path)
		path_only_b = path.sub(/#{name}$/, "")
		path_only = path_only_b != "/" ? path_only_b.sub(/\/$/, "") : path_only_b
		if @cache[path_only]
			files = @cache[path_only] 
		else
			files = FileCouch.by_path :key => path_only
		end
		trovato = false
    files.each do |fil|
			if fil["files"].include?("D#{name}")
				trovato = true
			end
		end
		return trovato
  end

  def file?(path)
		p "call:file?(#{path})" if DEBUG
		name = File.basename(path)
		path_only_b = path.sub(/#{name}$/, "")
		path_only = path_only_b != "/" ? path_only_b.sub(/\/$/, "") : path_only_b
		if @cache[path_only] != nil
			files = @cache[path_only]
		else
			files = FileCouch.by_path :key => path_only
		end
		trovato = false
    files.each do |fil|
			if fil["files"].include?("F#{name}")
				trovato = true
			end
		end
		return trovato
  end

  def touch(path)
    puts "#{path} has been pushed like a button!"
  end
  def read_file(path)
    ret = FileCouch.by_path :key => path
		ret.each do |fil|
			return @db.fetch_attachment(fil["_id"], fil["name"])
		end
  end
  def size(path)
		p "call:size(#{path})"
		ret = FileCouch.by_path :key => path 
		ret.each do |fil|
			return fil["size"] ? fil["size"] : 10
		end
  end

  # File writing
  def can_write?(path)
    true
  end
  def write_to(path,body)
		name = File.basename(path)
		path_only = path.sub(/#{name}$/, "")
		body ||= ""
		ret = FileCouch.by_path :key => path
		ret.each do |r|
			r.destroy
		end
    ret = FileCouch.new({"path" => path, "base_path" => path_only, "_attachments" => { name => {"data" => body}}, "name" => name, "size" => body.length})
		ret.save	
		ret3 = {}
		if path_only != "/"
	    ret2 = FileCouch.by_path :key => path_only.sub(/\/$/, "")
		else
	    ret2 = FileCouch.by_path :key => path_only
		end
		ret3 = nil
		if ret2.nitems == 0
			name2 = File.basename(path_only)
			path_only2 = path_only.sub(/\/#{name2}$/, "")
			if path_only2 == ""
				path_only2 = "/"
			end
    	ret3 = FileCouch.new({"path" => path_only, "base_path" => path_only2, "name" => name2, "files" => []})
		else
			ret2.each do |r|
				if r["files"].nitems < 1000
					ret3 = r
				end
			end
			if ret3 == nil
				#new
    		ret3 = FileCouch.new({"path" => path_only, "base_path" => path_only2, "name" => name2, "files" => []})
			end
		end
    ret3["files"] ||= []
		ret3["files"] << "F#{name}"
		ret3.save
  end

  # Delete a file
  def can_delete?(path)
		true
  end
  def delete(path)
		name = File.basename(path)
		path_only_b = path.sub(/#{name}$/, "")
		path_only = path_only_b != "/" ? path_only_b.sub(/\/$/, "") : path_only_b
    
		ret = FileCouch.by_path :key => path
		ret.each do |fil|
			fil.destroy
		end
		ret = FileCouch.by_path :key => path_only
		ret.each do |dir|
			if dir["files"].include?("D#{name}")
				dir["files"].delete("D#{name}")
			end
		end
  end


  def can_mkdir?(path)
		true
  end
  def mkdir(path)
		name = File.basename(path)
		path_only = path.sub(/#{name}$/, "")
    ret = FileCouch.new({"path" => path, "base_path" => path_only, "name" => name, "files" => []})
		ret.save	
		ret3 = {}
		if path_only != "/"
	    ret2 = FileCouch.by_path :key => path_only.sub(/\/$/, "")
		else
	    ret2 = FileCouch.by_path :key => path_only
		end
		ret3 = nil
		if ret2.nitems == 0
			name2 = File.basename(path_only)
			path_only2 = path_only.sub(/\/#{name2}$/, "")
			if path_only2 == ""
				path_only2 = "/"
			end
    	ret3 = FileCouch.new({"path" => path_only, "base_path" => path_only2, "name" => name2, "files" => []})
		else
			ret2.each do |r|
				if r["files"].nitems < 100
					ret3 = r
				end
			end
			if ret3 == nil
				#new
    		ret3 = FileCouch.new({"path" => path_only, "base_path" => path_only2, "name" => name2, "files" => []})
			end
		end
    ret3["files"] ||= []
		ret3["files"] << "D#{name}"
		ret3.save
  end

  # rmdir
  def can_rmdir?(path)
		true
  end
  def rmdir(path)
    ret = FileCouch.by_path :key => path
		ret.each do |fil|
			fil.destroy
		end
  end

end

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
