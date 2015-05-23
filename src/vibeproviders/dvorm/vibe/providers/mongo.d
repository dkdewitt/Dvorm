module dvorm.vibe.providers.mongo;
import dvorm.provider;
import vibe.d;
import std.conv;
import std.traits;
import std.string : indexOf;

private {
	shared MongoCollection[string] tableCollections;
}

class MongoProvider : Provider {
	override void*[] find(string table, string[] argNames, string[] args, ObjectBuilder builder, DbConnection[] connection) {
		checkConnection(table, connection);
		MongoCollection col = cast(MongoCollection)tableCollections[connection[0].database ~ "." ~ table];
		Bson[string] query;
		
		size_t i;
		foreach(vn; argNames) {
			query[vn] = Bson(args[i]);
			i++;
		}
		
		Bson qBson = Bson(query);
		void*[] ret;
		foreach(i, b; col.find(qBson)) {
			try {
				string[string] create;
				Bson[string] v = cast(Bson[string])b;
				foreach(k, v2; v) {
					try {
						create[k] = v2.get!string();
					} catch (Exception e) {}
				}
				ret ~= builder(create);
			} catch (Exception e) {}
		}
		return ret;
	}
	
	override void*[] findAll(string table, ObjectBuilder builder, DbConnection[] connection) {
		checkConnection(table, connection);
		MongoCollection col = cast(MongoCollection)tableCollections[connection[0].database ~ "." ~ table];
		
		void*[] ret;
		foreach(k, b; col.find()) {
			try {
				string[string] create;
				Bson[string] v = cast(Bson[string])b;
				foreach(k, v2; v) {
					try {
						create[k] = v2.get!string();
					} catch (Exception e) {}
				}
				
				ret ~= builder(create);
			} catch (Exception e) {}
		}
		return ret;
	}
	
	override void* findOne(string table, string[] argNames, string[] args, ObjectBuilder builder, DbConnection[] connection) {
		checkConnection(table, connection);
		MongoCollection col = cast(MongoCollection)tableCollections[connection[0].database ~ "." ~ table];
		Bson[string] query;
		
		size_t i;
		foreach(vn; argNames) {
			query[vn] = Bson(args[i]);
			i++;
		}
		
		Bson qBson = Bson(query);
		string[string] create;
		
		Bson ret = col.findOne(qBson);
		if (ret.isNull) return null;
		
		foreach(string k, b; ret) {
			try {
				create[k] = b.get!string();
			} catch (Exception e) {}
		}
		
		return builder(create);
	}
	
	override void remove(string table, string[] idNames, string[] valueNames, string[] valueArray, ObjectBuilder builder, DbConnection[] connection) {
		checkConnection(table, connection);
		MongoCollection col = cast(MongoCollection)tableCollections[connection[0].database ~ "." ~ table];
		Bson[string] query;
		
		foreach(id; idNames) {
			size_t i;
			foreach(vn; valueNames) {
				if (vn == id) {
					query[id] = Bson(valueArray[i]);
				}
				i++;
			}
		}
		
		col.remove(Bson(query));
	}
	
	override void removeAll(string table, ObjectBuilder builder, DbConnection[] connection) {
		checkConnection(table, connection);
		MongoCollection col = cast(MongoCollection)tableCollections[connection[0].database ~ "." ~ table];
		
		col.remove();
	}
	
	override void save(string table, string[] idNames, string[] valueNames, string[] valueArray, ObjectBuilder builder, DbConnection[] connection) {
		checkConnection(table, connection);
		MongoCollection col = cast(MongoCollection)tableCollections[connection[0].database ~ "." ~ table];
		Bson[string] query;
		
		size_t i;
		foreach(id; idNames) {
			i = 0;
			foreach(vn; valueNames) {
				if (vn == id) {
					query[id] = Bson(valueArray[i]);
				}
				i++;
			}
		}
		
		Bson[string] value;
		
		i = 0;
		foreach(vn; valueNames) {
			value[vn] = Bson(valueArray[i]);
			i++;
		}
		
		Bson qBson = Bson(query);
		Bson qValue = Bson(value);
		
		if (col.count(qBson) == 0)
			col.insert(qValue);
		else
			col.update(qBson, qValue);
	}
	
	override string[] handleQueryOp(string op, string prop, string value, string[] store) {
		return store ~ [op ~ ":" ~ prop ~ ":" ~ value];
	}
	
	override void*[] handleQuery(string[] store, string table, string[] idNames, string[] valueNames, ObjectBuilder builder, DbConnection[] connection) {
		checkConnection(table, connection);
		MongoCollection col = cast(MongoCollection)tableCollections[connection[0].database ~ "." ~ table];
		Bson[string] query;
		
		int num_skip = 0, num_docs_per_chunk = 0;
		
		// build the query
		foreach(s; store) {
			size_t i = s.indexOf(":");
			if (i >= 0 && i + 1 < s.length) {
				string op = s[0 .. i];
				string prop = s[i + 1.. $];
				i = prop.indexOf(":");
				if (i >= 0 && i + 1 < prop.length) {
					string value = prop[i + 1.. $];
					prop = prop[0 .. i];
					
					switch(op) {
						case "lt":
						case "lte":
						case "mt":
						case "mte":
							query[prop] = Bson(["$" ~ op : Bson(value)]);
							break;
						case "eq":
							query[prop] = Bson(value);
							break;
						case "neq":
							query[prop] = Bson(["$ne" : Bson(value)]);
							break;
							
						case "startAt":
							num_skip = to!int(value);
							break;
						case "maxAmount":
							num_docs_per_chunk = to!int(value);
							break;
							
						case "like":
							query[prop] = Bson(["$regex" : Bson(".*" ~ value ~ ".*"), "$options" : Bson("i")]);
							break;
							
						default:
							break;
					}
				}
			}
		}
		
		Bson qBson = Bson(query);
		
		void*[] ret;
		foreach(i, b; col.find(qBson, null, QueryFlags.None, num_skip, num_docs_per_chunk)) {
			try {
				string[string] create;
				Bson[string] v = cast(Bson[string])b;
				foreach(k, v2; v) {
					try {
						create[k] = v2.get!string();
					} catch (Exception e) {}
				}
				ret ~= builder(create);
			} catch (Exception e) {}
		}
		return ret;
	}
	
	override size_t handleQueryCount(string[] store, string table, string[] idNames, string[] valueNames, ObjectBuilder builder, DbConnection[] connection) {
		checkConnection(table, connection);
		MongoCollection col = cast(MongoCollection)tableCollections[connection[0].database ~ "." ~ table];
		Bson[string] query;
		
		int num_skip = 0, num_docs_per_chunk = 0;
		
		// build the query
		foreach(s; store) {
			size_t i = s.indexOf(":");
			if (i >= 0 && i + 1 < s.length) {
				string op = s[0 .. i];
				string prop = s[i + 1.. $];
				i = prop.indexOf(":");
				if (i >= 0 && i + 1 < prop.length) {
					string value = prop[i + 1.. $];
					prop = prop[0 .. i];
					
					switch(op) {
						case "lt":
						case "lte":
						case "mt":
						case "mte":
							query[prop] = Bson(["$" ~ op : Bson(value)]);
							break;
						case "eq":
							query[prop] = Bson(value);
							break;
						case "neq":
							query[prop] = Bson(["$ne" : Bson(value)]);
							break;
							
						case "startAt":
							num_skip = to!int(value);
							break;
						case "maxAmount":
							num_docs_per_chunk = to!int(value);
							break;
							
						case "like":
							query[prop] = Bson(["$regex" : Bson(".*" ~ value ~ ".*"), "$options" : Bson("i")]);
							break;
							
						default:
							break;
					}
				}
			}
		}
		
		Bson qBson;
		if (num_docs_per_chunk == 0)
			qBson = Bson(["count" : Bson(table), "query" : Bson(query), "skip" : Bson(num_skip)]);
		else
			qBson = Bson(["count" : Bson(table), "query" : Bson(query), "skip" : Bson(num_skip), "limit" : Bson(num_docs_per_chunk)]);
		
		size_t ret;
		try {
			Bson[string] v = col.database.runCommand(qBson).get!(Bson[string])();
			
			if ("ok" in v) {
				if (v["ok"].get!double() == 1) {
					if ("n" in v) {
						ret = cast(size_t)v["n"].get!double();
					}
				}
			}
		} catch (Exception e) {}
		return ret;
	}
	
	override void handleQueryRemove(string[] store, string table, string[] idNames, string[] valueNames, ObjectBuilder builder, DbConnection[] connection) {
		checkConnection(table, connection);
		MongoCollection col = cast(MongoCollection)tableCollections[connection[0].database ~ "." ~ table];
		Bson[string] query;
		
		//int num_skip = 0, num_docs_per_chunk = 0;
		
		// build the query
		foreach(s; store) {
			size_t i = s.indexOf(":");
			if (i >= 0 && i + 1 < s.length) {
				string op = s[0 .. i];
				string prop = s[i + 1.. $];
				i = prop.indexOf(":");
				if (i >= 0 && i + 1 < prop.length) {
					string value = prop[i + 1.. $];
					prop = prop[0 .. i];
					
					switch(op) {
						case "lt":
						case "lte":
						case "mt":
						case "mte":
							query[prop] = Bson(["$" ~ op : Bson(value)]);
							break;
						case "eq":
							query[prop] = Bson(value);
							break;
						case "neq":
							query[prop] = Bson(["$ne" : Bson(value)]);
							break;
							
						case "like":
							query[prop] = Bson(["$regex" : Bson(".*" ~ value ~ ".*"), "$options" : Bson("i")]);
							break;
							
						case "startAt":
						case "maxAmount":
						default:
							break;
					}
				}
			}
		}
		
		col.remove(Bson(query));
	}
	
	override void*[] queryJoin(string[] store, string baseTable, string endTable, string[] baseIdNames, string[] endIdNames, Provider provider, ObjectBuilder builder, DbConnection[] baseConnection, DbConnection[] endConnection) {
		checkConnection(baseTable, baseConnection);
		MongoCollection col = cast(MongoCollection)tableCollections[baseConnection[0].database ~ "." ~ baseTable];
		Bson[string] query;
		
		int num_skip = 0, num_docs_per_chunk = 0;
		
		// build the query
		foreach(s; store) {
			size_t i = s.indexOf(":");
			if (i >= 0 && i + 1 < s.length) {
				string op = s[0 .. i];
				string prop = s[i + 1.. $];
				i = prop.indexOf(":");
				if (i >= 0 && i + 1 < prop.length) {
					string value = prop[i + 1.. $];
					prop = prop[0 .. i];
					
					switch(op) {
						case "lt":
						case "lte":
						case "mt":
						case "mte":
							query[prop] = Bson(["$" ~ op : Bson(value)]);
							break;
						case "eq":
							query[prop] = Bson(value);
							break;
						case "neq":
							query[prop] = Bson(["$ne" : Bson(value)]);
							break;
							
						case "startAt":
							num_skip = to!int(value);
							break;
						case "maxAmount":
							num_docs_per_chunk = to!int(value);
							break;
							
						case "like":
							query[prop] = Bson(["$regex" : Bson(".*" ~ value ~ ".*"), "$options" : Bson("i")]);
							break;
							
						default:
							break;
					}
				}
			}
		}
		
		Bson qBson = Bson(query);
		
		void*[] ret;
		foreach(i, b; col.find(qBson, null, QueryFlags.None, num_skip, num_docs_per_chunk)) {
			try {
				string[string] create;
				Bson[string] v = cast(Bson[string])b;
				foreach(k, v2; v) {
					try {
						create[k] = v2.get!string();
					} catch (Exception e) {}
				}
				
				string[] args;
				string[] idArgs;
				
				foreach(j, id; baseIdNames) {
					if (id in create) {
						idArgs ~= endIdNames[j];
						args ~= create[id];
					}
				}
						
				ret ~= provider.find(endTable, idArgs, args, builder, endConnection);
				
			} catch (Exception e) {}
		}
		return ret;
	}
}

private {
	void checkConnection(string table, DbConnection[] connections) {
		if (connections.length >= 1) {
			DbConnection con = connections[0];
			if (con.database ~ "." ~ table !in tableCollections) {
				string conStr = "mongodb://";
				if (con.user != "") {
					conStr ~= con.user;
					if (con.pass != "") {
						conStr ~= ":" ~ con.pass;
					}
					conStr ~= "@";
				}
				
				foreach(con2; connections) {
					conStr ~= con2.host;
					if (con2.port != ushort.init) {
						conStr ~= ":" ~ to!string(con2.port) ~ ",";
					}
					if (conStr[$-1] == ',')
						conStr = conStr[0 .. $-1];
				}
				
				if(con.database != "")
				{
					conStr ~= "/" ~ con.database;
				}
				
				MongoClient client = connectMongoDB(conStr);
				tableCollections[con.database ~ "." ~ table] = cast(shared)client.getCollection(con.database ~ "." ~ table);
			} else {
				// already created
			}
		} else {
			assert(0, "No database could be connected to. For table " ~ table ~ ".");
		}
	}
}
