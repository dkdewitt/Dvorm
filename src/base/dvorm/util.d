module dvorm.util;
import dvorm;
import std.conv : to;
import std.traits;
import std.string : toUpper;

struct dbId {
}

struct dbDefaultValue {
	string value;
}

struct dbIgnore {
}

struct dbName {
	string value;
}

/**
 * Right now I have NO idea how to determine if this is dbActualModel or not.
 * So UDA it is
 */
@("dbIsModel")
struct dbActualModel(T, string prop) {
	T type;
	string name = prop;
}

pure string getDefaultValue(C, string m)() {
	C c = newValueOfType!C;
	string ret = "";
	
	foreach(UDA; __traits(getAttributes, mixin("c." ~ m))) {
		static if (__traits(compiles, {dbDefaultValue v = UDA;})) {
			ret = UDA.value;
		}
	}
	return ret;
}

pure bool hasDefaultValue(C, string m)() {
	C c = newValueOfType!C;
	bool ret = false;
	
	foreach(UDA; __traits(getAttributes, mixin("c." ~ m))) {
		static if (__traits(compiles, {dbDefaultValue v = UDA;})) {
			ret = true;
		}
	}
	return ret;
}

pure string getNameValue(C, string m)() {
	C c = newValueOfType!C;
	string ret = m;
	
	foreach(UDA; __traits(getAttributes, mixin("c." ~ m))) {
		static if (__traits(compiles, {dbName v = UDA;})) {
			ret = UDA.value;
		}
	}
	return ret;
}

pure string getTableName(C)() {
	string ret = C.stringof;

	foreach(UDA; __traits(getAttributes, C)) {
		static if (__traits(compiles, {dbName v = UDA;})) {
			ret = UDA.value;
		}
	}
	return ret;
}

pure bool shouldBeIgnored(C, string m)() {
	C c = newValueOfType!C;
	bool ret = false;
	
	static if (__traits(compiles, __traits(getProtection, mixin("c." ~ m))) &&
	           __traits(getProtection, mixin("c." ~ m)) == "public") {
		foreach(UDA; __traits(getAttributes, mixin("c." ~ m))) {
			static if (is(UDA : dbIgnore)) {
				ret = true;
			}
		}
		return ret;
	} else {
		return true;
	}
}

pure bool isAnId(C, string m)() {
	C c = newValueOfType!C;
	bool ret = false;
	
	foreach(UDA; __traits(getAttributes, mixin("c." ~ m))) {
		static if (is(UDA : dbId)) {
			ret = true;
		}
	}
	return ret;
}

pure string[] getAllIds(C, bool first = true, string prefix="")() {
	string[] ret;
	C c = newValueOfType!C;
	
	foreach(m; __traits(allMembers, C)) {
		static if (isUsable!(C, m)()) {
			static if(isAnObjectType!(typeof(mixin("c." ~ m)))) {
				static if (first)
					ret ~= getAllIds!(typeof(mixin("c." ~ m)), false, getNameValue!(C, m) ~ "_")();
			} else {
				static if (isAnId!(C, m)()) {
					ret ~= prefix ~ getNameValue!(C, m);
				}
			}
		}
	}
	return ret;
}

pure string[] getAllIdNames(C, bool first = true, string prefix="")() {
	string[] ret;
	C c = newValueOfType!C;
	
	foreach(m; __traits(allMembers, C)) {
		static if (isUsable!(C, m)()) {
			static if(isAnObjectType!(typeof(mixin("c." ~ m)))) {
				static if (first)
					ret ~= getAllIdNames!(typeof(mixin("c." ~ m)), false, m ~ "_")();
			} else {
				static if (isAnId!(C, m)()) {
					ret ~= prefix ~ m;
				}
			}
		}
	}
	return ret;
}

pure string[] getIdNamesFor(C, string m, bool first = true, string prefix="")() {
	string[] ret;
	C c = newValueOfType!C;
	
	static if (isUsable!(C, m)()) {
		static if(isAnObjectType!(typeof(mixin("c." ~ m)))) {
			static if (!first) {
				foreach(n; __traits(allMembers, typeof(mixin("c." ~ m)))) {
					static if (isUsable!(typeof(mixin("c." ~ m)), n)()) {
						static if(isAnObjectType!(typeof(mixin("c." ~ m))) && isAnId!(typeof(mixin("c." ~ m)), n))
							ret ~= getNameValue!(typeof(mixin("c." ~ m), n));
					}
				}
			}
		} else {
			ret = [getNameValue!(C, m)];
		}
	}
	
	return ret;
}

pure string[] getAllValues(C, bool first = true, string prefix="")() {
	string[] ret;
	C c = newValueOfType!C;
	
	foreach(m; __traits(allMembers, C)) {
		static if (isUsable!(C, m)()) {
			static if(isAnObjectType!(typeof(mixin("c." ~ m)))) {
				static if (first)
					ret ~= getAllValues!(typeof(mixin("c." ~ m)), false, m ~ "_")();
			} else {
				ret ~= prefix ~ getNameValue!(C, m);
			}
		}
	}
	return ret;
}

pure string[] getAllValueNames(C, bool first = true, string prefix="")() {
	string[] ret;
	C c = newValueOfType!C;
	
	foreach(m; __traits(allMembers, C)) {
		static if (isUsable!(C, m)()) {
			static if(isAnObjectType!(typeof(mixin("c." ~ m)))) {
				static if (first)
					ret ~= getAllValueNames!(typeof(mixin("c." ~ m)), false, m ~ "_")();
			} else {
				ret ~= prefix ~ m;
			}
		}
	}
	return ret;
}

pure bool isUsable(C, string m)() {
	C c = newValueOfType!C;
	
	static if (__traits(compiles, {auto value = typeof(mixin("c." ~ m)).init;})) {
		static if (__traits(compiles, {auto value = typeof(mixin("c." ~ m)).init;})) {
			static if (!__traits(hasMember, Object, m) &&
			           !__traits(isAbstractFunction, Object, m) &&
			           !__traits(isStaticFunction, mixin("c." ~ m)) &&
			           !__traits(isOverrideFunction, mixin("c." ~ m)) &&
			           !__traits(isFinalFunction, mixin("c." ~ m)) &&
			           !(m.length >= 2 && m[0 .. 2] == "op") &&
			           !__traits(isVirtualMethod, mixin("c." ~ m))) {
				
				static if (isAnObjectType!(typeof(mixin("c." ~ m))) ||
				           isBasicType!(typeof(mixin("c." ~ m))) ||
				           is(typeof(mixin("c." ~ m)) == enum) ||
				           is(typeof(mixin("c." ~ m)) == string)) {
					return true;
				} else {
					return false;
				}
			} else {
				return false;
			}
		} else {
			return false;
		}
	} else {
		return false;
	}
}

DbType getDbType(C)() {
	foreach(c; C.databaseConnection()) {
		return c.type;
	}
	foreach(c; databaseConnection()) {
		return c.type;
	}
	return DbType.Memory;
}

DbConnection[] getDbConnectionInfo(C)() {
	if (C.databaseConnection.length != 0)
		return C.databaseConnection;
	if (databaseConnection.length != 0)
		return databaseConnection();
	return [];
}

/**
 * Does a variable have another model associated with it?
 */

pure bool isActualRelationship(T, string f)() {
	T t = newValueOfType!T;
	bool ret = false;

	foreach(UDA; __traits(getAttributes, mixin("t." ~ f))) {
		foreach(UDA2; __traits(getAttributes, UDA)) {
			static if (UDA2 == "dbIsModel") {
				ret = true;
			}
		}
	}
	
	return ret;
}

/**
 * Get us the type name/module name of another model's based upon the variable.
 */

pure string getRelationshipClassName(T, string f)() {
	T t = newValueOfType!T;
	string ret = null;

	foreach(UDA; __traits(getAttributes, mixin("t." ~ f))) {
		foreach(UDA2; __traits(getAttributes, UDA))
			static if (UDA2 == "dbIsModel")
				ret = typeof(UDA.type).stringof;
	}
	
	return ret;
}

pure string getRelationshipClassModuleName(T, string f)() {
	T t = newValueOfType!T;
	string ret = null;

	foreach(UDA; __traits(getAttributes, mixin("t." ~ f))) {
		foreach(UDA2; __traits(getAttributes, UDA))
			static if (UDA2 == "dbIsModel")
				ret = moduleName!(typeof(UDA.type));
	}
	
	return ret;
}

/**
 * Get the name of property that the relationship's classes property is.
 */

string getRelationshipPropertyName(T, string f)() {
	T t = newValueOfType!T;
	string ret = null;

	foreach(UDA; __traits(getAttributes, mixin("t." ~ f))) {
		foreach(UDA2; __traits(getAttributes, UDA)) {
			static if (UDA2 == "dbIsModel") {
				ret = (UDA.init).name;
			}
		}
	}
	
	return ret;
}

/**
 * 
 */

pure string getterName(string m)() {
	static assert(m.length >= 2, "Property name must be more then 1 charactor long");
	return "get" ~ cast(char)m[0].toUpper() ~ m [1 .. $];
}

pure string setterName(string m)() {
	static assert(m.length >= 2, "Property name must be more then 1 charactor long");
	return "set" ~ cast(char)m[0].toUpper() ~ m [1 .. $];
}

pure T newValueOfType(T)() {
    static if (__traits(compiles, {T t = new T;}))
        return new T;
    else
	return T.init;
}

/**
 * Checks if a given type is either a class or a struct.
 */
pure bool isAnObjectType(T)() {
	return is(T : Object) || is(T == struct);
}

/**
 * 
 */

T[] dePointerArrayValues(T)(T*[] values) {
	T[] ret;
	foreach(v; values) {
		ret ~= *v;
	}
	
	return ret;
}
