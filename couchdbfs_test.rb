require 'test/unit'
require 'couchdbfs'

class TestCouchFs < Test::Unit::TestCase

	def setup
		@db = CouchRest.database!("http://127.0.0.1:5984/couchfs")
		@db.delete!
    @root = CouchdbDir.new()
		@db = CouchRest.database!("http://127.0.0.1:5984/couchfs")
	end

	#1
	def test_root
		files = @db.view("doc/path", :key => "/")
		assert_equal(1, files['rows'].nitems)
		assert_equal("/", files['rows'][0]['key'])
		root_dir = @db.get(files['rows'][0]['id'])
		assert_equal(nil, root_dir['base_path'])
		assert_equal("/", root_dir['name'])
		assert_equal("/", root_dir['path'])
		assert_equal(0, root_dir['files'].nitems)
	end

	#2
	def test_contents_empty
		ret = @root.contents("/")
		assert_equal(0, ret.nitems)
	end

	#3
	def test_write_file
		retw = @root.write_to("/test1", "abcd")
		ret = @db.get(retw['id'])
		assert_equal("/test1", ret["path"])
		assert_equal("/", ret["base_path"])
		assert_equal("test1", ret["name"])
		assert_not_equal(nil, ret["size"])
		assert_equal("abcd", @db.fetch_attachment(retw['id'], "test1"))
		ret = @root.contents("/")
		assert_equal(1, ret.nitems)
		assert_equal("test1", ret[0])
	end

	#4
	def test_write_file2
		retw1 = @root.write_to("/test2", "abcd")
		ret1 = @db.get(retw1['id'])
		retw2 = @root.write_to("/test3", "defg")
		ret2 = @db.get(retw2['id'])
		assert_equal("/test2", ret1["path"])
		assert_equal("/", ret1["base_path"])
		assert_equal("test2", ret1["name"])
		assert_not_equal(nil, ret1["size"])
		assert_equal("abcd", @db.fetch_attachment(retw1['id'], "test2"))
		assert_equal("/test3", ret2["path"])
		assert_equal("/", ret2["base_path"])
		assert_equal("test3", ret2["name"])
		assert_not_equal(nil, ret2["size"])
		assert_equal("defg", @db.fetch_attachment(retw2['id'], "test3"))
		ret = @root.contents("/")
		assert_equal(2, ret.nitems)
		assert(ret.include?("test2"))
		assert(ret.include?("test3"))
	end

	#5
	def test_create_dir
		retw = @root.mkdir("/dir_test1")
		ret = @db.get(retw['id'])
		assert_equal("dir_test1", ret["name"])
		assert_equal("/dir_test1", ret["path"])
		assert_equal("/", ret["base_path"])
		assert_equal(nil, ret["size"])
		ret = @root.contents("/")
		assert_equal(1, ret.nitems)
		assert_equal("dir_test1", ret[0])
	end

	#6
	def test_create_dir_with_file
		retd = @root.mkdir("/dir_test1")
		retw = @root.write_to("/dir_test1/test", "abcd")
		ret = @root.contents("/")
		assert_equal(1, ret.nitems)
		assert_equal("dir_test1", ret[0])
		ret = @root.contents("/dir_test1")
		assert_equal(1, ret.nitems)
		assert_equal("test", ret[0])
		retw = @root.write_to("/dir_test1/test3", "cdef")
		retw = @root.write_to("/test1", "test")
		ret = @root.contents("/dir_test1")
		assert_equal(2, ret.nitems)
		assert(ret.include?("test3"))
	end

	#7
	def test_can_mkdir
		assert(@root.can_mkdir?("/dir_test1"))
		retd = @root.mkdir("/dir_test1")
		assert(!@root.can_mkdir?("/dir_test1"))
		assert(@root.can_mkdir?("/dir_test2"))
		assert(@root.can_mkdir?("/test1"))
		retw = @root.write_to("/test1", "defg")
		assert(!@root.can_mkdir?("/test1"))
	end

	#8
	def test_can_write
		assert(@root.can_write?("/test1"))
		retw = @root.write_to("/test1", "defg")
		assert(!@root.can_write?("/test1"))
		assert(@root.can_write?("/test2"))
		assert(@root.can_write?("/dir_test1"))
		retd = @root.mkdir("/dir_test1")
		assert(!@root.can_write?("/dir_test1"))
	end

	#9
	def test_is_directory_file
		assert(!@root.directory?("/test1"))
		assert(!@root.file?("/test1"))
		retw = @root.write_to("/test1", "defg")
		retd = @root.mkdir("/dir_test1")
		assert(!@root.directory?("/test1"))
		assert(@root.file?("/test1"))
		assert(@root.directory?("/dir_test1"))
		assert(!@root.file?("/dir_test1"))
	end

	#10
	def test_touch
		retw = @root.touch("/test1")
		ret = @db.get(retw['id'])
		assert_equal("/test1", ret["path"])
		assert_equal("/", ret["base_path"])
		assert_equal("test1", ret["name"])
		assert_not_equal(nil, ret["size"])
		assert_equal(0, ret["size"])
		assert_equal("", @db.fetch_attachment(retw['id'], "test1"))
		ret = @root.contents("/")
		assert_equal(1, ret.nitems)
		assert_equal("test1", ret[0])
	end

	#11	
	def test_read_file
		test_write_file()
		file = @root.read_file("/test1")
		assert_equal("abcd", file)
	end

	#12
	def test_read_file2
		test_create_dir_with_file()
		file = @root.read_file("/dir_test1/test1")
		assert_equal(false, file)
		file = @root.read_file("/dir_test1/test")
		assert_equal("abcd", file)
		file = @root.read_file("/dir_test1")
		assert_equal(false, file)
	end

	#13
	def test_read_size_xx
		test_create_dir_with_file()
		size = @root.size("/dir_test1/test")
		assert_equal(4, size)
		size = @root.size("/dir_test1/test1")
		assert_equal(0, size)
		size = @root.size("/dir_test1")
		assert_equal(0, size)
	end

	#14
	def test_can_delete
		test_create_dir_with_file()
		ret = @root.can_delete?("/dir_test1/test")
		assert(ret)
		ret = @root.can_delete?("/dir_test1")
		assert(!ret)
		ret = @root.can_delete?("/test1")
		assert(ret)
		ret = @root.can_delete?("/test4")
		assert(!ret)
	end

	#15
	def test_delete
		test_create_dir_with_file()
		ret = @root.delete("/dir_test1/test")
		ret = @root.contents("/dir_test1")
		assert_equal(1, ret.nitems)
		assert(ret.include?("test3"))
		assert(!ret.include?("test"))
		ret = @root.delete("/dir_test1/test3")
		ret = @root.contents("/dir_test1")
		assert_equal(0, ret.nitems)
		assert(!ret.include?("test3"))
		assert(!ret.include?("test"))
		ret = @root.contents("/")
		assert_equal(2, ret.nitems)
		assert(!ret.include?("test3"))
		assert(ret.include?("test1"))
		assert(ret.include?("dir_test1"))
		ret = @root.delete("/test1")
		ret = @root.contents("/")
		assert_equal(1, ret.nitems)
		assert(!ret.include?("test3"))
		assert(!ret.include?("test1"))
		assert(ret.include?("dir_test1"))
	end

	#16
	def test_can_rmdir
		test_create_dir_with_file()
		assert(!@root.can_rmdir?("/dir_test1/test"))
		assert(!@root.can_rmdir?("/dir_test1"))
		ret = @root.delete("/dir_test1/test3")
		assert(!@root.can_rmdir?("/dir_test1"))
		ret = @root.delete("/dir_test1/test")
		assert(@root.can_rmdir?("/dir_test1"))
		assert(!@root.can_rmdir?("/"))
		ret = @root.delete("/test1")
		assert(!@root.can_rmdir?("/"))
	end

	#17
	def test_rmdir
		test_create_dir_with_file()
		ret = @root.delete("/dir_test1/test3")
		ret = @root.delete("/dir_test1/test")
		assert(!@root.rmdir?("/dir_test1"))
	end

  def teardown
  end

end
