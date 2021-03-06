module dvorm.provider;
public import dvorm.connection;
import dvorm.util;
import std.traits;

private {
	__gshared Provider[DbType] providers;
}

Provider provider(DbType type) {
	assert(providers.get(type, null) !is null, "Database provider " ~ type ~ " has not been registered :(");
	return providers[type];
}

void registerProvider(DbType type, Provider p) {
	providers[type] = p;
}

abstract class Provider {
	C[] find(C)(string[] argNames, string[] args, ObjectBuilder builder) {
		return dePointerArrayValues!(C)(cast(C*[])find(getTableName!C(), argNames, args, builder, getDbConnectionInfo!C));
	}
	
	C[] findAll(C)(ObjectBuilder builder) {
		return dePointerArrayValues!(C)(cast(C*[])findAll(getTableName!C(), builder, getDbConnectionInfo!C));
	}
	
	C findOne(C)(string[] argNames, string[] args, ObjectBuilder builder) {
		auto value = findOne(getTableName!C(), argNames, args, builder, getDbConnectionInfo!C);
		if (value is null)
			return null;
		else
			return *cast(C*)value;
	}
	
	/**
	 * A query a little like a SQL join but limited to a set return type.
	 * 
	 * Params:
	 * 		C 		= The type to go against
	 * 		D		= The type of the end value
	 * 		idNames	= The id values to compare against to create D (basically the property)
	 * 		builder	= The builder that creates the return values
	 * 
	 * Returns:
	 * 		An array of all type D that has a type C and set on its prop.
	 */
	D[] queryJoin(C, D)(string[] store, string[] baseIdNames, string[] endIdNames, Provider provider, ObjectBuilder builder) {
		return dePointerArrayValues!(D)(cast(D*[])queryJoin(store, getTableName!C(), getTableName!D(), baseIdNames, endIdNames, provider, builder, getDbConnectionInfo!C, getDbConnectionInfo!D));
	}
	
	void remove(C)(string[] idNames, string[] valueNames, string[] valueArray, ObjectBuilder builder) {
		remove(getTableName!C(), idNames, valueNames, valueArray, builder, getDbConnectionInfo!C);
	}
	
	void removeAll(C)(ObjectBuilder builder) {
		removeAll(getTableName!C(), builder, getDbConnectionInfo!C);
	}
	
	void save(C)(string[] idNames, string[] valueNames, string[] valueArray, ObjectBuilder builder) {
		save(getTableName!C(), idNames, valueNames, valueArray, builder, getDbConnectionInfo!C);
	}
	
	void*[] find(string table, string[] argNames, string[] args, ObjectBuilder builder, DbConnection[] connection);
	void*[] findAll(string table, ObjectBuilder builder, DbConnection[] connection);
	void* findOne(string table, string[] argNames, string[] args, ObjectBuilder builder, DbConnection[] connection);
	void remove(string table, string[] idNames, string[] valueNames, string[] valueArray, ObjectBuilder builder, DbConnection[] connection);
	void removeAll(string table, ObjectBuilder builder, DbConnection[] connection);
	void save(string table, string[] idNames, string[] valueNames, string[] valueArray, ObjectBuilder builder, DbConnection[] connection);
	
	string[] handleQueryOp(string op, string prop, string value, string[] store);
	void*[] handleQuery(string[] store, string table, string[] idNames, string[] valueNames, ObjectBuilder builder, DbConnection[] connection);
	size_t handleQueryCount(string[] store, string table, string[] idNames, string[] valueNames, ObjectBuilder builder, DbConnection[] connection);
	void handleQueryRemove(string[] store, string table, string[] idNames, string[] valueNames, ObjectBuilder builder, DbConnection[] connection);
	
	void*[] queryJoin(string[] store, string baseTable, string endTable, string[] baseIdNames, string[] endIdNames, Provider provider, ObjectBuilder builder, DbConnection[] baseConnection, DbConnection[] endConnection);
}

alias void* delegate(string[string] values) ObjectBuilder;

pure string objectBuilderCreator(C, string name = "objectBuilder")() {
	string ret = "void* " ~ name ~ "(string[string] values) {\n";
	ret ~= "    import " ~ moduleName!C ~ ";\n";
	ret ~= "    import std.conv : to;\n";
	ret ~= "    " ~ C.stringof ~ " ret = newValueOfType!(" ~ C.stringof ~ ")();\n";
	ret ~= "    string keyValueOfName;\n";
	
	foreach(m; __traits(allMembers, C)) {
		static if (isUsable!(C, m)) {
			static if (!shouldBeIgnored!(C, m)) {
				ret ~= 
					"""
	static if (!isAnObjectType!(typeof(ret." ~ m ~ "))) {
		 static if (isBasicType!(typeof(ret." ~ m ~ "))) {
			if (\"" ~ getNameValue!(C, m)() ~ "\" in values)
				ret." ~ m ~ " = to!(typeof(ret." ~ m ~ "))(values[\"" ~ getNameValue!(C, m)() ~ "\"]);
			} else static if (isArray!(typeof(ret." ~ m ~ ")) && 
							 (typeof(ret." ~ m ~ ").stringof == \"string\" ||
							  typeof(ret." ~ m ~ ").stringof == \"dstring\" ||
							  typeof(ret." ~ m ~ ").stringof == \"wstring\")) {
				if (\"" ~ getNameValue!(C, m)() ~ "\" in values)
					ret." ~ m ~ " = values[\"" ~ getNameValue!(C, m)() ~ "\"];
				}
			} else {
				auto " ~ m ~ " = newValueOfType!(typeof(ret." ~ m  ~ "));
				foreach(n; __traits(allMembers, typeof(ret." ~ m ~ "))) {
					static if (isUsable!(typeof(ret." ~ m  ~ "), n)() && !shouldBeIgnored!(typeof(ret." ~ m  ~ "), n)()) {
						static if (!newValueOfType!(typeof(mixin(\"" ~ m ~ ".\" ~ n)))) {
							keyValueOfName = \"" ~ getNameValue!(C, m)() ~ "_\" ~ getNameValue!(typeof(ret." ~ m  ~ "), n)();
							static if (isBasicType!(typeof(mixin(\"" ~ m ~ ".\" ~ n)))) {
								if (keyValueOfName in values) {
									mixin(\"" ~ m ~ ".\" ~ n) = to!(typeof(mixin(\"" ~ m ~ ".\" ~ n)))(values[keyValueOfName]);
								}
							} else static if (isArray!(typeof(mixin(\"" ~ m ~ ".\" ~ n))) && 
											 (typeof(mixin(\"" ~ m ~ ".\" ~ n)).stringof == \"string\" ||
											  typeof(mixin(\"" ~ m ~ ".\" ~ n)).stringof == \"dstring\" ||
											  typeof(mixin(\"" ~ m ~ ".\" ~ n)).stringof == \"wstring\")) {
								if (keyValueOfName in values) {
									mixin(\"" ~ m ~ ".\" ~ n) = to!(typeof(mixin(\"" ~ m ~ ".\" ~ n)))(values[keyValueOfName]);
								}
							}
						} else {
							assert(0, \"Cannot have ids within more then one recursion of an object\");
						}
					}
				}
				ret." ~ m ~ " = " ~ m ~ ";
			}
	 """;
			}
		}
	}
	
	ret ~= "    return [ret].ptr;\n";
	ret ~= "}\n";
	return ret;
}