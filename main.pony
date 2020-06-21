use net = "net"

class ServerNotify is net.TCPConnectionNotify
  var _env: Env
  var _client: net.TCPConnection
  var _clientNotify: ClientNotify ref
  var _conn: (net.TCPConnection | None) = None
  var _buffer: String = ""

  new create(env: Env, client: net.TCPConnection, clientNotify: ClientNotify ref) =>
    _env = env
    _client = client
    _clientNotify = clientNotify
    env.out.print("server notify created")

  fun ref connected(conn: net.TCPConnection ref) =>
    _clientNotify.server_ready()

  fun ref received(conn: net.TCPConnection ref, data: Array[U8] iso, times: USize): Bool =>
    _env.out.print("server notify received")
    var s = String.from_array(consume data)
    _env.out.print("<-")
    _env.out.print(s)
    _client.write(s)
    true

  fun ref connect_failed(conn: net.TCPConnection ref) =>
    None

class ClientNotify is net.TCPConnectionNotify
  var _env: Env
  var _server: (net.TCPConnection | None) = None
  var _server_ready: Bool = false
  var _buffer: String = ""

  new create(env: Env) =>
    _env = env

  fun ref accepted(conn: net.TCPConnection ref) =>
    try
      _server = net.TCPConnection(_env.root as AmbientAuth,
        recover ServerNotify(_env, conn, this) end, "localhost", "8080")
    else
      _env.out.print("server connected error")
    end
    None

  fun ref server_ready() =>
    _server_ready = true
    match _server
    | let serv: net.TCPConnection => serv.write(_buffer)
    | let serv: None => None
    end
    _buffer = ""

  fun ref received(_: net.TCPConnection ref, data: Array[U8] val, times: USize): Bool =>
    var s = String.from_array(data)
    _env.out.print("->")
    _env.out.print(s)
    if _server_ready then
        match _server
        | let serv: net.TCPConnection => serv.write(data)
        | let serv: None => _buffer.add(s)
        end
    else
        _buffer = _buffer.add(s)
    end
    true

  fun ref connect_failed(conn: net.TCPConnection ref) =>
    None

class ClientListenNotify is net.TCPListenNotify
  var _env: Env

  new create(env: Env) =>
    _env = env
    
  fun ref connected(listen: net.TCPListener ref): net.TCPConnectionNotify iso^ =>
    recover ClientNotify(_env) end

  fun ref not_listening(listen: net.TCPListener ref) =>
    None

actor Main
  new create(env: Env) =>
    try
      net.TCPListener(
        env.root as AmbientAuth,
        recover ClientListenNotify(env) end,
        "", "8989")
    end
