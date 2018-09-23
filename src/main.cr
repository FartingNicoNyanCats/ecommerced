require "uuid"

require "kemal"
require "jwt"

require "pg"
require "crecto"

alias DataBaseQuery = Crecto::Repo::Query

authd_db_password_file = "db-password-file"
authd_db_name = "authd"
authd_db_hostname = "localhost"
authd_db_user = "user"

Kemal.config.extra_options do |parser|
	parser.on "-d name", "--database-name name", "database name for authd" do |dbn|
		authd_db_name = dbn
	end

	parser.on "-u name", "--database-username user", "database user for authd" do |u|
		authd_db_user = u
	end

	parser.on "-a hostname", "--hostname host", "hostname for authd" do |h|
		authd_db_hostname = h
	end

	parser.on "-P password-file", "--passfile file", "password file for authd" do |f|
		authd_db_password_file = f
	end
end

class Category < Crecto::Model
	schema "categories" do # table name
		field :categoryid, Int32
		field :categoryname, String
		field :categorydesc, String
	end

	validate_required [:categoryid, :categoryname, :categorydesc]
	unique_constraint :categoryid
	has_many :products, Product, foreign_key: :productid

	def to_h
		{
			:categoryid   => @categoryid,
			:categoryname => @categoryname,
			:categorydesc => @categorydesc,
			:products => @products
		}
	end
end

class Product < Crecto::Model
	schema "products" do # table name
		field :productid, Int32
		field :productname, String
		field :images, Array(String)
		field :price, Float32
		# field :categories, Array(Int32)
		# field :categories, Array(Category)
	end

	validate_required [:productid, :productname, :price]
	unique_constraint :productid
	has_many :categories, Category, foreign_key: :categoryid
	# has_many :categoryid, foreign_key: :categoryid

	def to_h
		{
			:productid => @productid,
			:productname => @productname,
			:price => @price,
			:images => @images,
			:categories => @categories
		}
	end
end

get "/product" do |env|
	query = DataBaseQuery.new
	allproducts = DataBase.all(Product, query)

	if ! allproducts
		next halt env, status_code: 400, response: ({error: "Cannot request all products."}.to_json)
	end

	{
		"status" => "success",
		"content" => allproducts.map &.to_h
	}.to_json
end

# XXX Later
post "/product/search/byname" do |env|
	env.response.content_type = "application/json"

	searchre = env.params.json["searchre"]?
	next halt env, status_code: 400, response: ({error: "Search by regex not implemented, yet."}.to_json)

	if ! searchre.is_a? String
		next halt env, status_code: 400, response: ({error: "Missing search parameter."}.to_json)
	end
end

post "/product/byid" do |env|
	env.response.content_type = "application/json"

	productid = env.params.json["productid"]?

	if ! productid.is_a? String
		next halt env, status_code: 400, response: ({error: "Missing product id."}.to_json)
	end

	product = DataBase.get_by(Product, productid: productid)

	if ! product
		next halt env, status_code: 400, response: ({error: "Invalid product id."}.to_json)
	end

	{
		"status" => "success",
		"content" => product.to_h
	}.to_json
end

module DataBase
	extend Crecto::Repo
end

Kemal.run do
	DataBase.config do |conf|
		conf.adapter = Crecto::Adapters::Postgres
		conf.hostname = authd_db_hostname
		conf.database = authd_db_name
		conf.username = authd_db_user
		conf.password = File.read(authd_db_password_file).chomp()

		# p "hostname #{conf.hostname}"
		# p "database #{conf.database}"
		# p "username #{conf.username}"
		# p "password #{conf.password}"
	end
end
