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
    sqlite_query/3
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
