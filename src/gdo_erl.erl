%%% --------------------------------------------------
%%% @author @hebertcisco <hebertcisco@outlook.com>
%%% @doc Erlang ffi glue code for the gdo Gleam package.
%%% @end
%%% --------------------------------------------------

-module(gdo_erl).

-export([
    sqlite_open/1,
    sqlite_close/1,
    sqlite_exec/2,
    sqlite_query/3,
    mysql_open/7,
    mysql_close/1,
    mysql_exec/3,
    mysql_query/3,
    mysql_last_insert_id/1
]).

sqlite_open(Path) ->
    case sqlight_ffi:open(Path) of
        {ok, Connection} ->
            {ok, Connection};
        {error, {sqlight_error, Code, Message, Offset}} ->
            {error, {sqlite_native_error, sqlight:error_code_to_int(Code), Message, Offset}}
    end.

sqlite_close(Connection) ->
    case sqlight_ffi:close(Connection) of
        {ok, nil} ->
            {ok, nil};
        {error, {sqlight_error, Code, Message, Offset}} ->
            {error, {sqlite_native_error, sqlight:error_code_to_int(Code), Message, Offset}}
    end.

sqlite_exec(Sql, Connection) ->
    case sqlight_ffi:exec(Sql, Connection) of
        {ok, nil} ->
            {ok, nil};
        {error, {sqlight_error, Code, Message, Offset}} ->
            {error, {sqlite_native_error, sqlight:error_code_to_int(Code), Message, Offset}}
    end.

sqlite_query(Sql, Connection, Arguments) ->
    case sqlight_ffi:query(Sql, Connection, Arguments) of
        {ok, Rows} ->
            {ok, Rows};
        {error, {sqlight_error, Code, Message, Offset}} ->
            {error, {sqlite_native_error, sqlight:error_code_to_int(Code), Message, Offset}}
    end.

mysql_open(Host, Port, Database, Username, Password, TlsMode, Options) ->
    MysqlOptions =
        [{host, Host},
         {port, Port},
         {user, Username},
         {password, Password},
         {database, Database},
         {connect_mode, synchronous}] ++
        mysql_ssl_options(TlsMode, Options) ++
        mysql_client_options(Options),
    case mysql:start_link(MysqlOptions) of
        {ok, Connection} ->
            {ok, Connection};
        ignore ->
            {error, {my_sql_native_error, none, none,
                     <<"MySQL connection start returned ignore.">>}};
        {error, Reason} ->
            {error, mysql_native_error(Reason)}
    end.

mysql_close(Connection) ->
    case catch mysql:stop(Connection) of
        ok ->
            {ok, nil};
        {'EXIT', Reason} ->
            {error, mysql_native_error(Reason)}
    end.

mysql_exec(Sql, Connection, Arguments) ->
    Params = mysql_params(Arguments),
    case mysql:query(Connection, Sql, Params) of
        ok ->
            {ok, mysql_execution_result(Connection)};
        {ok, _Columns, _Rows} ->
            {ok, mysql_execution_result(Connection)};
        {ok, [_ | _]} ->
            {error, unsupported_multiple_result_sets()};
        {error, Reason} ->
            {error, mysql_native_error(Reason)}
    end.

mysql_query(Sql, Connection, Arguments) ->
    Params = mysql_params(Arguments),
    case mysql:query(Connection, Sql, Params) of
        ok ->
            {ok, {my_sql_query_result, [], []}};
        {ok, Columns, Rows} ->
            {ok, {my_sql_query_result, stringify_columns(Columns), Rows}};
        {ok, [_ | _]} ->
            {error, unsupported_multiple_result_sets()};
        {error, Reason} ->
            {error, mysql_native_error(Reason)}
    end.

mysql_last_insert_id(Connection) ->
    {ok, maybe_insert_id(mysql:insert_id(Connection))}.

mysql_execution_result(Connection) ->
    {my_sql_execution_result,
     mysql:affected_rows(Connection),
     maybe_insert_id(mysql:insert_id(Connection))}.

maybe_insert_id(0) ->
    none;
maybe_insert_id(Id) ->
    {some, Id}.

unsupported_multiple_result_sets() ->
    {my_sql_native_error, none, none,
     <<"Multiple MySQL result sets are not supported by gdo.">>}.

mysql_params(Arguments) ->
    lists:map(fun mysql_param/1, Arguments).

mysql_param(null) ->
    null;
mysql_param({int, Value}) ->
    Value;
mysql_param({float, Value}) ->
    Value;
mysql_param({bool, true}) ->
    1;
mysql_param({bool, false}) ->
    0;
mysql_param({string, Value}) ->
    Value;
mysql_param({bytes, Value}) ->
    Value.

stringify_columns(Columns) ->
    lists:map(fun to_binary/1, Columns).

mysql_native_error({Code, SqlState, Message}) when is_integer(Code) ->
    {my_sql_native_error, {some, Code}, maybe_binary(SqlState), to_binary(Message)};
mysql_native_error({shutdown, Reason}) ->
    mysql_native_error(Reason);
mysql_native_error(busy) ->
    {my_sql_native_error, none, none,
     <<"MySQL connection is busy with another transaction owner.">>};
mysql_native_error(Reason) ->
    {my_sql_native_error, none, none,
     to_binary(io_lib:format("~0tp", [Reason]))}.

maybe_binary(undefined) ->
    none;
maybe_binary(Value) ->
    {some, to_binary(Value)}.

to_binary(Value) when is_binary(Value) ->
    Value;
to_binary(Value) when is_list(Value) ->
    unicode:characters_to_binary(Value);
to_binary(Value) ->
    unicode:characters_to_binary(io_lib:format("~0tp", [Value])).

mysql_ssl_options(<<"disable_tls">>, _Options) ->
    [];
mysql_ssl_options(_, Options) ->
    SslOptions =
        [{verify, verify_none}, {server_name_indication, disable}] ++
        maybe_ssl_cacertfile(Options),
    [{ssl, SslOptions}].

maybe_ssl_cacertfile(Options) ->
    case proplists:get_value(<<"ssl_cacertfile">>, Options) of
        undefined ->
            [];
        Path ->
            [{cacertfile, Path}]
    end.

mysql_client_options(Options) ->
    lists:foldl(fun mysql_client_option/2, [], Options).

mysql_client_option({<<"connect_timeout">>, Value}, Acc) ->
    maybe_integer_option(connect_timeout, Value, Acc);
mysql_client_option({<<"query_timeout">>, Value}, Acc) ->
    maybe_integer_option(query_timeout, Value, Acc);
mysql_client_option({<<"keep_alive">>, Value}, Acc) ->
    maybe_boolean_or_integer_option(keep_alive, Value, Acc);
mysql_client_option({<<"query_cache_time">>, Value}, Acc) ->
    maybe_integer_option(query_cache_time, Value, Acc);
mysql_client_option({<<"found_rows">>, Value}, Acc) ->
    maybe_boolean_option(found_rows, Value, Acc);
mysql_client_option({<<"log_warnings">>, Value}, Acc) ->
    maybe_boolean_option(log_warnings, Value, Acc);
mysql_client_option({<<"log_slow_queries">>, Value}, Acc) ->
    maybe_boolean_option(log_slow_queries, Value, Acc);
mysql_client_option({<<"ssl_cacertfile">>, _Value}, Acc) ->
    Acc;
mysql_client_option(_, Acc) ->
    Acc.

maybe_integer_option(Key, Value, Acc) ->
    case parse_integer(Value) of
        {ok, Integer} ->
            [{Key, Integer} | Acc];
        error ->
            Acc
    end.

maybe_boolean_option(Key, Value, Acc) ->
    case parse_boolean(Value) of
        {ok, Boolean} ->
            [{Key, Boolean} | Acc];
        error ->
            Acc
    end.

maybe_boolean_or_integer_option(Key, Value, Acc) ->
    case parse_boolean(Value) of
        {ok, Boolean} ->
            [{Key, Boolean} | Acc];
        error ->
            maybe_integer_option(Key, Value, Acc)
    end.

parse_integer(Value) when is_integer(Value) ->
    {ok, Value};
parse_integer(Value) ->
    try
        {ok, binary_to_integer(to_binary(Value))}
    catch
        error:badarg ->
            error
    end.

parse_boolean(<<"true">>) ->
    {ok, true};
parse_boolean(<<"false">>) ->
    {ok, false};
parse_boolean(true) ->
    {ok, true};
parse_boolean(false) ->
    {ok, false};
parse_boolean(_) ->
    error.
