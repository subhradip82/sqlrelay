-module(sqlrelay).

%% Author: Bruce Kissinger, 2008
%% This work is licensed under the Creative Commons Attribution 3.0 United States License. To view a copy of this license, visit http://creativecommons.org/licenses/by/3.0/us/ or send a letter to Creative Commons, 171 Second Street, Suite 300, San Francisco, California, 94105, USA.


% API
-export([start/0, start/1, stop/0]).

-export([alloc/7, connectionFree/0, cursorFree/0, endSession/0, suspendSession/0, resumeSession/2]).
-export([ping/0, identify/0, dbVersion/0, bindFormat/0, errorMessage/0]).
-export([getConnectionPort/0, getConnectionSocket/0]).
-export([autoCommitOn/0, autoCommitOff/0, commit/0, rollback/0]).
-export([debugOn/0, debugOff/0, getDebug/0]).
-export([setResultSetBufferSize/1, getResultSetBufferSize/0]).
-export([dontGetColumnInfo/0, getColumnInfo/0]).
-export([mixedCaseColumnNames/0, upperCaseColumnNames/0, lowerCaseColumnNames/0]).
-export([cacheToFile/1, setCacheTtl/1, getCacheFileName/0, cacheOff/0]).

-export([sendQuery/1, sendQueryWithLength/2, sendFileQuery/2]).

-export([prepareQuery/1, prepareQueryWithLength/2, prepareFileQuery/2]).
-export([subString/2, subLong/2, subDouble/4]).
-export([clearBinds/0, countBindVariables/0]).
-export([inputBindString/2, inputBindLong/2, inputBindDouble/4, inputBindBlob/3, inputBindClob/3 ]).
-export([defineOutputBindString/2, defineOutputBindInteger/1, defineOutputBindDouble/1, defineOutputBindBlob/1, defineOutputBindClob/1, defineOutputBindCursor/1]).
-export([validateBinds/0, validBind/1]).
-export([executeQuery/0]).
-export([fetchFromBindCursor/0]).
-export([getOutputBindString/1, getOutputBindInteger/1, getOutputBindDouble/1, getOutputBindBlob/1, getOutputBindClob/1, getOutputBindCursor/1, getOutputBindLength/1]).
-export([openCachedResultSet/1]).
-export([colCount/0, rowCount/0, totalRows/0, affectedRows/0]).
-export([firstRowIndex/0, endOfResultSet/0]).
-export([getNullsAsEmptyStrings/0, getNullsAsNulls/0]).
-export([getFieldByIndex/2, getFieldByName/2]).
-export([getFieldAsIntegerByIndex/2, getFieldAsIntegerByName/2]).
-export([getFieldAsDoubleByIndex/2, getFieldAsDoubleByName/2]).
-export([getFieldLengthByIndex/2, getFieldLengthByName/2]).
-export([getRow/1, getRowLengths/1]).
-export([getColumnNames/0, getColumnName/1]).

-export([getColumnTypeByIndex/1, getColumnTypeByName/1]).
-export([getColumnLengthByIndex/1, getColumnLengthByName/1]).
-export([getColumnPrecisionByIndex/1, getColumnPrecisionByName/1]).
-export([getColumnScaleByIndex/1, getColumnScaleByName/1]).
-export([getColumnIsNullableByIndex/1, getColumnIsNullableByName/1]).
-export([getColumnIsPrimaryKeyByIndex/1, getColumnIsPrimaryKeyByName/1]).
-export([getColumnIsUniqueByIndex/1, getColumnIsUniqueByName/1]).
-export([getColumnIsPartOfKeyByIndex/1, getColumnIsPartOfKeyByName/1]).
-export([getColumnIsUnsignedByIndex/1, getColumnIsUnsignedByName/1]).
-export([getColumnIsZeroFilledByIndex/1, getColumnIsZeroFilledByName/1]).
-export([getColumnIsBinaryByIndex/1, getColumnIsBinaryByName/1]).
-export([getColumnIsAutoIncrementByIndex/1, getColumnIsAutoIncrementByName/1]).
-export([getLongestByIndex/1, getLongestByName/1]).

-export([suspendResultSet/0, getResultSetId/0, resumeResultSet/1, resumeCachedResultSet/2]).


% Internal exports
-export([init/1]).

%
% Driver control functions
%
start() ->
    start("./relay").
start(ExtPrg) ->
    spawn_link(?MODULE, init, [ExtPrg]).
stop() ->
	case(get("cursor")) of 
		"true" ->
			erase("cursor"),
			cursorFree();    
		_ ->  true
	end,
	case(get("connection")) of 
		"true" ->
			erase("connection"),
			connectionFree();    
		_ ->  true
	end,
	endSession(),    
	?MODULE ! stop.

%
% API functions
%

alloc(Server, Port, Socket, User, Password, Retrytime, Tries) 
	when is_list(Server), is_integer(Port), is_list(User), is_list(Password), is_integer(Retrytime), is_integer(Tries) -> 
	put("connection", "true"),
	call_port({alloc, Server, Port, Socket, User, Password, Retrytime, Tries}).

ping() -> call_port({ping}).

connectionFree() -> erase("connection"), call_port({connectionFree}).

cursorFree() -> erase("cursor"), call_port({cursorFree}).

endSession() -> call_port({endSession}).

suspendSession() -> call_port({suspendSession}).

getConnectionPort() -> call_port({getConnectionPort}).

getConnectionSocket() -> call_port({getConnectionSocket}).

resumeSession(Port, Socket) when is_integer(Port), is_list(Socket) -> call_port({getConnectionSocket, Port, Socket}).

identify() -> call_port({identify}).

dbVersion() -> call_port({dbVersion}).

bindFormat() -> call_port({bindFormat}).

autoCommitOn() -> call_port({autoCommitOn}).

autoCommitOff() -> call_port({autoCommitOff}).

commit() -> call_port({commit}).

rollback() -> call_port({rollback}).

debugOn() -> call_port({debugOn}).

debugOff() -> call_port({debugOff}).

getDebug() -> call_port({getDebug}).

setResultSetBufferSize(Rows) when is_integer(Rows) -> call_port({setResultSetBufferSize, Rows}).

getResultSetBufferSize() -> call_port({getResultSetBufferSize}).

dontGetColumnInfo() -> call_port({dontGetColumnInfo}).

getColumnInfo() -> call_port({getColumnInfo}).

mixedCaseColumnNames() -> call_port({mixedCaseColumnNames}).

upperCaseColumnNames() -> call_port({upperCaseColumnNames}).

lowerCaseColumnNames() -> call_port({lowerCaseColumnNames}).

cacheToFile(Filename) when is_list(Filename) ->  call_port({cacheToFile, Filename}).

setCacheTtl(Ttl) ->  call_port({setCacheTtl, Ttl}).

getCacheFileName() ->  call_port({getCacheFileName}).

cacheOff() ->  call_port({cacheOff}).

sendQuery(Query) when is_list(Query) -> 
	put("cursor", "true"),
	call_port({sendQuery, Query}).  

sendQueryWithLength(Query, Length) when is_list(Query), is_integer(Length) -> 
	put("cursor", "true"),
	call_port({sendQueryWithLength, Query, Length}).  

sendFileQuery(Path, Filename) when is_list(Path), is_list(Filename) -> 
	put("cursor", "true"),
	call_port({sendFileQuery, Path, Filename}).  

prepareQuery(Query) when is_list(Query) -> call_port({prepareQuery, Query}).  

prepareQueryWithLength(Query, Length) when is_list(Query), is_integer(Length) -> 
	call_port({prepareQueryWithLength, Query, Length}).  

prepareFileQuery(Path, Filename) when is_list(Path), is_list(Filename) -> 
	call_port({prepareFileQuery, Path, Filename}).  

subString(Variable, Value) when is_list(Variable), is_list(Value) ->
	call_port({subString, Variable, Value}).  

subLong(Variable, Value) when is_list(Variable), is_integer(Value) ->
	call_port({subLong, Variable, Value}).  

subDouble(Variable, Value, Precision, Scale) 
	when is_list(Variable), is_float(Value), is_integer(Precision), is_integer(Scale) ->
	call_port({subDouble, Variable, Value, Precision, Scale}).  

clearBinds() -> call_port({clearBinds}).

countBindVariables() -> call_port({countBindVariables}).

inputBindString(Variable, Value) when is_list(Variable), is_list(Value) ->
	call_port({inputBindString, Variable, Value}).  

inputBindLong(Variable, Value) when is_list(Variable), is_integer(Value) ->
	call_port({inputBindLong, Variable, Value}).  

inputBindDouble(Variable, Value, Precision, Scale) 
	when is_list(Variable), is_float(Value), is_integer(Precision), is_integer(Scale) ->
	call_port({inputBindDouble, Variable, Value, Precision, Scale}).  

inputBindBlob(Variable, Value, Size) 
	when is_list(Variable), is_list(Value), is_integer(Size) ->
	call_port({inputBindBlob, Variable, Value, Size}).  

inputBindClob(Variable, Value, Size) 
	when is_list(Variable), is_list(Value), is_integer(Size) ->
	call_port({inputBindClob, Variable, Value, Size}).  


defineOutputBindString(Variable, Length) 
	when is_list(Variable), is_integer(Length) ->
	call_port({defineOutputBindString, Variable, Length}).  

defineOutputBindInteger(Variable) when is_list(Variable)  ->
	call_port({defineOutputBindInteger, Variable}).  

defineOutputBindDouble(Variable) when is_list(Variable)  ->
	call_port({defineOutputBindDouble, Variable}).  

defineOutputBindBlob(Variable) when is_list(Variable)  ->
	call_port({defineOutputBindBlob, Variable}).  

defineOutputBindClob(Variable) when is_list(Variable)  ->
	call_port({defineOutputBindClob, Variable}).  

defineOutputBindCursor(Variable) when is_list(Variable)  ->
	call_port({defineOutputBindCursor, Variable}).  


validateBinds() -> call_port({validateBinds}).

validBind(Variable) when is_list(Variable) -> 
	call_port({validBind, Variable}).

executeQuery() -> call_port({executeQuery}).

fetchFromBindCursor() -> call_port({fetchFromBindCursor}).


getOutputBindString(Variable) when is_list(Variable) ->
	call_port({getOutputBindString, Variable}).  

getOutputBindBlob(Variable) when is_list(Variable) ->
	call_port({getOutputBindBlob, Variable}).  

getOutputBindClob(Variable) when is_list(Variable) ->
	call_port({getOutputBindClob, Variable}).  

getOutputBindInteger(Variable) when is_list(Variable) ->
	call_port({getOutputBindInteger, Variable}).  

getOutputBindDouble(Variable) when is_list(Variable) ->
	call_port({getOutputBindDouble, Variable}).  

getOutputBindLength(Variable) when is_list(Variable) ->
	call_port({getOutputBindLength, Variable}).  

getOutputBindCursor(Variable) when is_list(Variable) ->
	% function not implemented
	false.

openCachedResultSet(Filename) when is_list(Filename) ->
	call_port({openCachedResultSet, Filename}).  


colCount() -> call_port({colCount}).

rowCount() -> call_port({rowCount}).

totalRows() -> call_port({totalRows}).

affectedRows() -> call_port({affectedRows}).

firstRowIndex() -> call_port({firstRowIndex}).

endOfResultSet() -> call_port({endOfResultSet}).

errorMessage() -> call_port({errorMessage}).

getNullsAsEmptyStrings() -> call_port({getNullsAsEmptyStrings}).

getNullsAsNulls() -> call_port({getNullsAsNulls}).



getFieldByIndex(Row, Col) when is_integer(Row), is_integer(Col) -> 
	call_port({getFieldByIndex, Row, Col}).

getFieldByName(Row, Col) when is_integer(Row), is_list(Col) -> 
	call_port({getFieldByName, Row, Col}).

getFieldAsIntegerByIndex(Row, Col) when is_integer(Row), is_integer(Col) -> 
	call_port({getFieldAsIntegerByIndex, Row, Col}).

getFieldAsIntegerByName(Row, Col) when is_integer(Row), is_list(Col) -> 
	call_port({getFieldAsIntegerByName, Row, Col}).

getFieldAsDoubleByIndex(Row, Col) when is_integer(Row), is_integer(Col) -> 
	call_port({getFieldAsDoubleByIndex, Row, Col}).

getFieldAsDoubleByName(Row, Col) when is_integer(Row), is_list(Col) -> 
	call_port({getFieldAsDoubleByName, Row, Col}).

getFieldLengthByIndex(Row, Col) when is_integer(Row), is_integer(Col) -> 
	call_port({getFieldLengthByIndex, Row, Col}).

getFieldLengthByName(Row, Col) when is_integer(Row), is_list(Col) -> 
	call_port({getFieldLengthByName, Row, Col}).

getRowLengths(Row) when is_integer(Row) -> call_port({getRowLengths, Row}).

getColumnNames() -> call_port({getColumnNames}).

getColumnName(Col) when is_integer(Col) -> call_port({getColumnName, Col}).


getColumnTypeByIndex(Col) when is_integer(Col) -> call_port({getColumnTypeByIndex, Col}).
getColumnTypeByName(Col) when is_list(Col) -> call_port({getColumnTypeByName, Col}).

getColumnLengthByIndex(Col) when is_integer(Col) -> call_port({getColumnLengthByIndex, Col}).
getColumnLengthByName(Col) when is_list(Col) -> call_port({getColumnLengthByName, Col}).

getColumnPrecisionByIndex(Col) when is_integer(Col) -> call_port({getColumnPrecisionByIndex, Col}).
getColumnPrecisionByName(Col) when is_list(Col) -> call_port({getColumnPrecisionByName, Col}).

getColumnScaleByIndex(Col) when is_integer(Col) -> call_port({getColumnScaleByIndex, Col}).
getColumnScaleByName(Col) when is_list(Col) -> call_port({getColumnScaleByName, Col}).

getColumnIsNullableByIndex(Col) when is_integer(Col) -> call_port({getColumnIsNullableByIndex, Col}).
getColumnIsNullableByName(Col) when is_list(Col) -> call_port({getColumnIsNullableByName, Col}).

getColumnIsPrimaryKeyByIndex(Col) when is_integer(Col) -> call_port({getColumnIsPrimaryKeyByIndex, Col}).
getColumnIsPrimaryKeyByName(Col) when is_list(Col) -> call_port({getColumnIsPrimaryKeyByName, Col}).

getColumnIsUniqueByIndex(Col) when is_integer(Col) -> call_port({getColumnIsUniqueByIndex, Col}).
getColumnIsUniqueByName(Col) when is_list(Col) -> call_port({getColumnIsUniqueByName, Col}).

getColumnIsPartOfKeyByIndex(Col) when is_integer(Col) -> call_port({getColumnIsPartOfKeyByIndex, Col}).
getColumnIsPartOfKeyByName(Col) when is_list(Col) -> call_port({getColumnIsPartOfKeyByName, Col}).

getColumnIsUnsignedByIndex(Col) when is_integer(Col) -> call_port({getColumnIsUnsignedByIndex, Col}).
getColumnIsUnsignedByName(Col) when is_list(Col) -> call_port({getColumnIsUnsignedByName, Col}).

getColumnIsZeroFilledByIndex(Col) when is_integer(Col) -> call_port({getColumnIsZeroFilledByIndex, Col}).
getColumnIsZeroFilledByName(Col) when is_list(Col) -> call_port({getColumnIsZeroFilledByName, Col}).

getColumnIsBinaryByIndex(Col) when is_integer(Col) -> call_port({getColumnIsBinaryByIndex, Col}).
getColumnIsBinaryByName(Col) when is_list(Col) -> call_port({getColumnIsBinaryByName, Col}).

getColumnIsAutoIncrementByIndex(Col) when is_integer(Col) -> call_port({getColumnIsAutoIncrementByIndex, Col}).
getColumnIsAutoIncrementByName(Col) when is_list(Col) -> call_port({getColumnIsAutoIncrementByName, Col}).

getLongestByIndex(Col) when is_integer(Col) -> call_port({getLongestByIndex, Col}).
getLongestByName(Col) when is_list(Col) -> call_port({getLongestByName, Col}).

suspendResultSet() -> call_port({suspendResultSet}).
getResultSetId() -> call_port({getResultSetId}).
resumeResultSet(Id) when is_integer(Id) -> call_port({resumeResultSet, Id}).
resumeCachedResultSet(Id, Filename) when is_integer(Id), is_list(Filename) -> 
	call_port({resumeCachedResultSet, Id, Filename}).

% Special function to replace the getRow from the SQLRelay client wrapper
% After a query has been run return a tuple
% containing each column for a given row
getRow(Row) when is_integer(Row) ->
        {ok, Columns} = colCount(),
        L = appendColumnForRow([], Row, Columns-1),
        lists:reverse(L),
        list_to_tuple(L).

appendColumnForRow(L, Row, 0) ->
        {ok, Value} = getFieldByIndex(Row, 0),
        lists:append(L, Value);
appendColumnForRow(L, Row, Col) ->
        {ok, Value} = getFieldByIndex(Row, Col),
        NewL = lists:append(L, Value),
        appendColumnForRow(NewL, Row, Col-1).

%
% Port communication functions
%
call_port(Msg) ->
    ?MODULE ! {call, self(), Msg},
    receive
    Result ->
        Result
    end.

init(ExtPrg) ->
    register(?MODULE, self()),
    process_flag(trap_exit, true),
    Port = open_port({spawn, ExtPrg}, [{packet, 2}, binary, exit_status]),
    loop(Port).

loop(Port) ->
    receive
    {call, Caller, Msg} ->
%       io:format("Calling port with ~p~n", [Msg]),
        erlang:port_command(Port, term_to_binary(Msg)),
        receive
        {Port, {data, Data}} ->
            Caller ! binary_to_term(Data);
        {Port, {error, Data}} ->
            Caller ! binary_to_term(Data);
        {Port, {exit_status, Status}} when Status > 128 ->
            io:format("Port terminated with signal: ~p~n", [Status-128]),
            exit({port_terminated, Status});
        {Port, {exit_status, Status}} ->
            io:format("Port terminated with status: ~p~n", [Status]),
            exit({port_terminated, Status});
        {'EXIT', Port, Reason} ->
            exit(Reason)
        end,
        loop(Port);
    stop ->
        erlang:port_close(Port),
        exit(normal)
    end.
