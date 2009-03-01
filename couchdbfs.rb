require 'fusefs'
require 'rubygems'
require 'couchrest'

DEBUG = false #true

class CouchdbDir
  def initialize()
  	@db = CouchRest.database!("http://127.0.0.1:5984/couchfs")
		create_view()
		create_root()
  end

	def create_view
      @view = {}
			@view['path'] = {'map' => "function(doc) {
            if (doc['path']) {
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
			}

			@view['base_path'] = {'map' => "function(doc) {
            if (doc['base_path']) {
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
			}
      @db.save({
        "_id" => "_design/doc",
        :views => @view
      })
	end

	#create the root dir
	def create_root
		if @db.view("doc/path", :key => "/")['rows'].nitems == 0
	    ret = {"path" => "/", "name" => "/", "files" => []}
			@db.save(ret)
		end
	end

  def contents(path)
		p "call:contents?(#{path})" if DEBUG
		files = @db.view("doc/base_path", :key => path)
		p files if DEBUG
		ret = []
		files['rows'].each do |fil|
			ret << @db.get(fil['id'])['name']
		end
		return ret
  end
  def directory?(path)
		dir = @db.view("doc/path", :key => path)['rows']
		if dir.nitems > 0
			return !@db.get(dir[0]['id']).key?("size")
		else
			return false
		end
  end

  def file?(path)
		dir = @db.view("doc/path", :key => path)['rows']
		if dir.nitems > 0
			return @db.get(dir[0]['id']).key?("size")
		else
			return false
		end
  end

  def touch(path)
    write_to(path, "")
  end
  def read_file(path)
    ret = @db.view("doc/path", :key => path)
		if ret['rows'].nitems > 0
			file = @db.get(ret['rows'][0]['id'])
			if file.key?("size")
				return @db.fetch_attachment(file["_id"], file["name"])
			end
		end
		return false
  end
  def size(path)
		ret = @db.view("doc/path", :key => path)
		if ret['rows'].nitems > 0
			file = @db.get(ret['rows'][0]['id'])
			if file.key?("size")
				return file["size"]
			else
				#directory
				return 0
			end
		end
		return 0
  end

  # File writing
  def can_write?(path)
		return @db.view("doc/path", :key => path)['rows'].nitems == 0
  end
	def write_to(path, body)
		name = File.basename(path)
		path_only = path.sub(/#{name}$/, "")
    file = {"path" => path, "base_path" => path_only, "_attachments" => { name => {"data" => body}}, "name" => name, "size" => body.length, "type" => "f"}
		@db.save(file)
	end

  # Delete a file
  def can_delete?(path)
		rows = @db.view("doc/path", :key => path)['rows']
		if rows.nitems > 0
			file = @db.get(rows[0]['id'])
			if file.key?("size")
				return true
			end
		end
		false
  end
  def delete(path)
		name = File.basename(path)
		path_only_b = path.sub(/#{name}$/, "")
		path_only = path_only_b != "/" ? path_only_b.sub(/\/$/, "") : path_only_b
    
		ret = @db.view("doc/path", :key => path)
		ret.each do |fil|
			fil.destroy
		end
		ret = @db.view("doc/path", :key => path_only)
		ret.each do |dir|
			if dir["files"].include?("D#{name}")
				dir["files"].delete("D#{name}")
			end
		end
  end


  def can_mkdir?(path)
		return @db.view("doc/path", :key => path)['rows'].nitems == 0
  end
  def mkdir(path)
		name = File.basename(path)
		path_only = path.sub(/#{name}$/, "")
    dir = {"path" => path, "base_path" => path_only, "name" => name}
		@db.save(dir)
	end
  def mkdir_old(path)
		name = File.basename(path)
		path_only = path.sub(/#{name}$/, "")
    ret = {"type" => "FileCouch", "path" => path, "base_path" => path_only, "name" => name, "files" => []}
		#ret.save
		@db.save(ret)
		ret3 = {}
		if path_only != "/"
	    ret2 = @db.view("doc/path", :key => path_only.sub(/\/$/, ""))
		else
	    ret2 = @db.view("doc/path", :key => path_only)
		end
		ret3 = nil
		if ret2.nitems == 0
			name2 = File.basename(path_only)
			path_only2 = path_only.sub(/\/#{name2}$/, "")
			if path_only2 == ""
				path_only2 = "/"
			end
    	ret3 = {"type" => "FileCouch", "path" => path_only, "base_path" => path_only2, "name" => name2, "files" => []}
		else
			ret2.each do |r|
				if r["files"].nitems < 100
					ret3 = r
				end
			end
			if ret3 == nil
				#new
    		ret3 = {"type" => "FileCouch", "path" => path_only, "base_path" => path_only2, "name" => name2, "files" => []}
			end
		end
    ret3["files"] ||= []
		ret3["files"] << "D#{name}"
		@db.save(ret3)
		#ret3.save
  end

  # rmdir
  def can_rmdir?(path)
		true
  end
  def rmdir(path)
    ret = @db.view("doc/path", :key => path)
		ret.each do |fil|
			fil.destroy
		end
  end

	def delete_db
		@db.delete!
	end
end

#if (File.basename($0) == File.basename(__FILE__))
#  if (ARGV.size < 1)
#    puts "Usage: #{$0} <directory> <options>"
#    exit
#  end
#
#  dirname, yamlfile = ARGV.shift, ARGV.shift
#
#  unless File.directory?(dirname)
#    puts "Usage: #{dirname} is not a directory."
#    exit
#  end
#
#  root = CouchdbDir.new()
#
#  # Set the root FuseFS
#  FuseFS.set_root(root)
#
#  FuseFS.mount_under(dirname, *ARGV)
#
#  FuseFS.run # This doesn't return until we're unmounted.
#end
