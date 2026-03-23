import core.runtime;
import core.sys.windows.windows;
import core.sys.windows.tlhelp32;
import core.thread;
import core.time;
import std.algorithm;
import std.array;
import std.conv;
import std.file;
import std.format;
import std.json;
import std.socket;
import std.string;

enum string VERSION = "0.1.1";

__gshared status = "idle";
__gshared Http req;
__gshared Http res;

// My beautiful, standards disregarding, dogshit HTTP server

void httpRun() {
	auto server = new TcpSocket();
	server.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
	server.bind(new InternetAddress(31123));
	server.listen(1);

	while(true) {
		Socket client = server.accept();

		string data = "";
		char[1024] buffer;

		try {
			while (client.isAlive()) {
				auto received = client.receive(buffer);

				if (received > 0) {
					data ~= buffer[0..received];
					string message = data;
					Http http = parseHttp(message);
					if (http.valid) {
						if (http.method == "GET" && http.path == "/ping") {
							client.sendResponse(`{"name": "vs-link-ersatz", "version": "` ~ VERSION ~ `"}`);
							break;
						} else if (http.method == "POST" && http.path == "/status") {
							sendToLua(client, http);
						} else if (http.method == "GET" && http.path == "/sync") {
							sendToLua(client, http);
							break;
						} else {
							client.sendResponse(`{"error": "Unknown Vs. Link Ersatz command"}`);
						}
					}
				} else {
					break;
				}
			}
		} catch (Exception e) {
		}
		try {
			client.shutdown(SocketShutdown.BOTH);
			client.close();
		} catch (Exception e) {
		}
	}
}

void sendToLua(Socket client, Http http) {
	req = http;
	status = "requested";
	for (int waits = 0; waits < 200; waits++) {
		Thread.sleep(dur!"msecs"(30));
		if (status == "responded") {
			Http response = res;
			client.sendResponse(response.content);
			status = "idle";
			return;
		}
	}
	status = "idle";
	client.sendResponse(`{"error": "DeSmuME took too long to respond!"}`);
}

void sendResponse(Socket client, string message) {
	string response = 
		"HTTP/1.0 200 OK\r\n" ~
		"Access-Control-Allow-Origin: *\r\n" ~
		"Content-Type: text/plain\r\n" ~
		"Content-Length: " ~ message.length.to!string ~ "\r\n" ~
		"\r\n" ~ message;
	client.send(response);
}

Http parseHttp(string message) {
	Http http;
	long s = message.countUntil("\r\n\r\n");
	if (s != -1) {
		string[] headers = message[0..s].split("\r\n");
		string content = message[s + 4..$];
		string[] start = headers[0].split(" ");
		http.content = content;
		http.method = start[0];
		http.path = start[1];
		if (http.path.length > 0 && http.path[$ - 1] == '/') {
			http.path = http.path[0..$ - 1];
		}
		for (int i = 1; i < headers.length; i++) {
			string header = headers[i].strip();
			long sp = header.countUntil(":");
			if (sp == -1) {
				continue;
			}
			string key = header[0..sp].strip();
			string value = header[sp + 1..$].strip();
			http.headers[key] = value;
		}
	}
	return http;
}

struct Http {
	string method;
	string path;
	string[string] headers;
	string content;

	bool valid() {
		if (!headers.empty && "Content-Length" !in headers) {
			return true;
		}
		if ("Content-Length" in headers && headers["Content-Length"].to!int == content.length) {
			return true;
		}
		return false;
	}

	JSONValue json() {
		if ("Content-Type" in headers && headers["Content-Type"] == "application/json") {
			return parseJSON(content);
		}
		return JSONValue(null);
	}
}

// Lua nonsense

enum int LUA_GLOBALSCONTEXT = -10_002;

alias lua_State = void*;
alias lua_CFunction = extern(C) int function(lua_State L);

extern(C):

void function(lua_State L, const(char)*) 			lua_pushstring;
void function(lua_State L, ptrdiff_t)				lua_pushinteger;
void function(lua_State L, int idx, const(char)*) 	lua_setfield;
void function(lua_State L, lua_CFunction, int)		lua_pushcclosure;
void function(lua_State L, int, int)				lua_createtable;
void function(lua_State L, int)						lua_settable;
int function(lua_State L)							lua_gettop;
void function(lua_State L, int) 					lua_settop;
const(char)* function(lua_State L, int, size_t*)	luaL_checklstring;
void function(lua_State L, int, int)				lua_rawgeti;
size_t function(lua_State L, int)					lua_objlen;
ptrdiff_t function(lua_State L, int)				lua_tointeger;

extern(C) int vs_pollServer(lua_State L) {
	lua_createtable(L, 0, 0);

	string s = status;
	addTableField(L, "status", s);
	if (s == "requested") {
		addTableField(L, "method", req.method);
		addTableField(L, "path", req.path);
		addTableField(L, "request", req.content);
	}

	return 1;
}


extern(C) int vs_error(lua_State L) {
	size_t* size;
	string reason = cast(string) luaL_checklstring(L, 1, size).fromStringz();
	if (status == "requested") {
		res.content = `{"error": "` ~ reason ~ `"}`;
		status = "responded";
	}
	return 0;
}

extern(C) int vs_respond(lua_State L) {
	int args = lua_gettop(L);
	if (status == "requested") {
		if (req.path == "/sync") {
			int[] pc = getIntArray(L, 2);
			lua_settop(L, -2);
			int[] party = getIntArray(L, 1);
			res.content = `{"name": "vs-link-ersatz", "version": "` ~ VERSION ~ `", "party": ` ~ party.to!string ~ `, "pc": ` ~ pc.to!string ~ `}`;
			status = "responded";
		} else {
			res.content = `{"name": "vs-link-ersatz", "version": "` ~ VERSION ~ `"}`;
			status = "responded";
		}
	}
	return 0;
}

int[] getIntArray(lua_State L, int index) {
	size_t len = lua_objlen(L, index);

	int[] arr = new int[len];
	for (int i = 0; i < len; i++) {
		lua_rawgeti(L, index, i + 1);
		arr[i] = cast(int) lua_tointeger(L, -1);
		lua_settop(L, -2);
	}

	return arr;
}

HMODULE findLuaModule() {
	// Windows API future proofing in case DeSmuME ever changes their Lua version
	HANDLE hSnap = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, GetCurrentProcessId());
	if (hSnap == INVALID_HANDLE_VALUE) {
		return null;
	}

	MODULEENTRY32 me;
	me.dwSize = MODULEENTRY32.sizeof;

	if (Module32First(hSnap, &me)) {
		do {
			auto proc = GetProcAddress(me.hModule, "lua_gettop");
			if (proc) {
				CloseHandle(hSnap);
				return me.hModule;
			}
		} while (Module32Next(hSnap, &me));
	}

	CloseHandle(hSnap);
	return null;
}

void addTableField(lua_State L, string key, string value) {
	lua_pushstring(L, key.toStringz());
	lua_pushstring(L, value.toStringz());
	lua_settable(L, -3);
}

void addGlobal(lua_State L, string name, lua_CFunction func) {
	lua_pushcclosure(L, func, 0);
	lua_setfield(L, LUA_GLOBALSCONTEXT, name.toStringz());
}

extern(C) export int luaopen_vslinkcore(lua_State L) {
	if (!Runtime.initialize()) {
		return 0;
	}

	Thread thread = new Thread(&httpRun);
	thread.start();

	HMODULE hLua = findLuaModule();

	lua_pushstring = cast(typeof(lua_pushstring)) GetProcAddress(hLua, "lua_pushstring");
	lua_pushinteger = cast(typeof(lua_pushinteger)) GetProcAddress(hLua, "lua_pushinteger");
	lua_pushcclosure = cast(typeof(lua_pushcclosure)) GetProcAddress(hLua, "lua_pushcclosure");
	lua_setfield = cast(typeof(lua_setfield)) GetProcAddress(hLua, "lua_setfield");
	lua_createtable = cast(typeof(lua_createtable)) GetProcAddress(hLua, "lua_createtable");
	lua_settable = cast(typeof(lua_settable)) GetProcAddress(hLua, "lua_settable");
	lua_gettop = cast(typeof(lua_gettop)) GetProcAddress(hLua, "lua_gettop");
	lua_settop = cast(typeof(lua_settop)) GetProcAddress(hLua, "lua_settop");
	luaL_checklstring = cast(typeof(luaL_checklstring)) GetProcAddress(hLua, "luaL_checklstring");
	lua_rawgeti = cast(typeof(lua_rawgeti)) GetProcAddress(hLua, "lua_rawgeti");
	lua_objlen = cast(typeof(lua_objlen)) GetProcAddress(hLua, "lua_objlen");
	lua_tointeger = cast(typeof(lua_tointeger)) GetProcAddress(hLua, "lua_tointeger");

	addGlobal(L, "vs_pollServer", &vs_pollServer);
	addGlobal(L, "vs_respond", &vs_respond);
	addGlobal(L, "vs_error", &vs_error);
	
	return 0;
}
